class_name ContourLegend
extends VBoxContainer

## What the contour layer is drawing, and what it is declining to draw. M4.
##
## THE SHARE BELONGS ON SCREEN, NOT IN THE LOG. The line is broken by ruling
## (decision 890) and a broken line looks like a rendering fault; without a
## legend saying how much of the boundary is real, the honest artefact reads
## as a defective one and the dishonest continuous version reads as correct.
## FieldScrubber's refused-row label is the precedent: a control that shows
## only what it could draw makes an unresolved question look like a design.
##
## The row is named on every line the layer draws, because the contour keeps
## its own meaning while the terrain underneath shows whichever row the
## scrubber selected. A snowline over a wetness field is legible; an unlabelled
## line over a wetness field is a claim about wetness.

var title: Label
var standing: Label
var day_line: Label
var geometry: Label


func setup() -> void:
    custom_minimum_size = Vector2(420, 0)
    title = _line(18)
    standing = _line()
    day_line = _line()
    geometry = _line()
    show_absent("")


func show_set(cs: ContourSet, day: int, drape: Dictionary) -> void:
    title.text = "contour  %s ≥ %s %s" % [cs.row, String.num(cs.threshold, 4), cs.unit]
    standing.text = "threshold: " + _trim(cs.threshold_standing, 200)
    var st := cs.standing(day)
    if not bool(st.get("has_day", false)):
        day_line.text = "day %d — %s" % [day + 1, str(st["verdict"])]
        geometry.text = ""
        return
    day_line.text = "day %d of %d — %.1f%% drawn from the field, %d crossings declined at divides (decision 890)" % [
            day + 1, cs.day_count(), float(st["share_drawn"]) * 100.0,
            int(st["declined_crossings"])]
    geometry.text = ("%d arcs, %d runs, %d vertices off the heightfield, %d splits; "
            + "within %.0f m of the nearer band midpoint of a %.0f m band (§16.7)") % [
            int(st["arcs"]), int(drape.get("runs", 0)), int(drape.get("dropped_offmap", 0)),
            int(drape.get("splits", 0)), float(st["corridor_m"]), float(st["band_m"])]


## No set for this window is a statement, not an empty panel. Extraction is
## server-side, so the absence is answered upstream and never here.
func show_absent(window: String) -> void:
    title.text = "contour  none for this window"
    standing.text = ("no contour set is vendored for %s. Extraction is server-side "
            + "(§16.12.1); nothing is approximated here.") % (
                    window if window != "" else "the selected window")
    day_line.text = ""
    geometry.text = ""


func _trim(s: String, n: int) -> String:
    return s if s.length() <= n else s.substr(0, n).strip_edges() + "…"


func _line(font_size: int = 0) -> Label:
    var l := Label.new()
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(400, 0)
    if font_size > 0:
        l.add_theme_font_size_override("font_size", font_size)
    add_child(l)
    return l
