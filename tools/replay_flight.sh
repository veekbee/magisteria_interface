#!/usr/bin/env bash
# Score a recorded flight again, headlessly, without the person who flew it.
#
# HEADLESS ON PURPOSE, which is the opposite of every other harness here. It
# photographs nothing: what it recomputes is the population -- which instances
# existed and how the set changed -- and that is arithmetic over the scatter's
# own census. Frame time does not come back and is carried from the flight.
#
#   bash tools/replay_flight.sh --trace measurements/flights/scripted.trace.json
#   bash tools/replay_flight.sh --synthesise measurements/flights/scripted.trace.json
#
#   --trace PATH       the trace to replay
#                      (default: measurements/flights/scripted.trace.json)
#   --out PATH         artefact path   (default: measurements/flight_replay.json)
#   --append           keep the runs already in the artefact and add this one,
#                      replacing any earlier run of the same trace
#   --synthesise PATH  write a SCRIPTED walk to PATH instead of replaying. Not a
#                      flight: no person saw it, so it carries no marks.
#   --seconds N        length of a synthesised walk (default: 60)
#   --recentre M       metres before the scatter rebuilds, for a synthesised walk
#                      (default: 25)
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tools/replay_flight.gd -- "$@"
