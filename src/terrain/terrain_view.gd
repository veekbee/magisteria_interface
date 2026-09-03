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

var residence: ResidenceLayer
var fixture: FixtureLoader
var overlay: FieldOverlay
var _terrain_mi: MeshInstance3D
var _terrain_mat: StandardMaterial3D
var _flow_mi: MeshInstance3D = null
var _flow_display: FlowDisplay = null
var field_report: Dictionary = {}


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
    _terrain_mi = mi
    _terrain_mat = mat

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


## M2: bind the residence layer and the fixture so fields can be shown.
## Returns what it bound, or why it could not -- the viewer stays usable
## without a fixture, which is what keeps M1's claim separable from M2's.
func bind_fields(terrain_dir: String = TERRAIN_DIR,
                 fixture_dir: String = "res://assets/fixture/") -> Dictionary:
    var rman := _read_json(terrain_dir + "residence_overview.json")
    if rman.is_empty():
        field_report = {"ok": false, "why": "no residence manifest"}
        return field_report
    residence = ResidenceLayer.load_from(rman, terrain_dir + "residence_overview.png")
    if not residence.is_loaded():
        field_report = {"ok": false, "why": "residence layer did not load"}
        return field_report
    if residence.width != heightfield.width or residence.height != heightfield.height:
        # Alignment is asserted rather than assumed. The two layers are built on
        # one transform on the server; if they ever disagree here, every lookup
        # is off by some pixels and nothing else would say so.
        field_report = {"ok": false, "why": "residence %dx%d != heightfield %dx%d"
                % [residence.width, residence.height, heightfield.width, heightfield.height]}
        return field_report

    fixture = FixtureLoader.load_from(fixture_dir)
    if not fixture.is_loaded():
        field_report = {"ok": false, "why": "fixture did not load"}
        return field_report

    overlay = FieldOverlay.new()
    overlay.bind(residence, fixture)
    field_report = {
        "ok": true,
        "resolved_px": overlay.resolved_px,
        "nodata_px": overlay.nodata_px,
        "cells": fixture.n_cells,
        "windows": Array(fixture.windows),
        "rows": Array(fixture.row_names(fixture.windows[0])),
        "refused": fixture.refused_rows,
    }
    return field_report


## Paint one row-day onto the terrain. Bounds come from the CONTRACT.
func show_field(window: String, row: String, day: int, group: int = 0) -> bool:
    if overlay == null or not overlay.is_bound():
        return false
    var b := _bounds_for(row)
    var vals := fixture.day_values(window, row, day, group)
    if vals.is_empty():
        return false
    _terrain_mat.albedo_texture = overlay.texture_for(vals, b.x, b.y)
    _terrain_mat.albedo_color = Color.WHITE
    return true


func clear_field() -> void:
    if _terrain_mat:
        _terrain_mat.albedo_texture = null
        _terrain_mat.albedo_color = Color(0.62, 0.60, 0.55)


## The ramp's range. `lo`/`hi` are the REALISED range the fixture quantised
## over; `contract_lo`/`contract_hi` is the declared validity range. Using the
## realised range is what makes a field visible at all -- burned fraction
## occupies about a ten-thousandth of its declared bounds (§23.837) -- at the
## cost of colours not being comparable between windows. Which should be the
## default is §25 backlog 168's, unruled; this shows the data and the legend
## says which range it used.
func _bounds_for(row: String) -> Vector2:
    for k in fixture.manifest.get("client_form", {}).get("rows", {}):
        var d: Dictionary = fixture.manifest["client_form"]["rows"][k]
        if str(d["row"]) == row:
            return Vector2(float(d["lo"]), float(d["hi"]))
    return Vector2(0.0, 1.0)


## M3: paint streamflow on the flowlines for one day, and report what the
## provisional display mapping did with it.
func show_flow(window: String, day: int) -> Dictionary:
    if drape == null or fixture == null:
        return {"ok": false, "why": "no drape or fixture"}
    var vals := fixture.day_values(window, "node.streamflow", day)
    if vals.is_empty():
        return {"ok": false, "why": "no streamflow for %s day %d" % [window, day]}
    if _flow_display == null:
        _flow_display = FlowDisplay.new()
    var m := drape.paint_flow(vals, fixture, _flow_display)
    if m == null:
        return {"ok": false, "why": "nothing to paint"}
    if _flow_mi == null:
        _flow_mi = MeshInstance3D.new()
        _flow_mi.name = "Flow"
        var fm := StandardMaterial3D.new()
        fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        fm.vertex_color_use_as_albedo = true
        _flow_mi.material_override = fm
        add_child(_flow_mi)
        # the static order-coloured lines are replaced by the flow-coloured
        # mesh: two sets of the same channels would be drawing the same rivers
        # twice and reading the colour two ways.
        for c in get_children():
            if String(c.name).begins_with("Flowlines_order_"):
                c.visible = false
    _flow_mi.mesh = m
    var d := _flow_display.describe()
    d["ok"] = true
    return d


## M3: does this fixture hold a drawable burn perimeter (decision 892)?
func burn_edge(window: String, day: int) -> Dictionary:
    if fixture == null:
        return {"has_edge": false, "verdict": "no fixture"}
    var be := BurnEdge.new()
    return be.measure(fixture.day_values(window, "band.burned_fraction", day))


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
