# Brief: far-field vegetation, candidate #1 — the per-cell tint, and the harness that grades it

Written against `magisteria_interface@3eeb69c`. Every figure below is from `measurements/` at that
base, on the machine named there (Apple M5, `gl_compatibility`, Godot 4.7.2). Where this brief and
the repo disagree, the repo wins — say so in your notes.

## The design decision this implements

The far field has to become a collective representation (`measurements/README.md`, bands section).
The chosen first candidate is the cheapest one, on the argument that the metrics may show it is
sufficient: a **naturalistic per-cell vegetation tint** on the existing terrain — no new geometry,
no impostors, no band system. The viewer already draws a collective representation of vegetation
across the whole far field in data view (the `band.pft.biomass` overlay); this is its
natural-colour counterpart, derived from the same wire row the scatter samples.

The resolution wall licenses this as data rather than approximation: every plant within a cell is
the same plant, so per-cell mean colour × coverage is the same wire information the scatter
individualizes — nothing below cell scale is being invented that the scatter does not also invent.

## Part 1 — the tint

- A per-cell texture of (mean vegetation colour, coverage fraction), built from the same wire
  values the scatter is built from, rebuilt on day-step. Modulates the terrain shader in
  naturalistic view. Data view (the ramp) is untouched by this brief.
- **Range darkening.** Apparent stand colour falls with range — measured at 3eeb69c:
  (0.171, 0.340, 0.128) for the 100 m cut down to (0.085, 0.210, 0.061) for the fade-to-300 m.
  A tint that paints the near colour everywhere is visibly brighter than the stand it replaces.
  Fit a range-dependent darkening from the four measured rows in `scatter_bands.json`; the target
  is a function of range, not a constant.
- **Coverage, not opacity.** Instance bands cover 32–58% of screen with ground showing through;
  the 200→300 m band is worth 158,762 px of a 1,024,000 px frame at the pinned camera. Prefer
  reproducing coverage with a noise/dither mask over the tint rather than alpha blending — alpha
  over hillshade shifts colour, a mask reproduces "some pixels plant, some pixels ground," which
  is what the near field actually is. If you find a better mechanism, take it; the requirement is
  the measured coverage fraction, not the mask.
- The conserved quantity across any future seam is **coverage and mean colour per unit ground
  area, per family, as functions of range**. Build the tint so those two are its inputs, because
  the crossfade (out of scope here) will hold their sum to the target curve.

## Part 2 — `measure_seam`, without which sufficiency cannot be shown

A sibling of `tools/measure_bands.{sh,gd}`, inheriting its placement, isolation, coverage and
mean-colour machinery, and its refusals (headless, undrawn frames).

- **Oracle.** Instances-only render to 2–3× the candidate seam distance at a pinned
  place/day/camera. Affordable: the 300 m cut is 1.0 M instances, 7.9 s build, one frame
  photographed. The 28 M full-wire population is not the oracle and is not needed — beyond
  2–3× the seam everything is sub-pixel.
- **Range mask.** A second render writing linearized camera distance to a viewport, so image
  metrics can be binned by range. Score the seam in an annulus (≈0.7–1.5× seam distance), not
  whole-frame, where the near field would swamp it. This also upgrades the colour target from
  four schedule rows to a curve.
- **Baselines that calibrate the metric.** Score the null candidate (ships today: 2.0% coverage
  from eye level) and a constant-colour tint. The metric must cleanly rank
  {null, constant, range-matched} against the oracle or it cannot be trusted on anything subtler
  — the `ramp_agreement` discipline: the check has to fail the bad frame.
- **Outputs.** One JSON row per candidate — annulus colour error, coverage error, luminance-
  distribution distance, frame marginal, build time — to `measurements/`, PNGs to `shots/seam/`,
  in the `measurements/README.md` idiom: what was measured, how, on what, what it does not cover.
- **Two scores per candidate.** Isolated (vegetation only, against the measured targets) and
  in-situ (full scene, against the oracle) — the colour rows were measured in isolation, and a
  tint can match the stand in isolation and still fight the overlay and hillshade.

Frame cost of the tint is whatever the harness measures. Do not budget it from
`render_cost.json` — the empty-stage coefficient under-predicts this scene by ~1.3×, measured.

## Conditions and traps, inherited from the measurements

1. **Grass is untested at the pinned day.** `deepest_winter` day 22 draws 0 grass instances. Pin
   at least one growing-season day, and a second place (place-dependence is measured: 28.1 M vs
   23.8 M implied instances between the two windows). One place/day cannot show sufficiency.
2. **Eye-level cameras must bring the far plane down.** `near` 0.1 against the rig's 5,888,000 far
   draws nothing under `gl_compatibility`. Inherit `measure_bands`' placement code.
3. **Everything is conditional on the 12× vertical exaggeration.** Record any tuned distance as
   conditional on the factor, so a change to it stales them together rather than silently.
4. **The near field has no ground until the tile pyramid.** Ground colour through coverage gaps is
   pre-pyramid. Take the measurements anyway; when the pyramid lands, flag the absolute rows for
   re-take rather than rescaling them.
5. **Per-cell rebuild is per day-step**, not per frame — the 128 k instances/s build wall does not
   apply to a texture, but say in the artefact what the rebuild costs.

## Out of scope, deliberately

The shader-evaluated density fade, per-family seam distances (trees carried much further than the
small families), the crossfade schedule, and impostors are all *later* candidates, taken up only
if this one's metrics say the tint is not sufficient. Do not build ahead of the measurement — the
point of choosing the cheapest candidate first is that the harness gets to say no cheaply.

## What done looks like

`bash tools/measure_seam.sh` runs at two places × two days, emits the JSON and PNGs, and the
range-matched tint beats both baselines on colour and coverage in the annulus at every pinned
view — with the margins quoted, not asserted. Findings that come out of looking at the PNGs get
pinned by blindable asserts in `tests/run_headless.gd`, per the `visual_audit.md` pattern.
