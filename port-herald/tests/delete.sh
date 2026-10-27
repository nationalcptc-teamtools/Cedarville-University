#!/bin/bash
# Host deletion tests
set -eu
BASE="http://localhost:9999"
PASS=0; FAIL=0; TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1: $2"; }
assert_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi; }
assert_contains() {
    local tmp; tmp=$(mktemp); printf '%s' "$3" > "$tmp"
    if grep -q -- "$2" "$tmp"; then pass "$1"; else fail "$1" "missing '$2'"; fi
    rm -f "$tmp"
}
assert_gt() { if [ "$3" -gt "$2" ] 2>/dev/null; then pass "$1"; else fail "$1" "expected > $2, got '$3'"; fi; }

cd "$(dirname "$0")/.."

echo "============================================"
echo "  HOST DELETION TESTS"
echo "============================================"
echo ""

# Fresh state: wipe members from any prior run
while true; do
    IDS=$(curl -sf "$BASE/api/members" 2>/dev/null | jq -r '.[].id' 2>/dev/null)
    [ -z "$IDS" ] && break
    for mid in $IDS; do curl -s -X DELETE "$BASE/api/members/$mid" >/dev/null; done
done

# Seed with the fixture
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' tests/fixtures/sample-scan.xml)" > /dev/null

echo "1. ENDPOINT SHAPE"
echo "──────────────────────────────────────────"

# Non-existent host → 404
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE/api/hosts/99999")
assert_eq "Missing host → 404" "404" "$HTTP"

# Non-numeric id → 4xx
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE/api/hosts/not-an-id")
assert_contains "Bad id → 4xx" "4" "$HTTP"

echo ""
echo "2. FULL CASCADE DELETE"
echo "──────────────────────────────────────────"

# Pick a host, attach a member, assignment, note
curl -sf -X POST "$BASE/api/members" -H "Content-Type: application/json" \
    -d '{"names":"DeleteTester"}' > /dev/null
MID=$(curl -sf "$BASE/api/members" | jq '.[0].id')

TARGET_IP="204.152.191.37"   # kernel.org — has lots of ports in the fixture
HID=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"$TARGET_IP\") | .id")

# Attach everything
curl -sf -X POST "$BASE/api/hosts/$HID/assign" -H "Content-Type: application/json" \
    -d "{\"member_id\": $MID}" > /dev/null
curl -sf -X PUT "$BASE/api/hosts/$HID/status" -H "Content-Type: application/json" \
    -d "{\"member_id\": $MID, \"status\": \"compromised\"}" > /dev/null
curl -sf -X POST "$BASE/api/hosts/$HID/notes" -H "Content-Type: application/json" \
    -d "{\"member_id\": $MID, \"note\": \"doomed\"}" > /dev/null

# Count before
PORTS_BEFORE=$(curl -sf "$BASE/api/hosts/$HID" | jq '.ports | length')
assert_gt "Host has >=5 ports before delete" 4 "$PORTS_BEFORE"

HOSTS_BEFORE=$(curl -sf "$BASE/api/hosts" | jq 'length')
NOTES_BEFORE=$(curl -sf "$BASE/api/hosts/$HID/notes" | jq 'length')
assert_gt "At least one note is on the host" 0 "$NOTES_BEFORE"

# Delete
R=$(curl -sf -X DELETE "$BASE/api/hosts/$HID?member_id=$MID")
assert_eq "Delete status=deleted" "deleted" "$(echo "$R" | jq -r '.status')"
assert_eq "Response echoes ip_address" "$TARGET_IP" "$(echo "$R" | jq -r '.ip_address')"

# Host gone
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/hosts/$HID")
assert_eq "GET deleted host → 404" "404" "$HTTP"

# Host count dropped by exactly one
HOSTS_AFTER=$(curl -sf "$BASE/api/hosts" | jq 'length')
assert_eq "Host list shrank by 1" "$((HOSTS_BEFORE - 1))" "$HOSTS_AFTER"

# Not in topology
IN_TOPO=$(curl -sf "$BASE/api/topology" | jq "[.hosts[] | select(.id==$HID)] | length")
assert_eq "Topology no longer shows it" "0" "$IN_TOPO"

echo ""
echo "3. CHILDREN CASCADED"
echo "──────────────────────────────────────────"

# Check SQLite directly
PORTS_AFTER=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports WHERE host_id=$HID;")
SCRIPTS_AFTER=$(sqlite3 /tmp/port-herald_test.db \
    "SELECT COUNT(*) FROM script_results WHERE port_id NOT IN (SELECT id FROM ports);")
NOTES_IN_DB=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM host_notes WHERE host_id=$HID;")
ASSIGNS_IN_DB=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM assignments WHERE host_id=$HID;")

assert_eq "No orphaned ports" "0" "$PORTS_AFTER"
assert_eq "No orphaned script_results" "0" "$SCRIPTS_AFTER"
assert_eq "No orphaned notes" "0" "$NOTES_IN_DB"
assert_eq "No orphaned assignments" "0" "$ASSIGNS_IN_DB"

echo ""
echo "4. BLAME LOG PRESERVED"
echo "──────────────────────────────────────────"

# host_removed entry recorded
REMOVED=$(curl -sf "$BASE/api/blame?limit=10" | jq '[.[] | select(.action=="host_removed")] | length')
assert_gt "Blame log has host_removed entry" 0 "$REMOVED"

ENTRY=$(curl -sf "$BASE/api/blame?limit=10" | jq ".[] | select(.action==\"host_removed\" and .target_id==$HID)")
assert_eq "Entry attributes to DeleteTester" "DeleteTester" "$(echo "$ENTRY" | jq -r '.member_name')"
assert_eq "Entry details preserves IP"       "$TARGET_IP"    "$(echo "$ENTRY" | jq -r '.details')"
# target_label will be null (host doesn't exist anymore — LEFT JOIN resolves to NULL)
assert_eq "Entry target_label is null"       "null"          "$(echo "$ENTRY" | jq -r '.target_label')"

# The older blame entries for this host (assigned, status_changed, note_added) also persist
PRIOR=$(curl -sf "$BASE/api/blame?limit=50" | jq "[.[] | select(.target_id==$HID)] | length")
assert_gt "All blame entries for this host remain visible" 2 "$PRIOR"

echo ""
echo "5. OTHER HOSTS UNTOUCHED"
echo "──────────────────────────────────────────"

# Pick another host in the fixture; it should be unaffected
NEIGHBOR_IP="66.35.250.168"   # freshmeat.net
NEIGHBOR=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"$NEIGHBOR_IP\")")
assert_eq "Neighbor still exists" "$NEIGHBOR_IP" "$(echo "$NEIGHBOR" | jq -r '.ip_address')"

NEIGHBOR_PORTS=$(curl -sf "$BASE/api/hosts/$(echo "$NEIGHBOR" | jq .id)" | jq '.ports | length')
assert_gt "Neighbor still has ports" 0 "$NEIGHBOR_PORTS"

echo ""
echo "6. RE-IMPORT RESTORES THE HOST"
echo "──────────────────────────────────────────"

# After deletion, re-importing the fixture should bring the host back
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' tests/fixtures/sample-scan.xml)" > /dev/null

RESTORED=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"$TARGET_IP\")")
assert_eq "Host restored by re-import" "$TARGET_IP" "$(echo "$RESTORED" | jq -r '.ip_address')"

# But investigation_status starts fresh (default 'untouched')
RESTORED_STATUS=$(echo "$RESTORED" | jq -r '.investigation_status')
assert_eq "Restored host has fresh status" "untouched" "$RESTORED_STATUS"

# And notes / assignments start fresh (previous ones were deleted)
RID=$(echo "$RESTORED" | jq -r '.id')
NEW_NOTES=$(curl -sf "$BASE/api/hosts/$RID/notes" | jq 'length')
assert_eq "Restored host has 0 notes" "0" "$NEW_NOTES"

echo ""
echo "6b. REGRESSION: delete with a port-focused assignment"
echo "──────────────────────────────────────────"
#
# Previously `delete_host` tried to DELETE FROM ports before DELETE FROM
# assignments. If an assignment had `port_id` set (focused on a specific
# port, not just the host), SQLite blocked the port delete with FK code 787
# because assignments.port_id → ports(id). The tests above always assigned
# with port_id=NULL and so missed it. This case explicitly covers it.

# Need a port on the restored host
FOCUS_PORT_ID=$(curl -sf "$BASE/api/hosts/$RID" | jq '.ports[0].id')
assert_gt "Restored host has a port to focus on" 0 "$FOCUS_PORT_ID"

# Assign to that specific port
curl -sf -X POST "$BASE/api/hosts/$RID/assign" -H "Content-Type: application/json" \
    -d "{\"member_id\": $MID, \"port_id\": $FOCUS_PORT_ID}" > /dev/null

# Confirm the assignment carries port_id
AS_WITH_PORT=$(sqlite3 /tmp/port-herald_test.db \
    "SELECT COUNT(*) FROM assignments WHERE host_id=$RID AND port_id=$FOCUS_PORT_ID;")
assert_eq "Assignment row has port_id set" "1" "$AS_WITH_PORT"

# Now the critical bit: delete must succeed
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE/api/hosts/$RID?member_id=$MID")
assert_eq "Delete returns 200 even with port-focused assignment" "200" "$HTTP"

# Verify everything cascaded
assert_eq "No port rows left for deleted host" "0" \
    "$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports WHERE host_id=$RID;")"
assert_eq "No assignment rows left for deleted host" "0" \
    "$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM assignments WHERE host_id=$RID;")"
assert_eq "No orphaned assignment port_id references" "0" \
    "$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM assignments WHERE port_id IS NOT NULL AND port_id NOT IN (SELECT id FROM ports);")"

echo ""
echo "7. FRONTEND WIRING"
echo "──────────────────────────────────────────"

HTML=$(curl -sf "$BASE/")
CSS=$(curl -sf "$BASE/css/style.css")
JS=$(curl -sf "$BASE/js/app.js")

assert_contains "JS defines deleteHost()"               "function deleteHost"              "$JS"
assert_contains "JS exposes window.deleteHost"          "window.deleteHost ="              "$JS"
assert_contains "JS confirms before deleting"           "confirm("                         "$JS"
assert_contains "JS uses DELETE verb"                   "method: 'DELETE'"                 "$JS"
assert_contains "JS attaches member_id for blame"       "member_id="                       "$JS"
assert_contains "JS refreshes topology after delete"    "refreshTopology"                  "$JS"
assert_contains "JS refreshes hosts after delete"       "refreshHosts"                     "$JS"
assert_contains "JS refreshes blame after delete"       "refreshBlame"                     "$JS"
assert_contains "JS has per-row delete button class"    "host-delete-btn"                  "$JS"
assert_contains "JS renders trash SVG"                  "polyline points=\"3 6 5 6 21 6\"" "$JS"
assert_contains "JS stops propagation to card click"    "event.stopPropagation"            "$JS"
assert_contains "JS has modal danger zone"              "danger-zone"                      "$JS"
assert_contains "JS wires data-action delete-host"      'data-action=\"delete-host\"'      "$JS"

assert_contains "CSS styles .host-delete-btn"           ".host-delete-btn"                 "$CSS"
assert_contains "CSS hides button until hover"          "opacity: 0;"                      "$CSS"
assert_contains "CSS reveals on card hover"             ".host-card:hover .host-delete-btn" "$CSS"
assert_contains "CSS styles .danger-zone"               ".danger-zone"                     "$CSS"
assert_contains "CSS has .btn-danger"                   ".btn-danger"                      "$CSS"

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then echo "  ⚠️  Some tests failed!"; exit 1
else echo "  🎉 ALL HOST DELETE TESTS PASSED!"; exit 0; fi
