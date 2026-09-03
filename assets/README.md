# `assets/` — what is committed, what is fetched, and why

Roadmap 5(e) asked for this decision *before* the first large artefact lands, and called it "the
client repo's build-machinery call, not a corpus question." This is that call. Measured 2026-09-03.

## The ruling

**Committed:** everything a fresh clone needs to run `bash tools/verify.sh` green.
**Fetched:** everything else, from GitHub Releases, by a manifest carrying a sha256.
**Not Git LFS.**

## Why not LFS, which is the obvious answer and is wrong for *this* repo

`magisteria_interface` is **public** (decision 896 — world-readable, indexable, archived). GitHub
bills LFS **bandwidth to the repository owner**, not to the person cloning, on a free tier of 1 GB
storage and 1 GB bandwidth per month.

The roadmap sizes the full-resolution tile pyramid in the hundreds of MB. At 300 MB that is **three
clones a month by anybody at all** before the owner is paying, and the repo is world-readable, so
who clones it is not something this project controls. A cost that any stranger can run up, on an
artefact whose whole purpose is to be public, is the wrong shape — and it is a *new* argument rather
than a general dislike of LFS: on a private repo the same choice would be fine.

## Why not simply committing them

Git history is permanent. The 27 MB fixture payload is in this repo's history now and cannot leave
without a rewrite, and a rewrite is the operation this project has already had to do once to purge
transport artefacts. Measured today: **`.git` is 61 MB against 38 MB of working assets** — history
already carries more than the tree does, and every future clone pays for every version of every
binary ever committed, forever.

That is affordable at 38 MB. It is not affordable at 38 MB plus a tile pyramid, and the cost cannot
be undone later.

## The boundary is functional, not a size threshold

**The committed set is exactly what CI needs.** Not "files under N MB", for two reasons:

- **A size threshold is a number chosen from the quantity it grades** (§23.425's shape), and it has
  to be re-argued every time an artefact grows past it.
- **The functional rule is self-enforcing.** An asset that CI needs and that someone moves to the
  fetched set turns CI red on the next run. A size rule rots silently; this one cannot.

It also gives the right answer to the question that actually matters — **a gate must not depend on
the network.** A fetch step inside `verify.sh` makes the gate fail for reasons that have nothing to
do with the code, which is how a gate gets disabled.

### What that means today

Everything now in `assets/` stays committed. All three sets are read by `tests/run_headless.gd`:

| set | size | committed because |
|---|---:|---|
| `fixture/` | 27 MB | the headless tests decode it — precision, nodata, bounds, the cell join |
| `terrain/` | 6.8 MB | the heightfield, residence and flowline tests all read it |
| `contours/` | 4.4 MB | M4's arc-indexing and level-set tests read it |

**Fetched when they arrive:** the full-resolution tile pyramid (declared in `terrain_export.json`
and deliberately not emitted), any full-resolution raster, and any future artefact in the hundreds
of MB.

**M5's nine exported form archetypes commit**, as the roadmap already says — they are small, and the
scatter tests will read them, so both rules agree. No exception is needed.

## The fetch mechanism, when the first fetched artefact lands

Not built yet, because nothing is fetched yet, and building it now would be machinery with no
consumer. What it must be, so it is not redesigned under pressure:

- A manifest beside the PIN, adding exactly one thing the PIN does not carry: a **URL**. The PIN
  already carries the sha256 and the source commit, and that discipline does not change.
- A fetch script that **verifies the sha256 before writing**, and refuses rather than warns.
- **No `gh` CLI dependency.** A release asset on a public repo is a plain HTTPS URL, and requiring an
  authenticated tool to fetch a public file would be a second reason for a fresh clone to fail.
- The fetched set is **absent, not stale, in a fresh clone.** Code that reads it must report absence
  the way `TerrainView.bind_fields` reports a missing fixture — a viewer stays usable without it, and
  says which artefact it lacks.
