# Operator playbook

Common workflows against a running Port Herald instance.

## 1. Fresh engagement — bootstrap

```bash
# Build + launch
./port-herald build
./port-herald start --bind 0.0.0.0 --port 8080

# Add teammates (from the sidebar footer dropdown, click yourself afterwards
# to set the "You" selector)
curl -X POST http://localhost:8080/api/members \
    -H "Content-Type: application/json" \
    -d '{"names": "Alice\nBob\nCharlie\nDana"}'
```

The server auto-creates `~/.port-herald/port-herald.db` on first run.

## 2. Ingest existing Nmap XML

```bash
# From a shell session
nmap -A -oX scope.xml 10.0.0.0/24

# Pipe it in via curl
curl -X POST http://localhost:8080/api/import \
    -H "Content-Type: application/json" \
    -d "$(jq -Rs '{xml: .}' scope.xml)"
```

Or just paste into the **Import** tab. Re-importing the same file is safe —
hosts, ports, and scripts are upserted and nothing gets duplicated.

## 3. Launch a progressive scan

Via the UI: **Scanner** tab → fill in targets → **Launch Scan** → the UI
automatically redirects you to **Active Scans**.

Via the API:

```bash
curl -X POST http://localhost:8080/api/scans \
    -H "Content-Type: application/json" \
    -d '{
        "targets":          ["10.0.0.0/24"],
        "excluded_targets": ["10.0.0.1"],
        "scan_type":        "syn",
        "timing_template":  "Aggressive",
        "version_detection": true,
        "os_detection":     true,
        "script_scan":      true,
        "udp_scan":         false,
        "evasion_enabled":  false,
        "source_port":      null,
        "dns_servers":      [],
        "max_rate":         null
    }'
# → {"scan_id": "a1b2c3d4-…", "status": "started"}
```

The scan runs in the background; its XML output is auto-imported after each
phase, so the Topology/Hosts tabs fill in progressively while it runs.

## 4. Stealth / evasion profile

```json
{
    "targets": ["10.0.0.0/22"],
    "scan_type": "syn",
    "timing_template": "Sneaky",
    "evasion_enabled": true,
    "source_port": 53,
    "dns_servers": ["1.1.1.1", "8.8.8.8"],
    "max_rate": 100,
    "udp_scan": false,
    "version_detection": true,
    "os_detection": false,
    "script_scan": false
}
```

What this does:

- `-T1` (one packet every 15s)
- `--source-port 53` so filtered firewalls might let traffic back in via
  rules allowing DNS responses
- `-f` fragments every TCP packet (auto-applied when `evasion_enabled`)
- Custom resolvers so reverse-DNS doesn't go through the target's logged DNS
- `--max-rate 100` keeps aggregate throughput low

## 5. Monitor + cancel active scans

```bash
# Active scans
curl -s http://localhost:8080/api/scans/active | jq '.[] | {
    short_id, phase_label, overall_percent, hosts_discovered, ports_discovered
}'

# Stream a specific scan's logs (offset-based pagination)
curl -s "http://localhost:8080/api/scans/<scan_id>/logs?since=0" | jq .

# Cancel
curl -X POST http://localhost:8080/api/scans/<scan_id>/cancel
```

The UI's Active Scans tab does all of this automatically with a 2-second poll.

## 6. Team coordination patterns

### Claim a host before anyone else does

```bash
MEMBER_ID=1
HOST_ID=42
PORT_ID=$(curl -s http://localhost:8080/api/hosts/$HOST_ID \
          | jq '.ports[] | select(.port_number==22) | .id')

# Pin yourself to port 22 of host 42
curl -X POST http://localhost:8080/api/hosts/$HOST_ID/assign \
    -H "Content-Type: application/json" \
    -d "{\"member_id\": $MEMBER_ID, \"port_id\": $PORT_ID}"
```

In the UI: open the host modal, click **Assign me**, pick a focus port.

### Mark a host as compromised

```bash
curl -X PUT http://localhost:8080/api/hosts/$HOST_ID/status \
    -H "Content-Type: application/json" \
    -d "{\"member_id\": $MEMBER_ID, \"status\": \"compromised\"}"
```

Status values: `untouched | investigating | investigated | compromised`.
The badge color propagates to every view (topology card, host list, modal).

### Add a timestamped note

```bash
curl -X POST http://localhost:8080/api/hosts/$HOST_ID/notes \
    -H "Content-Type: application/json" \
    -d '{"member_id": 1, "note": "root via CVE-2024-XXXX, exfil via /tmp/.X11"}'
```

## 7. Query the DB directly

The sqlite file is just a sqlite file. Query it live from another terminal:

```bash
sqlite3 ~/.port-herald/port-herald.db <<SQL
.mode column
.headers on

-- Who's assigned to what, right now?
SELECT m.icon, m.name, h.ip_address, p.port_number, a.assigned_at
FROM assignments a
JOIN team_members m ON a.member_id = m.id
JOIN hosts h ON a.host_id = h.id
LEFT JOIN ports p ON a.port_id = p.id
WHERE a.released_at IS NULL
ORDER BY a.assigned_at DESC;

-- Compromised hosts
SELECT ip_address, hostname, os, investigation_status
FROM hosts
WHERE investigation_status = 'compromised';
SQL
```

Or use the bundled helper:

```bash
./port-herald stats
./port-herald find-port 445
./port-herald find-service ssh
./port-herald networks
./port-herald export-hosts hosts.csv
./port-herald export-ports open-ports.csv
```

## 8. End-of-engagement artefacts

```bash
# Full snapshot — pick whichever format you need
curl -so engagement.json http://localhost:8080/api/export/json
curl -so engagement.xml  http://localhost:8080/api/export/xml
curl -so engagement.txt  http://localhost:8080/api/export/txt

# Just the notes
curl -so notes.txt       http://localhost:8080/api/notes/export/txt
```

Full exports include: networks, hosts (with investigation status), ports,
scripts, members, active assignments, every note, the full blame log, and
all scan metadata. The TXT variant is console-friendly and great for
dropping into a report appendix.

## 9. Custom member icons

Three ways to set a member icon:

1. **Click the avatar in the Team tab** → pick from the emoji grid, type a
   custom emoji, or upload a PNG/SVG (max 50 KB, cover-cropped to 128×128).
2. **API with an emoji**:
   ```bash
   curl -X PUT http://localhost:8080/api/members/1/icon \
       -H "Content-Type: application/json" \
       -d '{"icon": "🥷"}'
   ```
3. **API with an image file**:
   ```bash
   DATA_URI=$(base64 -w0 ninja.png | awk '{print "data:image/png;base64," $0}')
   curl -X PUT http://localhost:8080/api/members/1/icon \
       -H "Content-Type: application/json" \
       -d "{\"icon\": \"$DATA_URI\"}"
   ```

Icons propagate everywhere: team roster avatars, topology host cards (member
stack), host-list cards (team row chips), host detail modal, blame log
entries, and all notes authored by that member.

## 10. Running tests

```bash
./port-herald test              # all 589 assertions, ~30s on a decent laptop
./port-herald test scan         # just one suite
./port-herald test team
./port-herald test ui
```

If you're hacking on the project, this is the quickest way to catch
regressions — every suite spins up a release binary against `/tmp/port-herald_test.db`
and tears it down on exit.
