class_name ContourDrape
extends RefCounted

## Contour arcs draped onto the terrain surface. M4.
##
## DRAPED, NOT PROJECTED, along the path that already exists:
## `Heightfield.world_to_texel` then `height_at` for the height,
## `TerrainMesh.world_to_mesh` for the position, and FlowlineDrape's own lift
## constant rather than a second one. A contour and a reach are the same
## problem -- a polyline that must sit on a surface without z-fighting along
## its whole length -- and a second epsilon would be a second answer to it.
##
## A DROPPED VERTEX SPLITS THE ARC; IT DOES NOT BRIDGE. FlowlineDrape skips an
## off-map vertex and joins its neighbours, which for a reach is a shortcut
## along a channel that exists on the ground. Here the join would be a
## straight run of snowline across ground the heightfield cannot support --
## the same fabricated continuity decision 890 refuses at the divides,
## arriving through the drape instead of through the geometry. So a NAN ends
## the run, the next valid vertex starts a new one, and both counts are
## reported rather than absorbed.
##
## NO ARC IS EVER JOINED TO ANOTHER. Segments are emitted as vertex pairs into
## one LINES surface, so there is no strip whose restart could be forgotten:
## the only way two vertices are connected is if this file connected them.

var arcs_in: int = 0
var runs_out: int = 0
var segments: int = 0
var vertices_drawn: int = 0
var dropped_offmap: int = 0
var splits: int = 0
var arcs_lost: int = 0          ## arcs that left no run at all
var runs_too_short: int = 0     ## single-vertex runs, which draw nothing

var mesh: ArrayMesh = null


func build(arcs: Array, hf: Heightfield, tm: TerrainMesh) -> ArrayMesh:
    arcs_in = 0
    runs_out = 0
    segments = 0
    vertices_drawn = 0
    dropped_offmap = 0
    splits = 0
    arcs_lost = 0
    runs_too_short = 0

    var lift := FlowlineDrape.LIFT_FRACTION * hf.pixel_size_m
    var verts := PackedVector3Array()

    for arc in arcs:
        arcs_in += 1
        var run := PackedVector3Array()
        var runs_here := 0
        for w in arc:
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
            var h := hf.height_at_world(w.x, w.y)
            if is_nan(h):
                dropped_offmap += 1
                runs_here += _flush(run, verts)
                run = PackedVector3Array()
                continue
            var y := tm.drawn_surface_y(w, hf)
            if is_nan(y):
                y = h * tm.exaggeration
            var m := tm.world_to_mesh(w, hf)
            run.append(Vector3(m.x, y + lift, m.y))
        runs_here += _flush(run, verts)
        runs_out += runs_here
        if runs_here == 0:
            arcs_lost += 1
        elif runs_here > 1:
            splits += runs_here - 1

    vertices_drawn = verts.size()
    segments = verts.size() / 2
    mesh = ArrayMesh.new()
    if verts.size() >= 2:
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
    return mesh


## Emit one run as segment pairs. A run of a single vertex draws nothing --
## a one-point arc has no direction, and giving it a segment would mean
## inventing the other end.
func _flush(run: PackedVector3Array, verts: PackedVector3Array) -> int:
    if run.size() < 2:
        if run.size() == 1:
            runs_too_short += 1
        return 0
    for k in run.size() - 1:
        verts.append(run[k])
        verts.append(run[k + 1])
    return 1


func describe() -> Dictionary:
    return {
        "arcs": arcs_in,
        "runs": runs_out,
        "segments": segments,
        "dropped_offmap": dropped_offmap,
        "splits": splits,
        "arcs_lost": arcs_lost,
        "runs_too_short": runs_too_short,
        "gaps": ("a vertex off the valid heightfield ends its run; the next one starts "
                + "a new run. Nothing bridges a gap, here or at the divides."),
    }
