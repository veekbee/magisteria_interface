#!/usr/bin/env bash
# The variogram of the synthesized detail surface, per landform. Writes
# measurements/detail_variogram.json. Headless -- nothing here is pixels.
#
#   bash tools/measure_variogram.sh
#   bash tools/measure_variogram.sh --flat     # the control that must FAIL
#
# "Reasonable features" has to be a measured match rather than taste, and a
# bounded-but-flat synthesizer must fail: it satisfies every range check and
# tells a playa from a talus slope not at all.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tools/measure_variogram.gd -- "$@"
