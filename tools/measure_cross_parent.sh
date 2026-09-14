#!/usr/bin/env bash
# Cross-parent invariance per landform -- HEADLESS, no window and no person.
#
#   bash tools/measure_cross_parent.sh                       # the vendored rows
#   bash tools/measure_cross_parent.sh --rows /path/rows.json # a candidate
#
# The second form is the one worth having: it measures an artefact BEFORE it is
# vendored, on either side of the boundary.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
exec "$GODOT" --headless --script tools/measure_cross_parent.gd -- "$@"
