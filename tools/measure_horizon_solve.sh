#!/usr/bin/env bash
# §24 gap 170 items (ii) and (iii): decision 1030's solved horizon over the
# basin fixture. Writes measurements/horizon_solve.json.
#
# HEADLESS -- the solve is arithmetic over wire quantities and committed
# coefficients, so nothing here is pixels. Item (i) is the frame-timing half and
# needs a window; it is not this.
#
#   bash tools/measure_horizon_solve.sh
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tools/measure_horizon_solve.gd -- "$@"
