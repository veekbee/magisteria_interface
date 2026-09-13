#!/usr/bin/env bash
# Re-pin tests/check_counts.json to what the suite currently contributes.
#
# The pin exists so a check that STOPS RUNNING is visible even when the total
# rises. Re-pinning is expected after a re-vendor -- a test looping over the
# fixture contributes more checks when the fixture carries more -- and the
# committed diff is the declaration: a fall shows as a red line in review.
#
# Read the diff before committing it. That is the whole mechanism.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --script res://tests/run_headless.gd -- --pin-counts
