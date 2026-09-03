class_name ContourSet
extends RefCounted

## Pre-extracted contours of a band-quantised field, as the client reads them.
## M4.
##
## EXTRACTION IS SERVER-SIDE (§16.12.1, decision 296) AND THERE IS NO FALLBACK
## HERE. If the artefact is absent, this says so and nothing is drawn. The
## level set is computable only from the sixteen HUC4 band ladders, which is
## the generator §16.12 keeps off the wire -- so a client-side "approximate"
## contour would not be a convenience, it would be that generator rebuilt
## badly and wearing the same line.
##
## THE LINE IS BROKEN AND MUST STAY BROKEN (decision 890). A cell is contoured
## only where its four corners carry one node index, so the arcs stop at the
## divides between nodes that hold no crossing -- 39.6% of the boundary on
## this window's peak day. Closing those gaps, smoothing across them, or
## joining one arc's endpoint to the next would draw the lattice, and the
## result would look BETTER than the honest one for being continuous.
## `standing()` carries the day's share so a viewer can read a gap as a
## statement rather than as a rendering fault.
##
## NOTHING HERE RESAMPLES OR SIMPLIFIES. The corridor is one band, 300 m
## (§16.7), and the manifest's `corridor_m` is a measurement of the vertices
## as shipped -- 149.7 m to the nearer band midpoint at this window's worst.
## A simplification pass would move them inside a corridor whose width is a
## ruling, so it would owe a measured deviation rather than a chosen
## tolerance. The vertices are drawn as sent: 9,292 on the busiest day, which
## is not a budget worth buying with a measurement nobody has taken.

const DIR := "res://assets/contours/"

var manifest: Dictionary = {}
var window: String = ""
var row: String = ""
var unit: String = ""
var threshold: float = 0.0
var threshold_standing: String = ""
var why_absent: String = ""      ## non-empty iff `is_loaded()` is false

var _bin_path: String = ""
var _days: Dictionary = {}


## Every contour set vendored into `dir_path`, keyed by window.
##
## Read from the directory rather than from a list of windows in this file: a
## set vendored later must appear without an edit here, the same way the
## scrubber takes its rows from the fixture instead of a constant.
static func discover(dir_path: String = DIR) -> Dictionary:
    var out: Dictionary = {}
    var names := DirAccess.get_files_at(dir_path)
    for n in names:
        if not n.begins_with("contours_") or not n.ends_with(".json"):
            continue
        var cs := ContourSet.load_from(dir_path + n)
        if cs.is_loaded():
            out[cs.window] = cs
        else:
            push_warning("contours: %s -- %s" % [n, cs.why_absent])
    return out


static func load_from(manifest_path: String) -> ContourSet:
    var cs := ContourSet.new()
    if not FileAccess.file_exists(manifest_path):
        cs.why_absent = "no manifest at %s" % manifest_path
        return cs
    var f := FileAccess.open(manifest_path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        cs.why_absent = "%s is not a JSON object" % manifest_path
        return cs
    cs.manifest = parsed
    cs.window = str(parsed.get("window", ""))
    cs.row = str(parsed.get("row", ""))
    cs.unit = str(parsed.get("unit", ""))
    cs.threshold = float(parsed.get("threshold", 0.0))
    cs.threshold_standing = str(parsed.get("threshold_standing", ""))
    cs._days = parsed.get("days", {})
    var payload: Dictionary = parsed.get("payload", {})
    cs._bin_path = manifest_path.get_base_dir() + "/" + str(payload.get("file", ""))
    if not FileAccess.file_exists(cs._bin_path):
        cs.why_absent = "the manifest names %s, which is not beside it" % cs._bin_path
        cs._days = {}
    return cs


func is_loaded() -> bool:
    return not _days.is_empty() and FileAccess.file_exists(_bin_path)


func day_count() -> int:
    return _days.size()


func has_day(day: int) -> bool:
    return _days.has(str(day))


## One day's arcs, as world polylines in EPSG:5070 metres.
##
## A day's arcs start at its `byte_offset` and run in the order of
## `arc_vertex_counts`; the counts are what separates one arc from the next,
## and they are the reason the file needs no terminator. Reading past the end
## of the day's own span would silently take the next day's first arc and draw
## it as this one's -- so the span is read once, up front, and the arcs are
## cut out of it.
func arcs_for_day(day: int) -> Array:
    var out: Array = []
    var d: Variant = _days.get(str(day), null)
    if d == null:
        return out
    var counts: Array = d["arc_vertex_counts"]
    var n_vertices := int(d["vertex_count"])
    var f := FileAccess.open(_bin_path, FileAccess.READ)
    if f == null:
        push_error("contours: cannot open %s" % _bin_path)
        return out
    f.seek(int(d["byte_offset"]))
    var raw := f.get_buffer(n_vertices * 8)
    if raw.size() != n_vertices * 8:
        push_error("contours: day %d wanted %d vertices and the file held %d bytes"
                % [day, n_vertices, raw.size()])
        return out
    var at := 0
    for c in counts:
        var n := int(c)
        var arc := PackedVector2Array()
        arc.resize(n)
        for i in n:
            var o := (at + i) * 8
            arc[i] = Vector2(float(raw.decode_s32(o)), float(raw.decode_s32(o + 4)))
        at += n
        out.append(arc)
    return out


## What the day's geometry does and does not claim.
##
## `share_drawn` is the fraction of the field's sign changes that became a
## line. The rest fell on divides between nodes that hold no crossing, and are
## DECLINED rather than bridged -- the arcs are correct and incomplete, which
## is a different thing from an artefact that is missing part of itself.
func standing(day: int) -> Dictionary:
    var d: Variant = _days.get(str(day), null)
    if d == null:
        return {"day": day, "has_day": false,
                "verdict": "no arcs were extracted for day %d" % day}
    var share := float(d["share_drawn"])
    var declined := int(d["boundary_crossings_not_drawn"])
    var corridor: Dictionary = d.get("corridor_m", {})
    return {
        "day": day,
        "has_day": true,
        "arcs": int(d["arc_count"]),
        "vertices": int(d["vertex_count"]),
        "length_km": float(d["length_km"]),
        "share_drawn": share,
        "declined_crossings": declined,
        "nodes_with_a_crossing": int(d["nodes_with_a_crossing"]),
        "corridor_m": float(corridor.get("max_m_to_nearer_band_midpoint", 0.0)),
        "band_m": float(corridor.get("max_m_between_the_two_midpoints", 0.0)),
        "verdict": ("%.1f%% of the boundary is drawn from the field; %d crossings fall on "
                + "divides between nodes that hold no crossing and are declined rather "
                + "than bridged (decision 890)") % [share * 100.0, declined],
    }


## The set's own description, threshold standing included, so a caller cannot
## show the line without the fact that 0.02 m is a display choice travelling
## with it.
func describe() -> Dictionary:
    return {
        "window": window,
        "row": row,
        "threshold": threshold,
        "unit": unit,
        "days": day_count(),
        "threshold_standing": threshold_standing,
        "extraction": "server-side (§16.12.1); no client-side fallback exists",
    }
