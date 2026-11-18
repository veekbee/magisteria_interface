#!/usr/bin/env bash
# The explorer's viewer: DA-6's dressing drawn with its pins, for the owner's
# look at DA-9 (owner ruling 2130 Q2; docs/roadmap/client.md G-9 W3).
#
# WINDOWED, NEVER HEADLESS -- the whole point is that a person is looking at it.
# --headless draws nothing and exits successfully, so a "look" taken there would
# photograph an empty stub and report a clean run; this driver refuses the flag
# rather than let that count as the owner having seen anything.
#
#   bash tools/explorer.sh
#
#   left / right   step one year          1 2 3 4   jump to 1890, 1940, 1990, 2039
#
# A PLAY SESSION'S PANEL (§25 backlog 752, decision 2149 (4)), optional:
#
#   MAGISTERIA_SESSION=/path/to/runs/play/<name> bash tools/explorer.sh
#
# draws that session's year panel and next year's demand down the right. The
# path is not committed and not guessed: a session directory is git-ignored and
# lives on the owner's machine, so the environment is the only place it can come
# from. With nothing set this is the viewer it was before -- the committed
# dressing and nothing else. A session that will not read says why in the
# panel's place and still draws the city; the city's own bindings are what gate
# the drawing.
#
# WITH A SESSION OPEN THE SLIDER DRAWS THE SESSION'S OWN CITY (§25 backlog 753)
# and the committed dressing is not drawn at all -- one city on screen, never
# two. The slider runs from the arc's first year to the year the session has
# built to, and grows as you advance; a rewind DELETES the years above its
# target, so it shrinks too, and the year on screen is clamped down with it.
#
#   a              advance one year
#   r              rewind to the year on screen -- PRICED FIRST, nothing is done
#   y              confirm a priced rewind or removal (a new command; never automatic)
#
# PLACING (§25 backlog 754), with a session open. RECTANGLES FIRST, by the
# owner's ruling: one drag makes an axis-aligned four-vertex polygon.
#
#   z k w          zone / cap / renew -- drag a rectangle
#   f              feature -- DRAG a rectangle for a polygon, or CLICK for a
#                  point; the gesture decides which, so there is no second key
#   c              centre -- click a point
#   t              route -- click the two ends; clicks between them become
#                  waypoints, and the router lays the path (none is invented here)
#   [ ]            cycle the class or type. A ZONE's ten are design's own labels
#                  -- homes, modest/middle/wealthy homes, shops and offices,
#                  industry, warehouses, civic, parks, keep open -- and the pin
#                  carries the register's class name, not the label. A route's
#                  classes and a feature's types are still derived from the
#                  fetched palette and reference.
#
# A feature type the format does not allow until a later year is refused by the
# session, in its own words: the client has no published source for a type's
# availability and does not guess at one.
#   Enter          place it: the pin is minted, checked against the pin format,
#                  and written as a `place` command
#   Esc            put the tool down
#   click, x       with no tool: select a pin, then remove it. A point kind is
#                  picked within half a tile of its point, so this reaches all
#                  six kinds and not only the four with polygons
#
# A placement is dated the year AFTER the session's current one, which is this
# client's first-version restriction and not the rule. The session checks every
# placement again, and the emission tool checks it a third time; a refusal is
# shown in the session's own words.
#
# A rewind replays from the arc's start and can cost as much as a whole build,
# which is why it is priced and confirmed by hand rather than run on a keypress.
# A refusal from the session is shown in its own words, never paraphrased.
#   left-drag      move a pin (inside its outline)
#   ESC            close
#
# WHAT IT NEEDS FETCHED, and it says so on screen rather than drawing a partial
# city if anything is missing: the dressing, §25 backlog 730's reference with
# §25 backlog 732's centres, and the committed pin file. All three arrive through
#   python3 tools/fetch_artefacts.py
# and nothing else. A refusal is drawn in words on a dark screen -- deliberately
# a worse demonstration and a better instrument, because an omission is the one
# thing a person cannot catch by looking at a city they have never seen.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

for a in "$@"; do
  if [ "$a" = "--headless" ]; then
    echo "explorer.sh: --headless draws nothing and would report a clean run." >&2
    echo "The owner's look is a person's step. Refusing." >&2
    exit 2
  fi
done

before=$(git diff --quiet -- project.godot 2>/dev/null; echo $?)

"$GODOT" --path . res://scenes/explorer.tscn "$@"
rc=$?

# The engine rewrites project.godot on any run and strips every comment from it
# (see CONTRIBUTING.md, and tools/screenshot.sh, which carries this same note
# because the rewrite reached main unnoticed once already).
if [ "$before" -eq 0 ] && ! git diff --quiet -- project.godot 2>/dev/null; then
  echo
  echo "NOTE: the engine rewrote project.godot on this run. Check the diff before"
  echo "committing it -- the rewrite strips the file's comments."
fi
exit $rc
