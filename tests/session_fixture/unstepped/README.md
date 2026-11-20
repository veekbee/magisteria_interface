# `unstepped/` — the state the owner's first launch actually met

Added after the first launch of the owner's play session refused to open, on
2026-11-19. **It is the third fixture here and it exists because the second one
could not fail.** See `../README.md` for the guard's own control and
`../recorded/README.md` for the synthetic recorded session.

## What it holds, and why it is one file

A session that has been **created and never advanced**: `year` is 1876 against
an arc of `[1877, 2039]`, there are **no `year_<Y>/` directories**, no commands
and no answers. That is the whole fixture, because that is the whole state.

**`year` one BELOW the arc's first year is the generator's own encoding**, not a
malformed file. Its `Session.year` returns the schedule's start less one while
nothing has been stepped, and `session.json`'s `year` means *years less than or
equal to this are built* — which, for a session that has built nothing, has to
name no years at all.

**The current and start digests are the SAME here**, both `sha256:aaa…`, which
`recorded/` deliberately makes differ. Nothing has moved the pin file yet, and a
reader that assumed a placement had always happened would be reading a session
one command too late.

## What went wrong, said plainly, because it was this client's fault

`SessionRead.open_dir` refused any `year` outside `years` and so refused this
state outright. The owner's first launch against their own session drew the
committed city with a panel reading *"session.json's year 1876 is outside its
own arc [1877, 2039]"*. **The session was correct; the reader was wrong.**

**`../recorded/README.md` predicted this exact bill in advance** — *"a suite
passing against this fixture proves the reader against the schema and never
against the generator"* — and it was right about the mechanism and wrong only
about which half would break first. The fixture was authored from the schema and
held only a **stepped** session (year 1879, three folds), so every test agreed
with an assumption no test contained: **that a session the owner opens has been
advanced at least once.** This directory is that assumption's control.

## The second half, which a one-line fix would have left behind

The slider's span was `(first_year, year)`. For this state that is `(1877,
1876)` — **a high end below its low end**, an axis running backwards. Relaxing
only the guard would have opened the session and inverted the slider.

The span rule therefore now lives in `SessionRead` rather than in the view,
**because the gate cannot build the view**: `ExplorerView` is a scene node
needing a tree and the fetched dressing, so a rule computed inside it is a rule
nothing asserts.

**And the emptiness is a predicate, `has_span()`, not a value.** The first cut of
this row said "no span" with a zero range alone — a sentinel that reads as data,
so a caller who skipped the check would draw a slider from 0 to 0 and believe
it. The zero is still returned, but only as the harmless answer to a question
nobody should ask of the range itself.

## Its names are scanned, like `recorded/`'s

Every field name here is a real schema name, so the `zz_` exemption of the
parent directory does not apply and these files are scanned like any other.
They carry **no name `recorded/` does not already carry**, so this directory
adds nothing to `contract/dressing_vocabulary.json` — and the walk that proves
it reads this subtree too, not just `recorded/`.

**No figure from any real session**, and nothing shaped like one: the digests
are runs of one character, the names are `not-a-session`, `not-a-dressing`,
`not-a-bound`, and no value is compound `snake_case`.
