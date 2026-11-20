# `recorded/` — the second fixture, and why it may not follow the `zz_` rule

Added by §25 backlog 752, which builds the session reader and the stats panel.
**It has a different job from the three files in the directory above, whose README
is `../README.md`, and the two must not be confused.**

- The parent directory's three files are the **guard's own control**: their names are synthetic so
  that a planted name can be found and refused. Their job is to make 741's
  derivation falsifiable.
- `recorded/` is a **synthetic recorded session**: the real schema's field names
  (`contract/session_schema.json`), with every value invented. Its job is to
  give the reader and the panel something to be built and tested against,
  because the thing 752 was specified to be built against does not exist.

**Why there is no real session to read.** 752's row says "built against a
recorded session directory (§25 backlog 747's play-through)". There is none, and
there cannot be one here: a session lives in a git-ignored directory on the
owner's machine (decision 2149 (1) — the **schemas** cross into this tree, the
values never do). 747 was a build with a timer and left a per-year cost table,
not a session. So the shape is declared in `contract/session_schema.json` and
this fixture is authored **from that file**.

**WHAT THAT COSTS, SAID HERE RATHER THAN DISCOVERED LATER: a suite passing
against this fixture proves the reader against the schema and never against the
generator.** The first real session the owner opens is the first integration,
and the first place a disagreement between the schema and `play_dressing.py`
can appear. The manager has that check recorded against the first integration
rather than dropped.

**THAT BILL ARRIVED ON 2026-11-19, AND THIS PARAGRAPH WAS RIGHT ABOUT THE
MECHANISM AND WRONG ABOUT NOTHING EXCEPT WHICH HALF WOULD BREAK FIRST.** The
owner's first launch met a session that had been created and never advanced, and
the reader refused it: this fixture holds a STEPPED session, so every test here
agreed with an assumption no test contained. See `../unstepped/README.md`, which
is that assumption's control.

## Why its names are not `zz_`-prefixed, and what happens because of that

They cannot be. The reader is built to read `built_tiles`, `capacity_less_occupancy`
and about thirty more; a fixture of invented names would exercise a reader
nobody will run. So this subtree holds the **real** field names, each one
allowed by a committed ruling in `contract/dressing_vocabulary.json`'s
`session_file_keys` group, added by this row with its reason.

**The scan's fixture exemption therefore LAPSES for these files, and that is
correct rather than unfortunate.** The exemption holds only while every
candidate under this directory is `zz_`-prefixed, precisely so that it cannot
be used to park a real name in a fixture. A real name appears here, so these
files are scanned like any other — and they pass, because every compound name
in them is on the allow side. **Remove one entry from the vocabulary and this
fixture is what goes red first.** That is the mechanism that makes "by ruling"
mean something.

## What is deliberately not in it

- **No feature row and no route row.** A real one carries a key naming its
  schedule-side source, which 741 forbids explicitly and permanently. A fixture
  may not hold it. The folds here carry two tile rows and empty `features` and
  `routes` arrays; the reader ignores unknown keys, so a real session's rows are
  read past.
- **No compound snake_case value anywhere, prose included.** The derivation
  reads leaf *values* as well as keys, so a sentence mentioning a filename with
  an underscore becomes a derived name of its own. One did, on the first cut of
  this fixture, and the check named it.
- **No figure from any real session**, and nothing shaped to look like one: the
  counts are small, the digests are runs of one character, the names are
  `not-a-session`, `not-a-dressing`, `not-a-bound`.

## Its shape, and what each piece is for

`session.json` at year 1879 over the arc `[1877, 2039]`, three stepped years
(`year_1877/`, `year_1878/`, `year_1879/`) each with a `fold.json` and a
`stats.json`, and two consumed commands with their answers under
`commands/done/`.

The **two pin-file digests** are the point of the arrangement, not decoration.
The start file's sha (`sha256:aaa…`) is what 1877 and 1878 were stepped under;
a placement then moved it to `sha256:bbb…`, which is `session.json`'s current
one and 1879's. So the fixture holds the exact state that would break a naive
binding: **a past year whose fold carries a sha that is no longer current.** A
reader demanding the current sha would refuse 1877 and 1878 — every year before
the placement — and the test asserts it does not.
