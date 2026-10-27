# Architecture

The project is one Rust binary. Everything the user interacts with — API,
subprocess orchestration, static assets, exports — lives behind a single
process. SQLite is the storage layer; there's no daemon or external queue.

```
┌─────────────────────────────────────────────────────────────────────┐
│  Browser (web/index.html + css + js, embedded in the binary)        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ REST + fetch polling
┌──────────────────────────────┴──────────────────────────────────────┐
│  Actix-web (main.rs)                                                │
│   ├── api.rs           handlers: hosts, topology, members, scans    │
│   ├── api_export.rs    JSON / XML / TXT exporters                   │
│   └── served via rust-embed (no filesystem dependency at runtime)   │
└───────────────┬──────────────────────────────────────┬──────────────┘
                │                                      │
     ┌──────────┴──────────────────┐    ┌──────────────┴──────────────┐
     │ db.rs                       │    │ scanner.rs                   │
     │ ┌─────────────────────────┐ │    │ ┌──────────────────────────┐ │
     │ │ SQLite (sqlx)           │ │    │ │ ScanManager              │ │
     │ │  networks               │ │    │ │  active_scans: HashMap   │ │
     │ │  hosts (+ status)       │ │    │ │  cancel_flags: HashMap   │ │
     │ │  ports                  │ │    │ └──────────────────────────┘ │
     │ │  script_results         │ │    │                              │
     │ │  team_members           │ │    │ nmap / masscan subprocesses  │
     │ │  assignments            │ │    │ via tokio::process           │
     │ │  host_notes             │ │    │                              │
     │ │  blame_log              │ │    │ Live stderr parsing:         │
     │ │  scans                  │ │    │   (\d+(?:\.\d+)?)% done      │
     │ └─────────────────────────┘ │    │   Discovered open port …     │
     └─────────────────────────────┘    └──────────────────────────────┘
                                                        │
                                                        ▼
                                          nmap_parser.rs auto-imports
                                          each phase's XML into the DB
```

## Modules (src/)

| File | Lines | Responsibility |
|---|---:|---|
| `main.rs` | ~115 | CLI (`clap`), Actix-web server, `rust_embed` asset serving with no-cache headers |
| `models.rs` | ~250 | All serde / sqlx types. Request DTOs, response wrappers like `HostFull` / `HostWithPorts` / `ActiveScan` |
| `db.rs` | ~830 | Migrations (CREATE TABLE + ALTER TABLE for `investigation_status`), CRUD, auto-generated-icon pool for new team members |
| `nmap_parser.rs` | ~400 | `quick-xml` streaming event parser. Handles the `Event::Start`/`Event::Empty` DTD gotcha where `<status/>`, `<address/>`, `<state/>` are usually empty self-closing elements. Upsert semantics across re-imports. |
| `scanner.rs` | ~830 | `ScanManager`, pipeline, child-process lifecycle, cancellation (`AtomicBool` + `tokio::select!`), stderr parsing for progress + discovered-port lines, auto-ingest hook after each phase |
| `api.rs` | ~525 | REST handlers mapped to actix routes. Validates payloads, writes blame entries, serializes DTOs |
| `api_export.rs` | ~455 | JSON (serde) + XML (manual escaping with CDATA for note bodies and script output) + plain-text rendering of the full DB or notes-only |

Zero `unsafe`, zero compiler warnings.

## DB schema

Nine tables, five foreign-key relationships. All timestamps are RFC3339 strings
(SQLite doesn't have a native datetime).

```sql
networks(id, cidr UNIQUE, name?, description?, created_at)

hosts(id, ip_address UNIQUE, hostname?, mac_address?, vendor?,
      os?, os_accuracy?, status,
      first_seen, last_seen,
      network_id → networks(id),
      investigation_status NOT NULL DEFAULT 'untouched')
          -- values: untouched | investigating | investigated | compromised

ports(id, host_id → hosts(id), port_number, protocol,
      state, service?, version?, product?, extra_info?,
      first_seen, last_seen,
      UNIQUE(host_id, port_number, protocol))

script_results(id, port_id → ports(id), script_name, output, created_at)

team_members(id, name UNIQUE, icon, created_at)
    -- `icon` is either a short emoji string or a base64 data: URI

assignments(id, member_id → team_members(id),
            host_id → hosts(id),
            port_id? → ports(id),
            assigned_at, released_at?)
    -- released_at IS NULL  ⇔  assignment is currently active

host_notes(id, host_id → hosts(id),
           member_id? → team_members(id),
           note, created_at)

blame_log(id, member_id? → team_members(id),
          action,                -- assigned | unassigned | status_changed | note_added | icon_changed | member_removed
          target_type,           -- host | port | member
          target_id, details?, created_at)

scans(id, scan_type, targets, arguments,
      start_time, end_time?, status, hosts_found)
```

### Deletion semantics

Deleting a team member doesn't drop their history: notes and blame entries
keep rolling by setting `member_id = NULL` (preserves attribution-less
history). Only the `assignments` rows are physically deleted — that column is
`NOT NULL` in SQL and historical assignment records aren't surfaced anywhere.

### Upsert behavior

Re-importing the same scan is idempotent. `upsert_host` and `upsert_port` use
`INSERT … ON CONFLICT DO UPDATE` with `COALESCE(excluded.X, X)` for optional
fields, so a less-detailed re-scan never *removes* information from a more
detailed earlier scan. Investigation status, assignments, and notes aren't
touched by import at all.

## Scanner concurrency model

`ScanManager` owns a `HashMap<String, Arc<RwLock<ScanState>>>` plus a parallel
`HashMap<String, Arc<AtomicBool>>` for cancel flags.

### Launch

```rust
let scan_id = Uuid::new_v4().to_string();
let state  = Arc::new(RwLock::new(ScanState { … }));
let cancel = Arc::new(AtomicBool::new(false));
self.active_scans.insert(scan_id.clone(), state.clone());
self.cancel_flags.insert(scan_id.clone(), cancel.clone());

tokio::spawn(async move {
    let result = execute_scan(state.clone(), config, pool, cancel.clone()).await;
    // Update terminal phase, run auto-ingest for each phase's XML
});

Ok(scan_id)  // returned to the API handler immediately
```

### Pipeline

`execute_scan` is a straight-line state machine. Every phase:

1. Writes `phase` + `phase_percent = 0` into state
2. Runs a nmap/masscan subprocess via `run_cmd`
3. Reads the output XML and auto-imports via `nmap_parser::parse_and_import_nmap_xml`
4. Updates host/port counters from the XML
5. Checks the cancel flag before continuing

The all-port scan and service detection on common ports run concurrently
(`tokio::spawn` + `JoinHandle::await`), overlapping the longest-running phase
with version detection on already-known ports.

### run_cmd — the subprocess primitive

```rust
let mut cmd = Command::new(program);
cmd.args(&args)
    .stdout(Stdio::piped())
    .stderr(Stdio::piped())
    .kill_on_drop(true);     // belt-and-suspenders cleanup

let mut child = cmd.spawn()?;

// Spawn independent readers for stdout and stderr
if let Some(stdout) = child.stdout.take() { … parse_and_record … }
if let Some(stderr) = child.stderr.take() { … parse_and_record … }

// Race wait() against cancel
let status = tokio::select! {
    s = child.wait() => s?,
    _ = wait_for_cancel(cancel.clone()) => {
        let _ = child.kill().await;
        return Err(anyhow!("cancelled"));
    }
};
```

`--stats-every 2s` and `-v` are injected into every nmap invocation. The
stderr reader runs the output through two regexes:

```rust
PCT_RX:   r"(\d+(?:\.\d+)?)% done"               → sets state.phase_percent
DISCO_RX: r"Discovered open port (\d+)/(tcp|udp) on (\S+)"
                                                  → increments ports_discovered,
                                                    adds unique IP to hosts list
```

### Overall progress

Each phase occupies a window of the overall bar:

| Phase | Overall window |
|---|---|
| Initializing | 0 → 2% |
| HostDiscovery | 2 → 15% |
| CommonPortScan | 15 → 30% |
| AllPortScan | 30 → 75% |
| ServiceDetection | 75 → 90% |
| ScriptScan | 90 → 100% |

`overall_for(phase, phase_pct) = start + weight * phase_pct / 100`.

### Log buffer

Every captured line is appended to `state.logs` (also kept with a 5000-line
cap — scans typically produce a few hundred lines, this is a cheap
defense against runaway logs). The frontend polls
`/api/scans/:id/logs?since=N` and appends only new lines, keeping its own
cursor.

## Frontend organization (`web/js/app.js`)

One file, ~900 lines, no bundler, no transpilation. Mental model:

```
Boot (DOMContentLoaded)
    initSidebar()      ← desktop collapse + mobile overlay + nav wiring
    initTheme()        ← reads ph-theme from localStorage
    initScanner()      ← form bindings
    initImport()       ← textarea/file input
    initModal()        ← host-detail modal close handlers
    initTeam()         ← add-members form, file upload
    initIconPicker()   ← grid + custom emoji + file upload
    │
    ↓
    refreshMembers(), restoreCurrentUser()
    refreshTopology(), refreshHosts(), refreshBlame()
    refreshActiveScans() → startActiveScanPolling() (2s interval)
```

Each view has an idempotent `refreshX()` function that `fetchJSON` + rerenders
its DOM. Cross-view propagation (e.g. after an icon change) is just:

```js
await refreshMembers();
await refreshTopology();
await refreshHosts();
await refreshBlame();
```

### Icon rendering

A universal `renderIcon(icon)` helper returns:
- The raw emoji text, if the icon is a short string
- `<img src="…">`, if the icon starts with `data:image/` or `http(s)://`

`<option>` elements can't contain `<img>`, so the "You" dropdown uses the
image-placeholder `🖼` text instead.

### OS classification

Done entirely client-side so the backend doesn't have to care. See
`classifyOS(host)` in `app.js`. Three-tier logic:

1. **OS fingerprint string match** (regex over `host.os`)
2. **Port / service heuristics** when no OS fingerprint:
   - 445 / 135 / 3389 open ⇒ Windows
   - Service names containing `microsoft` / `iis` / `netbios` / `smb` ⇒ Windows
   - OpenSSH / Apache / nginx / postfix / vsftpd / bind / etc. ⇒ Linux
   - Port 22 ⇒ Linux (fallback)
3. **Unknown** → "Other"

BSD and macOS are intentionally bucketed as Linux (per the original spec).

## Build / embed

```toml
[dependencies]
actix-web = "4.4"
rust-embed = "8"
tokio = { version = "1.35", features = ["full"] }
sqlx = { version = "0.7", features = ["runtime-tokio-native-tls", "sqlite", "chrono"] }
quick-xml = "0.31"
regex = "1.10"
once_cell = "1.19"
# … etc.
```

Release profile uses LTO + single codegen unit; the binary is ~8 MB stripped,
~10 MB with symbols. Startup is one `connect` call to SQLite plus binding a
TCP socket — well under 100ms.

Google Fonts are loaded from the CDN with `font-display: swap`, so there's no
blocking network dependency; if the Kali box is offline, the fallback stacks
(Georgia / Menlo / SF Mono) take over.

## Tests

Seven integration suites totalling 589 assertions. Everything runs against a
real release binary with a disposable `/tmp` database (`tests/run_all.sh`):

```
backend.sh   139  API shape, DB upsert, scan launch, 404s
frontend.sh   67  JSON contracts the UI depends on (flat shapes, no nested .host / .port)
os.sh         68  OS classifier regex coverage + sample-scan outcomes
team.sh      129  Members CRUD, assignments, status, notes, blame, exports
scan.sh       76  Active-scan lifecycle: logs, cancel, progress fields
ui.sh         58  Fonts loaded, sidebar collapse, theme toggle
icon.sh       52  Picker UI, propagation, backend icon endpoint, cropped-logo serving
```

See [`EXAMPLES.md`](EXAMPLES.md) for operator playbooks.
