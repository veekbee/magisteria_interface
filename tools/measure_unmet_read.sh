#!/usr/bin/env bash
# Reading the condition-2 UNMET: which cells can fail, which do, and how.
#
#   bash tools/measure_unmet_read.sh
#
# Grades the shipped ladder at every walked parent and publishes the miss per
# stratum per lag, with the cells whose bands cannot fail named separately.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
exec "$GODOT" --headless --script tools/measure_unmet_read.gd -- "$@"
