class_name TerrainView
extends Node3D

## M1: the terrain viewer. Assembles the heightfield, the mesh, the draped
## flowlines and the cameras, and reports what it built.
##
## It consumes the terrain export and NOTHING ELSE -- no schema, no fixture.
## That is the milestone's whole shape: the export has to stand on its own,
## and a viewer that quietly reached for another artefact would not prove it.
##
## HILLSHADE IS A LIGHT, NOT A TEXTURE. A DirectionalLight3D over per-vertex
## normals gives relief that responds to the camera and costs nothing; a baked
## shade map would be a second copy of the terrain, free to disagree with it.

const TERRAIN_DIR := "res://assets/terrain/"

@export var stride: int = 4
@export var exaggeration: float = 12.0   ## a 4 km relief over a 1,000 km basin

var heightfield: Heightfield
var terrain: TerrainMesh
var drape: FlowlineDrape
var rig: CameraRig
var report: Dictionary = {}


func build() -> Dictionary:
    var man := _read_json(TERRAIN_DIR + "terrain_export.json")
    if man.is_empty():
        report = {"ok": false, "why": "no terrain manifest"}
        return report

    heightfield = Heightfield.load_from(man, TERRAIN_DIR + "heightfield_overview.png")
    if not heightfield.is_loaded():
        report = {"ok": false, "why": "heightfield did not load"}
        return report

    terrain = TerrainMesh.new()
    var mesh := terrain.build(heightfield, stride, exaggeration)
    if mesh.get_surface_count() == 0:
        report = {"ok": false, "why": "terrain mesh has no surface"}
        return report

    var mi := MeshInstance3D.new()
    mi.name = "Terrain"
    mi.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.62, 0.60, 0.55)
    mat.roughness = 1.0
    mi.material_override = mat
    add_child(mi)

    var flow := _read_json(TERRAIN_DIR + "flowlines.json")
    drape = FlowlineDrape.new()
    var by_order := drape.build(flow.get("reaches", []), heightfield, terrain)
    for order in by_order:
        var fi := MeshInstance3D.new()
        fi.name = "Flowlines_order_%d" % order
        fi.mesh = by_order[order]
        var fm := StandardMaterial3D.new()
        fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        fm.vertex_color_use_as_albedo = false
        fm.albedo_color = Color(0.25, 0.55, 0.95)
        fi.material_override = fm
        add_child(fi)

    var sun := DirectionalLight3D.new()
    sun.name = "Hillshade"
    sun.rotation_degrees = Vector3(-45, 135, 0)   # NW, the cartographic default
    sun.light_energy = 1.1
    add_child(sun)

    rig = CameraRig.new()
    rig.name = "CameraRig"
    add_child(rig)
    rig.setup(mesh.get_aabb())

    report = {
        "ok": true,
        "vertices": terrain.vertex_count,
        "quads": terrain.quad_count,
        "skipped_quads": terrain.skipped_quads,
        "stride": stride,
        "exaggeration": exaggeration,
        "flowline_orders": by_order.keys().size(),
        "reaches_drawn": drape.reach_count,
        "reaches_offmap": drape.dropped_offmap,
        "aabb_m": [mesh.get_aabb().size.x, mesh.get_aabb().size.y, mesh.get_aabb().size.z],
        "lattice_geometry": 0,   # decision 890: there is none, and nothing adds any
    }
    return report


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
