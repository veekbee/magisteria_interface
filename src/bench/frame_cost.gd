class_name FrameCost
extends RefCounted

## What `measurements/render_cost.json` says a scatter will cost. M5 reads it
## so a density is measured against the engine rather than guessed at.
##
## THE MEASUREMENT IS THE AUTHORITY AND IT IS NOT PORTABLE. Everything here is
## a reading of an artefact this repo produced on one machine with one
## renderer; on other hardware the numbers are wrong and the artefact says so.
## A caller that cannot find the measurement gets a refusal rather than a
## default, because a default here is exactly the plausible number §19.8.9
## declined to write.
##
## THE MODEL IS THE ONE THE MEASUREMENT SUPPORTS, and no more. The benchmark
## measured three mesh complexities per technique, and MultiMesh cost per
## instance came out very close to linear in triangle count: about 14 ns at 12
## triangles, 56 at 288, 400 at 2,400. A line through those three points is a
## fit to three points and is stated as such -- it is used to price a 44-triangle
## family that sits inside the measured span, and it is refused outside it,
## because extrapolating a three-point line is how a measurement turns back
## into a guess.

const ARTEFACT := "res://measurements/render_cost.json"

var budget_ms: float = 0.0
var host: Dictionary = {}
var why_absent: String = ""

## Per-instance cost as `intercept_ns + slope_ns * triangles`, fitted across
## the complexities measured for one technique.
var intercept_ns: float = 0.0
var slope_ns_per_triangle: float = 0.0
var technique: String = ""
var triangles_measured: PackedFloat64Array = PackedFloat64Array()


static func load_from(technique_: String = "multimesh",
                      path: String = ARTEFACT) -> FrameCost:
    var fc := FrameCost.new()
    fc.technique = technique_
    if not FileAccess.file_exists(path):
        fc.why_absent = ("no measurement at %s. Per-instance frame cost requires the "
                + "engine (§19.8.9); run tools/run_benchmark.sh on this machine.") % path
        return fc
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        fc.why_absent = "%s is not a JSON object" % path
        return fc
    var doc: Dictionary = parsed
    if bool(doc.get("refused", false)):
        fc.why_absent = "the measurement was refused: %s" % str(doc.get("why", ""))
        return fc
    fc.budget_ms = float(doc.get("budget_ms", 0.0))
    fc.host = doc.get("host", {})

    # Per-instance nanoseconds at each measured complexity, taken from the
    # largest rung of each sweep: that is where the fixed per-frame cost is
    # smallest against the per-instance one, so it is where the per-instance
    # figure is least contaminated by it.
    var top: Dictionary = {}
    for r in doc.get("results", []):
        if not bool(r.get("measured", false)) or str(r.get("technique", "")) != technique_:
            continue
        var tris := float(r.get("triangles_per_instance", 0))
        var n := float(r.get("instances", 0))
        if tris <= 0.0 or n <= 0.0:
            continue
        var prev: Dictionary = top.get(tris, {})
        if prev.is_empty() or n > float(prev["instances"]):
            top[tris] = {"instances": n, "ms": float(r["frame_ms"]["p50"])}
    if top.size() < 2:
        fc.why_absent = ("%s measures %d mesh complexities for %s; a cost model needs at "
                + "least two") % [path, top.size(), technique_]
        return fc

    var xs := PackedFloat64Array()
    var ys := PackedFloat64Array()
    for tris in top:
        xs.append(float(tris))
        ys.append(float(top[tris]["ms"]) * 1.0e6 / float(top[tris]["instances"]))
    var fit := FrameStats.fit_linear(xs, ys)
    if not bool(fit.get("ok", false)):
        fc.why_absent = "the measured complexities do not support a cost model: %s" % str(fit)
        return fc
    fc.intercept_ns = float(fit["intercept_ms"])
    fc.slope_ns_per_triangle = float(fit["ms_per_instance"])
    fc.triangles_measured = xs
    return fc


func is_loaded() -> bool:
    return why_absent == "" and budget_ms > 0.0


func measured_span() -> Vector2:
    var lo := INF
    var hi := -INF
    for t in triangles_measured:
        lo = minf(lo, t)
        hi = maxf(hi, t)
    return Vector2(lo, hi)


## Nanoseconds per instance for a mesh of this many triangles.
##
## Refused outside the measured span. The model is a line through three
## measured points; carried past them it is an extrapolation wearing a
## measurement's name, which is the thing the artefact exists instead of.
func per_instance_ns(triangles: int) -> Dictionary:
    if not is_loaded():
        return {"ok": false, "why": why_absent}
    var span := measured_span()
    if float(triangles) < span.x or float(triangles) > span.y:
        return {"ok": false, "why": ("%d triangles is outside the measured span of %d..%d; "
                + "the model is a line through the complexities that were measured and "
                + "does not carry past them") % [triangles, int(span.x), int(span.y)]}
    return {"ok": true, "ns": intercept_ns + slope_ns_per_triangle * float(triangles)}


## What one frame of `instances` copies of a `triangles`-triangle mesh costs,
## and whether it fits the budget the measurement was taken against.
func predict(triangles: int, instances: int) -> Dictionary:
    var per := per_instance_ns(triangles)
    if not bool(per["ok"]):
        return {"ok": false, "why": str(per["why"])}
    var ms := float(per["ns"]) * float(instances) / 1.0e6
    return {
        "ok": true,
        "ms": ms,
        "budget_ms": budget_ms,
        "fits": ms <= budget_ms,
        "per_instance_ns": float(per["ns"]),
        "technique": technique,
        "measured_on": str(host.get("gpu", "?")) + " / " + str(host.get("rendering_method", "?")),
    }


## The largest instance count that fits the budget at this complexity.
func instances_within_budget(triangles: int) -> int:
    var per := per_instance_ns(triangles)
    if not bool(per["ok"]) or float(per["ns"]) <= 0.0:
        return 0
    return int(budget_ms * 1.0e6 / float(per["ns"]))
