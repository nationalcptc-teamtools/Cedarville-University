#!/bin/bash
# Frontend contract tests
# Verifies the JSON shapes the JS expects are exactly what the API returns.
# Also checks that multi-network topology grouping works correctly.

set -eu

BASE="http://localhost:9999"
PASS=0
FAIL=0
TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1: $2"; }

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then pass "$label"
    else fail "$label" "expected '$expected', got '$actual'"; fi
}

assert_gt() {
    local label="$1" threshold="$2" actual="$3"
    if [ "$actual" -gt "$threshold" ] 2>/dev/null; then pass "$label"
    else fail "$label" "expected > $threshold, got '$actual'"; fi
}

echo "============================================"
echo "  FRONTEND CONTRACT TESTS"
echo "============================================"
echo ""

# Import data first
curl -sf -X POST "$BASE/api/import" \
  -H "Content-Type: application/json" \
  -d "$(jq -Rs '{"xml": .}' tests/fixtures/sample-scan.xml)" > /dev/null

echo "1. EMBEDDED ASSET SERVING"
echo "──────────────────────────────────────────"

# Verify the ACTUAL JS content the browser gets has no host.host references
JS_BODY=$(curl -sf "$BASE/js/app.js")
if echo "$JS_BODY" | grep -q 'host\.host\.'; then
    fail "JS has no host.host references" "found host.host in served JS"
else
    pass "JS has no host.host references"
fi

if echo "$JS_BODY" | grep -q 'portData\.port'; then
    fail "JS has no portData.port references" "found portData.port in served JS"
else
    pass "JS has no portData.port references"
fi

if echo "$JS_BODY" | grep -q 'p\.port\.state'; then
    fail "JS has no p.port.state references" "found p.port.state in served JS"
else
    pass "JS has no p.port.state references"
fi

# Verify no-cache headers (use GET with -D-, not -I which sends HEAD)
CACHE_HDR=$(curl -s -o /dev/null -D- "$BASE/js/app.js" | grep -i 'cache-control')
if echo "$CACHE_HDR" | grep -qi 'no-cache'; then
    pass "JS served with no-cache header"
else
    fail "JS served with no-cache header" "got: $CACHE_HDR"
fi

echo ""
echo "2. TOPOLOGY JSON – host fields are FLAT (not nested under .host)"
echo "──────────────────────────────────────────"

TOPO=$(curl -sf "$BASE/api/topology")
FIRST_HOST=$(echo "$TOPO" | jq '.hosts[0]')

# The JS does: host.network_id, host.ip_address, host.hostname, host.id
# These must exist at the TOP level, NOT under .host
assert_eq "topology host has top-level .ip_address" "true" \
    "$(echo "$FIRST_HOST" | jq 'has("ip_address")')"
assert_eq "topology host has top-level .network_id" "true" \
    "$(echo "$FIRST_HOST" | jq 'has("network_id")')"
assert_eq "topology host has top-level .hostname" "true" \
    "$(echo "$FIRST_HOST" | jq 'has("hostname")')"
assert_eq "topology host has top-level .id" "true" \
    "$(echo "$FIRST_HOST" | jq 'has("id")')"
assert_eq "topology host has top-level .status" "true" \
    "$(echo "$FIRST_HOST" | jq 'has("status")')"
assert_eq "topology host has top-level .ports" "true" \
    "$(echo "$FIRST_HOST" | jq 'has("ports")')"
assert_eq "topology host does NOT have nested .host" "false" \
    "$(echo "$FIRST_HOST" | jq 'has("host")')"

echo ""
echo "3. TOPOLOGY JSON – port fields are FLAT (not nested under .port)"
echo "──────────────────────────────────────────"

FIRST_PORT=$(echo "$TOPO" | jq '[.hosts[].ports[]] | first')

# The JS does: port.state, port.port_number, port.protocol, port.service, port.scripts
assert_eq "topology port has top-level .port_number" "true" \
    "$(echo "$FIRST_PORT" | jq 'has("port_number")')"
assert_eq "topology port has top-level .state" "true" \
    "$(echo "$FIRST_PORT" | jq 'has("state")')"
assert_eq "topology port has top-level .protocol" "true" \
    "$(echo "$FIRST_PORT" | jq 'has("protocol")')"
assert_eq "topology port has top-level .service" "true" \
    "$(echo "$FIRST_PORT" | jq 'has("service")')"
assert_eq "topology port has top-level .scripts" "true" \
    "$(echo "$FIRST_PORT" | jq 'has("scripts")')"
assert_eq "topology port does NOT have nested .port" "false" \
    "$(echo "$FIRST_PORT" | jq 'has("port")')"

echo ""
echo "4. HOST DETAIL JSON – same flat shape"
echo "──────────────────────────────────────────"

# Get first host ID
FIRST_ID=$(curl -sf "$BASE/api/hosts" | jq '.[0].id')
DETAIL=$(curl -sf "$BASE/api/hosts/$FIRST_ID")

# showHostDetail does: host.ip_address, host.hostname, host.os, host.os_accuracy, etc.
assert_eq "detail has top-level .ip_address" "true" \
    "$(echo "$DETAIL" | jq 'has("ip_address")')"
assert_eq "detail has top-level .hostname" "true" \
    "$(echo "$DETAIL" | jq 'has("hostname")')"
assert_eq "detail has top-level .os" "true" \
    "$(echo "$DETAIL" | jq 'has("os")')"
assert_eq "detail has top-level .os_accuracy" "true" \
    "$(echo "$DETAIL" | jq 'has("os_accuracy")')"
assert_eq "detail has top-level .mac_address" "true" \
    "$(echo "$DETAIL" | jq 'has("mac_address")')"
assert_eq "detail has top-level .vendor" "true" \
    "$(echo "$DETAIL" | jq 'has("vendor")')"
assert_eq "detail has top-level .first_seen" "true" \
    "$(echo "$DETAIL" | jq 'has("first_seen")')"
assert_eq "detail has top-level .last_seen" "true" \
    "$(echo "$DETAIL" | jq 'has("last_seen")')"
assert_eq "detail has top-level .ports" "true" \
    "$(echo "$DETAIL" | jq 'has("ports")')"
assert_eq "detail does NOT have nested .host" "false" \
    "$(echo "$DETAIL" | jq 'has("host")')"

# Port within detail
DETAIL_PORT=$(echo "$DETAIL" | jq '.ports[0]')
assert_eq "detail port has .port_number" "true" \
    "$(echo "$DETAIL_PORT" | jq 'has("port_number")')"
assert_eq "detail port has .state" "true" \
    "$(echo "$DETAIL_PORT" | jq 'has("state")')"
assert_eq "detail port has .scripts" "true" \
    "$(echo "$DETAIL_PORT" | jq 'has("scripts")')"
assert_eq "detail port does NOT have nested .port" "false" \
    "$(echo "$DETAIL_PORT" | jq 'has("port")')"

echo ""
echo "5. SCRIPT RESULT shape inside port"
echo "──────────────────────────────────────────"

# Find a port that has scripts
PORT_WITH_SCRIPTS=$(echo "$TOPO" | jq '[.hosts[].ports[] | select(.scripts | length > 0)] | first')
FIRST_SCRIPT=$(echo "$PORT_WITH_SCRIPTS" | jq '.scripts[0]')

assert_eq "script has .script_name" "true" \
    "$(echo "$FIRST_SCRIPT" | jq 'has("script_name")')"
assert_eq "script has .output" "true" \
    "$(echo "$FIRST_SCRIPT" | jq 'has("output")')"
assert_eq "script .script_name is string" "true" \
    "$(echo "$FIRST_SCRIPT" | jq '.script_name | type == "string"')"
assert_eq "script .output is string" "true" \
    "$(echo "$FIRST_SCRIPT" | jq '.output | type == "string"')"

echo ""
echo "6. MULTI-NETWORK TOPOLOGY GROUPING"
echo "──────────────────────────────────────────"

# The scan has 8 hosts across 7 different /24 networks.
# freshmeat (66.35.250.168) and sourceforge (66.35.250.203) share 66.35.250.0/24.
NET_COUNT=$(echo "$TOPO" | jq '.networks | length')
assert_eq "7 distinct networks" "7" "$NET_COUNT"

# Verify each network has the expected CIDR
for CIDR in "66.35.250.0/24" "64.13.134.0/24" "204.152.191.0/24" \
            "199.185.137.0/24" "204.152.190.0/24" "72.14.207.0/24" "72.14.253.0/24"; do
    assert_eq "Network $CIDR present" "1" \
        "$(echo "$TOPO" | jq "[.networks[] | select(.cidr==\"$CIDR\")] | length")"
done

# Verify freshmeat + sourceforge share a network_id
FM_NID=$(echo "$TOPO" | jq '.hosts[] | select(.ip_address=="66.35.250.168") | .network_id')
SF_NID=$(echo "$TOPO" | jq '.hosts[] | select(.ip_address=="66.35.250.203") | .network_id')
assert_eq "freshmeat & sourceforge same network_id" "$FM_NID" "$SF_NID"

# All other hosts should have DIFFERENT network_ids
UNIQUE_NIDS=$(echo "$TOPO" | jq '[.hosts[].network_id] | unique | length')
assert_eq "7 unique network_ids across 8 hosts" "7" "$UNIQUE_NIDS"

# renderTopology groups by network_id — verify the grouping produces 7 groups
# Simulate the JS: group hosts by network_id, count groups
GROUP_COUNT=$(echo "$TOPO" | jq '[.hosts | group_by(.network_id)[] | length] | length')
assert_eq "Topology renders 7 network groups" "7" "$GROUP_COUNT"

# The 66.35.250.0/24 group should have 2 hosts
SHARED_GROUP_SIZE=$(echo "$TOPO" | jq "[.hosts[] | select(.network_id==$FM_NID)] | length")
assert_eq "66.35.250.0/24 group has 2 hosts" "2" "$SHARED_GROUP_SIZE"

# All other groups should have exactly 1 host
SINGLE_GROUPS=$(echo "$TOPO" | jq "[.hosts | group_by(.network_id)[] | select(length == 1)] | length")
assert_eq "6 networks with exactly 1 host each" "6" "$SINGLE_GROUPS"

echo ""
echo "7. TOPOLOGY NETWORK ↔ HOST LINKAGE"
echo "──────────────────────────────────────────"

# Every host's network_id should map to a network in .networks
echo "$TOPO" | jq -r '.hosts[] | "\(.ip_address) \(.network_id)"' | while read IP NID; do
    MATCH=$(echo "$TOPO" | jq "[.networks[] | select(.id==$NID)] | length")
    if [ "$MATCH" = "1" ]; then
        pass "Host $IP network_id=$NID maps to a network"
    else
        fail "Host $IP network_id=$NID maps to a network" "no matching network found"
    fi
done

# Each network's id should have at least one host referencing it
echo "$TOPO" | jq -r '.networks[] | "\(.id) \(.cidr)"' | while read NID CIDR; do
    HOST_COUNT=$(echo "$TOPO" | jq "[.hosts[] | select(.network_id==$NID)] | length")
    if [ "$HOST_COUNT" -gt 0 ]; then
        pass "Network $CIDR (id=$NID) has $HOST_COUNT host(s)"
    else
        fail "Network $CIDR (id=$NID) has hosts" "no hosts reference this network"
    fi
done

echo ""
echo "8. renderTopologyStats COMPUTATION CHECK"
echo "──────────────────────────────────────────"

# The JS computes these from topology data:
#   totalHosts = topology.hosts.length
#   upHosts = topology.hosts.filter(h => h.status === 'up').length
#   totalPorts = topology.hosts.reduce((sum, h) => sum + h.ports.length, 0)
#   openPorts = topology.hosts.reduce((sum, h) => sum + h.ports.filter(p => p.state === 'open').length, 0)

TOTAL_HOSTS=$(echo "$TOPO" | jq '.hosts | length')
UP_HOSTS=$(echo "$TOPO" | jq '[.hosts[] | select(.status=="up")] | length')
TOTAL_PORTS=$(echo "$TOPO" | jq '[.hosts[].ports[]] | length')
OPEN_PORTS=$(echo "$TOPO" | jq '[.hosts[].ports[] | select(.state=="open")] | length')

assert_eq "totalHosts = 8" "8" "$TOTAL_HOSTS"
assert_eq "upHosts = 8" "8" "$UP_HOSTS"
assert_gt "totalPorts > 30" 30 "$TOTAL_PORTS"
assert_gt "openPorts > 20" 20 "$OPEN_PORTS"

echo "  (totalHosts=$TOTAL_HOSTS, upHosts=$UP_HOSTS, totalPorts=$TOTAL_PORTS, openPorts=$OPEN_PORTS)"

echo ""
echo "9. HOST LIST renderHostsList SHAPE"
echo "──────────────────────────────────────────"

HOST_LIST=$(curl -sf "$BASE/api/hosts")
FIRST_LIST_HOST=$(echo "$HOST_LIST" | jq '.[0]')

# renderHostsList accesses: host.id, host.ip_address, host.status, host.hostname, host.os,
#   host.mac_address, host.last_seen
for FIELD in "id" "ip_address" "status" "hostname" "os" "mac_address" "last_seen"; do
    assert_eq "host list item has .$FIELD" "true" \
        "$(echo "$FIRST_LIST_HOST" | jq "has(\"$FIELD\")")"
done

echo ""
echo "10. showHostDetail COMPLETE RENDER PATHS"
echo "──────────────────────────────────────────"

# Test detail for every single host — make sure none crash
ALL_IDS=$(curl -sf "$BASE/api/hosts" | jq -r '.[].id')
for HID in $ALL_IDS; do
    D=$(curl -sf "$BASE/api/hosts/$HID")
    IP=$(echo "$D" | jq -r '.ip_address')
    HAS_PORTS=$(echo "$D" | jq '.ports | length')
    HAS_IP=$(echo "$D" | jq 'has("ip_address")')
    HAS_PORTS_ARR=$(echo "$D" | jq 'has("ports")')
    
    if [ "$HAS_IP" = "true" ] && [ "$HAS_PORTS_ARR" = "true" ]; then
        pass "Host $IP (id=$HID) detail renders ($HAS_PORTS ports)"
    else
        fail "Host $IP (id=$HID) detail renders" "missing ip_address or ports"
    fi
done

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo "  ⚠️  Some tests failed!"
    exit 1
else
    echo "  🎉 ALL FRONTEND CONTRACT TESTS PASSED!"
    exit 0
fi
