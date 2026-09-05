#!/usr/bin/env bash
# Motion metrics for the far field: a scripted dolly through the seam scoring
# the worst frame-pair delta in the annulus, and a lateral-step parallax pair.
# Roadmap item 2. Static sufficiency does not cover temporal defects.
#
# WINDOWED, NEVER HEADLESS. --headless draws nothing and reports success.
#
#   bash tools/measure_motion.sh --seam 120
#   bash tools/measure_motion.sh --seam 120 --at -1212793,1376226 --k 0.35
#
#   --seam M      the candidate seam distance   (default: 120)
#   --k FRACTION  k as a fraction of k_res      (default: 0.35, decision 949)
#   --window NAME fixture window                (default: the first)
#   --row NAME    row the scatter reads         (default: band.pft.biomass)
#   --day N       day within the window         (default: 22)
#   --at X,Y      EPSG:5070 point to stand at   (default: centre of the opening view)
#   --size WxH    window size                   (default: 1280x800)
#   --append      add this run to the artefact instead of replacing it
#   --out PATH    artefact path                 (default: measurements/scatter_motion.json)
#   --shots DIR   PNG directory                 (default: shots/motion)
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --path . --script res://tools/measure_motion.gd -- "$@"
rc=$?
if ! git diff --quiet -- project.godot 2>/dev/null; then
  echo; echo "note: this run rewrote project.godot and stripped its comments."
  echo "      git checkout project.godot   # unless you meant to change a setting"
fi
exit "$rc"
