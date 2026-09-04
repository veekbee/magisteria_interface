# `assets/families/` — M5's form archetypes

Four glTF families and `families.json`, mapping `life_form → file + parameters + legal ranges`.
Built by `bash tools/build_families.sh`; sources in `tools/blender/`.

Committed rather than fetched, and both halves of `assets/README.md`'s rule agree for once: they
total 23 KB, and `tests/run_headless.gd` reads them, so they are also part of what a fresh
clone needs to run the gate green.

## Four, and the count is read rather than chosen

`band.pft.biomass` and `band.pft_fractions` carry a group axis of four, and the fixture names those
groups in `windows.<window>.series.<row>.taxon_groups`. That list is the family list. The client
reads it at runtime and keys families **by name**: the wire's order is alphabetical — grass, shrub,
succulent, tree — and any other order a reader might reasonably expect would scatter each family
over another family's ground while looking entirely plausible.

**Keyed by life-form member, never per taxon member.** Palettes are off the wire (decision 894) and
the fixture aggregates to life form (decisions 872, 889), so a per-PFT or per-AFT mesh set has no
key it could legally be indexed by. A size-baked form token would be wrong rather than imprecise
across most of a palette (§23.302, decision 180). The family is authored; every individual is
parameters.

## The five animal families are absent, and that is a ruling rather than a gap

The roadmap's M5 asks for nine: four plant, five animal. The five are not here, `families.json`
records their absence with the reason, and the test suite asserts that record exists.

There is **no AFT row on the wire at all.** `contract/schema.json` at v2.0 carries eight rows, none
with an `aft` dim, and the envelope declares only the `pft` taxonomy. Decision 901 re-declared
`node.aft.population` internal because its only writer is unimplemented, and v2.0 dropped it from
the carried set.

So there is no density, no presence and no count to place an animal with. M5's binding rule is that
parameter ranges come from wire-visible information only; for animals there is none, and five
families whose legal ranges were invented — and which no test could exercise, because there is no
field to scatter them over — is precisely what that rule exists to prevent. Author them when an AFT
row reaches the wire. The family count is read from `taxon_groups`, so a fifth group arriving
upstream surfaces as a **missing family named in the report**, not as silence.

## Cover is two rows, not one, and this repo read it as one until the seam work

`band.pft_fractions` is a **composition**, not a cover. Its four groups sum to 1.0000 in 5,593 of
`deepest_winter`'s 5,612 covered cells and in **none** of them to `1 - band.bare_fraction`, while
bare itself spans 0.035 to 1.000 and averages 0.475. Both rows cannot be absolute: a cell cannot be
95% bare and 100% covered.

So a life form's ground cover is **its share × (1 − bare_fraction)**, which is what
`VegetationScatter.ground_cover` computes and what the tint and the scatter both call rather than
each deriving. The nineteen cells that sum to neither are all `bare_fraction = 1.0`: fully bare
ground that still names a mix, which is the model's PFT state persisting at zero cover — and
exactly the case the old reading scattered a full stand onto.

The contract declares both rows as `fraction` in [0, 1] and says what neither is a fraction *of*,
so the reading rests on a property of the data. `test_pft_fractions_are_a_composition_of_the_cover`
asserts that property, including the discriminator: if any appreciable number of cells ever *did*
track `1 - bare`, that would be what absolute cover looks like and the reading would have to change.

M5 read the share as a cover. Nothing rendered wrong enough to notice — the scatter drew plausible
plants — until the far-field tint aggregated the same rows and reported **every cell at full
canopy**. The figures in `measurements/scatter_cost.json` and `scatter_bands.json` predate the
correction; their headers say so.

## Crown from cover: measured, and left alone

The cover correction made the crown mapping worth a second look, because crown reads cover and
count is cover ÷ crown area — so cover enters the count twice. The first reading of that was that
count goes as 1/cover and blows up on sparse ground. **That reading is wrong**: crown is a lerp from
a non-zero minimum, so as cover falls crown tends to `crown_m.min` rather than to zero, and count
tends to zero with it. Checked at every cell of `deepest_winter` day 22: `count × crown_area` comes
back to `cover` exactly, so the identity the derivation is built on holds everywhere.

What is true is that individuals per km² fall steeply as cover rises, because big plants are few:

| crown reads | sparse-to-dense density ratio | basin implied |
|---|---:|---:|
| **cover** (today) | 296× | 4.1 × 10¹² |
| the composition share | 204× | 3.0 × 10¹² |
| biomass per covered area (allometric with height) | 85× | 1.4 × 10¹² |

Three defensible mappings inside a factor of three of each other, and none of them pathological — a
square kilometre of 6%-cover scrub really does hold more individuals than a square kilometre of
80%-cover forest. So this is a **choice, not a defect**, and it is left where M5 put it. What the
correction did change is the input's scale: crown used to read the composition share (mean 0.25) and
now reads ground cover (mean 0.13), so crowns sit lower in their declared ranges than they did.
Re-scaling to compensate would be inventing a normalisation, and inventing one is what the coarse
ranges exist to avoid.

## The convention an instance transform relies on

Each mesh is normalised to **one metre tall and one metre across, standing on the origin plane**, so
an instance is `scale(crown_m, height_m, crown_m)`. The builder normalises the geometry rather than
trusting its own authoring numbers, and the headless tests check it.

**The second axis is crown width, not trunk girth, and the wire forces that.** §17.8.2 asks for
height and girth as separate axes for woody forms; of the two readings of "girth", only one is
derivable here. Ground cover is crown area × count — so crown width is constrained by carried
rows. Trunk diameter is constrained
by nothing on the wire: no carried row mentions stems, and an authored trunk-to-height ratio would
be a number invented to look precise. The trunk is drawn as a fixed proportion of the crown and is
not a parameter.

**Phenology is a mask, not a mesh.** Vertex colour R is the weight of a vertex in the seasonal tint
— 1.0 on foliage, 0.0 on permanent structure — so one family covers the year under a shader
parameter instead of one mesh per season. G carries height fraction along the form.

The value that mask is multiplied by comes from the wire: **this cell's biomass today against its
own trough and peak across the window**, sampled every ninth day. Normalised over the *row's* range
instead, a cell that never carries much biomass would read as permanently wintering and a productive
one as permanently at peak — a statement about where a cell sits in the basin, not where it sits in
its year. Over `deepest_winter` the tint runs from 0.0 mid-window to 1.0 at the window's end, which
is spring green-up.

The two numbers travel down **separate channels** — the mask in the mesh's vertex colour, the
computed value in the MultiMesh's custom data — and `src/fixture/vegetation.gdshader` combines them.
Carried as an instance *colour* the engine would multiply them together before the shader saw
either, and the product is zero both for a trunk in summer and for foliage in midwinter, which must
not look alike.

One engine detail the mask depends on: the MultiMesh must enable **instance colours and write
white** as well as custom data. With `use_colors` off the compatibility renderer delivers `COLOR` as
zero rather than the mesh's vertex colour, so the mask arrives as 0, every plant renders as bare
structure, and the season never shows — while still looking like perfectly good vegetation.

**None of that can be read back headless.** Under the dummy renderer a MultiMesh has no per-instance
store: transforms return the identity, custom data returns zeros, `buffer` is empty. So the scatter's
report is the checkable statement, and a test asserting on the instances would pass by comparing zero
against zero. `tests/run_headless.gd` pins the limitation so the next reader does not have to
rediscover it.

## The ranges are coarse on purpose

They are the span a life form can physically occupy, wide enough to contain whatever the field
implies; the individual's value inside that span is computed at the instance from two different
carried rows. A **narrow** range would be a claim about which plants live here, and that claim is in
the palette, which is off the wire.

If coarse ranges prove insufficient, that is a one-line design ask upstream (see `CONTRIBUTING.md`)
and not a file this repo writes.

**Parameters are refused, never clamped.** A height outside its family's declared range means a
computation went wrong upstream; pulling it to the nearest legal value produces a plausible plant
and destroys the evidence. `FamilySet.instance_transform` returns the reason and the identity
transform, which is visibly wrong if a caller ignores the refusal.

## Triangles are the budget

`measurements/render_cost.json` prices MultiMesh instancing on this project's renderer at roughly
10 ns per instance plus 0.16 ns per triangle, so past a few hundred triangles the mesh *is* the
cost. These are authored well below that: 12 (grass), 44 (tree), 48 (succulent), 70 (shrub). Twelve
is a floor rather than a taste — the benchmark measured complexities from twelve triangles up, and a
family below that span could only be priced by extrapolating the cost model past its own evidence.

**The authored count is not always the drawn count.** `meshes/generate_lods=true` on every family's
`.import`, and the importer produced one simplified level for two of the four — shrub 70 → **20**
triangles, tree 44 → **14** — while declining to reduce grass and succulent at all. Nobody asked for
that and nothing declares it, which is why it is written here: an LOD scheme designed on top of this
one would be the second, and the first would still be running. `measurements/scatter_cost.json`
records how it was found, and the difference it makes at the horizon the scatter is drawn at is
about 0.09 ms — under that measurement's own noise.
