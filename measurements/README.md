# `measurements/` — numbers this repo measured, not artefacts it was given

Everything in `assets/` was made somewhere else, vendored and pinned. This directory is the
opposite: a measurement that can only be taken *here*, because the thing being measured is the
engine. It has no `PIN` and no upstream, and it is not vendored — but it carries the same four
claims a `PIN` does: what was measured, how, on what, and what it does not cover.

## `render_cost.json` — per-instance frame cost

§19.8 prices the individual tier's rendering. Every term in it is measured except one, and the
corpus declines to estimate that one:

> **One coefficient**: per-instance frame cost, which requires the engine. It is not estimated
> here, because a plausible-looking number with nothing behind it is worse than a named absence.
> — §19.8.9

§19.8.9 names two instruments for it. The first, the simulation's `tools/render_budget.py`, is
built and gives real instance counts per cell. The second is a Godot benchmark scene, and its
stated blocker was the transducer existing. It does now, so this is that scene:
`scenes/bench_instances.tscn`, driven by `bash tools/run_benchmark.sh`.

**Re-measure rather than believe.** The coefficient is a property of one machine, one renderer and
one Godot build, and none of those travel. Run the script on the hardware whose answer you want.

## What it measures, and the three things it refuses to do

**It refuses to run headless.** Under `--headless` the display server draws nothing and still
reports frame times; every configuration comes back at a few microseconds, which looks exactly like
a very fast GPU. The scene checks the display server it got and writes a refusal instead of a
number.

**It refuses to record a frame that was not drawn.** An unfocused or occluded window on macOS stops
being rendered while the main loop keeps ticking: `Performance`'s counters freeze at their last
values and every frame arrives on a fixed cadence. The first two runs of this benchmark lost
configurations to exactly that, and could not tell it from a cheap scene. Every configuration now
compares its primitive count against instances × triangles, its draw calls against what the
technique needs, and `Engine.get_frames_drawn()` against the number of frames it timed; a
configuration that fails any of the three is re-measured, and recorded as unmeasured with the counts
if it keeps failing.

**It refuses to report the GPU timer it cannot read.** `RenderingServer`'s measured render time is
not implemented under the `gl_compatibility` renderer and reads zero on every frame. Zeros recorded
as milliseconds would be a fabricated measurement wearing a real name, so the field carries an
absence and its reason instead.

## The method, in the numbers that would change the answer

| | |
|---|---|
| instances | a geometric ladder, 1,000 → 150,000, spanning where §19.8.4's example horizons land |
| techniques | `MultiMesh` and individual `MeshInstance3D` nodes — two coefficients, not one |
| complexity | 12, 288 and 2,400 triangles per instance |
| placement | uniform random in a flat 1,000 m square, seeded; no terrain under it |
| camera | directly overhead, 60° FOV, footprint fills the frame — every instance in frustum |
| viewport | 1280 × 720, vsync disabled, no fps cap |
| per rung | 20 warm-up frames, then 80 timed frames |
| quoted as | nearest-rank quantiles: p99 of 80 frames is the 80th-ranked frame, not an interpolation |
| budget | 33.3 ms (§16.10) |

**No terrain is drawn.** This measures instancing; a scene with M1's basin under it would measure
two things and let neither be recovered.

**Every instance is in frustum.** A real view culls, so these are the costs of a cell wholly in
view — which is the honest worst case for a budget question.

## What it found on the machine it was run on

Apple M5 (10-core GPU) / `gl_compatibility` / Godot 4.7.2 / macOS 26.6.2, windowed, 1280 × 720.

**The technique is not a detail of the coefficient. It is the coefficient.**

| technique | 12 tri | 288 tri | 2,400 tri |
|---|---:|---:|---:|
| `MultiMesh` | 13.9 ns | 56.0 ns | 400 ns |
| individual nodes | 861 ns | 878 ns | 887 ns |

Per instance, from the 150,000-instance rung at p50. The two columns of that table are two
different cost models, and neither is a variation on the other:

- **Individual nodes cost ~0.9 µs per instance and do not care what the mesh is.** 861 ns against
  887 ns across a 200× range of triangle counts. One draw call per instance — the counter confirms
  exactly `n` of them — and the draw call is the whole cost.
- **`MultiMesh` costs about 8 ns per instance plus 0.17 ns per triangle.** One draw call for the
  whole cell. At 2,400 triangles that predicts 400 ns and measures 400 ns; at 288 it predicts 57 ns
  and measures 56 ns.

So the ratio between the techniques is not a constant: `MultiMesh` is **62× cheaper per instance at
12 triangles and 2.2× cheaper at 2,400**. A single "per-instance frame cost" quoted without the
technique would be somewhere in that range and conditional on a decision nobody has recorded.

**Is cost linear in instance count?** Above 16,000 instances, yes, and the marginal cost is the
number to carry rather than the fitted slope. `MultiMesh` at 2,400 triangles holds 0.386–0.402 ms
per 1,000 instances across four rungs — a spread of 1.04×. Individual nodes hold 0.93–1.03 ms per
1,000 from 16,000 to 128,000. Below 16,000 the frame sits on a floor of about 1.4 ms and the
marginal is noise, which is why the whole-ladder fits in `render_cost.json` carry residuals of 15%
to 95%: **the straight line is a bad summary at the bottom of the ladder and a good one at the
top.** The `frame_p50_marginals` block is the honest form of the answer.

The one rung that breaks it: from 128,000 to 150,000 the individual-node sweeps flatten (marginal
falls to 0.19–0.36 ms per 1,000) as the frame approaches ~130 ms. Something other than draw-call
submission binds there, and this benchmark does not say what.

**Reproducibility.** Two independent hardened runs of all 54 configurations agree to a median of
**3.9% at p50** (worst rung 24.2%) and **6.5% at p99** (worst 63.8%, on a configuration whose frame
is under 6 ms). Read a verdict within a few ms of the budget as undecided.

## Reading it

`tools/render_budget_answer.py` turns the ladder into the sentence anyone wants — at N instances
per cell, does a frame fit? It interpolates between the two rungs that were really measured and
says which they were, rather than evaluating a fitted line: a fit is a summary of the ladder, and
where cost is not linear the summary is wrong exactly where it matters.

```
python3 tools/render_budget_answer.py --quantile p99 2000 15000 50000
```

The per-cell instance counts those N come from are the simulation's measurement and live in that
repo. They are arguments here, not data committed here.
