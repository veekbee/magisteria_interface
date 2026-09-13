class_name HorizonSolve
extends RefCounted

## Decision 1030's solved instancing horizon. ONE implementation, because two
## copies of a formula are two things free to diverge (convention 4) and this
## one is read by both the headless distribution run and the windowed frame
## measurement -- which exist precisely to be compared against each other.
##
##     k(place) = min(0.35 * k_res,
##                    sqrt(B_eff / (pi * SUM_f cover_f * height_f^2 * c_f / crown_area_f)))
##     d_f      = s * k(place) * height_f
##
## The frame budget is the invariant and decision 949's constant is the ceiling,
## so the drawn world is unchanged wherever the place affords the ceiling.
##
## TERMINAL AND CLIENT-SIDE. Arithmetic over wire quantities and committed
## coefficients, read by nothing simulation-side, so decision 262's invariant
## extends unchanged and world state never depends on it.
##
## `s` IS NOT APPLIED HERE. It is §19.8.7's `detail_scale`, a controller output,
## and folding it in would make this function of the wire also a function of the
## last frame. Callers multiply. `k(place)` does not depend on it at all.

const CEILING_FRACTION := 0.35

## Decision 1030's drop-to-tint bound: a family whose solved `d_f` falls under
## the placement sub-cell goes to decision 890's field layer rather than the
## budget breaking.
const PLACEMENT_FLOOR_M := 31.25


## The ceiling decision 949's constant becomes, for a declared camera.
static func ceiling_for(viewport_height_px: float, fov_degrees: float) -> float:
    return CEILING_FRACTION * VegetationScatter.resolution_k(viewport_height_px, fov_degrees)


## `k(place)` for one cell, and the terms it was computed from.
##
## `per_family` is `{life_form: {"cover": f, "height_m": f, "crown_area_m2": f,
## "cost_ns": f}}` -- what the caller read off the wire and the cost artefact.
## A family the caller could not price is simply absent, and `priced` says how
## many were included, because a family missing from the denominator makes the
## denominator SMALLER and the solved `k` correspondingly TOO HIGH: the budget
## the solve then claims is not the budget the frame would spend.
static func k_for_cell(per_family: Dictionary, b_eff_ns: float, ceiling: float) -> Dictionary:
    var denom := 0.0
    var priced := 0
    for lf in per_family:
        var d: Dictionary = per_family[lf]
        var crown_area := float(d.get("crown_area_m2", 0.0))
        var cost := float(d.get("cost_ns", NAN))
        if crown_area <= 0.0 or is_nan(cost):
            continue
        var h := float(d.get("height_m", 0.0))
        denom += float(d.get("cover", 0.0)) * h * h * cost / crown_area
        priced += 1
    if denom <= 0.0 or b_eff_ns <= 0.0:
        return {"ok": false, "why": "nothing priced at this cell", "priced": priced}
    var solved := sqrt(b_eff_ns / (PI * denom))
    return {
        "ok": true,
        "k": minf(ceiling, solved),
        "k_solved": solved,
        "at_ceiling": solved >= ceiling,
        "denominator": denom,
        "priced": priced,
    }


## `d_f` for one family, given the place's `k` and the controller's scale.
static func horizon_m(k: float, height_m: float, detail_scale: float = 1.0) -> float:
    return detail_scale * k * height_m


## Whether that horizon falls under the placement floor, in which case decision
## 1030 drops the family to the field layer rather than breaking the budget.
static func drops_to_tint(d_f_m: float) -> bool:
    return d_f_m < PLACEMENT_FLOOR_M
