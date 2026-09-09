class_name NearFieldPatch
extends RefCounted

## THE NATIVE GROUND, WHERE THE BODY IS. One square of the tile pyramid, built
## as its own mesh over the overview and seamed to it.
##
## WHAT THIS IS FOR, STATED AS THE NUMBER IT MOVES. A plant placed on the
## overview's drawn plane stands a median 42.5 m from the ground the data
## holds, p95 252 m, worst 427 m, and the disc a standing body sees contains
## ZERO of the drawn mesh's ground samples -- the whole near field is the
## interior of one 4 km triangle. That is what this buys down. Frame time is a
## budget to stay inside; it is not the thing being bought.
##
## THE PATCH NEVER SUBTRACTS. Wherever it has nothing to say it reproduces the
## coarse surface exactly, and that one rule does four jobs at once:
##
##   * THE SEAM. The blend weight is exactly zero on the outermost ring, so
##     the rim lies ON the overview's drawn plane -- not near it. The coarse
##     surface between its samples is planar, so a rim vertex evaluated there
##     is exactly on the triangle it overlaps and there is no crack to close.
##   * NODATA. The native grid's holes are not the overview's holes: both come
##     from the same DEM but `average` over a 10x10 block is valid wherever
##     part of the block was. A hole in the patch where the coarse surface had
##     ground would DROP the plants standing there, and a rebuild that removes
##     a plant is a worse version of a rebuild that moves one (decision 952).
##   * A TILE IN FLIGHT. The patch is not built at all until every tile it
##     needs is resident -- `TileResidency.pump` says when -- so "not loaded
##     yet" is never drawn as anything.
##   * THE COARSE CONSUMERS. Nothing outside the patch changes, so a level
##     arriving cannot alter the basin view.
##
## VERTICES SIT ON THE PYRAMID'S OWN TEXEL CENTRES, and that is what removes
## the bicubic-across-a-tile-edge problem rather than solving it. Sixteen taps
## at a tile boundary reach into the neighbour; one tap at a texel centre
## reaches into exactly the tile that texel belongs to. So `refine = 1` needs
## no interpolation at all and the drawn height is the datum.
##
## WHICH MEANS THE DETAIL TERM IS INVISIBLE AT `refine = 1`, EXACTLY, and that
## is the stage-0 guard doing its job rather than a defect. The detail is zero
## at every parent node by construction; refining the pyramid's 100 m lattice
## makes its nodes the patch's vertices. Metre-scale relief appears when the
## patch is tessellated finer than the data it is refining -- `refine = 2` and
## up -- and the gate asserts both halves, because "the synthesis is on and
## nothing moved" and "the synthesis is off" look identical from anywhere
## except a test that knows which it expects.

## World position of grid node (0, 0) is derived from these rather than from a
## float centre, so a patch's samples are the pyramid's samples exactly and two
## patches around two observers agree at every shared node.
var t0 := Vector2i.ZERO           ## level texel index of node (0, 0)
var z: int = 0
var pixel_size_m: float = 0.0
var refine: int = 1
var step_m: float = 0.0           ## metres between patch nodes
var n: int = 0                    ## nodes per side
var centre := Vector2.ZERO
var half_extent_m: float = 0.0
var blend_m: float = TileResidency.BLEND_M

var mesh: ArrayMesh = null
var vertex_count: int = 0
var quad_count: int = 0
## Where each height came from, which is the honest form of "did streaming do
## anything here".
var from_native: int = 0
## Ramped toward the coarse surface because the node is in the blend ring.
## The cost of an exact seam, and it is not small: a 1,000 m ring on a 4,000 m
## half extent is 44% of the nodes. Counted so that it is a number somebody
## decided rather than one nobody noticed.
var from_ramp: int = 0
## No native datum here, so the coarse surface stands. The patch never
## subtracts, so this is ground kept rather than ground lost -- but it is the
## count that says how much of the near field streaming did NOT refine, and it
## must not be confused with the ring above.
var no_native: int = 0
var holes: int = 0

## THE MESH THIS PATCH IS SEAMED TO AND THE DETAIL TERM IT WAS BUILT WITH.
## Recorded for the same reason `TerrainMesh.detail` is: `GroundSurface`
## refuses a patch that does not belong to the mesh in front of it, so there is
## no arrangement in which plants stand on a level nobody is drawing.
var seamed_to: TerrainMesh = null
## The detail term AS THIS PATCH USES IT -- re-parented to the level it is
## refining, which is not the lattice the caller's field was built against.
var detail: DetailField = null
## The caller's field, before the re-parent. Kept so the fix-up is a recorded
## fact rather than a silent one, and so `GroundSurface` can ask whether the
## two are the same function.
var detail_family: DetailField = null
var detail_reparented_from_m: float = 0.0

var _y := PackedFloat64Array()     ## drawn height per node, NAN for a hole
## World position of node (0, 0), IN DOUBLE PRECISION. `world_of` hands back a
## `Vector2` because that is what a consumer comparing against the detail
## function's own node positions needs; this is what the reverse map needs, and
## they cannot be the same variable. Measured: routing `surface_y` through the
## float32 corner put every lookup 0.00125 of a cell off, which over a 100 m
## cell of real relief is up to 0.03 m of interpolation error -- small, and
## indistinguishable in an artefact from ground the streaming had failed to
## reproduce.
var _origin_w_x: float = 0.0
var _origin_w_y: float = 0.0
var why_refused: String = ""


## Build one patch. `centre_` must already be snapped -- `TileResidency.snap`
## is the one place that does it, and passing an unsnapped centre here would
## resample the ground half a texel over on every rebuild.
static func build(res: TileResidency, centre_: Vector2, z_: int,
                  hf: Heightfield, tm: TerrainMesh,
                  df: DetailField = null, refine_: int = 1) -> NearFieldPatch:
    var p := NearFieldPatch.new()
    p.seamed_to = tm
    p.detail_family = df
    p.refine = maxi(1, refine_)
    p.z = z_
    var tp := res.pyramid()
    if tp == null or not tp.is_loaded():
        p.why_refused = "no tile pyramid"
        return p
    p.pixel_size_m = tp.pixel_size_of(z_)
    if is_nan(p.pixel_size_m) or p.pixel_size_m <= 0.0:
        p.why_refused = "no level %d in the pin" % z_
        return p
    var reach := res.reach_texels(z_)
    if reach <= 0:
        p.why_refused = "level %d is coarser than the patch" % z_
        return p
    p.centre = centre_
    p.half_extent_m = res.half_extent_m(z_)
    p.step_m = p.pixel_size_m / float(p.refine)
    p.n = 2 * reach * p.refine + 1
    # ONE CORNER, IN DOUBLE PRECISION, AND IT MUST BE THE OVERVIEW'S.
    #
    # The detail term is exactly zero on the lattice it refines, and that
    # exactness is asserted by comparing positions rather than by a tolerance.
    # `DetailField.parent_node` builds a node from the HEIGHTFIELD's corner;
    # this builds one from the PYRAMID's. The pin says they are the same
    # corner and the two grids are nested -- but "says" is not "checked", and
    # if they ever part company the patch's vertices stop being parent nodes
    # by a fraction of a metre, the detail stops vanishing on them, and what
    # shows is a millimetre of roughness on a mesh that is supposed to be the
    # data. Cheaper to refuse.
    if absf(tp.origin_x - hf.origin_x) > 0.0 or absf(tp.origin_y - hf.origin_y) > 0.0:
        p.why_refused = ("the tile grid's corner (%s, %s) is not the overview's (%s, %s). "
                % [String.num(tp.origin_x, 6), String.num(tp.origin_y, 6),
                        String.num(hf.origin_x, 6), String.num(hf.origin_y, 6)]
                + "The two grids have to be nested for the patch's vertices to be the "
                + "lattice the detail term vanishes on, and they are not.")
        return p
    # THE PARENT LATTICE IS THE LEVEL, AND THE PATCH IS THE ONLY OBJECT THAT
    # KNOWS WHICH LEVEL IT IS. So it re-parents the field rather than trusting
    # a caller to have computed a number the caller does not own -- which is
    # exactly the class of mistake this method existed for a week without.
    #
    # `DetailField.load_from` defaults the parent to the heightfield's own
    # pixel, which is the shipped 1,000 m overview. Every construction in the
    # tree takes that default. Handed straight to a 100 m patch it puts a
    # non-zero detail term on all 729 sampled patch vertices and moves the
    # drawn height at 676 of them -- the other 53 are on the rim, where the
    # blend weight is zero and nothing is applied -- by up to 0.36 m, at 3.55x
    # the amplitude the same row means at 100 m. And the exact-at-parent guard
    # goes on being green about a lattice nobody is drawing.
    #
    # Recorded rather than silent: `report()` carries both spacings.
    if df != null:
        p.detail_reparented_from_m = df.parent_spacing_m
        p.detail = df.for_parent(p.pixel_size_m)
    p._grid_origin_x = tp.origin_x
    p._grid_origin_y = tp.origin_y
    # THE SAME EXPRESSION `DetailField.parent_node` USES, and it has to be.
    # Exactness at the parent lattice is asserted by comparing POSITIONS, so
    # the position a patch vertex arrives at must be the float the detail
    # function computes for that node -- not a value a different but equal
    # arithmetic produced.
    p.t0 = Vector2i(int(round((centre_.x - tp.origin_x) / p.pixel_size_m - 0.5)) - reach,
                    int(round((tp.origin_y - centre_.y) / p.pixel_size_m - 0.5)) - reach)
    p._origin_w_x = p._grid_origin_x + (float(p.t0.x) + 0.5) * p.pixel_size_m
    p._origin_w_y = p._grid_origin_y - (float(p.t0.y) + 0.5) * p.pixel_size_m
    p._sample(tp, hf, tm)
    p._surface(hf, tm)
    return p


## The pyramid grid's top-left CORNER, which is also the overview's. Held so
## that a node's world position is arithmetic on the grid rather than on the
## patch's own float centre.
var _grid_origin_x: float = 0.0
var _grid_origin_y: float = 0.0


## The world position of a patch node.
##
## AT `refine = 1` THIS IS CHARACTER FOR CHARACTER THE EXPRESSION
## `DetailField.parent_node` USES. That is not a coincidence to be tidied up:
## the exact-at-parent guard compares positions rather than tolerances, so a
## patch vertex is on the parent lattice only if it arrives at the same float.
func world_of(i: int, j: int) -> Vector2:
    var fx := float(t0.x) + float(i) / float(refine)
    var fy := float(t0.y) + float(j) / float(refine)
    return Vector2(_grid_origin_x + (fx + 0.5) * pixel_size_m,
                   _grid_origin_y - (fy + 0.5) * pixel_size_m)


## HOW MUCH OF THE REFINEMENT SURVIVES AT THIS NODE. One across the interior,
## ramping to exactly zero on the outermost ring.
##
## CHEBYSHEV, NOT EUCLIDEAN, because the patch is a square and the rim is its
## edge: a radial weight would reach zero at the edge midpoints and not at the
## corners, which is a seam that holds along four lines and gaps at four
## points -- the failure that is hardest to see and easiest to ship.
func weight_at(i: int, j: int) -> float:
    if blend_m <= 0.0:
        return 1.0
    var c := (n - 1) / 2
    var d := float(maxi(absi(i - c), absi(j - c))) * step_m
    return clampf((half_extent_m - d) / blend_m, 0.0, 1.0)


func _sample(tp: TilePyramid, hf: Heightfield, tm: TerrainMesh) -> void:
    _y.resize(n * n)
    var exag := tm.exaggeration
    var has_detail := detail != null and detail.is_loaded()
    for j in n:
        for i in n:
            var w := world_of(i, j)
            # THE COARSE SURFACE FIRST, because it decides whether there is a
            # vertex at all. A hole in the overview is a hole in the basin as
            # every other consumer already understands it, and the patch is
            # not the place to start disagreeing about the boundary.
            var coarse := tm.drawn_surface_y(w, hf)
            if is_nan(coarse):
                _y[j * n + i] = NAN
                holes += 1
                continue
            var native := tp.height_at_world(w.x, w.y, z)
            if is_nan(native):
                _y[j * n + i] = coarse
                no_native += 1
                continue
            var refined := native
            if has_detail:
                refined += detail.detail_at(w)
            var t := weight_at(i, j)
            _y[j * n + i] = coarse + t * (refined * exag - coarse)
            if t >= 1.0:
                from_native += 1
            else:
                from_ramp += 1


func _surface(hf: Heightfield, tm: TerrainMesh) -> void:
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var index_of := PackedInt32Array()
    index_of.resize(n * n)
    index_of.fill(-1)
    for j in n:
        for i in n:
            var y := _y[j * n + i]
            if is_nan(y):
                continue
            var w := world_of(i, j)
            var m := tm.world_to_mesh(w, hf)
            index_of[j * n + i] = verts.size()
            verts.append(Vector3(m.x, y, m.y))
            normals.append(_normal_at(i, j, tm.shading_exaggeration))
            # The overview's texel grid, the same addressing the terrain shader
            # already uses, so an overlay painted for the coarse mesh lands on
            # the patch without a second alignment rule.
            var t := hf.world_to_texel(w.x, w.y)
            uvs.append(Vector2((t.x + 0.5) / float(hf.width),
                               (t.y + 0.5) / float(hf.height)))
    for j in n - 1:
        for i in n - 1:
            var a := index_of[j * n + i]
            var b := index_of[j * n + i + 1]
            var c := index_of[(j + 1) * n + i]
            var d := index_of[(j + 1) * n + i + 1]
            if a < 0 or b < 0 or c < 0 or d < 0:
                continue
            # THE SAME DIAGONAL `TerrainMesh` SPLITS ON. `surface_y` below
            # reproduces this triangulation to answer where the ground is, and
            # the two agreeing is the whole of that method's correctness.
            indices.append_array([a, b, c, b, d, c])
            quad_count += 1
    vertex_count = verts.size()
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh = ArrayMesh.new()
    if indices.size() > 0:
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _normal_at(i: int, j: int, exag: float) -> Vector3:
    var l := _y[j * n + maxi(i - 1, 0)]
    var r := _y[j * n + mini(i + 1, n - 1)]
    var u := _y[maxi(j - 1, 0) * n + i]
    var d := _y[mini(j + 1, n - 1) * n + i]
    if is_nan(l) or is_nan(r) or is_nan(u) or is_nan(d):
        return Vector3.UP
    var dzdx := (r - l) * exag / (2.0 * step_m)
    var dzdy := (d - u) * exag / (2.0 * step_m)
    return Vector3(-dzdx, 1.0, -dzdy).normalized()


func is_built() -> bool:
    return mesh != null and vertex_count > 0


## Whether a world position is inside this patch's footprint.
func contains(w: Vector2) -> bool:
    var f := _grid_of(w)
    return f.x >= 0.0 and f.y >= 0.0 and f.x <= float(n - 1) and f.y <= float(n - 1)


func _grid_of(w: Vector2) -> Vector2:
    return Vector2((w.x - _origin_w_x) / step_m, (_origin_w_y - w.y) / step_m)


## WHAT THIS PATCH DRAWS AT A WORLD POSITION -- its own triangulated plane, the
## same way `TerrainMesh.drawn_surface_y` reports the coarse one. NAN outside
## the footprint or over a hole, and a caller that wants one surface for the
## whole basin asks `GroundSurface`, which is the object that knows which of
## the two applies where.
func surface_y(w: Vector2) -> float:
    if not is_built():
        return NAN
    var f := _grid_of(w)
    var i := int(floor(f.x))
    var j := int(floor(f.y))
    if i < 0 or j < 0 or i >= n - 1 or j >= n - 1:
        # The far edge is a legitimate position and floors to the last node.
        i = clampi(i, 0, n - 2)
        j = clampi(j, 0, n - 2)
    var u := f.x - float(i)
    var v := f.y - float(j)
    if u < 0.0 or v < 0.0 or u > 1.0 or v > 1.0:
        return NAN
    var ya := _y[j * n + i]
    var yb := _y[j * n + i + 1]
    var yc := _y[(j + 1) * n + i]
    var yd := _y[(j + 1) * n + i + 1]
    if u + v <= 1.0:
        if is_nan(ya) or is_nan(yb) or is_nan(yc):
            return NAN
        return ya + u * (yb - ya) + v * (yc - ya)
    if is_nan(yd) or is_nan(yb) or is_nan(yc):
        return NAN
    return yd + (1.0 - u) * (yc - yd) + (1.0 - v) * (yb - yd)


## The drawn height at a node, for a test that wants to compare two patches
## node by node rather than through the triangulation.
func height_at_node(i: int, j: int) -> float:
    if i < 0 or j < 0 or i >= n or j >= n:
        return NAN
    return _y[j * n + i]


## How many of this patch's own ground samples fall inside a disc -- the
## acceptance metric's numerator, answered by the patch rather than recomputed
## by whoever is asking.
func nodes_within(w: Vector2, radius_m: float) -> int:
    var count := 0
    for j in n:
        for i in n:
            if is_nan(_y[j * n + i]):
                continue
            if (world_of(i, j) - w).length() <= radius_m:
                count += 1
    return count


func report() -> Dictionary:
    return {
        "z": z,
        "pixel_size_m": pixel_size_m,
        "refine": refine,
        "step_m": step_m,
        "nodes_per_side": n,
        "half_extent_m": half_extent_m,
        "vertices": vertex_count,
        "quads": quad_count,
        "from_native": from_native,
        "from_ramp": from_ramp,
        "no_native": no_native,
        "holes": holes,
        "detail": detail != null and detail.is_loaded(),
        "detail_parent_m": (detail.parent_spacing_m if detail != null else 0.0),
        "detail_reparented_from_m": detail_reparented_from_m,
        "why_refused": why_refused,
    }
