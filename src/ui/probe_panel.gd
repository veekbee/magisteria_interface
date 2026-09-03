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

const NOT_PROBED := "click the terrain to probe a cell"

var heading: Label
var where: Label
var state: Label
var key: Label
var value: Label


func setup() -> void:
    custom_minimum_size = Vector2(420, 0)
    heading = _line(18)
    heading.text = "probe"
    where = _line()
    state = _line()
    key = _line()
    value = _line()
    clear()


func clear() -> void:
    where.text = ""
    state.text = NOT_PROBED
    key.text = ""
    value.text = ""


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
