class_name ExplorerView
extends Node2D

## THE EXPLORER'S VIEW — G-9 W3, and the surface owner ruling 2130 Q2 asks the
## owner to rule on: DA-6's compact dressing drawn with its pins, folded to any
## year in [1877, 2039], at the four declared years at least.
##
## EVERYTHING DRAWN HERE COMES FROM A FETCHED, PINNED ARTEFACT. The tiles and
## their classes come from the dressing through `DressingFold`; the colours from
## the committed `palette.json`; the positions from §25 backlog 732's
## `centres.json`; the pins from the committed pin file. **No second fold, no
## retyped palette, no invented geometry** (the dispatch's words, and decision
## 2129 (b), (f)). The one display constant this file's drawing layer copies is
## named in `DressingDraw`'s header with the drift it risks.
##
## ⚠ A REFUSAL IS SHOWN ON SCREEN AND NOT ONLY LOGGED. If a binding fails or a
## tile has no centre, this draws the reason in words instead of drawing a city.
## The owner is being asked to rule on what they see; a view that quietly
## omitted a piece, or drew a partial city because a file was short, would be
## asking them to rule on something nobody had verified. A blank screen with a
## sentence on it is a worse demonstration and a better instrument.
##
## ⚠ WORLD COORDINATES STAY float64 UNTIL THE SUBTRACTION. EPSG:5070 metres do
## not fit a float32 without losing about 0.125 m (`Vector2` is float32), so the
## origin is subtracted in float64 and only the small local offset becomes a
## `Vector2`. `DressingCentres.local_of` is the single place that narrows. This
## is the same trap that produced a real defect in this window's `edit_list`.
##
## NOTHING IS PLACED AND NOTHING IS WRITTEN. Moving a pin builds an edit list in
## memory; emitting goes through the Python emitter and the placement is the
## simulation's, not this repo's (decision 2075's rejection, G-8).

const LO := 1877
const HI := 2039
const DECLARED := [1890, 1940, 1990, 2039]

var _load: DressingLoad
var _centres: DressingCentres
var _pins: DressingPins
var _palette: Dictionary = {}
var _tiles: Array = []
var _features: Array = []
var _routes: Array = []

var _year: int = 1890
var _refusal: String = ""
var _unknown_classes: Dictionary = {}

## World origin in EPSG:5070 metres, float64, subtracted before any Vector2.
var _ox: float = 0.0
var _oy: float = 0.0
var _scale: float = 1.0

## pin_id -> Array of [x, y] float64, as moved by the owner. Empty until a drag.
var _moved: Dictionary = {}
var _dragging: String = ""


func _ready() -> void:
    _load = DressingLoad.load_from()
    if not _load.is_present():
        _refusal = "The dressing is not fetched.\n\n%s" % _load.why_absent
        return
    if not _load.identity_holds():
        _refusal = "The dressing failed its identity:\n\n%s" % "\n".join(
                PackedStringArray(_load.identity_problems))
        return
    _centres = DressingCentres.load_from(_lattice_of_manifest(),
            _load.computed_dressing_sha256)
    if not _centres.is_present():
        _refusal = "The tile centres are not fetched.\n\n%s" % _centres.why_absent
        return
    if not _centres.is_bound():
        _refusal = "The tile centres are not this dressing's:\n\n%s" % "\n".join(
                PackedStringArray(_centres.problems))
        return
    _pins = DressingPins.load_from(_load.pins_digest())
    if _pins.is_present() and not _pins.is_bound():
        _refusal = "The pin file is not this dressing's:\n\n%s" % "\n".join(
                PackedStringArray(_pins.problems))
        return
    var pal = JSON.parse_string(FileAccess.get_file_as_string(
            DressingCentres.DIR + "palette.json"))
    if typeof(pal) != TYPE_DICTIONARY:
        _refusal = "palette.json did not parse; the colours are not this build's to invent."
        return
    _palette = pal
    _tiles = DressingFold.read_rows(DressingFold.DIR + "tiles.jsonl")
    _features = DressingFold.read_rows(DressingFold.DIR + "features.jsonl")
    _routes = DressingFold.read_rows(DressingFold.DIR + "routes.jsonl")
    set_year(_year)


func _lattice_of_manifest() -> String:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(
            DressingLoad.DIR + "manifest.json"))
    if typeof(parsed) != TYPE_DICTIONARY:
        return ""
    return str((parsed as Dictionary).get("lattice", ""))


## The eras and their first years, for the slider's ticks. A year carrying two
## eras names both (see `DressingLoad.era_ticks`).
func era_ticks() -> Array:
    if _load == null:
        return []
    return DressingLoad.era_ticks(_load.era_starts(), LO, HI)


func set_year(y: int) -> void:
    _year = clampi(y, LO, HI)
    if _refusal != "":
        return
    var fold := DressingFold.fold(_tiles, _year)
    # ⚠ THE REFUSAL, BEFORE ANYTHING IS DRAWN. A tile the centres do not place
    # is not skipped: a city drawn with pieces silently missing is exactly what
    # the owner cannot detect by looking, which is the one thing they are here
    # to do.
    var missing := _centres.missing(fold.keys())
    if not missing.is_empty():
        _refusal = ("%d of %d tiles at %d have no centre in centres.json, so this "
                + "view refuses to draw rather than show a city with pieces "
                + "missing.\n\nFirst: %s")\
                % [missing.size(), fold.size(), _year,
                ", ".join(missing.slice(0, mini(5, missing.size())))]
        queue_redraw()
        return
    _fit(fold)
    queue_redraw()


## Fit the year's extent to the viewport, in float64 before any narrowing.
func _fit(fold: Dictionary) -> void:
    var minx := INF
    var maxx := -INF
    var miny := INF
    var maxy := -INF
    for key in fold:
        var c := _centres.centre_of(str(key))
        if c.is_empty():
            continue
        minx = minf(minx, c[0])
        maxx = maxf(maxx, c[0])
        miny = minf(miny, c[1])
        maxy = maxf(maxy, c[1])
    if minx == INF:
        return
    var pad := _centres.tile_m
    _ox = (minx + maxx) * 0.5
    _oy = (miny + maxy) * 0.5
    var w := (maxx - minx) + pad * 2.0
    var h := (maxy - miny) + pad * 2.0
    var vp := get_viewport_rect().size
    _scale = minf(vp.x / maxf(w, 1.0), (vp.y - 80.0) / maxf(h, 1.0))


## World metres to screen. The subtraction is float64; only the result narrows.
func _to_screen(x: float, y: float) -> Vector2:
    var vp := get_viewport_rect().size
    # y is inverted: EPSG:5070 northing rises, screen y falls.
    return Vector2(float((x - _ox) * _scale) + vp.x * 0.5,
            float((_oy - y) * _scale) + (vp.y - 40.0) * 0.5)


func _draw() -> void:
    var vp := get_viewport_rect().size
    if _refusal != "":
        draw_rect(Rect2(Vector2.ZERO, vp), Color(0.1, 0.1, 0.12))
        _text(Vector2(28, 56), _refusal, Color(1, 0.85, 0.3))
        return
    draw_rect(Rect2(Vector2.ZERO, vp), DressingDraw.background_color(_palette))
    var fold := DressingFold.fold(_tiles, _year)
    var side := maxf(_centres.tile_m * _scale, 1.0)

    _unknown_classes.clear()
    for row: Dictionary in DressingDraw.tile_rows(fold, _palette,
            float(_palette.get("density_ref", 1.0)), _unknown_classes):
        var c := _centres.centre_of(str(row["key"]))
        var p := _to_screen(c[0], c[1])
        draw_rect(Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)), row["color"])

    var edge := DressingDraw.edge_color(_palette)
    for f: Dictionary in DressingFold.features_at(_features, _year):
        var keys: Array = []
        for t in f.get("tiles", []):
            keys.append(DressingFold.tile_key(t))
        for k in DressingDraw.outline_keys(keys, _centres):
            var c := _centres.centre_of(str(k))
            var p := _to_screen(c[0], c[1])
            draw_rect(Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)), edge, false,
                    maxf(side * 0.18, 1.0))

    for r: Dictionary in DressingFold.routes_at(_routes, _year):
        var pts := PackedVector2Array()
        for v in r.get("geometry", []):
            var xy: Array = v
            pts.append(_to_screen(float(xy[0]), float(xy[1])))
        if pts.size() >= 2:
            draw_polyline(pts, DressingDraw.route_color(_palette, str(r.get("class", ""))),
                    maxf(side * 0.4, 1.0))

    if _pins != null and _pins.is_present():
        for pin: Dictionary in _pins.at(_year):
            _draw_pin(pin, edge, side)
    _chrome(vp)


func _draw_pin(pin: Dictionary, edge: Color, side: float) -> void:
    var pid := str(pin.get("pin_id", ""))
    var verts: Array = _moved[pid] if _moved.has(pid) else pin.get("polygon", [])
    if verts.is_empty():
        # NAMED, NOT SKIPPED: a kind whose geometry this build cannot draw is
        # reported on screen rather than quietly absent.
        _text(Vector2(28, get_viewport_rect().size.y - 92),
                "pin %s (kind %s) has no polygon this build can draw"
                        % [pid, str(pin.get("kind", "?"))], Color(1, 0.85, 0.3))
        return
    var pts := PackedVector2Array()
    for v in verts:
        var xy: Array = v
        pts.append(_to_screen(float(xy[0]), float(xy[1])))
    pts.append(pts[0])
    draw_polyline(pts, edge, maxf(side * 0.5, 2.0))
    _text(pts[0] + Vector2(6, -8), "%s  %s" % [str(pin.get("kind", "?")), pid], edge)


func _chrome(vp: Vector2) -> void:
    var edge := DressingDraw.edge_color(_palette)
    _text(Vector2(20, 24), "DA-6 compact   %d" % _year, edge)
    var y := vp.y - 30.0
    draw_line(Vector2(20, y), Vector2(vp.x - 20, y), edge, 1.0)
    var span := float(HI - LO)
    for t: Dictionary in era_ticks():
        var fx := 20.0 + (vp.x - 40.0) * (float(int(t["year"]) - LO) / span)
        draw_line(Vector2(fx, y - 7), Vector2(fx, y + 7), edge, 1.0)
        _text(Vector2(fx - 10, y + 24), "%d %s" % [int(t["year"]),
                " ".join(t["eras"] as PackedStringArray)], edge)
    var hx := 20.0 + (vp.x - 40.0) * (float(_year - LO) / span)
    draw_line(Vector2(hx, y - 12), Vector2(hx, y + 12), Color(0.85, 0.2, 0.2), 2.0)
    if not _unknown_classes.is_empty():
        _text(Vector2(20, 44), "classes the palette does not name: %s"
                % ", ".join(PackedStringArray(_unknown_classes.keys())),
                Color(0.8, 0.1, 0.6))


func _text(at: Vector2, s: String, col: Color) -> void:
    var f := ThemeDB.fallback_font
    var line := 0
    for part in s.split("\n"):
        draw_string(f, at + Vector2(0, line * 20), str(part), HORIZONTAL_ALIGNMENT_LEFT,
                -1, 14, col)
        line += 1


## World metres under a screen point. The inverse of `_to_screen`, done in
## float64 so a drag lands where the owner pointed rather than 0.125 m away.
func _to_world(p: Vector2) -> PackedFloat64Array:
    var vp := get_viewport_rect().size
    var out := PackedFloat64Array()
    out.append(float(p.x - vp.x * 0.5) / _scale + _ox)
    out.append(_oy - float(p.y - (vp.y - 40.0) * 0.5) / _scale)
    return out


## Which pin's polygon contains a screen point, or "".
func _pin_at(p: Vector2) -> String:
    if _pins == null or not _pins.is_present():
        return ""
    for pin: Dictionary in _pins.at(_year):
        var pid := str(pin.get("pin_id", ""))
        var verts: Array = _moved[pid] if _moved.has(pid) else pin.get("polygon", [])
        if verts.is_empty():
            continue
        var poly := PackedVector2Array()
        for v in verts:
            var xy: Array = v
            poly.append(_to_screen(float(xy[0]), float(xy[1])))
        if Geometry2D.is_point_in_polygon(p, poly):
            return pid
    return ""


## The edit list for everything the owner moved, as float64 bit patterns.
##
## EMPTY UNTIL A DRAG, and that is the point: a pin nobody touched must not
## appear here at all, so the emitter re-emits its numbers from the author's own
## characters rather than from anything this engine parsed (G-8's finding).
func edit_list() -> Dictionary:
    return DressingPins.edit_list(_moved)


func _unhandled_input(e: InputEvent) -> void:
    if _refusal != "":
        return
    if e is InputEventMouseButton:
        var mb := e as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                _dragging = _pin_at(mb.position)
            else:
                _dragging = ""
            return
    if e is InputEventMouseMotion and _dragging != "":
        var mm := e as InputEventMouseMotion
        # THE OFFSET IS COMPUTED IN float64 METRES, not from the screen delta
        # scaled afterwards: two world points subtracted keep their precision,
        # where a float32 screen delta divided by the scale would not.
        var a := _to_world(mm.position - mm.relative)
        var b := _to_world(mm.position)
        var dx := b[0] - a[0]
        var dy := b[1] - a[1]
        var base: Array = _moved[_dragging] if _moved.has(_dragging) \
                else _polygon_of(_dragging)
        var out: Array = []
        for v in base:
            var xy: Array = v
            out.append([float(xy[0]) + dx, float(xy[1]) + dy])
        _moved[_dragging] = out
        queue_redraw()
        return
    if e is InputEventKey and (e as InputEventKey).pressed:
        var k := (e as InputEventKey).keycode
        if k == KEY_LEFT:
            set_year(_year - 1)
        elif k == KEY_RIGHT:
            set_year(_year + 1)
        elif k >= KEY_1 and k <= KEY_4:
            set_year(int(DECLARED[k - KEY_1]))


func _polygon_of(pin_id: String) -> Array:
    for pin: Dictionary in _pins.at(_year):
        if str(pin.get("pin_id", "")) == pin_id:
            return pin.get("polygon", [])
    return []
