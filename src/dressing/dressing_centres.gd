class_name DressingCentres
extends RefCounted

## WHERE A TILE IS — §25 backlog 732's `centres.json` (owner ruling 2130's
## *"Renderer emits centres"*; decision 2129).
##
## WHY THIS FILE EXISTS AT ALL, because it is the answer to a defect and not an
## obvious artefact. A dressing's tile is `[patch_id, i, j]` — an index, not a
## position — while its routes' geometry and its pins' polygons are EPSG:5070
## METRES. Nothing in the dressing or the reference said where a patch was. The
## mapping lived in the simulation's 2 km patch lattice: 20,465,308 bytes, over
## owner ruling 948's line, carrying the whole basin's elevation, slope, aspect,
## distance-to-channel and HUC ids for 179,470 patches — of which this city
## touches 61, and of whose thirteen columns the centre rule reads two. Crossing
## 20 MB of basin hydrology to obtain 3 KB of patch centres was put to the owner
## under owner ruling 973, who ruled that the RENDERER EMITS THE CENTRES
## instead. So the lattice does not cross, this client implements no geometry
## rule, and the lattice's digest is carried here where it can still be checked.
##
## THREE BINDINGS, AND EACH STOPS A DIFFERENT WRONG DRAWING.
##
##   `lattice_sha256`   must equal the MANIFEST's `lattice`. Centres computed
##                      from a different lattice would place this city's tiles
##                      at another basin's coordinates, and every tile would
##                      look plausible.
##   `dressing_sha256`  must equal the dressing's RECOMPUTED identity. Centres
##                      for another dressing would draw this one's tiles at
##                      that one's positions.
##   `n_centres`        must equal the number of entries actually parsed. A
##                      truncated file otherwise yields a smaller city with no
##                      error anywhere.
##
## AND `crs` IS CHECKED RATHER THAN ASSUMED. A file in another projection would
## misplace everything by kilometres while every digest still agreed, because a
## digest says what the bytes ARE and not what they MEAN.
##
## ⚠ A TILE WITH NO CENTRE REFUSES THE DRAW. It is not skipped. Skipping shows a
## city with pieces missing, at the plausible scale, with nothing on screen or
## in the log to say a piece is absent — and the one thing the owner is being
## asked to do is look at it. This is the tile pyramid's lesson in another
## costume: measured absence and missing data are different answers, and a
## viewer that renders them identically has destroyed the difference.
##
## ⚠ THE CENTRES ARE float64 AND MUST NOT PASS THROUGH A `Vector2` AS WORLD
## COORDINATES. `Vector2`'s components are 32-bit; at EPSG:5070 magnitudes that
## is about 0.125 m of resolution, so a world coordinate put into one is damaged
## on the way in. The same mistake, two orders of magnitude larger than G-8's
## one-ulp parse, cost this client a defect in `DressingPins.edit_list` earlier
## in this window. So `centre_of` returns a float64 pair, and `local_of` is the
## ONE place the narrowing happens — AFTER subtracting the scene's origin in
## float64, where what remains is a small offset a float32 can hold exactly
## enough to draw. Reading these to put a shape on screen is sound; carrying
## them in a `Vector2` first is not.
##
## No `generated_by` or `what` string from the file is surfaced or republished
## (owner ruling 973; the client's C3).

const DIR := "res://assets/dressing_renders/da6-compact/"
const FILE := "centres.json"
const CRS := "EPSG:5070"

const NOT_FETCHED := "NOT_FETCHED"
const PRESENT := "PRESENT"

var state: String = NOT_FETCHED
var why_absent: String = ""
var problems: Array = []

var centres: Dictionary = {}          ## "p,i,j" -> [x, y] as the file carries them
var tile_m: float = 0.0
var tile_m_row: String = ""           ## the register row the size came from
var declared_n: int = -1


static func load_from(manifest_lattice: String, dressing_identity: String,
        dir: String = DIR) -> DressingCentres:
    var c := DressingCentres.new()
    var path := dir + FILE
    if not FileAccess.file_exists(path):
        c.why_absent = ("the centres are pinned but not fetched: %s absent. Run the fetch "
                + "tool against the reference's pin; nothing else brings them in.") % path
        return c
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        c.problems.append("%s is not a JSON object" % path)
        return c
    var doc: Dictionary = parsed
    c.state = PRESENT

    var rows = doc.get("centres", {})
    if typeof(rows) != TYPE_DICTIONARY:
        c.problems.append("`centres` is not an object")
        return c
    c.centres = rows
    c.tile_m = float(doc.get("tile_m", 0.0))
    c.tile_m_row = str(doc.get("tile_m_row", ""))
    c.declared_n = int(doc.get("n_centres", -1))

    var crs := str(doc.get("crs", ""))
    if crs != CRS:
        c.problems.append(("the centres declare crs %s, not %s. A digest says what bytes "
                + "ARE and not what they MEAN: another projection would misplace every tile "
                + "by kilometres with every digest still agreeing.") % [crs, CRS])

    var lat := str(doc.get("lattice_sha256", ""))
    if lat == "":
        c.problems.append("the centres name no lattice_sha256, so nothing binds them to the "
                + "lattice the dressing was built on")
    elif manifest_lattice == "":
        c.problems.append("the manifest names no lattice, so the centres cannot be bound; "
                + "refusing rather than drawing them unbound")
    elif lat != manifest_lattice:
        c.problems.append(("the centres were computed on lattice %s and the dressing names "
                + "%s; every tile would be placed at another basin's coordinates and look "
                + "plausible") % [lat, manifest_lattice])

    var dr := str(doc.get("dressing_sha256", ""))
    if dr == "" or dressing_identity == "":
        c.problems.append("the centres or the dressing carry no identity to bind them")
    elif dr != dressing_identity:
        c.problems.append(("the centres are for dressing %s and the bytes on disk "
                + "compute to %s") % [dr, dressing_identity])

    if c.declared_n != c.centres.size():
        c.problems.append(("the centres declare n_centres %d and carry %d entries; a "
                + "truncated file would otherwise draw a smaller city with no error")
                % [c.declared_n, c.centres.size()])

    if not (c.tile_m > 0.0):
        c.problems.append("the centres declare tile_m %s; a tile has no size"
                % str(c.tile_m))
    return c


func is_present() -> bool:
    return state == PRESENT


func is_bound() -> bool:
    return state == PRESENT and problems.is_empty()


func has_centre(tile_key: String) -> bool:
    return centres.has(tile_key)


## One tile's centre in EPSG:5070 metres, as a float64 pair. NOT a `Vector2`:
## see the header. An unknown key returns an empty array, which a caller must
## treat as a refusal rather than as the origin.
func centre_of(tile_key: String) -> PackedFloat64Array:
    var out := PackedFloat64Array()
    if not centres.has(tile_key):
        return out
    var xy: Array = centres[tile_key]
    out.append(float(xy[0]))
    out.append(float(xy[1]))
    return out


## A tile's centre relative to a scene origin given in the SAME metres.
##
## THE ONE PLACE float64 NARROWS TO float32, and it happens AFTER the
## subtraction. `centre - origin` is a small local offset -- hundreds or
## thousands of metres across a city -- which a float32 holds to well under a
## millimetre. Narrowing BEFORE the subtraction would discard about 0.125 m of
## the absolute coordinate first, and no later arithmetic could recover it.
func local_of(tile_key: String, origin_x: float, origin_y: float) -> Vector2:
    var c := centre_of(tile_key)
    if c.is_empty():
        return Vector2.ZERO
    return Vector2(float(c[0] - origin_x), float(c[1] - origin_y))


## Every tile in `tile_keys` that this file has no centre for.
##
## THE CALLER MUST REFUSE THE DRAW ON A NON-EMPTY RESULT, and the names are
## returned rather than a count so the refusal can say which tiles. A count
## alone turns a specific, findable defect into a number nobody can act on.
func missing(tile_keys: Array) -> PackedStringArray:
    var out := PackedStringArray()
    for k in tile_keys:
        if not centres.has(str(k)):
            out.append(str(k))
    return out
