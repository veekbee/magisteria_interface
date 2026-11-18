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

## §25 backlog 742. The fold is computed once per (rows identity, year) instead
## of once per frame: `_draw()` runs every frame while a pin is dragged, and the
## fold depends on nothing a redraw changes.
##
## THE IDENTITY IS THE LOADER'S ALREADY-VERIFIED DIGEST OF `tiles.jsonl`, not a
## second hash of the same bytes. `DressingLoad` recomputes it from the file and
## checks it against the PIN before this view draws anything, so taking it from
## there keeps one source of truth for the claim "these are those rows". When
## DA-11's session supplies rows instead, the identity becomes whatever that
## session's reader can state, and the memo clears itself when it moves.
var _memo := DressingFoldMemo.new()
var _rows_digest: String = ""


## §25 backlog 752: a play session's directory, when one is named.
##
## NAMED BY THE ENVIRONMENT AND OPTIONAL BY DESIGN. A session lives in a
## git-ignored directory on the owner's machine, so its path cannot be committed
## and must not be guessed. With nothing set, this view is exactly what it was
## before 752 -- the committed dressing, drawn from fetched artefacts.
##
## ⚠ A SESSION THAT FAILS TO READ DOES NOT BLOCK THE CITY. The refusal is drawn
## in the panel's place instead. That asymmetry is deliberate: the dressing's
## bindings gate the drawing because the owner is being asked to rule on what
## they see, while a panel is a readout beside it -- and a session the owner
## pointed at wrongly should say so without taking the city away.
const SESSION_ENV := "MAGISTERIA_SESSION"

var _session: SessionRead = null
var _panel: Array = []

## §25 backlog 753: the session's own city, for the year on screen.
##
## A SESSION'S FOLD IS ALREADY FOLDED. `year_<Y>/fold.json` carries the per-tile
## state that `DressingFold` computes from the committed `tiles.jsonl`, so on the
## session path there is no fold to compute and 742's memo is not used at all --
## it stays for the no-session path, where it is still what makes dragging
## possible. Nothing here re-folds, re-sorts by its own rule, or derives a tile's
## state: the session hands over a year and this draws it.
var _session_fold: Dictionary = {}
var _session_features: Array = []
var _session_routes: Array = []

## The route classes the palette does not name, collected rather than assumed.
##
## SEPARATE FROM `_unknown_classes` ON PURPOSE: a tile class and a route class
## are different vocabularies and a reader told only that "some class" was
## unnamed cannot tell which drawing is wrong.
var _unknown_routes: Dictionary = {}

## The command issued and not yet answered, and what came back.
const POLL_S := 0.5
var _pending_stem: String = ""
var _pending_verb: String = ""
var _pending_confirm: Dictionary = {}
var _notice: String = ""
var _poll_accum: float = 0.0


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
    _rows_digest = str(_load.per_file.get("tiles.jsonl", {}).get("computed", ""))
    if _rows_digest.is_empty():
        # UNREACHABLE AS WIRED, AND CHECKED ANYWAY. `identity_holds()` above
        # already refuses a dressing whose per-file digests were not recomputed,
        # so this cannot fire today; it is here because the memo without an
        # identity silently stops memoising, and a view that got slower for a
        # reason nobody could see is worse than one that says why.
        _refusal = ("The tile rows arrived without the identity the fold is keyed on, so "
                + "this view cannot tell one rows set from another.")
        return
    _features = DressingFold.read_rows(DressingFold.DIR + "features.jsonl")
    _routes = DressingFold.read_rows(DressingFold.DIR + "routes.jsonl")
    set_year(_year)
    _open_session()


## Open the session named by the environment, if any, and build its panel.
func _open_session() -> void:
    var dir := OS.get_environment(SESSION_ENV)
    if dir.is_empty():
        return
    _session = SessionRead.open_dir(dir)
    if not _session.is_present():
        _panel = ["session %s" % dir, _session.problem]
        return
    # ⚠ THE SESSION'S BASE DRESSING MUST BE THE ONE THIS CLONE FETCHED, and the
    # check is by id because the identity cannot be used: `centres.json` is
    # stamped with the COMMITTED dressing's `dressing_sha256`, and a session's
    # city is not that dressing. What makes the centres usable for a session's
    # tiles is the LATTICE -- a tile is an index into it, so a tile's position
    # depends on the lattice and not on the city -- and the centres' load
    # already refuses a lattice that is not the manifest's. So the lattice half
    # is enforced upstream; the half that was missing is this one.
    var want := _manifest_field("dressing_id")
    if want != "" and _session.base_dressing_id != want:
        _refusal = ("This session was opened against dressing %s and this clone has fetched "
                + "%s. A tile is an index into a lattice, so drawing one city's tiles at "
                + "another's centres would place a city that never existed.")\
                % [_session.base_dressing_id, want]
        return
    _year = _session.year
    var stats := _session.stats_of(_session.year)
    var built := StatsPanel.of(stats)
    if built.problem != "":
        _panel = ["session %s at %d" % [_session.session_name, _session.year], built.problem]
        return
    _panel = ["session %s" % _session.session_name] + built.lines


## Draw the session's panel down the right, or nothing when no session is open.
func _draw_panel(vp: Vector2) -> void:
    if _panel.is_empty():
        return
    var w := 420.0
    var x := vp.x - w - 16.0
    draw_rect(Rect2(Vector2(x - 12, 12), Vector2(w + 12, vp.y - 72)), Color(0, 0, 0, 0.55))
    var y := 34.0
    for line in _panel:
        _text(Vector2(x, y), str(line), Color(0.92, 0.92, 0.88))
        y += 17.0


func _lattice_of_manifest() -> String:
    return _manifest_field("lattice")


## One top-level field of the fetched manifest, or "".
func _manifest_field(name: String) -> String:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(
            DressingLoad.DIR + "manifest.json"))
    if typeof(parsed) != TYPE_DICTIONARY:
        return ""
    return str((parsed as Dictionary).get(name, ""))


## The eras and their first years, for the slider's ticks. A year carrying two
## eras names both (see `DressingLoad.era_ticks`).
## THE SPAN IS THE SESSION'S WHEN THERE IS ONE, and that is not cosmetic: a
## session has folds only for the years it has stepped, so a slider running to
## 2039 would offer years with no city behind them. It runs to the session's
## current year and grows as the owner advances -- and SHRINKS after a rewind,
## which deletes the year directories above its target.
func _span_lo() -> int:
    return _session.first_year if _session != null and _session.is_present() else LO


func _span_hi() -> int:
    return _session.year if _session != null and _session.is_present() else HI


## The eras and their first years, for the slider's ticks. A year carrying two
## eras names both (see `DressingLoad.era_ticks`).
##
## Only the ticks INSIDE the span are drawn: early in a session most era starts
## lie beyond it, and a tick drawn outside the axis it belongs to is a label
## pointing at nothing.
func era_ticks() -> Array:
    if _load == null:
        return []
    return DressingLoad.era_ticks(_load.era_starts(), _span_lo(), _span_hi())


func set_year(y: int) -> void:
    _year = clampi(y, _span_lo(), _span_hi())
    if _refusal != "":
        return
    if _session != null and _session.is_present() and not _load_session_year(_year):
        queue_redraw()
        return
    var fold := _fold_now()
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


## The year's fold: the session's, already folded, or the committed dressing's.
func _fold_now() -> Dictionary:
    if _session != null and _session.is_present():
        return _session_fold
    return _memo.fold(_tiles, _rows_digest, _year)


## Read one of the session's years and bind it. False means refused.
##
## ⚠ A FOLD THAT FAILS ITS BINDING IS A REFUSAL, not a skipped draw. The owner
## is being asked to look at a city; a fold from another session, or stepped
## under a pin file this session never had, would be a different city drawn
## under this one's name.
func _load_session_year(y: int) -> bool:
    if not _session.years_present().has(y):
        _refusal = ("This session has no fold for %d. It stands at %d, and a rewind deletes "
                + "the years above its target rather than keeping a city no pin file "
                + "regrows.") % [y, _session.year]
        return false
    var doc := _session.fold_of(y)
    var why := _session.fold_problem(doc)
    if why != "":
        _refusal = "Year %d's fold is not this session's:\n\n%s" % [y, why]
        return false
    _session_fold = SessionRead.state_of_fold(doc)
    _session_features = doc.get("features", [])
    _session_routes = doc.get("routes", [])
    return true


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
    var fold := _fold_now()
    var side := maxf(_centres.tile_m * _scale, 1.0)
    var in_session := _session != null and _session.is_present()

    _unknown_classes.clear()
    _unknown_routes.clear()
    for row: Dictionary in DressingDraw.tile_rows(fold, _palette,
            float(_palette.get("density_ref", 1.0)), _unknown_classes):
        var c := _centres.centre_of(str(row["key"]))
        var p := _to_screen(c[0], c[1])
        draw_rect(Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)), row["color"])

    var edge := DressingDraw.edge_color(_palette)
    # THE SAME TWO SORT RULES EITHER WAY. A session's rows are already standing
    # at their year, so the filter is idempotent -- but `features_at` and
    # `routes_at` also impose §25 backlog 730's two DIFFERENT sort orders
    # (features by `feature_id` alone, routes by `(calendar_year, route)`), and
    # drawing a session's rows in file order would be a second ordering rule
    # nobody ruled.
    for f: Dictionary in DressingFold.features_at(
            _session_features if in_session else _features, _year):
        var keys: Array = []
        for t in f.get("tiles", []):
            keys.append(DressingFold.tile_key(t))
        for k in DressingDraw.outline_keys(keys, _centres):
            var c := _centres.centre_of(str(k))
            var p := _to_screen(c[0], c[1])
            draw_rect(Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)), edge, false,
                    maxf(side * 0.18, 1.0))

    for r: Dictionary in DressingFold.routes_at(
            _session_routes if in_session else _routes, _year):
        var pts := PackedVector2Array()
        for v in r.get("geometry", []):
            var xy: Array = v
            pts.append(_to_screen(float(xy[0]), float(xy[1])))
        if pts.size() >= 2:
            draw_polyline(pts, DressingDraw.route_color(_palette,
                    str(r.get("class", "")), _unknown_routes), maxf(side * 0.4, 1.0))

    # A SESSION'S PINS ARE ITS OWN FILE'S, AND THIS ROW DOES NOT DRAW THEM.
    # `pins.json` in a session directory is the working pin file; drawing it is
    # §25 backlog 754's, with the placing tools. The committed pin file is drawn
    # only when no session is open, so the owner is never shown one city's
    # outlines over another's tiles.
    if not in_session and _pins != null and _pins.is_present():
        for pin: Dictionary in _pins.at(_year):
            _draw_pin(pin, edge, side)
    _chrome(vp)
    _draw_panel(vp)


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
    var in_session := _session != null and _session.is_present()
    var head := "DA-6 compact   %d" % _year
    if in_session:
        head = "session %s   %d   (built to %d)" % [_session.session_name, _year, _session.year]
    _text(Vector2(20, 24), head, edge)
    var y := vp.y - 30.0
    draw_line(Vector2(20, y), Vector2(vp.x - 20, y), edge, 1.0)
    var lo := _span_lo()
    var hi := _span_hi()
    # ⚠ A SESSION AT ITS FIRST YEAR HAS A SPAN OF ZERO, which is a real state
    # (open a session, step nothing) and would divide by zero here. The axis is
    # still drawn, with the one year at its start, rather than skipped.
    var span := float(hi - lo)
    if span > 0.0:
        for t: Dictionary in era_ticks():
            var fx := 20.0 + (vp.x - 40.0) * (float(int(t["year"]) - lo) / span)
            draw_line(Vector2(fx, y - 7), Vector2(fx, y + 7), edge, 1.0)
            _text(Vector2(fx - 10, y + 24), "%d %s" % [int(t["year"]),
                    " ".join(t["eras"] as PackedStringArray)], edge)
    var hx := 20.0 + (vp.x - 40.0) * ((float(_year - lo) / span) if span > 0.0 else 0.0)
    draw_line(Vector2(hx, y - 12), Vector2(hx, y + 12), Color(0.85, 0.2, 0.2), 2.0)
    # THE AXIS'S END IS THE SESSION'S CURRENT YEAR, not the arc's last: the
    # slider cannot reach a year the session has not stepped.
    _text(Vector2(vp.x - 80, y + 24), "%d" % hi, edge)
    var line_y := 44.0
    if not _unknown_classes.is_empty():
        _text(Vector2(20, line_y), "classes the palette does not name: %s"
                % ", ".join(PackedStringArray(_unknown_classes.keys())),
                Color(0.8, 0.1, 0.6))
        line_y += 18.0
    # ⚠ NAMED, NOT SILENTLY COLOURED. Before §25 backlog 753 a route of a class
    # the palette does not name was drawn in the UNKNOWN colour with nothing
    # said, while unknown TILE classes were named above -- an asymmetry that let
    # the owner see an oddly coloured line with no words for it. The committed
    # compact dressing carries two such classes today, so this line appears on
    # the no-session path too. Colouring them is the generator's palette's to
    # change and would move committed renders, so it is not done here.
    if not _unknown_routes.is_empty():
        _text(Vector2(20, line_y), "route classes the palette does not name: %s"
                % ", ".join(PackedStringArray(_unknown_routes.keys())),
                Color(0.8, 0.1, 0.6))
        line_y += 18.0
    if _notice != "":
        _text(Vector2(20, line_y), _notice, Color(1, 0.9, 0.4))


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
        elif k == KEY_A:
            _issue("advance", {"years": 1})
        elif k == KEY_R:
            # THE GESTURE IS: SLIDE BACK, THEN PRESS R. The target is the year on
            # screen, so the owner rewinds to what they are looking at. Nothing
            # is done by this: the session answers with a price and `Y` confirms.
            _issue("rewind", {"to_year": _year})
        elif k == KEY_Y:
            _confirm()


## Issue one command, if a session is open and none is outstanding.
func _issue(verb: String, payload: Dictionary) -> void:
    if _session == null or not _session.is_present():
        return
    if _pending_stem != "":
        _notice = "waiting on %s already; one command at a time" % _pending_verb
        queue_redraw()
        return
    var got := SessionCommands.write(_session.dir, verb, payload)
    if not bool(got["ok"]):
        _notice = str(got["problem"])
        queue_redraw()
        return
    _pending_stem = str(got["stem"])
    _pending_verb = verb
    _pending_confirm = {}
    _notice = "%s issued as %s; the session is working" % [verb, _pending_stem]
    queue_redraw()


## Re-issue a priced command with `confirm`, under a NEW seq.
##
## ⚠ A NEW FILE, NOT THE SAME ONE. A command is consumed by being renamed into
## `commands/done/`, so re-writing the priced command's own name would be
## refused as consumed already. The confirm is its own command.
func _confirm() -> void:
    if _pending_confirm.is_empty():
        return
    var verb := str(_pending_confirm["verb"])
    var payload: Dictionary = _pending_confirm["payload"]
    payload["confirm"] = true
    _pending_confirm = {}
    _issue(verb, payload)


## Poll for the outstanding command's answer. Never blocks a frame.
func _process(delta: float) -> void:
    if _session == null or _pending_stem == "":
        return
    _poll_accum += delta
    if _poll_accum < POLL_S:
        return
    _poll_accum = 0.0
    var answer := SessionCommands.answer_of(_session.dir, _pending_stem)
    if answer.is_empty():
        return
    _on_answer(answer)


## One answer, read and acted on.
func _on_answer(answer: Dictionary) -> void:
    var verb := _pending_verb
    _pending_stem = ""
    _pending_verb = ""
    if not bool(answer.get("ok", false)):
        # ⚠ VERBATIM. The session's refusal names what it refused and why, and a
        # paraphrase would be this client's guess at the generator's reasoning.
        _notice = "refused: %s" % str(answer.get("refusal", "(no reason given)"))
        queue_redraw()
        return
    var cost := SessionCommands.priced_cost(answer)
    if cost >= 0.0:
        # PRICED: NOTHING WAS DONE. A rewind replays from the arc's start and can
        # cost the whole build, so it is never confirmed automatically.
        _pending_confirm = {"verb": verb, "payload": {"to_year": _year}}
        _notice = "a %s to %d costs about %.0f s -- press Y to confirm" % [verb, _year, cost]
        queue_redraw()
        return
    _reread()
    _notice = "%s done" % verb
    queue_redraw()


## Re-read the session after a command that changed it, and clamp the year.
##
## ⚠ THE YEAR IS CLAMPED DOWN BECAUSE A REWIND DELETES YEARS. The session removes
## `year_<y>/` above a rewind's target, so the year on screen can cease to exist
## while it is being looked at. Re-reading `session.json` and clamping is what
## stops the view holding a city the session no longer has.
func _reread() -> void:
    var dir := _session.dir
    _session = SessionRead.open_dir(dir)
    if not _session.is_present():
        _refusal = "The session stopped reading after a command:\n\n%s" % _session.problem
        return
    var stats := _session.stats_of(_session.year)
    var built := StatsPanel.of(stats)
    _panel = ["session %s" % _session.session_name]
    _panel += built.lines if built.problem == "" else [built.problem]
    set_year(mini(_year, _session.year))


func _polygon_of(pin_id: String) -> Array:
    for pin: Dictionary in _pins.at(_year):
        if str(pin.get("pin_id", "")) == pin_id:
            return pin.get("polygon", [])
    return []
