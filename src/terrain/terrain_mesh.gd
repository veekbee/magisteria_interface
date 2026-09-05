class_name TerrainMesh
extends RefCounted

## Builds the overview mesh from a `Heightfield`. M1.
##
## COORDINATES ARE RECENTRED, AND THAT IS NOT COSMETIC. The export is in
## EPSG:5070, where this basin sits around x = -1.3e6, y = 1.6e6 metres. A
## renderer's transforms are float32, which has ~7 significant digits, so a
## vertex at 1.6e6 m resolves to about 0.1 m -- and every camera matrix
## multiplication compounds it into visible jitter. The mesh is therefore built
## about its own centre and the offset is kept as `world_origin`, so a world
## coordinate is still recoverable exactly when a probe needs one (M4).
##
## NODATA IS A HOLE, NOT A ZERO. A quad is emitted only when all four of its
## corners are valid. The alternative -- clamping nodata to some height -- puts
## a wall around the basin that looks like terrain and is not.
##
## NO LATTICE GEOMETRY (decision 890). This builds one surface from the DEM.
## There is no cell outline, no patch grid, and no debug mode that adds one.

var mesh: ArrayMesh = null
var world_origin := Vector2.ZERO      ## EPSG:5070 metres of the mesh's origin
var vertex_count: int = 0
var quad_count: int = 0
var skipped_quads: int = 0
var stride: int = 1
var exaggeration: float = 1.0

## What the NORMALS are computed as if the exaggeration were, which is not what
## the vertices are built at.
##
## THE SPACE IS 1:1 AND THE SHADING IS NOT. Vertical exaggeration was removed
## from this project's geometry: terrain, plants and distances are all true
## scale, so `cover = count x crown area` holds by construction and no tuned
## distance is conditional on a factor. What that costs is relief legibility --
## 4 km of relief across 1,000 km of basin hillshades weakly from a map camera,
## and 12x existed for exactly that.
##
## So the gradient is steepened where the light reads it and nowhere else. A
## normal is a lighting input; moving a vertex is a geometric claim. Nothing
## downstream of this can tell the difference, because nothing downstream of
## this reads a normal for anything but shading: `drawn_surface_y`, the drapes,
## the scatter and the probe all use the height field and the vertex positions,
## which are true.
var shading_exaggeration: float = 1.0


## `stride` samples every Nth texel. `exaggeration` scales vertex height, and is
## 1.0 everywhere in this project; `shading_exaggeration` steepens the gradient
## the NORMALS are computed from, which moves no geometry.
func build(hf: Heightfield, stride_: int = 2, exaggeration_: float = 1.0,
           shading_exaggeration_: float = -1.0) -> ArrayMesh:
    stride = max(1, stride_)
    exaggeration = exaggeration_
    shading_exaggeration = (exaggeration_ if shading_exaggeration_ < 0.0
            else shading_exaggeration_)
    var nx := int(hf.width / stride)
    var ny := int(hf.height / stride)
    world_origin = Vector2(hf.origin_x, hf.origin_y)

    # Heights first, so a quad can ask about its corners without resampling.
    var h := PackedFloat32Array()
    h.resize(nx * ny)
    for j in ny:
        for i in nx:
            # Sampled through `height_at`, not `height_at_texel`: with a stride
            # the mesh is a RESAMPLING of the field, which is exactly where
            # §16.5's terracing appears if the sampling is nearest.
            h[j * nx + i] = hf.height_at(float(i * stride), float(j * stride))

    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    # UVs address the heightfield's own texel grid, so an overlay built on that
    # grid lands on the terrain without a second alignment rule to get wrong.
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var index_of := PackedInt32Array()
    index_of.resize(nx * ny)
    index_of.fill(-1)

    var half_x := 0.5 * float(nx - 1) * stride * hf.pixel_size_m
    var half_y := 0.5 * float(ny - 1) * stride * hf.pixel_size_m
    var step := float(stride) * hf.pixel_size_m

    for j in ny:
        for i in nx:
            var z := h[j * nx + i]
            if is_nan(z):
                continue
            index_of[j * nx + i] = verts.size()
            # +X east, +Z south, +Y up: a north-up top-down camera then needs
            # no flip, which is the orientation a map reader expects.
            verts.append(Vector3(float(i) * step - half_x,
                                 z * exaggeration,
                                 float(j) * step - half_y))
            normals.append(_normal_at(h, nx, ny, i, j, step, shading_exaggeration))
            uvs.append(Vector2((float(i * stride) + 0.5) / float(hf.width),
                               (float(j * stride) + 0.5) / float(hf.height)))

    for j in ny - 1:
        for i in nx - 1:
            var a := index_of[j * nx + i]
            var b := index_of[j * nx + i + 1]
            var c := index_of[(j + 1) * nx + i]
            var d := index_of[(j + 1) * nx + i + 1]
            if a < 0 or b < 0 or c < 0 or d < 0:
                skipped_quads += 1
                continue
            # WINDING IS CLOCKWISE-FRONT IN GODOT, and this had it backwards.
            # Wound the other way the surface renders only from BELOW: the
            # overview camera looks down at a basin whose every triangle faces
            # away from it, and the terrain is invisible while the flowlines
            # over it -- LINES, which are never culled -- still draw. The basin
            # then reads as a river network floating on the background, which is
            # exactly how it looked and how long it lasted.
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
    return mesh


## Central-difference normal. Hillshade reads this, so it is computed from the
## sampled grid rather than from the triangles -- a per-face normal would make
## the shading show the triangulation, which is the mesh's structure and not
## the ground's.
func _normal_at(h: PackedFloat32Array, nx: int, ny: int, i: int, j: int,
                step: float, exag: float) -> Vector3:
    var l := h[j * nx + max(i - 1, 0)]
    var r := h[j * nx + min(i + 1, nx - 1)]
    var u := h[max(j - 1, 0) * nx + i]
    var d := h[min(j + 1, ny - 1) * nx + i]
    if is_nan(l) or is_nan(r) or is_nan(u) or is_nan(d):
        return Vector3.UP
    var dzdx := (r - l) * exag / (2.0 * step)
    var dzdy := (d - u) * exag / (2.0 * step)
    return Vector3(-dzdx, 1.0, -dzdy).normalized()


## The world (EPSG:5070) position of a mesh-space point -- M4 probes need it.
##
## THE HALF TEXEL IS THE WHOLE OF THIS METHOD. Vertex (i, j) samples the
## heightfield at continuous texel coordinate (i * stride, j * stride), and a
## texel coordinate names a texel's CENTRE -- `Heightfield.world_to_texel`
## subtracts the half itself. Leaving it out here put every recovered world
## position half a pixel, 500 m on this grid, off the texel the vertex was
## built from: invisible in the surface, and enough to name the neighbouring
## cell wherever a probe lands within half a texel of a residence boundary.
## M4 found it by needing the inverse, which is the only thing that asks.
func mesh_to_world(p: Vector3, hf: Heightfield) -> Vector2:
    var h := _half_extent(hf)
    return Vector2(world_origin.x + p.x + h.x + 0.5 * hf.pixel_size_m,
                   world_origin.y - (p.z + h.y) - 0.5 * hf.pixel_size_m)


## Its exact inverse: world (EPSG:5070) -> the mesh's x and z.
##
## Everything draping onto this mesh goes through here rather than
## re-deriving the centring at the call site. Two copies of one transform are
## two places for a term to go missing, and that is precisely where the half
## texel above was hiding -- in the forward map as well as the inverse, so the
## drape and the mesh agreed with each other and both disagreed with the grid.
func world_to_mesh(w: Vector2, hf: Heightfield) -> Vector2:
    var h := _half_extent(hf)
    return Vector2(w.x - world_origin.x - h.x - 0.5 * hf.pixel_size_m,
                   (world_origin.y - w.y) - h.y - 0.5 * hf.pixel_size_m)


## The height of the DRAWN surface at a world position -- the mesh's own
## triangulated plane, not the field it was sampled from.
##
## THE MESH IS NOT THE HEIGHTFIELD AND THE GAP IS METRES TO HUNDREDS OF METRES.
## `build` samples the field every `stride` texels -- 4 km apart on the 1,000 m
## overview -- and triangulates those samples, so what renders between them is a
## plane and the field beneath it is not. A camera placed at "field height plus
## eye height" is routinely UNDER the drawn surface, and back-face culling then
## renders that as an empty frame or as a view out from under a slab with no
## near ground in it. Both were observed while building `measure_seam`, and a
## bound over the four surrounding samples was not good enough either: an upper
## bound puts the eye up to a cell's worth of relief above the ground, which
## from 4 km cells is hundreds of metres and takes the near field out of frame
## the other way.
##
## So this reproduces the triangulation exactly, including which diagonal
## `build` splits a quad along -- `[a, b, c, b, d, c]`, the diagonal from
## (i+1, j) to (i, j+1). A different diagonal here would put the camera under
## the surface on half the quads and nowhere near it on the rest.
## Memoised on the last quad, because the caller is the scatter and its
## instances arrive in runs: every plant in a texel -- and there are up to a
## kilometre of them -- falls in the same 4 km quad, so four bicubic samples
## serve thousands of placements. Without it a 1.65 M-instance build went from
## 14 s to 44 s.
var _quad_at := Vector2i(-2147483648, -2147483648)
var _quad_y := PackedFloat64Array([NAN, NAN, NAN, NAN])


func drawn_surface_y(w: Vector2, hf: Heightfield) -> float:
    var m := world_to_mesh(w, hf)
    var h := _half_extent(hf)
    var step := float(stride) * hf.pixel_size_m
    var fx := (m.x + h.x) / step
    var fy := (m.y + h.y) / step
    var i := int(floor(fx))
    var j := int(floor(fy))
    var u := fx - float(i)
    var v := fy - float(j)
    if _quad_at.x != i or _quad_at.y != j:
        _quad_at = Vector2i(i, j)
        _quad_y[0] = hf.height_at(float(i * stride), float(j * stride))
        _quad_y[1] = hf.height_at(float((i + 1) * stride), float(j * stride))
        _quad_y[2] = hf.height_at(float(i * stride), float((j + 1) * stride))
        _quad_y[3] = hf.height_at(float((i + 1) * stride), float((j + 1) * stride))
    var ya := _quad_y[0]
    var yb := _quad_y[1]
    var yc := _quad_y[2]
    var yd := _quad_y[3]
    var y: float
    if u + v <= 1.0:
        if is_nan(ya) or is_nan(yb) or is_nan(yc):
            return NAN
        y = ya + u * (yb - ya) + v * (yc - ya)
    else:
        if is_nan(yd) or is_nan(yb) or is_nan(yc):
            return NAN
        y = yd + (1.0 - u) * (yc - yd) + (1.0 - v) * (yb - yd)
    return y * exaggeration


func _half_extent(hf: Heightfield) -> Vector2:
    return Vector2(0.5 * float(int(hf.width / stride) - 1) * stride * hf.pixel_size_m,
                   0.5 * float(int(hf.height / stride) - 1) * stride * hf.pixel_size_m)
