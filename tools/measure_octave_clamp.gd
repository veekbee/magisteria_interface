extends SceneTree

## WHAT THE OCTAVE CEILING COSTS THE VERDICT, per walked parent.
##
## `DetailField.MAX_OCTAVES` is a cost bound: every octave is another noise
## evaluation per sample. At the two coarsest walked parents it stops the ladder
## short of the 0.25 m band every row declares -- 1,600 m wants 13 rungs and
## 3,200 m wants 14, so the field reaches 0.39 m and 0.78 m. `band_limit_note`
## says so on every run, and saying so was the immediate repair.
##
## THIS ANSWERS THE QUESTION THE DISCLOSURE CANNOT: whether a verdict moves.
## Until it is measured nobody can tell a DECLARATION defect from a SUBSTANTIVE
## one, and those have different owners. If decision 1040's conditions grade the
## same with the ladder lifted, the clamp is a cost decision that can be weighed
## at leisure and the corpus needs one sentence. If a verdict moves, the
## conjunction has been graded at two parents on a field that never reached its
## declared band, and that is design's to re-read. This tool does not rule on
## `MAX_OCTAVES` and does not change it.
##
## WHY THIS IS A PAIRED COMPARISON AND NOT TWO MEASUREMENTS. `StratumGrade`
## draws its stencils from `StableHash.of5(seed, salt, window, i, 0)` -- the
## positions, the directions and the membership weights are functions of the
## seed and the lag, and of NOTHING about the field. So both ladders are read at
## the same places in the same order, and the difference is the added band
## rather than a different sample cloud. Reported at the same `SEED`, span,
## quantile and sample count the gate grades at, for the same reason.
##
## AND THE NORMALISATION MOVES WITH THE LADDER. `residual_rms_for` divides by
## `rms(f - P[f])`, which at these two parents is not published and so is
## COMPUTED from the ladder that is running. Lifting the ceiling recomputes it
## -- `octave_ceiling`'s setter drops the cache for exactly this -- so the
## lifted field is not the shipped one plus variance. If the normalisation were
## held fixed the added octaves would show up as an amplitude change, which is
## not the question.
##
## THE FOUR PARENTS WHERE THE CLAMP DOES NOT BITE ARE THE CONTROL, and they are
## measured rather than argued: at 100, 200, 400 and 800 m the ladder wants 9 to
## 12 rungs, the lifted ceiling changes nothing, and every `S(l)` must come back
## IDENTICAL. An instrument that moved those would be measuring itself.

const OUT := "measurements/octave_clamp.json"
const TERRAIN_DIR := "res://assets/terrain/"
## The gate's own grading parameters. Not re-chosen here: a measurement meant to
## be read beside a verdict has to be taken the way the verdict is taken.
const SPAN_M := 3000.0
const QUANTILE := 0.5
const SAMPLES := 300
const SEED := 21
## The sweep's target: the cell the three-seed measurement left closest to its edge.
const SWEEP_OUT := "measurements/octave_clamp_playa_sweep.json"
const SWEEP_PARENT_M := 1600.0
const SWEEP_STRATUM := "playa"


## `--seed N` RE-DRAWS THE CLOUD, and it is not a knob for a nicer number.
##
## The paired comparison removes the sample cloud from the DIFFERENCE -- both
## ladders read the same stencils -- but not from `S(l)` itself, and it is
## `S(l)` that sets the distance to a band edge. So "no verdict moved" at one
## seed is a statement about one cloud. Where the movement is a large fraction
## of that distance, the honest follow-up is another cloud, and
## `--only-clamped` skips the four parents whose control has already run.
func _init() -> void:
    var seed_used := SEED
    var only_clamped := false
    var out_path := OUT
    var sweep_to := 0
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if str(args[i]) == "--seed" and i + 1 < args.size():
            seed_used = int(str(args[i + 1]))
        elif str(args[i]) == "--only-clamped":
            only_clamped = true
        elif str(args[i]) == "--sweep" and i + 1 < args.size():
            sweep_to = int(str(args[i + 1]))
        elif str(args[i]) == "--out" and i + 1 < args.size():
            out_path = str(args[i + 1])
    if seed_used != SEED and out_path == OUT:
        out_path = "measurements/octave_clamp_seed%d.json" % seed_used
    var f := FileAccess.open(TERRAIN_DIR + "terrain_export.json", FileAccess.READ)
    if f == null:
        printerr("octave_clamp: no terrain_export.json")
        quit(1)
        return
    var man: Dictionary = JSON.parse_string(f.get_as_text())
    var hf := Heightfield.load_from(man, TERRAIN_DIR + "heightfield_overview.png")
    if not hf.is_loaded():
        printerr("octave_clamp: the heightfield did not load")
        quit(1)
        return

    # REAL HAND AND SLOPE OR NOTHING, exactly as `StratumGrade` refuses. The
    # strata are membership functions on real inputs; without the layers this
    # would stratify on a re-derived lattice gradient and grade a different
    # space under the same names.
    var layers := TerrainLayers.load_from()
    if not layers.is_fetched():
        printerr("octave_clamp: the terrain layers are not fetched, so the strata cannot be "
                + "evaluated on real ground. `python3 tools/fetch_artefacts.py`")
        quit(1)
        return

    var cb := CalibrationBands.load_from()
    if not cb.is_loaded():
        printerr("octave_clamp: no vendored band set (%s), so there is no verdict to move"
                % cb.why_absent)
        quit(1)
        return
    var bands := cb.bands_for_grading()
    var lags := cb.graded_lags()

    var sourced := _sourced_windows()
    if sourced.is_empty():
        printerr("octave_clamp: no measurements/window_sourcing.json. "
                + "`bash tools/find_windows.sh`")
        quit(1)
        return

    var wp := WalkedParents.of_vendored()
    if not wp.is_declared():
        printerr("octave_clamp: no walked-parent set (%s)" % wp.why_absent)
        quit(1)
        return

    if sweep_to > 0:
        _sweep(hf, layers, bands, lags, sourced, sweep_to)
        return

    var per_parent: Array = []
    var flips: Array = []
    var control_moved: Array = []
    for parent_raw in wp.as_array():
        var parent_m := float(parent_raw)
        var shipped := DetailField.load_from(hf, DetailField.ROWS_PATH, parent_m, layers)
        if shipped == null or not shipped.is_loaded():
            continue
        # THE CEILING THE ROWS ASK FOR AT THIS PARENT, and not a number typed
        # here. `octaves_wanted` is the same expression the clamp clamps, so a
        # row that changed its declared band would move this with it.
        # ACROSS THE ROWS AND NOT ONE OF THEM. A single landform standing for
        # five is what made the cross-parent assertion pass for a lucky reason
        # -- `talus` carried the shallowest exponent and the gate hardcoded it.
        # The rows all declare 0.25 m today, so these ranges are degenerate;
        # they are ranges anyway, so a row that declares a different band is
        # visible here instead of hidden behind whichever name was typed.
        var wanted := 1
        var ships := 1
        var reached_s := 0.0
        var reached_l := 0.0
        for name in shipped.landforms():
            var n := str(name)
            wanted = maxi(wanted, shipped.octaves_wanted(n))
            ships = maxi(ships, shipped.octaves_for(n))
            reached_s = maxf(reached_s, shipped.finest_reached_m(n))
        var lifted := DetailField.load_from(hf, DetailField.ROWS_PATH, parent_m, layers)
        lifted.octave_ceiling = wanted
        for name in lifted.landforms():
            reached_l = maxf(reached_l, lifted.finest_reached_m(str(name)))
        var bites := wanted > DetailField.MAX_OCTAVES

        if only_clamped and not bites:
            continue
        var ms := StratumGrade.over_windows(shipped, hf, sourced, SPAN_M, lags,
                QUANTILE, SAMPLES, seed_used)
        var ml := StratumGrade.over_windows(lifted, hf, sourced, SPAN_M, lags,
                QUANTILE, SAMPLES, seed_used)
        var es := StratumGrade.evidence(ms, StratumGrade.spread(ms, lags), bands)
        var el := StratumGrade.evidence(ml, StratumGrade.spread(ml, lags), bands)
        var ok_s: Variant = (es.get("bands", {}) as Dictionary).get("ok", null)
        var ok_l: Variant = (el.get("bands", {}) as Dictionary).get("ok", null)

        var rows: Array = []
        var worst_rel := 0.0
        var identical := true
        for nm in (ms.get("strata", {}) as Dictionary):
            var sh: Dictionary = ms["strata"][nm]
            var li: Dictionary = (ml.get("strata", {}) as Dictionary).get(nm, {})
            for lag_raw in lags:
                var lag := float(lag_raw)
                var a = sh.get(lag, null)
                var b = li.get(lag, null)
                if a == null or b == null:
                    continue
                var sa := float(a)
                var sb := float(b)
                var rel: float = (0.0 if sa == sb
                        else absf(sb - sa) / maxf(absf(sa), 1.0e-300))
                if sa != sb:
                    identical = false
                worst_rel = maxf(worst_rel, rel)
                var band: Array = (bands.get(str(nm), {}) as Dictionary).get(lag, [])
                var in_s := band.size() == 2 and sa >= float(band[0]) and sa <= float(band[1])
                var in_l := band.size() == 2 and sb >= float(band[0]) and sb <= float(band[1])
                if band.size() == 2 and in_s != in_l:
                    flips.append("%s at %s m under a %s m parent: %s -> %s"
                            % [str(nm), String.num(lag, 1), String.num(parent_m, 0),
                               "in band" if in_s else "outside",
                               "in band" if in_l else "outside"])
                rows.append({
                    "landform": str(nm),
                    "lag_m": lag,
                    "s_shipped": sa,
                    "s_lifted": sb,
                    "relative_change": rel,
                    "in_band_shipped": in_s,
                    "in_band_lifted": in_l,
                    "band": band,
                })
        # THE CONTROL, CHECKED HERE RATHER THAN LEFT TO A READER. Where the
        # clamp does not bite the two fields are the same ladder, so anything
        # other than bit-identical is the instrument and not the ground.
        if not bites and not identical:
            control_moved.append("%s m moved by %s with the ceiling lifted to a bound that "
                    % [String.num(parent_m, 0), String.num(worst_rel, 6)]
                    + "does not bite")

        per_parent.append({
            "parent_spacing_m": parent_m,
            "octaves_shipped": ships,
            "octaves_wanted": wanted,
            "clamp_bites": bites,
            "finest_reached_shipped_m": reached_s,
            "finest_reached_lifted_m": reached_l,
            "condition_2_shipped": ("not gradeable" if ok_s == null
                    else ("MET" if bool(ok_s) else "UNMET")),
            "condition_2_lifted": ("not gradeable" if ok_l == null
                    else ("MET" if bool(ok_l) else "UNMET")),
            "verdict_moved": ok_s != ok_l,
            "why_shipped": str((es.get("bands", {}) as Dictionary).get("why", "")),
            "why_lifted": str((el.get("bands", {}) as Dictionary).get("why", "")),
            "worst_relative_change": worst_rel,
            "s_identical": identical,
            "per_lag": rows,
        })
        print("octave_clamp: %5s m  wants %2d, ships %2d%s  condition 2: %s -> %s  "
                % [String.num(parent_m, 0), wanted, ships,
                   " (CLAMPED)" if bites else "         ",
                   str(per_parent[per_parent.size() - 1]["condition_2_shipped"]),
                   str(per_parent[per_parent.size() - 1]["condition_2_lifted"])]
                + "worst |dS|/S %s" % String.num(worst_rel, 6))

    var doc := {
        "_what": ("What `DetailField`'s octave ceiling costs decision 1040's condition 2, "
                + "per walked parent: the same grading run twice over the same stencils, "
                + "once at the shipped bound and once at the count the rows ask for."),
        "_the_comparison_is_paired": ("`StratumGrade` draws its sample positions, directions "
                + "and membership weights from the seed and the lag alone, so both ladders "
                + "are read at the same places. The difference is the added band."),
        "_the_normalisation_moves_with_it_and_barely": ("`residual_rms_for` is not published "
                + "at 1,600 m or 3,200 m and is computed from the running ladder, so lifting "
                + "the ceiling renormalises rather than simply adding variance. MEASURED, it "
                + "moves by 1.4e-7 to 4.7e-5 relative -- the added octaves are suppressed by "
                + "the row's own spectral slope and the ladder is normalised by sqrt(norm). "
                + "So the normalisation is carried correctly and is NOT what produces the "
                + "movement reported below: that is the band itself, four to five orders "
                + "larger."),
        "_the_control_is_the_unclamped_parents": ("At 100, 200, 400 and 800 m the lifted "
                + "ceiling does not bite and every S(l) must come back identical. "
                + "`control_moved` is empty when the instrument is measuring the ground."),
        "_this_does_not_rule_on_the_bound": ("Raising `MAX_OCTAVES` is a cost decision and is "
                + "not made here. 14 octaves per sample against 12 is a real price."),
        "_verdict_is_condition_2_only": ("Condition 3 is the spread clause and is reported by "
                + "the gate; this measures the band clause, which is the one the missing "
                + "octaves could move."),
        "_what_no_movement_does_and_does_not_license": ("The graded lags are 4, 8 and 16 m and "
                + "the octaves the clamp drops are at 0.39 m down to 0.25 m, and 0.78 m down "
                + "to 0.25 m -- one to two orders FINER than the shortest lag graded. A second "
                + "difference at 4 m is nearly blind to a band at 0.25 m by construction, so "
                + "'no verdict moved' is in part a statement about what this instrument can "
                + "see. It licenses the conclusion that the clamp does not move decision "
                + "1040's condition 2. It does NOT license the conclusion that the clamp is "
                + "invisible: the dropped band is sub-metre, which is walking-eye scale, and "
                + "walk mode is what opens at these parents. What a viewer standing there sees "
                + "is not graded by anything here."),
        "_where_the_effect_concentrates": ("On `playa`, at every parent and seed measured -- "
                + "the smoothest row, whose second difference is the one a fine band can move "
                + "proportionally most, and one of the two strata that make condition 2 UNMET "
                + "today. The margin to its band edge is the number to read beside the "
                + "movement, not the movement alone."),
        # THE FACTOR THE METRES WERE TAKEN AT. Required of every artefact in
        # `measurements/`, and the gate compares them against each other rather
        # than only asserting each names one -- a directory at two scales is one
        # set and one relic, and no file in it says which it is.
        "vertical_exaggeration": 1.0,
        "_vertical_exaggeration_is": ("the grader samples `Heightfield.height_at_world` and "
                + "`DetailField` directly. The view's factor is applied at mesh build and does "
                + "not reach this path, so these are field metres in both axes -- which is "
                + "what makes the lags comparable with the wavelengths the ladder drops."),
        "measured_at_utc": Time.get_datetime_string_from_system(true),
        "grading_parameters": {"span_m": SPAN_M, "quantile": QUANTILE,
                "samples_per_lag": SAMPLES, "seed": seed_used, "windows": sourced.size(),
                "lags_m": lags, "_are_the_gate_s": seed_used == SEED,
                "only_clamped_parents": only_clamped},
        "max_octaves_shipped": DetailField.MAX_OCTAVES,
        "walked_parents_m": wp.as_array(),
        "verdicts_that_moved": flips,
        "control_moved": control_moved,
        "per_parent": per_parent,
    }
    var w := FileAccess.open("res://" + out_path, FileAccess.WRITE)
    if w == null:
        printerr("octave_clamp: cannot write %s" % out_path)
        quit(1)
        return
    w.store_string(JSON.stringify(doc, "  ") + "\n")
    w.close()
    print("octave_clamp: seed %d -- %d verdict(s) moved; control moved at %d unclamped "
            % [seed_used, flips.size(), control_moved.size()]
            + "parent(s) -> %s" % out_path)
    for line in flips:
        print("octave_clamp: MOVED -- %s" % str(line))
    for line in control_moved:
        print("octave_clamp: CONTROL FAILED -- %s" % str(line))
    quit(0)


## The centres `tools/find_windows.gd` sourced. Refused rather than defaulted:
## grading a hand-picked set here would answer a different question from the one
## the gate answers.
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


## IS THE TIGHTEST CELL'S RATIO THE TAIL OR THE MODE?
##
## Three seeds put `playa`'s movement at 0.36, 0.01 and 0.16 of its distance to
## the band edge at a 1,600 m parent. Three samples cannot tell a tail from a
## mode, and the difference decides what the clamp IS: at 0.36 typical it is a
## substantive question about a stratum that already fails condition 2; at 0.36
## rare it is a wording one.
##
## THE TIGHTEST CELL IS TAKEN OVER `playa`'s THREE LAGS AND NOT AT A CHOSEN ONE.
## Which lag binds MOVES WITH THE SEED -- 8 m at seed 21, 16 m at seed 47 -- so
## fixing the lag would sample one cell's distribution and call it the tightest
## cell's. That is the same error as grading one landform and calling it the set.
##
## ONE PARENT, BECAUSE THE ASK NAMES ONE. 1,600 m is where the 0.36 is; 3,200 m's
## tightest was 0.20 and is reported in the per-parent artefacts.
##
## THE CONTROL IS SEED 21, WHICH IS ALREADY PUBLISHED. It falls inside the swept
## range, so its `S` values here must reproduce `octave_clamp.json`'s at this
## parent BIT FOR BIT. A sweep that re-derived them slightly differently would be
## measuring a different quantity from the one the question is about.
func _sweep(hf: Heightfield, layers: TerrainLayers, bands: Dictionary, lags: Array,
            sourced: Array, seeds: int) -> void:
    var parent_m := SWEEP_PARENT_M
    var shipped := DetailField.load_from(hf, DetailField.ROWS_PATH, parent_m, layers)
    var wanted := 1
    for name in shipped.landforms():
        wanted = maxi(wanted, shipped.octaves_wanted(str(name)))
    var lifted := DetailField.load_from(hf, DetailField.ROWS_PATH, parent_m, layers)
    lifted.octave_ceiling = wanted

    var rows: Array = []
    var ratios := PackedFloat64Array()
    var flips := 0
    var verdict_moves := 0
    for sd in range(1, seeds + 1):
        var ms := StratumGrade.over_windows(shipped, hf, sourced, SPAN_M, lags,
                QUANTILE, SAMPLES, sd)
        var ml := StratumGrade.over_windows(lifted, hf, sourced, SPAN_M, lags,
                QUANTILE, SAMPLES, sd)
        # CONDITION 2 ITSELF, AT EVERY SEED, because a flip in one stratum-lag is
        # not the conjunction and the difference is the whole question. `playa`
        # is one of two strata outside their bands here; if the other is out at
        # the same seed, `playa` crossing its own edge changes nothing that
        # decision 1040 grades. Measured rather than reasoned.
        var es := StratumGrade.evidence(ms, StratumGrade.spread(ms, lags), bands)
        var el := StratumGrade.evidence(ml, StratumGrade.spread(ml, lags), bands)
        var ok_s: Variant = (es.get("bands", {}) as Dictionary).get("ok", null)
        var ok_l: Variant = (el.get("bands", {}) as Dictionary).get("ok", null)
        if ok_s != ok_l:
            verdict_moves += 1
        var sh: Dictionary = (ms.get("strata", {}) as Dictionary).get(SWEEP_STRATUM, {})
        var li: Dictionary = (ml.get("strata", {}) as Dictionary).get(SWEEP_STRATUM, {})
        var best := -1.0
        var best_lag := NAN
        var per_lag: Array = []
        for lag_raw in lags:
            var lag := float(lag_raw)
            var a = sh.get(lag, null)
            var b = li.get(lag, null)
            var band: Array = (bands.get(SWEEP_STRATUM, {}) as Dictionary).get(lag, [])
            if a == null or b == null or band.size() != 2:
                continue
            var sa := float(a)
            var sb := float(b)
            var move: float = absf(sb - sa) / maxf(absf(sa), 1.0e-300)
            # THE DISTANCE TO THE NEARER EDGE, SIGNED BY WHICH SIDE IT IS ON.
            # A cell already outside its band is not at risk of flipping IN by a
            # movement of this size either, so both are reported as a distance.
            var margin := 0.0
            if sa < float(band[0]):
                margin = (float(band[0]) - sa) / absf(sa)
            elif sa > float(band[1]):
                margin = (sa - float(band[1])) / absf(sa)
            else:
                margin = minf(sa - float(band[0]), float(band[1]) - sa) / absf(sa)
            var ratio: float = (INF if margin <= 0.0 else move / margin)
            var in_s := sa >= float(band[0]) and sa <= float(band[1])
            var in_l := sb >= float(band[0]) and sb <= float(band[1])
            if in_s != in_l:
                flips += 1
            per_lag.append({"lag_m": lag, "s_shipped": sa, "s_lifted": sb,
                    "relative_change": move, "margin": margin, "ratio": ratio,
                    "in_band_shipped": in_s, "in_band_lifted": in_l})
            if ratio > best:
                best = ratio
                best_lag = lag
        if best < 0.0:
            continue
        ratios.append(best)
        rows.append({"seed": sd, "tightest_ratio": best, "tightest_lag_m": best_lag,
                "condition_2_shipped": ("not gradeable" if ok_s == null
                        else ("MET" if bool(ok_s) else "UNMET")),
                "condition_2_lifted": ("not gradeable" if ok_l == null
                        else ("MET" if bool(ok_l) else "UNMET")),
                "verdict_moved": ok_s != ok_l,
                "why_shipped": str((es.get("bands", {}) as Dictionary).get("why", "")),
                "why_lifted": str((el.get("bands", {}) as Dictionary).get("why", "")),
                "per_lag": per_lag})
        print("sweep: seed %3d  tightest %s at %s m lag" % [sd, String.num(best, 4),
                String.num(best_lag, 1)])

    var sorted_r := ratios.duplicate()
    sorted_r.sort()
    var n := sorted_r.size()
    var med: float = (NAN if n == 0 else (sorted_r[n / 2] if n % 2 == 1
            else 0.5 * (sorted_r[n / 2 - 1] + sorted_r[n / 2])))
    var over_half := 0
    var over_quarter := 0
    for r in ratios:
        if r >= 0.5:
            over_half += 1
        if r >= 0.25:
            over_quarter += 1
    var doc := {
        "_what": ("The tightest `playa` cell's movement as a fraction of its distance to the "
                + "band edge, at a 1,600 m parent, over consecutive seeds. Answers whether the "
                + "0.36 in the three-seed measurement is the tail or the mode."),
        "_tightest_is_over_the_three_lags": ("Which lag binds moves with the seed -- 8 m at seed "
                + "21, 16 m at seed 47 -- so fixing one lag would report a single cell's "
                + "distribution under the name of the tightest cell's."),
        "_a_ratio_of_1_is_a_flip": ("The ratio is movement / distance-to-edge, so 1.0 is a cell "
                + "the clamp could carry across its own band edge. `flips` counts the readings "
                + "where it actually did."),
        "_the_control_is_seed_21": ("Seed 21 is inside this range and its S values must "
                + "reproduce measurements/octave_clamp.json's at this parent bit for bit."),
        "_this_does_not_rule_on_the_bound": ("Raising `MAX_OCTAVES` is a cost decision and is "
                + "not made here."),
        "vertical_exaggeration": 1.0,
        "_vertical_exaggeration_is": ("the grader samples `Heightfield.height_at_world` and "
                + "`DetailField` directly; the view's factor does not reach this path."),
        "measured_at_utc": Time.get_datetime_string_from_system(true),
        "grading_parameters": {"span_m": SPAN_M, "quantile": QUANTILE,
                "samples_per_lag": SAMPLES, "windows": sourced.size(), "lags_m": lags,
                "_are_the_gate_s": true, "seeds": "1..%d" % seeds},
        "parent_spacing_m": parent_m,
        "stratum": SWEEP_STRATUM,
        "octaves_shipped": shipped.octaves_for(SWEEP_STRATUM),
        "octaves_lifted": lifted.octaves_for(SWEEP_STRATUM),
        "seeds_measured": n,
        "flips": flips,
        "_flips_are_cell_level": ("`flips` counts THIS STRATUM'S in/out-of-band readings that "
                + "the clamp carried across an edge. It is not decision 1040's verdict: the "
                + "conjunction is over every stratum, and `condition_2_verdict_moved` is the "
                + "count that answers what 1040 grades."),
        "condition_2_verdict_moved": verdict_moves,
        "ratio_min": (NAN if n == 0 else sorted_r[0]),
        "ratio_median": med,
        "ratio_max": (NAN if n == 0 else sorted_r[n - 1]),
        "seeds_at_or_above_0_5": over_half,
        "seeds_at_or_above_0_25": over_quarter,
        "per_seed": rows,
    }
    var w := FileAccess.open("res://" + SWEEP_OUT, FileAccess.WRITE)
    if w == null:
        printerr("octave_clamp: cannot write %s" % SWEEP_OUT)
        quit(1)
        return
    w.store_string(JSON.stringify(doc, "  ") + "\n")
    w.close()
    print("sweep: %d seed(s) at %s m, %s: tightest ratio min %s median %s max %s; %d at or above "
            % [n, String.num(parent_m, 0), SWEEP_STRATUM, String.num(sorted_r[0], 4),
               String.num(med, 4), String.num(sorted_r[n - 1], 4), over_quarter]
            + "0.25, %d at or above 0.5, %d cell-level flip(s), %d condition-2 verdict move(s) "
            % [over_half, flips, verdict_moves] + "-> %s" % SWEEP_OUT)
    quit(0)
