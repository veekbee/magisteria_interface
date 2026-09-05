#!/usr/bin/env bash
# Measure what distance-banded density schedules cost and cover, and write
# measurements/scatter_bands.json. Windowed, never headless.
#
#   bash tools/measure_bands.sh
#   bash tools/measure_bands.sh --window deepest_winter --ceiling 2000000
#
#   --window NAME   fixture window        (default: the first)
#   --row NAME      row the scatter reads (default: band.pft.biomass)
#   --day N         day within the window (default: 22)
#   --at X,Y        EPSG:5070 point to stand at (default: centre of the opening view)
#   --ceiling N     instances the builder may place, so the SCHEDULE binds and
#                   not the builder (default: 1500000; the shipped app uses 120000)
#   --size WxH      window size           (default: 1280x800)
#   --exaggeration N  vertical exaggeration to build at. Naturalistic view is
#                   1x and data view 12x; every distance here is conditional on it
#   --camera NAME   eye (default) or overview; eye stands in the scatter, overview
#                   is the app's own focus_on_scatter, which frames it from above
#   --pitch DEG     how far below level the eye camera looks (default: 10)
#   --lift M        extra height for the eye camera (default: 0)
#   --out PATH      artefact path
#
# It also drops one PNG per schedule in shots/bands/ (ignored, like all shots).
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --path . --script res://tools/measure_bands.gd -- "$@"
rc=$?
if ! git diff --quiet -- project.godot 2>/dev/null; then
  echo; echo "note: this run rewrote project.godot and stripped its comments."
  echo "      git checkout project.godot"
fi
exit "$rc"
