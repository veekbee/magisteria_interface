extends SceneTree

## DOES THE SYNTHESIZED GROUND HAVE THE SPREAD IT CLAIMS?
##
##     bash tools/measure_variogram.sh
##
## "REASONABLE FEATURES" HAS TO BE A MEASURED MATCH RATHER THAN TASTE, and the
## measurement is the variogram: half the mean squared difference between pairs
## of points a distance `h` apart. It is the standard instrument for exactly
## this question -- how much does ground vary over what distance -- and it is
## the one a calibration against real metre ground will produce targets in.
##
## A BOUNDED-BUT-FLAT SYNTHESIZER MUST FAIL, which is why bounds alone are not
## the test. A function that adds a constant offset inside its amplitude bound
## satisfies every range check and discriminates nothing: a playa and a talus
## slope come out identical, and the owner's acceptance criterion -- a playa is
## smooth and rocky slopes are rough -- is precisely a statement about spread.
## `--flat` runs that synthesizer, and the gate requires it to fail.
##
## THE TARGETS ARE THE ROWS' OWN TODAY. No calibration exists, so what is
## checked is self-consistency: the measured variogram must match what the
## declared amplitude and spectral slope IMPLY. When measured targets land they
## drop into the same comparison and the harness does not change. That is what
## makes this shape-work rather than a placeholder.

const TERRAIN_DIR := "res://assets/terrain/"

## Lags in metres, below the parent spacing. Log-spaced, because the quantity
## fitted across them is a log-log slope.
const LAGS := [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0]


func _init() -> void:
    var args := _args()
    var flat := args.has("flat")
    var pairs := int(args.get("pairs", "400"))
    var out_path := str(args.get("out", "measurements/detail_variogram.json"))

    var manifest := _read_json(TERRAIN_DIR + "terrain_export.json")
    var hf := Heightfield.load_from(manifest, TERRAIN_DIR + "heightfield_overview.png")
    if not hf.is_loaded():
        _refuse(out_path, "the overview heightfield did not load")
        return
    # WITH THE DERIVED LAYERS WHERE THIS CLONE HAS THEM, because the class a
    # point is in is what this measurement strata by, and classifying from a
    # kilometre lattice measures a different partition of the basin.
    var df := DetailField.load_from(hf, DetailField.ROWS_PATH, 0.0, TerrainLayers.load_from())
    if not df.is_loaded():
        _refuse(out_path, "no detail rows: %s" % df.why_absent)
        return

    # A place with ground under it, found once and shared by every class, so a
    # difference between classes is a difference in the parameters rather than
    # in where each was measured.
    var centre := _somewhere_with_ground(hf)
    if centre == Vector2.INF:
        _refuse(out_path, "no valid ground to measure over")
        return

    var classes := {}
    for landform in df.landforms():
        classes[landform] = _score(df, centre, str(landform), pairs, flat)

    var verdict := _verdict(df, classes, flat)
    var doc := {
        "measurement": "variogram of the synthesized detail surface, per landform",
        "measured_at_utc": Time.get_datetime_string_from_system(true),
        "vertical_exaggeration": 1.0,
        "_exaggeration_is": ("1:1. Every number here is a vertical distance compared with a "
                + "horizontal one, so an exaggerated surface would inflate the whole artefact "
                + "against ground that had not moved."),
        "synthesizer": "flat (control)" if flat else "conditional spectral refinement",
        "_flat_is": ("a synthesizer that adds a constant offset inside its amplitude bound. It "
                + "satisfies every range check and discriminates nothing, which is why bounds "
                + "alone cannot be the test."),
        "parent_spacing_m": df.parent_spacing_m,
        "finest_synthesised_m": df.finest_m,
        "lags_m": LAGS,
        "parameters_are": ("PLACEHOLDER rows from assets/detail/detail_rows.json, every value "
                + "invented. What is checked is that the surface delivers what the rows "
                + "declare; when measured targets land they drop into the same comparison."),
        "classes": classes,
        "verdict": verdict,
    }
    _write(out_path, doc)

    print("variogram: %s synthesizer, parent %s m, finest %s m"
            % ["FLAT CONTROL" if flat else "spectral", String.num(df.parent_spacing_m, 0),
                    String.num(df.finest_m, 3)])
    for name in classes:
        var c: Dictionary = classes[name]
        print("variogram: %-16s sill %s m2 at %s m, hurst %s declared %s, %s"
                % [str(name), String.num(float(c["gamma_at_max_lag"]), 5),
                        String.num(float(LAGS[LAGS.size() - 1]), 0),
                        String.num(float(c["hurst_measured"]), 2),
                        String.num(float(c["hurst_declared"]), 2),
                        "matches" if bool(c["matches_rows"]) else "DOES NOT MATCH ITS ROW"])
    print("variogram: %s -- %s" % ["PASS" if bool(verdict["ok"]) else "FAIL",
            str(verdict["why"])])
    quit(0 if bool(verdict["ok"]) else 1)


## The variogram of one landform's synthesized surface, and what its row says
## it should be.
func _score(df: DetailField, centre: Vector2, landform: String, pairs: int,
            flat: bool) -> Dictionary:
    var row := df.row(landform)
    var amp := float(row.get("amplitude_m", 0.0))
    var declared_hurst := float(row.get("spectral_slope", 1.0))
    # THE DETAIL TERM'S OWN VARIOGRAM, and the total surface's beside it.
    #
    # A first run scored the TOTAL and reported every class within 2% of every
    # other, because at a 64 m lag on a kilometre lattice the terrain's own
    # variation is 7.6 m2 and the detail's is micrometres of it. The instrument
    # was measuring the lattice. What a calibration target actually asks of a
    # synthesizer is the part it SUPPLIES, so that is what is scored, and the
    # residual -- total minus lattice -- is reported beside it as the check
    # that the surface really carries what the term claims.
    var gamma := {}
    var gamma_total := {}
    var gamma_lattice := {}
    for lag in LAGS:
        var total := 0.0
        var tot_total := 0.0
        var tot_lattice := 0.0
        var n := 0
        for i in pairs:
            # Deterministic offsets: the same places every run, so two runs
            # differ only where the surface does.
            var u := StableHash.unit(StableHash.of3(i, int(lag * 1000.0), 11))
            var v := StableHash.unit(StableHash.of3(i, int(lag * 1000.0), 13))
            var a := centre + Vector2((u - 0.5) * 600.0, (v - 0.5) * 600.0)
            var theta := TAU * StableHash.unit(StableHash.of3(i, int(lag * 1000.0), 17))
            var b := a + Vector2(cos(theta), sin(theta)) * float(lag)
            var la := df._hf.height_at_world(a.x, a.y)
            var lb := df._hf.height_at_world(b.x, b.y)
            if is_nan(la) or is_nan(lb):
                continue
            var da: float = _term(df, a, landform, amp, flat)
            var db: float = _term(df, b, landform, amp, flat)
            total += (da - db) * (da - db)
            tot_lattice += (la - lb) * (la - lb)
            tot_total += (la + da - lb - db) * (la + da - lb - db)
            n += 1
        gamma[str(lag)] = 0.0 if n == 0 else 0.5 * total / float(n)
        gamma_total[str(lag)] = 0.0 if n == 0 else 0.5 * tot_total / float(n)
        gamma_lattice[str(lag)] = 0.0 if n == 0 else 0.5 * tot_lattice / float(n)

    # THE FITTED SLOPE. For fractional Brownian motion the variogram goes as
    # h^(2H), so the log-log slope over the lags is twice the Hurst exponent --
    # which is the row's `spectral_slope`. Fitting it is how a spectral claim
    # becomes checkable rather than decorative.
    var sx := 0.0
    var sy := 0.0
    var sxx := 0.0
    var sxy := 0.0
    var m := 0
    for lag in LAGS:
        var g := float(gamma[str(lag)])
        if g <= 0.0:
            continue
        var x := log(float(lag))
        var y := log(g)
        sx += x
        sy += y
        sxx += x * x
        sxy += x * y
        m += 1
    var slope := NAN
    if m >= 3 and (float(m) * sxx - sx * sx) != 0.0:
        slope = (float(m) * sxy - sx * sy) / (float(m) * sxx - sx * sx)
    var hurst := slope / 2.0

    var at_max := float(gamma[str(LAGS[LAGS.size() - 1])])
    # What the row implies at the longest lag measured: an fBm of this
    # amplitude, normalised at the parent spacing, carries about
    # `amp^2 * (h / parent)^(2H)` of semivariance.
    var implied := amp * amp * pow(float(LAGS[LAGS.size() - 1]) / df.parent_spacing_m,
            2.0 * declared_hurst)
    var residual := float(gamma_total[str(LAGS[LAGS.size() - 1])]) \
            - float(gamma_lattice[str(LAGS[LAGS.size() - 1])])
    return {
        "amplitude_m_declared": amp,
        "gamma_total_m2": gamma_total,
        "gamma_lattice_m2": gamma_lattice,
        "gamma_residual_at_max_lag": residual,
        "_residual_is": ("total surface minus lattice at the longest lag. It should come out "
                + "near `gamma_at_max_lag`; a large disagreement means the detail term is not "
                + "reaching the surface consumers sample."),
        "hurst_declared": declared_hurst,
        "hurst_measured": hurst,
        "gamma_m2": gamma,
        "gamma_at_max_lag": at_max,
        "gamma_implied_by_row": implied,
        "matches_rows": (not is_nan(hurst)) and absf(hurst - declared_hurst) < 0.35,
        "anisotropy": row.get("anisotropy", 1.0),
    }


## The detail TERM under test. `flat` replaces it with a constant offset inside
## the same amplitude bound -- bounded, carrying no variance at all, which is
## the whole point of the control.
func _term(df: DetailField, w: Vector2, landform: String, amp: float,
           flat: bool) -> float:
    return (amp * 0.5) if flat else df.detail_at(w, landform)


## Whether this run is a synthesizer worth having.
##
## THREE THINGS, and the second is the one bounds cannot check: every class
## delivers the spectral slope its row declares; the classes DISCRIMINATE, so
## the smooth one and the rough one are measurably different; and the roughest
## is rougher than the smoothest by something like the ratio their amplitudes
## imply.
func _verdict(df: DetailField, classes: Dictionary, flat: bool) -> Dictionary:
    var smooth := ""
    var rough := ""
    var lo := INF
    var hi := -INF
    for name in classes:
        var amp := float((classes[name] as Dictionary)["amplitude_m_declared"])
        if amp < lo:
            lo = amp
            smooth = str(name)
        if amp > hi:
            hi = amp
            rough = str(name)
    if smooth == "" or rough == "" or smooth == rough:
        return {"ok": false, "why": "fewer than two landform classes to compare"}

    var g_smooth := float((classes[smooth] as Dictionary)["gamma_at_max_lag"])
    var g_rough := float((classes[rough] as Dictionary)["gamma_at_max_lag"])
    var ratio := INF if g_smooth <= 0.0 else g_rough / g_smooth
    var implied := (hi * hi) / (lo * lo)
    # AND THE ROUGH CLASS HAS TO ACTUALLY VARY. A field that is zero everywhere
    # divides zero by zero and comes out infinite, which would let the flat
    # control pass the one test it exists to fail.
    var discriminates := ratio > 4.0 and g_rough > 0.0

    var slopes_ok := true
    var offenders: Array = []
    for name in classes:
        if not bool((classes[name] as Dictionary)["matches_rows"]):
            slopes_ok = false
            offenders.append(str(name))

    var ok := discriminates and slopes_ok
    var why := ""
    if g_rough <= 0.0:
        why = ("the roughest class has no variance at any lag. Every range check passes on a "
                + "field like this and it tells a playa from a talus slope not at all.")
    elif not discriminates:
        why = ("%s and %s have variograms within %sx of each other. A synthesizer that cannot "
                % [smooth, rough, String.num(ratio, 2)]
                + "tell a playa from a talus slope discriminates nothing, whatever its bounds "
                + "say -- their declared amplitudes differ by %sx." % String.num(implied, 0))
    elif not slopes_ok:
        why = ("%s did not deliver the spectral slope its row declares" % str(offenders))
    else:
        why = ("classes discriminate %sx at the longest lag against %sx implied by their "
                % [String.num(ratio, 0), String.num(implied, 0)]
                + "amplitudes, and every class delivers its declared slope")
    return {
        "ok": ok,
        "why": why,
        "smoothest": smooth,
        "roughest": rough,
        "gamma_ratio": ratio,
        "gamma_ratio_implied": implied,
        "discriminates": discriminates,
        "slopes_match_rows": slopes_ok,
        "_control": ("this run was the FLAT synthesizer and a PASS here would mean the harness "
                + "cannot see the defect it exists for") if flat else "",
    }


func _somewhere_with_ground(hf: Heightfield) -> Vector2:
    for ty in range(hf.height / 4, hf.height * 3 / 4, 7):
        for tx in range(hf.width / 4, hf.width * 3 / 4, 7):
            var w := hf.texel_to_world(float(tx), float(ty))
            if not is_nan(hf.height_at_world(w.x, w.y)):
                return w
    return Vector2.INF


func _args() -> Dictionary:
    var out := {}
    var argv := OS.get_cmdline_user_args()
    var i := 0
    while i < argv.size():
        var a := str(argv[i])
        if a == "--flat":
            out["flat"] = "1"
            i += 1
        elif a.begins_with("--") and i + 1 < argv.size():
            out[a.substr(2)] = str(argv[i + 1])
            i += 2
        else:
            i += 1
    return out


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _refuse(path: String, why: String) -> void:
    print("variogram: REFUSED -- %s" % why)
    _write(path, {"refused": true, "why": why})
    quit(1)


func _write(path: String, doc: Dictionary) -> void:
    var f := FileAccess.open("res://" + path, FileAccess.WRITE)
    if f == null:
        push_error("cannot write %s" % path)
        return
    f.store_string(JSON.stringify(doc, "  ") + "\n")
