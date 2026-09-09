class_name GroundSurface
extends RefCounted

## ONE GROUND, EVERY CONSUMER.
##
## The wrong-ground defect has already happened once here at kilometre scale:
## plants were placed on the heightfield while the mesh drew a triangulation of
## it, and the two disagree by a mean of 36 m and up to 640 m -- invisible from
## a map camera and the whole picture at eye level. The fix was to place on the
## surface that is DRAWN. Adding a metre-scale detail term reopens exactly that
## class of defect one scale down, and this class is what stops it.
##
## THE GUARD IS STRUCTURAL, NOT A TEST. There is one object, both consumers ask
## it, and it refuses to answer at all when the mesh in front of it was built
## with a different detail term from the one it is holding. That refusal is the
## point: a scatter standing on a detail surface the mesh does not draw would
## look correct from above and be wrong at every plant, which is the shape of
## the defect that took a seam run to find.
##
## SO DETAIL IS ON FOR BOTH CONSUMERS OR FOR NEITHER. There is no arrangement
## in which one of them has it.
##
## AND THE SAME THING ONE LEVEL UP, WHICH IS WHAT STREAMING ADDS. A near-field
## patch is a second drawn surface over part of the basin. A mesh built at one
## level while the scatter samples another is the identical defect at LEVEL
## granularity rather than at metre granularity -- and a worse version of it,
## because the two surfaces differ by a median 42.5 m rather than by
## centimetres. So a patch is `stream`ed in rather than assigned, and the
## setter refuses one that does not belong to the mesh in front of it: holding
## a patch at all is then proof that it is the patch being drawn.

## The mesh's own triangulated surface, and the field it was built from.
var _hf: Heightfield = null
var _tm: TerrainMesh = null
## The detail term, or null. Held rather than looked up so that "which detail
## did the mesh use" is a single comparable reference.
var detail: DetailField = null
## The near-field patch, when one is standing. Read through `stream`, never
## assigned: see `stream` for what it refuses and why that is the guard.
var patch: NearFieldPatch = null

var why_refused: String = ""


static func over(hf: Heightfield, tm: TerrainMesh, df: DetailField = null) -> GroundSurface:
    var g := GroundSurface.new()
    g._hf = hf
    g._tm = tm
    g.detail = df
    return g


## Whether the mesh in front of this surface carries the detail this surface
## holds. Both null is agreement; one null is not.
func agrees_with_mesh() -> bool:
    if _tm == null:
        return false
    var theirs: DetailField = _tm.detail
    # Spelled out rather than written as one comparison: `==` between an object
    # and null is a place where a typed language and an untyped one differ, and
    # this predicate is the whole of a guard.
    if detail == null:
        return theirs == null
    if theirs == null:
        return false
    return detail == theirs


## ACCEPT A NEAR-FIELD PATCH, or refuse it and say which half did not match.
##
## THE CHECK IS THE POINT AND THE ASSIGNMENT IS NOT. A patch carries the mesh
## it was seamed to and the detail term it was built with, so both halves of
## "is this the ground being drawn" are answerable here rather than by whoever
## remembered to call in the right order.
func stream(p: NearFieldPatch) -> bool:
    if p == null:
        patch = null
        return true
    if not p.is_built():
        why_refused = ("the patch did not build: %s" % p.why_refused)
        return false
    if p.seamed_to != _tm:
        why_refused = ("the patch was seamed to a different mesh from the one this surface "
                + "holds. Plants would stand on a level nobody is drawing, which is the "
                + "wrong-ground defect at level granularity.")
        return false
    # THE SAME FUNCTION, NOT THE SAME OBJECT, AND THE DIFFERENCE IS THE WHOLE
    # OF THIS CHECK.
    #
    # Object identity was right while one lattice was the only lattice. A patch
    # refines the pyramid's level, not the overview, so its field is re-parented
    # -- and an identity test would REFUSE the correctly parented field and
    # accept only the mis-parented one. A guard enforcing the defect it exists
    # to prevent is worse than no guard, because it is green.
    #
    # So: same rows, same calibration, and the parent is checked separately
    # against the level the patch actually refines.
    if detail == null:
        if p.detail_family != null:
            why_refused = ("the patch carries a detail term and this surface holds none. One "
                    + "ground, every consumer -- and that has to survive a level arriving.")
            return false
    elif not detail.same_function_as(p.detail_family):
        why_refused = ("the patch was built from different detail rows, or from rows "
                + "calibrated against a different parent, than this surface holds. Same "
                + "function on both sides or neither.")
        return false
    if p.detail != null and not is_equal_approx(p.detail.parent_spacing_m, p.pixel_size_m):
        why_refused = ("the patch refines a %s m level and its detail term is parented to "
                % String.num(p.pixel_size_m, 0)
                + "%s m. The exactness the whole method rests on is defined against the grid "
                % String.num(p.detail.parent_spacing_m, 0)
                + "being refined, so a field parented anywhere else is exact about a lattice "
                + "nobody is drawing while adding the wrong amplitude to the one they are.")
        return false
    patch = p
    why_refused = ""
    return true


## WHAT A PLANT STANDS ON, and what the mesh draws, which must be the same
## number or neither is answered.
##
## NAN with a reason rather than a plausible height. A caller that gets a
## number here is entitled to assume the mesh drew that surface; if it cannot
## be, the honest answer is no answer.
func surface_at(w: Vector2) -> float:
    if _tm == null or _hf == null:
        why_refused = "no mesh and no field"
        return NAN
    if not agrees_with_mesh():
        why_refused = ("the mesh was built with %s and this surface holds %s. A plant standing "
                % [("a detail term" if _tm.detail != null else "no detail term"),
                        ("one" if detail != null else "none")]
                + "on a surface the mesh does not draw is the wrong-ground defect at metre "
                + "scale, so this refuses rather than answering plausibly.")
        return NAN
    why_refused = ""
    # THE PATCH WINS WHERE IT COVERS, AND NOWHERE ELSE. Its rim lies exactly on
    # the coarse plane, so the two agree at the boundary and this is a choice
    # between equal answers there rather than a step.
    if patch != null and patch.contains(w):
        var y := patch.surface_y(w)
        # A hole in the patch over ground the coarse surface has is the one
        # case that must not fall through to the coarse answer: the patch is
        # DRAWN there or it is not, and if it is not then neither is the
        # ground. `NearFieldPatch` is built so this cannot arise -- it never
        # subtracts -- and this says so rather than assuming it.
        if not is_nan(y):
            return y
    return _tm.drawn_surface_y(w, _hf)


## The FUNCTION's ground -- lattice plus detail -- which is what the world is,
## as opposed to what this mesh happens to draw of it. They differ by whatever
## the mesh's triangulation loses, and a consumer wanting one should never take
## the other by accident, so they are named apart.
func function_at(w: Vector2) -> float:
    if detail != null and detail.is_loaded():
        return detail.height_at(w)
    return NAN if _hf == null else _hf.height_at_world(w.x, w.y)
