# `assets/families/` — reserved, empty

M5's output: parametric form archetypes exported to glTF, with a manifest mapping
`life_form → file + parameters + legal ranges`. Not yet built.

**Keyed by life-form member, never per taxon member.** Palettes are off the wire (decision 894) and
the fixture aggregates to life form (decisions 872, 889), so a per-PFT or per-AFT mesh set has no
key it could legally be indexed by. The family is authored; every individual is parameters.

**Parameter ranges come from wire-visible information only** — fixture coordinates, schema bounds,
and generic physical reasoning. A palette-derived morphology manifest is not a file this repo
creates. If coarse ranges prove insufficient that is an upstream design ask (see `CONTRIBUTING.md`),
and its output would itself have to be judged publishable before it could land here.

Sources live in `tools/blender/` and are build machinery; the exported families are small and commit
normally.
