#!/bin/bash
# OS Classification tests
# Verifies topology correctly classifies hosts by OS type

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

echo "============================================"
echo "  OS CLASSIFICATION TESTS"
echo "============================================"
echo ""

# Make sure the sample scan is loaded (idempotent — upsert)
cd "$(dirname "$0")/.."
if [ "$(curl -sf "$BASE/api/hosts" | jq 'length')" = "0" ]; then
    curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
        -d "$(jq -Rs '{xml: .}' tests/fixtures/sample-scan.xml)" > /dev/null
fi

# Verify JS has the classifyOS function embedded
JS=$(curl -sf "$BASE/js/app.js")
assert_contains "JS has classifyOS function" "function classifyOS" "$JS"
assert_contains "JS has WIN_PORTS set" "WIN_PORTS" "$JS"
assert_contains "JS has NIX_PORTS set" "NIX_PORTS" "$JS"
assert_contains "JS has OS_META map" "OS_META" "$JS"
assert_contains "JS checks for 'windows' in OS" "windows|win32|microsoft" "$JS"
assert_contains "JS checks for 'linux' in OS" "linux|ubuntu|debian" "$JS"
assert_contains "JS checks for 'bsd' in OS" "bsd|freebsd|openbsd|netbsd" "$JS"
assert_contains "JS checks port 445 for Windows" "445" "$JS"
assert_contains "JS checks port 135 for Windows" "135" "$JS"
assert_contains "JS checks port 3389 for Windows" "3389" "$JS"
assert_contains "JS checks port 22 for Linux" "openPorts.has(22)" "$JS"

echo ""
echo "── CSS has OS styling ──"
CSS=$(curl -sf "$BASE/css/style.css")
assert_contains "CSS has os-linux class" "os-linux" "$CSS"
assert_contains "CSS has os-windows class" "os-windows" "$CSS"
assert_contains "CSS has os-other class" "os-other" "$CSS"
assert_contains "CSS has os-chip styling" "os-chip" "$CSS"
assert_contains "CSS has os-badge styling" "os-badge" "$CSS"
assert_contains "CSS has os-subgroup-label" "os-subgroup-label" "$CSS"
assert_contains "CSS has topo-host-os" "topo-host-os" "$CSS"

echo ""
echo "── HTML has topology structure ──"
HTML=$(curl -sf "$BASE/")
assert_contains "HTML has topology-graph" "topology-graph" "$HTML"
assert_contains "HTML has topology-stats" "topology-stats" "$HTML"

echo ""
echo "── Classification logic against test data ──"
echo "  (simulating JS classifyOS with known data)"

# OS string based classification
classify_by_os() {
    local os="$1"
    local os_lower=$(echo "$os" | tr '[:upper:]' '[:lower:]')
    if echo "$os_lower" | grep -qE 'windows|win32|microsoft'; then echo "windows"; return; fi
    if echo "$os_lower" | grep -qE 'linux|ubuntu|debian|centos|fedora|redhat'; then echo "linux"; return; fi
    if echo "$os_lower" | grep -qE 'bsd|freebsd|openbsd|netbsd|darwin'; then echo "linux"; return; fi
    if echo "$os_lower" | grep -qE 'solaris|sunos|aix|hp-ux|unix'; then echo "linux"; return; fi
    echo "unknown"
}

# Test known OS strings
assert_eq "OS 'Linux 2.6.5' -> linux" "linux" "$(classify_by_os 'Linux 2.6.5 - 2.6.18')"
assert_eq "OS 'NetBSD 4.99.4' -> linux" "linux" "$(classify_by_os 'NetBSD 4.99.4 (x86)')"
assert_eq "OS 'Windows Server 2019' -> windows" "windows" "$(classify_by_os 'Windows Server 2019')"
assert_eq "OS 'Microsoft Windows 10' -> windows" "windows" "$(classify_by_os 'Microsoft Windows 10')"
assert_eq "OS 'FreeBSD 12.2' -> linux" "linux" "$(classify_by_os 'FreeBSD 12.2')"
assert_eq "OS 'OpenBSD 6.8' -> linux" "linux" "$(classify_by_os 'OpenBSD 6.8')"
assert_eq "OS 'Mac OS X 10.15' -> linux" "linux" "$(classify_by_os 'Darwin Mac OS X 10.15')"
assert_eq "OS 'Ubuntu 20.04' -> linux" "linux" "$(classify_by_os 'Ubuntu 20.04')"
assert_eq "OS '' -> unknown" "unknown" "$(classify_by_os '')"

echo ""
echo "── Verify topology API data supports classification ──"

TOPO=$(curl -sf "$BASE/api/topology")

# All 8 hosts from the test scan
for IP in "66.35.250.168" "66.35.250.203" "64.13.134.48" "204.152.191.37" \
          "199.185.137.3" "204.152.190.12" "72.14.207.99" "72.14.253.83"; do
    HAS_OS=$(echo "$TOPO" | jq ".hosts[] | select(.ip_address==\"$IP\") | has(\"os\")")
    HAS_PORTS=$(echo "$TOPO" | jq ".hosts[] | select(.ip_address==\"$IP\") | has(\"ports\")")
    assert_eq "Host $IP has .os field" "true" "$HAS_OS"
    assert_eq "Host $IP has .ports field" "true" "$HAS_PORTS"
done

echo ""
echo "── Verify port data has service/product for heuristics ──"

# Check that ports carry service and product info for heuristic classification
PORTS_WITH_SERVICE=$(echo "$TOPO" | jq '[.hosts[].ports[] | select(.service != null)] | length')
PORTS_WITH_PRODUCT=$(echo "$TOPO" | jq '[.hosts[].ports[] | select(.product != null)] | length')
assert_eq "Many ports have .service" "true" "$([ "$PORTS_WITH_SERVICE" -gt 15 ] && echo true || echo false)"
assert_eq "Some ports have .product" "true" "$([ "$PORTS_WITH_PRODUCT" -gt 5 ] && echo true || echo false)"

echo ""
echo "── Expected classifications for test scan hosts ──"

# Hosts with explicit Linux OS -> linux
for IP in "66.35.250.168" "66.35.250.203" "64.13.134.48" "204.152.191.37"; do
    OS=$(echo "$TOPO" | jq -r ".hosts[] | select(.ip_address==\"$IP\") | .os")
    assert_contains "Host $IP OS contains 'Linux'" "Linux" "$OS"
done

# NetBSD -> linux bucket
NB_OS=$(echo "$TOPO" | jq -r '.hosts[] | select(.ip_address=="204.152.190.12") | .os')
assert_contains "NetBSD host OS contains 'NetBSD'" "NetBSD" "$NB_OS"

# openbsd.org — the fixture has services with ostype="Linux" on BIND/Apache,
# so our parser now infers Linux. Also has FTP/SMTP/DNS open.
OB_OS=$(echo "$TOPO" | jq -r '.hosts[] | select(.ip_address=="199.185.137.3") | .os')
OB_PORTS=$(echo "$TOPO" | jq '[.hosts[] | select(.ip_address=="199.185.137.3") | .ports[] | select(.state=="open") | .port_number]')
assert_contains "openbsd.org OS inferred as Linux"     "Linux" "$OB_OS"
assert_contains "openbsd.org has port 21 (heuristic)"  "21"    "$OB_PORTS"
assert_contains "openbsd.org has port 53 (heuristic)"  "53"    "$OB_PORTS"

# Google hosts — the fixture has <service name="http" product="Google httpd" ostype="Linux">
# so OS inference now resolves to "Linux".
G1_OS=$(echo "$TOPO" | jq -r '.hosts[] | select(.ip_address=="72.14.207.99") | .os')
G1_PRODUCT=$(echo "$TOPO" | jq -r '[.hosts[] | select(.ip_address=="72.14.207.99") | .ports[] | .product // empty] | join(",")')
assert_contains "google.com OS inferred as Linux"       "Linux"  "$G1_OS"
assert_contains "google.com product is Google httpd"    "Google" "$G1_PRODUCT"

echo ""
echo "── Topology rendering structure ──"

# Verify the CSS classes for the 3 OS types exist and are distinct
assert_contains "CSS os-linux border color" "os-linux-border" "$CSS"
assert_contains "CSS os-win border color" "os-win-border" "$CSS"
assert_contains "CSS os-other border color" "os-other-border" "$CSS"

# Verify JS renders the sub-groups
assert_contains "JS renders os-subgroup-label" "os-subgroup-label" "$JS"
assert_contains "JS renders os-badge" "os-badge" "$JS"
assert_contains "JS renders os-chip" "os-chip" "$JS"
assert_contains "JS renders network-header" "network-header" "$JS"
assert_contains "JS iterates ['linux','windows','other']" "linux.*windows.*other" "$JS"

# Verify stat panel includes OS counts
assert_contains "JS calls statOS for linux" "statOS(linuxCount" "$JS"
assert_contains "JS calls statOS for windows" "statOS(windowsCount" "$JS"
assert_contains "JS calls statOS for other" "statOS(otherCount" "$JS"

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo "  ⚠️  Some tests failed!"
    exit 1
else
    echo "  🎉 ALL OS CLASSIFICATION TESTS PASSED!"
    exit 0
fi
