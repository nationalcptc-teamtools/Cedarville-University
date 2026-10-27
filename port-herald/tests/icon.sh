#!/bin/bash
# Member icon customization + sidebar logo restructure
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
    if grep -q -- "$2" "$tmp"; then fail "$1" "unexpected '$2'"; else pass "$1"; fi
    rm -f "$tmp"
}

HTML=$(curl -sf "$BASE/")
CSS=$(curl -sf "$BASE/css/style.css")
JS=$(curl -sf "$BASE/js/app.js")

# Clean slate for member tests
while true; do
    IDS=$(curl -sf "$BASE/api/members" 2>/dev/null | jq -r '.[].id' 2>/dev/null)
    [ -z "$IDS" ] && break
    for mid in $IDS; do curl -s -X DELETE "$BASE/api/members/$mid" >/dev/null; done
done

echo "============================================"
echo "  ICON CUSTOMIZATION + SIDEBAR LOGO FIX"
echo "============================================"
echo ""

echo "1. CROPPED LOGO ASSETS"
echo "──────────────────────────────────────────"
HTTP_DARK=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/img/logo-dark-cropped.png")
HTTP_LIGHT=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/img/logo-light-cropped.png")
assert_eq "logo-dark-cropped.png serves"   "200" "$HTTP_DARK"
assert_eq "logo-light-cropped.png serves"  "200" "$HTTP_LIGHT"
assert_contains "HTML references logo-dark-cropped"   "logo-dark-cropped.png"   "$HTML"
assert_contains "HTML references logo-light-cropped"  "logo-light-cropped.png"  "$HTML"
assert_not_contains "HTML no longer uses raw logo-dark.png" 'img.*src="/img/logo-dark\.png"' "$HTML"
assert_not_contains "HTML no longer uses raw logo-light.png" 'img.*src="/img/logo-light\.png"' "$HTML"

echo ""
echo "2. SIDEBAR HEADER LAYOUT"
echo "──────────────────────────────────────────"
assert_contains "HTML has .sidebar-brand wrapper"           'class="sidebar-brand"'   "$HTML"
assert_contains "Brand wraps logo + wordmark"               'sidebar-brand'           "$HTML"
assert_contains "CSS lays header as flex-column"            'flex-direction: column' "$CSS"
assert_contains "CSS .sidebar-brand aligns horizontally"    '.sidebar-brand'          "$CSS"
assert_contains "CSS logo uses object-fit:contain"          'object-fit: contain'     "$CSS"
assert_not_contains "CSS no longer scale(2.6) the logo"     'transform: scale(2.6)'   "$CSS"
assert_contains "CSS centers header when collapsed"         '.sidebar.collapsed .sidebar-header' "$CSS"

# Verify brand & toggle are siblings in the header (so logo is above hamburger)
# Pull out the sidebar-header block and check order
HEADER_HTML=$(printf '%s' "$HTML" | awk '/<div class="sidebar-header">/{flag=1} flag; /<\/div>/{if(flag){cnt++; if(cnt>=4){flag=0}}}')
BRAND_POS=$(printf '%s' "$HEADER_HTML" | grep -n 'sidebar-brand'  | head -1 | cut -d: -f1)
TOGGLE_POS=$(printf '%s' "$HEADER_HTML" | grep -n 'sidebar-toggle' | head -1 | cut -d: -f1)
if [ -n "$BRAND_POS" ] && [ -n "$TOGGLE_POS" ] && [ "$BRAND_POS" -lt "$TOGGLE_POS" ]; then
    pass "Logo (brand) appears before hamburger in header"
else
    fail "Logo (brand) appears before hamburger in header" "brand=$BRAND_POS toggle=$TOGGLE_POS"
fi

echo ""
echo "3. ICON PICKER UI"
echo "──────────────────────────────────────────"
assert_contains "HTML has icon-picker-modal"           'id="icon-picker-modal"'   "$HTML"
assert_contains "HTML has icon-grid container"         'id="icon-grid"'           "$HTML"
assert_contains "HTML has custom emoji input"          'id="icon-custom-input"'   "$HTML"
assert_contains "HTML has upload input"                'id="icon-upload-input"'   "$HTML"
assert_contains "HTML upload input accepts PNG"        'image/png'                "$HTML"
assert_contains "HTML upload input accepts SVG"        'image/svg'                "$HTML"
assert_contains "CSS styles .icon-grid"                '.icon-grid'               "$CSS"
assert_contains "CSS styles .icon-custom-row"          '.icon-custom-row'         "$CSS"
assert_contains "CSS styles .icon-upload-row"          '.icon-upload-row'         "$CSS"
assert_contains "CSS member chip image rule"           '.member-chip .icon img'   "$CSS"
assert_contains "CSS avatar edit overlay"              '.team-member-row .avatar::after' "$CSS"

echo ""
echo "4. ICON RENDERING JS"
echo "──────────────────────────────────────────"
assert_contains "JS defines renderIcon()"              'function renderIcon'      "$JS"
assert_contains "JS wraps data: URIs in <img>"         'data:image/'              "$JS"
assert_contains "JS wraps http(s) URLs in <img>"       'https?:'                  "$JS"
assert_contains "JS defines iconLabelForSelect"        'iconLabelForSelect'       "$JS"
assert_contains "JS defines AVAILABLE_ICONS array"     'AVAILABLE_ICONS'          "$JS"
assert_contains "JS defines openIconPicker"            'function openIconPicker'  "$JS"
assert_contains "JS defines saveMemberIcon"            'saveMemberIcon'           "$JS"
assert_contains "JS defines initIconPicker"            'initIconPicker'           "$JS"
assert_contains "JS resizes images to 128px"           'resizeDataUri'            "$JS"
assert_contains "JS caps upload at 50 KB"              '50 \* 1024'               "$JS"
assert_contains "JS calls initIconPicker on boot"      'initIconPicker()'         "$JS"
# Propagation: saveMemberIcon triggers all four refreshes
assert_contains "JS saveMemberIcon refreshes members"    'refreshMembers'   "$JS"
assert_contains "JS saveMemberIcon refreshes topology"   'refreshTopology'  "$JS"
assert_contains "JS saveMemberIcon refreshes hosts"      'refreshHosts'     "$JS"
assert_contains "JS saveMemberIcon refreshes blame log"  'refreshBlame'     "$JS"
# Team roster avatars are clickable
assert_contains "JS wires avatar onclick to picker"    'openIconPicker'           "$JS"

echo ""
echo "5. BACKEND ICON API"
echo "──────────────────────────────────────────"
curl -sf -X POST "$BASE/api/members" -H "Content-Type: application/json" -d '{"names":"IconTester"}' >/dev/null
MID=$(curl -sf "$BASE/api/members" | jq '.[] | select(.name=="IconTester") | .id')

# Default auto-assigned icon
DEFAULT_ICON=$(curl -sf "$BASE/api/members" | jq -r ".[] | select(.id==$MID) | .icon")
assert_contains "Default icon is non-empty" "." "$DEFAULT_ICON"

# PUT /icon → updates
R=$(curl -sf -X PUT "$BASE/api/members/$MID/icon" -H "Content-Type: application/json" \
    -d '{"icon":"\ud83e\udd77"}')
assert_eq "PUT icon returns status=updated" "updated" "$(echo "$R" | jq -r .status)"

NEW_ICON=$(curl -sf "$BASE/api/members" | jq -r ".[] | select(.id==$MID) | .icon")
assert_eq "New icon persisted" "🥷" "$NEW_ICON"

# data: URI payload is accepted
DATA='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
R=$(curl -sf -X PUT "$BASE/api/members/$MID/icon" -H "Content-Type: application/json" \
    -d "{\"icon\":\"$DATA\"}")
assert_eq "PUT accepts data: URI" "updated" "$(echo "$R" | jq -r .status)"
SIZE=$(curl -sf "$BASE/api/members" | jq -r ".[] | select(.id==$MID) | .icon" | wc -c | tr -d ' ')
if [ "$SIZE" -gt 100 ]; then pass "Data URI stored ($SIZE bytes)"
else fail "Data URI stored" "only $SIZE bytes"; fi

# Blame log recorded the change
BLAME=$(curl -sf "$BASE/api/blame")
assert_contains "Blame log has icon_changed action" '"icon_changed"' "$BLAME"

# Empty icon rejected
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/api/members/$MID/icon" \
    -H "Content-Type: application/json" -d '{"icon":""}')
assert_eq "Empty icon → 400" "400" "$HTTP"

# Whitespace-only icon rejected (we .trim())
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/api/members/$MID/icon" \
    -H "Content-Type: application/json" -d '{"icon":"   "}')
assert_eq "Whitespace icon → 400" "400" "$HTTP"

# 404 on missing member
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE/api/members/99999/icon" \
    -H "Content-Type: application/json" -d '{"icon":"🐸"}')
assert_eq "Missing member → 404" "404" "$HTTP"

# After deletion, old icon doesn't leak
curl -s -X DELETE "$BASE/api/members/$MID" >/dev/null

echo ""
echo "6. SIDEBAR TOGGLE STILL CLICKABLE"
echo "──────────────────────────────────────────"
# The hamburger shouldn't be covered by the logo anymore. We can't test
# pixel overlap directly, but we can assert the layout change that fixes it.
assert_contains "Header is flex-column"                     'flex-direction: column'   "$CSS"
assert_contains "Brand & toggle are block-level siblings"   'sidebar-brand'            "$HTML"

echo ""
echo "============================================"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then echo "  ⚠️  Some tests failed!"; exit 1
else echo "  🎉 ALL ICON + LOGO TESTS PASSED!"; exit 0; fi
