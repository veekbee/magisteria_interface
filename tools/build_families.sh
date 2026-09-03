#!/usr/bin/env bash
# Author M5's form archetypes and export them. Blender, headless.
#
# THE FULL PATH IS NOT A CONVENIENCE. Blender is not on PATH on this machine,
# and a script that says `blender` works for whoever installed it that way and
# fails in CI with a message about a missing command rather than about what it
# was trying to do. Override with GODOT-style env if your install differs:
#
#     BLENDER=/path/to/Blender bash tools/build_families.sh
#
# Writes tools/blender/family_*.blend (the sources), assets/families/*.glb (the
# exported families) and assets/families/families.json (the manifest mapping
# life_form -> file + parameters + legal ranges).
set -uo pipefail
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
cd "$(dirname "$0")/.."

if [ ! -x "$BLENDER" ]; then
  echo "no Blender at $BLENDER -- set BLENDER=<path> and re-run" >&2
  exit 2
fi

"$BLENDER" --version | head -1
"$BLENDER" --background --python tools/blender/build_families.py 2>&1 \
  | grep -E "^family |^wrote |Error|Traceback" || true

# The .blend sources are build machinery and tools/blender/.gdignore keeps the
# engine out of them: Godot imports .blend natively by shelling out to Blender,
# which fails headlessly with "Blender path is invalid or not set" and would
# turn the gate red for a file the project never loads.
[ -f tools/blender/.gdignore ] || { echo "tools/blender/.gdignore is missing" >&2; exit 1; }
python3 - <<'PY'
import json, pathlib
m = json.loads(pathlib.Path("assets/families/families.json").read_text())
for lf, f in sorted(m["families"].items()):
    p = f["parameters"]
    print(f"  {lf:10s} {f['triangles']:3d} tri  "
          f"height {p['height_m']['min']}..{p['height_m']['max']} m  "
          f"crown {p['crown_m']['min']}..{p['crown_m']['max']} m")
absent = m["not_here"]["animal_families"]["families"]
print(f"  absent by ruling: {', '.join(absent)}")
PY
