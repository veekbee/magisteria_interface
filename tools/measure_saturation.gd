extends SceneTree

## HOW FAR CAN A VIEWER ACTUALLY SEE INTO A STAND, AGAINST HOW FAR WE DRAW IT.
##
## The individuation horizon is `d = k x height`, so a TALL family is drawn
## FURTHER. Its reason is resolution: a 40 m tree stays one distinguishable
## object much further away than a 0.3 m tuft, and past that range a tint is the
## honest picture. That reason is sound and this tool does not dispute it.
##
## IT IS NOT THE ONLY CONSTRAINT, AND THE OTHER ONE IS NOT MODELLED ANYWHERE.
## In a dense stand the view CLOSES: plants occlude each other, and beyond some
## range nothing further contributes a pixel whether or not it would have been
## resolvable. Occlusion falls as cover RISES and as crowns widen, which is the
## opposite direction from `k x height`. So the two constraints disagree about
## which places are cheap, and only one of them is implemented.
##
## WHAT THIS PUBLISHES, AND IT RULES ON NOTHING. Per cell: the range at which
## the stand closes, beside the range at which we currently stop drawing it, and
## their ratio. Where the ratio is large we are drawing individuals into a wall
## of nearer ones. Whether that is WRONG is a ruling -- decision 949's `k` is
## the owner's, its revisit trigger has already fired (§23.913), and §25 backlog
## 198 is the open row. **This tool exists so that conversation has a number
## instead of an intuition.**
##
## THE MODEL, STATED SO IT CAN BE ARGUED WITH RATHER THAN TRUSTED.
## Plants are independent and Poisson-placed, so transmittance along a ray falls
## as `exp(-d / lambda)` with `lambda = 1 / sum(n_f * w_f)` over occluding
## families -- `n_f` instances per square metre, `w_f` the silhouette width,
## taken as the crown width. Saturation distance is `lambda * ln(1/T)` at a
## stated transmittance `T`.
##
## FIVE WAYS THIS IS WRONG, ALL IN THE SAME DIRECTION UNLESS NOTED:
##   * REAL STANDS CLUMP. Poisson placement spreads plants more evenly than
##     nature does, so real sight-lines through gaps are LONGER: this
##     UNDERSTATES saturation distance.
##   * A CROWN IS NOT A SOLID BLOCK. Canopies are porous and this treats the
##     full crown width as opaque, which also UNDERSTATES the distance.
##   * ONLY FAMILIES DRAWN TALLER THAN EYE HEIGHT OCCLUDE a horizontal ray at
##     eye height. Shorter families are excluded entirely rather than graded,
##     which OVERSTATES the distance wherever a stand is knee-high and dense.
##   * THE GROUND IS TAKEN AS FLAT. Relief both hides and exposes; direction
##     unknown.
##   * THE FLIGHTS PITCH DOWN about 10 degrees, and a descending ray leaves the
##     canopy. This measures the horizontal case only.
## A figure whose error bars are unknown in SIGN is named as such rather than
## quoted as a bound.

const OUT := "measurements/saturation.json"
const FIXTURE_DIR := "res://assets/fixture/"
const FAMILY_DIR := "res://assets/families/"
const TERRAIN_DIR := "res://assets/terrain/"

const VIEWPORT_H := 800.0
const FOV := 75.0
## Decision 949's ruled constant, as a fraction of the resolvable range.
const RULED_K_FRACTION := 0.35
## The flights' eye height, so this is comparable with a recorded walk.
const EYE_HEIGHT_M := 1.7
## The transmittance at which the stand is called closed. 0.05 is a choice and
## is reported in the artefact so a reader can re-derive at another value --
## `lambda` is published per cell for exactly that reason.
const TRANSMITTANCE := 0.05


func _init() -> void:
    var fl := FixtureLoader.load_from(FIXTURE_DIR)
    var fs := FamilySet.load_from(FAMILY_DIR)
    var fc := FrameCost.load_from()
    var man: Dictionary = JSON.parse_string(FileAccess.open(
            TERRAIN_DIR + "terrain_export.json", FileAccess.READ).get_as_text())
    var hf := Heightfield.load_from(man, TERRAIN_DIR + "heightfield_overview.png")
    var enc := ScatterEncoding.load_from()
    if enc.why_absent != "":
        printerr("saturation: %s" % enc.why_absent)
        quit(1)
        return
    var sc := VegetationScatter.new()
    sc.bind(hf, null, fl, fs, fc, null)

    var k_res := VegetationScatter.resolution_k(VIEWPORT_H, FOV)
    var k := RULED_K_FRACTION * k_res
    var windows: Array = []
    for w in fl.windows:
        windows.append(_over_window(sc, fl, hf, str(w), k))

    var doc := {
        "_what": ("the range at which a stand closes the view, beside the range at which this "
                + "client stops drawing individuals into it, per cell"),
        "_rules_on_nothing": ("decision 949's `k` is the owner's and its revisit trigger has "
                + "already fired; this publishes a number for that conversation and takes no "
                + "position on it"),
        "_model_is": ("Poisson-placed independent plants, transmittance exp(-d/lambda), "
                + "lambda = 1/sum(n_f * w_f) over families drawn taller than eye height, "
                + "silhouette width taken as crown width"),
        "_known_wrong_in": ["clumping lengthens real sight-lines (understates)",
                "porous canopies (understates)",
                "sub-eye-height families excluded rather than graded (overstates)",
                "flat ground assumed (sign unknown)",
                "horizontal ray only; the flights pitch down ~10 degrees (sign unknown)"],
        "encoding": enc.name,
        # THE GUARD THAT DEMANDED THIS CAUGHT A REAL DEFECT, NOT A MISSING
        # FIELD. Vertical exaggeration scales plant HEIGHT and relief; it does
        # not scale horizontal distance. This model mixes the two -- crown width
        # is horizontal, the eye-height test is vertical -- so at any factor but
        # 1.0 the test would have to compare the DRAWN height against eye
        # height, and every range below would be a range in a stretched world
        # rather than in the field.
        "vertical_exaggeration": 1.0,
        "_vertical_exaggeration_is": ("naturalistic, so drawn height equals declared height and "
                + "the eye-height comparison below is exact. AT ANY OTHER FACTOR THIS TOOL IS "
                + "WRONG until the comparison is moved to the drawn height: the factor would "
                + "raise plants over the ray without moving the crowns that occlude it"),
        "eye_height_m": EYE_HEIGHT_M,
        "transmittance": TRANSMITTANCE,
        "k_fraction_of_resolvable": RULED_K_FRACTION,
        "viewport_height_px": VIEWPORT_H,
        "fov_degrees": FOV,
        "windows": windows,
    }
    var f := FileAccess.open("res://" + OUT, FileAccess.WRITE)
    f.store_string(JSON.stringify(doc, "  ") + "\n")
    f.close()
    print("saturation -> %s" % OUT)
    quit(0)


func _over_window(sc: VegetationScatter, fl: FixtureLoader, hf: Heightfield,
                  window: String, k: float) -> Dictionary:
    ## Day 22, matching the flights and the audit set, so a number here is
    ## comparable with a recorded walk rather than with a different season.
    var day := 22
    var groups := fl.taxon_groups(window, "band.pft_fractions")
    var bare: PackedFloat64Array = fl.day_values(window, "band.bare_fraction", day)
    var biomass_hi := sc.row_hi(window, "band.pft.biomass")
    var texel_area: float = hf.pixel_size_m * hf.pixel_size_m
    var fr: Array = []
    var bm: Array = []
    for g in groups.size():
        fr.append(fl.day_values(window, "band.pft_fractions", day, g))
        bm.append(fl.day_values(window, "band.pft.biomass", day, g))

    var ratios := PackedFloat64Array()
    var sats := PackedFloat64Array()
    var drawn_past := 0
    var counted := 0
    var no_occluder := 0
    for cell in bare.size():
        var extinction := 0.0        ## sum of n_f * w_f, per metre
        var horizon := 0.0           ## the furthest any family is individuated here
        var any := false
        for gi in groups.size():
            var g := str(groups[gi])
            var vf: PackedFloat64Array = fr[gi]
            var vb: PackedFloat64Array = bm[gi]
            if cell >= vf.size() or cell >= vb.size():
                continue
            var imp := sc.implication(g, vf[cell], bare[cell], vb[cell], biomass_hi, texel_area)
            if not bool(imp["ok"]):
                continue
            any = true
            var crown := float(imp["crown_m"])
            var height := float(imp["height_m"])
            var cover := float(imp["cover"])
            horizon = maxf(horizon, VegetationScatter.individuation_horizon_m(height, k))
            # ONLY WHAT REACHES THE RAY OCCLUDES IT.
            if height < EYE_HEIGHT_M or crown <= 0.0 or cover <= 0.0:
                continue
            var n_per_m2: float = cover / (PI * (0.5 * crown) * (0.5 * crown))
            extinction += n_per_m2 * crown
        if not any:
            continue
        counted += 1
        if extinction <= 0.0:
            # NOTHING HERE REACHES EYE HEIGHT: the stand never closes, and that
            # is reported rather than recorded as an infinite distance.
            no_occluder += 1
            continue
        var lambda_m := 1.0 / extinction
        var d_sat := lambda_m * log(1.0 / TRANSMITTANCE)
        sats.append(d_sat)
        if horizon > 0.0:
            ratios.append(horizon / d_sat)
            if horizon > d_sat:
                drawn_past += 1
    return {
        "window": window,
        "cells_with_vegetation": counted,
        "cells_with_nothing_at_eye_height": no_occluder,
        "_no_occluder_means": ("every family drawn here is shorter than eye height, so a "
                + "horizontal ray never closes; these are the places the current rule is "
                + "already right about"),
        "cells_drawn_past_saturation": drawn_past,
        "saturation_m": _stats(sats),
        "horizon_over_saturation": _stats(ratios),
    }


func _stats(v: PackedFloat64Array) -> Dictionary:
    if v.is_empty():
        return {"n": 0}
    var s := v.duplicate()
    s.sort()
    return {"n": s.size(), "min": s[0], "p50": s[int(s.size() * 0.5)],
            "p95": s[int(s.size() * 0.95)], "max": s[s.size() - 1]}
