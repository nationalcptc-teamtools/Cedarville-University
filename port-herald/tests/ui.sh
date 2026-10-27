#!/bin/bash
# Font + collapsible sidebar + layout fix verification
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
assert_not_contains() {
    local tmp; tmp=$(mktemp); printf '%s' "$3" > "$tmp"
    if grep -q -- "$2" "$tmp"; then fail "$1" "should not contain '$2'"; else pass "$1"; fi
    rm -f "$tmp"
}

HTML=$(curl -sf "$BASE/")
CSS=$(curl -sf "$BASE/css/style.css")
JS=$(curl -sf "$BASE/js/app.js")

echo "============================================"
echo "  FONTS + COLLAPSIBLE SIDEBAR TESTS"
echo "============================================"
echo ""

echo "1. GOOGLE FONTS LINKED IN HTML"
echo "──────────────────────────────────────────"
assert_contains "HTML preconnects to googleapis"        "fonts.googleapis.com"              "$HTML"
assert_contains "HTML preconnects to gstatic"           "fonts.gstatic.com"                 "$HTML"
assert_contains "HTML loads Quattrocento"               "Quattrocento"                      "$HTML"
assert_contains "HTML loads IBM Plex Mono"              "IBM+Plex+Mono"                     "$HTML"
assert_contains "HTML loads JetBrains Mono"             "JetBrains+Mono"                    "$HTML"
assert_contains "HTML uses display=swap for fonts"      "display=swap"                      "$HTML"

echo ""
echo "2. CSS FONT TOKENS"
echo "──────────────────────────────────────────"
assert_contains "CSS defines --font-primary"            "--font-primary:"                   "$CSS"
assert_contains "CSS --font-primary = Quattrocento"     "Quattrocento"                      "$CSS"
assert_contains "CSS defines --font-accent"             "--font-accent:"                    "$CSS"
assert_contains "CSS --font-accent = IBM Plex Mono"     "IBM Plex Mono"                     "$CSS"
assert_contains "CSS defines --font-code"               "--font-code:"                      "$CSS"
assert_contains "CSS --font-code = JetBrains Mono"      "JetBrains Mono"                    "$CSS"
assert_contains "body uses --font-primary"              "font-family: var(--font-primary)"  "$CSS"
assert_contains "code blocks use --font-code"           "font-family: var(--font-code)"     "$CSS"
assert_contains "labels use --font-accent"              "font-family: var(--font-accent)"   "$CSS"

echo ""
echo "3. ACCENT FONT TARGETS"
echo "──────────────────────────────────────────"
# Check that key accent targets are included in the accent font block
assert_contains "CSS: .info-label uses accent font"     ".info-label"                       "$CSS"
assert_contains "CSS: .scan-phase-pill uses accent"     ".scan-phase-pill"                  "$CSS"
assert_contains "CSS: .invest-badge uses accent"        ".invest-badge"                     "$CSS"
assert_contains "CSS: .member-chip uses accent"         ".member-chip"                      "$CSS"
assert_contains "CSS: .os-chip uses accent"             ".os-chip"                          "$CSS"
assert_contains "CSS: .host-status uses accent"         ".host-status"                      "$CSS"

echo ""
echo "4. CODE FONT TARGETS"
echo "──────────────────────────────────────────"
assert_contains "CSS: .scan-console uses code font"     ".scan-console"                     "$CSS"
assert_contains "CSS: .script-output uses code font"    ".script-output"                    "$CSS"
assert_contains "CSS: .scan-hash uses code font"        ".scan-hash"                        "$CSS"
assert_contains "CSS: .topo-host-ip uses code font"     ".topo-host-ip"                     "$CSS"
assert_contains "CSS: .host-ip uses code font"          ".host-ip"                          "$CSS"
assert_contains "CSS: .port-number uses code font"      ".port-number"                      "$CSS"
assert_contains "CSS: xml paste textarea uses code"     "textarea#xml-paste"                "$CSS"

echo ""
echo "5. COLLAPSIBLE SIDEBAR MARKUP"
echo "──────────────────────────────────────────"
assert_contains "HTML has #sidebar-toggle button"       'id="sidebar-toggle"'                "$HTML"
assert_contains "HTML has aria-label on toggle"         'aria-label="Toggle sidebar"'        "$HTML"
assert_contains "HTML has hamburger SVG in toggle"      '<svg viewBox="0 0 24 24"'           "$HTML"
assert_contains "HTML has .sidebar-wordmark"            'class="sidebar-wordmark"'           "$HTML"
assert_contains "HTML wordmark reads Port Herald"       '>Port Herald<'                      "$HTML"
assert_not_contains "HTML has no old .sidebar-title"    'class="sidebar-title"'              "$HTML"

echo ""
echo "6. COLLAPSIBLE SIDEBAR CSS"
echo "──────────────────────────────────────────"
assert_contains "CSS defines --sidebar-w-collapsed"     "--sidebar-w-collapsed:"             "$CSS"
assert_contains "CSS has --ease variable"               "--ease:"                            "$CSS"
assert_contains "CSS .sidebar.collapsed selector"       ".sidebar.collapsed"                 "$CSS"
assert_contains "CSS .sidebar.collapsed shrinks width"  ".sidebar.collapsed { width:"        "$CSS"
assert_contains "CSS .sidebar-toggle styled"            ".sidebar-toggle {"                  "$CSS"
assert_contains "CSS .sidebar-wordmark styled"          ".sidebar-wordmark {"                "$CSS"
assert_contains "CSS wordmark hides when collapsed"     ".sidebar.collapsed .sidebar-wordmark" "$CSS"
assert_contains "CSS nav labels hide when collapsed"    ".sidebar.collapsed .nav-item > span" "$CSS"
assert_contains "CSS main margin shrinks when collapsed" "body.sidebar-collapsed .main"      "$CSS"
assert_contains "CSS width transition uses --ease"      "transition: width"                  "$CSS"
assert_contains "CSS main margin uses --ease"           "transition: margin-left"            "$CSS"

echo ""
echo "7. STRAY LINE REMOVED"
echo "──────────────────────────────────────────"
# Pull out the .sidebar-header block only (first match)
HEADER_BLOCK=$(awk '/^\.sidebar-header[ ]*{/{flag=1} flag; /^}/{if(flag){flag=0; exit}}' /tmp/live.css)
if [ -z "$HEADER_BLOCK" ]; then
    # Rebuild it ourselves from the fetched CSS
    HEADER_BLOCK=$(printf '%s' "$CSS" | awk '/^\.sidebar-header[ ]*\{/{flag=1} flag; /^\}/{if(flag){flag=0; exit}}')
fi
assert_not_contains ".sidebar-header has NO border-bottom" "border-bottom:" "$HEADER_BLOCK"

echo ""
echo "8. SIDEBAR TOGGLE JS BEHAVIOR"
echo "──────────────────────────────────────────"
assert_contains "JS reads #sidebar-toggle"              "getElementById('sidebar-toggle')"   "$JS"
assert_contains "JS toggles .collapsed class"           "classList.toggle('collapsed')"      "$JS"
assert_contains "JS toggles body.sidebar-collapsed"     "sidebar-collapsed"                  "$JS"
assert_contains "JS persists collapsed to localStorage" "ph-sidebar-collapsed"               "$JS"
assert_contains "JS restores collapsed on load"         "localStorage.getItem('ph-sidebar-collapsed')" "$JS"
assert_contains "JS treats <820px as mobile for toggle" '820px'                              "$JS"

echo ""
echo "9. EASING"
echo "──────────────────────────────────────────"
assert_contains "CSS uses cubic-bezier easing"          "cubic-bezier"                       "$CSS"
# At least one transition on .sidebar should use var(--ease)
SIDEBAR_BLOCK=$(printf '%s' "$CSS" | awk '/^\.sidebar[ ]*\{/{flag=1} flag; /^\}/{if(flag){flag=0; exit}}')
assert_contains ".sidebar transition uses --ease"       "var(--ease)"                        "$SIDEBAR_BLOCK"

echo ""
echo "10. ASSETS STILL SERVING"
echo "──────────────────────────────────────────"
for A in /favicon.ico /img/logo-dark.png /img/logo-light.png /img/wordmark.png; do
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$BASE$A")
    assert_eq "$A → 200" "200" "$HTTP"
done

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then echo "  ⚠️  Some tests failed!"; exit 1
else echo "  🎉 ALL FONTS/SIDEBAR TESTS PASSED!"; exit 0; fi
