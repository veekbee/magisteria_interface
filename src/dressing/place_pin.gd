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

## THE ZONE TOOL'S TEN, label then class, in the order design listed them.
##
## ⚠ THE LIST IS THE FORMAT'S `ZONE_CLASSES` AND NOT THE RENDER PALETTE'S. §25
## backlog 754 derived it from the palette and was wrong in BOTH directions: the
## palette is the nine bid classes **plus `transport`**, which the format refuses
## by name, and **without `residential`**, which the format accepts and which is
## this list's own *homes*. The integration read found the first half; the second
## was the manager's. A derived list was the right instinct and the wrong source
## -- a drawing palette is not a zonable set -- and there is no derivable source
## for this one: a session's `quota_carried` is empty in an early year and its
## `quotas_tiles` carries only the classes with demand that year, so both vary
## under the owner and omit the strata.
##
## ⚠ THE LABELS ARE DESIGN'S, NOT THIS CLIENT'S. They are listed at
## `notes/epoch-T/da11-play-loop.md` line 130 (heading 10's passage), which names
## *homes* as the umbrella over "all three strata" and *keep open* as `reserved`;
## the other eight follow by meaning. **The register's names are unchanged in the
## file** -- the label is what the owner reads, the class is what the pin carries.
##
## ⚠ AND THE CLIENT CANNOT PROVE THESE TEN ARE ACCEPTABLE. `PinFile` list-checks
## a route's class and a sink's type and NOT a zone's class, so acceptance is the
## session's answer and nothing else. One of the ten has been shown accepted on a
## real session (§25 backlog 754's integration read placed a zone and the
## emission took it); the other nine are asserted here by count, by the absence
## of `transport`, by the presence of `residential`, and by the map being a
## bijection.
const ZONE_LABELS: Array = [
    ["homes", "residential"],
    ["modest homes", "residential_low"],
    ["middle homes", "residential_middle"],
    ["wealthy homes", "residential_wealthy"],
    ["shops and offices", "commercial"],
    ["industry", "industrial"],
    ["warehouses", "warehouse"],
    ["civic", "institutional"],
    ["parks", "recreational"],
    ["keep open", "reserved"],
]


## The labels, in design's order.
static func zone_labels() -> Array:
    var out: Array = []
    for pair in ZONE_LABELS:
        out.append(str((pair as Array)[0]))
    return out


## The class a label stands for, or "".
static func class_of_label(label: String) -> String:
    for pair in ZONE_LABELS:
        if str((pair as Array)[0]) == label:
            return str((pair as Array)[1])
    return ""


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
    # ⚠ A ROUTE'S BASE IS ITS ENDPOINTS AND WAYPOINTS, added at §25 backlog 755.
    # Without this a route pin had no base at all and took the view's
    # `has no polygon this build can draw` line -- so "every first-version kind
    # drawn" was false for one of the six, and the kind that fails is the one
    # whose geometry is neither a polygon nor a point. The order is the
    # generator's own: the first endpoint, the waypoints, the second endpoint
    # (`endpoints[0], *waypoints, endpoints[1]`), so the line drawn here is the
    # line the router will be given.
    var ends = pin.get("endpoints", null)
    if typeof(ends) == TYPE_ARRAY and (ends as Array).size() == 2:
        var out: Array = [(ends as Array)[0]]
        var way = pin.get("waypoints", null)
        if typeof(way) == TYPE_ARRAY:
            for w in (way as Array):
                out.append(w)
        out.append((ends as Array)[1])
        return out
    return []
