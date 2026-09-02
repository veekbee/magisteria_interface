# magisteria_interface

The Godot client for the **magisteria** Colorado River Basin world simulation. Code, scenes and
build machinery live here. **The design corpus does not.**

## The boundary, which is a ruling and not a preference

`§16`, `§17.8`, `§19.8` and `§20.4` of the simulation repo's
`docs/basin_simulation_unified_design.md` remain that corpus's and are **normative for both
repos**. This repo holds no design authority. If client work ever needs its own design instrument,
it runs as a *track against that corpus* — the way the community tier does — and never as a
sibling corpus.

## What this repo may import from the simulation repo: exactly three artefacts

1. **The schema artefact** — `contract/schema.json`, vendored and pinned (below).
2. **The terrain export** — not yet built (sim-repo Phase 3).
3. **The fixture** — not yet built (sim-repo Phase 4).

No Python imports. No reading `sim/` or `/runs/` directly. No internal-rung debug path.

That last exclusion is decision 894's and it is absolute. Internal-rung debugging stays in the
simulation repo's Python tooling. **The reasoning for it is upstream and is not reproduced here** —
see `CONTRIBUTING.md`.

## The contract pin

`contract/schema.json` is a byte-identical copy of the simulation repo's
`data/schema_output/schema.json` — **never** `data/schema_draft_output/schema.DRAFT-v0.json`, which
is a superseded draft sharing its basename. `contract/PIN` is the machine-readable claim about
that file: its `sha256`, the simulation-repo commit the bytes come from, the commit the emitter
read, and the version pair.

The vendored file is *data*; the PIN is the *claim* about it. CI verifies the claim against the file
without parsing either, so an artefact bump is a two-file diff whose whole review surface is the
version movement.

- `tools/check_contract.py` — the local half. Does `contract/schema.json` match `contract/PIN`?
- `tools/check_contract.py --against <sim-checkout>` — the cross-repo half. Needs a checkout or a
  bundle of the simulation repo; run it when one is at hand. **Do not fake it with a stale copy.**
  The simulation side is independently guarded by `emit_schema.py --check` in that repo's own CI.

## This repo is public; the corpus is not

**Cite corpus sections and decisions by number. Never excerpt them** — in comments, READMEs, commit
messages, or issue replies. A bare `decision 894` or `§20.4.4` discloses nothing; the argument
behind it would. `CONTRIBUTING.md` has the rule, the worked examples, and the one case that is not
a leak (quoting `contract/schema.json`, which is vendored here and therefore already public).

## Layout

```
contract/     the vendored artefact and its pin
src/          GDScript — contract loader, UI
scenes/       Godot scenes
assets/       terrain and fixture fetched not committed; families commit normally
tools/        the contract check, and M5 build machinery
tests/        headless GDScript tests, no framework
```

## License

MIT — see `LICENSE`. Permissive by intent: this is a transducer, and the project's interest is in
as many of them existing as possible.

## No addons, of any kind

No third-party terrain plugins — a plugin's asset pipeline fights the ruled export formats. No
test framework either: `godot --headless --script` with hand-rolled asserts covers the loader and
the inspector. Revisit only if the test surface grows enough to justify the version coupling.
