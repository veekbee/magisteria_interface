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

| per instance | 12 tri | 288 tri | 2,400 tri |
|---|---:|---:|---:|
| `MultiMesh` | 12.3 ns | 56.0 ns | 402.8 ns |
| individual nodes | 926 ns | 933 ns | 926 ns |

From the 150,000-instance rung at p50. The two rows are two different cost models, and neither is a
variation on the other:

- **Individual nodes cost ~0.93 µs per instance and do not care what the mesh is.** 926 ns at 12
  triangles against 926 ns at 2,400 — a 200× range of geometry for no measurable difference. One
  draw call per instance, which the counter confirms as exactly `n`, and the draw call is the whole
  cost.
- **`MultiMesh` costs about 9.7 ns per instance plus 0.164 ns per triangle.** One draw call for the
  whole set. At 2,400 triangles that predicts 403 ns and measures 403; at 288 it predicts 57 and
  measures 56.

So the ratio between techniques is not a constant: `MultiMesh` is **75× cheaper per instance at 12
triangles and 2.3× cheaper at 2,400**. A single "per-instance frame cost" quoted without the
technique would be somewhere in that range and conditional on a decision nobody recorded.

**Is cost linear in instance count?** Above 16,000 instances, yes, and the marginal is the number to
carry rather than the fitted slope. `MultiMesh` at 2,400 triangles holds 0.395–0.408 ms per 1,000
instances across four rungs, a spread of 1.03×; individual nodes hold 0.85–0.95 across every sweep,
within 1.10×. Below 16,000 the frame sits on a floor of about 1.4 ms and the marginal is noise,
which is why the whole-ladder fits carry residuals from 27% to 197%: **the straight line is a bad
summary at the bottom of the ladder and a good one at the top.** The `frame_p50_marginals` block is
the honest form of the answer.

**One sweep is not reproducible and it is always the same one.** `multimesh` at 288 triangles moves
by up to 1.7× between runs and produced a rung here that cost nothing over the rung below it, which
is what its 197% residual and its undefined marginal spread record. Every other sweep repeats to a
few percent. Something about that configuration — fast enough to sit near the timer's floor, heavy
enough to leave it — is not being measured stably, and this benchmark does not say what. Read
`multimesh|mid` as the one row of the table with a factor of two on it.

**Reproducibility.** Two independent hardened runs of all 54 configurations agree to a median of
**4.0% at p50** (worst rung 46.3%, and it is `multimesh|mid`) and **6.2% at p99**. Read a verdict
within a few ms of the budget as undecided.

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
