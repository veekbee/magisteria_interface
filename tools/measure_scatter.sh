#!/usr/bin/env bash
# Measure what M5's scatter costs a frame, in the viewer that draws it, and
# write measurements/scatter_cost.json.
#
# WINDOWED, NEVER HEADLESS -- see tools/measure_scatter.gd. The window must stay
# on screen and in front for the whole run, or the frames stop being drawn and
# the timings become a cadence. It takes about half a minute.
#
#   bash tools/measure_scatter.sh
#   bash tools/measure_scatter.sh --row band.pft.biomass --day 22 --at -1234567,1789012
#
#   --window NAME  fixture window        (default: the first)
#   --row NAME     row the scatter reads (default: band.pft.biomass)
#   --day N        day within the window (default: 22)
#   --at X,Y       EPSG:5070 point to stand at, so a re-run repeats the place
#                  rather than the framing (default: the centre of the opening view)
#   --size WxH     window size           (default: 1280x800)
#   --out PATH     artefact path         (default: measurements/scatter_cost.json)
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --path . --script res://tools/measure_scatter.gd -- "$@"
rc=$?
if ! git diff --quiet -- project.godot 2>/dev/null; then
  echo
  echo "note: this run rewrote project.godot and stripped its comments."
  echo "      git checkout project.godot   # unless you meant to change a setting"
fi
exit "$rc"
