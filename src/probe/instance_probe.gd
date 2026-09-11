class_name InstanceProbe
extends RefCounted

## One plant, named and explained: which sub-cell it belongs to, which
## candidate it is, where the hash puts it, and -- if it is not on screen --
## which of the reasons that is.
##
## THE HEADER STANCE IS `CellProbe`'S AND IS INHERITED DELIBERATELY. This is a
## development view of data the client already holds whole, exempted by that
## context and by nothing about the answer. It is not a percept, not a
## transducer, and not a template for anything a player sees. Against a live
## wire it is absent by construction: the truth it reads never arrives.
##
## SELECTION BY RE-DERIVATION, NEVER BY PICKING, and the reason is worth having
## in the file. Instance transforms cannot be read back under the headless
## renderer, so a probe that picked what it saw could not run in the gate at
## all. Re-deriving from the hash pays three times: it runs headless, it
## survives a rebuild -- the name of a plant is its ground and its rank, not an
## index into a MultiMesh that changes every time the camera moves -- and it
## makes a mismatch diagnostic. A re-derived position that disagrees with the
## drawn one CAN ONLY MEAN A BUILD DEFECT, because both come from the same
## functions.
##
## THAT IS THE WHOLE DISCIPLINE: `VegetationScatter.implication`,
## `placement_key`, `candidate_at`, `candidate_position`,
## `individuation_horizon_m` and `keep_at` are called here, not reimplemented.
## A second copy of the placement arithmetic would produce a probe that agrees
## with a defect.
##
## THE ABSENCE TAXONOMY, extending `CellProbe`'s three. None of these is an
## error; each is a different sentence:
##
##   NOT_IMPLIED     -- the wire puts no plant of this family on this ground.
##   THINNED         -- implied, and its rank sits above the drawn prefix. It
##                      still has a position and this prints it.
##   BEYOND_HORIZON  -- individuation stops closer than this, with the margin.
##   DRAWN           -- it is on screen.

const NOT_IMPLIED := "NOT_IMPLIED"
const THINNED := "THINNED"
const BEYOND_HORIZON := "BEYOND_HORIZON"
const DRAWN := "DRAWN"
## A fourth, and it is about the HARNESS rather than about the plant: this
## ground is outside the radius the last build covered, so nothing was decided
## here either way. Kept named rather than folded into one of the three above,
## which would report a build's extent as a property of the vegetation.
const NOT_BUILT := "NOT_BUILT"

## `probe.survive`'s own vocabulary. The last is a bug report by construction:
## placement is a function of ground, so a key that moved when the camera did
## is the defect §16.6 exists to remove.
const EXITS_THINNED := "EXITS: THINNED"
const EXITS_BEYOND_HORIZON := "EXITS: BEYOND_HORIZON"
const EXITS_KEY_MOVED := "EXITS: KEY MOVED"
const STAYS := "STAYS"

var _sc: VegetationScatter = null
var _hf: Heightfield = null
var _cp: CellProbe = null
var _fl: FixtureLoader = null
var _fs: FamilySet = null


func bind(sc: VegetationScatter, hf: Heightfield, fl: FixtureLoader, cp: CellProbe,
          fs: FamilySet = null) -> void:
    _sc = sc
    _hf = hf
    _fl = fl
    _cp = cp
    _fs = fs


func is_bound() -> bool:
    return _sc != null and _hf != null and _fl != null and _cp != null and _sc.report.get("ok", false)


## THE SUB-CELL A POINT STANDS IN, and everything the last build decided about
## it: what the wire implied there, how many candidates the pool holds, how
## many of them the share drew, and where each one is.
##
## Reads the LAST BUILD's parameters out of its report rather than being told
## them, so the probe answers about the picture on screen and not about a
## hypothetical one.
func sub_at(world: Vector2, life_form: String) -> Dictionary:
    if not is_bound():
        return {"ok": false, "why": "no build to probe: the scatter has not run here"}
    var r := _sc.report
    var window := str(r["window"])
    var day := int(r["day"])

    var cell := _cp.at_world(world.x, world.y)
    if str(cell.get("state", "")) != CellProbe.RESOLVED:
        return {"ok": false, "state": str(cell.get("state", "")), "why": str(cell.get("why", "")),
                "cell_probe": cell}

    var groups := _fl.taxon_groups(window, "band.pft_fractions")
    var gi := Array(groups).find(life_form)
    if gi < 0:
        return {"ok": false, "why": "%s is not one of the wire's life forms %s"
                % [life_form, str(groups)]}

    var ci := int(cell["cell"])
    var share := _fl.day_values(window, "band.pft_fractions", day, gi)
    var bio := _fl.day_values(window, "band.pft.biomass", day, gi)
    var bare := _fl.day_values(window, "band.bare_fraction", day)
    if ci >= share.size() or ci >= bio.size():
        return {"ok": false, "why": "cell %d is outside the rows this window carries" % ci}

    var texel_area := _hf.pixel_size_m * _hf.pixel_size_m
    var imp := _sc.implication(life_form, share[ci],
            NAN if ci >= bare.size() else bare[ci], bio[ci],
            _sc.row_hi(window, "band.pft.biomass"), texel_area)

    var t := _hf.world_to_texel(world.x, world.y)
    var centre := _hf.texel_to_world(round(t.x), round(t.y))
    var half := 0.5 * _hf.pixel_size_m
    var sub := VegetationScatter.sub_cell_of(centre, half, world)
    var origin := VegetationScatter.sub_cell_origin(centre, half, sub.x, sub.y)
    var sub_half := half / float(VegetationScatter.BAND_SUBDIVISION)

    var out := {
        "ok": true,
        "window": window,
        "day": day,
        "life_form": life_form,
        "cell_probe": cell,
        "texel": Vector2i(int(round(t.x)), int(round(t.y))),
        "sub_cell": sub,
        "origin_m": origin,
        "half_m": sub_half,
        # THE COMPOSITION ARITHMETIC, INLINE. `share x (1 - bare) = cover` is
        # printed rather than summarised because reading the share as a cover
        # is the mistake this format exists to make impossible to repeat.
        "share": share[ci],
        "bare_fraction": NAN if ci >= bare.size() else bare[ci],
        "cover": float(imp.get("cover", NAN)),
        "biomass": bio[ci],
    }
    if not bool(imp["ok"]):
        out["state"] = NOT_IMPLIED
        out["why"] = str(imp["why"])
        return out

    out["height_m"] = float(imp["height_m"])
    out["crown_m"] = float(imp["crown_m"])
    out["implied_per_texel"] = float(imp["count"])
    out["implied_per_sub_cell"] = float(imp["per_sub"])

    # The drawing decisions, in the order the build applies them.
    var build_centre: Array = r.get("centre_m", [0.0, 0.0])
    var from_centre := Vector2(origin.x - float(build_centre[0]),
            origin.y - float(build_centre[1])).length()
    var k := float(r.get("individuation_k", 0.0))
    var horizon_m := VegetationScatter.individuation_horizon_m(float(imp["height_m"]), k)
    var keep := VegetationScatter.keep_at(from_centre, r.get("bands", []))
    var share_drawn := float(r.get("share_drawn", 1.0))

    var key := VegetationScatter.placement_key(
            VegetationScatter.family_key(life_form), origin, sub_half)
    var u := VegetationScatter.hash01(VegetationScatter.stable_hash3(key, 0, 7))
    var pool := VegetationScatter.resolve_count(float(imp["per_sub"]), u)
    var n := VegetationScatter.resolve_count(float(imp["per_sub"]) * keep * share_drawn, u)
    if pool < n:
        pool = n

    out["distance_from_build_centre_m"] = from_centre
    out["individuation_k"] = k
    out["horizon_m"] = horizon_m
    out["beyond_horizon"] = k > 0.0 and from_centre > horizon_m
    out["horizon_margin_m"] = (horizon_m - from_centre) if k > 0.0 else INF
    out["density_keep"] = keep
    out["share_drawn"] = share_drawn
    out["placement_key"] = key
    out["pool"] = pool
    out["drawn"] = n
    out["in_build_radius"] = from_centre <= float(r.get("radius_m", 0.0))
    if not bool(out["in_build_radius"]):
        out["state"] = NOT_BUILT
        out["why"] = ("this ground is %s m from the last build's centre and the build reached "
                % String.num(from_centre, 0)
                + "%s m. Nothing was decided here either way."
                        % String.num(float(r.get("radius_m", 0.0)), 0))
        return out
    # WHICH NODE THIS GROUND'S PLANTS OF THIS FAMILY ARE DRAWN AT, from the
    # same overlay the build read. Re-derived rather than remembered: the probe
    # asks the scatter's own refinement map, so a probe-vs-drawn disagreement
    # here can only mean the build wrote something else.
    var cell_key := "%s|%d" % [str(cell.get("huc10", "")), int(cell.get("band", -1))]
    var node := str(_sc.refinements.get(
            PerceptBundle.refinement_key(cell_key, life_form), life_form))
    out["node"] = node
    out["rung"] = "" if _fs == null else _fs.rung_of(node)
    out["refined"] = node != life_form
    out["state"] = BEYOND_HORIZON if bool(out["beyond_horizon"]) else DRAWN
    return out


## THE CANDIDATES OF ONE SUB-CELL, in the order the build draws them.
##
## `limit` caps how many are listed: a grass sub-cell's pool runs to millions
## and the first hundred are the ones the share is deciding between.
func candidates_in(sub: Dictionary, limit: int = 64) -> Array:
    var out: Array = []
    if not bool(sub.get("ok", false)) or not sub.has("pool"):
        return out
    var key := int(sub["placement_key"])
    var pool := int(sub["pool"])
    var n := int(sub["drawn"])
    var origin: Vector2 = sub["origin_m"]
    var half := float(sub["half_m"])
    for i in mini(limit, pool):
        var c := VegetationScatter.candidate_at(i, pool, key)
        if c < 0:
            continue
        out.append({
            "rank": i,
            "candidate": c,
            "position_m": VegetationScatter.candidate_position(key, c, origin, half),
            "state": DRAWN if i < n else THINNED,
        })
    return out


## THE PLANT NEAREST A POINT, re-derived. Its name is `(placement key, rank)`,
## which is ground and order rather than an index into anything the camera
## built -- so the same plant is the same plant after a rebuild.
func nearest(world: Vector2, life_form: String, search: int = 256) -> Dictionary:
    var sub := sub_at(world, life_form)
    if not bool(sub.get("ok", false)):
        return sub
    if str(sub["state"]) == NOT_IMPLIED or str(sub["state"]) == NOT_BUILT:
        return sub
    var best := {}
    var best_d := INF
    for c in candidates_in(sub, search):
        var d: float = ((c["position_m"] as Vector2) - world).length()
        if d < best_d:
            best_d = d
            best = c
    if best.is_empty():
        sub["state"] = NOT_IMPLIED
        sub["why"] = "the pool here is empty: %s implies %s plants per sub-cell" % [
                life_form, String.num(float(sub.get("implied_per_sub_cell", 0.0)), 4)]
        return sub
    var out := sub.duplicate()
    out["rank"] = int(best["rank"])
    out["candidate"] = int(best["candidate"])
    out["position_m"] = best["position_m"]
    out["distance_from_probe_m"] = best_d
    out["searched"] = mini(search, int(sub["pool"]))
    if str(sub["state"]) == BEYOND_HORIZON:
        out["state"] = BEYOND_HORIZON
    elif int(best["rank"]) >= int(sub["drawn"]):
        out["state"] = THINNED
        out["why"] = ("rank %d of a %d-deep pool, and this share draws the first %d. It has a "
                % [int(best["rank"]), int(sub["pool"]), int(sub["drawn"])]
                + "position and is not on screen.")
    else:
        out["state"] = DRAWN
        out["why"] = ""
    return out


## WHAT A RE-CENTRE DOES TO ONE PLANT: the interactive twin of the churn
## metric, answering WHICH plant and WHY rather than how many.
##
## The three exits are different findings. Thinning and the horizon are
## drawing decisions doing their job. A MOVED KEY IS A DEFECT: placement is a
## function of ground, so the same ground under a different camera must produce
## the same key, and this reports it as a bug rather than as churn.
func survives(world: Vector2, life_form: String, dx: float, dy: float) -> Dictionary:
    var before := nearest(world, life_form)
    if not bool(before.get("ok", false)) or not before.has("placement_key"):
        return before
    var r := _sc.report
    var centre: Array = r.get("centre_m", [0.0, 0.0])
    var moved := Vector2(float(centre[0]) + dx, float(centre[1]) + dy)

    # The key is recomputed from the SAME ground; only the camera moved.
    var key_after := VegetationScatter.placement_key(
            VegetationScatter.family_key(life_form),
            before["origin_m"], float(before["half_m"]))
    var out := {
        "ok": true,
        "life_form": life_form,
        "rank": before.get("rank", -1),
        "was": str(before["state"]),
        "key_before": int(before["placement_key"]),
        "key_after": key_after,
        "moved_centre_m": [moved.x, moved.y],
    }
    if key_after != int(before["placement_key"]):
        out["verdict"] = EXITS_KEY_MOVED
        out["why"] = ("the placement key changed when the camera did. Placement is a function "
                + "of ground (§16.6); this is a build defect and not churn.")
        return out

    var from_moved := ((before["origin_m"] as Vector2) - moved).length()
    var k := float(r.get("individuation_k", 0.0))
    var horizon_m := float(before.get("horizon_m", 0.0))
    if k > 0.0 and from_moved > horizon_m:
        out["verdict"] = EXITS_BEYOND_HORIZON
        out["why"] = "the re-centre puts this %s m past a %s m horizon" % [
                String.num(from_moved - horizon_m, 1), String.num(horizon_m, 1)]
        return out

    var keep := VegetationScatter.keep_at(from_moved, r.get("bands", []))
    var u := VegetationScatter.hash01(VegetationScatter.stable_hash3(key_after, 0, 7))
    var n_after := VegetationScatter.resolve_count(
            float(before["implied_per_sub_cell"]) * keep * float(before["share_drawn"]), u)
    out["drawn_before"] = int(before["drawn"])
    out["drawn_after"] = n_after
    if int(before.get("rank", 0)) >= n_after:
        out["verdict"] = EXITS_THINNED
        out["why"] = ("the schedule draws %d here after the re-centre and this is rank %d. "
                % [n_after, int(before.get("rank", -1))]
                + "The prefix is nested, so it is the same plants minus this one.")
        return out
    out["verdict"] = STAYS
    out["why"] = ""
    return out
