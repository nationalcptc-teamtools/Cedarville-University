#!/bin/bash
# Live-scan / Active Scans tab tests
# Verifies: start → status shape → logs streaming → cancel → auto-cleanup
set -eu
BASE="http://localhost:9999"
PASS=0; FAIL=0; TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1: $2"; }
assert_eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi; }
assert_gt() { if [ "$3" -gt "$2" ] 2>/dev/null; then pass "$1"; else fail "$1" "expected > $2, got '$3'"; fi; }
assert_contains() {
    local tmp; tmp=$(mktemp); printf '%s' "$3" > "$tmp"
    if grep -q -- "$2" "$tmp"; then pass "$1"
    else fail "$1" "missing '$2'"; fi
    rm -f "$tmp"
}

echo "============================================"
echo "  ACTIVE SCANS / CANCEL / LOG STREAMING"
echo "============================================"
echo ""

# ─── Payload for a scan that will fail fast (no nmap on this host? still works) ───
CFG='{"targets":["127.0.0.1"],"excluded_targets":[],"scan_type":"connect","timing_template":"Aggressive","version_detection":false,"os_detection":false,"script_scan":false,"udp_scan":false,"evasion_enabled":false,"source_port":null,"dns_servers":[],"max_rate":null}'

echo "1. SCAN LIFECYCLE"
echo "──────────────────────────────────────────"

# Baseline: list is empty
LIST=$(curl -sf "$BASE/api/scans/active")
INITIAL_COUNT=$(echo "$LIST" | jq 'length')
echo "  (initial active count: $INITIAL_COUNT)"

# Start a scan
R=$(curl -sf -X POST "$BASE/api/scans" -H "Content-Type: application/json" -d "$CFG")
SID=$(echo "$R" | jq -r '.scan_id')
assert_contains "Start returns scan_id" "scan_id" "$R"
assert_eq "scan_id is a UUID" "36" "${#SID}"

sleep 1
# List active
LIST=$(curl -sf "$BASE/api/scans/active")
AFTER_COUNT=$(echo "$LIST" | jq 'length')
assert_gt "Active list grew" "$INITIAL_COUNT" "$AFTER_COUNT"

echo ""
echo "2. ACTIVE SCAN SHAPE"
echo "──────────────────────────────────────────"

ENTRY=$(echo "$LIST" | jq ".[] | select(.scan_id==\"$SID\")")
for FIELD in scan_id short_id targets phase phase_label phase_percent overall_percent \
             hosts_discovered ports_discovered cancelled finished started_at log_count; do
    assert_eq "Entry has .$FIELD" "true" "$(echo "$ENTRY" | jq "has(\"$FIELD\")")"
done

# short_id is first 8 chars of the UUID
SHORT=$(echo "$ENTRY" | jq -r '.short_id')
assert_eq "short_id = 8 chars of UUID" "${SID:0:8}" "$SHORT"

# phase_label is human-readable
assert_eq "phase_label is non-empty" "true" "$(echo "$ENTRY" | jq '.phase_label != ""')"

# targets echoes config
assert_eq "targets[0] = 127.0.0.1" "127.0.0.1" "$(echo "$ENTRY" | jq -r '.targets[0]')"

echo ""
echo "3. STATUS ENDPOINT"
echo "──────────────────────────────────────────"

STATUS=$(curl -sf "$BASE/api/scans/$SID/status")
assert_eq "Status short_id matches" "$SHORT" "$(echo "$STATUS" | jq -r '.short_id')"
assert_eq "Status has overall_percent" "true" "$(echo "$STATUS" | jq 'has("overall_percent")')"
assert_eq "Status has phase_percent" "true" "$(echo "$STATUS" | jq 'has("phase_percent")')"

# Non-existent scan → 404
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/scans/not-a-real-uuid/status")
assert_eq "Missing scan status -> 404" "404" "$HTTP"

echo ""
echo "4. LOGS ENDPOINT"
echo "──────────────────────────────────────────"

sleep 1  # let a couple of log lines accumulate
LOGS=$(curl -sf "$BASE/api/scans/$SID/logs?since=0")
assert_eq "Logs has .scan_id" "true" "$(echo "$LOGS" | jq 'has("scan_id")')"
assert_eq "Logs has .total" "true" "$(echo "$LOGS" | jq 'has("total")')"
assert_eq "Logs has .offset" "true" "$(echo "$LOGS" | jq 'has("offset")')"
assert_eq "Logs has .lines array" "true" "$(echo "$LOGS" | jq '.lines | type == "array"')"

# Partial fetch with since=N returns slice from N onward
LTOTAL=$(echo "$LOGS" | jq '.total')
HALF=$((LTOTAL / 2))
if [ "$LTOTAL" -gt 1 ]; then
    SLICE=$(curl -sf "$BASE/api/scans/$SID/logs?since=$HALF")
    SLICE_LEN=$(echo "$SLICE" | jq '.lines | length')
    EXPECTED=$((LTOTAL - HALF))
    assert_eq "since=$HALF returns remaining $EXPECTED lines" "$EXPECTED" "$SLICE_LEN"
    assert_eq "slice offset = $HALF" "$HALF" "$(echo "$SLICE" | jq '.offset')"
fi

# since > total is clamped
OVER=$(curl -sf "$BASE/api/scans/$SID/logs?since=999999")
assert_eq "since > total returns []" "0" "$(echo "$OVER" | jq '.lines | length')"

# Logs 404 on missing scan
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/scans/not-a-real-uuid/logs")
assert_eq "Missing scan logs -> 404" "404" "$HTTP"

# At least one line should start with the "$ " command prompt prefix.
FIRST_LINES=$(echo "$LOGS" | jq -r '.lines[]' | head -5)
assert_contains "Logs include a command invocation line" '\$ ' "$FIRST_LINES"

echo ""
echo "5. CANCEL ENDPOINT"
echo "──────────────────────────────────────────"

# Start another scan (first may already have terminated on this macOS test box)
R2=$(curl -sf -X POST "$BASE/api/scans" -H "Content-Type: application/json" -d "$CFG")
SID2=$(echo "$R2" | jq -r '.scan_id')
sleep 1

CANCEL=$(curl -sf -X POST "$BASE/api/scans/$SID2/cancel")
assert_eq "Cancel returns status=cancelling" "cancelling" "$(echo "$CANCEL" | jq -r '.status')"

sleep 2
STATUS2=$(curl -sf "$BASE/api/scans/$SID2/status")
assert_eq "Cancelled scan has .cancelled=true" "true" "$(echo "$STATUS2" | jq '.cancelled')"
assert_eq "Cancelled scan is .finished=true" "true" "$(echo "$STATUS2" | jq '.finished')"

# Cancelling an unknown scan → 404
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/scans/no-such-id/cancel")
assert_eq "Cancel missing scan -> 404" "404" "$HTTP"

echo ""
echo "6. PROGRESS WEIGHTING"
echo "──────────────────────────────────────────"

# overall_percent must be a float in [0, 100]
OP=$(echo "$STATUS" | jq '.overall_percent')
PP=$(echo "$STATUS" | jq '.phase_percent')
if awk "BEGIN{ exit !($OP >= 0 && $OP <= 100) }"; then pass "overall_percent in [0,100]"; else fail "overall_percent in [0,100]" "got $OP"; fi
if awk "BEGIN{ exit !($PP >= 0 && $PP <= 100) }"; then pass "phase_percent   in [0,100]"; else fail "phase_percent in [0,100]" "got $PP"; fi

echo ""
echo "7. FRONTEND ASSET WIRING"
echo "──────────────────────────────────────────"

HTML=$(curl -sf "$BASE/")
assert_contains "HTML has Active Scans nav button" 'data-tab="active"' "$HTML"
assert_contains "HTML has nav badge element" 'id="active-scans-badge"' "$HTML"
assert_contains "HTML has active-tab panel" 'id="active-tab"' "$HTML"
assert_contains "HTML has active-scans-list container" 'id="active-scans-list"' "$HTML"
assert_contains "HTML has auto-scroll toggle" 'id="auto-scroll-logs"' "$HTML"
assert_contains "HTML has refresh-active button" 'id="refresh-active"' "$HTML"
assert_contains "HTML has scanner-launch-notice" 'scanner-launch-notice' "$HTML"

JS=$(curl -sf "$BASE/js/app.js")
assert_contains "JS has refreshActiveScans" 'refreshActiveScans' "$JS"
assert_contains "JS has renderActiveScans" 'renderActiveScans' "$JS"
assert_contains "JS has pollScanLogs" 'pollScanLogs' "$JS"
assert_contains "JS has cancelScan" 'async function cancelScan' "$JS"
assert_contains "JS has startActiveScanPolling" 'startActiveScanPolling' "$JS"
assert_contains "JS has buildScanCard" 'buildScanCard' "$JS"
assert_contains "JS reads /scans/active" '/scans/active' "$JS"
assert_contains "JS reads logs endpoint" '/scans/.*/logs' "$JS"
assert_contains "JS calls cancel endpoint" '/scans/.*/cancel' "$JS"
assert_contains "JS tracks scan_hash via short_id" 'short_id' "$JS"
assert_contains "JS classifies console lines" 'classifyLine' "$JS"
assert_contains "JS has active TAB_TITLE" "active:" "$JS"

CSS=$(curl -sf "$BASE/css/style.css")
assert_contains "CSS has .active-scan-card" 'active-scan-card' "$CSS"
assert_contains "CSS has .scan-hash" 'scan-hash' "$CSS"
assert_contains "CSS has .scan-phase-pill" 'scan-phase-pill' "$CSS"
assert_contains "CSS has .scan-cancel-btn" 'scan-cancel-btn' "$CSS"
assert_contains "CSS has .scan-console" 'scan-console' "$CSS"
assert_contains "CSS has .scan-progress-fill" 'scan-progress-fill' "$CSS"
assert_contains "CSS has .nav-badge" 'nav-badge' "$CSS"
assert_contains "CSS has running state" 'scan-phase-pill.running' "$CSS"
assert_contains "CSS has complete state" 'scan-phase-pill.complete' "$CSS"
assert_contains "CSS has failed state" 'scan-phase-pill.failed' "$CSS"
assert_contains "CSS has cancelled state" 'scan-phase-pill.cancelled' "$CSS"

echo ""
echo "8. SUMMARY FIELDS (scan hash / stage / completion / hosts / ports)"
echo "──────────────────────────────────────────"

FINAL=$(curl -sf "$BASE/api/scans/$SID/status")
# These are the summary fields the user asked for
assert_eq "Summary field: scan hash (short_id)"   "true" "$(echo "$FINAL" | jq 'has("short_id")')"
assert_eq "Summary field: stage (phase_label)"    "true" "$(echo "$FINAL" | jq 'has("phase_label")')"
assert_eq "Summary field: completion (overall_percent)" "true" "$(echo "$FINAL" | jq 'has("overall_percent")')"
assert_eq "Summary field: completion (phase_percent)"   "true" "$(echo "$FINAL" | jq 'has("phase_percent")')"
assert_eq "Summary field: hosts (hosts_discovered)" "true" "$(echo "$FINAL" | jq 'has("hosts_discovered")')"
assert_eq "Summary field: ports (ports_discovered)" "true" "$(echo "$FINAL" | jq 'has("ports_discovered")')"
assert_eq "Summary field: started_at"               "true" "$(echo "$FINAL" | jq 'has("started_at")')"
assert_eq "Summary field: finished flag"            "true" "$(echo "$FINAL" | jq 'has("finished")')"

echo ""
echo "9. SCAN HISTORY (DB persistence)"
echo "──────────────────────────────────────────"

# Wait a beat so the finalizer has had a chance to write.
sleep 2

HIST=$(curl -sf "$BASE/api/scans")
assert_eq "History endpoint returns array" "true" "$(echo "$HIST" | jq 'type == "array"')"

# Row for our SID should exist with scan_uuid matching.
ROW=$(echo "$HIST" | jq ".[] | select(.scan_uuid==\"$SID\")")
assert_eq "History row exists for scan $SHORT" "true" "$([ -n "$ROW" ] && echo true || echo false)"

for FIELD in id scan_uuid scan_type targets arguments start_time status hosts_found ports_found; do
    assert_eq "Row has .$FIELD" "true" "$(echo "$ROW" | jq "has(\"$FIELD\")")"
done

# Status should be one of the terminal states by now (the scan was short-lived).
ST=$(echo "$ROW" | jq -r '.status')
case "$ST" in
    complete|failed|cancelled|running) pass "History status is a known state ($ST)" ;;
    *) fail "History status is a known state" "got '$ST'" ;;
esac

# scan_uuid should round-trip exactly.
assert_eq "scan_uuid matches submission" "$SID" "$(echo "$ROW" | jq -r '.scan_uuid')"

# Cancelled scan from section 5 should also show up with status=cancelled.
sleep 1
HIST=$(curl -sf "$BASE/api/scans")
CANCEL_ROW=$(echo "$HIST" | jq ".[] | select(.scan_uuid==\"$SID2\")")
if [ -n "$CANCEL_ROW" ]; then
    CST=$(echo "$CANCEL_ROW" | jq -r '.status')
    case "$CST" in
        cancelled|failed) pass "Cancelled scan persisted with terminal status ($CST)" ;;
        *) fail "Cancelled scan persisted with terminal status" "got '$CST'" ;;
    esac
fi

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then echo "  ⚠️  Some tests failed!"; exit 1
else echo "  🎉 ALL SCAN TESTS PASSED!"; exit 0; fi
