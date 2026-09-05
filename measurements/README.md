# `measurements/` — numbers this repo measured, not artefacts it was given

Everything in `assets/` was made somewhere else, vendored and pinned. This directory is the
opposite: a measurement that can only be taken *here*, because the thing being measured is the
engine. It has no `PIN` and no upstream, and it is not vendored — but it carries the same four
claims a `PIN` does: what was measured, how, on what, and what it does not cover.

## What is here

- `render_cost.json` — per-instance frame cost, and the ladder it was fitted from.
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
gives. Apple M5 / `gl_compatibility` / Godot 4.7.2, windowed at 1280 × 800, vsync off.

| | |
|---|---:|
| instances drawn | 119,994 (ceiling-bound) |
| frame p50, scatter hidden | 0.80 ms |
| frame p50, scatter drawn | 3.70 ms |
| **marginal, p50** | **2.90 ms** |
| `render_cost.json` predicts | 2.13 ms |
| ratio | **1.36×** |

**The empty-stage coefficient under-predicts, consistently.** Five runs gave marginals of 2.94,
2.90, 2.83, 2.75 and 2.74 ms against a ~2.14 ms prediction — 1.28× to 1.37×, reproducible to
1.07× and never once below the prediction. (The count is ceiling-bound at ~120 k either way, so
this row survived the cover correction below almost unchanged.) That is a bias rather than noise, and it is the size of
the conditional on every budget sentence M5 rests on that coefficient. What it does *not* say is
which of the differences is responsible: this scene draws through a custom shader with culling
disabled rather than a `StandardMaterial3D`, it overdraws a terrain rather than empty space, and it
uses three MultiMesh nodes rather than one. Naming the cause needs a sweep this artefact does not
run.

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

### What it does not cover

**Frustum culling is all-or-nothing, and it works.** Timed at the same place: 1.04 ms with the
scatter hidden, 3.70 ms with the camera on it, and **0.85 ms with the camera turned 180°** — the
three vegetation draw calls disappear and the primitive count returns to the baseline's. A
MultiMesh is culled as one node against one AABB, so looking away from the scatter is free and
looking at any part of it costs all 120,006 instances. Nothing between those two is available
without splitting the scatter into more than one MultiMesh.

One machine, one renderer, one place, one window, one day, one camera distance. The coefficient it
is checked against is itself not portable, and neither is this. It measures the scatter that was
*drawn*, which is the build ceiling's 120,006 instances and not the 28 million the wire implies —
the 501 ms figure remains a prediction, now made from a coefficient known to under-predict by about
a third in this scene.


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
| today: uniform over 1,500 m, 120 k ceiling | 119,994 | 0.91 s | 2.95 ms | 27,250 px (2.7%) | 227 |
| cut at 100 m | 186,208 | 1.42 s | 6.82 ms | 990,531 px (96.7%) | 5,319 |
| cut at 200 m | 721,556 | 5.47 s | 24.25 ms | 841,062 px (82.1%) | 1,166 |
| cut at 300 m | 1,500,088 † | 11.44 s | 43.69 ms | 939,757 px (91.8%) | 626 |
| fade 1 / .75 / .5 / .25 to 300 m | 750,500 | 5.75 s | 23.49 ms | 861,749 px (84.2%) | 1,148 |
| fade 1 / .5 / .15 / .05 to 1,500 m | 1,498,616 † | 11.52 s | 39.99 ms | 516,144 px (50.4%) | 344 |

† ceiling-bound rather than schedule-bound: these two are measurements of the cap, not of the
schedule, and the cap thins uniformly.

### These rows no longer support the conclusions they were taken for, and that is the finding

**The cover correction changed the plants, not just the counts.** Height comes from biomass per
*covered* area and crown from cover, so halving cover made every family taller and narrower: shrub
0.23 → 0.51 m, succulent 0.23 → 0.94 m, tree 2.10 → 4.37 m. At the 12× exaggeration those are drawn
6.1 m, 11.3 m and **52.5 m**.

The consequence is that **coverage saturates the frame at every horizon**: 96.7% at a 100 m cut,
82.1% at 200 m, 91.8% at 300 m — no longer monotonic, and no longer a curve anything can be fitted
to. From an eye at 1.7 m real (20.4 m drawn) among trees drawn 52.5 m tall, the near field fills the
picture whatever the far field does.

Read before the correction, these rows said coverage saturates with range and a fade beats a cut.
**Neither claim survives on this data.** What replaced them is a sharper constraint: *an eye-level
naturalistic view and a 12× vertical exaggeration are incompatible*, because the exaggeration is
applied to plants and not to the horizontal distance to them. Any seam distance tuned at eye level
here is tuned against a stand twelve times too tall.

The cost column is untouched by all of this and still stands: instances cost what they cost.

### The bottom row is a warning about the ceiling, not about long fades

The 1,500 m fade is the only schedule the build ceiling bound rather than the schedule, and it
covers **less** screen than the 300 m cut while costing more. When the ceiling binds it thins
**uniformly**, including the near field, which is exactly where the pixels are. A band system and a
global instance cap interact badly: the cap has to be spent near the camera or it undoes the
schedule.

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

### One plant on screen, and the 12× problem

Drawn height, not real height: M1 draws the basin at 12× vertical relief and the scatter scales
plants by the same factor so the two agree, while horizontal distance is **not** exaggerated. A
plant therefore subtends about twelve times the angle it would in the field.

| family | real | drawn | 100 m | 200 m | 300 m | 500 m | 1,000 m | 1,500 m |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| shrub | 0.23 m | 2.7 m | 14.1 px | 7.0 px | 4.7 px | 2.8 px | 1.4 px | 0.9 px |
| succulent | 0.23 m | 2.8 m | 14.7 px | 7.3 px | 4.9 px | 2.9 px | 1.5 px | 1.0 px |
| tree | 2.10 m | 25.2 m | 131 px | 65.6 px | 43.7 px | 26.2 px | 13.1 px | 8.7 px |

At true scale every one of these numbers is twelve times smaller: a real shrub is **sub-pixel past
about 85 m** and a real tree past about 780 m. **Any band distance tuned by eye on this render is
tuned against a 12× distortion, and the families do not fade together** — a tree is still 44 pixels
at 300 m where a shrub is 4.7.

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

### First, which of these runs is a measurement of a stand

**Only the 1× one.** The 12× rows below are faithful measurements of what the application draws at
its shipped exaggeration, and what it draws is not vegetation: `VegetationScatter` scales plant
HEIGHT by the exaggeration and leaves crown alone, so at 12× every plant is a 12:1 spike, and from
an eye inside the scatter 1.65 million of them render as a radial starburst. The picture is in
`shots/seam/x12_..._oracle_..._insitu.png` and it settles the question; no number in this file
would have.

At 1× the same view is a stand — pillar-form succulents, conifer-form trees, ground between them.

**The exaggeration cannot be applied to vegetation consistently, and that is a trilemma rather than
a bug.** Scale height only and the plants are the wrong shape. Scale uniformly and each plant covers
144× the ground it should, which breaks the identity `cover = count × crown area` that the whole
derivation rests on. Scale neither and the plants are twelve times too short against the relief,
which is what M5 was avoiding. There is no free option here; the resolution this measurement points
to is that **naturalistic view should not use the map view's exaggeration at all**, and that is a
ruling this repo has not made.

So: read the 1× row as the sufficiency result. Read the 12× rows as a metric check — the metric
ranks the null baseline worst there too — and not as a statement about a stand.

### The result: the tint is sufficient on both conserved quantities, at 1×

Seam 120 m, annulus 84–180 m, eye level on the drawn surface. **At 1×, where the oracle is a
stand** — two places, two windows, three day-window pairs:

| window | day | place | oracle cover | tint cover | tint ΔE | null ΔE | margin |
|---|---:|---|---:|---:|---:|---:|---:|
| deepest_winter | 22 | A | 1.000 | 1.000 | 0.0223 | 0.1471 | 6.6× |
| deepest_winter | 85 | A | 1.000 | 1.000 | 0.0224 | 0.1476 | 6.6× |
| largest_fire | 0 | A | 1.000 | 1.000 | 0.0140 | 0.1873 | 13.4× |
| deepest_winter | 22 | B | 1.000 | 1.000 | 0.0030 | 0.1588 | **53.4×** |

**The tint sits 0.003 to 0.022 from the stand in RGB and matches its coverage exactly, everywhere
it was run.** The null baseline sits 0.147 to 0.187 away. The margin runs from 6.6× to 53×.

The same matrix at 12×, which is a measurement of the spike scene rather than of a stand, and is
here as a metric check — the ranking survives, the absolute errors do not mean the same thing:

| window | day | place | tint ΔE | null ΔE | margin |
|---|---:|---|---:|---:|---:|
| deepest_winter | 22 | A | 0.0198 | 0.1167 | 5.9× |
| deepest_winter | 85 | A | 0.0198 | 0.1166 | 5.9× |
| largest_fire | 0 | A | 0.0497 | 0.1431 | 2.9× |
| deepest_winter | 22 | B | 0.1038 | 0.2470 | 2.4× |

Place B is the tell: **0.003 at 1× and 0.104 at 12×**, the best row and the worst row of the two
tables and the same place, day and window. What moved is the subject, not the candidate.

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
scatter placed every instance on the *field*. The two differ by a **mean of 426 m in mesh space and
up to 7,722 m**; at 12× that is 35 and 644 true metres of float or bury. Invisible from an overview
camera 1.5 million metres wide, and the whole picture at eye level: the first seam run photographed
1.65 million instances as a patch on the horizon. `TerrainMesh.drawn_surface_y` reproduces the
triangulation exactly, including which diagonal a quad is split along, and both the instances and
the camera stand on it now.

That also retracts a conclusion from `scatter_bands.json`: the eye-level coverage saturation there
was a camera placed *underground*, not an incompatibility between eye level and 12×. Both work.

**Four other things this harness got wrong before it got them right**, each of which produced a
plausible-looking artefact:

- A depth image encoding range into RGB, which does not survive this renderer's sRGB output. The
  annulus is a one-bit mask instead, one render per band.
- `length(VERTEX)` read as a camera distance: every mask came back black at every band, which looks
  exactly like a camera pointing at nothing. World positions and `CAMERA_POSITION_WORLD` instead,
  and horizontally — a 3D distance at 12× would put a band's far edge partway up a hillside.
- A grey backdrop, so the sky counted as vegetation and coverage came back at exactly 1.0 for every
  candidate including the ones drawing nothing.
- A dither cell a **kilometre** across, because the mask frequency was in cycles across a raster
  whose texels are 1,000 m. A 180 m band fell inside one or two cells and came back entirely plant
  or entirely ground. It is metres of ground now, at 0.5 m.

### What it does not cover

One machine, one seam distance, two places, three day-window pairs, eight runs. The 12× half of
the matrix was run and written up before its picture was looked at, and the picture is what showed
the subject was wrong — `visual_audit.md`'s lesson arriving late again, in the tool built to stop
it arriving late. The scoring annulus saturates —
oracle coverage is 1.000 in every run — so **coverage is matched trivially here and only colour
discriminates**; a basin band where the stand did not close would test it harder. No crossfade is
measured: each candidate is scored as if it were the whole far field. A run whose annulus contains
no ground is recorded as unmeasured rather than as a four-way tie at zero error, which is what the
first attempt at place B produced.
