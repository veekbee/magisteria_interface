#!/usr/bin/env bash
# Run exactly what CI runs, in the same order, and fail the same way.
#
# WHY THIS EXISTS. A local check that greps a test runner's output for "OK"
# passes while the engine reports SCRIPT ERROR and exits non-zero -- which is
# how a runtime error reached CI green-locally. CI greps the log AND reads the
# exit code; anything less than both is a weaker gate than the one that
# matters, so this file is the only local invocation worth trusting.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
fail=0

echo "== contract pin =="
python3 tools/check_contract.py || fail=1

echo "== no addons =="
[ -d addons ] && { echo "addons/ exists"; fail=1; } || echo "ok"

echo "== project imports =="
"$GODOT" --headless --import 2>&1 | tee /tmp/import.log >/dev/null
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load" /tmp/import.log; then
  echo "import produced script or parse errors"; grep -E "SCRIPT ERROR|Parse Error" /tmp/import.log | head -5; fail=1
else echo "ok"; fi

echo "== headless tests =="
"$GODOT" --headless --script res://tests/run_headless.gd 2>&1 | tee /tmp/test.log
rc=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|^FAIL:" /tmp/test.log; then
  echo "-- script errors or failures in the test log"; fail=1
fi
grep -q "^OK -- " /tmp/test.log || { echo "-- no OK line: the runner did not finish"; fail=1; }
[ "$rc" -ne 0 ] && { echo "-- runner exited $rc"; fail=1; }

echo
[ "$fail" -eq 0 ] && echo "ALL GREEN" || echo "FAILED"
exit $fail
