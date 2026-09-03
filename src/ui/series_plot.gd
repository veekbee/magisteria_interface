class_name SeriesPlot
extends Control

## `node.streamflow` over a window's days, for one probed node. M4.
##
## THE VERTICAL SCALE IS FlowDisplay'S, NOT A SECOND ONE. Streamflow spans
## 4.9e-324 to 982.8 m3/s in this window and no axis represents that.
## FlowDisplay already answers it for the flowlines -- a stated finite log
## window, with zero and below-scale drawn distinctly rather than as "very
## little water" -- and the plot has exactly the same problem. Two answers
## would let a reach and its own time series disagree about whether a day had
## no flow or a little, which is the disagreement a viewer has no way to
## adjudicate.
##
##   * exactly zero     -> its own row beneath the axis. A state, not a small
##                         number, and 13.2% of samples are it.
##   * below the window -> its own row. Present, measured, and smaller than
##                         this plot resolves; not the same as absent.
##   * on the scale     -> the log decades, FlowDisplay's own.
##   * no value at all  -> not drawn, and counted. A day the fixture holds
##                         nodata for is not a height on this axis.
##
## PLOTTED FROM float64, AND THAT IS LOAD-BEARING. `FixtureLoader.day_values`
## returns PackedFloat64Array because streamflow reaches 4.9e-324; float32
## flushes everything under 1.18e-38 to zero and would move thousands of
## samples out of "below the scale" and into "no flow" (§23.812). Godot's
## Vector2 is float32, so every sample is CLASSIFIED on the double before any
## of it becomes geometry -- the conversion happens after the meaning is
## fixed, which is the only order in which the container cannot change it.
##
## A SEGMENT JOINS TWO SAMPLES ONLY IF BOTH ARE ON THE SCALE. A line from an
## in-scale day down to a zero day would draw a descent through values the
## river never had, on an axis those values are not even on -- the same
## fabricated continuity the contour layer refuses at its gaps.

const ZERO := 0
const BELOW := 1
const IN_SCALE := 2
## Not a fourth height on the axis: a day with no value is not drawn at all.
## Placing it anywhere -- the zero row included -- would be the plausible zero
## (§23.819) at the one point of the plot a reader would never question.
const NO_VALUE := 3

## Where each class sits, as a fraction of the plot's height. The two rows are
## OUTSIDE the decades rather than at the bottom of them, because a sample
## drawn at the axis floor reads as the smallest value on the scale instead of
## as one that is not on it.
const SCALE_TOP := 0.06
const SCALE_BOTTOM := 0.66
const BELOW_ROW := 0.80
const ZERO_ROW := 0.92

const GRID := Color(0.30, 0.30, 0.34)
const LINE := Color(0.55, 0.78, 0.95)
const MARKER := Color(0.90, 0.85, 0.35)

var values: PackedFloat64Array = PackedFloat64Array()
var marked_day: int = -1
var counts := {"zero": 0, "below": 0, "in_scale": 0, "no_value": 0}


## Which class a value falls in: FlowDisplay's three, plus a day with no value
## at all. The thresholds are FlowDisplay's constants rather than copies.
static func band_of(v: float) -> int:
    if is_nan(v):
        return NO_VALUE
    if v <= 0.0:
        return ZERO
    return IN_SCALE if log(v) / log(10.0) >= FlowDisplay.DECADE_LO else BELOW


## Vertical position as a fraction of the plot, 0 at the top. NAN for a day
## with no value, which has no position because it has nothing to be at.
static func y_fraction(v: float) -> float:
    match band_of(v):
        NO_VALUE:
            return NAN
        ZERO:
            return ZERO_ROW
        BELOW:
            return BELOW_ROW
        _:
            var l := log(v) / log(10.0)
            var t: float = clampf((l - FlowDisplay.DECADE_LO)
                    / (FlowDisplay.DECADE_HI - FlowDisplay.DECADE_LO), 0.0, 1.0)
            return SCALE_BOTTOM - t * (SCALE_BOTTOM - SCALE_TOP)


## May a segment be drawn between two consecutive samples? Only if both are
## on the scale. A line from an in-scale day to a zero or below-scale day
## would descend through values the river never had, on a part of the plot
## those values are not even measured on -- the fabricated continuity the
## contour layer refuses at its gaps, arriving in a chart instead.
static func joins(a: float, b: float) -> bool:
    return band_of(a) == IN_SCALE and band_of(b) == IN_SCALE


## One node's row over every day of a window.
##
## Read day by day through `day_values`, which is the only reader that decodes
## the fixture's float64 rows as float64. The node's position on the axis is
## the caller's, from `FixtureLoader.node_index_of` -- never the order ids
## appear in `cell_keys`, which agrees today and would plot the wrong river's
## flow while looking entirely plausible.
static func series_for(fl: FixtureLoader, window: String, row: String,
                       node_axis: int) -> PackedFloat64Array:
    var out := PackedFloat64Array()
    if fl == null or node_axis < 0:
        return out
    var n := fl.days(window, row)
    for day in n:
        var vals := fl.day_values(window, row, day)
        if node_axis >= vals.size():
            return PackedFloat64Array()
        out.append(vals[node_axis])
    return out


func show_series(series: PackedFloat64Array, day: int) -> void:
    values = series
    marked_day = day
    counts = {"zero": 0, "below": 0, "in_scale": 0, "no_value": 0}
    for v in values:
        match band_of(v):
            NO_VALUE:
                counts["no_value"] += 1
            ZERO:
                counts["zero"] += 1
            BELOW:
                counts["below"] += 1
            _:
                counts["in_scale"] += 1
    queue_redraw()


func clear() -> void:
    values = PackedFloat64Array()
    marked_day = -1
    counts = {"zero": 0, "below": 0, "in_scale": 0, "no_value": 0}
    queue_redraw()


func _draw() -> void:
    var w := size.x
    var h := size.y
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.10, 0.12))
    if h <= 0.0 or w <= 0.0:
        return
    var font := get_theme_default_font()
    var fs := 10

    # the decades, then the two rows that are not on them
    for k in range(int(FlowDisplay.DECADE_LO), int(FlowDisplay.DECADE_HI) + 1):
        var y := y_fraction(pow(10.0, float(k))) * h
        draw_line(Vector2(0.0, y), Vector2(w, y), GRID, 1.0)
        if font != null:
            draw_string(font, Vector2(2.0, y - 1.0), "1e%d" % k,
                    HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GRID)
    for pair in [[BELOW_ROW, "below scale", FlowDisplay.BELOW_SCALE],
                 [ZERO_ROW, "no flow", FlowDisplay.NO_FLOW]]:
        var y: float = float(pair[0]) * h
        draw_line(Vector2(0.0, y), Vector2(w, y), pair[2], 1.0)
        if font != null:
            draw_string(font, Vector2(2.0, y - 1.0), str(pair[1]),
                    HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pair[2])

    if values.is_empty():
        return
    var n := values.size()
    var dx := w / float(maxi(n - 1, 1))
    for i in n:
        var b := band_of(values[i])
        if b == NO_VALUE:
            continue
        var x := float(i) * dx
        var y := y_fraction(values[i]) * h
        if i > 0 and joins(values[i - 1], values[i]):
            draw_line(Vector2(x - dx, y_fraction(values[i - 1]) * h), Vector2(x, y), LINE, 1.5)
        var col: Color = LINE
        if b == ZERO:
            col = FlowDisplay.NO_FLOW
        elif b == BELOW:
            col = FlowDisplay.BELOW_SCALE
        draw_rect(Rect2(x - 1.0, y - 1.0, 2.0, 2.0), col)

    if marked_day >= 0 and marked_day < n:
        var mx := float(marked_day) * dx
        draw_line(Vector2(mx, 0.0), Vector2(mx, h), MARKER, 1.0)
