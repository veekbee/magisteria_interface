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
##
## Which window, and whether zero and below-scale should be distinguishable at
## all, is a display ruling nobody has made. Until it is, drawing them the same
## as "very little water" would be this project's plausible-zero (§23.819) in
## the one place a viewer would never question it.

const DECADE_LO := -3.0        ## 1e-3 m3/s
const DECADE_HI := 3.0         ## 1e3  m3/s
const NO_FLOW := Color(0.20, 0.20, 0.24)
const BELOW_SCALE := Color(0.35, 0.20, 0.45)

var n_zero: int = 0
var n_below: int = 0
var n_in_scale: int = 0
var n_no_node: int = 0


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
        "counts": {"zero": n_zero, "below_scale": n_below,
                   "in_scale": n_in_scale, "no_node": n_no_node},
    }


func reset_counts() -> void:
    n_zero = 0
    n_below = 0
    n_in_scale = 0
    n_no_node = 0


func colour_for(flow: float) -> Color:
    if is_nan(flow):
        n_no_node += 1
        return NO_FLOW
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
