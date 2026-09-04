class_name VegetationTint
extends RefCounted

## The far field's vegetation, as a per-cell colour and coverage rather than as
## instances. Seam candidate #1.
##
## WHY THIS IS DATA AND NOT AN APPROXIMATION. Every plant within a cell is the
## same plant: height, crown and phenology all come from `vals[cell]`, and only
## position varies, from a seeded RNG. A cell is about 126 km2. So per-cell mean
## colour x coverage is the SAME wire information the scatter individualises,
## and nothing below cell scale is being invented here that the scatter does not
## also invent. What the scatter adds at range is a hundred thousand copies of
## one plant at coordinates a random number generator chose.
##
## IT IS BUILT FROM THE SCATTER'S OWN INPUTS, deliberately and by reference
## rather than by reimplementation. Cover fraction per family comes from
## `band.pft_fractions` and phenology from the scatter's own cell-relative
## season range -- the same call, not a second copy of the rule. A tint computed
## from a parallel derivation would drift from the instances it has to meet.
##
## THE TWO OUTPUTS ARE THE CONSERVED QUANTITIES. RGB is mean vegetation colour
## and A is coverage fraction, per cell, which is what any future crossfade has
## to hold to a curve (`measurements/README.md`, the seam section). They are
## kept as two channels rather than premultiplied for exactly that reason: a
## premultiplied colour cannot be checked against a coverage target.
##
## RANGE DARKENING IS NOT HERE. Apparent stand colour falls with range and a
## per-cell texture is view-independent, so the range term belongs at the
## fragment, where the distance is known. This carries the near colour; the
## terrain shader attenuates it.

var _rl: ResidenceLayer = null
var _fl: FixtureLoader = null
var _fs: FamilySet = null
var _scatter: VegetationScatter = null
var report: Dictionary = {}


func bind(rl: ResidenceLayer, fl: FixtureLoader, fs: FamilySet,
          scatter: VegetationScatter) -> void:
    _rl = rl
    _fl = fl
    _fs = fs
    _scatter = scatter


func is_bound() -> bool:
    return _rl != null and _fl != null and _fs != null and _scatter != null


## Mean colour and coverage for every cell, one day of one window.
##
## Coverage is the sum of the families' GROUND covers -- each family's share of
## the composition scaled by how much of the cell is vegetated at all. It sums
## to `1 - bare_fraction` by construction, which is 0.525 on the basin mean, so
## roughly half of this basin's ground shows through the stand.
func cell_colours(window: String, day: int) -> PackedColorArray:
    report = {"ok": false}
    var out := PackedColorArray()
    if not is_bound():
        report["why"] = "the tint is not bound to its artefacts"
        return out
    var groups := _fl.taxon_groups(window, "band.pft_fractions")
    if groups.is_empty():
        report["why"] = "the fixture names no taxon_groups for band.pft_fractions"
        return out
    var n := _fl.n_cells
    out.resize(n)

    var bare := _fl.day_values(window, "band.bare_fraction", day)
    if bare.is_empty():
        report["why"] = ("no band.bare_fraction for %s day %d, and without it pft_fractions "
                + "is a composition with nothing to scale it") % [window, day]
        return out
    var fractions: Array = []
    var biomass: Array = []
    var seasons: Array = []
    var foliage := PackedFloat32Array()
    var known := PackedInt32Array()
    for gi in groups.size():
        var g: String = groups[gi]
        fractions.append(_fl.day_values(window, "band.pft_fractions", day, gi))
        biomass.append(_fl.day_values(window, "band.pft.biomass", day, gi))
        seasons.append(_scatter.season_range(window, "band.pft.biomass", gi))
        foliage.append(_fs.foliage_fraction(g) if _fs.has(g) else NAN)
        known.append(1 if _fs.has(g) else 0)

    var covered_cells := 0
    var total_cover := 0.0
    var per_family: Dictionary = {}
    for gi in groups.size():
        per_family[groups[gi]] = 0.0
    for cell in n:
        var cover := 0.0
        var r := 0.0
        var gc := 0.0
        var b := 0.0
        for gi in groups.size():
            if known[gi] == 0:
                continue
            var vf: PackedFloat64Array = fractions[gi]
            var vb: PackedFloat64Array = biomass[gi]
            if cell >= vf.size() or cell >= vb.size():
                continue
            # `VegetationScatter.ground_cover`, not a second copy of the rule:
            # the tint has to cover what the instances cover or the seam is a
            # density step whatever else is right.
            var f := VegetationScatter.ground_cover(vf[cell],
                    NAN if cell >= bare.size() else bare[cell])
            if is_nan(f) or f <= 0.0:
                continue
            var phen := _scatter.phenology_for(seasons[gi], cell,
                    0.0 if cell >= vb.size() or is_nan(vb[cell]) else vb[cell])
            var c := VegetationPalette.colour_for(foliage[gi], phen)
            # WEIGHTED BY COVER, because that is what a viewer sees: the mean
            # colour of the ground that is plant, not the mean of the families
            # present. A family covering a hundredth of the cell must not pull
            # the colour as hard as one covering half of it.
            cover += f
            r += c.r * f
            gc += c.g * f
            b += c.b * f
            per_family[groups[gi]] = float(per_family[groups[gi]]) + f
        if cover <= 0.0:
            out[cell] = Color(0, 0, 0, 0)
            continue
        covered_cells += 1
        total_cover += cover
        out[cell] = Color(r / cover, gc / cover, b / cover, minf(cover, 1.0))
    var shares: Dictionary = {}
    for g in per_family:
        shares[g] = float(per_family[g]) / float(maxi(covered_cells, 1))
    report = {
        "ok": true,
        "window": window,
        "day": day,
        "cells": n,
        "cells_with_cover": covered_cells,
        "mean_cover_where_covered": total_cover / float(maxi(covered_cells, 1)),
        "mean_cover_per_family": shares,
        "foliage_fraction": _foliage_report(groups, foliage),
        "what": ("mean vegetation colour weighted by cover, and coverage as the sum of the "
                + "families' cover fractions -- the two conserved quantities any seam has to "
                + "hold"),
    }
    return out


func _foliage_report(groups: PackedStringArray, foliage: PackedFloat32Array) -> Dictionary:
    var out: Dictionary = {}
    for gi in groups.size():
        if not is_nan(foliage[gi]):
            out[groups[gi]] = foliage[gi]
    return out
