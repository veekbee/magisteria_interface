extends SceneTree

## Window sourcing for decision 1019's bands: find a centre set that covers the
## JOINT HAND-by-slope membership space, not a few places that happen to be
## adjacent.
##
## WHY THIS EXISTS NOW, AHEAD OF THE BANDS IT SERVES. `StratumGrade.gradeable`
## returns `NO_COVERAGE` BEFORE it returns `NO_BANDS`, and the six hand-picked
## centres in the gate cover three of the five strata -- `playa` and
## `riparian_margin` fall below the sampling floor at every lag. So when the
## fixture re-cut publishes decision 985's measured band values, walk mode's
## conditions 2 and 3 would STILL read NOT_GRADEABLE, and the refusal would name
## coverage rather than the values that just arrived. The producing side would
## have shipped the thing everyone was waiting for and the gate would not move.
##
## Window sourcing is the client's own item -- 1019 says so, and
## `StratumGrade.gradeable` splits the two refusals precisely so that the
## actionable half is visible. This is that half, taken while the other is still
## in flight.
##
## HEADLESS. Membership is evaluated on real HAND and slope from the terrain
## layers; nothing here needs a frame or a person.
##
## THE SEARCH IS A PROXY AND THE VERDICT IS NOT. Candidate centres are ranked by
## membership mass sampled over the window, which is cheap and approximate. What
## is reported is the result of running `StratumGrade.over_windows` on the chosen
## set and asking `gradeable` -- the real grader, at the real sample count. A
## proxy that selected well and a grader that still refuses is the outcome this
## separation exists to make visible rather than to hide.

const OUT := "measurements/window_sourcing.json"

## The span `StratumGrade` is called with in the gate, so the search selects for
## the geometry the grader will actually use. A centre good for a 3 km window is
## not necessarily good for a 10 km one.
const SPAN_M := 3000.0
const LAGS := [4.0, 8.0, 16.0]
## The gate's own sample count, for the same reason.
const SAMPLES_PER_LAG := 300
const SEED := 21

## How many candidate centres to draw before selecting. The basin is large and
## the two missing strata are small, so a coarse scan finds nothing: `playa` and
## `riparian_margin` are the corners of the membership space, which is why they
## are the ones missing.
const SCAN_SIDE := 96
## Points sampled inside a candidate window to estimate its membership mass.
const PROBE_POINTS := 220

const RULED_BY := {
    "decision": "1019",
    "clause": ("window sourcing covers the joint HAND-by-slope membership space rather than "
            + "filling criterion 1b's five elevation classes; the calibration support is the "
            + "window, membership per point within it, never the catchment median"),
    "serves": "decision 986's walk-mode conditions 2 and 3, via §24 gap 164's ruling",
}


func _init() -> void:
    var f := FileAccess.open("res://assets/terrain/terrain_export.json", FileAccess.READ)
    if f == null:
        printerr("find_windows: no terrain_export.json")
        quit(1)
        return
    var man: Dictionary = JSON.parse_string(f.get_as_text())
    var hf := Heightfield.load_from(man, "res://assets/terrain/heightfield_overview.png")
    var layers := TerrainLayers.load_from()
    if not layers.is_fetched():
        printerr("find_windows: the terrain layers are not fetched, so membership cannot be "
                + "evaluated on real ground. `python3 tools/fetch_artefacts.py`")
        quit(1)
        return
    var df := DetailField.load_from(hf, DetailField.ROWS_PATH, 0.0, layers)
    if not df.is_loaded():
        printerr("find_windows: the detail rows did not load")
        quit(1)
        return
    # REAL HAND AND SLOPE OR NOTHING, the same refusal `StratumGrade` makes. A
    # classifier re-deriving slope from the parent lattice is a different
    # stratification wearing the same names, and a window set sourced against it
    # would be sourced for a basin that is not this one.
    if df.classifier_source().begins_with("the parent lattice"):
        printerr("find_windows: the classifier is re-deriving slope from the lattice, so "
                + "membership is not being read from real ground")
        quit(1)
        return

    var strata := df.landforms()
    print("find_windows: %d strata -- %s" % [strata.size(), str(strata)])

    var candidates := _scan(df, hf, strata)
    print("find_windows: %d candidate centres on ground" % candidates.size())
    var chosen := _select(candidates, strata)
    var centres: Array = []
    for c in chosen:
        centres.append((c as Dictionary)["centre"])

    # THE REAL GRADER, NOT THE PROXY.
    var m := StratumGrade.over_windows(df, hf, centres, SPAN_M, LAGS, 0.5, SAMPLES_PER_LAG, SEED)
    var verdict := StratumGrade.gradeable(m, {})
    var covered := PackedStringArray()
    var uncovered := PackedStringArray()
    for name in (m.get("strata", {}) as Dictionary):
        var entry: Dictionary = (m["strata"] as Dictionary)[name]
        var n := 0
        for lag in entry:
            if typeof(lag) == TYPE_FLOAT and entry[lag] != null:
                n += 1
        if n > 0:
            covered.append(str(name))
        else:
            uncovered.append(str(name))

    print("find_windows: %d centres cover %d/%d strata -- covered %s, uncovered %s"
            % [centres.size(), covered.size(), strata.size(), str(covered), str(uncovered)])
    print("find_windows: the grader says %s"
            % ("gradeable but for the bands" if str(verdict.get("why", "")).begins_with(
                    StratumGrade.NO_BANDS) or bool(verdict.get("ok", false))
               else str(verdict.get("why", ""))))

    var out_centres: Array = []
    for c in chosen:
        var d: Dictionary = c
        var w: Vector2 = d["centre"]
        out_centres.append({
            "world_m": [w.x, w.y],
            "texel": [float((d["texel"] as Vector2).x), float((d["texel"] as Vector2).y)],
            "chosen_for": d["chosen_for"],
            "membership_mass": d["mass"],
        })

    var doc := {
        "_what": ("Window centres covering decision 1019's joint HAND-by-slope membership "
                + "space, so that decision 986's walk-mode conditions 2 and 3 refuse for the "
                + "reason that is actually outstanding -- the published band values -- rather "
                + "than for coverage the client can fix itself."),
        "_the_verdict_is_the_graders": ("The selection is a membership-mass proxy. What is "
                + "reported below is `StratumGrade.over_windows` run on the selected set at the "
                + "gate's own span, lags and sample count, and `gradeable` asked. A proxy that "
                + "chose well and a grader that still refuses is a result, not an error."),
        "measured_at_commit": _commit(),
        "ruled_by": RULED_BY,
        # TRUE METRES, AND THE REASON IS A PATH RATHER THAN A SETTING. The
        # exaggeration lives on `TerrainView` and is applied when the mesh is
        # built; `StratumGrade` reads the heightfield and the detail field
        # directly, so nothing on this path has ever seen the factor. Recorded
        # at 1.0 because that is what it is here, not because 1.0 is the value
        # every other artefact in `measurements/` happens to carry -- a number
        # copied for agreement is the relic the directory-wide check exists to
        # catch.
        "vertical_exaggeration": 1.0,
        "_vertical_exaggeration_is": ("the grader samples `Heightfield.height_at_world` and "
                + "`DetailField` directly. The view's factor is applied at mesh build and does "
                + "not reach this path, so these are field metres in both axes."),
        "geometry": {"span_m": SPAN_M, "lags": LAGS, "samples_per_lag": SAMPLES_PER_LAG,
                "seed": SEED, "min_effective_samples": StratumGrade.MIN_EFFECTIVE_SAMPLES},
        "classifier_source": df.classifier_source(),
        "strata": Array(strata),
        "centres": out_centres,
        "grader": {
            "windows": m.get("windows", 0),
            "covered": Array(covered),
            "uncovered": Array(uncovered),
            "ok": verdict.get("ok", false),
            "why": verdict.get("why", ""),
            "n_effective": _n_effective(m, strata),
        },
    }
    var w := FileAccess.open("res://" + OUT, FileAccess.WRITE)
    if w == null:
        printerr("find_windows: cannot write %s" % OUT)
        quit(1)
        return
    w.store_string(JSON.stringify(doc, "  "))
    w.close()
    print("find_windows: wrote %s" % OUT)
    quit(0)


## Per-stratum effective sample count at the best lag, which is what the floor is
## read against. Reported so that a stratum sitting just under 256 is visible as
## a near miss rather than as a flat absence.
func _n_effective(m: Dictionary, strata: PackedStringArray) -> Dictionary:
    var out := {}
    for name in strata:
        var entry: Dictionary = (m.get("strata", {}) as Dictionary).get(str(name), {})
        out[str(name)] = float(entry.get("n_effective", 0.0))
    return out


## Candidate centres on ground, each with the membership mass a window there
## would carry.
func _scan(df: DetailField, hf: Heightfield, strata: PackedStringArray) -> Array:
    var out: Array = []
    var step_x := float(hf.width) / float(SCAN_SIDE)
    var step_y := float(hf.height) / float(SCAN_SIDE)
    var rng := RandomNumberGenerator.new()
    rng.seed = SEED
    for iy in SCAN_SIDE:
        for ix in SCAN_SIDE:
            var tx := (float(ix) + 0.5) * step_x
            var ty := (float(iy) + 0.5) * step_y
            var c := hf.texel_to_world(tx, ty)
            if not is_finite(hf.height_at_world(c.x, c.y)):
                continue
            var mass := _mass_at(df, hf, c, strata, rng)
            if mass.is_empty():
                continue
            out.append({"centre": c, "texel": Vector2(tx, ty), "mass": mass})
    return out


## Membership mass inside one window, as an effective-n estimate per stratum.
##
## KISH'S EFFECTIVE N AND NOT A SUM, because that is what the grader's floor is
## read against: a window where one point carries all the membership has mass 1
## by either measure and an effective n of 1, and the floor is there to refuse
## exactly that.
func _mass_at(df: DetailField, hf: Heightfield, centre: Vector2,
              strata: PackedStringArray, rng: RandomNumberGenerator) -> Dictionary:
    var half := SPAN_M * 0.5
    var sums := {}
    var sq := {}
    for name in strata:
        sums[str(name)] = 0.0
        sq[str(name)] = 0.0
    var on_ground := 0
    for _i in PROBE_POINTS:
        var p := centre + Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
        if not is_finite(hf.height_at_world(p.x, p.y)):
            continue
        on_ground += 1
        var weights := df.weights_at(p)
        for name in weights:
            var v := float(weights[name])
            sums[str(name)] = float(sums.get(str(name), 0.0)) + v
            sq[str(name)] = float(sq.get(str(name), 0.0)) + v * v
    if on_ground < PROBE_POINTS / 2:
        return {}
    var out := {}
    for name in strata:
        var s := float(sums[str(name)])
        var s2 := float(sq[str(name)])
        out[str(name)] = 0.0 if s2 <= 0.0 else (s * s) / s2
    return out


## Greedy cover: take the centre that most helps the stratum currently worst off.
##
## GREEDY AND NOT OPTIMAL, and the artefact says so. What matters is that every
## stratum clears the floor, not that the set is minimal -- and the grader's
## verdict is what decides whether it did.
func _select(candidates: Array, strata: PackedStringArray) -> Array:
    var chosen: Array = []
    var running := {}
    for name in strata:
        running[str(name)] = 0.0
    # The floor is per lag over the POOLED windows, so a centre contributes its
    # mass to the running total rather than having to clear the floor alone.
    var target := StratumGrade.MIN_EFFECTIVE_SAMPLES
    for _round in strata.size() * 2:
        var worst := ""
        var worst_v := INF
        for name in strata:
            var v := float(running[str(name)])
            if v < worst_v:
                worst_v = v
                worst = str(name)
        if worst == "" or worst_v >= target:
            break
        var best := -1
        var best_gain := 0.0
        for i in candidates.size():
            var d: Dictionary = candidates[i]
            if d.get("taken", false):
                continue
            var gain := float((d["mass"] as Dictionary).get(worst, 0.0))
            if gain > best_gain:
                best_gain = gain
                best = i
        if best < 0:
            break
        var picked: Dictionary = candidates[best]
        picked["taken"] = true
        picked["chosen_for"] = worst
        chosen.append(picked)
        for name in strata:
            running[str(name)] = float(running[str(name)]) \
                    + float((picked["mass"] as Dictionary).get(str(name), 0.0))
        print("find_windows: picked a window for %s (mass %s); running %s"
                % [worst, String.num(best_gain, 1), str(_rounded(running))])
    return chosen


func _rounded(d: Dictionary) -> Dictionary:
    var out := {}
    for k in d:
        out[k] = roundf(float(d[k]))
    return out


func _commit() -> String:
    var o: Array = []
    var code := OS.execute("git", ["rev-parse", "--short", "HEAD"], o, true)
    return "unknown" if code != 0 or o.is_empty() else str(o[0]).strip_edges()
