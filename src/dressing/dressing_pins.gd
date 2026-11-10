class_name DressingPins
extends RefCounted

## THE COMMITTED PIN FILE, READ — `docs/roadmap/client.md` G-9, W3 (decision
## 2129, owner ruling 2130; §22.8.4, decision 2068).
##
## NOT TO BE CONFUSED WITH `PinFile`, WHICH WRITES. `PinFile` is G-8's authoring
## surface: it builds an emitted `pins.json` and checks its form. This class
## reads the dressing's COMMITTED pin file so the explorer can draw what is
## already placed. One writes, one reads, and they meet only at the emitter.
##
## THE BINDING, AND IT WAS ALREADY IN THE DATA. A dressing's manifest carries a
## `pins` field holding this file's sha256, so the dressing itself declares
## which pin file it was built against. This class REFUSES a pin file whose
## digest that field does not name, and the refusal prints both digests. Without
## it the explorer would happily draw one dressing's pins over another
## dressing's tiles and the owner would be asked to rule on the result.
##
## THE DIGEST IS COMPUTED HERE AND COMPARED WITH THE MANIFEST'S, which is read
## from the FETCHED manifest rather than from the pin file's own neighbouring
## `PIN`. The pin records the same value for a reader, and reading the
## expectation from the pin would compare the transport against itself.
##
## WHAT IS DRAWN, AND WHAT IS NOT. A pin row carries `pin_id`, `kind`, `type`,
## `from`, `authored_by` and its geometry, and those are what the explorer may
## show. The file ALSO carries free text -- its own `what`, `form` and
## `ruled_by`, and the pin's `note` -- which between them name a simulation
## register row, a simulation module path, decision numbers and a quoted
## instruction. **None of that is republished, surfaced or drawn** (decision
## 973; the client's C3 as confirmed at W2).
##
## THE SEVEN KINDS ARE NOT RETYPED HERE AND MUST NOT BE. §22.8.4 declares them
## and the file's own prose lists them; a copy in this tree would be a second
## copy of a bound, which is the defect §25 backlog 690's construal Q4 exists to
## prevent and the one G-8 was told not to repeat. A pin is read and drawn by
## the `kind` ITS OWN ROW CARRIES, shown as that row's own text.
##
## THERE IS NO COLOUR-BY-KIND TABLE, AND THE ABSENCE IS DELIBERATE.
## `palette.json` carries colours for tile classes, route classes, a feature
## outline, a background and an UNKNOWN, and NOTHING for the pin kinds -- so no
## colour for a kind has been ruled, and inventing one here would be a display
## bound the owner is shown without anyone having decided it. A pin is therefore
## drawn as an outlined polygon with its kind as a TEXT LABEL.
##
## ⚠ THE OUTLINE IS `FEATURE_EDGE` AND NOT `UNKNOWN`, which is the opposite of
## what this file said first. `UNKNOWN` is the renderer's magenta (255, 0, 255)
## for a CLASS MISSING FROM THE PALETTE, so a viewer that drew every pin in it
## would read as an error on every pin -- the owner would be looking at a screen
## full of the colour that means *something is wrong here*, at the one moment
## the screen is supposed to be trustworthy. `FEATURE_EDGE` (30, 30, 30) is the
## renderer's own outline for a feature's footprint, and the committed
## placeholder is a FEATURE pin, so the pin is outlined the way the thing it
## stands for is outlined. Nothing invented, nothing retyped. If the owner wants
## colour by kind at the look, that is a `palette.json` row and the simulation's
## to add, not a table for this tree.
##
## A PIN THAT CANNOT BE DRAWN IS REPORTED AND NAMED, NEVER SILENTLY SKIPPED.
## The kinds carry different geometry -- a polygon, a point, an edge, a tile
## list -- and a build that cannot draw one of those shapes must say which pin
## it could not draw. A pin quietly absent is one the owner cannot see is
## missing, and the owner's look is the whole point of the window.
##
## ⚠ THE GEOMETRY IS READ TO DRAW AND IS NEVER WRITTEN BACK. Pin polygons are
## EPSG:5070 metres, the magnitude at which this engine's decimal-to-double
## conversion is not correctly rounded: G-8 measured a coordinate reading one
## ulp low through the JSON parser, the script lexer and `String.to_float`
## alike. Drawing tolerance is metres and the error is about 1.4e-10 m, so
## reading these to put a shape on screen is sound. WRITING one back is not, and
## this class offers no way to do it: a moved pin's coordinates leave through
## `edit_list`, as float64 bit patterns keyed by `pin_id`, and every number the
## owner did not touch is re-emitted by the Python emitter as the author's own
## characters (construals (e) and (h)).

const PIN_PATH := "res://assets/dressing_pins/PIN"
const DIR := "res://assets/dressing_pins/"
const FILE := "pins.json"

const NOT_FETCHED := "NOT_FETCHED"
const PRESENT := "PRESENT"

## A pin row's fields the explorer may read. Identity and geometry only.
const DRAWABLE: Array[String] = ["pin_id", "kind", "type", "from", "authored_by",
        "polygon", "point", "edge", "tiles"]

var state: String = NOT_FETCHED
var why_absent: String = ""
var pins: Array = []                  ## the rows as read, untouched
var computed_sha256: String = ""      ## of the fetched bytes, prefixed
var problems: Array = []              ## empty exactly when the file is usable
## Spellings the EMISSION TOOL will refuse, which do not stop this view drawing.
var emitter_warnings: Array = []


## `manifest_pins_digest` is the manifest's `pins` field, from the fetched
## manifest. Pass "" and the load refuses rather than binding to nothing.
static func load_from(manifest_pins_digest: String, dir: String = DIR) -> DressingPins:
    var d := DressingPins.new()
    var path := dir + FILE
    if not FileAccess.file_exists(path):
        d.why_absent = ("the pin file is pinned but not fetched: %s absent. Run the fetch "
                + "tool against its pin; nothing else brings it in.") % path
        return d

    var bytes := FileAccess.get_file_as_bytes(path)
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(bytes)
    d.computed_sha256 = "sha256:" + ctx.finish().hex_encode()

    if manifest_pins_digest == "":
        d.problems.append("the manifest names no `pins` digest, so this pin file cannot be "
                + "bound to the dressing; refusing rather than drawing it unbound")
    elif manifest_pins_digest != d.computed_sha256:
        d.problems.append(("the pin file is not the one this dressing was built against. "
                + "the manifest names %s, the fetched bytes compute to %s")
                % [manifest_pins_digest, d.computed_sha256])

    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        d.problems.append("%s is not a JSON object" % path)
        return d
    var doc: Dictionary = parsed
    var rows = doc.get("pins", [])
    if typeof(rows) != TYPE_ARRAY:
        d.problems.append("the pin file's `pins` is not an array")
        return d

    d.state = PRESENT
    for r in rows:
        if typeof(r) != TYPE_DICTIONARY:
            d.problems.append("a pin row is not an object")
            continue
        var row: Dictionary = r
        for f: String in ["pin_id", "kind", "from"]:
            if not row.has(f):
                d.problems.append("a pin row lacks `%s`" % f)
        # ⚠ `from` IS CHECKED FOR BEING A WHOLE YEAR, NOT FOR BEING `TYPE_INT`.
        #
        # This check was `typeof(row["from"]) != TYPE_INT` and it REJECTED THE
        # COMMITTED PIN FILE, which carries `"from": 1877` -- an integer
        # literal, no decimal point, as Python reads it. **Godot's JSON parser
        # returns every number as a float**, so the parsed value is `1877.0`
        # whatever the file says, and a type check on it cannot see the file at
        # all: it reports a property of the PARSER and calls it a property of
        # the artefact. It failed a correct file and would have passed a wrong
        # one, which is both halves of being the wrong check.
        #
        # What is meaningful after parsing is whether the year is WHOLE. A
        # fractional year is not a year and the viewer cannot place it.
        if row.has("from"):
            var y = row["from"]
            if typeof(y) != TYPE_INT and typeof(y) != TYPE_FLOAT:
                d.problems.append("pin %s has a `from` that is not a number (%s)"
                        % [str(row.get("pin_id", "?")), str(y)])
            elif absf(float(y) - roundf(float(y))) > 0.0:
                d.problems.append("pin %s has a fractional `from` (%s); a year is whole"
                        % [str(row.get("pin_id", "?")), str(y)])
        d.pins.append(row)
    d.emitter_warnings = _decimal_from_spellings(FileAccess.get_file_as_string(path))
    return d


## Any `from` written with a decimal point IN THE FILE'S TEXT.
##
## SEPARATE FROM `problems`, AND DELIBERATELY NOT A REFUSAL TO DRAW. §25 backlog
## 724's finding is about the WRITE path: the emission tool refused an emitted
## file whose year arrived as `1877.0`, and `rewrite_pins.py` writes `from` and
## `to` as integers for that reason. A viewer has no business refusing to DRAW
## over a spelling -- the pin is perfectly placeable -- but an author re-pinning
## in the explorer should learn it here rather than from the tool, so it is
## reported and does not gate.
##
## IT IS A TEXT CHECK BECAUSE IT HAS TO BE. After `JSON.parse_string` there is
## no difference between `1877` and `1877.0` in this engine, so the only place
## the distinction survives is the characters.
static func _decimal_from_spellings(text: String) -> Array:
    var out: Array = []
    var re := RegEx.new()
    re.compile("\"from\"\\s*:\\s*(-?\\d+\\.\\d+)")
    for m in re.search_all(text):
        out.append(("a `from` is written as %s, with a decimal point. The emission tool "
                + "refuses that on an emitted file (§25 backlog 724); a year is written as "
                + "an integer. The pin still draws.") % m.get_string(1))
    return out


func is_present() -> bool:
    return state == PRESENT


## True only when the file is here AND it is the dressing's own pin file.
func is_bound() -> bool:
    return state == PRESENT and problems.is_empty()


## The pins standing at `year`: those whose `from` is at or before it.
##
## A PIN IS NOT A TILE EVENT AND THIS IS NOT A FOLD. There is no later row that
## supersedes a pin; `from` is the year it begins to apply, and nothing in
## §22.8.4's form removes one. So this filters and never accumulates.
func at(year: int) -> Array:
    var out: Array = []
    for r: Dictionary in pins:
        # NOT a TYPE_INT test: see the note on the `from` check above. Godot's
        # JSON parser hands back a float for an integer literal, so a type test
        # here silently returned NO PINS AT ALL on a correct file -- a pin that
        # stands at the year would simply not be drawn, and nothing would say so.
        if not r.has("from"):
            continue
        var y = r["from"]
        if typeof(y) != TYPE_INT and typeof(y) != TYPE_FLOAT:
            continue
        if int(round(float(y))) <= year:
            out.append(r)
    return out


## The kinds present in this file, as the rows carry them, sorted. READ, NEVER
## DECLARED: see the header on why the seven kinds are not retyped here.
func kinds() -> PackedStringArray:
    var seen := {}
    for r: Dictionary in pins:
        seen[str(r.get("kind", ""))] = true
    var out := PackedStringArray()
    for k in seen:
        out.append(str(k))
    out.sort()
    return out


## The edit list the Python emitter takes: `pin_id` -> the moved geometry as
## float64 BIT PATTERNS, never as text.
##
## WHY BIT PATTERNS AND NOT NUMBERS. This engine's three text-to-double paths
## all read an EPSG:5070 coordinate one ulp low, so a coordinate that leaves
## here as a decimal string arrives wrong, and the emission tool refuses the
## file (§25 backlog 724, measured at G-8 on `from 1877.0`'s neighbour). Its bit
## representation is not in question, so the move crosses as bits and the
## emitter reassembles the double exactly. Every number the owner did not touch
## is not in this list at all, and is re-emitted from the author's own
## characters.
## ⚠ A VERTEX IS `[x, y]` OF GDScript FLOATS AND **NEVER A `Vector2`**, and this
## is not a style preference. GDScript's `float` is a double; **`Vector2`'s
## components are 32-bit**. At EPSG:5070 magnitudes float32 has about 0.125 m of
## resolution, so putting a coordinate through a `Vector2` loses roughly a tenth
## of a metre BEFORE this function ever runs -- and `encode_double` would then
## write a perfectly exact bit pattern for the wrong number. That failure is
## invisible: the round trip succeeds, the digest is stable, the emitter accepts
## the file, and the pin has silently moved.
##
## This signature took a `Vector2` for exactly as long as it took to write the
## test for it. The test now keeps a `Vector2` beside the float64 pair as a
## CONTROL, so the loss is a measured number in the suite rather than a claim
## in this comment.
static func edit_list(moved: Dictionary) -> Dictionary:
    var out := {}
    for pin_id in moved:
        var verts: Array = moved[pin_id]
        var rows: Array = []
        for v in verts:
            var xy: Array = v
            # TWO float64 bit patterns per vertex, x then y.
            var b := PackedByteArray()
            b.resize(16)
            b.encode_double(0, float(xy[0]))
            b.encode_double(8, float(xy[1]))
            rows.append(b.hex_encode())
        out[str(pin_id)] = rows
    return out
