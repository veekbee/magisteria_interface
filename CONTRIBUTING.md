# Contributing

## Design rationale lives upstream and is not reproduced here

This repository is **public**. The design corpus it implements is **not**, and is not going to be.
So there is one rule that governs every file, every comment, every README, every commit message,
and every issue or PR reply:

> **Cite corpus sections and decisions by number. Never excerpt them.**

`decision 894`, `§20.4.4`, `§23.819` — a bare number is a pointer, and a pointer to a private
document discloses nothing. What must not appear is the *content*: the argument a decision rests
on, the finding a section records, the measurement behind either. A reader who does not have the
corpus should be able to see **what** this code must do and never **why the project concluded it**.

This is not secrecy for its own sake. It closes a slow-leak channel that is genuinely hard to see
while you are in it: the helpful comment that explains why a percept behaves as it does. One such
comment is harmless. The accumulated set is a reconstruction of the design, assembled by people who
were each being helpful.

**Worked examples.**

| Not this | This |
|---|---|
| `# No lattice is ever geometry (890). The drawn substrate is the DEM, because a lattice is a generator and not a thing.` | `# No lattice is ever geometry (decision 890).` |
| `# Excluded because a per-taxon anything discloses the axis's cardinality at any rung.` | `# Palettes are excluded at every rung (§23.773).` |
| A commit message reconstructing the argument for a ruling | A commit message saying what changed here, citing the ruling by number |

**One thing that is not a leak, and the distinction matters.** `contract/schema.json` is vendored
here and is therefore public by decision 896. Quoting *it* — its `version_rule.mismatch` text, its
`row_form_note`, its envelope notes — reproduces a file that already sits in this repo. The loader
and its tests do exactly that on purpose, so that the policy they implement can be checked against
the contract's own words. **Quoting the artefact is fine. Quoting the corpus is not.** If you are
unsure which you are holding, the test is whether the sentence appears in `contract/schema.json`.

**If a rule here seems wrong or a rationale seems necessary**, that is an upstream design ask, not
a comment to write. Open an issue saying what is unclear and which number it concerns; the answer
lands in the corpus and comes back as a ruling.

## The import boundary

This repo consumes exactly three artefacts from the simulation repo — the schema artefact, the
terrain export, and the fixture — each vendored and pinned. No Python imports, no reading the
simulation's `sim/` or run directories, no internal-rung debug path. See `README.md`.

## No addons, of any kind

No third-party terrain plugins and no test framework. `godot --headless --script` with hand-rolled
asserts covers the loader and the inspector. CI enforces the absence of an `addons/` directory.

## Godot version

**4.7.2**, pinned in two places that must move together: `GODOT_VERSION` in
`.github/workflows/checks.yml` and `config/features` in `project.godot`. A local/CI version split is
a class of failure neither side can see — local goes green on one engine, CI on another, and the
divergence only surfaces when a language feature differs.

## Before you push

```
python3 tools/check_contract.py
godot --headless --import        # must print no SCRIPT ERROR
godot --headless --script res://tests/run_headless.gd
```

The import step **exits 0 even when scripts fail to parse** — that is measured, not theoretical, so
read the output rather than the exit code. CI greps for it.
