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

## The mesh's own triangulated surface, and the field it was built from.
var _hf: Heightfield = null
var _tm: TerrainMesh = null
## The detail term, or null. Held rather than looked up so that "which detail
## did the mesh use" is a single comparable reference.
var detail: DetailField = null

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
    return _tm.drawn_surface_y(w, _hf)


## The FUNCTION's ground -- lattice plus detail -- which is what the world is,
## as opposed to what this mesh happens to draw of it. They differ by whatever
## the mesh's triangulation loses, and a consumer wanting one should never take
## the other by accident, so they are named apart.
func function_at(w: Vector2) -> float:
    if detail != null and detail.is_loaded():
        return detail.height_at(w)
    return NAN if _hf == null else _hf.height_at_world(w.x, w.y)
