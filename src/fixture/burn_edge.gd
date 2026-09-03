class_name BurnEdge
extends RefCounted

## Decision 892's burn perimeter. M3.
##
## 892 rules a burn perimeter a physically real edge, to be DRAWN as an edge
## rather than blended away. This class decides whether this fixture contains
## one -- and on this trace it does not.
##
## A perimeter needs an inside and an outside. Measured over the fire window:
## `band.burned_fraction` peaks at 4.6e-05 and **5,522 of 5,684 cells burn at
## some point**, so at any threshold below the peak nearly the whole basin is
## "inside" and above it nothing is. There is no closed curve to draw; there is
## a uniform trace of burning at a vanishing level.
##
## So this REPORTS rather than draws. Contouring the field anyway would produce
## a curve wherever the threshold happened to cut the noise, and it would look
## exactly like a fire boundary -- decision 892's own objection to drawing the
## simulation's file format on the ground, arriving as a drawn edge that
## corresponds to nothing.
##
## The run's own acceptance verdict records fire among its failing criteria, so
## the absence is consistent with what the trace is known to be. When a run
## produces a real perimeter this class will find one, and `has_edge()` is what
## a caller should ask before drawing.

#: A perimeter encloses a minority; beyond this it is a threshold through the
#: middle of a field rather than a boundary.
const MAX_INSIDE_FRACTION := 0.25

#: Below this peak burned fraction there is nothing worth drawing a boundary
#: around. PROVISIONAL and display-side: 1% of a band is a legible statement
#: about the ground, but which level counts as "burned" for rendering is not
#: ruled anywhere, and this constant is where a ruling would land.
const MIN_DRAWABLE_FRACTION := 0.01

var threshold: float = 0.0
var cells_inside: int = 0
var cells_total: int = 0
var max_value: float = 0.0
var verdict: String = ""


## Measure the field's edge structure at a set of thresholds.
##
## `fraction_inside` at every candidate threshold is the diagnostic: an edge
## exists when some threshold puts a *minority* of cells inside. If every
## threshold gives ~everything or ~nothing, the field is a smear.
func measure(values: PackedFloat64Array) -> Dictionary:
    cells_total = values.size()
    max_value = 0.0
    for v in values:
        if not is_nan(v):
            max_value = max(max_value, v)
    var sweep := []
    var best_frac := 0.0
    var best_t := 0.0
    for k in 9:
        var t: float = max_value * float(k + 1) / 10.0
        if t <= 0.0:
            continue
        var inside := 0
        for v in values:
            if not is_nan(v) and v >= t:
                inside += 1
        var frac := float(inside) / float(max(cells_total, 1))
        sweep.append({"threshold": t, "fraction_inside": frac})
        # A perimeter bounds a MINORITY. The first version of this maximised
        # the fraction under a half and duly proposed a "perimeter" enclosing
        # 46% of the basin -- a threshold cutting through the middle of a
        # smooth field, which is the opposite of an edge.
        if frac > 0.005 and frac <= MAX_INSIDE_FRACTION:
            if best_t <= 0.0 or frac > best_frac:
                best_frac = frac
                best_t = t
    threshold = best_t
    cells_inside = int(best_frac * float(cells_total))
    # MAGNITUDE FIRST. A boundary around cells at 4.6e-05 burned fraction is a
    # boundary around nothing: it is 0.005% of a band, four orders below any
    # level at which "this burned" is a statement about the ground. The sweep
    # will happily find a threshold at any magnitude, so the magnitude has to
    # be asked about separately or the geometry answers a question nobody put.
    if max_value < MIN_DRAWABLE_FRACTION:
        threshold = 0.0
        cells_inside = 0
        verdict = ("nothing burned to a drawable degree: peak burned fraction is "
                + String.num_scientific(max_value) + ", below the "
                + String.num_scientific(MIN_DRAWABLE_FRACTION) + " floor. A sweep still "
                + "finds thresholds -- it always does -- but a perimeter here would "
                + "enclose cells that did not meaningfully burn. The run's own "
                + "acceptance verdict records fire among its failing criteria.")
    elif max_value <= 0.0:
        verdict = "nothing burned in this window -- no edge to draw"
    elif best_t <= 0.0:
        # NOTE: GDScript's format has no %e. Scientific notation goes through
        # String.num_scientific; %e silently fails at runtime, which is how the
        # first version of this line got as far as being run.
        verdict = ("no threshold separates a minority from a majority: the field is a "
                + "uniform trace at a vanishing level, not a perimeter. Peak "
                + String.num_scientific(max_value) + " over "
                + str(cells_total) + " cells.")
    else:
        verdict = ("a perimeter exists at " + String.num_scientific(best_t)
                + " (" + String.num(best_frac * 100.0, 1) + "% of cells inside)")
    return {"threshold": threshold, "cells_inside": cells_inside,
            "cells_total": cells_total, "max_value": max_value,
            "has_edge": has_edge(), "verdict": verdict, "sweep": sweep}


func has_edge() -> bool:
    return threshold > 0.0 and cells_inside > 0
