#!/usr/bin/env bash
# Free flight at walking pace, recorded as a replayable trace. The owner drives.
#
# WINDOWED, NEVER HEADLESS -- a person has to be looking at it. The window must
# stay focused: frames recorded while it is not are counted, and a flight that
# spends more than a tenth of itself behind another window is refused rather
# than written.
#
#   bash tools/free_flight.sh
#   bash tools/free_flight.sh --recentre 25 --at -1212793,1376226 --minutes 3
#
#   W/A/S/D  walk        mouse  look        SPACE  mark "that looked wrong"
#   ESC      land and write the trace
#
#   --speed M/S    walking speed            (default: 5.0, the ruled traversal speed)
#   --recentre M   metres before the scatter rebuilds around the camera
#                  (default: 0 -- one build, flown through, which is what ships.
#                   Above 0 is the population following the camera, which is
#                   what a per-place instance budget does and what boils.)
#   --k FRACTION   k as a fraction of k_res (default: 0.35, decision 949)
#   --window NAME  fixture window           (default: the first)
#   --row NAME     row the scatter reads    (default: band.pft.biomass)
#   --day N        day within the window    (default: 22)
#   --at X,Y       EPSG:5070 point to start at
#   --minutes N    land automatically after N minutes (default: 0, fly until ESC)
#   --size WxH     window size              (default: 1280x800)
#   --out PATH     trace path               (default: measurements/flights/flight.trace.json)
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --path . --script res://tools/free_flight.gd -- "$@"
rc=$?
if ! git diff --quiet -- project.godot 2>/dev/null; then
  echo; echo "note: this run rewrote project.godot and stripped its comments."
  echo "      git checkout project.godot   # unless you meant to change a setting"
fi
exit "$rc"
