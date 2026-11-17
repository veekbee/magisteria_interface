class_name DressingFoldMemo
extends RefCounted

## §25 backlog 742: THE FOLD, COMPUTED ONCE PER (ROWS, YEAR) INSTEAD OF ONCE PER FRAME.
##
## WHY THIS EXISTS. `ExplorerView` called `DressingFold.fold(_tiles, _year)` from
## inside `_draw()`, and `_draw()` runs once a frame while a pin is being
## dragged. Owner ruling 2141's cost reading puts one fold-and-draw at no more
## than 0.268 s of CPU against the 14,325,300 bytes the explorer parses, so a
## drag redraws at about four frames a second, and twice the input halves that.
## The fold depends on the rows and the year and on nothing a redraw changes, so
## every one of those recomputations after the first produced the same answer.
##
## ⚠ THE KEY IS THE ROWS' IDENTITY **AND** THE YEAR, NEVER THE YEAR ALONE, and
## that is the whole of the design rather than a refinement of it. DA-11's play
## loop advances a session whose rows change with every placement: a route is
## drawn as the tiles the router laid, and those arrive as NEW ROWS from the
## generator, because what marks a tile route-laid is the row's own field and no
## rule in this client turns endpoints into laid tiles. A memo keyed on the year
## would therefore hand back the pre-placement city for any year it had already
## folded — while the placing preview had just drawn the route on screen. The two
## would disagree, both would look right, and nothing would report it. That is a
## control that cannot fail, in the viewer, on the surface the owner is being
## asked to rule on.
##
## SO THE IDENTITY IS PASSED AT EVERY CALL AND NOT MERELY AT CONSTRUCTION. A memo
## that learned its identity once could be held past the rows it describes, and
## then the caller carries the bug instead of the memo. Here a digest that does
## not match clears the cache and records a reset: the staleness is not something
## a caller has to remember to avoid.
##
## THE IDENTITY IS THE CALLER'S TO SUPPLY, because the caller knows the
## provenance and this class must not invent one. For the committed dressing it
## is the digest `DressingLoad` already recomputed from `tiles.jsonl`'s bytes and
## checked against the PIN — not a second hash of the same file, which would be
## a second source of truth for the same claim. For a session's rows it will be
## whatever identity that session's reader can state. An EMPTY digest is not a
## usable identity and is refused: see `problem`.
##
## THE CACHE IS BOUNDED, AND THE BOUND IS FIVE. Owner ruling 2141 measured peak
## resident set at 491,814,912 B holding ONE fold; 163 resident folds would trade
## a measured CPU cost for an unmeasured memory one, which is not a trade this
## client can make on one reading. So the four declared years stay resident once
## computed — they are the years the owner rules on, and §22.7's look returns to
## them — plus ONE slot for whatever other year is current. Stepping year by year
## through the slider therefore still folds once per step, which is unavoidable:
## each year is a different answer. What this removes is folding the SAME year
## again, which is what a drag did sixty times a second.

const DECLARED: Array[int] = [1890, 1940, 1990, 2039]

## The declared four plus the current year. Stated here and in the handover
## because a bound nobody writes down is a bound the next change raises by
## accident.
const RESIDENT_CAP := 5

## Why this memo is not memoising, if it is not. Empty when all is well.
var problem: String = ""

## Counters, for the gate rather than for display. `resets` is the one that
## matters: it is the number of times the rows' identity moved under the memo,
## and a test that could not see it could not tell this class from one keyed on
## the year alone.
var hits: int = 0
var misses: int = 0
var resets: int = 0

var _digest: String = ""
var _folds: Dictionary = {}
var _spare_year: int = -1


## The fold of `rows` at `year`, computed at most once per (identity, year).
##
## `rows_digest` is the identity of `rows`. It is compared on every call, and a
## change clears everything cached under the old one.
func fold(rows: Array, rows_digest: String, year: int) -> Dictionary:
    if rows_digest.is_empty():
        # NO IDENTITY, NO MEMO -- AND STILL THE RIGHT ANSWER. Caching under an
        # empty key would put every rows set in one bucket, which is the exact
        # staleness this class exists to prevent, so nothing is cached at all and
        # the fold is recomputed every call. Correct and slow beats fast and
        # wrong; `problem` says which state this is in, and the gate asserts
        # that nothing was cached.
        problem = ("the rows were handed over with no identity, so nothing is memoised and "
                + "every call recomputes: a memo keyed on an empty digest would serve one "
                + "rows set's fold for another's")
        misses += 1
        return DressingFold.fold(rows, year)
    if rows_digest != _digest:
        if not _digest.is_empty():
            resets += 1
        _digest = rows_digest
        _folds.clear()
        _spare_year = -1
    problem = ""
    if _folds.has(year):
        hits += 1
        return _folds[year]
    misses += 1
    var folded := DressingFold.fold(rows, year)
    if year in DECLARED:
        _folds[year] = folded
    else:
        if _spare_year != -1:
            _folds.erase(_spare_year)
        _spare_year = year
        _folds[year] = folded
    return folded


## The years currently held, sorted. The gate reads this to assert the bound.
func resident_years() -> Array:
    var out: Array = []
    for y in _folds:
        out.append(int(y))
    out.sort()
    return out


## The identity everything cached here belongs to.
func identity() -> String:
    return _digest
