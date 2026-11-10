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
