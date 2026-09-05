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
var reaches_without_node: int = 0

## M3 repaints per day, so the geometry is built once and only the colours are
## rewritten. One combined mesh rather than one per order: colour now carries
## flow, and grouping by order would put a second meaning on the same channel.
var flow_mesh: ArrayMesh = null
var _flow_verts: PackedVector3Array = PackedVector3Array()
var _reach_node: PackedStringArray = PackedStringArray()   ## per reach
var _reach_span: PackedInt32Array = PackedInt32Array()     ## start,count pairs


func build(reaches: Array, hf: Heightfield, tm: TerrainMesh) -> Dictionary:
    var by_order: Dictionary = {}
    var lift := LIFT_FRACTION * hf.pixel_size_m

    for r in reaches:
        var xy: Array = r.get("xy", [])
        var order: int = int(r.get("order", 0))
        var pts := PackedVector3Array()
        for k in range(0, xy.size() - 1, 2):
            var wx := float(xy[k])
            var wy := float(xy[k + 1])
            # ON THE SURFACE THAT IS DRAWN. `h * exaggeration` is the field,
            # and the mesh triangulates the field every `stride` texels -- the
            # two differ by a mean of 426 m in mesh space. A line draped on the
            # field floats above the terrain or is buried under it by that much,
            # and the `lift` below is a z-fighting nudge that assumed it was
            # sitting on the surface. Invisible from the overview camera, where
            # 426 m is sub-pixel; wrong at every closer view. Found when the
            # same defect was found in the scatter.
            #
            # FALLING BACK TO THE FIELD WHERE NO QUAD IS DRAWN, which is the
            # basin's ragged edge: `TerrainMesh.build` emits a quad only when
            # all four of its corners are valid, so a point over an incomplete
            # quad has no drawn surface to sit on. Dropping those would delete
            # the outermost reach and contour of the basin -- 132 vertices of
            # one test set -- to fix a case where nothing is drawn either way.
            # The field is where they were before and where they stay.
            var h := hf.height_at_world(wx, wy)
            if is_nan(h):
                continue          # off the valid heightfield; see dropped_offmap
            var y := tm.drawn_surface_y(Vector2(wx, wy), hf)
            if is_nan(y):
                y = h * tm.exaggeration
            # Through the mesh's own transform, not a second copy of it: this
            # method held a half-texel error for as long as it was written out
            # here as well as in `mesh_to_world`.
            var m := tm.world_to_mesh(Vector2(wx, wy), hf)
            pts.append(Vector3(m.x, y + lift, m.y))
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

        # the flow mesh: same segments, one surface, colour repainted per day
        var start := _flow_verts.size()
        for k in pts.size() - 1:
            _flow_verts.append(pts[k])
            _flow_verts.append(pts[k + 1])
        _reach_span.append(start)
        _reach_span.append(_flow_verts.size() - start)
        var node_id := str(r.get("node", ""))
        if node_id == "":
            reaches_without_node += 1
        _reach_node.append(node_id)

    for order in by_order:
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = by_order[order]
        var m := ArrayMesh.new()
        m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
        order_meshes[order] = m
    return order_meshes


## Repaint the flow mesh for one day. `flow_of_node` is looked up per reach;
## a reach with no node is drawn as NO_FLOW rather than skipped -- the channel
## exists on the ground whatever the fixture can say about it, and hiding it
## would make the map disagree with M1's.
func paint_flow(values: PackedFloat64Array, fl: FixtureLoader,
                disp: FlowDisplay) -> ArrayMesh:
    if _flow_verts.is_empty():
        return null
    disp.reset_counts()
    var colours := PackedColorArray()
    colours.resize(_flow_verts.size())
    for i in _reach_node.size():
        var node := _reach_node[i]
        var idx := -1 if node == "" else fl.node_index_of(node)
        var v := NAN
        if idx >= 0 and idx < values.size():
            v = values[idx]
        var col := disp.colour_for(v)
        var start := _reach_span[i * 2]
        var count := _reach_span[i * 2 + 1]
        for k in count:
            colours[start + k] = col
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = _flow_verts
    arrays[Mesh.ARRAY_COLOR] = colours
    flow_mesh = ArrayMesh.new()
    flow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
    return flow_mesh
