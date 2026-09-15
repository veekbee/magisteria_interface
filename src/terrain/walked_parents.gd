class_name WalkedParents
extends RefCounted

## Decision 1040's walked-parent set: every parent lattice at which this build
## may draw walkable ground.
##
## WHY IT IS A DECLARATION AND WHY IT IS NOT A TYPED LIST. Decision 1040
## evaluates decision 986's conditions 2 and 3 at every parent walkable ground is
## drawn at, with the verdict the conjunction. Before this existed the parent
## was whatever `DetailField.load_from` happened to default to -- the shipped
## 1,000 m overview -- while `NearFieldPatch` re-parented to the pyramid level
## it was drawing. `near_field_patch.gd` said so in a comment for weeks, beside
## the code that avoids it, and nothing connected the fact to the grader.
##
## SO IT IS DERIVED FROM THE PYRAMID AND NOT TRANSCRIBED. A typed list is a
## second copy of the tile pin's own levels, free to disagree with it, and the
## lesson of `GRADED_LAGS` was that a value living anywhere but the place that
## owns it eventually says something the owner does not. What is DECLARED here
## is the RULE -- which lattices draw walkable ground and why -- and the set
## follows from the vendored pyramid.
##
## MAY DRAW, NOT DID DRAW. `TileResidency.level_for` walks the pyramid from the
## finest level and takes the first whose tiles are all fetched, so a client with
## a partial pyramid walks on a coarser parent than one with a full pyramid. A
## set meaning *what this run used* would be a different claim on every machine,
## which is why 1040's declaration is over what the build may reach.
##
## THE OVERVIEW IS NOT IN THE SET, AND THAT IS THE EDGE WORTH STATING. Walkable
## ground is a `NearFieldPatch` and a patch is always a pyramid level; the
## 1,000 m overview draws the far field. With no pyramid at all `level_for`
## returns -1, no patch builds, and what is on screen is the overview mesh --
## but walk mode cannot open there, and calling that a walked parent would put
## the lattice nobody walks back into the set this exists to keep it out of.
##
## ABSENT IS REFUSED AND NOT DEFAULTED, per 1040. A pyramid that is not fetched
## yields no set and says so; defaulting to the overview would reintroduce
## exactly the parent the ruling was written about.

## The parent spacings, finest first. Empty when the pyramid is absent.
var spacings_m: PackedFloat64Array = PackedFloat64Array()
## Empty when the set is readable; a sentence when it is not.
var why_absent: String = ""


static func of_pyramid(tp: TilePyramid) -> WalkedParents:
    var wp := WalkedParents.new()
    if tp == null or not tp.is_loaded():
        wp.why_absent = ("no tile pyramid, so there is no set of parents walkable ground is "
                + "drawn at: %s" % ("" if tp == null else tp.why_absent))
        return wp
    var seen := {}
    for lv in tp.levels:
        var px := float((lv as Dictionary).get("pixel_size_m", NAN))
        if is_nan(px) or px <= 0.0:
            continue
        seen[px] = true
    if seen.is_empty():
        wp.why_absent = "the tile pyramid declares no level with a pixel size"
        return wp
    var sorted := seen.keys()
    sorted.sort()
    for px in sorted:
        wp.spacings_m.append(float(px))
    return wp


static func of_vendored() -> WalkedParents:
    return of_pyramid(TilePyramid.load_from())


func is_declared() -> bool:
    return spacings_m.size() > 0


## The finest parent, which is the one a fully-fetched client walks on.
##
## NAMED BUT NOT PRIVILEGED: 1040's verdict is the conjunction, so this is for
## reporting rather than for grading. A consumer grading only here would be
## certifying the best case and calling it the world.
func finest_m() -> float:
    return NAN if spacings_m.is_empty() else spacings_m[0]


func as_array() -> Array:
    var out: Array = []
    for v in spacings_m:
        out.append(float(v))
    return out
