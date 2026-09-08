# `measurements/` — numbers this repo measured, not artefacts it was given

## Before quoting a number from a new capture path, open one frame

Not "when the numbers look odd" — unconditionally, the first time any harness photographs anything.
Three artefacts in this project have come back complete, plausible and wrong, and **not one of them
was caught by reading numbers**: a per-family reference that was three copies of the same frame, two
motion runs that scored one frozen image against every position, and a scatter that was drawing the
previous build's instances. Each was found by opening a PNG, and each had a numeric tell that was on
screen and unread at the time.

`HarnessGuard` now refuses all three shapes — an identical capture across a move, two signatures that
must differ coming out equal, a stage that stops advancing — and those refusals are worth more than
this paragraph. But they are the shapes that have already happened. Looking is what finds the next one.

Everything in `assets/` was made somewhere else, vendored and pinned. This directory is the
opposite: a measurement that can only be taken *here*, because the thing being measured is the
engine. It has no `PIN` and no upstream, and it is not vendored — but it carries the same four
claims a `PIN` does: what was measured, how, on what, and what it does not cover.

## What is here

- `render_cost.json` — per-instance frame cost, and the ladder it was fitted from. It prices an
  empty stage, which makes it a **floor** rather than a prediction; see the ruling under
  `scatter_cost.json` for why it stays one.
- `scatter_cost.json` — what M5's scatter costs a frame in the viewer that draws it, and whether
  `render_cost.json`'s empty-stage coefficient predicts it. Re-take it with
  `bash tools/measure_scatter.sh`.
- `scatter_bands.json` — what distance-banded density schedules cost and cover, for deciding where
  individual instances should stop and a collective representation start. Re-take it with
  `bash tools/measure_bands.sh`.
- `scatter_seam.json` — how far a far-field candidate sits from the instances it stands in for,
  scored in an annulus around the seam. Re-take it with `bash tools/measure_seam.sh`.
- `scatter_horizon.json` — the individuation constant `k` swept at the basin's five densest cells,
  which is where decision 949's `[PROVISIONAL]` ruling is tested. Re-take it with
  `bash tools/measure_seam.sh --sweep-k --at X,Y --out measurements/scatter_horizon.json`.
- `scatter_motion.json` — what the far field does when the camera MOVES: a scripted dolly through
  the seam and a lateral-step parallax pair. Roadmap item 2. Re-take it with
  `bash tools/measure_motion.sh`.
- `flights/*.trace.json` — recorded camera paths: what a person did, frame by frame, at walking
  pace. Fixtures, not results. Record one with `bash tools/free_flight.sh`.
- `flight_replay.json` — a trace scored again from its poses alone, headlessly. Re-take it with
  `bash tools/replay_flight.sh --trace measurements/flights/<name>.trace.json`.
- `ground_relief.json` — what the ground actually has, at the overview the client draws and at
  the tile pyramid's native 100 m, and which of two blockers walk mode was refusing on. Headless.
  Re-take it with `bash tools/measure_relief.sh` (needs `python3 tools/fetch_artefacts.py` first).
- `visual_audit.md` — what each milestone's claim looks like when photographed, and the five
  defects that came out of looking. Re-take it with `bash tools/audit.sh`.

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

### Does the paced timer censor these coefficients? Checked — no, and the benchmark saw it coming

`scatter_cost.json`'s rung finding lands here too, because §24 cites these coefficients. Asked
directly of all three multimesh ladders, on the artefact as it stands. **All three coefficients
stand.** The determination, and it is not the same answer for each:

| | 12 tri | 288 tri | 2400 tri |
|---|---:|---:|---:|
| quoted (paced `frame_p50`) | 9.607e-6 | 5.386e-5 | 3.9958e-4 |
| refit on the **unpaced** reading | 8.445e-6 | 5.379e-5 | 3.9963e-4 |
| moves by | **−12.1%** | **−0.1%** | **+0.0%** |
| rungs reporting every frame at one value | 1 of 9 | 1 of 9 | 5 of 9 |

**The benchmark already carried its own defence, and that is why this is a short answer.** Every
rung records `wall_clock_mean_ms` beside `frame_ms`, with the note *"the per-frame delta quantises
on this platform and a mean that disagrees with p50 is how that shows."* The pacing was known when
this was built and a second, unpaced reading of the same 80 frames was written down next to every
rung. `scatter_cost.json` did not inherit that, which is exactly why the finding surfaced there and
not here. (`gpu_p50` would have been better still and is unavailable — `gl_compatibility` reports no
GPU render time. `cpu_ms` is 0.04–0.12 ms throughout and never the bottleneck, so it cannot stand in.)

**2400 tri — clean, and the pacing is loudest here.** Five of nine rungs report every frame
identically, so the ladder is unmistakably present. It does not matter, because the rungs span
0.67 → 60.4 ms and each lands on a *different* rung of it. Paced and unpaced fits agree to four
significant figures; r² is 0.99997 and 0.999996. Dropping the five pinned rungs moves the
coefficient by −0.1%. **This is the coefficient the corpus leans on hardest and it is the safest of
the three.**

**288 tri — genuinely censored, and the artefact's own reading of it was wrong.** 64,000 and 128,000
instances both report `frame_p50` of exactly **7.1429 ms**, so the artefact records a marginal of
**zero** and explains it as *"the fixed-cost floor rather than a per-instance cost"*. It is not a
floor: 64,000 more instances at 288 triangles is 18.4 M triangles and cannot be free. The unpaced
reading separates the pair — **6.76 against 7.27 ms** — and every unpaced marginal on this ladder is
positive. The coefficient moves 0.1%. **The number stands; the explanation beside it did not.**

**12 tri — not censoring, which is what both sessions guessed and neither had right.** The −0.000125
marginal is between the 2,000 and 4,000 rungs, and *neither is pinned* — both span 0.30 to 1.39 ms.
The negative survives on the unpaced instrument and gets **worse** (−1.52e-4). What it actually is:
**the sweep was still warming up.** The first two rungs measure dearer than the rung above them
(wall means 0.836, 0.719 against 0.415 at 4,000) and `cpu_ms` *falls* across them, 0.059 → 0.055 →
0.046, which is a process settling and not work. Drop the first two rungs and r² goes **0.884 →
0.998**; drop three and every marginal is positive at r² 0.9996 with a coefficient of 1.0023e-5 —
**+4.3% from the quoted figure, inside the benchmark's own reproducibility.** The number stands. Its
stated reason did not, and the defect is real but is a warm-up defect, not an instrument one.

**What changed in the code, and what did not.** `FrameStats.marginals` now takes the unpaced series
and distinguishes the three causes it used to collapse into one — *censored by the paced timer*,
*not the timer*, and *the fixed-cost floor*, which it is only entitled to claim when neither of the
others applies — and flags the warm-up signature separately when a sweep's first rung measures
dearer than a later one. `test_the_benchmark_ladder_says_which_rungs_the_timer_could_not_separate`
runs that over the three real ladders in the gate, so this determination is checked on every run
rather than being a paragraph.

**`render_cost.json` is deliberately NOT re-run.** The determination is that its coefficients stand;
re-measuring would move them by noise and force every citation of them to be re-taken for nothing.
The warm-up finding is a reason to drop the head of a sweep before quoting a fit, not a reason to
discard this one.

**And it is a floor, not a forecast.** The empty stage is the point of it, and no frame the client
draws has ever met it: the real scene has come in above the prediction in every run taken, by about
a third. Quote the coefficient with the observed ratio beside it rather than on its own — the ruling
and the current ratio are under `scatter_cost.json` below.

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


## `scatter_cost.json` — what the scatter costs in the scene that draws it

`render_cost.json` prices instancing on an empty stage: a placeholder mesh over a flat square, no
terrain, no culling, no LOD. That is the right shape for a coefficient — a basin underneath would
make it a joint measurement of two things and let neither be recovered — but it means every
sentence M5 writes about a frame is a *prediction* from that coefficient rather than an observation
of one. The 1,500 m horizon figure in particular was reported by the scatter at runtime and
committed nowhere, which makes it a number with a derivation and no artefact. This is that
artefact, and it checks the derivation against the frame it describes.

**The method is subtraction.** The same scene is timed twice, once with the scatter drawn and once
with it hidden, and the cost is the difference. A single timing of the viewer is the terrain, its
overlay, the flowlines, the contours, the UI and the scatter added together, and no arithmetic
recovers one term of that sum.

### What it found

`deepest_winter`, `band.pft.biomass`, day 22, standing at EPSG:5070 `(-1310793, 1616226)` — the
centre of the opening view — with the fly camera framed on the scatter, which is what the `G` key
gives. Apple M5 / `gl_compatibility` / Godot 4.7.2, windowed at 1280 × 800, vsync
*requested* off — see the instrument section, which is why that qualifier is there. **Re-taken
at 1:1**; the 12× column below is the same scene at the old scale, kept for the one comparison it
makes possible and quoted nowhere else.

| | 12× (superseded) | **1:1** |
|---|---:|---:|
| instances drawn | 119,994 | **119,994** (ceiling-bound) |
| triangles in frame | 5,944,404 | **5,944,404** |
| frame p50, scatter hidden | 0.80 ms | **0.55 ms** |
| frame p50, scatter drawn | 3.70 ms (all 80 frames) | **3.40 ms** (3.33–3.70) |
| **marginal, p50** | 2.90 ms | **2.85 ms** |
| `render_cost.json` predicts | 2.13 ms | **2.13 ms** |
| ratio | 1.36× | **1.33×** |
| pixels the scatter changed | 4,387 | **778** |

**The empty-stage coefficient under-predicts, consistently.** Six runs at 1:1 gave marginals of
2.93, 3.12, 2.88, 2.85, 2.86 and 2.85 ms against a 2.13 ms prediction — **1.33× to 1.46×**. Five of
the six sit within 0.08 ms of each other, which is inside the instrument's step and so is not
reproducibility that has been demonstrated, only agreement that has not been contradicted; the 3.12
outlier came with a busy-frame p99 of **5.64 ms against 3.70 for every other run**, which is the
signature of something else on the machine during that run rather than of the scene. That is the
one place run-to-run contention is visible in this data, and it is visible in the tail rather than
in the median — which is the right place to look for it. Five runs at 12× gave 2.94, 2.90, 2.83, 2.75 and 2.74 — 1.28× to 1.37×. Across all ten,
**never once below the prediction.** That is a bias rather than noise, and it is the size of the
conditional on every budget sentence M5 rests on that coefficient. What it does *not* say is which
of the differences is responsible: this scene draws through a custom shader with culling disabled
rather than a `StandardMaterial3D`, it overdraws a terrain rather than empty space, and it uses
three MultiMesh nodes rather than one. Naming the cause needs a sweep this artefact does not run.

**The scatter's cost is per-instance, not per-pixel, and the scale change is what showed it.**
Going to 1:1 shortened every plant by twelve and the scatter's drawn pixels fell **5.6×**, from
4,387 to 778 — shrub 213 → 38, succulent 3,758 → 595, tree 627 → 161. The frame cost did not follow
it down: 2.90 ms then, 2.85 ms now. **Read that to about half a millisecond, not to the digits** —
see the instrument section below — but the conclusion does not need the digits. An 82% reduction in
fill that cost fill-bound work anything like its share would have moved the marginal by more than a
millisecond, which this instrument resolves easily; it moved by less than its own step size. The
same instance count over the same triangle count costs the same time whether it covers 4,000 pixels
or 800. This was not measured on purpose; it fell out of re-taking a stale artefact, and it is the
strongest thing the file says.

**Which is also why the empty-stage coefficient stays.** The under-prediction held at 1.36× and
1.37× across a 5.6× change in fill, so the gap between the empty stage and this scene is not fill —
it is per-instance overhead the empty stage does not have. A coefficient re-measured with a basin
under it would fold the two together and let neither be recovered. See the ruling below.

### The instrument: `delta` is paced, and a spread of zero is the proof

**Frame time here is not free-running, and asking for no vsync does not make it so.** The harness
calls `window_set_vsync_mode(VSYNC_DISABLED)` and sets `Engine.max_fps = 0`, and the artefact used
to record `"vsync": "disabled"` as a flat fact. It was recording the *request*. Probed directly:

- An **idle** window gives a continuum — 125 distinct `delta` values over 300 frames, around
  0.29–0.34 ms — so the timer itself is fine and fine-grained.
- A frame held **busy** lands on rungs. Observed rung values: 1/720, 1/360, 1/330, 1/300, 1/270,
  1/240, 1/220, 1/210, 1/200 and 1/180 s. Near 3.5 ms that is a **step of 0.3–0.5 ms**.
- A busy-wait held at **3.4 ms** reported **four distinct values over 140 frames, 97 of them the
  same one**, with a floor of 4.167 ms — 0.77 ms above the work actually done.

**So a scene whose cost sits inside one rung reports every frame at that rung, and a spread of
zero.** That reads as an exceptionally steady measurement and is the opposite of one. The 12×
run did exactly this: all 80 busy frames at 3.7037 ms, `scene_spread_ms` **0.020**, `resolved`
true — and nothing in the file said the number was the rung's rather than the scene's. Its
apparent stability was the instrument having one value available, and it was quoted here as
reproducibility.

`ScatterCost.marginal` now detects it: a timing whose `min` equals its `max` sets
`instrument_limited` and a note saying the cost is censored inside one rung. The 1:1 runs are not
pinned — they cross rungs, 3.33 to 3.70 — so their p50s are real samples, but the **marginal is
still a difference of two rung-quantised numbers and its resolution is roughly ±0.5 ms.** Every
sub-0.1 ms comparison in this file should be read as "not resolved", including the 2.90-vs-2.93
above and most of the run-to-run scatter.

This does not touch the ratio to `render_cost.json`, which is 1.36× — far outside the step — nor
the floor ruling, which rests on a sign and not on a magnitude.

### One thing changed that this file cannot explain

Draw calls in the same scene fell from 223 to 29 with the scatter hidden (226 → 32 with it drawn:
the delta of three, one per MultiMesh, is unchanged), and the hidden-scatter frame got 32% faster,
0.80 → 0.57 ms. Primitives are essentially unchanged, 210,423 → 212,503, and **every layer was
confirmed still drawing** — photographed alone against black, the contours put 926 px on screen and
the flowlines 14,533 px. So nothing was lost; the same geometry is arriving in a seventh of the
calls. No commit between the two runs names a cause, and none of the drape or contour code builds
more than one surface. Recorded as observed and unexplained rather than attributed, because the
marginal is a difference and is unaffected by it either way.

**The horizon question, which is what the coefficient was wanted for.** At this place, the full
scatter the wire implies inside a 1,500 m horizon is **51,869,460 instances — 922 ms, 27.7× the
33.3 ms budget**. What is drawn is 0.2% of it, and the binding limit is the build ceiling rather
than the frame budget.

**That number is a property of a place, not of a horizon** — the implied count is cover and biomass
summed over whatever cells fall inside the disc, so a horizon figure quoted without the place it was
taken at is not reproducible. The place travels in the artefact, and `--at X,Y` pins a re-run to it
rather than to the framing.

**And it moved by 1.8× when the cover reading was corrected** — 28,092,359 before, 51,869,460 after
— which is the opposite direction to the one the correction sounds like it should push. Cover fell
(a life form's ground cover is its composition share × `1 - bare_fraction`, not the share), and
crown width is derived from cover while count is cover ÷ crown area, so cover enters the count twice
with opposite signs and the smaller number wins. **That coupling is M5's parameter derivation and is
not fixed here**; it is recorded because the correction is what made it visible.

### The verification had to change, and that is a finding about the benchmark's check

`InstanceBench` verifies a configuration by comparing `RENDER_TOTAL_PRIMITIVES_IN_FRAME` against
instances × triangles. Over M5's families that check is **wrong**:

| family | instances | authored tri | counter reported | pixels drawn |
|---|---:|---:|---:|---:|
| succulent | 108,672 | 48 | 5,216,256 — exactly n × 48 | 2,988 |
| shrub | 10,947 | 70 | **20** | 344 |
| tree | 387 | 44 | **14** | 1,312 |

The 20 does not move when `visible_instance_count` is set to 100 and then to 1, so it is not
counting instances at all; it follows the *multimesh* rather than the node. All three families are
drawing — the pixel counts scale with instance count exactly as the counter fails to.

**The 20 and the 14 are generated LODs**, read out of the meshes rather than inferred:
`meshes/generate_lods=true` on all four `.import` files, and `RenderingServer.mesh_get_surface`
reports one generated level for shrub (70 → **20** triangles, edge 0.279) and one for tree (44 →
**14**, edge 0.344) and **none at all** for grass and succulent, whose base meshes the simplifier
declined to reduce. So the counter reports the last entry of a mesh's LOD chain, once, for a mesh
that has one, and instances × triangles for a mesh that does not.

What that does *not* settle is which level was being drawn at the measured camera, because forcing
`lod_bias` to 0.001 moved neither the counter nor the pixels. The difference is below this
instrument anyway: 10,947 shrubs at 70 triangles rather than 20 is 547,000 triangles, about 0.09 ms
by the coefficient, against a scene spread of 0.24 ms.

Two consequences. The check here is the one the screenshot harness already makes — **showing the
scatter must change the frame in pixels** — which is weaker, cannot say how many instances arrived,
and has the property that matters: it does not pass a frame the scatter is missing from. And
`render_cost.json`'s own verification is *not* invalidated, because it swept one MultiMesh of a
procedural mesh and the counter tracked it exactly there; but anyone reusing that check on other
meshes should confirm the counter tracks them first.

### The ruling: `render_cost.json` is a floor, and stays one

The corpus row citing the per-instance coefficient carries its conditions — one machine,
`gl_compatibility`, and **no culling, no LOD, no terrain**. Two of those three have since changed in
the viewer: the scatter thins with distance and the far field is drawn. The row is therefore
true-as-written about the artefact it cites and misleading-in-effect about the client it describes,
and the question was whether to re-measure the coefficient in the scene that now exists.

**It is not re-measured, and the reason is that the floor property survived a test nobody designed.**
A coefficient measured with a basin under it is no longer a coefficient: it is a joint measurement of
instancing and one particular scene, which is exactly what `scatter_cost.json` already is. Two
artefacts of the same quantity under different names is worse than one floor and one observation,
because neither is recoverable from the other. And the empty stage behaves like a floor: ten runs
across a 5.6× change in drawn pixels and a 12× change in vertical scale, never once below it, with
the gap holding at ~1.36× throughout. A number that stable under that much perturbation is measuring
something real about instancing rather than something incidental about a scene.

**So the two figures sit together, and the second one is the one that gets re-taken.** The row wants
the coefficient stated as a floor *and* the observed ratio beside it — currently **1.34× to 1.46×,
five runs, 1:1, this scene**. When LOD or the seam moves the client again, it is this ratio that
moves; the floor underneath it does not, and re-measuring it would only make the pair less
informative. `test_the_empty_stage_coefficient_is_a_floor_and_the_scene_sits_above_it` fails if a
scene ever comes in *under* the prediction, at which point the word "floor" is what has to change,
not the artefact.

The conditions worth adding to the row are not new measurements but a sentence: the coefficient is a
lower bound on instancing alone, and the client has never rendered a frame that met it.

### What it does not cover

**Frustum culling is all-or-nothing, and it works.** Timed at the same place: 1.04 ms with the
scatter hidden, 3.70 ms with the camera on it, and **0.85 ms with the camera turned 180°** — the
three vegetation draw calls disappear and the primitive count returns to the baseline's. A
MultiMesh is culled as one node against one AABB, so looking away from the scatter is free and
looking at any part of it costs all of them. Nothing between those two is available without
splitting the scatter into more than one MultiMesh. *(Those three timings are 12×-era and were not
re-taken; the property is structural and the scale change moved the marginal by less than its own
spread, but they are illustrations of a shape rather than current figures — the harness has no flag
for the turned-around camera, so re-taking them is a hand-driven run.)*

One machine, one renderer, one place, one window, one day, one camera distance. The coefficient it
is checked against is itself not portable, and neither is this. It measures the scatter that was
*drawn*, which is the build ceiling's 119,994 instances and not the **51,869,460** the wire implies
at this place — the **922 ms** figure remains a prediction, now made from a coefficient known to
under-predict by about a third in this scene, and known not to notice fill at all.


## `scatter_motion.json` — the dolly, and why it does not catch popping

Roadmap item 2: *"scripted dolly through the seam scoring worst frame-pair delta in the annulus;
lateral-step parallax pair. Static sufficiency does not cover temporal defects."* Built, run, and
**it does not do the job it was wanted for.** That is the finding, and it is worth more than a table
of smooth-looking numbers would have been, because the item exists to gate backlog 198's inversion
before it lands.

**Nothing pops today, so the harness ships with the thing that would.** The scatter is built once
around a place and does not follow the camera, so dollying changes the view and not the population.
Backlog 198 proposes solving the horizon from an instance budget *per place*, which makes the
population a function of where the camera is — and then every camera step re-decides which instances
exist. `rebuilt` does exactly that at every step and is the deliberately popping control; `static` is
what ships; `tint` is painted on the ground and cannot pop, which calibrates the other two.

**The metric ranks them wrong.** `deepest_winter` day 22, place B, k/k_res = 0.35, 12 dolly steps of
20 m, annulus 84–180 m:

| | coverage worst / median | ratio | colour worst / median | ratio |
|---|---|---:|---|---:|
| static | 0.189 / **0.000** | — | 0.092 / 0.018 | 5.13× |
| **rebuilt** (the control) | 0.080 / 0.016 | **4.90×** | 0.097 / 0.016 | **5.98×** |
| tint (cannot pop) | 0.091 / 0.007 | **13.43×** | 0.042 / **0.000** | — |

The control is not separated from the static scene, and the candidate that *cannot* pop scores worst.
Three measured reasons:

1. **Coverage saturates.** `static` sits at 1.000 for ten of twelve steps — `lit_pixels` equals
   `ground_pixels` exactly — so the median adjacent delta is zero and there is no ratio at all.
2. **The ratio is unstable near zero.** A candidate that varies very little gets a huge score from
   one ordinary step, because the denominator is nearly nothing. That is the whole of the tint's
   13.43×.
3. **An aggregate is blind to a local event, which is what a pop is.** Coverage and mean colour are
   means over ~8,000 pixels; re-centring the horizon disc on a camera 20 m away changes the
   population at the disc's rim, which is the far edge of the annulus and sub-pixel there.

**The same-camera comparison was the obvious next instrument, and it does not close it either.**
Comparing `static` against `rebuilt` at the *same* camera position removes camera motion entirely —
same camera, same terrain, same day, only the population differs. It reports **77–85% of annulus
pixels changed at every position, at a worst/median of 1.10**. Large and *steady*: two different
scenes rather than one flickering, and steadiness is what says so. It is large because `static`
measures its horizon from the place while `rebuilt` measures it from the camera, so at 240 m back
they are simply not the same scene.

### The metric that does work: the population, not the picture

Reprojecting the previous frame was the obvious next step and it is not the one taken. Motion
compensation needs the depth of the **plants**, not of the ground under them, and depth written
through an sRGB viewport has already cost this project one harness. So the measurement moved off the
screen and onto the thing being measured: **a pop is an instance that exists in one frame and not the
next**, and the instance set is exact, cheap, and cannot be handed a frozen frame.

| | worst churn, instance set | worst churn, weighted by pixels |
|---|---:|---:|
| static (one build, dollied through) | **0.0000** | 0.000 |
| rebuilt, before placement-by-hash | **1.0000** | 2.892 |
| rebuilt, after | 1.0000 | 1.478 |

**`static` churning exactly zero is the calibration, not a nicety.** It is one build looked at from
twelve places; it *cannot* churn, so any non-zero reading is the instrument counting the movement of
its own measurement window. The first version did exactly that — 0.12 instead of 0, from filtering
set membership by what the camera could see. Membership is existence; the camera enters only in the
pixel weight.

**The control's 1.0000 was literal, and that is the row that has been fixed.** At a 22 m camera
step: 36,081 instances before, 28,358 after, **28,350 appeared and 33,117 gone** — eight survivors.
The next pair had none at all. Mean churn across the dolly was 0.8838.

### Why re-centring replaced the whole stand, and what is left after the fix

That was not a rim of instances crossing the horizon; it was every one of them, and the cause was the
placement. `VegetationScatter` seeded **one** `RandomNumberGenerator` per build and consumed it in
`wanted` order, and `wanted` is assembled by scanning texels relative to the **centre**. Moving the
centre by twenty metres made every draw from that sequence land on a different instance — so an
inversion that solves the horizon from an instance budget *per place* (backlog 198) would have made
the entire far field boil on every camera movement, which no crossfade schedule addresses.

**Placement is now a function of the ground.** A candidate's position comes from a hash of its own
sub-cell's quantised world coordinates, its family and its index in that sub-cell; thinning takes a
stable prefix of a fixed per-sub-cell order, so a falling share removes plants and a rising one
restores the same ones. `SCATTER_SEED` is a world key now, not a sequence seed, and no random stream
is consumed anywhere in the build.

The gate checks it three ways rather than inferring it from the pictures: the same ground reached
across an 1,800 m disc and a 2,600 m one places the same plants (26,283 of them, identical fold); the
same holds through the subdivided path the seam work actually uses; and a build re-centred 25 m away
agrees **texel for texel** with the build it moved from. The instrument is an order-independent XOR
fold of every placed instance's quantised position, per texel — instance transforms cannot be read
back headless, so the report is the checkable statement, as it is for everything else here.

**What re-taking `scatter_cost.json` says about the other artefacts.** Instance counts, per-family
counts and triangle counts came back **identical** — `round(count × keep × share)` is the same
arithmetic it was, and only *which* plants those are has changed. Screen-space rows moved by a
resampling: shrub 38 → 30 px, succulent 595 → 553, tree 161 → 180, the frame's changed pixels 778 →
746, the marginal 2.846 → 2.853 ms. So `scatter_seam.json` and `scatter_horizon.json` are not stale
in their counts, shares, budgets or verdicts, and their pixel and colour rows are a different sample
of the same stand at the scale of the numbers above. They are flagged here rather than re-taken.

### What the fix does not remove, and it is the number backlog 198 needs

Re-centred churn fell from a mean of 0.8838 to **0.4702**, and the residue is not placement. It is the
**individuation horizon moving with the camera**, which is correct: the cut is `k × height` measured
from the build's centre, so a step re-selects which sub-cells the rule admits. What survives ranks
exactly by how large a family's disc is relative to the 21.8 m step:

| family | reach | in sub-cells | survived a step | a smooth cut would allow | reached |
|---|---:|---:|---:|---:|---:|
| grass | 57.6 m | 1.8 | 0.260 | 0.760 | 0.34 |
| shrub | 121.3 m | 3.9 | 0.463 | 0.886 | 0.52 |
| tree | 991.4 m | 31.7 | **0.907** | 0.986 | **0.92** |

Trees keep essentially everything a continuous disc would allow. Grass and shrub fall well short of
it, and the reason is the same one `scatter_horizon.json` already refuses on from the static side:
**the cut is evaluated at sub-cell centres**, so a reach of 1.8 sub-cells is a blocky handful of
cells that a 0.7-sub-cell step re-selects wholesale. It is one defect seen twice, not two.

The consequence for backlog 198 is now a bounded one rather than a total one: a per-place instance
budget may re-centre freely for the families whose horizon is many sub-cells across, and for the
small families it re-selects the whole population every step or two until the cut is evaluated at a
finer grain than the placement raster — which is the same lever `k`'s floor of 0.35 already names.

**What the harness cannot say.** Nothing about how a *pan* behaves — the camera translates and never
rotates — and nothing about whether a churn of, say, 0.05 would be visible. The zero and the one are
unambiguous; the threshold between them is not measured, and calling one is a design judgement this
does not make.

**A refusal that fired twice, for real.** On this platform a window that loses focus or is occluded
stops being drawn while the main loop keeps ticking, so `get_image()` goes on returning the last
frame rendered. It cost two complete runs: every candidate after the freeze scored one frozen image
against each position's own mask, which gave *different* numbers per position and *identical* ones
between candidates — a table that looked like a result. Three saved PNGs from three different
candidates and positions came out byte-identical, which is how it was found. The harness now
compares each capture with the last and refuses when two are identical across a camera move, and it
renders at 640 × 400 because every score here is a ratio and the pixel loops were minutes of CPU
with no frame drawn — which is when the compositor gives up.

**The parallax pair** is recorded and says little yet: over a 4 m lateral step the tint's mean colour
in the annulus does not move measurably and the instances' moves by ΔE 0.018. That is the expected
direction — a tint painted on the terrain shifts with the ground it is on — but with the dolly metric
unable to separate its own control, this pair is not load-bearing either.

### What it does not cover

One place, one day, one dolly axis, one `k`. The camera translates and never rotates, so nothing here
says what happens when a viewer turns — which is the motion a viewer actually makes most.

## `flight_replay.json` — a walk at walking pace, recorded once and scored forever

Everything above is an aggregate over a scripted path. Two of the open questions are not aggregate
questions — **where between 0 and 1 a churn becomes visible**, and **what a pan does** — and neither
can be answered by pointing a harness at itself. They need a person moving through the world the way
a player would.

The risk in that is a judgement nobody can reproduce, which is the opposite of everything else here.
So the flight is not the measurement: **the trace is**.

1. A person flies, at 5 m/s, translating and panning (`bash tools/free_flight.sh`).
2. Every frame records the pose, the population, what is in front of the camera, the churn, the
   frame time, and whether the window was actually being drawn.
3. The trace is pinned as a fixture in `flights/`.
4. `bash tools/replay_flight.sh` scores it again, headlessly, on any machine, forever.

**5 m/s is not a round number picked for being round.** It is the speed the corpus derives for an
avatar under its own kinematic compression (§3.1c), so tuning here is tuning at the speed the world
will be seen at. The harness records what was *travelled* rather than what was *asked for*, and the
pinned path measures 5.00 m/s mean off its own poses.

### The replay is headless, which every other harness here refuses to be

The others photograph frames, so the dummy renderer — which draws nothing and reports success — is
fatal to them. This one photographs nothing. What it recomputes is the **population**, and that is
arithmetic over the scatter's own census rather than anything read off a screen.

That is only possible because of the placement rule. Two builds that admit the same sub-cell hold
the first `n_a` and the first `n_b` plants of one fixed order, so **the plants they share are the
first `min(n_a, n_b)`** — set intersection collapses to a minimum, per sub-cell, and a churn is
three sums over two dictionaries. Against the per-build random sequence this replaced, two builds
shared nothing whatever their counts said and no census could have told the difference. The
instrument did not exist before the fix did.

| what replays | what does not |
|---|---|
| which instances existed, and where | frame time — a headless frame is not drawn and costs nothing |
| how the population changed between frames | anything about colour, coverage or the seam's appearance |
| what a heading had in front of it | |

Frame times in the artefact are the **flight's** measurements carried through, never re-derived, and
every column says which it is. Read them to about half a millisecond: the frame timer on this
platform lands on a paced ladder.

### Two fractions, named apart, because reading one as the other has cost a prediction

- **`gone_fraction`** — what left, over what was there. `1 − survival`. This is what a disc-overlap
  argument predicts.
- **`churn_fraction`** — the symmetric difference over both populations summed. This is what
  `scatter_motion.json` reports, and roughly **twice** the first when the populations are similar.

### What the first flown path says

Three minutes, 16,184 frames, at the viewer's own 1280×800 with `k/k_res = 0.35`, re-centring every
25 m. Flown by the owner.

| | |
|---|---:|
| frames | 16,184 |
| measured speed, p50 | 5.04 m/s |
| rebuilds | 26 |
| `gone_fraction` per rebuild, p50 / max | **0.080** / 0.103 |
| instances in view, p50 | 27,283 of ~107,000 |
| in view by heading, lowest to highest mean | 25,746 → 28,860 (**1.12×**) |
| replay agreement | **exact over all 16,184 frames** |

**The replay agreement is the design's own claim, checked on a real flight rather than on a script.**
Every frame's population, recomputed from the poses alone on a headless machine, matched what the
flight recorded. One human session is now a fixture.

### The second flight: nothing was visible at a third of the stand replaced

Four minutes, 22,706 frames, fullscreen at 3024×1898, `--recentre 200`. Flown by the owner with the
instruction to mark only what looked wrong.

| | |
|---|---:|
| frames | 22,706 |
| rebuilds | 2 |
| `gone_fraction` per rebuild | **0.284** and **0.345** |
| stalls | 3.1 s of 240.0 s — **1.3%** |
| **marks** | **0** |
| replay agreement | exact over all 22,706 frames |

**A third of the stand was replaced, twice, and it was not reported.** That is a real upper bound
and the first evidence anyone has about where the threshold sits: at this stand, at 5 m/s, a
`gone_fraction` of 0.35 is below it. It is the number that was going to have to be ruled in the
abstract, and it is now measured instead.

Three things bound how far it can be pushed, and all three are the harness's fault rather than the
observer's:

- **Two events.** The path was 1,190 m long but only 360 m end to end — a wander, not a walk — so a
  200 m re-centre fired twice in four minutes. Two opportunities to notice is a thin sample.
- **The churn happens inside a freeze the flyer was told to ignore.** The rebuild blocks for 1.56 s
  and the stand changes during it, so the new arrangement arrives on the first frame after the
  window starts updating again. Having been told the freeze is a known harness artefact, "ignore the
  freeze" and "ignore the moment the churn is visible" are the same instruction. That is a defect in
  how the measurement was set up, and it is mine.
- **Fullscreen moved the level being tested.** At 1898 px of viewport height `k` is 433, so the
  discs are large and a 200 m step costs 0.28–0.35 rather than the 0.618 the same step costs at
  1280×800. The bound is at the level measured, not the level intended.

**So the ordering for backlog 198 is settled by these two flights together.** The stall is both the
dominant defect *and* a confound on measuring the other one: while a rebuild blocks the renderer for
1.5 s, no flight can say cleanly whether the churn inside it would have been seen. Fix the
synchronous build first; then a re-measure can push the churn level up until something is reported,
and that number will mean what it says.

### The third flight found a wall, and it was the scatter's

Flight 03 walked a straight line at `--recentre 400`, and the flyer reported: a well-defined point
where the vegetation ceased entirely, then a flat empty plane, then a rebuild that repopulated
everything. One mark, offered with *"I'm not sure how useful it is."*

It was the most useful mark of the three. Measured off the trace: **62.4 seconds of a 240-second
flight with nothing at all in front of the camera.**

The cause was in `VegetationScatter`. A texel was kept when its **centre** was inside the radius —
wrong by half a texel in every direction, since a texel centred 600 m away reaches to within 100 m of
the camera. At the 480 m radius every far-field harness here uses, **at most one texel centre can be
within the radius of any point**, so the scatter drew one 1 km texel and the ground past it was bare.
`texels: 1` was sitting in every report and read as a small disc rather than as a wall.

The disc is now tested against the texel's square, and the radius is a real cut at sub-cell
resolution. After the fix the same flight has a longest empty run of **0.8 s**.

**What the bug was hiding, beyond the wall.** Re-taking `scatter_motion.json` at the same place and
`k`:

| | before | after |
|---|---:|---:|
| worst re-centred churn | 1.0000 | 0.8537 |
| grass survival / ceiling | 0.260 / 0.760 | 0.378 / 0.852 |
| shrub survival / ceiling | 0.463 / 0.886 | 0.630 / 0.931 |
| tree survival / ceiling | 0.907 / 0.986 | 0.866 / 0.991 |
| succulent | **absent** | 1.000 / 0.977 |

**A whole family was missing from the metric.** Succulent lived in texels the old filter excluded, so
every motion number quoted here was over three families where there are four. Nothing in the artefact
said so — `placed` reported `"succulent": 0` and read as *"no succulent grows here"*, which was true
of the one texel being drawn and false of the ground.

### A correction: the heading spread was mostly this bug

| flight | re-centre | before the fix | after |
|---|---:|---:|---:|
| 01 | 25 m | 1.12× | 1.09× |
| 02 | 200 m | **9.32×** | **3.24×** |
| 03 | 400 m | — | 2.27× |

This file previously said flight 02's 9.32× spread was *"the lazy re-centring, not the far field"* —
the camera wandering up to 200 m off the centre of a 480 m disc. That was about a third right. Two
thirds of it was the texel wall: heading into the missing ground showed almost nothing, and heading
back into the drawn texel showed a stand. The residual 3.24× is the lazy re-centring, and flight 01's
1.09× is still the control for what heading alone is worth.

The general lesson is the one this file keeps re-learning: **a ratio between two numbers is only a
finding once you know both numbers are of the same thing.**

### Artefacts re-taken, and the ones still owed

`scatter_cost.json` and `scatter_motion.json` are re-taken at the fix. The cost artefact barely moved
— 119,994 → 119,963 instances, marginal 2.853 → 2.83 ms — because the build ceiling binds either way
and the extra texels are thinned into the same budget.

**`scatter_seam.json` and `scatter_horizon.json` were re-taken too, and the result is not what the
staleness flag predicted.**

`scatter_horizon.json` barely moved: every frame time at every `k` came back within 1 ms, so decision
949's evidence stands unchanged — three of the five densest cells over 33.3 ms at `k/k_res = 0.35`,
and one cell with no `k` that is both above the placement-raster floor and inside budget. The texel
defect's blast radius was the **small-radius** harnesses. Both of these build at 1,500 m, where
reach is 2 and the centre test already caught nearly every contributing texel; the wall only appears
when the radius is under a texel, which is the 480 m the motion and flight harnesses use. That is
also why it survived so long: every artefact anyone checked carefully was built at a big radius.

`scatter_seam.json` moved a great deal, but for an unrelated reason the re-take exposed — see the
withdrawn sufficiency verdict below.

### The finding from the first flight, which is not the one this harness was built to look for

**Every one of the flight's 16 marks was within two seconds of the harness blocking its own main
loop.** The flyer pressed SPACE not because the far field looked wrong but because the view froze
every few seconds while the camera kept moving — and reported it as such.

| | |
|---|---:|
| stalls | 26 |
| each | 1,606–1,840 ms (p50 **1,766 ms**) |
| total | 45.6 s of 180.9 s flown — **25.2%** |
| marks within 4 s of a stall | **16 of 16** |

The stalls are the scatter rebuilds. At 5 m/s a 25 m re-centre comes round every five seconds, and a
build of ~107,000 instances takes **1.75 s of blocked main loop** on this machine. So a quarter of
the flight was spent inside a rebuild, and what a person experiences is a freeze followed by the
camera having jumped several metres.

**This is a bigger objection to backlog 198 than churn is.** The churn at those same rebuilds is
0.080 — a twelfth of the stand, at the rim, which is what the placement fix bought. Nobody marked
it. What is unlivable is the 1.75 s stop, and no crossfade schedule addresses a stopped renderer.
The inversion needs the build to stop being synchronous — incremental over frames, or off the main
thread with only the MultiMesh upload on it — before a per-place budget is flyable at all. That is
`VegetationScatter`'s to solve and it is not solved here.

**Build cost is not frame cost and the two are now both measured.** `scatter_cost.json` prices
*drawing* the scatter: 2.85 ms marginal. This prices *building* it: 1,754 ms mean, about 73,000
instances per second. They are different quantities about the same instances and only one of them
was ever measured before.

**Part of that was mine and is now returned.** The per-instance digest added with the placement fix
was recomputing loop invariants inside the instance loop — the family key as an FNV walk over a
string, the texel a sub-cell sits in, and a `str()` per ring — about 107,000 times a build. Hoisting
them took the build from 1,670 ms to 1,470 ms; the digest now costs ~65 ms rather than ~270 ms.
Inlining the mixer would have bought another 11% and was **not** taken: it makes the one function in
this file whose values are pinned unreadable, and a 1.3 s stall is not meaningfully better than a
1.5 s one. The fix for a stall is not to shave it.

### And the instrumentation that hid it, which is worth recording

The flight recorded everything needed to see this and reported none of it. Two defects, both now
fixed:

- **`frame_ms` is measured at the top of the frame**, so a rebuild below that line lands in the
  *next* frame's reading. The trace came back with 26 stalls of 1.8 s and 26 rebuilds and **not one
  of them on the same row**. `build_ms` was on the right row all along; nothing read it as blocked
  time.
- **The mark analysis quoted the churn and the population at each mark**, which for these sixteen
  marks reads: churn 0.0000, a normal population, an unremarkable frame. Sixteen rows saying nothing
  is what an instrument looks like when it is answering a different question from the one being
  asked of it. A replay that reports marks must now also report what they were near, and the gate
  requires it.

The flight harness now says `[REBUILT: the freeze you just saw was this, 1766 ms]` on screen, because
a person cannot mark what they cannot name.

### Choosing what to fly: what each `--recentre` is worth in churn

A flight at one re-centre distance produces one churn level, so a flight that marks nothing bounds
the threshold at that level and nowhere else. Measured headlessly at place B, day 22,
`k/k_res = 0.35`, `gone_fraction` per rebuild. **Read the column for the window actually being
flown** — flight 02 was flown fullscreen and landed at 0.28–0.35 rather than the 0.618 its
re-centre distance is worth at 1280×800:

| re-centre | at 1280×800 | at 1600 px tall | at 1898 px tall (flight 02's window) |
|---:|---:|---:|---:|
| 25 m | 0.077 | 0.047 | |
| 50 m | 0.166 | 0.090 | |
| 100 m | 0.338 | 0.175 | |
| 200 m | 0.618 | 0.344 | 0.293 |
| 300 m | | | 0.434 |
| 400 m | 0.859 | 0.648 | 0.561 |
| 600 m | | | **1.000** |

The 1898 px column predicts flight 02's two measured events — 0.284 and 0.345 against 0.293 — which
is the ladder checking itself against a flight rather than only against arithmetic. **It also runs
out at 600 m**: past that the two discs no longer overlap at all and every plant is a new one, so
there is no larger churn to test than a complete replacement.

### Path shape decides how many events a flight gets, and at the top of the ladder it decides whether it gets any

Rebuilds fire on distance from the *last build centre*, so what matters is net displacement, not path
length. Flight 02 walked 1,190 m of path but only 360 m end to end — a wander — and got two events.
The same four minutes walked in a straight line is 1,200 m of net displacement:

| re-centre | events on flight 02's wandering path | events walked straight |
|---:|---:|---:|
| 200 m | 2 *(observed)* | 6 |
| 400 m | **0** | 3 |
| 600 m | **0** | 2 |

At the bottom of the ladder a wander costs a third of the sample. At 400 m and above it costs the
whole flight: a path that never gets 400 m from where it started never rebuilds, and four minutes
produce no measurement at all. So the straight line stops being a refinement and becomes the
difference between a flight and an afternoon.

**A bigger window halves the churn at the same re-centre distance**, and that is not an artefact of
the measurement — `k_res` is a function of viewport height, so doubling the height doubles every
family's individuation reach, and two discs twice as large overlap far more after the same step.
Flying fullscreen is therefore not neutral: it is a different point on this table as well as a
better look at the far field.

**Bigger steps also cost less stall.** A rebuild blocks for ~1.75 s whatever the step, so re-centring
every 200 m over a 1,200 m walk is six freezes rather than forty-eight, and the flight is about the
far field rather than about the harness.

The way to use the table is from the top: if the largest churn is not visible, everything below it
is not either, and the bound is established in one flight instead of five.

### The scripted path, which is the fixture rather than the measurement

A 30 s walk with a slow pan, same place and `k`, re-centring every 25 m: 1,800 frames, 5 rebuilds,
`gone_fraction` p50 0.088 / max 0.097, in view by heading 24,242 → 28,732 (1.19×). It carries **no
marks** — a script cannot judge — and it exists so the replay and the gate have a path to score with
nobody at the machine.

**A quantile over every frame would have been a lie of arithmetic.** Only a rebuild can change the
population, so 1,795 of those 1,800 frames are zero by construction; a p95 over all of them reads
0.0000 and says nothing. The churn distribution is quoted over the frames that could churn, with
the count of them beside it.

**The 1.19× is the pan finding, and it is the statistic a pan has to be measured by.** A pan cannot
churn — the scatter is built around a centre and a rotation does not move it, so churn is exactly
0.0000 for any pan, always. That is a metric that cannot fail on what it is pointed at. What *does*
vary with heading is what is in front of the camera, and here it varies by a fifth between the
emptiest heading and the fullest, which a translation-only dolly never sampled. The ratio is only
meaningful across frames at a comparable attitude, so the artefact carries the pitch quantiles and a
count of frames with nothing in view beside it.

### What this does not answer, and it is the reason the harness exists

**The threshold is now bounded from one side and not from the other.** Flight 02 puts it above
0.345: a third of the stand was replaced twice and nothing was reported. Nothing yet puts a ceiling
on it, because no flight has produced a mark that was about the far field — flight 01's sixteen were
all about the harness stalling.

A count of marks is not evidence. A count of marks *that were about what the harness was pointed at*
is, and that count is still zero across two flights and 38,890 frames. What the pair does establish
is that the mechanism works in both directions: it caught a defect nobody had predicted when there
was one to catch, and it reported nothing when there was nothing the flyer could see.

### Whether this replaces the scripted dolly: no, and they are not substitutes

Asked, and answered here rather than assumed:

- The dolly scores **pictures** — annulus colour, coverage, luminance distance — against an oracle,
  and needs a renderer. The replay scores **populations** and cannot say anything about how a frame
  looks. They do not overlap.
- The dolly compares three candidates **at identical camera positions**, which is the only
  comparison in either harness with no camera motion in it. A flight has one candidate.
- The dolly runs today with nobody present. A flight's trace is reproducible only after somebody
  has flown it once.
- What the flight adds and the dolly cannot: **per-frame sampling** — at 5 m/s the dolly's 20 m step
  is four seconds of travel, and everything between two samples is invisible to it — **pan**, and
  **the mark**.

So the gate keeps the dolly and the tuning uses the flight.

### The refusal that matters most here

An interactive window loses focus by construction: it is what happens every time a person looks at
something else, and a window that is not focused stops being drawn while the loop keeps ticking. It
already cost two complete `measure_motion` runs. So the flight harness counts frames recorded while
unfocused and **refuses to write a trace at all** if more than a tenth of it was not on screen — the
path would replay perfectly and the judgement it carries, which is the entire reason a person is
there, would be about frames nobody saw. Recording does not begin until the window has been clicked,
so setup is not counted against the flyer.

### Not covered

One path, one place, one day, one `k`, one walking speed. **The near field has no ground until the
tile pyramid lands** — the terrain is triangulated every 4 km on the overview, so at eye level the
surface under the plants is an interpolated plane and not a hillside. Eye-level judgement is limited
by that and nothing here generalises past it.

## `scatter_bands.json` — where individuals should stop

Beyond a few hundred metres an individual plant is a fraction of a pixel and there are tens of
millions of it, so the far field has to become some collective representation. Where that starts,
and whether the two ends can be faded into each other rather than cut, is a design question. These
are the measurements it needs: for a set of density schedules, what each costs a frame, how long it
takes to build, and how much of the screen the vegetation still covers.

`deepest_winter`, day 22, standing at EPSG:5070 `(-1310793, 1616226)`, **eye level inside the
scatter** — 1.7 m real, pitched 10° down, looking north — on Apple M5 / `gl_compatibility` at
1280 × 800, vsync off. The marginal is against the same scene with the scatter hidden (p50
1.56 ms).

| schedule | instances | build | marginal | coverage | px per 1,000 instances |
|---|---:|---:|---:|---:|---:|
| today: uniform over 1,500 m, 120 k ceiling | 119,994 | 1.5 s | 2.35 ms | 4,968 px (0.5%) | 41 |
| cut at 100 m | 186,208 | 1.8 s | 4.83 ms | 595,240 px (58.1%) | 3,196 |
| cut at 200 m | 721,556 | 7.0 s | 18.47 ms | 447,144 px (43.7%) | 620 |
| cut at 300 m | 1,500,088 † | 14.7 s | 38.35 ms | 600,990 px (58.7%) | 401 |
| fade 1 / .75 / .5 / .25 to 300 m | 750,500 | 7.5 s | 19.60 ms | 531,535 px (51.9%) | 708 |
| fade 1 / .5 / .15 / .05 to 1,500 m | 1,498,616 † | 15.0 s | 37.10 ms | 280,378 px (27.4%) | 187 |

† ceiling-bound rather than schedule-bound: measurements of the cap, not of the schedule.

**Re-taken at 1:1**, which is the only scale this project draws at now, from an eye placed on the
*drawn* surface. Both of those changed since the rows this table replaces: the earlier ones were
taken at 12×, where plants are 12:1 spikes, from a camera that was underground.

### Coverage here is a lower bound, and that is why it is not monotonic

Going from a 100 m cut to a 200 m cut adds 535,348 instances and **removes** 148,096 covered
pixels. Reproducible to the digit across runs, so it is not noise.

The picture explains it: `shots/bands/cut_at_200_m.png` is a dense stand of succulent trunks, and
the ones in shadow are **darker than `FrameProbe.BLACK_CEILING`**, so they are counted as near-black
rather than as coloured. Adding plants adds mutual shadowing, and shadowed plants leave the count.

So **"coverage" in this file is the share of the frame carrying a plant bright enough to see, not
the share carrying a plant**, and it undercounts by more as density rises. `scatter_seam.json`
measures the same quantity against an explicit ground denominator in a range annulus, with oracle
and candidate measured identically at the same density — its *ranking* is unaffected by this and
its absolute coverage is a lower bound in the same way. Neither file supports a claim about how
coverage varies with density, and the earlier version of this section made one; it is withdrawn.

The cost column is untouched by any of this. Instances cost what they cost.

### Build time, not frame time, is what stops this being dynamic

GDScript fills MultiMeshes at about **128,000 instances per second** here: 0.94 s for 120 k, 3.4 s
for 441 k, 7.9 s for 1.0 M, 11.6 s for 1.5 M — linear, and slower than the frame it feeds by three
orders of magnitude. **Nothing above about 30,000 instances can be rebuilt inside a frame**, so a
scheme that re-scatters as the camera moves is not available at these counts without moving the
build off GDScript or keeping bands resident and only swapping visibility.

### The resolution wall, which is the real constraint on band distances

| | |
|---|---:|
| heightfield texel | **1,000 m** |
| terrain mesh triangle (`stride` 4) | **4,000 m** |
| cell (one set of wire values) | ~126 km² |

A 1,500 m horizon is **nine texels**, sitting inside one or two cells. Three consequences:

- **A band boundary under a kilometre has no grid to hang on.** The first run of this measurement
  reported byte-identical instance counts for cuts at 100 m, 200 m and 300 m, because each kept
  exactly the centre texel. Schedules now subdivide the texel they thin, at 32 per side — a 31 m
  grid — and `test_a_density_schedule_is_finer_than_the_texel_it_thins` holds it there.
- **The density variation inside a band is invented.** Height, crown and phenology all come from
  the *cell*, so every plant within a kilometre is the same plant and only its position differs.
  A fade varies density at a resolution the wire does not have. That is defensible for a drawing
  decision and it must not leak into anything reported as data — which is why `implied` stays the
  unthinned implication and `implied_after_bands` is a separate number.
- **The near field has no ground.** At 4 km per terrain triangle, a viewer standing in the scatter
  is in the middle of one flat triangle. Near-field vegetation would stand on a plane. Tuning a
  200 m boundary by eye is not really possible until the tile pyramid lands.
  **Measured since, and the pyramid has landed**: the drawn mesh has a median of **0** vertices
  inside the 480 m disc a standing body sees, against **69** ground samples at the pyramid's
  100 m, and a plant placed on the drawn plane stands a median **42.5 m** — worst 427 m — from the
  ground the data actually has. See `ground_relief.json`. What the pyramid does **not** fix is
  below.

### One plant on screen

At 1×, where naturalistic view now draws, real height and drawn height are the same number.

| family | real = drawn at 1× | 100 m | 200 m | 300 m | 500 m | 1,000 m | 1,500 m |
|---|---:|---:|---:|---:|---:|---:|---:|
| shrub | 0.51 m | 2.7 px | 1.3 px | **0.9 px** | 0.5 px | 0.3 px | 0.2 px |
| succulent | 0.94 m | 4.9 px | 2.5 px | 1.6 px | **1.0 px** | 0.5 px | 0.3 px |
| tree | 4.37 m | 22.8 px | 11.4 px | 7.6 px | 4.6 px | 2.3 px | 1.5 px |

**A shrub goes sub-pixel past about 300 m, a succulent past about 500 m, a tree past about
2,300 m** — 1280 × 800 at 75° FOV. The families do not fade together, so a single global seam
distance is the wrong shape and per-family distances fall straight out of this table. (Those
figures supersede the ~85 m and ~780 m carried into the seam brief's addendum: those divided the
12× numbers by twelve, but the 12× numbers predate the cover correction that made every family
roughly twice as tall.)

### What a far-field texture would have to match

If the far bands become a shaded surface, these are the targets it has to hit at the seam — the
mean colour of the plants themselves, measured with everything else hidden:

| schedule | mean colour of the vegetation | green − red |
|---|---|---:|
| cut at 100 m | (0.171, 0.340, 0.128) | +0.170 |
| cut at 200 m | (0.110, 0.250, 0.081) | +0.141 |
| cut at 300 m | (0.096, 0.230, 0.070) | +0.134 |
| fade to 300 m | (0.085, 0.210, 0.061) | +0.125 |

They fall with distance because more of what is drawn is far, small and in shadow. A texture that
reproduced the near colour everywhere would be visibly brighter than the stand it replaces, so the
target is a function of range and not a constant. Coverage is the other half of the target: a
texture standing in for the band from 200 m to 300 m has to read as the difference between those
two rows, which is 158,762 pixels of a 1,024,000-pixel frame.

### A trap worth writing down

The eye-level camera rendered **completely empty frames** at every height tried, which looks exactly
like a scatter that failed to build. The cause was the projection: `near` pulled to 0.1 against the
rig's basin-scale `far` of 5,888,000 is a ratio of 6 × 10⁷, and the compatibility renderer draws
nothing at all through it. Anything that puts a camera on the ground in this scene has to bring the
far plane down with it.

### What it does not cover

One machine, one place, one day, one camera, one FOV. Density is a property of the place — see
`scatter_cost.json` — so the instance counts here do not transfer to another part of the basin;
the *ratios* between schedules should. No far-field representation exists yet, so nothing here
measures a seam: it measures what a seam would have to match.


## `scatter_seam.json` — grading the far field against the stand it replaces

Beyond a few hundred metres the far field has to become a collective representation. Candidate #1
is the cheapest one: a **per-cell vegetation tint** on the terrain — mean colour and coverage from
the same two wire rows the scatter samples, no new geometry. Whether that is sufficient is not
arguable, and this is the arithmetic that decides.

`bash tools/measure_seam.sh` renders four candidates at a pinned place, day and camera — an
**oracle** of instances at full density out to 2.5× the seam, the **null** baseline that ships
today, a **constant** tint, and a **range-matched** tint whose attenuation is fitted to the
oracle's own binned brightness — and scores each in an annulus at 0.7–1.5× the seam.

### The scale is 1:1, and that is what these runs are of

Vertical exaggeration is out of this project's geometry: terrain, plants and the distances between
them are true scale in every view. It was 12×, then briefly per view, and both were superseded —
**this harness is what removed it.** At 12× the oracle is not a stand: the factor was applied to
plant *height* and not to the horizontal distance to a plant, so every plant is a 12:1 spike and
1.65 M of them seen from inside render as a radial starburst. The numbers looked fine; the picture
did not, and it is at `shots/seam/` in the runs that produced it.

At 1:1 `cover = count × crown area` — the identity every metric here is derived through — holds by
construction, and no tuned distance carries a factor it is conditional on.

**The cost is paid in the shading, not in the space.** Relief is what the 12× was for, and true
normals over 4 km of relief across 1,000 km of basin hillshade to almost nothing. So the gradient
is steepened where the *light* reads it and nowhere else — `TerrainMesh.shading_exaggeration`, a
lighting parameter that moves no vertex. Tuned against what the old geometry produced rather than
by eye, over the bare terrain at the overview camera:

| shading | brightness levels | spread |
|---:|---:|---:|
| 1× (true normals) | **13** | **0.016** |
| 6× | 50 | 0.098 |
| **12×** | **74** | **0.188** |
| 18× | 90 | 0.266 |

against **68 levels and 0.188** for the old 12× *geometry*. The first row is the cost the decision
was accepting, measured. And from the ortho map camera the whole change is **byte-identical** to
the 12× render — an orthographic top-down projection does not project Y at all, so only the normals
reach the frame, and those are unchanged. `test_the_shading_is_exaggerated_and_the_geometry_is_not`
holds the two apart: vertices within 0.006 m of the field they are sampled from, normals turning up
to 52° away from the ones those heights would give.

### The result, corrected: the tint is NOT sufficient, and the evidence that it was is withdrawn

**This section previously said the tint was sufficient on both conserved quantities, with margins of
6.6× to 53× over the null baseline. That was wrong, and it was wrong because the harness was scoring
the oracle and calling it the tint.**

`measure_seam`'s isolation hid the terrain and the flowlines and never the instances. A tint
candidate still *builds* a scatter — it needs one to bind the day — so the tint's **isolated** frame
was the tint with the plants drawn on top of it. In the near field the plants leave gaps and the tint
showed through, which is why the numbers looked plausible rather than absurd.

It surfaced during a routine re-take, when the gate refused an exactly-zero colour error: three
candidates were reporting one mean colour to six decimals and identical luminance histograms across
six bins. Once mid-field coverage reached 1.0, the plants covered the tint completely and the tint's
frame *became* the oracle's frame. The refusal that caught it was written after the last time two
things that must differ came out the same.

Scored with the tint alone, seam 120 m, annulus ≈80–180 m, eye level:

| window | day | place | tint ΔE **as published** | tint ΔE **isolated** | null ΔE | margin |
|---|---:|---|---:|---:|---:|---:|
| deepest_winter | 22 | A | 0.0223 | **0.1150** | 0.1365 | 1.19× |
| deepest_winter | 85 | A | 0.0224 | **0.1150** | 0.1363 | 1.18× |
| largest_fire | 0 | A | 0.0140 | **0.0907** | 0.1630 | 1.80× |
| deepest_winter | 22 | B | 0.0030 | **0.1617** | 0.1305 | **0.81× — it loses** |

**At place B the tint is worse than drawing nothing.** At place A it beats the null by a fifth, not
by six-fold. The brief chose the cheapest candidate first on the argument that *"the harness gets to
say no cheaply"*. It is saying no.

### And the coverage half fails for a reason worth keeping

| window | day | place | oracle cover | tint cover | null cover |
|---|---:|---|---:|---:|---:|
| deepest_winter | 22 | A | 1.000 | 0.195 | 0.077 |
| deepest_winter | 85 | A | 1.000 | 0.195 | 0.077 |
| largest_fire | 0 | A | 1.000 | 0.101 | 0.060 |
| deepest_winter | 22 | B | 1.000 | 0.747 | 0.210 |

The oracle covers the whole annulus. The tint covers a fifth of it at place A — and that is the tint
doing exactly what the brief asked for, which is the finding.

**Ground cover and screen cover are not the same quantity, and the seam is where they come apart.**
The tint reproduces the wire's cover fraction: the share of *ground area* a life form occupies. At
80–180 m the stand's plants overlap in *screen space*, so a fifth of the ground covers all of the
pixels. A tint painted to the conserved quantity will therefore always under-cover the stand it
replaces, and the shortfall grows with range because the overlap does.

So the requirement in the brief — *"the requirement is the measured coverage fraction, not the
mask"* — is under-specified, and this is the measurement that says which fraction. A far-field
candidate has to hit the **screen** coverage at range, which is a function of ground cover, crown
size and distance, not the ground cover alone. Whether that is a different mask or a different
candidate is not decided here.

### The range dependence is geography, not optics

The brief asked for a fitted range darkening, from four schedule rows that showed apparent stand
colour falling from (0.171, 0.340, 0.128) to (0.085, 0.210, 0.061). **Binned by range rather than
by cumulative cut, there is no darkening to fit**: the fit returns `k0 = 1.000` in all five runs,
and the oracle's brightness actually *rises* slightly with range (0.285 → 0.327).

What does change with range is **hue** — green-minus-red goes +0.061 near to +0.201 far — and the
tint reproduces that with **no range term at all**, because the cells at different ranges genuinely
carry different composition. The earlier figures were an artefact of measuring cumulative cuts:
a 300 m cut contains its own 100 m core, so the difference between the rows was mixture, not
attenuation.

So `range_matched` and `constant` are the same candidate here, with identical uniforms and
identical frames. The two tying is arithmetic, not a metric that cannot separate them — the metric
still puts 0.02 to 0.07 between the tint and the null baseline, which is what the gate now holds:
that the instrument can tell two visibly different frames apart, not that either of them wins.

### The horizon rule: one constant, and where size stops doing the rest

The instancing horizon is derived rather than tuned — `d_f = k × height_f`, one shared individuation
constant for every family — so four distances become one knob. `bash tools/measure_seam.sh --sweep-k`
rebuilds per `k` and records what that `k` meant in metres per family. The rule is **off in the
shipped viewer** (`k = 0`); it exists to be swept.

**`k` is bounded above by the camera, and that bound is exact.** The range at which an object falls
below one pixel is `k_res × height` with `k_res = H / (2·tan(fov/2))` — a pinhole identity, a
property of the rig and not of vegetation. At 1280 × 800 and 75° it is **521.3**, and
`scatter_bands.json`'s own pixel table gives **521 for shrub, succulent and tree alike**. So the
premise "individuation range is proportional to size" is not an approximation to be measured; it is
geometry. What is left to measure is how far *below* resolution individuation actually stops, which
is why the sweep runs at fractions of `k_res` and quotes them that way — a bare `k` is conditional
on a viewport and a field of view.

`deepest_winter`, day 22, at EPSG:5070 `(-1310793, 1616226)`, seam 120 m:

| k/k_res | k | shrub | succulent | tree | instances | ×prev | k² predicts | frame p50 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.05 | 26 | 13 m | 24 m | 113 m | 22,588 | | | 2.08 ms |
| 0.10 | 52 | 27 m | 49 m | 226 m | 26,956 | 1.19 | 4.00 | 1.39 ms |
| 0.20 | 104 | 53 m | 97 m | 453 m | 193,072 | 7.16 | 4.00 | 5.56 ms |
| **0.35** | **183** | **93 m** | **170 m** | **792 m** | **535,126** | **2.77** | **3.06** | **14.29 ms** |
| 0.50 | 261 | 133 m | 243 m | 1,131 m | 1,155,030 | 2.16 | 2.04 | 29.63 ms |
| 0.75 | 391 | 199 m | 364 m | 1,697 m | 1,875,526 | 1.62 | 2.25 | 46.97 ms |
| 1.00 | 521 | 265 m | 485 m | 2,263 m | 1,874,296 | 1.00 | 1.78 | 46.30 ms |

**The k² law holds in the middle and is bounded at both ends by things that are not the rule.**
0.2 → 0.35 → 0.5 track the prediction (2.77 vs 3.06, 2.16 vs 2.04). Below that, the horizon falls
under the **31.25 m sub-cell** the cut is evaluated on — the resolution wall one level down from the
1 km texel — and families are dropped rather than thinned; the report names them
(`horizon.<family>.below_the_grid`) rather than letting a count read as a measurement. Above it, the
tree horizon passes the **1,500 m scan radius** and the outer loop binds instead of the rule. So the
usable sweep range here is roughly **k/k_res ∈ [0.2, 0.6]**, and that is a property of this raster
and this radius, not of the rule.

**Trees carry about 8.5× further than shrubs**, which is the brief's "roughly an order of
magnitude", arriving by arithmetic rather than by tuning.

### Per-family annulus scoring, and the reference's own depth

Each family is now scored in **its own annulus** — `[0.7, 1.5] × d_f`, around its own horizon — with
only that family's instances drawn, against the oracle rendered the same way. `bash
tools/measure_seam.sh --sweep-k` emits one row per (family, k). The polarity that matters:
`test_a_family_is_scored_in_its_own_annulus_or_not_at_all` fails if a row's annulus is not
`[0.7, 1.5]` times that row's own horizon, because a table of numbers all measured in one family's
band would read as a per-family result and be nothing of the kind.

**Most rows are refused, and that is the finding.** 23 of 42 at the two pinned places. Per-family
horizons span **16 m to 8.5 km**; the oracle is cut at `2.5 × seam` = 300 m and the scatter draws
nothing past its 1,500 m radius. An annulus beyond the shallower of those contains no instances at
all — not the candidate's, not the oracle's — and a score there measures **near vegetation painted
over far ground**, because the mask marks a pixel by the range of the terrain *behind* it. It comes
back as coverage near 1.0 and a tiny colour error, which reads as agreement and is two empty annuli
agreeing. Refused with the reason rather than scored.

**Deepening the oracle does not fix it, and the harness now says so.** At a 700 m cut the oracle
drew **51.6% of its own stand** — the build ceiling sampled it — and a sampled oracle is not a
reference: every candidate is flattered by exactly the sampling. The distortion was immediate and
measurable, shrub's colour error going from 0.002–0.009 against the valid 300 m oracle to
**0.030–0.053** against the sampled one, while its apparent coverage advantage grew. `--oracle-cut`
exists so the depth can be raised, and `reference_is_a_sample` is recorded **at the run level**,
because a thinned oracle invalidates every row and not only the oracle's own.

**What the 19 measurable rows say**, `deepest_winter` day 22, both places, coverage quoted as the
candidate's over the oracle's in the same annulus:

| k/k_res | succulent (A) | shrub (A) | grass (B) | shrub (B) |
|---:|---|---|---|---|
| 0.05 | ΔE 0.005, 1.00 | ΔE 0.005, 0.93 | ΔE 0.002, 0.96 | ΔE 0.009, 1.04 |
| 0.10 | ΔE 0.001, 0.95 | ΔE 0.006, 1.06 | ΔE 0.001, 0.91 | ΔE 0.006, 1.00 |
| 0.20 | ΔE 0.000, 1.00 | ΔE 0.003, 0.82 | ΔE 0.004, 0.67 | ΔE 0.002, 1.00 |
| **0.35** | **ΔE 0.001, 1.00** | **ΔE 0.004, 0.88** | **ΔE 0.000, 0.94** | — |
| 0.50 | — | ΔE 0.002, 0.78 | ΔE 0.003, 0.96 | — |

**Read the coverage column as a shortfall the tint has to fill, not as an error.** The annulus
straddles the horizon by design: the candidate draws instances in `[0.7, 1.0] × d_f` and *nothing*
in `[1.0, 1.5]`, which is exactly the range the tint exists to cover. An instances-only candidate is
therefore expected to under-cover its own annulus, and does — except where coverage saturates,
which is why the dense succulent reads 1.00 throughout and says less than it appears to.

### The per-family oracle, and the two things that had to be true first

One cut cannot serve horizons spanning two orders of magnitude, so each family now has **its own
reference, cut to its own deepest annulus** and built with `only` set so a three-kilometre tree
reference does not pay for grass at three kilometres. **55 of 84 rows measurable, against 19 of 42
before** — and trees and succulents have rows at all for the first time.

| | grass | shrub | succulent | tree |
|---|---:|---:|---:|---:|
| own reach, place B | 494 m | 1,040 m | — | **8,498 m** |
| own reach, place A | — | 398 m | *refused* | 3,394 m |

**A reference must not be budgeted like a frame.** Every per-family oracle was refused on the first
attempt: the scatter thins to fit 33.3 ms, so each drew 80–95% of its own stand and became a
*sample*, which is the one thing a reference may not be. An oracle is photographed once and never
played, so these builds now run with the frame budget deliberately not applied — the build ceiling
still binds, and at place A the succulent's own oracle hit it at 72.4% and was **refused**, falling
back to the shared reach rather than pretending. That family is dense enough that no deep reference
for it is affordable, and the artefact says so.

**A reference must be placed the way the candidate is placed.** With no schedule and no `k` the
scatter takes its *unsubdivided* path — one placement per kilometre texel — while every candidate
subdivides, because `k > 0` forces it. Two arrangements of the same count differ enormously inside an
annulus tens of metres wide.

**And the frame has to hold the family the name says.** This is the one that was caught by opening
the PNG and by nothing else. A MultiMesh node keeps its previous mesh when a build does not mention
its family; the harness showed every `Vegetation_*` node before photographing, which **resurrected
the last build's instances**. `oracle_grass` came back as a frame full of trees and shrubs with grass
as a fringe along the bottom, and produced a complete, plausible table — every score finite, every
row in the right annulus, ΔE rising smoothly with `k`. The tell was in the numbers and was missed:
three *different* family references reporting the same mean colour to three decimals. That is now the
assert, beside the cheaper structural one.

**What the corrected rows say.** Every family matches its own reference on colour at every `k` —
**ΔE ≤ 0.019 across all 55 rows** — so the instance representation's colour is right regardless of
the horizon, which is what one would expect of instances. `k` shows in **coverage**, as the fraction
of the annulus the candidate fills against the oracle:

| k/k_res | grass (B) | shrub (B) | tree (B) | succulent (A) | shrub (A) |
|---:|---:|---:|---:|---:|---:|
| 0.05 | 1.04 | 1.05 | 0.98 | 1.00 | 1.00 |
| 0.10 | 0.93 | 1.01 | 1.00 | 0.95 | 0.98 |
| 0.20 | 0.67 | 1.00 | 1.00 | 1.00 | 0.79 |
| **0.35** | **0.94** | **1.00** | **1.00** | **1.00** | **0.88** |
| 0.50 | 0.96 | 1.00 | 1.00 | — | 0.78 |

Shrub, tree and succulent reach parity by **0.2**; grass by **0.35–0.5**, with the 0.67 dip at 0.2
being the sub-cell quantisation zone already documented above. The read is unchanged in direction and
now rests on each family's own reference rather than on one shallow shared one.

### `scatter_horizon.json` — `k` at the hard cells, and what the ruled value costs there

Decision 949 rules `k/k_res = 0.35` `[PROVISIONAL]` with a named revisit trigger. §23.909 locates the
two places priced above at the **81st percentile** of the count law's own weight and predicts the p99
cell at 2.05× and the densest at 2.35×. This is that test: the five densest cells swept at their own
EPSG:5070 centroids, `deepest_winter` day 22.

**Frame p50, against the 33.3 ms budget. Three of five are over at the ruled value.**

| HUC10 | weight | 0.05 | 0.1 | 0.2 | **0.35** | 0.5 | 0.75 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1502001703 | 69.7 | 0.9 | 1.9 | 5.5 | **14.6** | 28.3 | 47.6 ✗ |
| 1502000807 | 67.8 | 2.7 | 7.1 | 23.3 | **49.2 ✗** | 49.1 ✗ | 47.2 ✗ |
| 1502001607 | 67.3 | 18.3 | 41.7 ✗ | 37.9 ✗ | **36.4 ✗** | 38.3 ✗ | 42.3 ✗ |
| 1502001608 | 67.0 | 1.8 | 4.2 | 13.9 | **35.7 ✗** | 48.6 ✗ | 47.2 ✗ |
| 1505030306 | 66.5 | 1.7 | 1.8 | 4.2 | **11.9** | 22.9 | 47.0 ✗ |

**The weight ordering is very nearly the reverse of the cost ordering.** The heaviest cell is the
*cheapest* — 14.6 ms — and the fifth-heaviest is the second cheapest. Ordering by weight was offered
as the robust half of §23.909 and against measured frame cost it does not hold.

**What does predict the cost is realised plant HEIGHT, and it predicts it exactly.** Succulent drawn
height across the five: 0.98, 3.34, 8.95, 2.58, 0.90 m; cost at 0.35: 14.6, 49.2, 36.4, 35.7,
11.9 ms — the same rank order, no exceptions. The mechanism is in the rule itself: `d_f = k × h`, so
the drawn area goes as `h²` and the count with it. Height enters **squared**, cover enters linearly,
and a cell with 9 m succulents against 1 m succulents carries ~80× the count from that term alone.
A weight built from cover and a declared aspect factor cannot see it, because realised height comes
from biomass per covered area and is not in the formula.

**And no `k` satisfies both bounds at 1502001607.** It is over budget at every value from 0.1 up, and
0.05 is far below the 0.35 placement-raster floor. The window is empty there. That is not a tuning
problem; it is the shape of a fixed global constant meeting a basin with two orders of magnitude of
plant height in it.

### The budgeter is already engaged at these cells, and it is calibrated on a floor

This is the finding that outranks the sweep. `VegetationScatter._affordable` divides the frame budget
by `render_cost.json`'s per-instance coefficient — **the empty-stage floor**, which
`scatter_cost.json` measures a real frame sitting **1.33× above**. So a scatter thinned to "fit
33.3 ms" lands near 44 ms, and the thinning is not hypothetical:

| cell, k = 0.35 | share drawn | bound by | frame p50 |
|---|---:|---|---:|
| 1502001607 | **6.8%** | the frame budget | **36.4 ms** |
| 1502000807 | 80.8% | the frame budget | **49.2 ms** |
| 1502001608 | 100% | *nothing: the whole implied scatter is drawn* | **35.7 ms** |

The first two thinned themselves *on purpose, to fit the budget*, and missed it. The third believed
it fitted and did not. **A scatter cannot budget itself with a coefficient that under-predicts the
frame it is budgeting for**, and no choice of `k` repairs that — at best it moves which cells the
error is visible in.

**The correction is now applied.** It was held disclosure-only while §19.8.9 owned the coefficient;
**decision 951** answers it — a budget solve divides by floor × measured multiplier — so the solve
spends `budget_ms / 1.33` and the report carries `budget_ms_effective` beside the nominal figure.
`test_the_budget_solve_divides_by_the_floors_measured_multiplier` pins both solve sites and keeps the
quoted multiplier tracking `scatter_cost.json`, currently 1.334× measured against 1.33 quoted.

**The three rows above were measured before that landed**, and they are left as they were rather than
re-labelled: they are the evidence the ruling was made on. What applying it does to them is
arithmetic — where the frame budget was the binding constraint, the affordable head divides by 1.33
and so does the share. What it does not do is fix them, which is the caveat the ruling carries in its
own arithmetic: the multiplier is **one-place**, measured here and not known to generalise.

**What this says about the revisit trigger.** The trigger fires, but not for the reason it names: the
ruled `k` is over budget at three of five hard cells, and the instrument that ranked them mis-ranks
against measured cost. Both point the same way — an instance budget solved *per place* (backlog 198)
would hold where a fixed global constant cannot, because the quantity that varies is a property of
the place. That is an argument for the inversion and not a recommendation to land it: it buys a
popping defect, and the motion metrics that would catch one do not exist yet.

### Recommended `k`, for the corpus to rule on

The horizon rule is §19.8.4's; `k_res` is a pinhole identity and that half is measurement. What
follows is a **recommendation with its evidence**, not a setting — the shipped viewer runs with the
rule off (`k = 0`).

> **Recommended: `k / k_res = 0.35`** — `k ≈ 182` at 1280 × 800 and 75°.
> **Usable range: `k / k_res ∈ [0.35, 0.6]`.**
>
> **SUPERSEDED AT THE HARD CELLS — see `scatter_horizon.json` above.** This range was derived at two
> 81st-percentile places. At the five densest cells 0.35 is over budget in three, and one has no
> value that is both above the placement-raster floor and inside the frame budget. The recommendation
> stands for the basin's typical cell and does not generalise; a fixed global constant is what fails,
> not this particular value of it.

**Bounded below at 0.35 by the placement raster, measured from both directions.** The horizon is cut
on a 31.25 m sub-cell grid, and a family whose horizon is under about four sub-cells is drawn as a
handful of squares or dropped outright. At place A the count law breaks below 0.2 (16.2× and 7.16×
against a predicted 4.0) and is clean from 0.2 to 0.5. At place B grass is **dropped entirely** at
0.05 — a 16 m horizon is half a sub-cell — erratic through 0.2, and clean from 0.35 (1.88 against
2.04, 2.10 against 2.25). Two independent routes to the same floor.

**Bounded above at about 0.6 by two things that arrive together.** The frame budget: at place A,
which carries the denser family, k/k_res = 0.5 costs **29.6 ms** and 0.75 costs **46.6 ms** against
a 33.3 ms budget. And the 1,500 m scan radius, which tree horizons pass at roughly the same point
(1,131 m at 0.5, 1,697 m at 0.75) — past it the outer loop binds instead of the rule.

**0.35 sits at the cheap edge of that window and the fidelity is already there**: 535,126 instances
and 14.3 ms at place A, 180,184 and 9.1 ms at place B, with succulent at ΔE 0.001 and full coverage,
grass at ΔE 0.000 and 94%, shrub at ΔE 0.004 and 88%.

**What this recommendation does not rest on.** No tree evidence at all — the oracle cannot reach a
tree's annulus. One day, `deepest_winter` day 22; the growing-season day the brief asks for is not
pinned yet. Place A's per-family rows predate the grass proxy-unit change and its costs above are
from the run that still carried the old unit. And `k_res` is a property of the rig: 521.3 at this
viewport and field of view, and a different one at any other, which is why the recommendation is a
ratio and not a number.

### Where "size cancels" does not hold, and what it costs

The brief's arithmetic is that per-family drawn count is `π k² × cover_f` — size cancels, so every
family costs the same order of instances per unit cover and the budget is one scalar. **Half of that
is true here and half is not**, and the half that fails is the one the brief's own caveat predicts:
*height sets the horizon while crown sets the cover*.

Count inside a family's own horizon is `cover_f × π k² × height²/crown_area`. That last factor only
cancels if it is common across families. It is not:

| | grass | shrub | succulent | tree |
|---|---:|---:|---:|---:|
| height² / crown area (declared max) | 22.1 | 2.0 | **127.3** | 9.1 |
| the same, on realised sizes | — | 2.7 | **51.0** | 3.6 |

A **64× spread declared, 19× realised**, and it is not spread evenly — the columnar succulent is the
outlier, because a form that stays narrow as it grows tall earns a far horizon and a tiny crown
area at the same time. The consequence is measured, not inferred: **succulents are 80–95% of the
drawn population at every k in the sweep**, against ~2% shrub and ~8% tree.

**What is true, and is the useful half:** one `k` does set the whole budget, total count really does
go as `k²` over the usable range, and **the family mix is k-invariant** — succulent share moves only
between 88.7% and 90.0% across 0.2 → 0.75. So the budget is one scalar in the sense that matters for
a knob. It is not one scalar in the sense that a family's share of it is predictable from its cover
alone.

**The lever is the brief's own, and it has now been pulled for grass.** It names the drawn *proxy
unit* — "a grass clump, not a blade" — as the per-family choice of what "individual" means, and that
choice is exactly what sets the height:crown ratio. Grass's drawn unit is now a **patch of sward**
rather than one tussock: `crown_m` 0.05–0.6 → **0.30–0.50**, which at the place that carries grass
takes the realised crown from **0.086 m to 0.313 m** and the aspect factor from **68.5 to 5.17** —
the "order 1–5" the brief asks for.

**The mesh had to change with it, and six ribbons could not simply be scaled.** Each of the old six
blades spanned the whole unit footprint, so at 0.31 m across they draw as six 0.31 m leaves: the
instance transform scales the blades as well as their spacing. The patch is 96 narrow blades on a
sunflower spiral — even over the disc, deterministic, and blade-width at any crown. 12 → **192
triangles**.

**Cover is conserved by construction, and measured to five significant figures.** Count is
`cover × texel_area / crown_area`, so a wider unit is proportionally fewer of them. Implied grass at
place B falls **101,413,641 → 7,651,670** (13.3×, exactly the crown-area ratio) and the ground
covered goes **589,113 m² → 589,102 m²**. The same ground, under fewer and wider instances.

What that does to the sweep at place B, k/k_res = 0.35:

| | before | after |
|---|---:|---:|
| grass instances | 484,176 | **36,520** |
| total instances | 627,840 | **180,184** |
| grass share | **77.1%** | **20.3%** |
| shrub / tree share | 9.8% / 13.1% | 34.1% / 45.6% |
| frame p50 | 9.52 ms | 9.09 ms |

**The composition is the win; the frame time is not, and should not be quoted as one.** 9.52 → 9.09
ms is inside the paced timer's own step (see the instrument section under `scatter_cost.json`), and
the reason it did not fall with the instance count is that the triangles moved into the mesh —
grass contributes 5.81 M triangles before and 7.01 M after. What changed is that the frame is no
longer three-quarters one family.

**The succulent keeps its unit, and that is a ruling rather than an omission.** Its factor stays high
(127.3 declared, 51.0 realised) and it is *not* the same case as grass. A columnar cactus **is** one
column: tall, narrow, and individually resolvable at range, so one column is the honest drawn unit
and widening it would be drawing a thing that is not there. A single grass blade never was the unit
in the same sense -- a sward is read as a surface and the blade was an arbitrary slice of it, which
is why the patch is truer as well as cheaper.

So the remaining aspect-factor spread is **expected, not unfinished**. What follows from it is a
budgeting fact rather than a defect: at a place carrying columnar succulents, that family takes most
of the drawn population under the horizon rule, and no proxy-unit change should be made to hide it.
If the count becomes unaffordable there, the lever is `k` or a per-family split of it -- both
measurements -- not a re-authored cactus.

**And the tint must keep taking trace shares un-floored**, which is the constraint that pulls the
other way. Trace shares are grass's main mode of existence — median 0.88% across the reference
basin, half of it under 1% — and they correctly draw *no individuals*, because a hundredth of a
texel's ground does not resolve into a plant. They must still tint, or grass vanishes from most of
the basin by construction and it renders as a basin without much grass rather than as a floor. The
shipped fixture carries **996 trace cell-groups under 1% cover, the smallest at 2.77e-7**, and all
996 reach the tint. Asserted, and blinded: a 1% floor in the tint drops 58 of them and breaks the
coverage-conservation check at the same time.

### Grass: it is the place, not the day — and the two pinned places are complementary

The first sweep drew **zero grass**, and the obvious reading — the brief's trap 1, that
`deepest_winter` day 22 is a winter day with no grass on it — is **wrong**, checked rather than
assumed. Grass is abundant on the wire: peak ground cover **0.76** in `largest_fire` (day 16) and
**0.74** in `deepest_winter` (day 89), over ~196,000 and ~210,000 cell-days respectively. And at the
seam place, grass reads **zero on every day sampled of both windows** — 0, 15, 30, 45, 60, 75, 89 —
in the *implied* pass, which is the unthinned wire implication before any drawing decision. A day
cannot explain a number that does not move with the day.

**It is the place.** The two places already pinned in this file are near mirror images:

| at EPSG:5070, `deepest_winter` day 22 | grass | shrub | succulent | tree |
|---|---:|---:|---:|---:|
| A `(-1310793, 1616226)` — implied | **0** | 3.7 M | **48.0 M** | 226 k |
| B `(-1212793, 1376226)` — implied | **101.4 M** | 3.0 M | **0** | 85 k |

A has no grass; B has no succulent. So the sweep was run again at B, and grass has rows after all:

| k/k_res | k | grass | shrub | tree | total | ×prev | k² predicts | grass horizon |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0.05 | 26 | **0** | 1,308 | 2,304 | 3,612 | | | 16 m = 0.5 sub-cells, **dropped** |
| 0.10 | 52 | 44,016 | 5,232 | 9,297 | 58,545 | 16.21 | 4.00 | 33 m = 1.1 sub-cells |
| 0.20 | 104 | 132,048 | 19,620 | 37,152 | 188,820 | 3.23 | 4.00 | 66 m = 2.1 sub-cells |
| **0.35** | **183** | **484,176** | 61,476 | 82,188 | **627,840** | 3.33 | 3.06 | 115 m = 3.7 sub-cells |
| 0.50 | 261 | 968,352 | 128,184 | 82,944 | 1,179,480 | **1.88** | **2.04** | 165 m = 5.3 sub-cells |
| 0.75 | 391 | 2,112,768 | 285,144 | 82,944 | 2,480,856 | **2.10** | **2.25** | 247 m = 7.9 sub-cells |

**Grass is the family the grid hurts most, and the numbers say where it stops mattering.** At
k/k_res = 0.05 grass is *dropped entirely* — its 16 m horizon is half a sub-cell — and the report
names it rather than letting the zero read as a measurement. Between 0.1 and 0.2 the horizon is one
to two sub-cells and the counts overshoot the k² law badly (16.2× and 3.2× against 4.0). From
**0.35 upward the law is clean** — 1.88 against 2.04, 2.10 against 2.25 — which is where the horizon
first exceeds about four sub-cells. That is the same lower bound the first sweep found, arrived at
from the opposite direction.

**And it generalises the imbalance rather than being an exception to it.** Grass at this place has a
realised height of 0.63 m against a 0.086 m crown, so its `height²/crown_area` is **68.5** — higher
even than the succulent's 51. It takes **77–87% of the drawn population** here, exactly as succulent
took 87–91% at place A. So the rule's composition is not a quirk of one family: **whichever family a
place carries with the highest height-to-crown ratio dominates what gets drawn**, and one `k` sets
the total without saying anything about the split.

The remaining gap is a scan-radius one: tree count flattens at 82,944 from k/k_res = 0.35 because
every tree the wire implies inside 1,500 m is already drawn, not because the rule stopped.

### Cost

| candidate | instances | build | frame p50 |
|---|---:|---:|---:|
| oracle (300 m at full density) | 1,652,596 | 16.3 s | 52.38 ms |
| null (ships today) | 119,994 | 1.6 s | 3.33 ms |
| tint (instances cut at 120 m) | 302,588 | 3.0 s | 12.50 ms |

The tint itself is a texture on a surface already being drawn; **all 12.5 ms is the near-field
instances inside the seam**, and the number to move is the seam distance, not the tint. Rebuilding
the per-cell texture costs **247 ms**, per day-step and not per frame.

### What had to be got right first, and was not

**Plants stood on the wrong surface, since M5.** `TerrainMesh.build` samples the heightfield every
`stride` texels — 4 km apart on the 1,000 m overview — and triangulates those samples, and the
scatter placed every instance on the *field*. The two differ by a **mean of 36 m and by up to
640 m** of float or bury. Invisible from an overview camera 1.5 million metres wide, and the whole
picture at eye level: the first seam run photographed 1.65 million instances as a patch on the
horizon. `TerrainMesh.drawn_surface_y` reproduces the
triangulation exactly, including which diagonal a quad is split along, and both the instances and
the camera stand on it now.

That also retracts a conclusion from `scatter_bands.json`: the eye-level coverage saturation
recorded there was a camera placed *underground*, not an incompatibility between eye level and the
exaggeration. The exaggeration turned out to be incompatible with eye level for a different reason
— the spikes — and is gone.

**Four other things this harness got wrong before it got them right**, each of which produced a
plausible-looking artefact:

- A depth image encoding range into RGB, which does not survive this renderer's sRGB output. The
  annulus is a one-bit mask instead, one render per band.
- `length(VERTEX)` read as a camera distance: every mask came back black at every band, which looks
  exactly like a camera pointing at nothing. World positions and `CAMERA_POSITION_WORLD` instead,
  and horizontally, so a band means the same thing whatever the relief does.
- A grey backdrop, so the sky counted as vegetation and coverage came back at exactly 1.0 for every
  candidate including the ones drawing nothing.
- A dither cell a **kilometre** across, because the mask frequency was in cycles across a raster
  whose texels are 1,000 m. A 180 m band fell inside one or two cells and came back entirely plant
  or entirely ground. It is metres of ground now, at 0.5 m.

### What it does not cover

One machine, one seam distance, two places, three day-window pairs, four runs, all at 1:1. An
earlier 12× half of this matrix was run and written up before its picture was looked at, and the
picture is what showed the subject was wrong — `visual_audit.md`'s lesson arriving late again, in
the tool built to stop it arriving late. Those rows are gone rather than kept: they measure a
render that no longer exists. The scoring annulus saturates —
oracle coverage is 1.000 in every run — so **coverage is matched trivially here and only colour
discriminates**; a basin band where the stand did not close would test it harder. No crossfade is
measured: each candidate is scored as if it were the whole far field. A run whose annulus contains
no ground is recorded as unmeasured rather than as a four-way tie at zero error, which is what the
first attempt at place B produced.

## `ground_relief.json` — two blockers that were wearing one gate

`DebugPlayer.walk_available` refused walk mode while the ground was sampled more coarsely than the
distance a body covers in a second. It was written as one criterion and it was answering two
questions, which only became visible when the tile pyramid moved one of them and not the other.

Measured headlessly at 60 places across the basin, each a 480 m disc — what
`tools/free_flight.sh` builds a scatter within, so it is the ground a standing body has near field.
Both grids decoded with **their own** constants; see below for why that sentence is load-bearing.

### The near field was one flat triangle, and now it is relief

| inside a 480 m disc | drawn today | tile pyramid z=0 |
|---|---:|---:|
| ground sample spacing | 4,000 m | **100 m** |
| ground samples in the disc (p50) | **0** | **69** |
| relief the grid holds (p50) | 20.2 m | **48.0 m** |

Zero is not a rounding of one. At stride 4 over a 1 km overview the drawn mesh triangulates every
4 km, so the whole near field of a standing body falls **inside a single triangle** — the blocker
this file has named since M5, stated as a count rather than as a complaint.

**What that costs today, in metres.** The gap between the drawn surface and the native grid inside
one disc: **p50 42.5 m, p95 252 m, worst 427 m**. That is how far a plant standing on the drawn
plane sits from the ground the data has. It is the same defect `vegetation_scatter.gd` already
places *against the drawn surface* to avoid — plants floating or buried — measured against the
data instead of against the mesh.

### The ground still does not change underfoot, and no pyramid will fix that

The underfoot question is not "does a 5 m step change the height" — that is a question about where
the step started. So it is measured as a **distance**: walk from each place on three headings at
1 m steps, and record how far the body goes between one reported height and the next.

| | metres between height changes |
|---|---:|
| p50 | **100.0 m** |
| p95 | 142 m |
| min | 1 m |

| at this sustainable speed | seconds of walking between one height and the next | meets the criterion |
|---|---:|---|
| 5.0 m/s (§3.1c, the stub) | 20.0 s | **no** |
| 0.7 m/s (a load-bearing envelope) | 142.9 s | **no** |

The criterion asks for ≤5 m at the stub's speed and ≤0.7 m at a real envelope's. The DEM under the
pyramid is **92.6 m native**, so **no pyramid built from this DEM can meet it** — and the real
envelope makes it stricter rather than looser, which is worth saying because the usual direction of
travel for a threshold under pressure is the other one.

**The number was not moved.** `test_the_pyramid_makes_the_near_field_relief_and_does_not_open_walk_mode`
fails if the underfoot measurement ever passes at 100 m, and the gate holds a control asserting that
a *slower* body cannot open a gate a faster one closed.

### And on a synthesised surface the criterion stops discriminating

The detail function (`src/terrain/detail_field.gd`) is that product, and running the same instrument
on it produced a second finding rather than a pass:

| on the synthesised surface | |
|---|---:|
| metres between height changes (p50) | **1.0 m — the sampling step** |
| vertical swing over 5 m of walking | 0.139 m |
| vertical swing over 0.7 m of walking | 0.0167 m |

**A raster cannot report a gap smaller than one cell; a continuous function has no cell.** It returns
a different height at every representable position, so the gap comes out as whatever step the
instrument used — and a synthesizer of one micrometre amplitude would measure exactly as well as one
of a metre. The criterion is satisfied trivially and says nothing.

So **walk mode is not opened on it.** What a body would actually feel is the swing — 14 cm of
undulation per second at running pace, 1.7 cm at a load-bearing one — and the criterion has no
clause about that. Adding one is a design question about how much ground movement is enough, not a
threshold to pick, and it is carried rather than answered.

**So the finding is that walk mode wants a product that does not exist**: metre-scale relief, which
is a detail mesh or a synthesis rather than a terrain export. Synthesising it is *adding* to what
the data says, which is a design question and not this repo's to answer. Fly mode is unaffected, and
a rung-boundary sweep does not need walk mode.

### The tiles do not decode with the overview's constants

Both grids resample with `average`, which pulls extremes in by an amount that depends on pixel
footprint; the native grid measures about 53 m higher at the top. **Decoding a tile with the
overview's `offset_m` / `scale_m_per_step` misreads it by up to 39.9 m** on real ground here,
silently, because a clipped code is a valid code.

So the encoding travels in the tiles' **own** pin (`assets/terrain/tiles/PIN`), `TilePyramid`
refuses to run without one rather than falling back on the pair it can see, and
`test_the_tiles_do_not_decode_with_the_overviews_constants` measures what the wrong pair would have
cost rather than asserting that it would have cost something.
