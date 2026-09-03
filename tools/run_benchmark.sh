#!/usr/bin/env bash
# Measure per-instance frame cost (§19.8.9) and write the artefact.
#
# WINDOWED, NOT HEADLESS, AND NOT BY PREFERENCE. Under --headless Godot's
# display server is a stub that draws nothing and still reports frame times;
# every configuration comes back at a few microseconds, which looks exactly
# like a very fast GPU. The scene refuses to record a number there. So this
# runs windowed, on the machine whose coefficient is wanted, and the machine
# is part of the result rather than a note beside it.
#
# The run takes minutes: 54 configurations, each warmed up and then measured
# over 80 frames, with the expensive rungs abandoned from below once one of
# them exceeds eight frame budgets.
#
#     bash tools/run_benchmark.sh [output.json]
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
OUT="${1:-$PWD/measurements/render_cost.json}"
mkdir -p "$(dirname "$OUT")"

echo "== per-instance frame cost =="
echo "writing $OUT"
"$GODOT" --path . res://scenes/bench_instances.tscn -- --out "$OUT"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "-- the benchmark exited $rc; see $OUT for what it refused and why"
  exit "$rc"
fi
python3 - "$OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("refused"):
    print("REFUSED:", d["why"]); raise SystemExit(1)
h = d["host"]
print(f"{h['gpu']} / {h['rendering_method']} / Godot {h['godot']} / {h['os']}")
for k, f in sorted(d["fits"].items()):
    fit = f["frame_p50"]
    if not fit.get("ok"):
        print(f"  {k:18s} {fit['why']}"); continue
    print(f"  {k:18s} {fit['ms_per_instance']*1000:8.4f} ms/1k instances  "
          f"r2 {fit['r2']:.4f}  worst residual {fit['max_rel_residual']*100:5.1f}%  "
          f"({f['rungs_measured']} rungs)")
PY
