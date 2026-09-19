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

## Re-taken 2026-09-18, and four things came back — PRODUCED AND JUDGED BY ONE SESSION

**The control this record exists for is not satisfied here.** The shots were taken and read by the
same session that wrote the shot they were taken to validate. Every finding below is a first pass;
the owner's eye is outstanding and **T1 is not closed on this reading**. That limit is the point of
the paragraph at the top of this file: four milestones "appeared correct" to everyone reading data.

Run: `bash tools/audit.sh`, 52 s, 9 invocations, 15 images, on the built-in Retina display (the
external DX80 was attached and not used; Godot took the primary). Nothing here was ambiguous as to
whether it rendered — the set produced real frames and one deliberate blank, which is what rules out
the stub the harness warns about.

### 1. M5's scatter shot renders NOTHING, and has been doing so silently

`state probe=resolved  scatter FAILED: the horizon could not be solved here: nothing priced at this
cell`, twice, and the two frames come back at **one brightness level, spread 0.000 over 1,024,000
px, 100% neutral**. Opened: a uniform grey rectangle. The harness caught it itself —
*"THE TWO FRAMES ARE IDENTICAL. Either the state did not change, or the thing it changes is not
drawn."*

The gate has been printing the same refusal on every headless run for weeks
(`main scene scatter: the centre cell refused`), where it reads as one probe declining a cell. On
screen it is the whole of M5: the milestone's picture is a blank.

### 2. TWO SHOTS WERE OVERWRITING TWO OTHERS, EVERY RUN, AND ONE OF THEM DESTROYED §1's EVIDENCE

The output name is `window_row_day`, and **`--only`, `--camera` and `--size` do not reach it**. So:

| claim | wrote | overwritten by |
|---|---|---|
| M5 vegetation scatter | `deepest_winter_band_pft_biomass_day22.png` | verdict banner |
| M2 field overlay | `deepest_winter_band_wetness_day45.png` | composite |

Eleven files for thirteen shots. **M5's blank frame — the evidence for §1 — was replaced by a
correctly-rendered banner shot under M5's own name**, and the author of this run opened that file,
saw a good picture and reported M5 as fine for one message before checking the log. A set whose
entire purpose is that the next person can re-take a picture and compare had two claims with no
picture to compare against, and the replacement looked like a pass.

Fixed: `--tag` on `capture.gd`, applied to the five shots that needed discriminating. Fifteen files
for fifteen images now.

### 3. The harness's own line filter was discarding the tint measurement

`shot()` greps a **whitelist** of line prefixes, and `tint` was not in it. `--natural` is the only
flag that emits one, so the first run of the T1 shot produced its entire numeric evidence and threw
it away. Absence reading as a pass, one layer below the shots.

### 4. T1 — the far-field tint is there, covers exactly the drawable cells, and moves with the day

New named shot, `--natural`, ortho, black backdrop, days 22 and 89 of `deepest_winter`.

    tint   3252/5684 cells covered, mean cover 0.712, rebuild 267 ms  (day 22)
    tint   3252/5684 cells covered, mean cover 0.713, rebuild 235 ms  (day 89)
    compare: 10.01% of pixels differ; green-minus-red -0.058 -> +0.082

**3,252 is `drawable_cells` for `deepest_winter` exactly** — the count this client recomputes from
the payload through `VegetationScatter.ground_cover` and checks against the manifest. The tint covers
precisely the cells a plant can be placed in, which is T1's claim about consuming `fixture_v1`
reaching the screen.

Opened: an earth-toned basin — olive and khaki over the dry ground, green in the south and along the
wetter margins, bare grey rock, relief through the tint. **Not the viridis ramp**, which is what
`--natural` exists to replace. Coverage barely moves between the two days (0.712 → 0.713) while a
tenth of the pixels change colour and green-minus-red crosses zero, so what the season moves is the
COLOUR and not the population — consistent with cover being static across a window.

**The cross-reference this shot was framed for could not be taken.** It shares M5's day pair so the
far field's seasonal movement could be read against the near field's; M5 renders nothing, so there
is nothing to read it against.

### The owner looked, 2026-09-18 — the control is satisfied, and two things came out of it

**The second eye ran and T1's visible claim is CLOSED by it.** Six checks put to the owner; four
passed as posed, one resolved a condition I had left open, and one produced a finding by being read
the way a viewer reads it.

**M1's relief is NOT inverted, and the condition attached to that pass resolves true.** The owner
read the light as arriving *from the south in `sun045` and from the north in `sun225`* and made the
pass conditional on that being right. Worked through the geometry rather than left hanging: the
hillshade is a `DirectionalLight3D` at `Vector3(-45, degrees, 0)`, the mesh is +X east and +Z south,
so `sun045` travels west-and-north and **arrives from the south-east**, `sun225` travels east-and-south
and **arrives from the north-west**. That is what they described. The surface reads correctly under
both.

**But `--sun DEG` IS NOT A CARTOGRAPHIC AZIMUTH, AND THE RUN PRINTS THAT IT IS.** `capture.gd` emits
`state  sun azimuth 45 deg` while the light arrives from the south-east; an azimuth of 45 means light
from the north-**east**. It is a Y-rotation of the light node, not a compass bearing, and the two
differ by about 135 degrees. **This is finding 1 of this file, again, one layer out**: that one was a
comment saying north-west beside light arriving from the north-east. The value is not wrong and
nothing rendered is wrong; the LABEL names a convention the number does not follow, and the audit's
own purpose is to read those shots by that label.

**The far-field tint has no snow term, and it is read as snow.** The owner described the speckle
flagged below as *"texture that communicates partially-snowed areas"*. `VegetationTint.cell_colours`
composes `band.pft_fractions`, `band.bare_fraction`, the phenology row and `band.pft.biomass` — and
nothing else. **There is no snowpack anywhere in the tint.** What reads as snow is BARE GROUND showing
through at sub-cell scale.

That is a finding about the view and not about the reader. The window is named `deepest_winter`, the
days are in January and March, and white speckle over high tan ground is snow to anyone who looks.
The naturalistic view offers a viewer no way to tell bare rock from snow cover, and the quantity it
would need is carried — `band.snowpack_swe` is a row in this fixture and the contour layer keys on
it. **Not repaired here; a tint that means two things is a design question.**

**The reading was trained by the shot next to it, which is why it is worth recording.** The same
owner read white marks in the composite as snow too, and THERE THEY ARE: those are the vendored
contour set at `band.snowpack_swe >= 0.02 m`, in the same positions as M4's isolated frame, closed
loops over high ground. One shot shows snow as white and the next shows bare ground as white, in the
same sitting.

**The composite passes for the thing it exists to catch**: no layer eating another, no z-fighting, the
banner beside the basin rather than over it. Its lack of vegetation is EXPECTED and is not evidence
about M5 — at ortho with a field ramp painted, individuated plants are sub-pixel and the tint is off.
Those are two different absences and only one of them is the defect above.

**Passed as posed:** the tint's green sits in the low ground and the tan on the high mountains, which
is the cross-layer plausibility check against the drainage network; day 89 is visibly greener than
day 22, so the 10.01% and the green-minus-red crossing are perceptible and not merely measurable; and
the banner's orange headline is easily legible against the ramp at the narrow-tall size, which is the
size the original defect needed.

### W3 flown, 2026-09-18 — the first first-person flights since the C2 work, and two findings

**`flight-04`** (4,297 frames, 36 s, 1 mark) and **`flight-05`** (16,834 frames, 2.3 min, 0 marks),
both `first_person: true`, both at `--at -1107074.125,2255611.75 --recentre 0`, 11,791 instances
built with 3,398 in view, medians 4.46 and 4.94 m/s against an asked 5.0.

**They are the first flights recorded since `free_flight` stopped producing a first-person view at
all** — see `7689e99`. Two earlier attempts this evening produced the ortho overview with a walk
recorded around them, and a third produced a first-person view over ground with no vegetation
because the operator sent the owner to a cell that refuses. None of those three is committed.

#### 1. Height and crown width interpolate on different quantities, and it shows

The owner's mark, at 12.7 s of `flight-04`: *"the camera was at the top of the trees and their width
seemed stretched"*. The replay puts that mark **outside any stall reaction**, so it is a response to
something drawn rather than to a stutter — unlike all sixteen of `flight-01`'s.

`VegetationScatter.parameters_for` is the mechanism, and it is two lines:

    var t_h := clampf(per_covered / biomass_hi, 0.0, 1.0)   # HEIGHT <- biomass per covered area
    var t_c := clampf(fraction, 0.0, 1.0)                   # CROWN  <- cover fraction

**Nothing couples them.** Height tracks biomass; width tracks composition share. So wherever cover is
substantial and biomass is low, a plant is drawn short and full-width. Against the declared ranges,
a low `t_h` with a high `t_c` puts a tree at about **3.4 m tall and 12.2 m wide** (ranges 1.5-40 m
and 0.8-15 m) — a height-to-width of **0.28**, and **0.12** for shrubs.

**That is this basin.** Criterion 6 of the shipped verdict records area-weighted cover falling 0.96
to 0.53 across the run and still moving, which is the low-biomass-with-cover corner the two `t`s
diverge in. At a 1.7 m eye height the result is a camera at treetop.

**NOT RULED ON HERE.** Whether `t_crown` should track biomass, whether crown should be bounded by
height, or whether the fixture's biomass is simply low and the drawing honest, is a design question.
What is established is that the two axes are independent by construction and that the basin sits
where that is visible.

#### 2. The replay cannot reproduce a flight recorded at its own commit

Both flights, replayed at the commit they were flown at:

    flight-04:  4,297 of  4,297 frames disagree on population
    flight-05: 16,834 of 16,834 frames disagree on population

The artefact says what that means in its own words — *"a defect: the flight and the replay ran the
same code and disagree anyway"*, with `same_commit: true` and `ok: false`.

**The magnitude is a factor of ten and it has a shape.** At frame 0 the flight recorded **11,791**
instances; the replay recomputes **120,006** from the same poses. 120,006 is the CEILING build — the
figure `flight-02` and `flight-03` carry — while 11,791 is the solved-horizon build the flight
actually made. So the flight built at the solved horizon and the replay builds at decision 949's
ceiling, which is the pre-inversion world.

**That is the symptom's shape and not a diagnosis; the cause is not traced.** It is recorded here
because `replay_flight.gd` is also one of the four callers that discard
`TerrainView.focus_on_scatter`'s refusal with no other verification route, and because
`flight_replay.json` — already stale by construction — was produced by this path.

### Flagged and NOT diagnosed

The tinted surface carries a fine light **speckle** over most of its area. It is far finer than the
5,684-cell grid at this zoom, so it is not cell boundaries. It could be the naturalistic shader's
own texture, the synthesised micro-relief, or bare ground showing through at sub-cell scale — I
cannot tell which from one frame and I am not guessing. It is in every tinted frame and it is not a
stub: the same run produced correctly-rendered ramp, flowline and banner shots.

**ANSWERED IN PART, above**: whatever its mechanism, it is not snow -- the tint carries no snowpack
term -- and it is read as snow. The cause of the speckle itself is still undiagnosed.

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
