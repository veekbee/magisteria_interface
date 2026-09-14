extends SceneTree

## Cross-parent invariance, per landform: does one row draw the same ground
## under the two parents this client refines?
##
## WHY THIS IS A TOOL AND NOT A WIDER GATE ASSERTION. The gate asserts the
## property on ONE landform -- `talus`, hardcoded in `_detail_variance` -- and
## that was passing for a lucky reason: under the rows vendored at
## `magisteria_interface@4671cc6`, `talus` carried the SHALLOWEST exponent in
## the set and the ratio is monotone in the exponent. Two other rows already
## exceeded the bound the gate enforces, unmeasured, for as long as the check
## has existed. Widening the assertion is the right fix and turns the gate red
## on the rows currently shipped, so it waits on a ruling. THE MEASUREMENT DOES
## NOT WAIT: this reports every landform every time it is run, so the table is
## reproducible rather than something I once saw.
##
## `--rows <path>` MEASURES AN ARTEFACT THAT IS NOT VENDORED, which is the point
## of it. The producing side can run this against its own output before
## dispatching, and so can I against a candidate before committing it. A
## property that only becomes visible after a re-vendor is one both sides
## discover too late.
##
## WHAT IS MEASURED, AND THE FIRST CUT OF THIS MEASURED THE WRONG THING.
##
## It took `0.5 * mean((z(x+L) - z(x))^2)` -- a FIRST difference -- and reported
## ratios from 1.5 to 20.9 that grow with `spectral_slope`. The producing side
## could not reproduce them against `sim/detail.py` and got 0.97 to 1.13, which
## looked for a day like two implementations of a ruled function disagreeing by
## an order of magnitude.
##
## THEY DO NOT DISAGREE. Decision 1019 rules the SECOND difference for exactly
## this reason: it is gradient-blind by construction. Under a 1 km parent the
## detail term legitimately carries the 100-1000 m band, which under a 100 m
## parent is carried by the DATA instead -- so at an 8 m lag a first difference
## is dominated by the local slope of those coarse octaves, which is not
## roughness at 8 m at all. The ratio grew with the exponent because a steeper
## exponent concentrates variance in the coarsest octave. That is the band
## decomposition working, reported as a defect.
##
## So this reads `StructureFunction` in its `detrended` form, which is the one
## definition of the second difference in this tree. A third hand-rolled copy is
## what produced the first cut.

const OUT := "measurements/cross_parent.json"
## The two parents this client actually refines: the shipped overview and the
## pyramid's finest level. Not a sweep -- these are the lattices a level switch
## moves between, and the switch is what the property is about.
const COARSE_M := 1000.0
const FINE_M := 100.0
## A graded lag (`StratumGrade.GRADED_LAGS`), so the number speaks to what walk
## mode's conditions 2 and 3 compare against rather than to a lag nothing reads.
const LAG_M := 8.0
## The window the second difference is measured over. It must hold the whole
## centred stencil -- `2 * lag * sqrt(2)` -- with room for the sample cloud.
const SPAN_M := 400.0
const SAMPLES := 4000
const SEED := 11


func _init() -> void:
    var rows := DetailField.ROWS_PATH
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if str(args[i]) == "--rows" and i + 1 < args.size():
            rows = str(args[i + 1])
    var f := FileAccess.open("res://assets/terrain/terrain_export.json", FileAccess.READ)
    if f == null:
        printerr("measure_cross_parent: no terrain_export.json")
        quit(1)
        return
    var man: Dictionary = JSON.parse_string(f.get_as_text())
    var hf := Heightfield.load_from(man, "res://assets/terrain/heightfield_overview.png")
    var coarse := DetailField.load_from(hf, rows, COARSE_M)
    var fine := DetailField.load_from(hf, rows, FINE_M)
    if not (coarse.is_loaded() and fine.is_loaded()):
        printerr("measure_cross_parent: the rows did not load at both parents: %s"
                % coarse.why_absent)
        quit(1)
        return

    var at := hf.texel_to_world(500.0, 700.0)
    var per: Array = []
    var worst := 0.0
    var worst_name := ""
    for name in coarse.landforms():
        var n := str(name)
        var gc := _detrended(coarse, at, LAG_M, n)
        var gf := _detrended(fine, at, LAG_M, n)
        var ratio: float = maxf(gc, gf) / maxf(minf(gc, gf), 1.0e-12)
        if ratio > worst:
            worst = ratio
            worst_name = n
        per.append({
            "landform": n,
            "spectral_slope": DetailField.scalar_of(coarse.row(n), "spectral_slope", NAN),
            "amplitude_m": DetailField.scalar_of(coarse.row(n), "amplitude_m", NAN),
            "calibration_parent_m": coarse.calibration_parent_of(n),
            "octaves_coarse": coarse.octaves_for(n),
            "octaves_fine": fine.octaves_for(n),
            "s_detrended_coarse": gc,
            "s_detrended_fine": gf,
            "ratio": ratio,
        })
        print("cross_parent: %-16s slope %s  ratio %s"
                % [n, String.num(float(per[per.size() - 1]["spectral_slope"]), 4),
                   String.num(ratio, 2)])
    print("cross_parent: worst is %s at %sx" % [worst_name, String.num(worst, 2)])

    var doc := {
        "_what": ("Cross-parent invariance per landform: the same row's detail term measured at "
                + "one graded lag under the two parents this client refines. A ratio above 1 is "
                + "ground that changes when a streaming level switches."),
        "_why_it_matters": ("§23.977 measured 3.55x cross-parent disagreement with the "
                + "calibration parent UNDECLARED and 1.43x with it declared, which is why "
                + "`calibrated_at_parent_m` exists. This measures what the declared rescale "
                + "actually delivers, per row, rather than on the one row the gate asserts."),
        "_the_gate_asserts_less_than_this": ("`tests/run_headless.gd` asserts the property on "
                + "`talus` alone. That row carried the shallowest exponent in the set it was "
                + "written against, and the ratio is monotone in the exponent, so the assertion "
                + "was measuring the most favourable member of the set it generalises over."),
        "measured_at_commit": _commit(),
        "rows_read": rows,
        "rows_are_vendored": rows == DetailField.ROWS_PATH,
        "vertical_exaggeration": 1.0,
        "_vertical_exaggeration_is": ("the detail field is sampled directly; the view's factor is "
                + "applied at mesh build and does not reach this path"),
        "geometry": {"coarse_parent_m": COARSE_M, "fine_parent_m": FINE_M, "lag_m": LAG_M,
                "span_m": SPAN_M, "samples": SAMPLES, "seed": SEED,
                "form": "detrended",
                "_form_is": ("decision 1019's second difference, gradient-blind by "
                        + "construction. The first cut of this tool used a first difference and "
                        + "reported a 20.9x disagreement that was its own instrument."),
                "_lag_is": "a member of StratumGrade.GRADED_LAGS"},
        "worst": {"landform": worst_name, "ratio": worst},
        "landforms": per,
    }
    var w := FileAccess.open("res://" + OUT, FileAccess.WRITE)
    if w == null:
        printerr("measure_cross_parent: cannot write %s" % OUT)
        quit(1)
        return
    w.store_string(JSON.stringify(doc, "  "))
    w.close()
    print("cross_parent: wrote %s" % OUT)
    quit(0)


## Decision 1019's second difference on the detail term alone, through the one
## implementation of it this tree has.
##
## THE DETAIL TERM AND NOT THE DRAWN GROUND. The question is whether one ROW
## draws the same thing under two parents; the parent surface is the same field
## either way and would dilute the comparison with ground neither parent is
## responsible for.
func _detrended(df: DetailField, at: Vector2, lag: float, landform: String) -> float:
    var sampler := func(x: float, y: float) -> float:
        return df.detail_at(Vector2(x, y), landform)
    var sf := StructureFunction.of_function(sampler, at - Vector2(SPAN_M, SPAN_M) * 0.5,
            Vector2(SPAN_M, SPAN_M), "detail term, %s" % landform)
    var s := sf.s_of_lag([lag], 0.5, "detrended", SAMPLES, SEED)
    var v = s.get(lag, null)
    return NAN if v == null or typeof(v) == TYPE_DICTIONARY else float(v)


func _commit() -> String:
    var o: Array = []
    var code := OS.execute("git", ["rev-parse", "--short", "HEAD"], o, true)
    return "unknown" if code != 0 or o.is_empty() else str(o[0]).strip_edges()
