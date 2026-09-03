class_name FlowlineDrape
extends RefCounted

## Flowlines draped onto the terrain surface. M1; M3 lights them by `comid`.
##
## Each reach keeps its NHD `comid` as the mesh's name, because M3 keys
## streamflow onto it and a drawn line with no key can never be lit. Reaches
## are grouped into ONE mesh per stream order rather than one node per reach:
## 29,502 nodes would cost more in the tree than the geometry does on the GPU.
##
## LIFTED, NOT PROJECTED. A polyline sampled at the same heights as the surface
## z-fights along its whole length. It is raised by a fraction of the local
## pixel instead of a fixed epsilon, so the lift is scale-free the way decision
## 892 asks the hiding to be -- a constant would vanish at the overview and
## float visibly on a full-resolution tile.

const LIFT_FRACTION := 0.004   ## of one heightfield pixel, per §892's scale-free note

var order_meshes: Dictionary = {}     ## stream order -> ArrayMesh
var reach_count: int = 0
var dropped_offmap: int = 0


func build(reaches: Array, hf: Heightfield, tm: TerrainMesh) -> Dictionary:
    var by_order: Dictionary = {}
    var half_x := 0.5 * float(int(hf.width / tm.stride) - 1) * tm.stride * hf.pixel_size_m
    var half_y := 0.5 * float(int(hf.height / tm.stride) - 1) * tm.stride * hf.pixel_size_m
    var lift := LIFT_FRACTION * hf.pixel_size_m

    for r in reaches:
        var xy: Array = r.get("xy", [])
        var order: int = int(r.get("order", 0))
        var pts := PackedVector3Array()
        for k in range(0, xy.size() - 1, 2):
            var wx := float(xy[k])
            var wy := float(xy[k + 1])
            var h := hf.height_at_world(wx, wy)
            if is_nan(h):
                continue          # off the valid heightfield; see dropped_offmap
            pts.append(Vector3(wx - hf.origin_x - half_x,
                               h * tm.exaggeration + lift,
                               (hf.origin_y - wy) - half_y))
        if pts.size() < 2:
            dropped_offmap += 1
            continue
        if not by_order.has(order):
            by_order[order] = PackedVector3Array()
        # A line strip per reach cannot share a mesh, so segments are emitted
        # as pairs: one LINES surface per order, no strip restarts to manage.
        var acc: PackedVector3Array = by_order[order]
        for k in pts.size() - 1:
            acc.append(pts[k])
            acc.append(pts[k + 1])
        by_order[order] = acc
        reach_count += 1

    for order in by_order:
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = by_order[order]
        var m := ArrayMesh.new()
        m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
        order_meshes[order] = m
    return order_meshes
