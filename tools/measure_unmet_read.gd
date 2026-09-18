extends SceneTree

## READING THE CONDITION-2 UNMET: which cells can fail, which do, and how.
##
## Decision 1040's conjunction has read UNMET at all six walked parents on the
## same two strata for four revs. The sim side's leading candidate is its own
## CLOSURE STANDARD: decision 1033 withdrew the authored `CLOSE_TOL` and grades
## closure against each landform's cross-window exponent scatter, so the
## thinnest-supported strata get the widest scatters and therefore the most
## permissive closure -- and the two thinnest-supported are exactly the two this
## client reports UNMET. It is preferred because it is the only one of the four
## that predicts BOTH strata.
##
## THIS TOOL DOES NOT RULE ON IT. It publishes what this client can see about
## the failure, so the candidate is tested against the shape of the miss rather
## than against which names appear.
##
## THREE THINGS IT MEASURES THAT "UNMET AT ALL SIX PARENTS" DOES NOT SAY.
##
##   * WHICH CELLS CAN FAIL AT ALL. A band is `[mean - sd, mean + sd]` over the
##     windows a stratum qualified in, and `S` is a second difference, which is
##     NON-NEGATIVE by construction. A band whose lower edge is below zero
##     cannot be failed from below, so "in band" there is an inability to fail
##     rather than evidence. Counting those changes what a per-stratum verdict
##     means: a stratum can be reported in band at a cell no measurement could
##     have moved.
##   * HOW FAR OUT, AND WHICH WAY. A miss of 3x below a band and a miss of 13%
##     above it are different objects, and a conjunction reports them alike.
##   * WHETHER THE MISS IS A LEVEL OR A SHAPE. If a row's amplitude is wrong the
##     measured curve is displaced and the miss is roughly constant across lags;
##     if its exponent is wrong the curve is tilted and the miss grows or shrinks
##     with lag. So the log-slope of the measurement is published beside the
##     log-slope of the band means it is graded against. A candidate that puts
##     the fault in a loosely-certified ROW should predict which of the two it
##     produced.
##
## WHAT IS DELIBERATELY NOT HERE. No disposition of the four candidates, and no
## reading of the band's width as a defect -- the bands are the producing side's
## and their width is theirs to rule on. This client measures, names what cannot
## fail, and hands both over.

const OUT := "measurements/unmet_read.json"
const TERRAIN_DIR := "res://assets/terrain/"
## The gate's own grading parameters, so this is readable beside its verdicts.
const SPAN_M := 3000.0
const QUANTILE := 0.5
const SAMPLES := 300
const SEED := 21


func _init() -> void:
    var f := FileAccess.open(TERRAIN_DIR + "terrain_export.json", FileAccess.READ)
    if f == null:
        printerr("unmet_read: no terrain_export.json")
        quit(1)
        return
    var man: Dictionary = JSON.parse_string(f.get_as_text())
    var hf := Heightfield.load_from(man, TERRAIN_DIR + "heightfield_overview.png")
    var layers := TerrainLayers.load_from()
    if not hf.is_loaded() or not layers.is_fetched():
        printerr("unmet_read: the heightfield or the layers are not available. "
                + "`python3 tools/fetch_artefacts.py`")
        quit(1)
        return
    var cb := CalibrationBands.load_from()
    if not cb.is_loaded():
        printerr("unmet_read: no vendored band set (%s)" % cb.why_absent)
        quit(1)
        return
    var bands := cb.bands_for_grading()
    var lags := cb.graded_lags()
    var sourced := _sourced_windows()
    var wp := WalkedParents.of_vendored()
    if sourced.is_empty() or not wp.is_declared():
        printerr("unmet_read: no sourced windows or no walked-parent set")
        quit(1)
        return

    # THE SUPPORT EACH BAND RESTS ON, read from the artefact rather than from the
    # dispatch that quoted it. `n_qualifying` is the window count and the
    # exponent's `sd` is the closure scatter the candidate is built on.
    var support := cb.support_figures()

    var cells: Array = []
    var unfailable: Array = []
    var per_parent: Array = []
    for parent_raw in wp.as_array():
        var parent_m := float(parent_raw)
        var df := DetailField.load_from(hf, DetailField.ROWS_PATH, parent_m, layers)
        if df == null or not df.is_loaded():
            continue
        var m := StratumGrade.over_windows(df, hf, sourced, SPAN_M, lags, QUANTILE, SAMPLES, SEED)
        var ev := StratumGrade.evidence(m, StratumGrade.spread(m, lags), bands)
        var ok: Variant = (ev.get("bands", {}) as Dictionary).get("ok", null)
        var out_here: Array = []
        for nm in (m.get("strata", {}) as Dictionary):
            var entry: Dictionary = m["strata"][nm]
            var series: Array = []
            for lag_raw in lags:
                var lag := float(lag_raw)
                var sv = entry.get(lag, null)
                var band: Array = (bands.get(str(nm), {}) as Dictionary).get(lag, [])
                if sv == null or band.size() != 2:
                    continue
                var s := float(sv)
                var lo := float(band[0])
                var hi := float(band[1])
                # A SECOND DIFFERENCE CANNOT BE NEGATIVE, so a band reaching
                # below zero cannot be failed from below.
                var can_fail_low := lo > 0.0
                var inside := s >= lo and s <= hi
                var miss := 0.0
                var direction := "in band"
                if s < lo:
                    miss = lo / maxf(s, 1.0e-300)
                    direction = "below"
                elif s > hi:
                    miss = s / maxf(hi, 1.0e-300)
                    direction = "above"
                series.append({"lag_m": lag, "s": s, "band": [lo, hi],
                        "band_mean": 0.5 * (lo + hi), "band_width_over_mean":
                                (hi - lo) / maxf(absf(0.5 * (lo + hi)), 1.0e-300),
                        "in_band": inside, "direction": direction, "miss_factor": miss,
                        "band_can_fail_low": can_fail_low})
                if inside and not can_fail_low:
                    unfailable.append("%s at %s m under a %s m parent is in band on [%s, %s], "
                            % [str(nm), String.num(lag, 1), String.num(parent_m, 0),
                               String.num(lo, 4), String.num(hi, 4)]
                            + "whose lower edge is below zero: a second difference cannot fail it")
                if not inside:
                    out_here.append("%s@%sm" % [str(nm), String.num(lag, 1)])
            # LEVEL OR SHAPE. The log-slope of the measurement against the
            # log-slope of the band means it is graded against, over the same
            # lags. Equal slopes with a constant offset is a level error; unequal
            # slopes is a shape error, which is what a mis-fit exponent makes.
            var ms := _log_slope(series, "s")
            var bs := _log_slope(series, "band_mean")
            cells.append({"parent_spacing_m": parent_m, "landform": str(nm),
                    "n_windows": int((support.get(str(nm), {}) as Dictionary).get("n", -1)),
                    "closure_scatter": float((support.get(str(nm), {}) as Dictionary)
                            .get("exponent_sd", NAN)),
                    "closure_scatter_relative": float((support.get(str(nm), {}) as Dictionary)
                            .get("exponent_sd_over_mean", NAN)),
                    "measured_log_slope": ms, "band_log_slope": bs,
                    "log_slope_gap": (NAN if is_nan(ms) or is_nan(bs) else ms - bs),
                    "per_lag": series})
        per_parent.append({"parent_spacing_m": parent_m,
                "condition_2": ("not gradeable" if ok == null
                        else ("MET" if bool(ok) else "UNMET")),
                "cells_outside": out_here})
        print("unmet: %5s m parent -- condition 2 %s; outside: %s"
                % [String.num(parent_m, 0),
                   str(per_parent[per_parent.size() - 1]["condition_2"]),
                   ", ".join(PackedStringArray(out_here))])

    # OUTSIDE AT EVERY PARENT, OR ONLY AT SOME -- DERIVED HERE RATHER THAN LEFT
    # TO A READER TO INTERSECT SIX LISTS.
    #
    # THIS EXISTS BECAUSE I GOT IT WRONG READING MY OWN OUTPUT. I reported "three
    # cells, the same three at every parent" from six printed lines; three are
    # outside at all six, and a FOURTH -- `playa` at 8 m -- is outside at two of
    # them. The claim reached a handback and a commit message before the
    # intersection was taken. A summary a reader has to compute by hand is one
    # that gets computed wrongly, so it is computed here.
    #
    # AND THE INTERMITTENT CELL IS THE INFORMATIVE ONE. `playa`@8m is the same
    # cell the octave-clamp seed sweep finds crossing its band edge in 11 of 100
    # seeds. Two instruments that share no sampling -- one varying the parent
    # lattice, one varying the sample cloud -- both find that cell marginal and
    # the other three stable. An "outside at every parent" summary hides exactly
    # the cell that is telling them something.
    var every := {}
    var some := {}
    var first := true
    for pr in per_parent:
        var here := {}
        for cname in ((pr as Dictionary).get("cells_outside", []) as Array):
            here[str(cname)] = true
            some[str(cname)] = true
        if first:
            every = here.duplicate()
            first = false
        else:
            for k in every.keys():
                if not here.has(k):
                    every.erase(k)
    var every_list := PackedStringArray()
    for k in every:
        every_list.append(str(k))
    every_list.sort()
    var sometimes := PackedStringArray()
    for k in some:
        if not every.has(k):
            sometimes.append(str(k))
    sometimes.sort()

    var doc := {
        "_what": ("What this client can see about decision 1040's condition-2 UNMET: which cells "
                + "can fail at all, which do, by how much and in which direction, and whether "
                + "each stratum's miss is a level or a shape."),
        "_a_band_reaching_below_zero_cannot_fail": ("`S` is a second difference and is "
                + "non-negative by construction, so a band whose lower edge is below zero cannot "
                + "be failed from below. `cells_that_cannot_fail` names those. They still count "
                + "as they count -- excluding them would be this client ruling on a band width "
                + "that is not its own -- but a stratum reported in band there has not passed a "
                + "test."),
        "_level_or_shape": ("A wrong amplitude displaces the curve and the miss is roughly "
                + "constant across lags; a wrong exponent tilts it and the miss grows or shrinks. "
                + "`log_slope_gap` is the measurement's log-slope minus the band means', over "
                + "the graded lags. A candidate placing the fault in a loosely-certified row "
                + "should say which of the two it produces."),
        "_this_rules_on_nothing": ("No disposition of the four candidates and no reading of a "
                + "band's width as a defect. The bands are the producing side's."),
        "vertical_exaggeration": 1.0,
        "_vertical_exaggeration_is": ("the grader samples `Heightfield.height_at_world` and "
                + "`DetailField` directly; the view's factor does not reach this path."),
        "measured_at_utc": Time.get_datetime_string_from_system(true),
        "grading_parameters": {"span_m": SPAN_M, "quantile": QUANTILE,
                "samples_per_lag": SAMPLES, "seed": SEED, "windows": sourced.size(),
                "lags_m": lags, "_are_the_gate_s": true},
        # THE BOUND THIS GRADING RAN AT, so the artefact can be caught when it
        # stops describing the tree. It was graded once at `MAX_OCTAVES` 12,
        # decision 1073 raised it to 14, and every `S` at the two coarsest
        # walked parents moved -- while the gate stayed green, because its check
        # reconciles this file against its own rows and never against a live
        # re-grade. Three artefacts went stale that way in one day.
        #
        # THIS ONE IS BOUND TO THE SYMBOL, and the clamp artefacts beside it are
        # bound to the number, deliberately. This file is LIVE: it must describe
        # the current tree, so its check follows the constant and breaks when the
        # two part. Those are historical: they record a superseded bound as
        # evidence, so their check pins the number and must NOT follow. A check
        # on the symbol silently stops testing history; a check on the number
        # breaks loudly when the constant moves. Which is correct depends on
        # whether the artefact is meant to age.
        "max_octaves_shipped": DetailField.MAX_OCTAVES,
        "_max_octaves_is_the_live_bound": ("the octave ceiling in force when this was graded. "
                + "It is compared against the constant, not against a number, because this "
                + "artefact is meant to describe the tree it sits in rather than to record a "
                + "past one."),
        "walked_parents_m": wp.as_array(),
        "support": support,
        "cells_that_cannot_fail": unfailable,
        "_outside_at_every_versus_some": ("A cell outside its band at every walked parent and one "
                + "outside at two of six are different objects, and a per-parent list reports "
                + "them alike. The intermittent one is where the lattice is doing something; the "
                + "invariant ones are properties of the row and the band. Derived here because I "
                + "read my own six lines as three invariant cells and missed the fourth."),
        "cells_outside_at_every_parent": every_list,
        "cells_outside_at_some_parents": sometimes,
        "per_parent": per_parent,
        "cells": cells,
    }
    var w := FileAccess.open("res://" + OUT, FileAccess.WRITE)
    if w == null:
        printerr("unmet_read: cannot write %s" % OUT)
        quit(1)
        return
    w.store_string(JSON.stringify(doc, "  ") + "\n")
    w.close()
    print("unmet: outside at EVERY parent: %s; outside at SOME: %s"
            % [", ".join(every_list), ("none" if sometimes.is_empty() else ", ".join(sometimes))])
    print("unmet: %d cell-parent row(s), %d cell(s) that cannot fail -> %s"
            % [cells.size(), unfailable.size(), OUT])
    quit(0)


## The log-slope of a series against lag, by least squares in log-log. NAN with
## fewer than two usable points or a non-positive value, which cannot be logged.
func _log_slope(series: Array, key: String) -> float:
    var xs := PackedFloat64Array()
    var ys := PackedFloat64Array()
    for e in series:
        var d: Dictionary = e
        var v := float(d.get(key, NAN))
        var l := float(d.get("lag_m", NAN))
        if is_nan(v) or is_nan(l) or v <= 0.0 or l <= 0.0:
            continue
        xs.append(log(l))
        ys.append(log(v))
    if xs.size() < 2:
        return NAN
    var mx := 0.0
    var my := 0.0
    for i in xs.size():
        mx += xs[i]
        my += ys[i]
    mx /= float(xs.size())
    my /= float(xs.size())
    var num := 0.0
    var den := 0.0
    for i in xs.size():
        num += (xs[i] - mx) * (ys[i] - my)
        den += (xs[i] - mx) * (xs[i] - mx)
    return NAN if den <= 0.0 else num / den


func _sourced_windows() -> Array:
    var f := FileAccess.open("res://measurements/window_sourcing.json", FileAccess.READ)
    if f == null:
        return []
    var doc = JSON.parse_string(f.get_as_text())
    if typeof(doc) != TYPE_DICTIONARY:
        return []
    var out: Array = []
    for c in (doc as Dictionary).get("centres", []):
        var w: Array = (c as Dictionary).get("world_m", [])
        if w.size() == 2:
            out.append(Vector2(float(w[0]), float(w[1])))
    return out
