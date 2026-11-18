class_name PlacePin
extends RefCounted

## MINTING A PIN THE OWNER PLACED — §25 backlog 754, decision 2149 (3) and (5),
## owner ruling 2150.
##
## The owner's gesture becomes a pin ROW in decision 2075's format, which the
## session consumes through `place` and hands to the emission tool. This class
## builds the row and nothing else: it draws nothing, writes nothing, and
## decides no geometry rule.
##
## ⚠ THE CLIENT MINTS THE `pin_id`, AND THE BRIEF SAYS IT DOES NOT. Decision
## 2149 (3) says a placement is "minted by the emission path"; the code requires
## otherwise -- `Session.place` takes full pin rows, each with "its own `pin_id`
## unused", and refuses a duplicate against the session's file and within the
## batch. The repo wins. The form is ruled: `<kind>-<from>-<n>`, HYPHENATED, with
## `n` the lowest free positive integer such that the whole id is in no pin's.
##
## ⚠ THE HYPHENS ARE NOT COSMETIC. An id with underscores would be a compound
## snake_case string, and a session file's leaf values are read by §25 backlog
## 741's derivation -- so an underscored id this client invented would start
## deriving as a forbidden name and refuse the client that wrote it.
##
## ⚠ `authored_by` IS `owner` AND NOT A GUESS. The generator's own provenance set
## is (`owner`, `design`), and the one committed pin -- the placeholder the owner
## placed -- carries `owner`. Anything this client writes was placed by the owner
## by construction: nothing here mints a pin on its own initiative.
##
## ⚠ NO VALIDATION RULE IS RE-IMPLEMENTED HERE. `refusal_of` builds a `PinFile`
## and offers the row to it, so the kind table, the required fields, the route
## classes and the numeric checks are the ones already written and already
## tested. A second copy of that table would agree with the first until the day
## §22.8.4 moved.

const AUTHOR := "owner"


## An axis-aligned four-vertex polygon from two world corners, in float64 metres.
##
## RECTANGLES FIRST, by the owner's ruling at this row: one drag, four vertices,
## free shapes later. The order is deterministic and starts at the low corner, so
## the same drag always produces the same row -- a polygon whose vertex order
## depended on which way the owner dragged would make two identical rectangles
## two different pins.
static func rect(ax: float, ay: float, bx: float, by: float) -> Array:
    var x0 := minf(ax, bx)
    var x1 := maxf(ax, bx)
    var y0 := minf(ay, by)
    var y1 := maxf(ay, by)
    return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]


## Every `pin_id` in a pin list, as a set.
static func ids_of(pins: Array) -> Dictionary:
    var out := {}
    for pin_v in pins:
        if typeof(pin_v) != TYPE_DICTIONARY:
            continue
        var id := str((pin_v as Dictionary).get("pin_id", ""))
        if id != "":
            out[id] = true
    return out


## The next free id of this kind and year. `taken` is `ids_of`'s set.
static func next_id(kind: String, from_year: int, taken: Dictionary) -> String:
    var n := 1
    while true:
        var id := "%s-%d-%d" % [kind, from_year, n]
        if not taken.has(id):
            return id
        n += 1
    return ""


## A pin row: the common four fields plus the kind's own, as given.
##
## `fields` carries the geometry and the class or type. Nothing is defaulted into
## it: a kind's required field that the caller did not supply is REFUSED by
## `refusal_of` rather than invented here, because a polygon or a class this
## class made up would be a placement the owner did not make.
static func row(kind: String, from_year: int, id: String, fields: Dictionary) -> Dictionary:
    var out := {"pin_id": id, "kind": kind, "from": from_year, "authored_by": AUTHOR}
    for k in fields:
        out[str(k)] = fields[k]
    return out


## Why this row would be refused, or "" -- `PinFile`'s own answer.
static func refusal_of(pin: Dictionary) -> String:
    # The anchors are this check's own and reach no file: `PinFile.over` wants a
    # well-formed pair, and the row is what is under test.
    var anchor := "sha256:" + "0".repeat(64)
    var pf := PinFile.over(anchor, anchor)
    if pf.add_pin(pin):
        return ""
    return pf.why_refused


## A point kind's pin at a world point, or "" -- within `radius_m` of its point.
##
## ⚠ WITHOUT THIS, `remove` WORKS ON FOUR OF THE SIX KINDS. The polygon hit-test
## next door tests containment, and a `centre` or a point `feature` has no
## polygon to contain anything -- which is the same blind spot the point-kind
## guards cover on the drag. A point is picked by distance instead, in float64
## metres so that the test does not depend on the zoom.
static func point_pick(pins: Array, wx: float, wy: float, radius_m: float) -> String:
    var best := ""
    var best_d := radius_m
    for pin_v in pins:
        if typeof(pin_v) != TYPE_DICTIONARY:
            continue
        var pin: Dictionary = pin_v
        var pt = pin.get("point", null)
        if typeof(pt) != TYPE_ARRAY or (pt as Array).size() < 2:
            continue
        var p: Array = pt
        var dx := float(p[0]) - wx
        var dy := float(p[1]) - wy
        var d := sqrt(dx * dx + dy * dy)
        if d <= best_d:
            best_d = d
            best = str(pin.get("pin_id", ""))
    return best


## The drag's base for a pin: its polygon, or its own point for a point kind.
##
## ⚠ THE SECOND POINT-KIND GUARD. Falling through to `polygon` alone returns `[]`
## for a `centre` or a point `feature`, and the drag then recorded an entry with
## no vertices -- a pin whose geometry a gesture had deleted. A point kind
## carries its own base, so dragging one moves the point it actually has.
static func base_of(pin: Dictionary) -> Array:
    var poly = pin.get("polygon", null)
    if typeof(poly) == TYPE_ARRAY and not (poly as Array).is_empty():
        return poly
    var pt = pin.get("point", null)
    if typeof(pt) == TYPE_ARRAY and (pt as Array).size() >= 2:
        return [pt]
    return []
