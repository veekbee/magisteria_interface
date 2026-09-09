class_name TerrainLayers
extends RefCounted

## The three derived terrain layers -- slope, aspect, distance-to-channel --
## on the height pyramid's own grid.
##
## SAME GRID, AND THE PRODUCER READS THE HEIGHT EXPORT TO GET IT. Same origin,
## same `tile_px`, same z-polarity, same per-level tile counts, identical key
## sets. A layer tile half a pixel off the height tile beneath it is a
## misalignment nothing reports, because both look like data -- so the grid
## arithmetic here is `TilePyramid.on_grid`, shared rather than reimplemented.
##
## THEY ARE NOT THE GEOTIFFS THEY CAME FROM, and three things about those files
## would each have been a silent defect:
##
##   * `slope_100m.tif` and its siblings are named `_100m` and are NOT 100 m.
##     Their pixel is 92.6185 x 82.7865 m, non-square. These are reprojected
##     onto this grid rather than relabelled.
##   * `aspect_100m.tif` DECLARES NO NODATA AND FILLS WITH 0.0, which is a
##     legal aspect. 52.19% of its grid is exactly 0.0 and 99.04% of that is
##     where slope has nothing. A consumer trusting the file draws a basin
##     facing north.
##   * `distance_to_channel_100m.tif` is finite everywhere, because a distance
##     transform fills its raster. Outside the basin its median is 115.3 km
##     against 6.8 km inside, so the mask is doing real work rather than
##     tidying.
##
## ASPECT SHIPS AS SIN/COS AND NEVER AS AN ANGLE, for two independent reasons
## either of which is sufficient. An angle is CIRCULAR: 359.9 and 0.1 degrees
## are neighbours on the ground and opposite ends of a linear code, so anything
## that interpolates -- and this project interpolates everywhere -- reads due
## SOUTH across north. And an angle channel cannot say *no aspect here* without
## spending a real direction on it.
##
## SO B IS READ BEFORE THE COMPONENTS, AND THIS CLASS MAKES THAT STRUCTURAL
## RATHER THAN REMEMBERED. Where B is 0 or 128 the components are zeroed, and
## zeroed components decode through `atan2(-128/127, -128/127)` to 225 degrees
## -- a perfectly plausible south-west. That is the one reading that would look
## right and be meaningless, so there is no method here that returns an azimuth
## without having consulted B: `aspect_at` returns a STATE and a number, and
## the number is NAN in two of the three states.
##
## THREE STATES, BECAUSE THE FIELD HAS THREE. Flat ground is in the basin and
## has no aspect -- 704,980 px, 0.98% of valid ground. Folding it into `no
## data` would say the basin has a hole where it has a plateau.
##
## COARSE LEVELS AVERAGE THE COMPONENTS, NEVER THE ANGLE (convention 7), so
## z >= 1 is safe to sample: averaging angles across a 2x2 straddling north is
## the same circular error one aggregation up.
##
## THE MASK IS NEVER WIDER THAN THE DEM'S. A layer never claims ground the
## client is not drawing, so a consumer can key on a layer without first asking
## whether terrain exists under it. NARROWER is real and per layer: slope has
## no value on 136,865 of the pyramid's 71,826,193 ground pixels -- 0.19%,
## about 1,369 km2 -- because a gradient needs neighbours and loses a one-pixel
## rim at every nodata boundary. That is a SECOND, independent population where
## a patch has a layer hole while the ground is drawn, and it does not coincide
## with the height nodata.

const PIN_PATH := "res://assets/terrain/layers/PIN"
const DIR := "res://assets/terrain/layers/"

const SLOPE := "slope"
const ASPECT := "aspect"
const DISTANCE := "distance_to_channel"

## Aspect's third state. The other two reuse `TilePyramid`'s absence names,
## because "no tile was ever written here" means the same thing about the same
## grid and a second vocabulary for it would be a second thing to keep in step.
const NO_DATA := "NO_DATA"
const FLAT := "FLAT"
const VALID := "VALID"

## Twelve, because a near-field patch touches up to four tiles and there are
## three layers. Each decoded tile is three 512x512 byte planes, 786 KB.
const CACHE_TILES := 12

var layers: Dictionary = {}          ## name -> {encoding_kind, stats, levels}
var origin_x: float = 0.0
var origin_y: float = 0.0
var keys: Dictionary = {}            ## "<layer>/<z>/<x>_<y>.png" -> true
var host_base: String = ""
var why_absent: String = ""

var _cache: Dictionary = {}          ## key -> {"r":.., "g":.., "b":..}
var _order: Array = []


## Read the pin. The pin is the manifest; nothing here walks a directory,
## because a walk answers "what is on this disk" and the question is "what did
## the producing run write".
static func load_from(pin_path: String = PIN_PATH) -> TerrainLayers:
    var tl := TerrainLayers.new()
    if not FileAccess.file_exists(pin_path):
        tl.why_absent = ("no layer pin at %s. The layers are fetched, not committed "
                + "(decision 948); run tools/vendor_layers.py against a host to write one.")\
                % pin_path
        return tl
    var f := FileAccess.open(pin_path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        tl.why_absent = "%s is not a JSON object" % pin_path
        return tl
    var pin: Dictionary = parsed
    var grid: Dictionary = pin.get("grid", {})
    var o: Array = grid.get("origin", [])
    if o.size() >= 2:
        tl.origin_x = float(o[0])
        tl.origin_y = float(o[1])
    tl.layers = pin.get("layers", {})
    for k in pin.get("files", {}):
        tl.keys[str(k)] = true
    tl.host_base = str((pin.get("fetched", {}) as Dictionary).get("host_base", ""))
    if tl.layers.is_empty() or tl.keys.is_empty():
        tl.why_absent = "%s names no layers or no files" % pin_path
    return tl


func is_loaded() -> bool:
    return not layers.is_empty() and not keys.is_empty()


func names() -> PackedStringArray:
    var out := PackedStringArray()
    for k in layers:
        out.append(str(k))
    out.sort()
    return out


func has(layer: String) -> bool:
    return layers.has(layer)


## The pixel size of one layer's level, metres. NAN where either is absent.
func pixel_size_of(layer: String, z: int = 0) -> float:
    for lv in (layers.get(layer, {}) as Dictionary).get("levels", []):
        if int((lv as Dictionary)["z"]) == z:
            return float((lv as Dictionary)["pixel_size_m"])
    return NAN


## Which tile and texel a world position falls in, for one layer's level.
func locate(layer: String, wx: float, wy: float, z: int = 0) -> Dictionary:
    var px_m := pixel_size_of(layer, z)
    if is_nan(px_m):
        return {"ok": false, "why": "no level %d of %s" % [z, layer]}
    var at := TilePyramid.on_grid(origin_x, origin_y, px_m, wx, wy)
    if not bool(at["ok"]):
        return at
    var tile: Vector2i = at["tile"]
    at["z"] = z
    at["layer"] = layer
    at["key"] = "%s/%d/%d_%d.png" % [layer, z, tile.x, tile.y]
    return at


## Which of the three absences -- or PRESENT -- applies to one key. The same
## three the pyramid has and for the same reasons: unkeyed is ground that was
## never written, keyed-and-absent is a fetch that has not happened.
func availability(key: String) -> String:
    if not keys.has(key):
        return TilePyramid.EMPTY_GROUND
    return TilePyramid.PRESENT if FileAccess.file_exists(DIR + key) else TilePyramid.NOT_FETCHED


## A SCALAR LAYER'S VALUE AT A WORLD POSITION, in the layer's own unit.
##
## `min + (R * 256 + G) * (max - min) / 65535, where B > 0` -- the encoding is
## read from the layer's own block, never shared between layers. Slope and
## distance-to-channel have ranges three orders of magnitude apart and one pair
## of constants applied to the other's bytes would be wrong by that much, with
## nothing to report it.
##
## REFUSES `aspect` RATHER THAN DECODING IT. Aspect is not a scalar and this
## method's arithmetic is exactly the misreading the direction pair exists to
## prevent, so it is a refusal and not an omission.
func value_at(layer: String, wx: float, wy: float, z: int = 0) -> float:
    if layer == ASPECT:
        push_error("terrain layers: aspect is a direction pair, not a scalar. Ask "
                + "`aspect_at`, which reads the validity byte before the components.")
        return NAN
    var block: Dictionary = layers.get(layer, {})
    if block.is_empty():
        return NAN
    var stats: Dictionary = block.get("stats", {})
    var lo := float(stats.get("min", NAN))
    var hi := float(stats.get("max", NAN))
    if is_nan(lo) or is_nan(hi) or hi <= lo:
        return NAN
    var at := locate(layer, wx, wy, z)
    if not bool(at["ok"]):
        return NAN
    var tile := _tile(str(at["key"]))
    if tile.is_empty():
        return NAN
    var inside: Vector2i = at["in_tile"]
    var i := inside.y * TilePyramid.TILE_PX + inside.x
    var b: PackedByteArray = tile["b"]
    if i < 0 or i >= b.size() or b[i] == 0:
        return NAN
    var r: PackedByteArray = tile["r"]
    var g: PackedByteArray = tile["g"]
    return lo + float(int(r[i]) * 256 + int(g[i])) * (hi - lo) / 65535.0


## ASPECT, AS A STATE AND A NUMBER, and the number is NAN unless the state is
## VALID.
##
## THE VALIDITY BYTE IS CONSULTED BEFORE THE COMPONENTS ARE TOUCHED, and this
## signature is what makes that structural. A method returning a bare float
## could be called and used; a caller of this one has a state in hand and has
## to decide what to do with FLAT before it can reach a direction.
##
## Zeroed components decode to 225 degrees -- a plausible south-west -- so the
## failure this prevents is not a crash or a NAN. It is a wrong answer that
## looks like a right one over half the grid.
func aspect_at(wx: float, wy: float, z: int = 0) -> Dictionary:
    var at := locate(ASPECT, wx, wy, z)
    if not bool(at["ok"]):
        return {"state": NO_DATA, "azimuth_deg": NAN,
                "why": str(at.get("why", "off grid"))}
    var tile := _tile(str(at["key"]))
    if tile.is_empty():
        return {"state": NO_DATA, "azimuth_deg": NAN,
                "why": availability(str(at["key"]))}
    var inside: Vector2i = at["in_tile"]
    var i := inside.y * TilePyramid.TILE_PX + inside.x
    var b: PackedByteArray = tile["b"]
    if i < 0 or i >= b.size():
        return {"state": NO_DATA, "azimuth_deg": NAN, "why": "outside the tile"}
    # THE THREE STATES, IN THIS ORDER. Anything that is not 255 leaves without
    # the components having been read at all.
    if b[i] == 0:
        return {"state": NO_DATA, "azimuth_deg": NAN,
                "why": "outside the basin, or the layer has no value here"}
    if b[i] != 255:
        return {"state": FLAT, "azimuth_deg": NAN,
                "why": ("in the basin and the cell is flat, so aspect is undefined rather "
                        + "than absent. 0.98% of valid ground.")}
    var r: PackedByteArray = tile["r"]
    var g: PackedByteArray = tile["g"]
    var s := (float(r[i]) - 128.0) / 127.0
    var c := (float(g[i]) - 128.0) / 127.0
    # `v * 127 + 128` rather than `(v + 1) * 127.5`: the obvious scale puts zero
    # at an unrepresentable code, so due north decoded 0.2247 degrees off --
    # and north is what the source's undeclared nodata fill produces, so it is
    # the direction most likely to be met and misread. Centring on an integer
    # makes all four cardinals exact and measures slightly better overall.
    return {"state": VALID, "azimuth_deg": rad_to_deg(atan2(s, c)), "why": ""}


## Convenience readers, named in the unit they return so a call site cannot be
## read as asking for the other one.
func slope_degrees_at(wx: float, wy: float, z: int = 0) -> float:
    return value_at(SLOPE, wx, wy, z)


func distance_to_channel_m(wx: float, wy: float, z: int = 0) -> float:
    return value_at(DISTANCE, wx, wy, z)


## A decoded tile's three raw channels. Empty dictionary for every absence.
##
## RAW, AND DECODED AT THE POINT OF USE. The pyramid pre-combines R and G into
## a code because there is one encoding; here there are two, and a cache
## holding half-decoded bytes under one of them is a cache the other layer
## would read wrong.
func _tile(key: String) -> Dictionary:
    if _cache.has(key):
        return _cache[key]
    if availability(key) != TilePyramid.PRESENT:
        return {}
    var f := FileAccess.open(DIR + key, FileAccess.READ)
    if f == null:
        return {}
    var img := Image.new()
    if img.load_png_from_buffer(f.get_buffer(f.get_length())) != OK:
        return {}
    var w := img.get_width()
    var h := img.get_height()
    var r := PackedByteArray()
    var g := PackedByteArray()
    var b := PackedByteArray()
    r.resize(w * h)
    g.resize(w * h)
    b.resize(w * h)
    for y in h:
        for x in w:
            var px := img.get_pixel(x, y)
            var i := y * w + x
            r[i] = int(round(px.r * 255.0))
            g[i] = int(round(px.g * 255.0))
            b[i] = int(round(px.b * 255.0))
    var out := {"r": r, "g": g, "b": b, "width": w, "height": h}
    _cache[key] = out
    _order.append(key)
    while _order.size() > CACHE_TILES:
        var drop: String = _order.pop_front()
        _cache.erase(drop)
    return out


## What the pin holds and what this clone has of it, per layer.
func inventory() -> Dictionary:
    var per := {}
    for name in names():
        per[name] = {"keyed": 0, "present": 0}
    var keyed := 0
    var present := 0
    for k in keys:
        var name := str(k).split("/")[0]
        if not per.has(name):
            per[name] = {"keyed": 0, "present": 0}
        var row: Dictionary = per[name]
        row["keyed"] = int(row["keyed"]) + 1
        keyed += 1
        if FileAccess.file_exists(DIR + str(k)):
            row["present"] = int(row["present"]) + 1
            present += 1
        per[name] = row
    return {
        "keyed": keyed,
        "present": present,
        "not_fetched": keyed - present,
        "layers": per,
        "host_base_set": host_base != "",
    }
