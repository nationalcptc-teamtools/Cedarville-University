#!/bin/bash
# Team/assignment/notes/export test suite
set -eu
BASE="http://localhost:9999"
PASS=0; FAIL=0; TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1: $2"; }
assert_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi; }
assert_contains() {
    # Write to a temp file so SIGPIPE doesn't trip us when $3 is huge
    local tmp
    tmp=$(mktemp)
    printf '%s' "$3" > "$tmp"
    if grep -q -- "$2" "$tmp"; then pass "$1"
    else fail "$1" "missing '$2'"; fi
    rm -f "$tmp"
}
assert_gt() { if [ "$3" -gt "$2" ] 2>/dev/null; then pass "$1"; else fail "$1" "expected > $2, got '$3'"; fi; }

echo "============================================"
echo "  TEAM / ASSIGNMENTS / NOTES / EXPORT TESTS"
echo "============================================"
echo ""

# ─── Fresh state (clean members from any previous run) ───
# Delete each member individually. We don't own the DB file so we go through the API.
while true; do
  IDS=$(curl -sf "$BASE/api/members" 2>/dev/null | jq -r '.[].id' 2>/dev/null)
  [ -z "$IDS" ] && break
  for mid in $IDS; do
    curl -s -X DELETE "$BASE/api/members/$mid" > /dev/null
  done
done

# Also drop any accumulated notes from prior runs via direct DB (if we're
# running locally with a known test DB path). This keeps counts deterministic.
if [ -f "/tmp/port-herald_test.db" ]; then
    sqlite3 /tmp/port-herald_test.db "DELETE FROM host_notes; DELETE FROM blame_log;" 2>/dev/null || true
fi

# ─── Fresh import ───
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
  -d "$(jq -Rs '{"xml": .}' tests/fixtures/sample-scan.xml)" > /dev/null

echo "1. MEMBER MANAGEMENT"
echo "────────────────────────────────────────────"

# Empty initially (now guaranteed)
INITIAL=$(curl -sf "$BASE/api/members" | jq 'length')
echo "  (initial member count: $INITIAL)"
assert_eq "Clean member slate" "0" "$INITIAL"

# Bulk add via newline-separated
R=$(curl -sf -X POST "$BASE/api/members" -H "Content-Type: application/json" \
  -d '{"names":"Alice\nBob\nCharlie\nDana"}')
assert_eq "Bulk add returns 4 added" "4" "$(echo "$R" | jq '.added')"

# Verify each has an icon
ICON_COUNT=$(echo "$R" | jq '[.members[] | select(.icon != "" and .icon != null)] | length')
assert_eq "All 4 members got icons" "4" "$ICON_COUNT"

# Verify icons are distinct (first 4 members should get different icons)
UNIQUE_ICONS=$(echo "$R" | jq '[.members[].icon] | unique | length')
assert_eq "4 distinct icons assigned" "4" "$UNIQUE_ICONS"

# Comma-separated add
R2=$(curl -sf -X POST "$BASE/api/members" -H "Content-Type: application/json" \
  -d '{"names":"Eve, Frank"}')
assert_eq "Comma-separated add returns 2" "2" "$(echo "$R2" | jq '.added')"

# Duplicate add should be a no-op (name UNIQUE)
R3=$(curl -sf -X POST "$BASE/api/members" -H "Content-Type: application/json" \
  -d '{"names":"Alice"}')
assert_eq "Duplicate add doesn't error" "1" "$(echo "$R3" | jq '.added')"

# List
MEMBERS=$(curl -sf "$BASE/api/members")
assert_gt "Member list has >=6" 5 "$(echo "$MEMBERS" | jq 'length')"

# Member shape
FIRST=$(echo "$MEMBERS" | jq '.[0]')
for FIELD in id name icon created_at; do
    assert_eq "Member has .$FIELD" "true" "$(echo "$FIRST" | jq "has(\"$FIELD\")")"
done

# Delete
ALICE_ID=$(echo "$MEMBERS" | jq '[.[] | select(.name=="Alice")] | .[0].id')
curl -sf -X DELETE "$BASE/api/members/$ALICE_ID" > /dev/null
REMAINING=$(curl -sf "$BASE/api/members" | jq '[.[] | select(.name=="Alice")] | length')
assert_eq "Alice removed from roster" "0" "$REMAINING"

# Re-add Alice for subsequent tests
curl -sf -X POST "$BASE/api/members" -H "Content-Type: application/json" \
  -d '{"names":"Alice"}' > /dev/null
ALICE_ID=$(curl -sf "$BASE/api/members" | jq '.[] | select(.name=="Alice") | .id')

# Add empty names
EMPTY_R=$(curl -s -X POST "$BASE/api/members" -H "Content-Type: application/json" \
  -d '{"names":"\n\n  \n"}' -o /dev/null -w "%{http_code}")
assert_eq "All-blank input returns 400" "400" "$EMPTY_R"

echo ""
echo "2. ASSIGNMENTS"
echo "──────────────────────────────────────────"

# Pick kernel.org (host 4) and its port 22
HOST_ID=$(curl -sf "$BASE/api/hosts" | jq '.[] | select(.ip_address=="204.152.191.37") | .id')
PORT_ID=$(curl -sf "$BASE/api/hosts/$HOST_ID" | jq '.ports[] | select(.port_number==22) | .id')

# Assign Alice without port
R=$(curl -sf -X POST "$BASE/api/hosts/$HOST_ID/assign" -H "Content-Type: application/json" \
  -d "{\"member_id\": $ALICE_ID}")
assert_contains "Assign returns assignment_id" "assignment_id" "$R"

# Verify in host detail
H=$(curl -sf "$BASE/api/hosts/$HOST_ID")
ASSIGNED=$(echo "$H" | jq '[.assignments[] | select(.member_name=="Alice")] | length')
assert_eq "Alice appears in host.assignments" "1" "$ASSIGNED"

# Re-assign with a port (should update, not duplicate)
curl -sf -X POST "$BASE/api/hosts/$HOST_ID/assign" -H "Content-Type: application/json" \
  -d "{\"member_id\": $ALICE_ID, \"port_id\": $PORT_ID}" > /dev/null
H=$(curl -sf "$BASE/api/hosts/$HOST_ID")
ASSIGNED_COUNT=$(echo "$H" | jq '[.assignments[] | select(.member_name=="Alice")] | length')
PORT_FOCUS=$(echo "$H" | jq '.assignments[] | select(.member_name=="Alice") | .port_number')
assert_eq "Still only 1 Alice assignment" "1" "$ASSIGNED_COUNT"
assert_eq "Alice now focused on port 22" "22" "$PORT_FOCUS"

# Member assignments endpoint
MA=$(curl -sf "$BASE/api/members/$ALICE_ID/assignments")
assert_eq "Alice has 1 active assignment" "1" "$(echo "$MA" | jq 'length')"

# Multi-member on same host
BOB_ID=$(curl -sf "$BASE/api/members" | jq '.[] | select(.name=="Bob") | .id')
curl -sf -X POST "$BASE/api/hosts/$HOST_ID/assign" -H "Content-Type: application/json" \
  -d "{\"member_id\": $BOB_ID}" > /dev/null
H=$(curl -sf "$BASE/api/hosts/$HOST_ID")
assert_eq "2 members on host" "2" "$(echo "$H" | jq '.assignments | length')"

# Unassign
curl -sf -X POST "$BASE/api/hosts/$HOST_ID/unassign" -H "Content-Type: application/json" \
  -d "{\"member_id\": $BOB_ID}" > /dev/null
H=$(curl -sf "$BASE/api/hosts/$HOST_ID")
assert_eq "After unassign Bob, 1 remains" "1" "$(echo "$H" | jq '.assignments | length')"

# Assign to non-existent host
BAD=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/hosts/99999/assign" \
  -H "Content-Type: application/json" -d "{\"member_id\": $ALICE_ID}")
assert_eq "Assign to missing host -> 404" "404" "$BAD"

# Assign non-existent member
BAD2=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/hosts/$HOST_ID/assign" \
  -H "Content-Type: application/json" -d '{"member_id": 99999}')
assert_eq "Assign missing member -> 404" "404" "$BAD2"

echo ""
echo "3. INVESTIGATION STATUS"
echo "──────────────────────────────────────────"

for STATUS in "investigating" "investigated" "compromised" "untouched"; do
    curl -sf -X PUT "$BASE/api/hosts/$HOST_ID/status" -H "Content-Type: application/json" \
      -d "{\"member_id\": $ALICE_ID, \"status\": \"$STATUS\"}" > /dev/null
    ACTUAL=$(curl -sf "$BASE/api/hosts/$HOST_ID" | jq -r '.investigation_status')
    assert_eq "Set status to $STATUS" "$STATUS" "$ACTUAL"
done

# Invalid status
BAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/api/hosts/$HOST_ID/status" \
  -H "Content-Type: application/json" -d "{\"member_id\": $ALICE_ID, \"status\": \"pwned\"}")
assert_eq "Invalid status -> 400" "400" "$BAD_STATUS"

# Status is visible in hosts list
LIST=$(curl -sf "$BASE/api/hosts")
LIST_STATUS=$(echo "$LIST" | jq -r ".[] | select(.id==$HOST_ID) | .investigation_status")
assert_eq "Status appears in hosts list" "untouched" "$LIST_STATUS"

# Status is visible in topology
TOPO=$(curl -sf "$BASE/api/topology")
TOPO_STATUS=$(echo "$TOPO" | jq -r ".hosts[] | select(.id==$HOST_ID) | .investigation_status")
assert_eq "Status appears in topology" "untouched" "$TOPO_STATUS"

# Set to compromised for export test
curl -sf -X PUT "$BASE/api/hosts/$HOST_ID/status" -H "Content-Type: application/json" \
  -d "{\"member_id\": $ALICE_ID, \"status\": \"compromised\"}" > /dev/null

echo ""
echo "4. NOTES"
echo "──────────────────────────────────────────"

# Add two notes
N1=$(curl -sf -X POST "$BASE/api/hosts/$HOST_ID/notes" -H "Content-Type: application/json" \
  -d "{\"member_id\": $ALICE_ID, \"note\": \"SSH is OpenSSH 4.3, checking CVEs\"}")
N2=$(curl -sf -X POST "$BASE/api/hosts/$HOST_ID/notes" -H "Content-Type: application/json" \
  -d "{\"member_id\": $ALICE_ID, \"note\": \"Found anonymous FTP open\"}")
assert_contains "Note 1 returns id" "id" "$N1"
assert_contains "Note 2 returns id" "id" "$N2"

# Notes list
NOTES=$(curl -sf "$BASE/api/hosts/$HOST_ID/notes")
assert_eq "2 notes on host" "2" "$(echo "$NOTES" | jq 'length')"

# Note shape
FIRST_NOTE=$(echo "$NOTES" | jq '.[0]')
for F in id host_id member_id member_name member_icon note created_at; do
    assert_eq "Note has .$F" "true" "$(echo "$FIRST_NOTE" | jq "has(\"$F\")")"
done

# Note author populated
AUTHOR=$(echo "$NOTES" | jq -r '.[0].member_name')
assert_eq "Note author is Alice" "Alice" "$AUTHOR"

# Notes appear in host detail
H=$(curl -sf "$BASE/api/hosts/$HOST_ID")
assert_eq "Host detail includes 2 notes" "2" "$(echo "$H" | jq '.notes | length')"

# Anonymous note (no member_id)
curl -sf -X POST "$BASE/api/hosts/$HOST_ID/notes" -H "Content-Type: application/json" \
  -d '{"note": "Automated finding"}' > /dev/null
H=$(curl -sf "$BASE/api/hosts/$HOST_ID")
ANON=$(echo "$H" | jq '[.notes[] | select(.member_id == null)] | length')
assert_eq "Anonymous note stored" "1" "$ANON"

# Empty note rejected
BAD_NOTE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/hosts/$HOST_ID/notes" \
  -H "Content-Type: application/json" -d '{"note": "   "}')
assert_eq "Empty note -> 400" "400" "$BAD_NOTE"

echo ""
echo "5. BLAME LOG"
echo "──────────────────────────────────────────"

BLAME=$(curl -sf "$BASE/api/blame")
BLAME_COUNT=$(echo "$BLAME" | jq 'length')
assert_gt "Blame log has >=5 entries" 5 "$BLAME_COUNT"

# Verify blame entry shape
FIRST_B=$(echo "$BLAME" | jq '.[0]')
for F in id member_id member_name member_icon action target_type target_id target_label created_at; do
    assert_eq "Blame has .$F" "true" "$(echo "$FIRST_B" | jq "has(\"$F\")")"
done

# target_label is the host IP for host actions
HOST_ACTIONS=$(echo "$BLAME" | jq "[.[] | select(.target_type==\"host\" and .target_id==$HOST_ID)]")
BLAME_IP=$(echo "$HOST_ACTIONS" | jq -r '.[0].target_label')
assert_eq "Blame target_label is host IP" "204.152.191.37" "$BLAME_IP"

# Blame actions logged
assert_eq "Has 'assigned' action" "true" \
    "$(echo "$BLAME" | jq 'any(.action == "assigned")')"
assert_eq "Has 'unassigned' action" "true" \
    "$(echo "$BLAME" | jq 'any(.action == "unassigned")')"
assert_eq "Has 'status_changed' action" "true" \
    "$(echo "$BLAME" | jq 'any(.action == "status_changed")')"
assert_eq "Has 'note_added' action" "true" \
    "$(echo "$BLAME" | jq 'any(.action == "note_added")')"

# Per-member blame
AB=$(curl -sf "$BASE/api/members/$ALICE_ID/blame")
ALICE_ONLY=$(echo "$AB" | jq '[.[] | select(.member_id != '$ALICE_ID')] | length')
assert_eq "Per-member blame filters correctly" "0" "$ALICE_ONLY"

# Blame log limit
LIMITED=$(curl -sf "$BASE/api/blame?limit=3" | jq 'length')
assert_eq "Limit parameter works" "3" "$LIMITED"

echo ""
echo "6. HOST DETAIL ENRICHMENT"
echo "──────────────────────────────────────────"

H=$(curl -sf "$BASE/api/hosts/$HOST_ID")
# All new fields present
for F in investigation_status assignments notes; do
    assert_eq "Host detail has .$F" "true" "$(echo "$H" | jq "has(\"$F\")")"
done

# Topology also has assignments
TOPO_HOST=$(echo "$TOPO" | jq ".hosts[] | select(.id==$HOST_ID)")
assert_eq "Topology host has .assignments" "true" "$(echo "$TOPO_HOST" | jq 'has("assignments")')"
assert_eq "Topology host has .investigation_status" "true" "$(echo "$TOPO_HOST" | jq 'has("investigation_status")')"

echo ""
echo "7. EXPORTS"
echo "──────────────────────────────────────────"

# JSON export
JSON=$(curl -sf "$BASE/api/export/json")
assert_contains "JSON export has hosts" '"hosts":' "$JSON"
assert_contains "JSON export has members" '"members":' "$JSON"
assert_contains "JSON export has blame_log" '"blame_log":' "$JSON"
assert_contains "JSON export has networks" '"networks":' "$JSON"
assert_contains "JSON has Alice" '"Alice"' "$JSON"
assert_contains "JSON has test host" "204.152.191.37" "$JSON"
assert_contains "JSON has compromised status" "compromised" "$JSON"

# Content-Disposition for download
JSON_HDR=$(curl -s -o /dev/null -D- "$BASE/api/export/json" | grep -i 'content-disposition')
assert_contains "JSON export is downloadable" "attachment" "$JSON_HDR"

# XML export
XML=$(curl -sf "$BASE/api/export/xml")
assert_contains "XML has prolog" '<?xml' "$XML"
assert_contains "XML has root" '<portherald_export' "$XML"
assert_contains "XML has <hosts>" '<hosts>' "$XML"
assert_contains "XML has <members>" '<members>' "$XML"
assert_contains "XML has <blame_log>" '<blame_log>' "$XML"
assert_contains "XML has host IP" "204.152.191.37" "$XML"
assert_contains "XML has note CDATA" 'CDATA' "$XML"

# TXT export
TXT=$(curl -sf "$BASE/api/export/txt")
assert_contains "TXT header" "Port Herald Export" "$TXT"
assert_contains "TXT has NETWORKS section" "NETWORKS" "$TXT"
assert_contains "TXT has HOSTS section" "HOSTS" "$TXT"
assert_contains "TXT has TEAM section" "TEAM" "$TXT"
assert_contains "TXT has BLAME LOG section" "BLAME LOG" "$TXT"
assert_contains "TXT has host IP" "204.152.191.37" "$TXT"
assert_contains "TXT has note content" "OpenSSH 4.3" "$TXT"

# Invalid format
BAD_FMT=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/export/csv")
assert_eq "Bad format -> 400" "400" "$BAD_FMT"

echo ""
echo "8. NOTES-ONLY EXPORT"
echo "──────────────────────────────────────────"

NJ=$(curl -sf "$BASE/api/notes/export/json")
assert_eq "Notes JSON is array" "true" "$(echo "$NJ" | jq 'type == "array"')"
assert_gt "Notes JSON has >=3 entries" 2 "$(echo "$NJ" | jq 'length')"

NT=$(curl -sf "$BASE/api/notes/export/txt")
assert_contains "Notes TXT header" "Notes Export" "$NT"
assert_contains "Notes TXT has host context" "204.152.191.37" "$NT"
assert_contains "Notes TXT has note content" "OpenSSH 4.3" "$NT"

NX=$(curl -sf "$BASE/api/notes/export/xml")
assert_contains "Notes XML prolog" '<?xml' "$NX"
assert_contains "Notes XML root" '<notes>' "$NX"
assert_contains "Notes XML has note element" '<note ' "$NX"

echo ""
echo "9. FRONTEND ASSET CHECK"
echo "──────────────────────────────────────────"

HTML=$(curl -sf "$BASE/")
assert_contains "HTML has Team tab button" 'data-tab="team"' "$HTML"
assert_contains "HTML has Export tab button" 'data-tab="export"' "$HTML"
assert_contains "HTML has current-user-select" 'current-user-select' "$HTML"
assert_contains "HTML has members-input" 'members-input' "$HTML"
assert_contains "HTML has members-file" 'members-file' "$HTML"
assert_contains "HTML has team-list container" 'id="team-list"' "$HTML"
assert_contains "HTML has blame-list" 'id="blame-list"' "$HTML"
assert_contains "HTML has blame-filter" 'id="blame-filter"' "$HTML"
assert_contains "HTML has export links to JSON/XML/TXT" '/api/export/json' "$HTML"

JS=$(curl -sf "$BASE/js/app.js")
assert_contains "JS has refreshMembers" 'refreshMembers' "$JS"
assert_contains "JS has refreshBlame" 'refreshBlame' "$JS"
assert_contains "JS has addMembers" 'async function addMembers' "$JS"
assert_contains "JS has removeMember" 'removeMember' "$JS"
assert_contains "JS has STATUS_META" 'STATUS_META' "$JS"
assert_contains "JS has renderTeamPanel" 'renderTeamPanel' "$JS"
assert_contains "JS has renderNotesPanel" 'renderNotesPanel' "$JS"
assert_contains "JS has openHostFromTopology" 'openHostFromTopology' "$JS"
assert_contains "JS has openHostFromTeam" 'openHostFromTeam' "$JS"
assert_contains "JS uses currentUserId" 'currentUserId' "$JS"
assert_contains "JS persists currentUserId" "localStorage.setItem('ph-current-user'" "$JS"
assert_contains "JS has member-icon-only renderer" 'member-icon-only' "$JS"

CSS=$(curl -sf "$BASE/css/style.css")
assert_contains "CSS has .invest-badge" 'invest-badge' "$CSS"
assert_contains "CSS has .member-chip" 'member-chip' "$CSS"
assert_contains "CSS has .member-icon-only" 'member-icon-only' "$CSS"
assert_contains "CSS has .team-member-row" 'team-member-row' "$CSS"
assert_contains "CSS has .blame-entry" 'blame-entry' "$CSS"
assert_contains "CSS has .status-btn" 'status-btn' "$CSS"
assert_contains "CSS has .note style" '.note ' "$CSS"
assert_contains "CSS has invest-compromised" 'invest-compromised' "$CSS"
assert_contains "CSS has invest-investigated" 'invest-investigated' "$CSS"

echo ""
echo "10. UPSERT & STATUS PERSISTENCE"
echo "──────────────────────────────────────────"

# Re-import the same scan - compromised status should persist
BEFORE_STATUS=$(curl -sf "$BASE/api/hosts/$HOST_ID" | jq -r '.investigation_status')
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
  -d "$(jq -Rs '{"xml": .}' tests/fixtures/sample-scan.xml)" > /dev/null
AFTER_STATUS=$(curl -sf "$BASE/api/hosts/$HOST_ID" | jq -r '.investigation_status')
assert_eq "Status persists through re-import" "$BEFORE_STATUS" "$AFTER_STATUS"

# Notes also persist
NOTES_AFTER=$(curl -sf "$BASE/api/hosts/$HOST_ID" | jq '.notes | length')
assert_gt "Notes persist through re-import" 2 "$NOTES_AFTER"

# Assignments also persist
ASSIGN_AFTER=$(curl -sf "$BASE/api/hosts/$HOST_ID" | jq '.assignments | length')
assert_gt "Assignments persist through re-import" 0 "$ASSIGN_AFTER"

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then echo "  ⚠️  Some tests failed!"; exit 1
else echo "  🎉 ALL TEAM TESTS PASSED!"; exit 0; fi
