#!/usr/bin/env python3
"""
render_budget_answer.py -- read the measured frame cost, answer for an instance count.

§19.8 prices the individual tier's rendering and leaves one coefficient
unmeasured, because measuring it requires the engine. `measurements/render_cost.json`
is that measurement. This turns it into the sentence anyone actually wants: at
N instances per cell, does a frame fit the budget?

WHY IT INTERPOLATES BETWEEN MEASURED RUNGS AND SAYS SO
------------------------------------------------------
The benchmark sweeps a geometric ladder rather than a list of interesting
counts, so any count of interest falls between two rungs that were really
measured. This reports the bracket AND the interpolation, rather than
evaluating a fitted line: a fit is a summary of the ladder, and where the cost
is not linear the summary is wrong exactly where it matters. The measured
neighbours are the evidence; the line is the convenience.

THE INSTANCE COUNTS ARE ARGUMENTS, NOT DATA IN THIS REPO. The per-cell tree
counts they come from are the simulation's measurement and live in that repo.
This tool takes them on the command line so the answer can be recomputed there
without either number being copied into the other's history.

Usage:
    python3 tools/render_budget_answer.py 2000 15000 50000
    python3 tools/render_budget_answer.py --technique multimesh --quantile p99 5000
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / "measurements" / "render_cost.json"


def rungs(doc: dict, technique: str, complexity: str, quantile: str):
    """The measured (instances, ms) pairs for one sweep, ascending.

    Rungs the benchmark marked unmeasured are skipped rather than treated as
    zero -- a configuration that did not draw what it was asked, or was never
    run because the rung below it already blew the budget, has no frame time
    and must not contribute one.
    """
    out = []
    for r in doc["results"]:
        if r["technique"] != technique or r["complexity"] != complexity:
            continue
        if not r.get("measured"):
            continue
        out.append((float(r["instances"]), float(r["frame_ms"][quantile])))
    return sorted(out)


def at(pairs, n: float):
    """Cost at n instances: measured if a rung sits there, else interpolated
    between the neighbours, else extrapolated from the top two with a flag."""
    if not pairs:
        return None, "no measured rung"
    for x, y in pairs:
        if x == n:
            return y, f"measured at {int(x)}"
    below = [p for p in pairs if p[0] < n]
    above = [p for p in pairs if p[0] > n]
    if below and above:
        x0, y0 = below[-1]
        x1, y1 = above[0]
        t = (n - x0) / (x1 - x0)
        return y0 + t * (y1 - y0), f"interpolated between {int(x0)} and {int(x1)}"
    if not below:
        x1, y1 = pairs[0]
        return None, f"below the ladder; the lowest rung measured is {int(x1)}"
    (x0, y0), (x1, y1) = pairs[-2], pairs[-1]
    slope = (y1 - y0) / (x1 - x0)
    return y1 + slope * (n - x1), f"EXTRAPOLATED past the top rung {int(x1)}"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("counts", type=float, nargs="+", help="instances per cell")
    ap.add_argument("--artefact", type=Path, default=DEFAULT)
    ap.add_argument("--quantile", default="p50", choices=["p50", "p95", "p99"])
    ap.add_argument("--technique", default=None, help="default: every technique measured")
    ap.add_argument("--complexity", default=None)
    a = ap.parse_args(argv)

    if not a.artefact.exists():
        print(f"no measurement at {a.artefact} -- run tools/run_benchmark.sh on the "
              f"machine whose coefficient you want", file=sys.stderr)
        return 2
    doc = json.loads(a.artefact.read_text())
    if doc.get("refused"):
        print(f"the measurement was refused: {doc['why']}", file=sys.stderr)
        return 2

    budget = float(doc["budget_ms"])
    h = doc["host"]
    print(f"{h['gpu']} / {h['rendering_method']} / Godot {h['godot']} / {h['os']}")
    print(f"budget {budget} ms per frame, quoting {a.quantile} of "
          f"{doc['method']['measure_frames']} frames\n")

    sweeps = sorted({(r["technique"], r["complexity"], r["triangles_per_instance"])
                     for r in doc["results"] if r.get("measured")})
    for technique, complexity, tris in sweeps:
        if a.technique and technique != a.technique:
            continue
        if a.complexity and complexity != a.complexity:
            continue
        pairs = rungs(doc, technique, complexity, a.quantile)
        print(f"{technique} / {complexity} ({tris} triangles per instance)")
        for n in a.counts:
            ms, how = at(pairs, n)
            if ms is None:
                print(f"  {int(n):>8d}  --          {how}")
                continue
            verdict = "FITS" if ms <= budget else "does NOT fit"
            print(f"  {int(n):>8d}  {ms:8.2f} ms  {verdict:12s}  ({how})")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
