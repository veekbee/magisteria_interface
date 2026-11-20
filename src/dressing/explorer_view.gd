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
## The payload as issued, so a priced answer can be re-issued as ITSELF.
##
## ⚠ NOT RECONSTRUCTED FROM THE VIEW. A priced `remove` must come back as the
## same `pin_id`, and a priced `rewind` as the same `to_year` -- and the year on
## screen can have moved between the price and the confirm. Rebuilding the
## payload from the current view would confirm a different command than the one
## that was priced.
var _pending_payload: Dictionary = {}
var _notice: String = ""
var _poll_accum: float = 0.0

## §25 backlog 754: the placing tools. Owner ruling at this row -- RECTANGLES
## FIRST: one drag makes an axis-aligned four-vertex polygon for `zone`, `cap`,
## `renew` and a polygon `feature`; free shapes come later.
##
## A FEATURE'S GEOMETRY FOLLOWS THE GESTURE RATHER THAN A SECOND KEY: a drag is
## a polygon, a click is a point. The kind admits either, and the owner's key set
## is the six ruled letters, so the alternative was a modifier nobody asked for.
const TOOLS := {KEY_Z: "zone", KEY_F: "feature", KEY_C: "centre", KEY_T: "route",
        KEY_K: "cap", KEY_W: "renew"}
## A press and release closer than this in metres is a click, not a drag.
const CLICK_M := 60.0

var _tool: String = ""
var _tool_choice: int = 0
var _drag_a: Array = []
var _points: Array = []
var _selected: String = ""
## The session's own working pin file, drawn so a placement is visible at once.
var _session_pins: Array = []


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
    # ⚠ AN UNSTEPPED SESSION HAS NO CITY OF ITS OWN, AND THAT IS NOT A FAULT.
    # Its year is the arc's first less one, there is no `year_<Y>/` yet, and so
    # there is no fold, no stats and nothing of this session's to draw. The
    # committed city STAYS ON SCREEN -- the header's asymmetry: the dressing's
    # bindings gate the drawing, a panel is a readout beside it. And `_year` is
    # left where it is on purpose: no city exists at the session's year, here or
    # anywhere, so moving the view to it would show an empty map and call it the
    # session's.
    if _session.unstepped:
        _panel = ["session %s" % _session.session_name,
                "not advanced yet, so nothing is built.",
                "the arc starts at %d; press `a` to build it." % _session.first_year]
        _load_session_pins()
        return
    _year = _session.year
    var stats := _session.stats_of(_session.year)
    var built := StatsPanel.of(stats)
    if built.problem != "":
        _panel = ["session %s at %d" % [_session.session_name, _session.year], built.problem]
        return
    _panel = ["session %s" % _session.session_name] + built.lines
    _load_session_pins()


## The pin ids the session's own fold already draws, so the pin stands down.
##
## BOTH KINDS THAT GET A FOLD ROW, matched the way the generator writes them --
## see `SessionRead.ids_drawn_by_fold`, which holds the rule and the reason it is
## not a date.
func _ids_the_fold_draws() -> Dictionary:
    return SessionRead.ids_drawn_by_fold(_session_features, _session_routes)


## The session's working pin file. Empty when there is none, which is a state.
func _load_session_pins() -> void:
    _session_pins = []
    if _session == null or not _session.is_present():
        return
    var doc := SessionRead.read_json(_session.dir + "pins.json")
    var rows = doc.get("pins", [])
    if typeof(rows) == TYPE_ARRAY:
        _session_pins = rows


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
    if _session == null or not _session.has_span():
        return LO
    return _session.slider_span().x


## ⚠ AN UNSTEPPED SESSION HAS NO SPAN AT ALL, and the obvious code returns its
## year -- which is the arc's first LESS ONE, so the slider's high end would sit
## BELOW its low end and the axis would run backwards. Both ends therefore fall
## back to the committed span together, which is the city actually on screen in
## that state; splitting them would label a committed city with a session's arc.
func _span_hi() -> int:
    if _session == null or not _session.has_span():
        return HI
    return _session.slider_span().y


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

    # ⚠ A ROUTE IS DRAWN FROM ITS LAID TILES, NOT ITS GEOMETRY (§25 backlog 755:
    # *a route as its laid tiles from the session's regenerated rows -- the client
    # derives none*). The row carries both, and they are not the same claim: the
    # geometry is the line the router was given, and the tiles are the ground it
    # actually laid. Drawing the line would show the owner a route where no tile
    # was taken -- the client deciding what a route covers, which is the thing
    # this client does not do. The straight line survives only as the PLACING
    # preview, where it is explicitly not yet a route.
    for r: Dictionary in DressingFold.routes_at(
            _session_routes if in_session else _routes, _year):
        var col := DressingDraw.route_color(_palette, str(r.get("class", "")), _unknown_routes)
        for tv in r.get("tiles", []):
            var k := DressingFold.tile_key(tv)
            if not _centres.has_centre(k):
                continue
            var c := _centres.centre_of(k)
            var q := _to_screen(c[0], c[1])
            draw_rect(Rect2(q - Vector2(side, side) * 0.5, Vector2(side, side)), col)

    # A SESSION'S PINS ARE ITS OWN FILE'S, AND THIS ROW DOES NOT DRAW THEM.
    # `pins.json` in a session directory is the working pin file; drawing it is
    # §25 backlog 754's, with the placing tools. The committed pin file is drawn
    # only when no session is open, so the owner is never shown one city's
    # outlines over another's tiles.
    if in_session:
        # THE OWNER'S OWN PINS, SO A PLACEMENT IS VISIBLE AT ONCE. Without this a
        # placement shows nothing until the next advance -- the worst moment to
        # have no feedback. A pin the session has already applied is drawn in the
        # edge colour; one dated after the year on screen is PENDING and drawn in
        # the notice colour, because `from` is Y + 1 and the owner would
        # otherwise see no difference between asked-for and built.
        var drawn_by_the_fold := _ids_the_fold_draws()
        for pin: Dictionary in _session_pins:
            var kind := str(pin.get("kind", ""))
            var applied := int(pin.get("from", 0)) <= _year
            # ⚠ WHO DRAWS WHAT, AND IT DIFFERS BY KIND BECAUSE THE FOLD DIFFERS.
            #   zone, cap, renew  the fold NEVER carries them -- a zone pin
            #                     writes no tile row, it sets the allowed-class
            #                     mask -- so the pin is the only drawing there
            #                     will ever be, applied or not. A missing zone
            #                     colour is not a missing zone.
            #   centre            likewise: it founds a subcentre and writes no
            #                     row, so it stays a marker from the pin.
            #   feature           once applied, the fold's own row is drawn (its
            #                     tiles ARE the catalogue footprint the generator
            #                     chose), so the pin stands down; matched by
            #                     `pin_id`, which a session's feature rows carry.
            #   route             once laid, the fold's laid tiles are drawn --
            #                     matched by the row's `route` BEING the pin's
            #                     id, with `by` = "pin", and NOT by date. The
            #                     generator lays routes of its own in the same
            #                     years, so a date match drew a rule-laid route
            #                     as the owner's: real session, 1880, two routes,
            #                     both "rule".
            var pid := str(pin.get("pin_id", ""))
            if (kind == "feature" or kind == "route") and drawn_by_the_fold.has(pid):
                continue
            _draw_pin(pin, edge if applied else Color(1, 0.9, 0.4), side)
    elif _pins != null and _pins.is_present():
        for pin: Dictionary in _pins.at(_year):
            _draw_pin(pin, edge, side)
    _draw_preview(side)
    _chrome(vp)
    _draw_panel(vp)


## The gesture in progress, drawn as decision 2149 (5) describes it: a route as
## a straight line while it is being placed, a polygon as its outline, a point as
## a marker. Nothing here is a pin yet.
func _draw_preview(side: float) -> void:
    if _tool == "" or _points.is_empty():
        return
    var col := Color(0.4, 1.0, 0.6)
    if _tool == "route":
        var pts := PackedVector2Array()
        for v in _points:
            var xy: Array = v
            pts.append(_to_screen(float(xy[0]), float(xy[1])))
        for q in pts:
            draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), col)
        if pts.size() >= 2:
            draw_polyline(pts, col, maxf(side * 0.3, 1.0))
        return
    if _points.size() == 1:
        var xy0: Array = _points[0]
        var c := _to_screen(float(xy0[0]), float(xy0[1]))
        draw_line(c - Vector2(8, 0), c + Vector2(8, 0), col, 2.0)
        draw_line(c - Vector2(0, 8), c + Vector2(0, 8), col, 2.0)
        return
    var ring := PackedVector2Array()
    for v in _points:
        var xy: Array = v
        ring.append(_to_screen(float(xy[0]), float(xy[1])))
    ring.append(ring[0])
    draw_polyline(ring, col, maxf(side * 0.3, 2.0))


func _draw_pin(pin: Dictionary, edge: Color, side: float) -> void:
    var pid := str(pin.get("pin_id", ""))
    # `base_of` RATHER THAN `polygon`, so a point kind draws as its point. Before
    # §25 backlog 754 a `centre` reported itself undrawable here, which was honest
    # and is now avoidable. §25 backlog 755 still owns drawing what the GENERATOR
    # made of a pin, from the fold; this draws the pin the owner wrote.
    var verts: Array = _moved[pid] if _moved.has(pid) else PlacePin.base_of(pin)
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
    var kind := str(pin.get("kind", "?"))
    if pts.size() == 1:
        # A marker: a one-vertex outline is not a shape.
        draw_line(pts[0] - Vector2(7, 7), pts[0] + Vector2(7, 7), edge, 2.0)
        draw_line(pts[0] - Vector2(7, -7), pts[0] + Vector2(7, -7), edge, 2.0)
        var label := "%s  %s" % [kind, pid]
        # ⚠ THE ONE PLACE "EVERY FIRST-VERSION KIND DRAWN" IS NARROWER THAN IT
        # SOUNDS, said on screen rather than left as a silence. A POINT feature
        # dated after the year on screen has no fold row yet, so its catalogue
        # footprint does not exist to be drawn: the generator decides it at the
        # next advance. A marker and these words are the honest drawing.
        if kind == "feature":
            label += "  (footprint is the generator's, at the next advance)"
        _text(pts[0] + Vector2(10, -8), label, edge)
        return
    # A ROUTE IS AN OPEN LINE. Closing it would draw a ring through ground the
    # router was never asked about.
    if kind != "route":
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
    if _tool != "":
        var choices := _tool_choices()
        var choice := str(choices[_tool_choice]) if _tool_choice < choices.size() else "-"
        _text(Vector2(20, line_y), "tool %s  [%s]  %d point(s)"
                % [_tool, choice, _points.size()], Color(0.4, 1, 0.6))
        line_y += 18.0
    if _selected != "":
        _text(Vector2(20, line_y), "selected %s  (x removes it)" % _selected,
                Color(0.6, 0.9, 1))
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
    var pins := _drawn_pins()
    if pins.is_empty():
        return ""
    for pin: Dictionary in pins:
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
    # ⚠ AND THEN BY DISTANCE, OR `remove` WOULD WORK ON FOUR OF THE SIX KINDS.
    # The loop above tests CONTAINMENT, and a `centre` or a point `feature` has
    # no polygon to contain anything -- the same blind spot the point-kind guards
    # cover on the drag. Half a tile, in float64 metres, so the pick does not
    # depend on the zoom.
    var w := _to_world(p)
    return PlacePin.point_pick(pins, w[0], w[1], _centres.tile_m * 0.5)


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
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if _tool != "":
            _tool_click(mb)
            return
        if mb.pressed:
            _dragging = _pin_at(mb.position)
            _selected = _dragging
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
        # ⚠ THE FIRST POINT-KIND GUARD: AN EMPTY BASE IS REFUSED. `base_of`
        # gives a point kind its own point (the second guard), so an empty base
        # now means a pin with no geometry at all -- and a gesture that recorded
        # one would put a zero-vertex pin into the edit list, which is a pin
        # whose geometry a drag had deleted. Refused, and said out loud.
        var base: Array = _moved[_dragging] if _moved.has(_dragging) \
                else _base_of(_dragging)
        if base.is_empty():
            _notice = "pin %s has no geometry to move" % _dragging
            _dragging = ""
            queue_redraw()
            return
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
        elif TOOLS.has(k):
            _tool = str(TOOLS[k])
            _tool_choice = 0
            _drag_a = []
            _points = []
            _notice = "%s: %s" % [_tool, _tool_hint()]
            queue_redraw()
        elif k == KEY_ESCAPE:
            if _tool != "":
                _tool = ""
                _drag_a = []
                _points = []
                _notice = "no tool"
                queue_redraw()
        elif k == KEY_ENTER or k == KEY_KP_ENTER:
            _commit_place()
        elif k == KEY_BRACKETLEFT or k == KEY_BRACKETRIGHT:
            var choices := _tool_choices()
            if not choices.is_empty():
                var step := 1 if k == KEY_BRACKETRIGHT else -1
                _tool_choice = posmod(_tool_choice + step, choices.size())
                _notice = "%s: %s" % [_tool, str(choices[_tool_choice])]
                queue_redraw()
        elif k == KEY_X:
            _issue_remove()


## What the current tool is waiting for, in words.
func _tool_hint() -> String:
    match _tool:
        "route":
            return "click the two ends, clicks between them are waypoints, Enter to place"
        "centre":
            return "click a point, Enter to place"
        "feature":
            return "drag a rectangle or click a point, Enter to place"
        _:
            return "drag a rectangle, Enter to place"


## The classes or types this tool cycles with `[` and `]`.
##
## ⚠ DERIVED FROM THE FETCHED ARTEFACTS, AND NAMED NOWHERE IN THIS SOURCE. The
## zone's classes come from the palette's own map, the route's from the palette's
## route map, a feature's types from the reference's own feature rows. §25
## backlog 755 lays the plain labels over them and rules the names it needs; this
## row names none, so it needs no vocabulary entry at all -- and a class the
## generator stops using stops being offered without anyone editing a list.
func _tool_choices() -> Array:
    var out: Array = []
    match _tool:
        "zone":
            # ⚠ THE RULED TEN, NOT THE PALETTE'S. §25 backlog 754 derived this
            # from the render palette and was wrong both ways: the palette offers
            # `transport`, which the format refuses, and omits the umbrella,
            # which it accepts. The labels are design's
            # (`notes/epoch-T/da11-play-loop.md` line 130) and the class the pin
            # carries is the register's, unchanged.
            out = PlacePin.zone_labels()
        "route":
            var rt = _palette.get("ROUTE", {})
            if typeof(rt) == TYPE_DICTIONARY:
                out = (rt as Dictionary).keys()
        "feature":
            var seen := {}
            for f: Dictionary in (_session_features if _session_features.size() > 0 else _features):
                var ty := str(f.get("type", ""))
                if ty != "":
                    seen[ty] = true
            out = seen.keys()
    out.sort()
    return out


## One click or release with a tool active.
func _tool_click(mb: InputEventMouseButton) -> void:
    var w := _to_world(mb.position)
    if _tool == "route":
        if mb.pressed:
            _points.append([w[0], w[1]])
            _notice = "route: %d point(s), Enter to place" % _points.size()
            queue_redraw()
        return
    if mb.pressed:
        _drag_a = [w[0], w[1]]
        return
    # THE RELEASE DECIDES WHAT THE GESTURE WAS: a drag is a rectangle, a press
    # and release in the same place is a point.
    if _drag_a.is_empty():
        return
    var dx := w[0] - float(_drag_a[0])
    var dy := w[1] - float(_drag_a[1])
    if sqrt(dx * dx + dy * dy) < CLICK_M:
        _points = [[float(_drag_a[0]), float(_drag_a[1])]]
        _notice = "%s: a point, Enter to place" % _tool
    else:
        _points = PlacePin.rect(float(_drag_a[0]), float(_drag_a[1]), w[0], w[1])
        _notice = "%s: a rectangle, Enter to place" % _tool
    _drag_a = []
    queue_redraw()


## Mint the pin the gesture describes and write it as a `place`.
func _commit_place() -> void:
    if _tool == "" or _session == null or not _session.is_present():
        return
    if _points.is_empty():
        _notice = "%s: nothing placed yet" % _tool
        queue_redraw()
        return
    # ⚠ `from` IS Y + 1, AND THAT IS THIS CLIENT'S RESTRICTION RATHER THAN THE
    # RULE. Decision 2149 (3) allows any `from >= Y + 1`; the first version
    # offers only the next year, because the owner is playing year by year and a
    # later date has no use yet. A pin dated at or before Y is refused by the
    # session with `rewind to from - 1 first`.
    var from_year := _session.year + 1
    var fields := {}
    var choices := _tool_choices()
    var choice := str(choices[_tool_choice]) if _tool_choice < choices.size() else ""
    match _tool:
        "route":
            if _points.size() < 2:
                _notice = "route: two ends are needed"
                queue_redraw()
                return
            fields["endpoints"] = [_points[0], _points[_points.size() - 1]]
            if _points.size() > 2:
                fields["waypoints"] = _points.slice(1, _points.size() - 1)
            fields["class"] = choice
        "centre":
            fields["point"] = _points[0]
        "feature":
            fields["type"] = choice
            if _points.size() == 1:
                fields["point"] = _points[0]
            else:
                fields["polygon"] = _points
        _:
            fields["polygon"] = _points
            if _tool == "zone":
                # THE LABEL IS WHAT THE OWNER PICKED; THE CLASS IS WHAT THE FILE
                # GETS. A pin carrying "shops and offices" would be refused by
                # the format, which knows only the register's names.
                fields["class"] = PlacePin.class_of_label(choice)
    var id := PlacePin.next_id(_tool, from_year, PlacePin.ids_of(_session_pins))
    var row := PlacePin.row(_tool, from_year, id, fields)
    # REFUSED HERE BEFORE IT IS WRITTEN, by `PinFile`'s own rules rather than a
    # second copy of them. The session will check it again, and so will the
    # emission tool; this one only saves a round trip the owner would wait on.
    var why := PlacePin.refusal_of(row)
    if why != "":
        _notice = "refused before writing: %s" % why
        queue_redraw()
        return
    _issue("place", {"pins": [row]})
    _points = []
    _drag_a = []


## Remove the selected pin, priced if the session has applied it.
func _issue_remove() -> void:
    if _selected == "":
        _notice = "nothing selected to remove"
        queue_redraw()
        return
    _issue("remove", {"pin_id": _selected})


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
    _pending_payload = payload.duplicate(true)
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
        _pending_confirm = {"verb": verb, "payload": _pending_payload.duplicate(true)}
        _notice = "that %s costs about %.0f s -- press Y to confirm" % [verb, cost]
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
    _load_session_pins()
    set_year(mini(_year, _session.year))


func _polygon_of(pin_id: String) -> Array:
    for pin: Dictionary in _drawn_pins():
        if str(pin.get("pin_id", "")) == pin_id:
            return pin.get("polygon", [])
    return []


## A pin's drag base: its polygon, or its own point for a point kind.
##
## THE SECOND POINT-KIND GUARD, via `PlacePin.base_of` so that the rule has one
## implementation rather than one here and one in the minting class.
func _base_of(pin_id: String) -> Array:
    for pin: Dictionary in _drawn_pins():
        if str(pin.get("pin_id", "")) == pin_id:
            return PlacePin.base_of(pin)
    return []


## The pins on screen: the session's working file, or the committed one.
func _drawn_pins() -> Array:
    if _session != null and _session.is_present():
        return _session_pins
    if _pins != null and _pins.is_present():
        return _pins.at(_year)
    return []
