# `visual_audit.md` — what the milestones look like, measured

M1's terrain was wound inside-out and never rendered. It was found during M5. For four milestones
the hillshade, the field overlay, the flow colours and the contours were asserted against data and
never against a picture — and every one of them "appeared correct", which is the claim the
inside-out terrain also satisfied.

This is the record of photographing each milestone's visible claim. Re-take it with
`bash tools/audit.sh`; the numbers below are that command's output on the hardware named at the
foot. **The pictures are not committed** — they are large, they go stale silently, and a stale PNG
looks more authoritative than a stale sentence. The record is the durable half.

**The audit is not a gate, and its findings are.** `tools/verify.sh` runs headless in CI and the
harness refuses headless, for the reason the frame-cost benchmark refuses: `--headless` draws
nothing and reports success. A check that cannot run where the gate runs is a checklist wearing a
gate's name. So every finding below is pinned by an assert in `tests/run_headless.gd` that can be
made blind — a vector, a material property, a colour — and the assert messages carry the
measurement that found them.

---

## Eight findings

Four of them are in one place: the terrain's surface. None was visible to the 1,827 checks that were passing before it,
because in each case the data was right and the picture was wrong.

### 1. The hillshade came from the north-east, beside a comment saying north-west

`# NW, the cartographic default` sat next to `rotation_degrees = Vector3(-45, 135, 0)` from M1. The
mesh is `+X east, +Z south`; at azimuth 135 the light travels west and south, so it **arrives from
the north-east**. Relief inversion — ridges reading as valleys — is what a non-NW hillshade costs,
and it is the one shading error a reader takes for the terrain rather than for the render.

Now 225. `test_the_hillshade_arrives_from_the_north_west` pins it, and it asks `mesh_to_world` which
way north is rather than restating the convention from the docstring beside it: repeating the
comment is precisely how this survived four milestones.

### 2. A specular highlight was washing the ramp off the ramp

`StandardMaterial3D` defaults to a specular term. It adds **white** in proportion to nothing in the
data, and white is the one colour a viridis ramp cannot absorb: the ramp was chosen because its
lightness rises monotonically, so a highlight moves a pixel off the ramp rather than up it.

| terrain material | overlay pixels lying on the declared ramp | mean distance |
|---|---:|---:|
| default specular | 43.5% | 0.126 |
| `metallic_specular = 0.0` | **99.8%** | **0.022** |

Measured with `FrameProbe.ramp_agreement`, which compares channel *ratios* rather than colours, so a
diffuse light — a scalar on all three channels — leaves it untouched and an added white term does
not. `test_ramp_agreement_survives_a_light_and_not_a_highlight` pins both halves of that: the
measurement has to pass a frame that is the ramp under a light and fail one with white added, or it
could not have found this.

### 3. Slopes facing away from the sun rendered pure black

One directional light and no ambient: **738 pixels of a 1,024,000-pixel frame** at zero. Black sits
next to this ramp's low end, `(0.267, 0.005, 0.329)`, so those pixels read as the lowest value in
the field rather than as ground the light did not reach.

A `WorldEnvironment` at `ambient_light_energy = 0.15` takes it to **1 pixel**, and the relief spread
goes **up**, 0.195 → 0.219 — those pixels now carry their field colour instead of none. Ambient
rather than a second light: a fill from the opposite side would flatten the relief the first light
exists to show.

### 4. The overlay's nodata — and enabling alpha is the wrong fix, measured

Commit `133c921` documented this and left it: nodata was written transparent black into a material
with `transparency` DISABLED, so the engine ignored the alpha and those texels reached the screen as
black. Two corrections come out of photographing it.

**The 105-pixel figure recorded against it was measuring something else.** Most of the black in that
frame was finding 3 — unlit terrain, present with or without a field painted. With no overlay at all
the same frame carries 697 near-black pixels; with the overlay, 738. The overlay's own contribution
was about forty pixels plus a bilinear smudge: the texture is filtered, so a black texel darkens its
neighbours too, and the artefact was never confined to the texels that caused it.

**And the obvious fix moves 700× more of the frame than the defect does.** Photographed both ways
against the same baseline:

| terrain material | pixels that changed | near-black | what happened |
|---|---:|---:|---|
| `transparency = ALPHA` | **17.89%** (183,000 px) | 738 → 0 | the ramp writes alpha 200, so the *whole basin* blended with the sky; the nodata texels became holes onto the background, not bare hillshade |
| nodata painted `BARE_ALBEDO` | **0.02%** (~256 px) | 738 → 738 | only the nodata texels changed; sorting untouched |

So nodata is now painted with the terrain's own bare albedo and reads as unmeasured ground.
Transparency stays DISABLED, and `test_the_main_scene_populated_itself` refuses to let it be turned
on without reading why.

### 5. The harness was captioning its own screenshots wrongly

The composite shot came back with the basin drawn for `deepest_winter / band.wetness / day 46` and
the panel beside it reading `largest_fire / band.bare_fraction / day 1`. The capture called main's
`_on_field_changed` directly, which repaints the terrain and leaves every widget as it was. Nothing
was wrong with the render and the caption on it was false — which is worse, and it is the exact
failure the harness exists to prevent, committed by the harness.

`FieldScrubber.select()` now sets the controls and emits once, and the capture drives that. The
application's own path runs all the way out to the controls, because the controls are in the frame.

---

## Three more, from photographing the verdict banner

The banner is the one UI element whose entire job is to appear on other people's screenshots, and
it had **twenty-six headless asserts and no picture**. All three findings below are failures the
asserts could not see, because every one of them reads the string and the string was perfect.

Shot over a scene rather than alone, at the two sizes that matter: `1280 × 800`, which is what
`tools/screenshot.sh` and every shot in `shots/` default to, and `900 × 1400`, which puts the basin
under the controls instead of beside them. Neither defect was visible in the other's shot, so both
are now in `tools/audit.sh` and come back on every re-take.

### 6. The disclaimer ran off the bottom of the window, and looked complete doing it

At 1280 × 800 the banner demanded **677 px starting at y = 186**, so its last 63 px were outside
the window. What that cut, in order: the second half of criterion 8 — *"stem density pinned at its
floor — occupancy 0.9994, so a vegetation field drawn per-stem is showing an absorbing state, not a
stand"*, which is the one bearing on the vegetation this session spent the week drawing — then the
equivalence exclusions **in their entirety**, and then the probe panel below it, displaced off
screen completely.

**It did not render as a broken disclaimer. It rendered as a disclaimer that stops.** A reader has
no way to tell four named fails from five, or an unqualified equivalence proof from one that
stepped around three fields.

Two fixes, and the second is the one that mattered: the banner moved to second in the control
column, where truncation cannot reach it — the column holds more than 800 px shows, so *something*
is always cut and the order decides which, and the interactive panels can be scrolled to while a
photograph cannot. And the exclusions are now grouped by reason (finding 8). Demanded height fell
**677 → 551 px**, bottom at 737 of 800.

Pinned by an assert on the banner's own laid-out height against a 800 px budget — the headless root
is a 64 px stub but the control column still lays out for real, so the number that overflowed is
measurable in the gate. Blinded by ungrouping the reasons: 863 of 800, fails.

### 7. The amber headline all but vanished against the bright end of the ramp

Photographed at 900 × 1400 over `band.bare_fraction`, where the basin sits under the controls, the
headline was drawn straight onto the scene and **disappeared into it**. Amber `(0.95, 0.78, 0.30)`
against the ramp's brightest stop `(0.993, 0.906, 0.144)` is a contrast ratio of **1.28 : 1** —
barely a colour difference, on the one element that exists to be read.

The banner now draws its own plate, `(0.07, 0.07, 0.09, 0.92)`, so contrast is a property of the
banner rather than of wherever the camera happens to point. Over the worst the ramp can put behind
it, amber goes **1.28 : 1 → 9.81 : 1**, and the two other states clear 4.5 : 1 as well (stale red
5.68, absent grey 7.55).

The assert is a pair, and the second half is what gives it teeth: each state must clear 4.5 : 1
**with** the plate *and fail it without*. Without that second check the test would pass on any
dark-ish default and never notice the plate had gone.

### 8. Three excluded fields, one reason, printed three times

The shipped fixture excludes `outlet_min_daily_q_m3_s`, `outlet_peak_q_m3_s` and `outlet_peak_doy`
for one gauge change, and the banner printed the same forty words once per field — about a third of
its height, two thirds of it repetition. That is what pushed finding 6 over the edge.

Fields sharing a reason are named together now. It is shorter, and it says the truer thing: **one
instrument change moved all three**, and a reader counting distinct reasons is counting what
actually happened to the proof. Two fields excluded for two reasons still render as two lines,
asserted, because grouping that hid a second cause would be a worse defect than the one it fixed.

### What the banner establishes, now that it has been photographed

`--window deepest_winter --row band.pft.biomass --day 22`, 1280 × 800, default view.

- The headline renders **EQUIVALENT** on real data: *"ancestor trace — acceptance 7 pass / 5 fail,
  scored at 5317027b6543 on runs/m0-instrumented-001: a different run, proven identical to this one
  (18/18 fields, 3650 ticks, 3 fields excluded)"* — legible in amber over its plate.
- **All five named fails are legible**, ending with criterion 8 complete.
- The exclusion line is legible and complete, naming all three fields and their one reason.

**EQUIVALENT and SCORED render in the same amber, by design** — the brief asked for both photographed
if they differ, and they deliberately do not. A proven-equivalent verdict is a valid verdict of this
basin, so it gets a valid verdict's colour; what separates them is the sentence, which names the
other run and the size of the proof. A second amber would say "unlike the one beside it" and stop
there. Only EQUIVALENT is photographable from the shipped fixture — the other three states are
reachable only by supplying a verdict, and this repo reads verdicts and never supplies them.

---

## What each milestone's picture establishes

Isolated with `--only`, black backdrop where the subject is not the ground, so the census measures
the layer and not the sky. 1280 × 800, `deepest_winter`, ortho camera.

### M1 — the hillshade is a light over real relief

`--only terrain --no-field --sun 225,45`

- **185,709 terrain pixels across 68 brightness levels**, p05 0.471 → p95 0.635. A terrain lit flat,
  one whose normals all point up, and one drawn from a shade map that failed to load all report
  **one** level; that is the number that separates a surface from a colour.
- **Moving the light moves 17.65% of the frame** — the terrain's whole share of it. A baked shade
  map could not do that, so the claim "hillshade is a light, not a texture" is now photographed
  rather than asserted.
- The two suns report *identical* spread and near-identical means. That is what a 180° flip should
  do: it mirrors which slopes are lit without changing how many are. The finding is the differing
  count, and the unchanged mean is why a mean alone would have found nothing.

### M2 — the overlay is the declared ramp, over the contract's bounds, moving with the day

`--only terrain --row band.wetness --days 0,45`

- **99.9% of 185,708 coloured pixels lie on the declared ramp**, mean distance 0.019. The overlay on
  screen is the ramp in `field_overlay.gd` and not some other palette.
- **11.07% of the frame differs between day 0 and day 45**, green-minus-red −0.146 → +0.108 and mean
  brightness 0.143 → 0.305 over those pixels: the basin wets across the window, in the direction the
  ramp's rising lightness encodes.
- Relief survives the paint — 95 and 150 brightness levels *through* the overlay — so the terrain is
  legible as terrain and as a field at the same time, which is the whole point of shading it with a
  light rather than tinting it.

### M3 — flow colour on the reaches, from a mapping that says it is provisional

`--only flowlines --row node.streamflow --days 0,45`

- **14,533 pixels of network drawn**, spanning brightness 0.166 → 0.596 — the flow ramp's own span,
  pale blue for little water to deep blue for much.
- **1.33% of the frame differs between the two days.** The reaches recolour with the day; the
  geometry does not move.
- *Observation, not a finding:* on a black backdrop the ramp reads inverted, because "more water" is
  drawn darker and the mainstem is the dimmest thing in the picture. Over the terrain — which is
  where it is drawn — it does not. The backdrop is the capture's, and the direction of the ramp is a
  display ruling `FlowDisplay` already declares provisional.

### M4 — the vendored contours are drawn, draped, and take their day from the scrubber

`--only contours --row band.snowpack_swe --days 0,45`

- **2,770 arc pixels on day 0 and 2,268 on day 45**, at a flat 0.990 white — unshaded, as intended.
- **0.47% of the frame differs between the days**: the line moves, and it moves *because the day
  moved*, since nothing else in the capture changed.
- The arcs sit over the northern high country and nowhere else. That is not a contouring defect —
  it is a near-bare snowpack, which is one of the acceptance criteria this run fails, and it is the
  reason for item 2 below.

### M5 — the scatter stands where a probe resolved, and carries a tint

`--only vegetation --row band.pft.biomass --days 22,89 --scatter`

- **120,006 instances placed** — 108,672 succulent, 10,947 shrub, 387 tree, 0 grass — covering 0.4%
  of the frame at the 1,500 m horizon, green-dominant at g−r +0.043.
- **0.02% of the frame differs between day 22 and day 89.** That is not a broken tint: the state
  line reports `phenology=[0.0, 1.0]` on *both* days, so this location's cells span the whole
  seasonal range in each frame and the aggregate barely moves. Without the state line printed beside
  the pixels, this reads as a defect. It is the reason the state line is printed.

### Composite — every layer at once

`--window deepest_winter --row band.wetness --days 45`

No layer eats another: contours over the overlay, flow over both, controls reading the state the
picture is in. Ramp agreement falls to 94.4% here and that is correct — the flow ramp and the white
arcs are coloured pixels that were never drawn from the overlay's ramp. Isolate with `--only
terrain` for a clean number.

*Two legibility observations, recorded and not acted on:* the flow legend at bottom right is dark
text on a dark strip and is close to unreadable, and the probe panel shows only its heading until
something is clicked.

---

## Conditions

Apple M5 (10-core GPU) / `gl_compatibility` / Godot 4.7.2 / macOS 26.6.2, windowed. Fixture
`millennium-001`, contract v2.0, `deepest_winter`. The census thresholds — what counts as neutral,
as near-black, as a brightness level, as on-ramp — are display conventions stated in
`src/bench/frame_probe.gd` and are not measurements; two frames should be compared rather than
thresholded wherever both are available.

**No verdict travels with any of these pictures yet.** The fixture manifest carries no acceptance
score, the banner in the dev UI says so on every frame, and until it carries one, every image here
is a picture of a run that fails several of its criteria with nothing on the image saying which.
