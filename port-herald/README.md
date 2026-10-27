# Port Herald

**Network reconnaissance and team-collaboration platform.** Port Herald ingests
Nmap scan results, visualises network topology, orchestrates multi-phase
reconnaissance pipelines, and lets a team coordinate who is working on which
host and port in real time.

| Area | What's inside |
|---|---|
| **Discovery** | Live Nmap/Masscan pipeline with cancellation + auto-import |
| **Visualisation** | Topology grouped by CIDR, sub-grouped by OS (Linux / Windows / other) |
| **Collaboration** | Team members with icons, assignments, blame log, notes, investigation status |
| **Export** | Full-database and notes-only exports as JSON, XML, or TXT |
| **Deployment** | Single self-contained binary; web UI embedded at compile time |

The entire backend is a single ~8 MB Rust binary. The web UI (HTML / CSS / JS,
no build step) is embedded via `rust-embed`, so you can `scp` the binary to a
Kali box and run it with no further setup beyond the DB file.

---

## Quick start

```bash
# One-time build
cargo build --release

# Run (defaults to port 8080, DB in CWD)
./target/release/port-herald

# Or use the wrapper (recommended)
./port-herald start                             # defaults
./port-herald start --bind 0.0.0.0 --port 9000  # expose
```

Open <http://127.0.0.1:8080> and you're in.

The wrapper also provides:

```bash
./port-herald build
./port-herald test                 # run every test suite
./port-herald test backend         # run one suite
./port-herald stats
./port-herald find-port 22
./port-herald find-service http
./port-herald export-hosts hosts.csv
```

## The web UI

Six tabs in the left sidebar (collapsible via the hamburger inside the sidebar
header):

| Tab | Purpose |
|---|---|
| **Topology** | Hosts grouped by `/24`, sub-grouped by Linux / Windows / Other. Member icons appear on each host card showing who's assigned. Click a host to open its detail modal in the Hosts tab. |
| **Hosts** | Searchable, flat list of every discovered host with status, OS, open-port count, investigation status, and the member chips (icon + name + focused port). |
| **Team** | Add members (one-per-line textarea or `.txt` upload). Each gets an auto-assigned emoji icon that can be changed by clicking the avatar. Shows per-member active assignments and the global blame log. |
| **Scanner** | Launch a scan pipeline with all the knobs: scan type, timing, evasion, UDP, source port, DNS servers, max packet rate, target exclusions. Launching redirects to Active Scans. |
| **Active Scans** | Live-updating list of every running scan with: scan hash (first 8 chars of UUID), stage + percentage of current phase + overall percentage, hosts/ports discovered, elapsed time, cancel button, and a scrolling console pane of the subprocess output (color-coded, auto-scroll). |
| **Import** | Paste any Nmap `-oX` XML output or upload a `.xml` file to ingest. Upsert semantics: re-importing updates existing rows without duplicating. |
| **Export** | Download the entire database (or just notes) as JSON / XML / TXT. |

## Theming

Dark / light mode toggle in the sidebar footer. Three Google Fonts:

- **Quattrocento** — body text, headings
- **IBM Plex Mono** — labels, chips, badges, pill tags
- **JetBrains Mono** — scan console, script output, IP addresses, port numbers,
  scan hashes, textareas

Primary / secondary / text colors follow the spec you'd expect from a security
dashboard: `#0E6DCC` primary, `#A1AAB5` / `#4B4F54` secondary, `#292929` /
`#D4D4D6` text.

## Scanner pipeline

A single scan progresses through six phases. The server kicks off `nmap`
(or `masscan` when available) subprocesses, parses stderr for `--stats-every`
output to drive the progress bar, and automatically imports each phase's XML
into the DB as soon as that phase completes.

```
HostDiscovery  (0–15%)   masscan if present, else nmap -sn
    ↓
CommonPortScan (15–30%)  nmap --top-ports 1000 <scan_type>
    ↓
AllPortScan    (30–75%)  nmap -p-   ──┐
                                       │ (parallel)
ServiceDetection, pass 1 (75–90%)      │ nmap -sV against the common-port file
                                       │
Final ServiceDetection on new ports ───┘
    ↓
ScriptScan     (90–100%) — only if the config enables NSE scripts
```

Cancellation is a `tokio::select!` between `child.wait()` and an
`Arc<AtomicBool>`; killing a scan immediately SIGKILLs the running nmap/masscan
subprocess.

## Team workflow

1. **Pick who you are** — the "You" dropdown in the sidebar footer persists to
   `localStorage` under `ph-current-user`.
2. **Open any host** → the host-detail modal has a Team panel at the top with
   an **Assign me** / **Unassign me** button and an optional "focus port"
   dropdown.
3. **Investigation status** — four buttons at the top of the modal: Untouched,
   Investigating, Investigated, Compromised. Color-coded badges propagate
   back to the topology and host-list views.
4. **Notes** — a free-form text area at the bottom of the modal. Every note is
   attributed to the current user (or anonymous) and timestamped. Notes
   persist across re-imports.
5. **Blame log** — every assign / unassign / status change / note creation
   writes an entry to the Team tab's blame log. Filterable per member.

## Exports

| Endpoint | Format | What's included |
|---|---|---|
| `GET /api/export/json` | JSON | Full DB (networks, hosts, ports, scripts, members, assignments, notes, blame log, scans) with embedded relations |
| `GET /api/export/xml` | XML | Same, as a well-formed `<port-herald_export>` tree with CDATA for note bodies and script output |
| `GET /api/export/txt` | TXT | Human-readable, console-friendly dump |
| `GET /api/notes/export/{json,xml,txt}` | — | Just notes, with host + author context |

All six endpoints emit a `Content-Disposition: attachment` header so browsers
offer them as downloads.

## HTTP API summary

```
# Hosts
GET    /api/hosts
GET    /api/hosts/:id
POST   /api/hosts/:id/assign
POST   /api/hosts/:id/unassign
PUT    /api/hosts/:id/status
GET    /api/hosts/:id/notes
POST   /api/hosts/:id/notes

# Topology / network
GET    /api/networks
GET    /api/topology

# Team
GET    /api/members
POST   /api/members                   # body: {"names": "Alice\nBob\nCharlie"}
DELETE /api/members/:id
PUT    /api/members/:id/icon          # body: {"icon": "🦊"} or a data: URI
GET    /api/members/:id/assignments
GET    /api/members/:id/blame?limit=N
GET    /api/blame?limit=N

# Scans
POST   /api/scans                     # launch
GET    /api/scans                     # recent scans from the DB
GET    /api/scans/active              # live active-scan DTOs
GET    /api/scans/:id/status
GET    /api/scans/:id/logs?since=N
POST   /api/scans/:id/cancel

# Import / export
POST   /api/import                    # body: {"xml": "<nmaprun>…"}
GET    /api/export/{json|xml|txt}
GET    /api/notes/export/{json|xml|txt}
```

## Project layout

```
port-herald/
├── Cargo.toml
├── README.md              This file
├── ARCHITECTURE.md        Technical deep-dive (modules, data flow, DB schema)
├── EXAMPLES.md            Operator playbook (common scanning patterns, API curl recipes)
├── port-herald            Convenience wrapper (./port-herald help)
├── install.sh             Kali-targeted installer
├── .gitignore
│
├── src/                   Rust source (~3,400 lines, 6 modules)
│   ├── main.rs            Actix-web server + rust-embed asset serving
│   ├── api.rs             REST handlers
│   ├── api_export.rs      JSON/XML/TXT renderers
│   ├── db.rs              SQLite migrations + CRUD
│   ├── models.rs          Serde / sqlx data types
│   ├── nmap_parser.rs     quick-xml streaming parser for Nmap -oX
│   └── scanner.rs         ScanManager, pipeline, child-process orchestration
│
├── web/                   Embedded into the binary at compile time
│   ├── index.html
│   ├── css/style.css
│   ├── js/app.js
│   ├── img/               Logo variants
│   └── favicon-*.png etc.
│
├── scripts/
│   ├── gen_favicons.py        Generate favicons + cropped logos from source PNGs
│   └── port-herald-helper.py  Standalone DB inspector (stats, CSV export, port/service lookup)
│
└── tests/                 Integration test suites (698 assertions, 9 suites)
    ├── run_all.sh         Master runner (./port-herald test)
    ├── backend.sh         API, DB upserts, scan launch, 139 tests
    ├── frontend.sh        JSON shapes consumed by the UI, 67 tests
    ├── os.sh              OS classifier regexes + sample-scan outcomes, 68 tests
    ├── team.sh            Members, assignments, status, notes, exports, 129 tests
    ├── scan.sh            Live scan lifecycle + DB persistence, 90 tests
    ├── ui.sh              Fonts loaded, collapsible-sidebar wiring, theme toggle, 58 tests
    ├── icon.sh            Icon picker + cropped-logo serving + icon propagation, 52 tests
    ├── delete.sh          Host-delete button + modal confirm + cascade behavior, 41 tests
    ├── import.sh          Multi-file Nmap XML import + merge + OS inference, 54 tests
    └── fixtures/
        └── sample-scan.xml  8-host nmap -A fixture used across the suites
```

## Running the tests

```bash
./port-herald test                 # all suites (698 tests)
./port-herald test backend         # one suite
./port-herald test scan
```

The master runner spins up a release build against a disposable DB in `/tmp`,
curls each suite, aggregates results, and tears everything down on exit.

## Deployment notes

- The web assets are embedded at compile time via `rust-embed`. Changing
  anything in `web/` requires a rebuild.
- The DB file is a single SQLite file. Point `--database` at a persistent
  path (e.g. `/var/lib/port-herald/db.sqlite`) in production.
- Favicons and logo PNGs are regenerated by `scripts/gen_favicons.py` from
  the originals in `web/img/logo-*.png`. Re-run that if you ever swap the
  source logo.
- The server listens on `127.0.0.1:8080` by default. Expose with
  `--bind 0.0.0.0` behind a reverse proxy; the API has no built-in auth.

## See also

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — module-by-module internals, DB
  schema, scanner concurrency model.
- [`EXAMPLES.md`](EXAMPLES.md) — concrete scanning workflows, scope exclusions,
  stealth tuning, API curl recipes.
