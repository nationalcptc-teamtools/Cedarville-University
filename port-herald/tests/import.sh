#!/bin/bash
# Import / OS inference / port sort tests
# Covers the nmap-fast + nmap-full round-trip and the new client-side
# port sort selector.
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
echo "  IMPORT / OS INFERENCE / PORT SORT"
echo "============================================"
echo ""

# Clean the host that both XMLs target (10.64.177.54)
EXISTING=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"10.64.177.54\") | .id" || echo "")
if [ -n "$EXISTING" ]; then
    curl -s -X DELETE "$BASE/api/hosts/$EXISTING" >/dev/null
fi

FAST_XML="/Users/nick/CPTC/nmap-fast.xml"
FULL_XML="/Users/nick/CPTC/nmap-full.xml"

if [ ! -f "$FAST_XML" ] || [ ! -f "$FULL_XML" ]; then
    echo "Skipping: nmap-fast.xml and nmap-full.xml must live at ~/CPTC/"
    exit 0
fi

echo "1. FAST SCAN IMPORT (no OS, no service version)"
echo "──────────────────────────────────────────"

R=$(curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' "$FAST_XML")")
assert_eq "fast import imports 1 host"  "1" "$(echo "$R" | jq -r '.hosts_imported')"
assert_eq "fast import imports 5 ports" "5" "$(echo "$R" | jq -r '.ports_imported')"

HID=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"10.64.177.54\") | .id")
HOST=$(curl -sf "$BASE/api/hosts/$HID")

assert_eq "host IP captured"       "10.64.177.54" "$(echo "$HOST" | jq -r '.ip_address')"
assert_eq "host status is up"      "up"           "$(echo "$HOST" | jq -r '.status')"
assert_eq "OS is null after fast"  "null"         "$(echo "$HOST" | jq -r '.os')"
assert_eq "network inferred"       "10.64.177.0/24" "$(echo "$HOST" | jq -r '.network_id as $n | $n' > /dev/null && curl -sf "$BASE/api/networks" | jq -r ".[] | select(.cidr==\"10.64.177.0/24\") | .cidr")"

# Specific states from the fast scan
STATES=$(echo "$HOST" | jq -c '[.ports[] | {p: .port_number, s: .state}]')
assert_contains "port 21 open"      '{"p":21,"s":"open"}'   "$STATES"
assert_contains "port 22 open"      '{"p":22,"s":"open"}'   "$STATES"
assert_contains "port 80 open"      '{"p":80,"s":"open"}'   "$STATES"
assert_contains "port 8000 open"    '{"p":8000,"s":"open"}' "$STATES"
assert_contains "port 8080 closed"  '{"p":8080,"s":"closed"}' "$STATES"

echo ""
echo "2. FULL SCAN IMPORT (service -sV, extracts OS from ostype + extrainfo)"
echo "──────────────────────────────────────────"

R=$(curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' "$FULL_XML")")
assert_eq "full import imports 1 host"   "1" "$(echo "$R" | jq -r '.hosts_imported')"
assert_gt "full import imports more ports" 10 "$(echo "$R" | jq -r '.ports_imported')"
assert_gt "full import imports scripts"    5  "$(echo "$R" | jq -r '.scripts_imported')"

HOST=$(curl -sf "$BASE/api/hosts/$HID")
OS=$(echo "$HOST" | jq -r '.os')
assert_contains "OS now inferred as Linux (Ubuntu)" "Linux (Ubuntu)" "$OS"

# ssh now has product/version
SSH=$(echo "$HOST" | jq '.ports[] | select(.port_number==22)')
assert_eq "ssh product=OpenSSH" "OpenSSH" "$(echo "$SSH" | jq -r '.product')"
assert_contains "ssh version mentions Ubuntu" "Ubuntu" "$(echo "$SSH" | jq -r '.version')"

# ftp vsftpd
FTP=$(echo "$HOST" | jq '.ports[] | select(.port_number==21)')
assert_eq "ftp product=vsftpd" "vsftpd" "$(echo "$FTP" | jq -r '.product')"
assert_eq "ftp version=3.0.3"  "3.0.3"  "$(echo "$FTP" | jq -r '.version')"

# Apache
APACHE=$(echo "$HOST" | jq '.ports[] | select(.port_number==8000)')
assert_eq "port 8000 product=Apache httpd" "Apache httpd" "$(echo "$APACHE" | jq -r '.product')"

# Scripts attached to ports
SCRIPTS_ON_FTP=$(echo "$HOST" | jq '[.ports[] | select(.port_number==21) | .scripts[]] | length')
assert_gt "ftp-anon script attached to port 21" 0 "$SCRIPTS_ON_FTP"

echo ""
echo "3. DATA COMBINING (upsert semantics across the two imports)"
echo "──────────────────────────────────────────"

PORTS=$(curl -sf "$BASE/api/hosts/$HID" | jq '.ports | length')
assert_gt "host now has >=16 ports total" 15 "$PORTS"

# Fast scan had port 21 with service=ftp, no product. Full upgraded it.
assert_eq "port 21 service was upgraded"  "ftp"    "$(curl -sf "$BASE/api/hosts/$HID" | jq -r '.ports[] | select(.port_number==21) | .service')"
assert_eq "port 21 product was upgraded"  "vsftpd" "$(curl -sf "$BASE/api/hosts/$HID" | jq -r '.ports[] | select(.port_number==21) | .product')"

# Ports from only full scan (20, 50000+) exist
FULL_ONLY=$(curl -sf "$BASE/api/hosts/$HID" | jq '[.ports[] | select(.port_number==20 or .port_number==50000 or .port_number==50500)] | length')
assert_eq "full-scan-only ports present" "3" "$FULL_ONLY"

echo ""
echo "4. OPPOSITE ORDER (full first, then fast — must not clobber good data)"
echo "──────────────────────────────────────────"

# Delete and re-run reversed
curl -s -X DELETE "$BASE/api/hosts/$HID" >/dev/null
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' "$FULL_XML")" >/dev/null
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' "$FAST_XML")" >/dev/null

HID2=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"10.64.177.54\") | .id")
HOST2=$(curl -sf "$BASE/api/hosts/$HID2")

# OS should STILL be Linux (Ubuntu) \u2014 fast scan has no OS data,
# so it must not overwrite the good one we already had.
assert_contains "OS survives fast re-import" "Linux (Ubuntu)" "$(echo "$HOST2" | jq -r '.os')"

# Port 21 should keep its vsftpd product/version
assert_eq "port 21 product preserved" "vsftpd" "$(echo "$HOST2" | jq -r '.ports[] | select(.port_number==21) | .product')"
assert_eq "port 21 version preserved" "3.0.3"  "$(echo "$HOST2" | jq -r '.ports[] | select(.port_number==21) | .version')"

echo ""
echo "5. PARSER OS-INFERENCE PRIORITIES"
echo "──────────────────────────────────────────"

# Craft a minimal XML with only an osmatch, make sure that wins
XML_OSMATCH='<nmaprun><host><status state="up"/><address addr="10.99.99.1" addrtype="ipv4"/>
<ports><port protocol="tcp" portid="22"><state state="open"/><service name="ssh" product="OpenSSH" ostype="Linux" extrainfo="Ubuntu Linux" method="probed" conf="10"/></port></ports>
<os><osmatch name="Linux 5.4" accuracy="98"/></os></host></nmaprun>'
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rsn --arg x "$XML_OSMATCH" '{xml:$x}')" >/dev/null
MATCH_HOST=$(curl -sf "$BASE/api/hosts" | jq -r '.[] | select(.ip_address=="10.99.99.1") | {os,acc:.os_accuracy}')
assert_eq "osmatch wins over service hint" "Linux 5.4" "$(echo "$MATCH_HOST" | jq -r .os)"
assert_eq "osmatch accuracy captured"      "98"        "$(echo "$MATCH_HOST" | jq -r .acc)"

# Service with ostype=Linux and extrainfo (Debian) should resolve to "Linux (Debian)"
XML_SVC='<nmaprun><host><status state="up"/><address addr="10.99.99.2" addrtype="ipv4"/>
<ports><port protocol="tcp" portid="80"><state state="open"/><service name="http" product="Apache" ostype="Linux" extrainfo="(Debian)" method="probed" conf="10"/></port></ports></host></nmaprun>'
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rsn --arg x "$XML_SVC" '{xml:$x}')" >/dev/null
assert_eq "service with distro infers correctly" "Linux (Debian)" \
    "$(curl -sf "$BASE/api/hosts" | jq -r '.[] | select(.ip_address=="10.99.99.2") | .os')"

# A service with ONLY ostype=Unix (no distro) should fall back to "Unix"
XML_UNIX='<nmaprun><host><status state="up"/><address addr="10.99.99.3" addrtype="ipv4"/>
<ports><port protocol="tcp" portid="21"><state state="open"/><service name="ftp" product="vsftpd" ostype="Unix" method="probed" conf="10"/></port></ports></host></nmaprun>'
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rsn --arg x "$XML_UNIX" '{xml:$x}')" >/dev/null
assert_eq "service ostype=Unix only -> \"Unix\"" "Unix" \
    "$(curl -sf "$BASE/api/hosts" | jq -r '.[] | select(.ip_address=="10.99.99.3") | .os')"

# No OS data at all → NULL
XML_NONE='<nmaprun><host><status state="up"/><address addr="10.99.99.4" addrtype="ipv4"/>
<ports><port protocol="tcp" portid="80"><state state="open"/><service name="http" method="table" conf="3"/></port></ports></host></nmaprun>'
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rsn --arg x "$XML_NONE" '{xml:$x}')" >/dev/null
assert_eq "no hints → null" "null" \
    "$(curl -sf "$BASE/api/hosts" | jq -r '.[] | select(.ip_address=="10.99.99.4") | .os')"

# Cleanup synthetic test hosts
for IP in 10.99.99.1 10.99.99.2 10.99.99.3 10.99.99.4; do
    ID=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"$IP\") | .id")
    [ -n "$ID" ] && curl -s -X DELETE "$BASE/api/hosts/$ID" >/dev/null
done

echo ""
echo "6. CLIENT-SIDE PORT SORT (frontend wiring)"
echo "──────────────────────────────────────────"

JS=$(curl -sf "$BASE/js/app.js")
HTML=$(curl -sf "$BASE/")
CSS=$(curl -sf "$BASE/css/style.css")

assert_contains "JS defines PORT_STATE_RANK"              "PORT_STATE_RANK"           "$JS"
assert_contains "JS ranks 'open' lowest"                  "'open':             0"     "$JS"
assert_contains "JS ranks 'open|filtered' second"         "'open|filtered':    1"     "$JS"
assert_contains "JS ranks 'filtered' third"               "'filtered':         3"     "$JS"
assert_contains "JS ranks 'closed' last"                  "'closed':           5"     "$JS"
assert_contains "JS defines sortPorts()"                  "function sortPorts"        "$JS"
assert_contains "JS has 'availability' sort mode"         "case 'availability':"      "$JS"
assert_contains "JS has 'number' sort mode"               "case 'number':"            "$JS"
assert_contains "JS has 'service' sort mode"              "case 'service':"           "$JS"
assert_contains "JS renders port-sort-mode selector"      'id="port-sort-mode"'       "$JS"
assert_contains "JS wires the sort selector"              "port-sort-mode"            "$JS"
assert_contains "JS persists sort choice"                 "ph-port-sort"              "$JS"
assert_contains "JS adds data-state to port cards"        'data-state="'              "$JS"
assert_contains "JS has ports-list-container"             "ports-list-container"      "$JS"

assert_contains "CSS .ports-header styled"                ".ports-header"             "$CSS"
assert_contains "CSS .port-sort-label styled"             ".port-sort-label"          "$CSS"
assert_contains "CSS covers open|filtered"                'host-status\[class\*="open|filtered"\]' "$CSS"
assert_contains "CSS covers closed|filtered"              'host-status\[class\*="closed|filtered"\]' "$CSS"
assert_contains "CSS has .host-status.unfiltered"         ".host-status.unfiltered"   "$CSS"

echo ""
echo "7. SORT LOGIC CORRECTNESS (via local jq simulation)"
echo "──────────────────────────────────────────"

# Re-import both files to get the realistic port mix
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' "$FAST_XML")" >/dev/null
curl -sf -X POST "$BASE/api/import" -H "Content-Type: application/json" \
    -d "$(jq -Rs '{"xml": .}' "$FULL_XML")" >/dev/null

HID3=$(curl -sf "$BASE/api/hosts" | jq ".[] | select(.ip_address==\"10.64.177.54\") | .id")

# jq-simulate the availability sort — open first, then closed, break by port number
EXPECTED_FIRST=$(curl -sf "$BASE/api/hosts/$HID3" | jq -r \
    '[.ports[] | {p: .port_number, s: .state}]
    | sort_by(if .s == "open" then 0
              elif .s == "open|filtered" then 1
              elif .s == "unfiltered" then 2
              elif .s == "filtered" then 3
              elif .s == "closed|filtered" then 4
              elif .s == "closed" then 5 else 99 end,
              .p)
    | .[0]
    | "\(.p) \(.s)"')
assert_eq "availability-sort: smallest open port first" "21 open" "$EXPECTED_FIRST"

# Number sort: port 20 (ftp-data closed) is smallest
EXPECTED_NUM=$(curl -sf "$BASE/api/hosts/$HID3" | jq -r \
    '[.ports[]] | sort_by(.port_number) | .[0] | .port_number')
assert_eq "number-sort: port 20 is first" "20" "$EXPECTED_NUM"

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then echo "  ⚠️  Some tests failed!"; exit 1
else echo "  🎉 ALL IMPORT / SORT TESTS PASSED!"; exit 0; fi
