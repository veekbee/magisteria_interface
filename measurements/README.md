# `measurements/` — numbers this repo measured, not artefacts it was given

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

### The result: the tint is sufficient on both conserved quantities

Seam 120 m, annulus 84–180 m, eye level on the drawn surface, two places and three day-window
pairs:

| window | day | place | oracle cover | tint cover | tint ΔE | null ΔE | margin |
|---|---:|---|---:|---:|---:|---:|---:|
| deepest_winter | 22 | A | 1.000 | 1.000 | 0.0223 | 0.1471 | 6.6× |
| deepest_winter | 85 | A | 1.000 | 1.000 | 0.0224 | 0.1476 | 6.6× |
| largest_fire | 0 | A | 1.000 | 1.000 | 0.0140 | 0.1873 | 13.4× |
| deepest_winter | 22 | B | 1.000 | 1.000 | 0.0030 | 0.1588 | **53.4×** |

**The tint sits 0.003 to 0.022 from the stand in RGB and matches its coverage exactly, everywhere
it was run.** The null baseline — what ships today — sits 0.147 to 0.187 away and reaches 0.02 to
0.09 of the coverage. The margin runs from 6.6× to 53×.

Across range bands at place A it tracks the oracle the whole way out:

| band | ground px | oracle colour | tint colour |
|---|---:|---|---|
| 30–60 m | 188,544 | (0.248, 0.309, 0.160) | (0.233, 0.286, 0.148) |
| 84–120 m | 53,460 | (0.227, 0.322, 0.153) | (0.210, 0.309, 0.142) |
| 120–180 m | 42,299 | (0.209, 0.337, 0.147) | (0.198, 0.324, 0.139) |
| 240–360 m | 21,580 | (0.188, 0.380, 0.145) | (0.177, 0.367, 0.137) |
| 360–480 m | 10,837 | (0.186, 0.387, 0.145) | (0.176, 0.376, 0.138) |

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
separates the null baseline by 2.4× at its worst.

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

**The lever is the brief's own.** It names the drawn *proxy unit* — "a grass clump, not a blade" —
as the per-family choice of what "individual" means, and that choice is exactly what sets the
height:crown ratio. A columnar family drawn as a clump of columns rather than one column would move
its aspect factor toward the woody families and the imbalance with it. That is a family-authoring
change and is not made here.

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
