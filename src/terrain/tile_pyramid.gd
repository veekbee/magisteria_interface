class_name TilePyramid
extends RefCounted

## The terrain export's tile pyramid: the drawn substrate at native resolution.
##
## SIX LEVELS, 100 m TO 3200 m, AND `z = 0` IS THE FINEST. That is inverted
## from the web-map convention where zero is the whole world in one tile, and
## getting it backwards loads the coarsest tiles into the near field -- which
## looks exactly like the blocker the pyramid exists to remove, so it would be
## read as the pyramid not working rather than as being read upside down. The
## levels are READ from the pin, never assumed.
##
## THE TILES DO NOT DECODE WITH THE OVERVIEW'S CONSTANTS, and this is the one
## mistake here that is silent. Both grids resample with `average`, which pulls
## extremes in by an amount that depends on pixel footprint; the native grid
## measures about 53 m higher at the top. Decode a tile with the overview's
## `offset_m` / `scale_m_per_step` and the basin's real peaks are clipped, with
## nothing to report it, because a clipped code is a valid code. So the
## encoding comes from the TILES' own pin and this class refuses to run without
## it rather than falling back on the pair it can see.
##
## READ AS PNG BYTES, NOT AS A RESOURCE. `assets/terrain/tiles/` carries a
## `.gdignore`, so the engine never scans or imports these files -- which is
## deliberate twice over. They are fetched artefacts and absent in a fresh
## clone, so an importer would have nothing to import; and the overview needed
## a hand-kept `.import` to stop VRAM compression corrupting height that is
## encoded IN the RGB bytes. Decoding the PNG in memory sidesteps the import
## pipeline entirely, so there is no setting anyone can get wrong.
##
## THREE ABSENCES, and §5.1a's distinction is the whole reason the pin lists
## keys at all:
##
##   EMPTY_GROUND -- no tile was ever written here. 254 of 600 at z=0 are
##                   entirely nodata and the emitter skips them, so this is
##                   measured absence and the correct answer is NAN.
##   NOT_FETCHED  -- the pin keys it and the file is not on disk. A working
##                   clone, and the checks that need it must say so rather
##                   than read it as empty ground.
##   PRESENT      -- it is here and it decoded.

const PIN_PATH := "res://assets/terrain/tiles/PIN"
const DIR := "res://assets/terrain/tiles/"
const TILE_PX := 512

const EMPTY_GROUND := "EMPTY_GROUND"
const NOT_FETCHED := "NOT_FETCHED"
const PRESENT := "PRESENT"

## How many decoded tiles to hold. Each is a 512x512 code plane plus its
## validity mask, about 1.3 MB, and a walk crosses a handful.
const CACHE_TILES := 8

var levels: Array = []               ## [{z, pixel_size_m, tiles_x, tiles_y, written}]
var origin: Vector2 = Vector2.ZERO   ## world position of the grid's top-left CORNER
var offset_m: float = 0.0
var scale_m: float = 0.0
var keys: Dictionary = {}            ## "z/x_y.png" -> true, from the pin
var host_base: String = ""
var why_absent: String = ""

var _cache: Dictionary = {}          ## key -> {"codes":.., "valid":..}
var _order: Array = []


## Read the pin. The pin is the manifest; nothing here walks a directory,
## because a walk answers "what is on this disk" and the question is "what did
## the producing run write" -- and telling those apart is what makes a missing
## tile a missing tile rather than empty ground.
static func load_from(pin_path: String = PIN_PATH) -> TilePyramid:
    var tp := TilePyramid.new()
    if not FileAccess.file_exists(pin_path):
        tp.why_absent = ("no tile pin at %s. The pyramid is fetched, not committed "
                + "(decision 948); run tools/vendor_tiles.py against a host to write one.")\
                % pin_path
        return tp
    var f := FileAccess.open(pin_path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        tp.why_absent = "%s is not a JSON object" % pin_path
        return tp
    var pin: Dictionary = parsed
    var grid: Dictionary = pin.get("grid", {})
    tp.levels = grid.get("levels", [])
    var o: Array = grid.get("origin", [])
    if o.size() >= 2:
        tp.origin = Vector2(float(o[0]), float(o[1]))
    var enc: Dictionary = pin.get("encoding", {})
    tp.offset_m = float(enc.get("offset_m", NAN))
    tp.scale_m = float(enc.get("scale_m_per_step", NAN))
    if is_nan(tp.offset_m) or is_nan(tp.scale_m) or tp.scale_m <= 0.0:
        tp.why_absent = ("the tile pin carries no encoding. These do not decode with the "
                + "overview's constants and this class will not guess at them: a wrong pair "
                + "clips the real peaks silently.")
        return tp
    for k in pin.get("files", {}):
        tp.keys[str(k)] = true
    tp.host_base = str((pin.get("fetched", {}) as Dictionary).get("host_base", ""))
    return tp


func is_loaded() -> bool:
    return not levels.is_empty() and not keys.is_empty() and scale_m > 0.0


## The pixel size of one level, in metres. NAN for a level that does not exist.
func pixel_size_of(z: int) -> float:
    for lv in levels:
        if int((lv as Dictionary)["z"]) == z:
            return float((lv as Dictionary)["pixel_size_m"])
    return NAN


func finest_pixel_size_m() -> float:
    return pixel_size_of(0)


## Which tile a world position falls in at level `z`, and where inside it.
##
## The texel coordinate names a CENTRE, the same convention `Heightfield` uses,
## so the two grids agree about what "the height at this point" means and a
## comparison between them is a comparison of the data rather than of two
## offsets by half a pixel.
func locate(wx: float, wy: float, z: int = 0) -> Dictionary:
    var px_m := pixel_size_of(z)
    if is_nan(px_m):
        return {"ok": false, "why": "no level %d" % z}
    var fx := (wx - origin.x) / px_m - 0.5
    var fy := (origin.y - wy) / px_m - 0.5
    var ix := int(round(fx))
    var iy := int(round(fy))
    if ix < 0 or iy < 0:
        return {"ok": false, "why": "outside the grid"}
    var tx := ix / TILE_PX
    var ty := iy / TILE_PX
    return {"ok": true, "z": z, "tile": Vector2i(tx, ty),
            "in_tile": Vector2i(ix - tx * TILE_PX, iy - ty * TILE_PX),
            "texel": Vector2i(ix, iy),
            "key": "%d/%d_%d.png" % [z, tx, ty], "pixel_size_m": px_m}


## Which of the three absences -- or PRESENT -- applies to one key.
func availability(key: String) -> String:
    if not keys.has(key):
        return EMPTY_GROUND
    return PRESENT if FileAccess.file_exists(DIR + key) else NOT_FETCHED


## Height in metres at a world position, from the level's own texel. NAN where
## there is no ground, no tile, or no fetch -- `availability` is how a caller
## tells those apart, and it must, because two of them are facts about the
## basin and one is a fact about this clone.
##
## NEAREST TEXEL, NOT BICUBIC, and the reason is a real limit rather than a
## shortcut: sixteen taps at a tile's edge reach into the neighbouring tile,
## and deciding when to hold four tiles open is the streaming question that
## consuming this pyramid has to answer. Measuring what it contains does not
## need it, and pretending otherwise would put a smoothing decision inside a
## measurement.
func height_at_world(wx: float, wy: float, z: int = 0) -> float:
    var at := locate(wx, wy, z)
    if not bool(at["ok"]):
        return NAN
    var tile := _tile(str(at["key"]))
    if tile.is_empty():
        return NAN
    var inside: Vector2i = at["in_tile"]
    var i := inside.y * TILE_PX + inside.x
    var valid: PackedByteArray = tile["valid"]
    if i < 0 or i >= valid.size() or valid[i] == 0:
        return NAN
    var codes: PackedFloat32Array = tile["codes"]
    return offset_m + float(codes[i]) * scale_m


## A decoded tile, cached. Empty dictionary for every absence.
func _tile(key: String) -> Dictionary:
    if _cache.has(key):
        return _cache[key]
    if availability(key) != PRESENT:
        return {}
    var f := FileAccess.open(DIR + key, FileAccess.READ)
    if f == null:
        return {}
    var img := Image.new()
    if img.load_png_from_buffer(f.get_buffer(f.get_length())) != OK:
        return {}
    var w := img.get_width()
    var h := img.get_height()
    var codes := PackedFloat32Array()
    var valid := PackedByteArray()
    codes.resize(w * h)
    valid.resize(w * h)
    for y in h:
        for x in w:
            var c := img.get_pixel(x, y)
            var i := y * w + x
            codes[i] = float(int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0)))
            valid[i] = 1 if c.b > 0.5 else 0
    var out := {"codes": codes, "valid": valid, "width": w, "height": h}
    _cache[key] = out
    _order.append(key)
    while _order.size() > CACHE_TILES:
        var drop: String = _order.pop_front()
        _cache.erase(drop)
    return out


## What the pyramid holds and what this clone has of it. For a report that has
## to say whether a number came from data or from an absence.
func inventory() -> Dictionary:
    var present := 0
    for k in keys:
        if FileAccess.file_exists(DIR + str(k)):
            present += 1
    return {
        "keyed": keys.size(),
        "present": present,
        "not_fetched": keys.size() - present,
        "levels": levels.size(),
        "finest_pixel_size_m": finest_pixel_size_m(),
        "host_base_set": host_base != "",
    }
