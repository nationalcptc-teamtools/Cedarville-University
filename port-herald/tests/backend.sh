#!/bin/bash
# Comprehensive Port Herald test suite
# Tests all functionality against the example Nmap scan

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

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    local tmp; tmp=$(mktemp); printf '%s' "$haystack" > "$tmp"
    if grep -q -- "$needle" "$tmp"; then pass "$label"
    else fail "$label" "expected to contain '$needle'"; fi
    rm -f "$tmp"
}

assert_gt() {
    local label="$1" threshold="$2" actual="$3"
    if [ "$actual" -gt "$threshold" ] 2>/dev/null; then pass "$label"
    else fail "$label" "expected > $threshold, got '$actual'"; fi
}

echo "============================================"
echo "  PORT HERALD COMPREHENSIVE TEST SUITE"
echo "============================================"
echo ""

# ──────────────────────────────────────────────
echo "1. HEALTH & STATIC ASSETS"
echo "──────────────────────────────────────────"

# 1a. Health endpoint
HEALTH=$(curl -sf "$BASE/api/health")
assert_eq "Health endpoint returns ok" "ok" "$(echo "$HEALTH" | jq -r '.status')"
assert_eq "Version is 0.1.0" "0.1.0" "$(echo "$HEALTH" | jq -r '.version')"

# 1b. Static files
HTTP_INDEX=$(curl -so /dev/null -w "%{http_code}" "$BASE/")
assert_eq "index.html serves (200)" "200" "$HTTP_INDEX"

HTTP_CSS=$(curl -so /dev/null -w "%{http_code}" "$BASE/css/style.css")
assert_eq "style.css serves (200)" "200" "$HTTP_CSS"

HTTP_JS=$(curl -so /dev/null -w "%{http_code}" "$BASE/js/app.js")
assert_eq "app.js serves (200)" "200" "$HTTP_JS"

# 1c. Verify HTML content
INDEX_BODY=$(curl -sf "$BASE/")
assert_contains "HTML has Port Herald title" "Port Herald" "$INDEX_BODY"
assert_contains "HTML has topology tab" 'data-tab="topology"' "$INDEX_BODY"
assert_contains "HTML has hosts tab" 'data-tab="hosts"' "$INDEX_BODY"
assert_contains "HTML has scanner tab" 'data-tab="scanner"' "$INDEX_BODY"
assert_contains "HTML has import tab" 'data-tab="import"' "$INDEX_BODY"

# ──────────────────────────────────────────────
echo ""
echo "2. EMPTY STATE (pre-import)"
echo "──────────────────────────────────────────"

HOSTS_EMPTY=$(curl -sf "$BASE/api/hosts")
assert_eq "Hosts empty before import" "0" "$(echo "$HOSTS_EMPTY" | jq 'length')"

NETS_EMPTY=$(curl -sf "$BASE/api/networks")
assert_eq "Networks empty before import" "0" "$(echo "$NETS_EMPTY" | jq 'length')"

TOPO_EMPTY=$(curl -sf "$BASE/api/topology")
assert_eq "Topology hosts empty" "0" "$(echo "$TOPO_EMPTY" | jq '.hosts | length')"
assert_eq "Topology networks empty" "0" "$(echo "$TOPO_EMPTY" | jq '.networks | length')"

SCANS_EMPTY=$(curl -sf "$BASE/api/scans")
assert_eq "Scans empty before import" "0" "$(echo "$SCANS_EMPTY" | jq 'length')"

# ──────────────────────────────────────────────
echo ""
echo "3. IMPORT – Full Nmap XML"
echo "──────────────────────────────────────────"

IMPORT_RESULT=$(curl -sf -X POST "$BASE/api/import" \
  -H "Content-Type: application/json" \
  -d "$(jq -Rs '{"xml": .}' tests/fixtures/sample-scan.xml)")

assert_eq "Import status is success" "success" "$(echo "$IMPORT_RESULT" | jq -r '.status')"
assert_eq "Imported 8 hosts" "8" "$(echo "$IMPORT_RESULT" | jq -r '.hosts_imported')"
assert_gt "Imported ports > 30" 30 "$(echo "$IMPORT_RESULT" | jq -r '.ports_imported')"
assert_gt "Imported scripts > 15" 15 "$(echo "$IMPORT_RESULT" | jq -r '.scripts_imported')"

PORTS_COUNT=$(echo "$IMPORT_RESULT" | jq -r '.ports_imported')
SCRIPTS_COUNT=$(echo "$IMPORT_RESULT" | jq -r '.scripts_imported')

echo "  (imported $PORTS_COUNT ports, $SCRIPTS_COUNT scripts)"

# ──────────────────────────────────────────────
echo ""
echo "4. HOSTS LIST"
echo "──────────────────────────────────────────"

ALL_HOSTS=$(curl -sf "$BASE/api/hosts")
assert_eq "8 hosts in database" "8" "$(echo "$ALL_HOSTS" | jq 'length')"

# Verify each host exists
for IP in "66.35.250.168" "66.35.250.203" "64.13.134.48" "204.152.191.37" \
          "199.185.137.3" "204.152.190.12" "72.14.207.99" "72.14.253.83"; do
    FOUND=$(echo "$ALL_HOSTS" | jq -r "[.[] | select(.ip_address==\"$IP\")] | length")
    assert_eq "Host $IP exists" "1" "$FOUND"
done

# Verify hostnames
assert_eq "freshmeat.net hostname" "freshmeat.net" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="66.35.250.168") | .hostname')"
assert_eq "sourceforge.net hostname" "sourceforge.net" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="66.35.250.203") | .hostname')"
assert_eq "kernel.org hostname" "pub2.kernel.org" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="204.152.191.37") | .hostname')"
assert_eq "openbsd.org hostname" "cvs.openbsd.org" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="199.185.137.3") | .hostname')"
assert_eq "netbsd.org hostname" "www.netbsd.org" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="204.152.190.12") | .hostname')"
assert_eq "google.com hostname" "eh-in-f99.google.com" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="72.14.207.99") | .hostname')"
assert_eq "gmail.com hostname" "po-in-f83.google.com" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="72.14.253.83") | .hostname')"

# Verify all hosts are up
ALL_UP=$(echo "$ALL_HOSTS" | jq '[.[] | select(.status=="up")] | length')
assert_eq "All 8 hosts status=up" "8" "$ALL_UP"

# Verify OS detection
assert_eq "freshmeat OS detected" "Linux 2.6.5 - 2.6.18" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="66.35.250.168") | .os')"
assert_eq "nmap.org OS 100% accuracy" "100" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="64.13.134.48") | .os_accuracy')"
assert_eq "netbsd OS detected" "NetBSD 4.99.4 (x86)" \
    "$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="204.152.190.12") | .os')"

# ──────────────────────────────────────────────
echo ""
echo "5. NETWORKS"
echo "──────────────────────────────────────────"

ALL_NETS=$(curl -sf "$BASE/api/networks")
assert_eq "7 networks detected" "7" "$(echo "$ALL_NETS" | jq 'length')"

# Verify specific networks
for CIDR in "66.35.250.0/24" "64.13.134.0/24" "204.152.191.0/24" \
            "199.185.137.0/24" "204.152.190.0/24" "72.14.207.0/24" "72.14.253.0/24"; do
    FOUND=$(echo "$ALL_NETS" | jq -r "[.[] | select(.cidr==\"$CIDR\")] | length")
    assert_eq "Network $CIDR exists" "1" "$FOUND"
done

# Verify freshmeat + sourceforge share a network
FM_NET=$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="66.35.250.168") | .network_id')
SF_NET=$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="66.35.250.203") | .network_id')
assert_eq "freshmeat+sourceforge same network" "$FM_NET" "$SF_NET"

# ──────────────────────────────────────────────
echo ""
echo "6. HOST DETAIL – freshmeat.net (66.35.250.168)"
echo "──────────────────────────────────────────"

FM_ID=$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="66.35.250.168") | .id')
FM_DETAIL=$(curl -sf "$BASE/api/hosts/$FM_ID")
FM_PORTS=$(echo "$FM_DETAIL" | jq '.ports | length')

assert_eq "freshmeat has 2 ports" "2" "$FM_PORTS"
assert_eq "freshmeat port 80 open" "open" \
    "$(echo "$FM_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .state')"
assert_eq "freshmeat port 80 service=http" "http" \
    "$(echo "$FM_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .service')"
assert_eq "freshmeat port 80 product=Apache" "Apache httpd" \
    "$(echo "$FM_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .product')"
assert_eq "freshmeat port 80 version=1.3.39" "1.3.39" \
    "$(echo "$FM_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .version')"
assert_eq "freshmeat port 80 extrainfo" "(Unix) PHP/4.4.7" \
    "$(echo "$FM_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .extra_info')"
assert_eq "freshmeat port 443 closed" "closed" \
    "$(echo "$FM_DETAIL" | jq -r '.ports[] | select(.port_number==443) | .state')"

# Scripts on port 80
FM_SCRIPTS=$(echo "$FM_DETAIL" | jq '[.ports[] | select(.port_number==80) | .scripts[].script_name]')
assert_contains "freshmeat has robots.txt script" "robots.txt" "$FM_SCRIPTS"
assert_contains "freshmeat has HTML title script" "HTML title" "$FM_SCRIPTS"

FM_TITLE=$(echo "$FM_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .scripts[] | select(.script_name=="HTML title") | .output')
assert_contains "freshmeat HTML title correct" "freshmeat.net" "$FM_TITLE"

# ──────────────────────────────────────────────
echo ""
echo "7. HOST DETAIL – kernel.org (204.152.191.37)"
echo "──────────────────────────────────────────"

KO_ID=$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="204.152.191.37") | .id')
KO_DETAIL=$(curl -sf "$BASE/api/hosts/$KO_ID")
KO_PORTS=$(echo "$KO_DETAIL" | jq '.ports | length')

assert_eq "kernel.org has 10 ports" "10" "$KO_PORTS"
assert_eq "kernel.org port 21 ftp" "ftp" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==21) | .service')"
assert_eq "kernel.org port 22 ssh" "ssh" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==22) | .service')"
assert_eq "kernel.org port 79 finger" "finger" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==79) | .service')"
assert_eq "kernel.org port 199 smux" "smux" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==199) | .service')"
assert_eq "kernel.org port 873 rsync" "rsync" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==873) | .service')"
assert_eq "kernel.org port 1720 filtered" "filtered" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==1720) | .state')"
assert_eq "kernel.org port 5978 open" "open" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==5978) | .state')"
assert_eq "kernel.org port 7000 open" "open" \
    "$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==7000) | .state')"

# Anonymous FTP script
KO_FTP_SCRIPT=$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==21) | .scripts[] | select(.script_name=="Anonymous FTP") | .output')
assert_contains "kernel.org Anonymous FTP script" "Anonymous login allowed" "$KO_FTP_SCRIPT"

# HTML title
KO_TITLE=$(echo "$KO_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .scripts[] | select(.script_name=="HTML title") | .output')
assert_contains "kernel.org title = Linux Kernel Archives" "Linux Kernel Archives" "$KO_TITLE"

# ──────────────────────────────────────────────
echo ""
echo "8. HOST DETAIL – openbsd.org (199.185.137.3)"
echo "──────────────────────────────────────────"

OB_ID=$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="199.185.137.3") | .id')
OB_DETAIL=$(curl -sf "$BASE/api/hosts/$OB_ID")
OB_PORTS=$(echo "$OB_DETAIL" | jq '.ports | length')

assert_eq "openbsd has 5 ports" "5" "$OB_PORTS"
assert_eq "openbsd port 25 smtp" "smtp" \
    "$(echo "$OB_DETAIL" | jq -r '.ports[] | select(.port_number==25) | .service')"
assert_eq "openbsd port 53 domain" "domain" \
    "$(echo "$OB_DETAIL" | jq -r '.ports[] | select(.port_number==53) | .service')"
assert_eq "openbsd port 53 product=ISC BIND" "ISC BIND" \
    "$(echo "$OB_DETAIL" | jq -r '.ports[] | select(.port_number==53) | .product')"
assert_eq "openbsd port 7326 icb" "icb" \
    "$(echo "$OB_DETAIL" | jq -r '.ports[] | select(.port_number==7326) | .service')"

# Zone transfer script
OB_ZT=$(echo "$OB_DETAIL" | jq -r '.ports[] | select(.port_number==53) | .scripts[] | select(.script_name=="zone-transfer") | .output')
assert_contains "openbsd zone-transfer script exists" "openbsd.org" "$OB_ZT"

# ──────────────────────────────────────────────
echo ""
echo "9. HOST DETAIL – netbsd.org (204.152.190.12)"
echo "──────────────────────────────────────────"

NB_ID=$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="204.152.190.12") | .id')
NB_DETAIL=$(curl -sf "$BASE/api/hosts/$NB_ID")
NB_PORTS=$(echo "$NB_DETAIL" | jq '.ports | length')

assert_eq "netbsd has 9 ports" "9" "$NB_PORTS"
assert_eq "netbsd port 871 supfilesrv" "supfilesrv" \
    "$(echo "$NB_DETAIL" | jq -r '.ports[] | select(.port_number==871) | .service')"
assert_eq "netbsd port 874 rsync" "rsync" \
    "$(echo "$NB_DETAIL" | jq -r '.ports[] | select(.port_number==874) | .service')"
assert_eq "netbsd port 1984 tcpwrapped" "tcpwrapped" \
    "$(echo "$NB_DETAIL" | jq -r '.ports[] | select(.port_number==1984) | .service')"
assert_eq "netbsd port 2022 ssh" "ssh" \
    "$(echo "$NB_DETAIL" | jq -r '.ports[] | select(.port_number==2022) | .service')"
assert_eq "netbsd port 2022 version=4.4" "4.4" \
    "$(echo "$NB_DETAIL" | jq -r '.ports[] | select(.port_number==2022) | .version')"

# SSLv2 on 443
NB_SSLV2=$(echo "$NB_DETAIL" | jq -r '.ports[] | select(.port_number==443) | .scripts[] | select(.script_name=="SSLv2") | .output')
assert_contains "netbsd SSLv2 script on 443" "SSLv2" "$NB_SSLV2"

# ──────────────────────────────────────────────
echo ""
echo "10. HOST DETAIL – google.com (72.14.207.99)"
echo "──────────────────────────────────────────"

G_ID=$(echo "$ALL_HOSTS" | jq -r '.[] | select(.ip_address=="72.14.207.99") | .id')
G_DETAIL=$(curl -sf "$BASE/api/hosts/$G_ID")
G_PORTS=$(echo "$G_DETAIL" | jq '.ports | length')

assert_eq "google has 4 ports" "4" "$G_PORTS"
assert_eq "google port 80 product=Google httpd" "Google httpd" \
    "$(echo "$G_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .product')"
assert_eq "google port 80 version=1.3" "1.3" \
    "$(echo "$G_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .version')"
assert_eq "google port 80 extrainfo=GFE" "GFE" \
    "$(echo "$G_DETAIL" | jq -r '.ports[] | select(.port_number==80) | .extra_info')"
assert_eq "google port 113 closed" "closed" \
    "$(echo "$G_DETAIL" | jq -r '.ports[] | select(.port_number==113) | .state')"
assert_eq "google port 179 closed" "closed" \
    "$(echo "$G_DETAIL" | jq -r '.ports[] | select(.port_number==179) | .state')"

# ──────────────────────────────────────────────
echo ""
echo "11. TOPOLOGY ENDPOINT"
echo "──────────────────────────────────────────"

TOPO=$(curl -sf "$BASE/api/topology")

assert_eq "Topology has 7 networks" "7" "$(echo "$TOPO" | jq '.networks | length')"
assert_eq "Topology has 8 hosts" "8" "$(echo "$TOPO" | jq '.hosts | length')"

# Every host in topology has ports
for IP in "66.35.250.168" "66.35.250.203" "64.13.134.48" "204.152.191.37" \
          "199.185.137.3" "204.152.190.12" "72.14.207.99" "72.14.253.83"; do
    PCOUNT=$(echo "$TOPO" | jq "[.hosts[] | select(.ip_address==\"$IP\") | .ports | length] | .[0]")
    assert_gt "Topology $IP has ports" 0 "$PCOUNT"
done

# Topology scripts present
TOPO_SCRIPT_COUNT=$(echo "$TOPO" | jq '[.hosts[].ports[].scripts[]?] | length')
assert_gt "Topology includes scripts" 10 "$TOPO_SCRIPT_COUNT"

# ──────────────────────────────────────────────
echo ""
echo "12. RE-IMPORT (upsert – no duplicates)"
echo "──────────────────────────────────────────"

REIMPORT=$(curl -sf -X POST "$BASE/api/import" \
  -H "Content-Type: application/json" \
  -d "$(jq -Rs '{"xml": .}' tests/fixtures/sample-scan.xml)")

assert_eq "Re-import status success" "success" "$(echo "$REIMPORT" | jq -r '.status')"

HOSTS_AFTER=$(curl -sf "$BASE/api/hosts" | jq 'length')
assert_eq "Still 8 hosts after re-import" "8" "$HOSTS_AFTER"

NETS_AFTER=$(curl -sf "$BASE/api/networks" | jq 'length')
assert_eq "Still 7 networks after re-import" "7" "$NETS_AFTER"

# Verify port count stayed the same via direct DB query
PORT_COUNT_DB=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports;")
assert_eq "Port count unchanged ($PORTS_COUNT)" "$PORTS_COUNT" "$PORT_COUNT_DB"

# ──────────────────────────────────────────────
echo ""
echo "13. PROGRESSIVE UPDATE – partial re-scan with new data"
echo "──────────────────────────────────────────"

# Simulate a follow-up scan that updates one host with a new port
cat > /tmp/update_scan.xml << 'XMLEOF'
<?xml version="1.0"?>
<nmaprun scanner="nmap" args="nmap -sV -p8080 66.35.250.168" start="1701000000" version="7.94" xmloutputversion="1.06">
<host><status state="up" reason="syn-ack"/>
<address addr="66.35.250.168" addrtype="ipv4"/>
<hostnames><hostname name="freshmeat.net" type="PTR"/></hostnames>
<ports>
<port protocol="tcp" portid="8080"><state state="open" reason="syn-ack" reason_ttl="45"/><service name="http-proxy" product="Squid" version="3.1.23" method="probed" conf="10"/></port>
</ports>
<os><osmatch name="Linux 2.6.32" accuracy="96"/></os>
</host>
</nmaprun>
XMLEOF

UPDATE_RESULT=$(curl -sf -X POST "$BASE/api/import" \
  -H "Content-Type: application/json" \
  -d "$(jq -Rs '{"xml": .}' /tmp/update_scan.xml)")

assert_eq "Update import success" "success" "$(echo "$UPDATE_RESULT" | jq -r '.status')"
assert_eq "Update imported 1 host" "1" "$(echo "$UPDATE_RESULT" | jq -r '.hosts_imported')"
assert_eq "Update imported 1 port" "1" "$(echo "$UPDATE_RESULT" | jq -r '.ports_imported')"

# Verify the host was updated, not duplicated
HOSTS_AFTER_UPDATE=$(curl -sf "$BASE/api/hosts" | jq 'length')
assert_eq "Still 8 hosts after update" "8" "$HOSTS_AFTER_UPDATE"

# Verify the new port is present
FM_DETAIL_UPDATED=$(curl -sf "$BASE/api/hosts/$FM_ID")
FM_8080=$(echo "$FM_DETAIL_UPDATED" | jq -r '.ports[] | select(.port_number==8080) | .service')
assert_eq "freshmeat now has port 8080" "http-proxy" "$FM_8080"

FM_8080_PRODUCT=$(echo "$FM_DETAIL_UPDATED" | jq -r '.ports[] | select(.port_number==8080) | .product')
assert_eq "freshmeat 8080 product=Squid" "Squid" "$FM_8080_PRODUCT"

# Verify old ports are still there
FM_80_STILL=$(echo "$FM_DETAIL_UPDATED" | jq -r '.ports[] | select(.port_number==80) | .service')
assert_eq "freshmeat still has port 80" "http" "$FM_80_STILL"

# Verify OS was updated (higher accuracy)
FM_OS_UPDATED=$(curl -sf "$BASE/api/hosts" | jq -r '.[] | select(.ip_address=="66.35.250.168") | .os')
assert_eq "freshmeat OS updated to newer" "Linux 2.6.32" "$FM_OS_UPDATED"

# ──────────────────────────────────────────────
echo ""
echo "14. ERROR HANDLING"
echo "──────────────────────────────────────────"

# Invalid host ID
HTTP_404=$(curl -so /dev/null -w "%{http_code}" "$BASE/api/hosts/99999")
assert_eq "Non-existent host returns 404" "404" "$HTTP_404"

# Invalid XML
BAD_IMPORT=$(curl -sf -X POST "$BASE/api/import" \
  -H "Content-Type: application/json" \
  -d '{"xml": "this is not xml at all"}')
assert_eq "Bad XML import still succeeds (0 hosts)" "success" "$(echo "$BAD_IMPORT" | jq -r '.status')"
assert_eq "Bad XML imports 0 hosts" "0" "$(echo "$BAD_IMPORT" | jq -r '.hosts_imported')"

# Empty XML
EMPTY_IMPORT=$(curl -sf -X POST "$BASE/api/import" \
  -H "Content-Type: application/json" \
  -d '{"xml": "<?xml version=\"1.0\"?><nmaprun></nmaprun>"}')
assert_eq "Empty XML import succeeds" "success" "$(echo "$EMPTY_IMPORT" | jq -r '.status')"
assert_eq "Empty XML imports 0 hosts" "0" "$(echo "$EMPTY_IMPORT" | jq -r '.hosts_imported')"

# Missing body
HTTP_BAD=$(curl -so /dev/null -w "%{http_code}" -X POST "$BASE/api/import" \
  -H "Content-Type: application/json" -d '{}')
# Should be 400 or similar
assert_contains "Missing xml field returns 4xx" "4" "$HTTP_BAD"

# ──────────────────────────────────────────────
echo ""
echo "15. DATABASE INTEGRITY"
echo "──────────────────────────────────────────"

# Foreign keys
ORPHAN_PORTS=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports WHERE host_id NOT IN (SELECT id FROM hosts);")
assert_eq "No orphan ports" "0" "$ORPHAN_PORTS"

ORPHAN_SCRIPTS=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM script_results WHERE port_id NOT IN (SELECT id FROM ports);")
assert_eq "No orphan scripts" "0" "$ORPHAN_SCRIPTS"

# All hosts have network_id
NULL_NET=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM hosts WHERE network_id IS NULL;")
assert_eq "All hosts have a network" "0" "$NULL_NET"

# Unique constraints
DUP_HOSTS=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) - COUNT(DISTINCT ip_address) FROM hosts;")
assert_eq "No duplicate hosts" "0" "$DUP_HOSTS"

DUP_PORTS=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM (SELECT host_id, port_number, protocol, COUNT(*) c FROM ports GROUP BY host_id, port_number, protocol HAVING c > 1);")
assert_eq "No duplicate ports" "0" "$DUP_PORTS"

DUP_NETS=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) - COUNT(DISTINCT cidr) FROM networks;")
assert_eq "No duplicate networks" "0" "$DUP_NETS"

# Timestamps are valid ISO format
BAD_TS=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM hosts WHERE first_seen NOT LIKE '20%T%';")
assert_eq "All host timestamps valid RFC3339" "0" "$BAD_TS"

# ──────────────────────────────────────────────
echo ""
echo "16. PORT STATE COVERAGE"
echo "──────────────────────────────────────────"

OPEN_COUNT=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports WHERE state='open';")
CLOSED_COUNT=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports WHERE state='closed';")
FILTERED_COUNT=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports WHERE state='filtered';")

assert_gt "Has open ports" 20 "$OPEN_COUNT"
assert_gt "Has closed ports" 5 "$CLOSED_COUNT"
assert_gt "Has filtered ports" 0 "$FILTERED_COUNT"

echo "  (open=$OPEN_COUNT, closed=$CLOSED_COUNT, filtered=$FILTERED_COUNT)"

# ──────────────────────────────────────────────
echo ""
echo "17. SERVICE DIVERSITY"
echo "──────────────────────────────────────────"

UNIQUE_SERVICES=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(DISTINCT service) FROM ports WHERE service IS NOT NULL;")
assert_gt "Multiple unique services" 8 "$UNIQUE_SERVICES"

# Spot-check key services
for SVC in "http" "ssh" "ftp" "smtp" "domain" "rsync" "https"; do
    SVC_EXISTS=$(sqlite3 /tmp/port-herald_test.db "SELECT COUNT(*) FROM ports WHERE service='$SVC';")
    assert_gt "Service '$SVC' exists" 0 "$SVC_EXISTS"
done

# ──────────────────────────────────────────────
echo ""
echo "18. SCANNER CONFIG (API shape)"
echo "──────────────────────────────────────────"

# Test that the scan endpoint accepts valid config (won't run nmap, but validates shape)
SCAN_RESP=$(curl -sf -X POST "$BASE/api/scans" \
  -H "Content-Type: application/json" \
  -d '{
    "targets": ["192.168.1.0/24"],
    "excluded_targets": ["192.168.1.1"],
    "scan_type": "syn",
    "timing_template": "Normal",
    "version_detection": true,
    "os_detection": false,
    "script_scan": true,
    "udp_scan": false,
    "evasion_enabled": false,
    "source_port": null,
    "dns_servers": [],
    "max_rate": null
  }')

assert_contains "Scan API returns scan_id" "scan_id" "$SCAN_RESP"
SCAN_ID=$(echo "$SCAN_RESP" | jq -r '.scan_id')

# Check scan status endpoint
SCAN_STATUS=$(curl -sf "$BASE/api/scans/$SCAN_ID/status")
assert_contains "Scan status has phase" "phase" "$SCAN_STATUS"
assert_contains "Scan status has progress" "overall_percent" "$SCAN_STATUS"

# Non-existent scan
HTTP_NOSCAN=$(curl -so /dev/null -w "%{http_code}" "$BASE/api/scans/nonexistent-id/status")
assert_eq "Non-existent scan returns 404" "404" "$HTTP_NOSCAN"

# ──────────────────────────────────────────────
echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo "  ⚠️  Some tests failed!"
    exit 1
else
    echo "  🎉 ALL TESTS PASSED!"
    exit 0
fi
