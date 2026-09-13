#!/usr/bin/env bash
# Window sourcing for decision 1019's bands -- HEADLESS, no window and no person.
#
# Writes `measurements/window_sourcing.json`, which the gate reads. Re-run it
# when the terrain layers move: the centres are a measurement of THIS basin at
# THESE layers, and the artefact records the classifier source so a reader can
# tell whether the ground under them is the ground they were sourced on.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
exec "$GODOT" --headless --script tools/find_windows.gd
