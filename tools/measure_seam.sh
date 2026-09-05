#!/usr/bin/env bash
# Grade a far-field candidate against the instances it stands in for, and write
# measurements/scatter_seam.json. Windowed, never headless; the window must stay
# on screen and in front for the whole run.
#
#   bash tools/measure_seam.sh --seam 120
#   bash tools/measure_seam.sh --seam 120 --window largest_fire --day 60
#
#   --seam M          the candidate seam distance     (default: 120)
#   --window NAME     fixture window                  (default: the first)
#   --row NAME        row the scatter reads           (default: band.pft.biomass)
#   --day N           day within the window           (default: 22)
#   --at X,Y          EPSG:5070 point to stand at     (default: centre of the opening view)
#   --sweep-k         sweep the individuation constant k, one rebuild per value,
#                     and record what one k meant per family in metres
#   --oracle-check    also build an oracle at 5x the seam, to measure whether
#                     the 2.5x one is deep enough for the annulus score
#   --size WxH        window size                     (default: 1280x800)
#   --append          add this run to the artefact instead of replacing it;
#                     sufficiency is a claim about places and days, and one row
#                     of it is not evidence for the claim
#   --out PATH        artefact path
#   --shots DIR       PNG directory                   (default: shots/seam)
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --path . --script res://tools/measure_seam.gd -- "$@"
rc=$?
if ! git diff --quiet -- project.godot 2>/dev/null; then
  echo; echo "note: this run rewrote project.godot and stripped its comments."
  echo "      git checkout project.godot"
fi
exit "$rc"
