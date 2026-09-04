#!/usr/bin/env bash
# Photograph the running application in a described state, and measure it.
#
# WHY: the headless suite verifies data end to end and cannot see the screen.
# Three defects reached main past 1,800 passing checks -- the terrain wound
# inside-out and never drawn, a phenology mask that never reached its shader,
# nodata rendering as black -- and each was found by rendering and looking.
# This makes that repeatable and quotable.
#
# WINDOWED, NEVER HEADLESS. --headless draws nothing and reports success, so a
# capture there photographs an empty stub and looks exactly like a bug. The
# driver refuses it rather than saving the picture.
#
#   bash tools/screenshot.sh                                  # default view
#   bash tools/screenshot.sh --row band.pft.biomass --days 22,89 --scatter
#   bash tools/screenshot.sh --hide ui,flowlines --window deepest_winter
#
# Options are passed straight through to tools/capture.gd:
#   --window NAME   fixture window            (default: the first)
#   --row NAME      carried row to paint      (default: the first)
#   --days a,b,c    one shot per day          (default: 45)
#   --scatter       probe screen centre, scatter there, fly the camera to it
#   --hide LIST     ui,terrain,flowlines,vegetation,contours
#   --only LIST     the same names, kept instead of removed (wins over --hide)
#   --no-field      leave the terrain's own albedo on, so relief is the subject
#   --natural       naturalistic view: the far-field vegetation tint, not the ramp
#   --sun DEG       aim the hillshade; a lit surface changes and a texture does not
#   --compare PNG   diff the last shot against a frame from an earlier run
#   --backdrop black  clear to black, so the sky drops out of the measurements
#   --camera NAME   ortho or fly              (default: whatever the scene starts on)
#   --size WxH      window size               (default: 1280x800)
#   --out DIR       output directory          (default: shots)
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

before=$(git diff --quiet -- project.godot 2>/dev/null; echo $?)

"$GODOT" --path . --script res://tools/capture.gd -- "$@"
rc=$?

# The engine rewrites project.godot on any run and deletes every comment in it
# (see CONTRIBUTING.md). Saying so beats leaving it to be committed unnoticed,
# which is how it reached main once already.
if [ "$before" -eq 0 ] && ! git diff --quiet -- project.godot 2>/dev/null; then
  echo
  echo "note: this run rewrote project.godot and stripped its comments."
  echo "      git checkout project.godot   # unless you meant to change a setting"
fi
exit "$rc"
