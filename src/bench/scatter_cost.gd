class_name ScatterCost
extends RefCounted

## What M5's scatter actually costs a frame, measured on the running viewer.
##
## WHY THIS EXISTS SEPARATELY FROM THE BENCHMARK. `measurements/render_cost.json`
## prices instancing on an empty stage: a placeholder mesh over a flat square,
## no terrain, no culling, no LOD. That is the right shape for a coefficient --
## a basin underneath would make it a joint measurement of two things and let
## neither be recovered -- but it means every statement M5 makes about a frame
## is a PREDICTION from that coefficient rather than an observation of a frame.
## The 1,500 m horizon figure was reported by the scatter at runtime and
## committed nowhere, which makes it a number with a derivation and no artefact.
##
## SO THIS MEASURES THE DIFFERENCE, NOT THE FRAME. The same scene is timed
## twice, once with the scatter drawn and once with it hidden, and the scatter's
## cost is what separates them. A single timing of the viewer would be the
## terrain, the flowlines, the contours, the overlay and the scatter added
## together, and no amount of arithmetic recovers one term of that sum.
##
## IT CHECKS THE FRAMES WERE DRAWN, for the reason the benchmark checks: an
## occluded window on this platform stops rendering while the main loop keeps
## ticking, and the frames come back on a fixed cadence that looks exactly like
## a cheap scene. Here there is a second, stronger check available that the
## benchmark could not use -- the primitive count must rise by EXACTLY the
## triangles the scatter reports it built, because that number is known before
## the frame is drawn.

const WARMUP_FRAMES := 20
const MEASURE_FRAMES := 80
const ATTEMPTS := 3

## §16.10's fixed client frame, the same budget the benchmark answers against.
const FRAME_BUDGET_MS := 33.3

## How far the observed marginal may sit from the predicted one before the two
## are called disagreeing. Wide, deliberately: the benchmark's own
## reproducibility is a median of 4% at p50 with one sweep at 46%, so a
## tolerance tighter than the instrument would report noise as a finding.
const AGREEMENT_TOLERANCE := 0.35


## What the scatter cost, as the difference between two timings of one scene.
##
## REPORTED AGAINST THE SCENE'S OWN VARIATION, because a difference smaller than
## the frame-to-frame spread of either side is not a measurement of a small cost
## -- it is the absence of a measurement, and the two must not read alike.
static func marginal(with_scatter: Dictionary, without: Dictionary) -> Dictionary:
    if not with_scatter.has("p50") or not without.has("p50"):
        return {"ok": false, "why": "one of the two timings carries no p50"}
    var d50 := float(with_scatter["p50"]) - float(without["p50"])
    var d95 := float(with_scatter["p95"]) - float(without["p95"])
    var d99 := float(with_scatter["p99"]) - float(without["p99"])
    # The wider of the two sides' own p50..p95 spans. Using the narrower one
    # would let a quiet baseline certify a noisy measurement.
    var spread: float = maxf(float(with_scatter["p95"]) - float(with_scatter["p50"]),
                             float(without["p95"]) - float(without["p50"]))
    var out := {
        "ok": true,
        "p50_ms": d50,
        "p95_ms": d95,
        "p99_ms": d99,
        "scene_spread_ms": spread,
        "resolved": absf(d50) > spread,
    }
    if not out["resolved"]:
        out["why_unresolved"] = ("the difference between the two timings (%.2f ms) is inside "
                + "the scene's own frame-to-frame spread (%.2f ms), so this run did not "
                + "resolve the scatter's cost rather than measuring it as small"
                ) % [d50, spread]
    # A TAIL MINUS AN OUTLIER IS NOT A TAIL. One stalled frame in the quieter
    # timing lifts its p99 far above its own p95, and subtracting that from the
    # busier side yields a p99 "marginal" that can come out near zero or
    # negative -- which reads as the scatter being free at the tail. It is the
    # outlier, and the number has to say so rather than be quietly dropped.
    var quiet_p99 := float(without["p99"])
    var quiet_p95 := float(without["p95"])
    if quiet_p99 > 1.5 * quiet_p95:
        out["p99_note"] = ("the quieter timing's own p99 is %.2f ms against a p95 of %.2f: a "
                + "stalled frame, not a tail. The p99 difference above is that outlier "
                + "subtracted from the other side, and p50 is the number this run supports."
                ) % [quiet_p99, quiet_p95]
    return out


## The cost model's prediction for the instances that were actually drawn.
##
## The model is per-instance nanoseconds at a triangle count, fitted on an empty
## stage. Nothing about that fit knows there is a basin under these instances,
## which is exactly why comparing it to an observation is worth doing: if the
## two agree, the coefficient transfers into a real scene, and if they do not,
## every budget sentence M5 writes is conditional on a stage nobody renders.
static func predicted_ms(placed: Dictionary, ns_per_instance: Dictionary) -> Dictionary:
    var total := 0
    var ns := 0.0
    var missing := PackedStringArray()
    for life_form in placed:
        var n := int(placed[life_form])
        if n <= 0:
            continue
        if not ns_per_instance.has(life_form):
            missing.append(life_form)
            continue
        total += n
        ns += float(n) * float(ns_per_instance[life_form])
    if not missing.is_empty():
        return {"ok": false, "why": "no per-instance cost for %s" % str(missing)}
    if total == 0:
        return {"ok": false, "why": "nothing was placed, so there is nothing to price"}
    return {"ok": true, "instances": total, "ms": ns / 1.0e6,
            "mean_ns_per_instance": ns / float(total)}


## Did the frame agree with the model?
static func agreement(predicted: float, observed: float) -> Dictionary:
    if predicted <= 0.0:
        return {"ok": false, "why": "the model predicts no cost, so there is no ratio"}
    var ratio := observed / predicted
    var within: bool = absf(ratio - 1.0) <= AGREEMENT_TOLERANCE
    return {
        "ok": true,
        "ratio_observed_over_predicted": ratio,
        "within_tolerance": within,
        "tolerance": AGREEMENT_TOLERANCE,
        # ONE RUN'S RATIO, and the tolerance is the instrument's own noise floor
        # rather than a standard anything meets. A verdict that flips between
        # repeats is worth less than the ratio itself, so both are reported and
        # the artefact's README carries the spread across repeats.
        "verdict": ("the frame cost %.2fx what the empty-stage coefficient predicts, "
                + "%s the %.0f%% the benchmark's own reproducibility supports. Every budget "
                + "sentence resting on that coefficient is conditional on a stage nobody "
                + "renders, and this is the size of the conditional."
                ) % [ratio, "inside" if within else "outside",
                     100.0 * AGREEMENT_TOLERANCE],
    }


## Did the frame draw the scatter it was told to?
##
## MEASURED IN PIXELS, NOT IN PRIMITIVES, and that is a correction. The
## benchmark verifies a configuration by checking the primitive counter against
## instances x triangles, and that check is sound there. It is NOT sound here:
## on this renderer `RENDER_TOTAL_PRIMITIVES_IN_FRAME` reported 5,114,160 for a
## 106,545-instance MultiMesh and a constant 20 for a 12,960-instance one --
## unchanged when `visible_instance_count` was set to 100 and then to 1, so it
## was not counting instances at all for that mesh. All three families were
## drawing: the pixel counts scaled with the instance count exactly as the
## primitive counter failed to.
##
## So the check that survives is the one the screenshot harness already makes:
## showing the scatter has to CHANGE THE FRAME. It is weaker -- it cannot say
## how many instances arrived -- and it has the property that matters, which is
## that it does not pass a frame the scatter is missing from.
static func drew_the_scatter(changed_px: int, frames_drawn: int, frames_timed: int) -> String:
    if frames_drawn < frames_timed:
        return ("the renderer drew %d frames while %d were timed: the window stopped being "
                + "drawn partway through, and the samples are a cadence rather than a cost"
                ) % [frames_drawn, frames_timed]
    if changed_px <= 0:
        return ("showing the scatter changed no pixels, so the two timings are of one scene "
                + "and their difference is not the cost of anything")
    return ""
