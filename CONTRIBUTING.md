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

This repo consumes exactly four artefacts from the simulation repo — the schema artefact, the
terrain export, the fixture, and the pre-extracted contours — each vendored and pinned. No Python imports, no reading the
simulation's `sim/` or run directories, no internal-rung debug path. See `README.md`.

## How large artefacts arrive: fetch by manifest, never LFS

**Ruled upstream (decision 948).** Anything over roughly **10 MB** is fetched, not committed.
Smaller artefacts stay committed directly, which is why everything vendored under `assets/` and
`contract/` today is simply in the tree.

Four rules, and the first two are the ones that bite:

1. **The manifest's `sha256` is authoritative; its host column is not.** The digest is what makes a
   fetched byte-stream the artefact. Hosting starts on this repo's GitHub Releases and is expected
   to move; a move of hosting is not a change of contract, and nothing may be written that would
   make it one.
2. **The fetch script is the only sanctioned way bytes arrive.** Not a browser download, not a
   second helper, not a hand-placed file. One path, so there is no second one to drift from it.
3. **CI verifies digests on whatever is present.** A clone with none of the large artefacts is a
   valid clone and must stay one — the checks that need them skip, loudly, naming what is absent.
   A clone with the *wrong* bytes is not valid and fails.
4. **A manifest row carries the same fields a pin does**, one artefact wider: `path`, `sha256`,
   `size`, the producing `repo@SHA`, the producing tool, and the artefact's acceptance verdict
   where it carries one. `contract/PIN` is the idiom to copy.

**Why not git-LFS**, since it is the obvious answer and was rejected: it binds the bytes to the
forge that stores them and requires a reader to speak the protocol before they can clone at all.
This repo is public and its readers are not this project. A manifest leaves a plain `git clone`
working with the bytes optional.

**Why this paragraph exists at all.** A distribution policy that lives only in a conversation is
not readable from a fresh clone, and this project does not treat conversation history as authority.
If you are adding an artefact and are unsure which side of the threshold it falls on, the answer is
the manifest — a small artefact listed there costs a row, and a large artefact committed costs the
repo permanently.

## No addons, of any kind

No third-party terrain plugins and no test framework. `godot --headless --script` with hand-rolled
asserts covers the loader and the inspector. CI enforces the absence of an `addons/` directory.

## The tests cannot see the screen, so look at it

`tests/run_headless.gd` verifies data end to end and is blind to rendering: under `--headless` the
display server draws nothing, and every per-instance value in a MultiMesh reads back as zero. Three
defects reached `main` past a suite of 1,800 passing checks — the terrain wound inside-out and never
drawn since M1, a phenology mask that never reached its shader, nodata rendering as black. Each was
found by rendering something and looking at it.

**`bash tools/screenshot.sh` is the instrument for that.** It drives the application's own paths — a
day change goes through `main._on_field_changed`, a scatter through `probe_at_screen` and
`_on_probed` — photographs the result, and prints a colour census beside it so a finding can be
quoted instead of gestured at.

```
bash tools/screenshot.sh --row band.pft.biomass --days 22,89 --scatter --hide ui,terrain
```

Two habits it enforces, both learned by getting them wrong:

- **It reports the state it achieved, not the state you asked for.** A capture that prints only
  pixels invites you to assume the scene reached the state you named. When it quietly did not, the
  pixels are a picture of something else and nothing says so.
- **It refuses to report a difference between identical frames.** "+0.000 → +0.000" across two
  byte-identical images reads as a measured absence of change; it is the absence of a measurement.

Screenshots go to `shots/`, which is ignored: a frame is large and regenerable, so quote the
measurement in the commit message rather than committing the picture.

**`bash tools/audit.sh` is the named set** — one shot per milestone's visible claim, so the next
person can re-take the same picture and compare rather than take a different one and conclude. Its
record is `measurements/visual_audit.md`, and it found five defects the suite could not see: a
hillshade lit from the wrong compass point beside a comment naming the right one, a specular
highlight washing the field overlay off its own ramp, unlit slopes rendering pure black next to a
ramp whose low end is nearly black, an overlay nodata fix that would have moved 700× more of the
frame than the defect did, and the harness captioning its own screenshots with a state the picture
was not in.

**The audit is not part of the gate, and everything it finds is.** `verify.sh` runs headless and
the harness refuses headless; a check that cannot run where the gate runs is a checklist wearing a
gate's name. So each finding is re-expressed as something a blind suite *can* hold — a light's
direction as a vector, a material property, a colour written into a texture — and the assert
message carries the measurement that found it. Look with the harness; keep what you find in
`tests/run_headless.gd`.

## `project.godot` is minimal by intent, and cannot hold its own rule

Renderer and main scene only. Anything else added there is a decision someone should have to argue
for in review.

The rule lives **here** because it cannot live in the file it governs: Godot rewrites
`project.godot` whenever it runs — the editor, a windowed run, even `--headless --import` — and
deletes every comment in it. That happened twice during M5, once reaching a commit unnoticed. A test
that asserted the comments were present was worse than the disease: it turned the gate red for
something no code change caused, which is how a gate gets disabled.

So: settings are asserted by `tests/run_headless.gd`, which survives; reasons go in a Markdown file,
which the engine does not own. If you find `project.godot` carrying the engine's default boilerplate
header again, that is expected — restore the comment if you like, and do not build anything on it.

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
