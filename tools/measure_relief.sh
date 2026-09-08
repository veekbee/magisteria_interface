#!/usr/bin/env bash
# What the ground actually has, at the overview and at the tile pyramid, and
# which of the two blockers walk mode was refusing on. Writes
# measurements/ground_relief.json.
#
# HEADLESS, unlike the seam and motion tools: nothing here is measured in
# pixels. It is two grids and their difference.
#
#   bash tools/measure_relief.sh
#   bash tools/measure_relief.sh --radius 480 --samples 64
#
# Needs the pyramid fetched: `python3 tools/fetch_artefacts.py`. Without it the
# tool refuses rather than reporting zeros, which would be a measurement of
# this clone rather than of the basin.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tools/measure_relief.gd -- "$@"
