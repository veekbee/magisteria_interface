class_name CalibrationBands
extends RefCounted

## Decision 1019's measured bands, read into the shape `StratumGrade` grades
## against.
##
## THE ARTEFACT IS NOT SHAPED LIKE THE GRADER AND NEITHER IS WRONG. It publishes
## `landform_bands[name][form]` -- the fitted `(amplitude, exponent)` with their
## provenance -- and the per-lag `S(l)` bands separately, inside
## `cross_stratum_separation.per_lag[lag].band[name]`. The grader wants one
## dictionary per landform keyed by lag. This joins them, and does nothing else:
## every number below is read, none is derived beyond the band's own width rule.
##
## THE BAND IS `mean +/- sd`, AND THAT IS READ RATHER THAN CHOSEN. The artefact
## states its separation criterion as *"|mean_A - mean_B| > sd_A + sd_B; no
## threshold is chosen"* -- which is exactly the statement that two bands
## separate when they do not overlap, for bands of one standard deviation. So
## the width follows from the producing side's own clause, and a different width
## here would silently disagree with the separation verdict published beside it.
##
## `plain` IS NOT SELECTED AND THAT IS A LINE OF CODE, NOT A PROPERTY OF THE
## FILE. Decision 1019 rules the second difference carries both of convention
## 6's clauses; the plain form travels as decision 1018's property-3 audit and
## grades nothing. The artefact sends both deliberately so this choice is
## visible here, and `FORM` is where it is made.

## The graded form, per decision 1019.
const FORM := "detrended"
const PATH := "res://assets/detail/calibration_rows_1019.json"

var doc: Dictionary = {}
## Empty when the bands are readable; a sentence when they are not.
var why_absent: String = ""


static func load_from(path: String = PATH) -> CalibrationBands:
    var cb := CalibrationBands.new()
    if not FileAccess.file_exists(path):
        cb.why_absent = "no calibration bands at %s" % path
        return cb
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        cb.why_absent = "%s is not a JSON object" % path
        return cb
    cb.doc = parsed
    if not (cb.doc.has("landform_bands") and cb.doc.has("cross_stratum_separation")):
        cb.why_absent = ("%s carries no `landform_bands` or no `cross_stratum_separation`, so "
                % path) + "the per-lag bands the gate grades against are not in it"
        cb.doc = {}
    return cb


func is_loaded() -> bool:
    return not doc.is_empty()


## `{landform: {lag: [lo, hi], "window_support": ...}}` for `StratumGrade`.
##
## A REFUSED BLOCK ARRIVES AS AN EMPTY ENTRY, which is what makes the producing
## side's refused-block guarantee worth having: `gradeable` reads an empty band
## as `NO_BANDS` for that landform and says so by name. A refused block silently
## carrying numbers from somewhere else would grade a stratum against a band its
## own artefact declined to measure.
func bands_for_grading() -> Dictionary:
    if not is_loaded():
        return {}
    var per_lag: Dictionary = (doc["cross_stratum_separation"] as Dictionary).get("per_lag", {})
    var out := {}
    for name in (doc["landform_bands"] as Dictionary):
        var block: Dictionary = (doc["landform_bands"][name] as Dictionary).get(FORM, {})
        if block.is_empty() or bool(block.get("refused", false)):
            out[str(name)] = {}
            continue
        var per := {}
        # THE SUPPORT TRAVELS WITH THE BAND, not beside it. `StratumGrade`
        # refuses a band set sourced at a stratification this client does not
        # measure on, and it asks the band block -- so an entry that lost the
        # declaration on the way through this reader would be refused for the
        # wrong reason.
        per[StratumGrade.SUPPORT_KEY] = str(block.get(StratumGrade.SUPPORT_KEY, ""))
        for lag_key in per_lag:
            var lag := float(str(lag_key))
            var band: Dictionary = ((per_lag[lag_key] as Dictionary).get("band", {})
                    as Dictionary).get(str(name), {})
            if band.is_empty():
                continue
            var mean := float(band.get("mean", NAN))
            var sd := float(band.get("sd", NAN))
            if is_nan(mean) or is_nan(sd):
                continue
            per[lag] = [mean - sd, mean + sd]
        out[str(name)] = per
    return out


## THE SUPPORT EACH BAND RESTS ON, read from the artefact rather than from the
## dispatch that quoted it.
##
## `n_qualifying` is how many windows a stratum actually qualified in, and the
## exponent's `sd` is the CLOSURE SCATTER decision 1033 grades closure against
## after the authored `CLOSE_TOL` was withdrawn. Both are the producing side's
## own figures; this reader does not compute them, it carries them so a client
## measurement can be read beside the support it rests on instead of beside a
## number quoted in prose.
##
## `exponent_sd_over_mean` IS COMPUTED HERE AND IS NOT THEIRS. The scatter is an
## absolute spread on an exponent whose mean differs by nearly a factor of two
## across the strata, so the same `sd` means different things at different means.
## It is published as a derived figure and named as one.
##
## Rows are `landform -> {n, exponent_sd, exponent_mean, exponent_sd_over_mean}`;
## a refused or absent block contributes nothing.
func support_figures() -> Dictionary:
    if not is_loaded():
        return {}
    var out := {}
    for name in (doc["landform_bands"] as Dictionary):
        var block: Dictionary = (doc["landform_bands"][name] as Dictionary).get(FORM, {})
        if block.is_empty() or bool(block.get("refused", false)):
            continue
        var exp_block: Dictionary = block.get("exponent", {})
        var sd := float(exp_block.get("sd", NAN))
        var mean := float(exp_block.get("mean", NAN))
        out[str(name)] = {
            "n": int(block.get("n_qualifying", -1)),
            "exponent_sd": sd,
            "exponent_mean": mean,
            "exponent_sd_over_mean": (NAN if is_nan(sd) or is_nan(mean) or mean == 0.0
                    else sd / absf(mean)),
        }
    return out


## Decision 986's cross-stratum clause, as the ARTEFACT measured it.
##
## NOT `StratumGrade.spread()`, AND THE DIFFERENCE IS THE POINT. That function
## takes the ratio of the loudest stratum to the quietest and compares it to a
## number -- a stand-in written when no band set existed and there was nothing
## else to ask. The artefact measures the clause as decision 986 states it:
## pairwise, *"the gate discriminates iff strata's bands separate where strata
## differ"*, with **no threshold chosen**. A ratio of extremes can pass while
## two middle strata sit on top of each other, which is the failure the clause
## exists to catch.
##
## So this reports the published verdict rather than recomputing it. The one
## thing asserted here is the reading: a stratum separating from NOTHING fails,
## and the artefact names those.
func separation_evidence() -> Dictionary:
    if not is_loaded():
        return {}
    var cs: Dictionary = doc["cross_stratum_separation"]
    var isolated: Array = cs.get("separates_from_nothing", [])
    var counts: Dictionary = cs.get("separates_from_n_others", {})
    var lags: Array = cs.get("graded_lags_m", [])
    return {
        "ok": isolated.is_empty(),
        "why": ("%s at lags %s: %s"
                % [str(cs.get("clause", "decision 986's cross-stratum clause")), str(lags),
                   ("every stratum separates from at least one other (%s)" % str(counts))
                        if isolated.is_empty()
                        else "these separate from nothing: %s" % str(isolated)]),
        "strata": counts.keys(),
        "separates_iff": str(cs.get("separates_iff", "")),
    }


## Which lags the artefact measured its cross-stratum bands at.
##
## READ BACK, because the producing side took this client's `GRADED_LAGS` across
## the boundary to measure them. If the two ever disagree the bands are per-lag
## numbers for lags nothing grades, which would be silent: the grader would find
## no band at its own lag and report `NO_BANDS` for a set that is right there.
func graded_lags() -> Array:
    if not is_loaded():
        return []
    return (doc["cross_stratum_separation"] as Dictionary).get("graded_lags_m", [])
