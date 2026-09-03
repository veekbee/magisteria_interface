class_name ProbePanel
extends VBoxContainer

## M4's probe readout: what the point that was clicked resolves to.
##
## THE THREE ABSENCES STAY THREE THINGS. CellProbe distinguishes no ground, a
## ruled empty key, and a key the fixture cannot join; this panel prints the
## reason it was given rather than collapsing them into "no data". Two of the
## three are not errors, and a readout that said "no data" to all three would
## make a ruling, a measurement and a broken join indistinguishable at exactly
## the moment someone is looking for one of them.
##
## The row and day are printed with the value because the probe reads what the
## terrain is painted with. Showing a bare number would leave the reader to
## remember which row it came from, and they would remember the one they
## selected rather than the one that is drawn.
##
## ONE NODE ROW IS PLOTTED AND THE OTHER IS EXPLAINED. The milestone asks for
## `node.streamflow` and `node.wetland_extent`; only the first is on the wire.
## Contract v2.0 advanced its major for, in the artefact's own words, "row
## removed or renamed: node.wetland_extent" -- its only writer is an
## unimplemented subsystem (decision 901) -- and the fixture's carried set has
## eight rows without it. So the panel says the row is absent UPSTREAM rather
## than drawing one plot and leaving the reader to wonder about the other:
## FieldScrubber's refused-row label again, and for the same reason.

const NOT_PROBED := ("click the terrain to probe a cell — the click also scatters vegetation "
        + "there, and G takes the camera to it")

#: The node rows M4 asks for. A row here that the fixture does not carry is
#: reported by name rather than dropped from the panel.
const NODE_ROWS := ["node.streamflow", "node.wetland_extent"]

var heading: Label
var where: Label
var state: Label
var key: Label
var value: Label
var series_caption: Label
var series: SeriesPlot
var absent_rows: Label
var scatter_line: Label
var scatter_where: Label
var scatter_share: Label

var _fl: FixtureLoader = null


func setup(fl: FixtureLoader = null) -> void:
    _fl = fl
    custom_minimum_size = Vector2(420, 0)
    heading = _line(18)
    heading.text = "probe"
    where = _line()
    state = _line()
    key = _line()
    value = _line()

    series_caption = _line()
    series = SeriesPlot.new()
    series.custom_minimum_size = Vector2(400, 130)
    add_child(series)
    absent_rows = _line()
    scatter_line = _line()
    scatter_where = _line()
    scatter_share = _line()
    clear()


func clear() -> void:
    where.text = ""
    state.text = NOT_PROBED
    key.text = ""
    value.text = ""
    series_caption.text = ""
    series.clear()
    absent_rows.text = ""
    scatter_line.text = ""
    scatter_where.text = ""
    scatter_share.text = ""


func show_probe(r: Dictionary) -> void:
    var st := str(r.get("state", ""))
    var texel: Vector2i = r.get("texel", Vector2i(-1, -1))
    if r.has("world"):
        var w: Vector2 = r["world"]
        where.text = "at %.0f, %.0f m (EPSG:5070)   texel %d, %d" % [w.x, w.y, texel.x, texel.y]
    else:
        where.text = ""

    match st:
        CellProbe.NO_GROUND:
            state.text = "NO GROUND — " + str(r.get("why", ""))
            key.text = ""
            value.text = ""
        CellProbe.NO_KEY:
            state.text = "NO RESIDENCE KEY — " + str(r.get("why", ""))
            key.text = "elevation %.1f m" % float(r.get("elevation_m", NAN))
            value.text = ""
        CellProbe.NO_CELL:
            state.text = "NO CELL — " + str(r.get("why", ""))
            key.text = _key_line(r)
            value.text = ""
        CellProbe.RESOLVED:
            state.text = "resolved"
            key.text = _key_line(r)
            value.text = _value_line(r)
        _:
            state.text = NOT_PROBED
            key.text = ""
            value.text = ""

    if st == CellProbe.RESOLVED or st == CellProbe.NO_CELL:
        _show_series(r)
    else:
        series_caption.text = ""
        series.clear()
        absent_rows.text = ""


## The node's own time series, and the standing of the rows there is no series
## for. The node axis position comes from `FixtureLoader.node_index_of`, which
## reads the manifest's `node_order`.
func _show_series(r: Dictionary) -> void:
    var window := str(r.get("window", ""))
    var carried := PackedStringArray() if _fl == null else _fl.row_names(window, "node")
    var missing := PackedStringArray()
    for row in NODE_ROWS:
        if not carried.has(row):
            missing.append(str(row))
    absent_rows.text = "" if missing.is_empty() else (
            "%s: not on the wire. Contract v2.0 advanced its major for \"row removed or "
            % ", ".join(missing)
            + "renamed\" (decision 901); the fixture's carried set does not hold it. "
            + "Absent upstream, not omitted here.")

    var axis := int(r.get("node_axis", -1))
    if _fl == null or axis < 0 or not carried.has("node.streamflow"):
        series_caption.text = "no node series for this cell"
        series.clear()
        return
    var s := SeriesPlot.series_for(_fl, window, "node.streamflow", axis)
    series.show_series(s, int(r.get("day", -1)))
    series_caption.text = ("node.streamflow  node %s (axis %d), %d days — "
            + "%d on scale, %d below it, %d no flow%s") % [
            str(r.get("huc10", "?")), axis, s.size(), series.counts["in_scale"],
            series.counts["below"], series.counts["zero"],
            "" if int(series.counts["no_value"]) == 0
                    else ", %d with no value" % int(series.counts["no_value"])]


func _key_line(r: Dictionary) -> String:
    return "node %s  band %d  →  cell %d   (node axis %d, elevation %.1f m)" % [
            str(r.get("huc10", "?")), int(r.get("band", -1)), int(r.get("cell", -1)),
            int(r.get("node_axis", -1)), float(r.get("elevation_m", NAN))]


func _value_line(r: Dictionary) -> String:
    var head := "%s  day %d" % [str(r.get("row", "?")), int(r.get("day", -1)) + 1]
    if not bool(r.get("has_value", false)):
        # Not "0" and not blank: the fixture stores NAN for nodata precisely
        # because zero is a real value for every one of these rows.
        return "%s — no value: %s" % [head, str(r.get("why", "absent"))]
    return "%s = %s" % [head, String.num(float(r["value"]), 6)]


func _line(font_size: int = 0) -> Label:
    var l := Label.new()
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(400, 0)
    if font_size > 0:
        l.add_theme_font_size_override("font_size", font_size)
    add_child(l)
    return l


## M5's scatter, reported where the click that caused it is reported.
##
## THE SHARE IS ON SCREEN FOR THE SAME REASON THE CONTOUR LEGEND'S IS. What the
## wire implies is very often more instances than a frame can hold -- grass runs
## to millions per square kilometre -- and the scatter draws one stated share
## across every family rather than thinning quietly. A picture at a share of
## 1e-4 is a sample of a stand, and it is only readable as one if the number is
## next to it.
func show_scatter(r: Dictionary) -> void:
    if not bool(r.get("ok", false)):
        scatter_line.text = "scatter: %s" % str(r.get("why", "not built"))
        scatter_where.text = ""
        scatter_share.text = ""
        return
    var parts := PackedStringArray()
    var placed: Dictionary = r.get("placed", {})
    var implied: Dictionary = r.get("implied", {})
    for life_form in r.get("groups", []):
        parts.append("%s %d/%s" % [life_form, int(placed.get(life_form, 0)),
                _si(float(implied.get(life_form, 0.0)))])
    scatter_line.text = "scatter %.0f m horizon, %d texels — %s (drawn/implied)" % [
            float(r.get("radius_m", 0.0)), int(r.get("texels", 0)), " ".join(parts)]

    # WHY THE WINDOW CAN LOOK EMPTY. The overview camera shows 1,545,600 m of
    # basin; the scatter is 3,000 m across. Everything can be working and the
    # result still lands on about one pixel, and a viewer has no way to tell
    # that from nothing having happened.
    var px := float(r.get("on_screen_px", NAN))
    if not is_nan(px):
        if px < 8.0:
            scatter_where.text = ("the whole scatter is %s px across at this camera — press %s "
                    + "to stand in it") % [String.num(px, 1), str(r.get("focus_key", "G"))]
        else:
            scatter_where.text = "the scatter is %s px across at this camera" % String.num(px, 0)

    var budget: Dictionary = r.get("budget", {})
    var share := float(r.get("share_drawn", 1.0))
    if not bool(budget.get("ok", false)):
        scatter_share.text = "no frame-cost budget: %s" % str(budget.get("why", ""))
        return
    # NOTE: GDScript's format has no %g. It fails at runtime rather than at
    # parse, exactly as burn_edge.gd records for %e, so the share goes through
    # String.num instead.
    scatter_share.text = ("share drawn %s — the wire implies %s instances at %.1f ms; "
            + "the %.1f ms budget holds %s on %s") % [
            String.num(share, 5), _si(float(budget.get("implied_total", 0.0))),
            float(budget.get("implied_ms", 0.0)), float(budget.get("budget_ms", 0.0)),
            _si(float(budget.get("instances", 0.0))), str(budget.get("measured_on", "?"))]


## Counts here span single instances to billions, and a raw integer at either
## end is unreadable next to the other.
func _si(v: float) -> String:
    if v < 1000.0:
        return str(int(round(v)))
    for pair in [[1.0e9, "G"], [1.0e6, "M"], [1.0e3, "k"]]:
        if v >= float(pair[0]):
            return "%.1f%s" % [v / float(pair[0]), str(pair[1])]
    return str(int(round(v)))
