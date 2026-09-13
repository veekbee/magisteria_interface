extends SceneTree

## §24 gap 170 items (ii) and (iii): decision 1030's solved horizon, evaluated
## over the basin fixture.
##
## HEADLESS, AND THAT IS THE POINT OF IT. Item (i) needs frames and therefore a
## window and a person. These two do not: `k(place)` is arithmetic over realised
## wire quantities and committed coefficients --
##
##     k(place) = min(0.35 * k_res,
##                    sqrt(B_eff / (pi * SUM_f cover_f * height_f^2 * c_f / crown_area_f)))
##
## -- every term of which is in the fixture, in `families.json`, or in
## `render_cost.json`. So the spread assertion, which is the item most likely to
## falsify the form, can be taken before anyone spends a windowed session on
## frame timings.
##
## WHAT THIS DOES NOT DO: change what is drawn. Decision 1030 says the client
## changes nothing now and C2 executes against the shape on its own roadmap.
## This evaluates the solve; it does not wire it into a build.
##
## `s` IS PINNED AT 1.0 AND THE COUNT IS THEREFORE A LOWER BOUND. `s` is
## §19.8.7's `detail_scale`, a controller output driven by measured frames, and
## a controller at rest is 1.0. It does not enter `k(place)` at all, so item
## (ii) is independent of it. It does enter `d_f = s * k * height_f`, and a
## controller that has cut detail pushes MORE pairs under the placement floor --
## so item (iii)'s count is the floor of the population, not an estimate of it.
##
## THE CAMERA IS DECLARED, NOT DISCOVERED. `k_res` is a property of the viewport
## and the field of view, so a headless run has to state one rather than read a
## window. This uses the size every shot in `shots/` is taken at, which is the
## camera the rest of the measurements are against; the artefact records it so a
## reader can see the solve moves with the window.

const VIEWPORT_H := 800.0
const FOV := 75.0
const CEILING_FRACTION := 0.35
## Decision 1030's drop-to-tint bound: a family whose solved `d_f` falls under
## the placement sub-cell goes to decision 890's field layer rather than the
## budget breaking.
const PLACEMENT_FLOOR_M := 31.25

const OUT := "measurements/horizon_solve.json"


func _init() -> void:
    var fl := FixtureLoader.load_from("res://assets/fixture/")
    var fs := FamilySet.load_from("res://assets/families/")
    var fc := FrameCost.load_from()
    var man: Dictionary = JSON.parse_string(FileAccess.open(
            "res://assets/terrain/terrain_export.json", FileAccess.READ).get_as_text())
    var hf := Heightfield.load_from(man, "res://assets/terrain/heightfield_overview.png")
    if not fc.is_loaded():
        printerr("measure_horizon_solve: %s" % fc.why_absent)
        quit(1)
        return
    var sc := VegetationScatter.new()
    sc.bind(hf, null, fl, fs, fc, null)

    var k_res := VegetationScatter.resolution_k(VIEWPORT_H, FOV)
    var ceiling := CEILING_FRACTION * k_res
    var b_eff_ms := fc.budget_ms / VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS
    var b_eff_ns := b_eff_ms * 1.0e6

    var windows: Array = []
    for w in fl.windows:
        windows.append(_over_window(sc, fl, fs, fc, hf, str(w), ceiling, b_eff_ns))

    var doc := {
        "_what": ("§24 gap 170 items (ii) and (iii): decision 1030's solved instancing horizon "
                + "evaluated over the basin fixture. Headless -- the solve is arithmetic over "
                + "wire quantities and committed coefficients, so it needs no frame. Item (i) "
                + "is the frame-timing half and is not here."),
        "measured_at_commit": _commit(),
        "camera": {
            "viewport_height_px": VIEWPORT_H, "fov_degrees": FOV,
            "_declared_not_discovered": ("k_res is a property of the viewport and the field of "
                    + "view, so a headless run states a camera rather than reading a window. "
                    + "The solve moves with the window and this is the one the rest of "
                    + "`measurements/` is taken at."),
            "k_res": k_res,
            "ceiling": ceiling,
            "_ceiling_is": "decision 949's constant as decision 1030's ceiling, 0.35 * k_res",
        },
        "budget": {
            "line_item_ms": fc.budget_ms,
            "empty_stage_multiplier": VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS,
            "b_eff_ms": b_eff_ms,
            "_line_item_is": ("§19.8.5's vegetation line item, currently the whole frame budget "
                    + "as a named placeholder, divided by decision 951's measured multiplier at "
                    + "the point of use"),
        },
        "detail_scale": {
            "s": 1.0,
            "_why": ("§19.8.7's `detail_scale` with the controller at rest. It does not enter "
                    + "k(place), so item (ii) is independent of it; it does enter d_f, and a "
                    + "controller that has cut detail pushes MORE pairs under the floor -- so "
                    + "item (iii)'s count is a LOWER BOUND on the population, not an estimate."),
        },
        # A MEASUREMENT CARRYING METRES CARRIES THE FACTOR THOSE METRES WERE
        # TAKEN AT. 1.0 here is not a copy of what the other artefacts say: the
        # solve consumes `height_f` from `implication`, which is the family's
        # REAL height in metres, and `d_f` is a horizontal distance, so drawn
        # and real coincide only while the view draws at 1x.
        #
        # WHICH MEANS THE DATA VIEW WOULD NEED THE HEIGHTS SCALED BEFORE THE
        # SOLVE, NOT AFTER IT. At 12x a plant is drawn twelve times taller and
        # subtends twelve times the angle, so its individuation horizon is
        # twelve times further -- and `k_res` is a pinhole property that does
        # not move. Feeding real heights to the solve and exaggerating the
        # result afterwards would put the ceiling in the wrong place, because
        # the min() is taken before the scaling.
        "vertical_exaggeration": 1.0,
        "_vertical_exaggeration_is": ("the naturalistic view, where drawn height equals wire "
                + "height. The solve is over wire quantities; at a view that exaggerates, the "
                + "heights entering the denominator and `d_f` are the DRAWN ones and this run "
                + "does not answer for it."),
        "placement_floor_m": PLACEMENT_FLOOR_M,
        "windows": windows,
        "not_covered": ("item (i), the frame p50 against the vegetation line item at §23.909's "
                + "five cells, which needs a window. And the solve is evaluated, not applied: "
                + "decision 1030 says the client changes nothing now."),
    }
    var f := FileAccess.open("res://../" + OUT, FileAccess.WRITE)
    if f == null:
        f = FileAccess.open(OUT, FileAccess.WRITE)
    f.store_string(JSON.stringify(doc, "  ") + "\n")
    f.close()
    for wd in windows:
        var d: Dictionary = wd
        print("%s day %d: k over %d cells -- min %s median %s, %d at the ceiling (%s%%)"
                % [str(d["window"]), int(d["day"]), int(d["cells"]),
                   String.num(float(d["k_min"]), 2), String.num(float(d["k_median"]), 2),
                   int(d["cells_at_ceiling"]),
                   String.num(100.0 * float(d["cells_at_ceiling"]) / maxf(float(d["cells"]), 1.0), 1)])
        print("    under the %s m placement floor: %d of %d (cell, family) pairs (%s%%)"
                % [String.num(PLACEMENT_FLOOR_M, 2), int(d["pairs_under_floor"]),
                   int(d["pairs"]),
                   String.num(100.0 * float(d["pairs_under_floor"]) / maxf(float(d["pairs"]), 1.0), 2)])
    print("-> %s" % OUT)
    quit()


func _over_window(sc: VegetationScatter, fl: FixtureLoader, fs: FamilySet, fc: FrameCost,
                  hf: Heightfield, w: String, ceiling: float, b_eff_ns: float) -> Dictionary:
    var day := 22
    var groups := fl.taxon_groups(w, "band.pft_fractions")
    var bare := fl.day_values(w, "band.bare_fraction", day)
    var biomass_hi := sc.row_hi(w, "band.pft.biomass")
    var texel_area: float = hf.pixel_size_m * hf.pixel_size_m
    var fr: Array = []
    var bm: Array = []
    for g in groups.size():
        fr.append(fl.day_values(w, "band.pft_fractions", day, g))
        bm.append(fl.day_values(w, "band.pft.biomass", day, g))

    # `c_f` is a FLOOR coefficient at the family's triangle count, and a family
    # outside the measured span has none -- reported rather than extrapolated,
    # because the cost model is a line through complexities that were measured
    # and does not carry past them.
    var c_ns := {}
    var no_coefficient := PackedStringArray()
    for g in groups:
        var p := fc.per_instance_ns(fs.triangles_of(str(g)))
        if bool(p["ok"]):
            c_ns[str(g)] = float(p["ns"])
        else:
            no_coefficient.append("%s: %s" % [str(g), str(p["why"])])

    var ks := PackedFloat64Array()
    var at_ceiling := 0
    var pairs := 0
    var under := 0
    var under_by_family := {}
    for cell in bare.size():
        var denom := 0.0
        var heights := {}
        for gi in groups.size():
            var g := str(groups[gi])
            if not c_ns.has(g):
                continue
            var vf: PackedFloat64Array = fr[gi]
            var vb: PackedFloat64Array = bm[gi]
            if cell >= vf.size() or cell >= vb.size():
                continue
            var imp := sc.implication(g, vf[cell], bare[cell], vb[cell], biomass_hi, texel_area)
            if not bool(imp["ok"]):
                continue
            var crown := float(imp["crown_m"])
            var crown_area: float = PI * (0.5 * crown) * (0.5 * crown)
            if crown_area <= 0.0:
                continue
            var h := float(imp["height_m"])
            heights[g] = h
            denom += float(imp["cover"]) * h * h * c_ns[g] / crown_area
        if denom <= 0.0:
            continue
        var solved := sqrt(b_eff_ns / (PI * denom))
        var k: float = minf(ceiling, solved)
        ks.append(k)
        if solved >= ceiling:
            at_ceiling += 1
        for g in heights:
            pairs += 1
            if 1.0 * k * float(heights[g]) < PLACEMENT_FLOOR_M:
                under += 1
                under_by_family[g] = int(under_by_family.get(g, 0)) + 1
    var sorted := Array(ks)
    sorted.sort()
    var n := sorted.size()
    var q := func(f: float) -> float:
        return 0.0 if n == 0 else float(sorted[clampi(int(f * float(n)), 0, n - 1)])
    return {
        "window": w, "day": day,
        "cells": n,
        "k_min": q.call(0.0), "k_p25": q.call(0.25), "k_median": q.call(0.5),
        "k_p75": q.call(0.75), "k_max": q.call(0.999999),
        "cells_at_ceiling": at_ceiling,
        "pairs": pairs,
        "pairs_under_floor": under,
        "pairs_under_floor_by_family": under_by_family,
        "families_without_a_cost_coefficient": no_coefficient,
    }


func _commit() -> String:
    var out: Array = []
    OS.execute("git", ["rev-parse", "--short", "HEAD"], out, true)
    return "" if out.is_empty() else str(out[0]).strip_edges()
