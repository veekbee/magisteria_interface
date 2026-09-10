class_name FlowDisplay
extends RefCounted

## Streamflow on flowlines. M3.
##
## THE MAPPING HERE IS PROVISIONAL AND SAYS SO. Streamflow in this window spans
## 4.9e-324 to 982.8 m3/s -- not a range any single ramp represents. Measured
## over the fire window: 13.2% of samples are exactly zero, 40.9% of the
## non-zero ones are below 1e-6, the median is 0.0063 and p99 is 321.7. A
## linear ramp over the contract's [0, 100000] draws almost every reach
## identically; a log ramp over the true non-zero range spans three hundred
## decades and is no better.
##
## So this uses a log ramp over a STATED, FINITE window and marks what falls
## outside it, rather than choosing a scale and presenting it as the scale:
##
##   * exactly zero        -> NO_FLOW, drawn distinctly. Zero is a real state
##                            here, not a small number, and 13.2% of samples
##                            are it.
##   * below the window    -> BELOW_SCALE, drawn distinctly. Present, measured,
##                            and smaller than this display resolves -- which
##                            is not the same as absent.
##   * inside the window   -> the ramp.
##   * nothing known       -> NO_INFO, and this one was NO_FLOW until the drape
##                            started reading a bundle.
##
## Which window, and whether zero and below-scale should be distinguishable at
## all, is a display ruling nobody has made. Until it is, drawing them the same
## as "very little water" would be this project's plausible-zero (§23.819) in
## the one place a viewer would never question it.
##
## AND THAT IS EXACTLY WHAT THIS FILE WAS DOING TO A FOURTH STATE. `colour_for`
## took a NAN and returned NO_FLOW -- so a reach the client knew nothing about
## was drawn as a channel with no water in it. Against the fixture that was
## nearly harmless: every reach with a node had a value. Against a producer
## that gives an observer only what they have earned it is the plausible-zero
## in its purest form, because the wire's silence is the common case beyond the
## earned horizon and a dry river is a statement about the world.
##
## THREE REASONS TO KNOW NOTHING, ONE COLOUR, THREE COUNTS. The display has one
## thing to say -- nothing is known here -- and the report says which of the
## three it was:
##
##   NO_NODE    -- the flowline export gives this reach no node. About the MAP.
##   NOT_KEYED  -- the reach has a node and the bundle's node axis does not
##                 carry it. About what this OBSERVER was given.
##   NODATA     -- keyed, and the value is NAN. About the MOMENT.
##
## Folding them into one count would lose the only distinction that matters
## later: the first is a defect in the geometry, the second is the percept
## working, and the third is the world.

const DECADE_LO := -3.0        ## 1e-3 m3/s
const DECADE_HI := 3.0         ## 1e3  m3/s
const NO_FLOW := Color(0.20, 0.20, 0.24)
const BELOW_SCALE := Color(0.35, 0.20, 0.45)
## Nothing known. Warm and desaturated so it reads as absence of information
## rather than as a low value on a blue ramp -- NO_FLOW is a dark blue-grey and
## sits at the ramp's cold end, which is precisely why it could stand in for
## "no water" and must not stand in for "no news".
const NO_INFO := Color(0.42, 0.38, 0.32)

const NO_NODE := "NO_NODE"
const NOT_KEYED := "NOT_KEYED"
const NODATA := "NODATA"

var n_zero: int = 0
var n_below: int = 0
var n_in_scale: int = 0
var n_no_node: int = 0
var n_not_keyed: int = 0
var n_nodata: int = 0


## `provisional` is stated in the returned report so a caller cannot use this
## without the fact travelling with it.
func describe() -> Dictionary:
    return {
        "mapping": "log10 over [1e%d, 1e%d] m3/s" % [int(DECADE_LO), int(DECADE_HI)],
        "provisional": true,
        "why_provisional": ("streamflow spans 4.9e-324 to 982.8 m3/s in this window; no "
                + "single ramp represents that. The window is stated rather than fitted, "
                + "and zero and below-scale are drawn distinctly rather than as "
                + "'very little water'."),
        "zero": ("drawn as NO_FLOW -- 13.2% of samples are exactly zero and that is a "
                + "state, not a small number"),
        "below_scale": ("drawn as BELOW_SCALE -- present and measured, smaller than this "
                + "display resolves, which is not the same as absent"),
        "no_info": ("drawn as NO_INFO and never as NO_FLOW -- a reach nothing is known "
                + "about is not a channel with no water in it. Three reasons, counted "
                + "apart: no_node is about the map, not_keyed is about what this observer "
                + "was given, nodata is about the moment."),
        "counts": {"zero": n_zero, "below_scale": n_below,
                   "in_scale": n_in_scale, "no_node": n_no_node,
                   "not_keyed": n_not_keyed, "nodata": n_nodata},
        "known": n_zero + n_below + n_in_scale,
        "unknown": n_no_node + n_not_keyed + n_nodata,
    }


func reset_counts() -> void:
    n_zero = 0
    n_below = 0
    n_in_scale = 0
    n_no_node = 0
    n_not_keyed = 0
    n_nodata = 0


## A reach nothing is known about, and WHY nothing is known. One colour, three
## counts -- see the header for what each of them is a fact about.
##
## SEPARATE FROM `colour_for` AND NOT A NAN CASE OF IT. The caller is the only
## one that can tell the three apart, so the caller says which; a single
## entry point taking NAN could only ever have reported one of them, which is
## how all three came to be drawn as no water.
func colour_for_absence(reason: String) -> Color:
    match reason:
        NO_NODE:
            n_no_node += 1
        NOT_KEYED:
            n_not_keyed += 1
        _:
            n_nodata += 1
    return NO_INFO


func colour_for(flow: float) -> Color:
    if is_nan(flow):
        # A KEYED NODE WHOSE VALUE IS NAN. Routed through the absence path so
        # it is counted as what it is; the ramp never sees a NAN.
        return colour_for_absence(NODATA)
    if flow <= 0.0:
        n_zero += 1
        return NO_FLOW
    var l := log(flow) / log(10.0)
    if l < DECADE_LO:
        n_below += 1
        return BELOW_SCALE
    n_in_scale += 1
    var t: float = clampf((l - DECADE_LO) / (DECADE_HI - DECADE_LO), 0.0, 1.0)
    # Pale blue to deep blue: a single hue, because flow has one direction of
    # "more" and a multi-hue ramp would invite reading a category into it.
    return Color(0.55, 0.78, 0.95).lerp(Color(0.02, 0.16, 0.55), t)
