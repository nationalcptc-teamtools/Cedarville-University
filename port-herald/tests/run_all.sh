#!/bin/bash
# Port Herald — Master test runner.
#
# Spins up a release build of the server against a disposable DB, then runs
# every test suite in sequence. Server is stopped on exit.
#
# Usage:
#   tests/run_all.sh            # run all suites
#   tests/run_all.sh backend    # run a single suite
set -eu

cd "$(dirname "$0")/.."
BINARY="./target/release/port-herald"
DB="/tmp/port-herald_test.db"
LOG="/tmp/port-herald_test.log"
PORT=9999
BASE="http://localhost:$PORT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [ ! -x "$BINARY" ]; then
    echo "${YELLOW}Building release binary…${NC}"
    cargo build --release >/dev/null
fi

cleanup() { kill $SERVER_PID 2>/dev/null || true; }
trap cleanup EXIT

rm -f "$DB"
"$BINARY" --database "$DB" --port $PORT > "$LOG" 2>&1 &
SERVER_PID=$!

# Wait until the server is actually responding
for _ in $(seq 1 20); do
    if curl -sf -o /dev/null "$BASE/api/health"; then break; fi
    sleep 0.2
done

SUITES=("backend" "frontend" "os" "team" "scan" "ui" "icon" "delete" "import")
FILTER="${1:-}"
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_SUITES=()

for suite in "${SUITES[@]}"; do
    if [ -n "$FILTER" ] && [ "$suite" != "$FILTER" ]; then
        continue
    fi
    printf "\n${GREEN}══ %s ══${NC}\n" "$suite"
    SCRIPT="tests/${suite}.sh"
    if [ ! -f "$SCRIPT" ]; then
        echo "  (missing: $SCRIPT)"
        continue
    fi
    OUT=$(bash "$SCRIPT" 2>&1 || true)
    RESULT=$(echo "$OUT" | grep "RESULTS:" | tail -1 || echo "")
    echo "$RESULT"
    PASS=$(echo "$RESULT" | awk '{for(i=1;i<=NF;i++) if($i=="passed,") print $(i-1)}')
    FAIL=$(echo "$RESULT" | awk '{for(i=1;i<=NF;i++) if($i=="failed") print $(i-1)}')
    [ -n "$PASS" ] && TOTAL_PASS=$((TOTAL_PASS + PASS))
    if [ -n "$FAIL" ] && [ "$FAIL" -gt 0 ]; then
        TOTAL_FAIL=$((TOTAL_FAIL + FAIL))
        FAILED_SUITES+=("$suite")
        echo "$OUT" | grep "❌" | head -5
    fi
done

echo ""
echo "═══════════════════════════════════════════"
if [ "$TOTAL_FAIL" -gt 0 ]; then
    printf "  TOTAL: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}\n" "$TOTAL_PASS" "$TOTAL_FAIL"
    printf "  Failed suites: %s\n" "${FAILED_SUITES[*]}"
    exit 1
else
    printf "  TOTAL: ${GREEN}%d passed${NC}, 0 failed 🎉\n" "$TOTAL_PASS"
fi
