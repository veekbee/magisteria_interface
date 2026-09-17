#!/usr/bin/env bash
# What the octave ceiling costs decision 1040's condition 2, per walked parent.
#
#   bash tools/measure_octave_clamp.sh
#
# Grades the sourced windows twice at every walked parent -- once at the shipped
# MAX_OCTAVES and once at the count the rows ask for -- over the same stencils.
# Needs the fetched layers, the vendored band set and window_sourcing.json.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
exec "$GODOT" --headless --script tools/measure_octave_clamp.gd -- "$@"
