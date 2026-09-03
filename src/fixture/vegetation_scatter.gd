class_name VegetationScatter
extends RefCounted

## M5's first visible result: the carried vegetation rows, scattered as form
## archetypes over the terrain at life form.
##
## THE CHAIN, AND EVERY LINK IS SOMEBODY ELSE'S. A texel has a residence key
## (decision 891, received not computed); the key joins to a cell; the cell
## indexes one day of `band.pft_fractions` and `band.pft.biomass`; the group
## axis is named by the fixture's `taxon_groups` and keys a family. Nothing
## here decides what grows where.
##
## TWO AXES FROM TWO ROWS, WHICH IS WHY THERE ARE TWO ROWS. §17.8.2 wants
## height and crown as separate axes for woody forms, deriving from different
## field quantities, and the wire carries exactly two per group:
##
##   * `crown_m`  <- the COVER FRACTION. Cover is crown area times count, so
##                   the fraction is the quantity that speaks about width.
##   * `height_m` <- the BIOMASS PER COVERED AREA (biomass / fraction). Mass
##                   packed into a given crown footprint is the quantity that
##                   speaks about height.
##
## Both are normalised into the family's declared legal range, so a value can
## never leave it by construction -- and `FamilySet` still checks, because a
## parameter that escapes is a bug upstream and clamping it would hide the bug
## behind a plausible plant.
##
## COUNT IS NOT A FREE PARAMETER. Instances per texel are
## `fraction * texel_area / crown_area`, which is cover divided by the area one
## individual covers. That number is what the wire implies and it is very often
## far more than a frame can draw -- grass alone runs to millions per square
## kilometre. The scatter does NOT quietly thin it. It draws one stated share
## across every family, so the mix between families is preserved, and reports
## the share, the implied count and the predicted cost. A picture with a share
## of 1e-4 is a sample of a stand and says so; a picture that silently drew the
## thousand instances that happened to fit would be a different stand.
##
## NOTHING WRITTEN INTO A MultiMesh CAN BE READ BACK HEADLESS. Under the dummy
## renderer the per-instance store does not exist: `get_instance_transform`
## returns the identity, `get_instance_custom_data` returns zeros, and `buffer`
## is empty, whatever was written. `instance_count` and the format flags are
## properties of the resource and do survive.
##
## So THIS REPORT is the checkable statement about what the scatter placed --
## every figure in it is computed in GDScript from the same values that go into
## the instances. A test that read the instances back would be testing the stub,
## and would pass by comparing zero against zero.
##
## THE VERTICAL EXAGGERATION APPLIES TO THE PLANTS TOO. M1 draws this basin at
## 12x relief. Vegetation at true scale on 12x terrain reads as twelve times
## too short, so the same factor scales plant height and the report carries it.
## No height should be read off the picture either way.

## Placement is seeded, so two runs over one day differ by the data and not by
## the draw. The seed travels in the report.
const SCATTER_SEED := 20260903

## A ceiling on instances BUILT, which is not the frame budget and must not be
## confused with it. `measurements/render_cost.json` prices a frame; this
## bounds the seconds GDScript spends filling a MultiMesh before that frame
## exists. Whichever binds is named in the report, so a share of 0.02 is never
## ambiguous between "the GPU cannot draw this" and "the scatter declined to
## spend a minute building it".
const MAX_BUILT_INSTANCES := 120000

## Days sampled to find a cell's own yearly trough and peak for phenology.
##
## Ten of the window's ninety, because the alternative is reading every day of
## every group for a number that moves slowly. The sampling is stated in the
## report: a trough between two samples is missed, which widens no cell's range
## and narrows some, so a sampled phenology is conservative rather than wrong
## in an unknown direction.
const PHENOLOGY_SAMPLE_STRIDE := 9

var meshes: Dictionary = {}          ## life_form -> MultiMesh
var report: Dictionary = {}

var _hf: Heightfield = null
var _rl: ResidenceLayer = null
var _fl: FixtureLoader = null
var _fs: FamilySet = null
var _fc: FrameCost = null
var _tm: TerrainMesh = null
var _season: Dictionary = {}         ## "window|group" -> {"lo": .., "hi": ..} per cell


func bind(hf: Heightfield, rl: ResidenceLayer, fl: FixtureLoader,
          fs: FamilySet, fc: FrameCost, tm: TerrainMesh) -> void:
    _hf = hf
    _rl = rl
    _fl = fl
    _fs = fs
    _fc = fc
    _tm = tm


func is_bound() -> bool:
    return _hf != null and _rl != null and _fl != null and _fs != null and _tm != null


## Scatter one day of one window within `radius_m` of a world position.
##
## A radius rather than the basin: a cell here is about 126 km2 and the whole
## basin is 5,684 of them, so "scatter the fixture" is not a thing any frame
## can contain. The horizon is the caller's and the cost of it is reported.
func build(window: String, day: int, centre: Vector2, radius_m: float) -> Dictionary:
    meshes = {}
    if not is_bound():
        report = {"ok": false, "why": "the scatter is not bound to its artefacts"}
        return report

    var groups := _fl.taxon_groups(window, "band.pft_fractions")
    if groups.is_empty():
        report = {"ok": false, "why": "the fixture names no taxon_groups for band.pft_fractions"}
        return report
    var biomass_groups := _fl.taxon_groups(window, "band.pft.biomass")
    if Array(groups) != Array(biomass_groups):
        # Two rows on one group axis. If they ever disagreed, every plant would
        # take its width from one life form and its height from another.
        report = {"ok": false, "why": ("the two vegetation rows name different group axes: "
                + "%s against %s") % [str(groups), str(biomass_groups)]}
        return report
    var missing := _fs.missing_for(groups)

    var fractions: Array = []
    var biomass: Array = []
    for g in groups.size():
        fractions.append(_fl.day_values(window, "band.pft_fractions", day, g))
        biomass.append(_fl.day_values(window, "band.pft.biomass", day, g))
    var biomass_hi := _row_hi(window, "band.pft.biomass")
    var seasons: Array = []
    for g in groups.size():
        seasons.append(_season_range(window, "band.pft.biomass", g))

    # PASS ONE: what the wire implies, before any question of what fits.
    var texel_area := _hf.pixel_size_m * _hf.pixel_size_m
    var wanted: Array = []             ## {texel, group, count, height_m, crown_m}
    var implied: Dictionary = {}
    for g in groups:
        implied[g] = 0.0
    var texels := 0
    var flat_cells := 0
    var phen_lo := 1.0
    var phen_hi := 0.0
    var centre_texel := _hf.world_to_texel(centre.x, centre.y)
    var reach := int(ceil(radius_m / _hf.pixel_size_m))
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            var tx := int(round(centre_texel.x)) + dx
            var ty := int(round(centre_texel.y)) + dy
            var w := _hf.texel_to_world(float(tx), float(ty))
            if Vector2(w.x - centre.x, w.y - centre.y).length() > radius_m:
                continue
            if is_nan(_hf.height_at_texel(tx, ty)):
                continue
            var key := _rl.key_at(tx, ty)
            if key.is_empty():
                continue
            var huc: String = _rl.node_of_index.get(int(key[0]), "")
            if huc == "":
                continue
            var ci: Variant = _fl.cell_of_key.get("%s|%d" % [huc, int(key[1])], null)
            if ci == null:
                continue
            texels += 1
            var cell := int(ci)
            for gi in groups.size():
                var life_form := groups[gi]
                if not _fs.has(life_form):
                    continue
                var vals_f: PackedFloat64Array = fractions[gi]
                var vals_b: PackedFloat64Array = biomass[gi]
                if cell >= vals_f.size() or cell >= vals_b.size():
                    continue
                var frac := vals_f[cell]
                var bio := vals_b[cell]
                if is_nan(frac) or is_nan(bio) or frac <= 0.0:
                    continue
                var params := parameters_for(life_form, frac, bio, biomass_hi)
                if not bool(params["ok"]):
                    continue
                var crown := float(params["crown_m"])
                var crown_area: float = PI * (0.5 * crown) * (0.5 * crown)
                if crown_area <= 0.0:
                    continue
                var count := frac * texel_area / crown_area
                implied[life_form] = float(implied[life_form]) + count
                var phen := phenology_for(seasons[gi], cell, bio)
                var why_phen := _fs.check(life_form, "phenology", phen)
                if why_phen != "":
                    # The tint is a declared parameter with a declared range,
                    # so it is refused on the same terms as height and crown.
                    continue
                if float(seasons[gi]["hi"][cell]) - float(seasons[gi]["lo"][cell]) <= 0.0:
                    flat_cells += 1
                wanted.append({"texel": Vector2i(tx, ty), "life_form": life_form,
                               "count": count, "height_m": float(params["height_m"]),
                               "crown_m": crown, "phenology": phen})

    # What one frame can hold, from the measurement rather than from a guess.
    var total_implied := 0.0
    for g in implied:
        total_implied += float(implied[g])
    var afford := _affordable(groups, implied)
    var ceiling := float(afford.get("instances", 0.0)) if bool(afford.get("ok", false)) else 0.0
    var bound_by := "the frame budget"
    if not bool(afford.get("ok", false)):
        ceiling = float(MAX_BUILT_INSTANCES)
        bound_by = "the build ceiling, with no frame-cost measurement to price against"
    elif ceiling > float(MAX_BUILT_INSTANCES):
        ceiling = float(MAX_BUILT_INSTANCES)
        bound_by = "the build ceiling, which is lower here than the frame budget"
    var share: float = 1.0
    if total_implied > ceiling and total_implied > 0.0:
        share = ceiling / total_implied
    else:
        bound_by = "nothing: the whole implied scatter is drawn"

    # PASS TWO: place the share, preserving the mix between families.
    var rng := RandomNumberGenerator.new()
    rng.seed = SCATTER_SEED
    var placed: Dictionary = {}
    var refused := 0
    var by_family: Dictionary = {}
    var phen_of: Dictionary = {}
    for g in groups:
        placed[g] = 0
        by_family[g] = []
        phen_of[g] = PackedFloat32Array()
    for item in wanted:
        var n := int(round(float(item["count"]) * share))
        if n <= 0:
            continue
        var life_form: String = item["life_form"]
        var t: Vector2i = item["texel"]
        var origin := _hf.texel_to_world(float(t.x), float(t.y))
        var half := 0.5 * _hf.pixel_size_m
        for i in n:
            var wx := origin.x + rng.randf_range(-half, half)
            var wy := origin.y + rng.randf_range(-half, half)
            var h := _hf.height_at_world(wx, wy)
            if is_nan(h):
                continue            # the one-texel nodata border; dropped, not clamped
            var m := _tm.world_to_mesh(Vector2(wx, wy), _hf)
            var pos := Vector3(m.x, h * _tm.exaggeration, m.y)
            var xf := _fs.instance_transform(life_form, pos, float(item["height_m"]),
                    float(item["crown_m"]), _tm.exaggeration)
            if not bool(xf["ok"]):
                refused += 1
                continue
            (by_family[life_form] as Array).append(xf["transform"])
            var pf: PackedFloat32Array = phen_of[life_form]
            pf.append(float(item["phenology"]))
            phen_of[life_form] = pf
            phen_lo = minf(phen_lo, float(item["phenology"]))
            phen_hi = maxf(phen_hi, float(item["phenology"]))
            placed[life_form] = int(placed[life_form]) + 1

    var triangles := 0
    for life_form in by_family:
        var transforms: Array = by_family[life_form]
        if transforms.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        # CUSTOM DATA, NOT INSTANCE COLOUR. The engine multiplies an instance
        # colour into the mesh's vertex colour, and the mesh's vertex colour is
        # the authored phenology MASK -- the product is zero both for a trunk in
        # summer and for foliage in midwinter, which must not look alike.
        mm.use_custom_data = true
        mm.mesh = _fs.mesh_for(life_form)
        mm.instance_count = transforms.size()
        var pf: PackedFloat32Array = phen_of[life_form]
        for i in transforms.size():
            mm.set_instance_transform(i, transforms[i])
            mm.set_instance_custom_data(i, Color(pf[i], 0.0, 0.0, 1.0))
        meshes[life_form] = mm
        triangles += _fs.triangles_of(life_form) * transforms.size()

    report = {
        "ok": true,
        "window": window,
        "day": day,
        "centre_m": [centre.x, centre.y],
        "radius_m": radius_m,
        "texels": texels,
        "seed": SCATTER_SEED,
        "vertical_exaggeration": _tm.exaggeration,
        "groups": Array(groups),
        "families_missing": Array(missing),
        "implied": implied,
        "placed": placed,
        "share_drawn": share,
        "share_bound_by": bound_by,
        "build_ceiling": MAX_BUILT_INSTANCES,
        "refused_parameters": refused,
        "phenology": {
            "from": ("this cell's biomass today against its own trough and peak across the "
                    + "window, not against the row's range: the row's range says where a "
                    + "cell sits in the basin, not where it sits in its year"),
            "days_sampled": int(seasons[0]["days_sampled"]) if seasons.size() > 0 else 0,
            "range_drawn": [phen_lo, phen_hi] if phen_hi >= phen_lo else [],
            "cells_with_no_seasonal_signal": flat_cells,
        },
        "triangles_in_frame": triangles,
        "budget": afford,
        "what_share_means": ("one share across every family, so the mix between them is what "
                + "the wire says. A share below 1 is a sample of the stand, not a thinner "
                + "stand."),
    }
    return report


## Height and crown for one cell's worth of one life form, both inside the
## family's declared range by construction.
##
## `t` for each axis is a normalised position in a wire quantity, and the two
## quantities are different: cover fraction for width, biomass per covered area
## for height. Deriving both from one quantity would make the two axes one axis
## wearing two names.
func parameters_for(life_form: String, fraction: float, biomass: float,
                    biomass_hi: float) -> Dictionary:
    var h_range := _fs.range_of(life_form, "height_m")
    var c_range := _fs.range_of(life_form, "crown_m")
    if h_range.is_empty() or c_range.is_empty():
        return {"ok": false, "why": "%s declares no height or crown range" % life_form}
    if fraction <= 0.0:
        return {"ok": false, "why": "no cover"}
    var per_covered := biomass / fraction
    var t_h: float = 0.0 if biomass_hi <= 0.0 else clampf(per_covered / biomass_hi, 0.0, 1.0)
    var t_c: float = clampf(fraction, 0.0, 1.0)
    return {
        "ok": true,
        "height_m": lerpf(float(h_range["min"]), float(h_range["max"]), t_h),
        "crown_m": lerpf(float(c_range["min"]), float(c_range["max"]), t_c),
        "t_height": t_h,
        "t_crown": t_c,
    }


## How many instances a frame can hold, at the mix these families imply.
##
## Priced through `measurements/render_cost.json` rather than assumed. Without
## the measurement there is no budget and the scatter says so instead of
## inventing one -- which is §19.8.9's whole point, one milestone along.
func _affordable(groups: PackedStringArray, implied: Dictionary) -> Dictionary:
    if _fc == null or not _fc.is_loaded():
        return {"ok": false, "instances": 0.0,
                "why": ("no frame-cost measurement, so no budget. "
                        + ("" if _fc == null else _fc.why_absent))}
    var total := 0.0
    var weighted_ns := 0.0
    for g in groups:
        var n := float(implied.get(g, 0.0))
        if n <= 0.0 or not _fs.has(g):
            continue
        var per := _fc.per_instance_ns(_fs.triangles_of(g))
        if not bool(per["ok"]):
            return {"ok": false, "instances": 0.0, "why": str(per["why"])}
        total += n
        weighted_ns += n * float(per["ns"])
    if total <= 0.0:
        return {"ok": true, "instances": 0.0, "why": "nothing implied"}
    var mean_ns := weighted_ns / total
    var affordable := _fc.budget_ms * 1.0e6 / mean_ns
    return {
        "ok": true,
        "instances": affordable,
        "budget_ms": _fc.budget_ms,
        "mean_ns_per_instance": mean_ns,
        "implied_total": total,
        "implied_ms": weighted_ns / 1.0e6,
        "measured_on": str(_fc.host.get("gpu", "?")) + " / "
                + str(_fc.host.get("rendering_method", "?")),
    }


## A cell's own yearly trough and peak for one life form's biomass.
##
## PHENOLOGY IS RELATIVE TO THE CELL, NOT TO THE ROW. Normalised over the row's
## realised range instead, a cell that never carries much biomass would read as
## permanently wintering, and a productive one as permanently at peak -- which
## is a statement about where a cell sits in the basin, not about where it sits
## in its year. The seasonal signal is the cell against itself.
func _season_range(window: String, row: String, group: int) -> Dictionary:
    var key := "%s|%s|%d" % [window, row, group]
    if _season.has(key):
        return _season[key]
    var n_days := _fl.days(window, row)
    var lo := PackedFloat64Array()
    var hi := PackedFloat64Array()
    var day := 0
    while day < n_days:
        var vals := _fl.day_values(window, row, day, group)
        if lo.is_empty():
            lo = vals.duplicate()
            hi = vals.duplicate()
        else:
            for c in vals.size():
                var v := vals[c]
                if is_nan(v):
                    continue
                if is_nan(lo[c]) or v < lo[c]:
                    lo[c] = v
                if is_nan(hi[c]) or v > hi[c]:
                    hi[c] = v
        day += PHENOLOGY_SAMPLE_STRIDE
    var out := {"lo": lo, "hi": hi, "days_sampled": int(ceil(float(n_days) / float(PHENOLOGY_SAMPLE_STRIDE)))}
    _season[key] = out
    return out


## Where today sits between this cell's own trough and peak, in [0, 1].
##
## A cell whose biomass does not move across the window has trough == peak ==
## today, and the ratio's limit there is 1: the day's value IS the cell's
## maximum. That is the honest degenerate answer rather than a chosen midpoint,
## and the count of such cells travels in the report.
func phenology_for(season: Dictionary, cell: int, today: float) -> float:
    var lo: PackedFloat64Array = season["lo"]
    var hi: PackedFloat64Array = season["hi"]
    if cell >= lo.size() or cell >= hi.size() or is_nan(today):
        return 1.0
    var span := hi[cell] - lo[cell]
    if is_nan(span) or span <= 0.0:
        return 1.0
    return clampf((today - lo[cell]) / span, 0.0, 1.0)


func _row_hi(window: String, row: String) -> float:
    var rows: Dictionary = _fl.manifest.get("client_form", {}).get("rows", {})
    var d: Variant = rows.get("%s/%s" % [window, row], null)
    return 0.0 if d == null else float(d["hi"])
