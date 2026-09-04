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
## Checkable by moving it: `tools/screenshot.sh --sun 135,-45` turns the light
## between two frames, and 18% of the frame differs -- which a texture could
## not do.

## M4: a click resolved to a residence key. Emitted by this node because it is
## the one that holds the cameras, the heightfield and the row currently
## painted -- a probe assembled anywhere else would need a second copy of all
## three and could disagree with what is on screen.
signal probed(result: Dictionary)

const TERRAIN_DIR := "res://assets/terrain/"

## The march samples the surface every half heightfield pixel. Coarser steps
## walk over ridges at a grazing angle and report the ground behind them.
const PROBE_STEP_FRACTION := 0.5
const PROBE_REFINEMENTS := 24

## M5 scatters within a horizon rather than over the basin. A cell here is
## about 126 km2 and there are 5,684 of them, so "scatter the fixture" is not
## a thing any frame contains. 1,500 m is the largest of §19.8.4's example
## horizons, and the cost of it is reported rather than assumed.
const SCATTER_HORIZON_M := 1500.0

const VEGETATION_SHADER := "res://src/fixture/vegetation.gdshader"

## The terrain with no field on it. It is also what a nodata texel is painted
## with, so "no measurement here" reads as bare ground rather than as a colour
## -- which is why the two live on one constant instead of two.
const BARE_ALBEDO := Color(0.62, 0.60, 0.55)

## Sun azimuth in mesh degrees. The mesh is +X east, +Z south, so a light at
## 225 travels south-east and therefore arrives FROM THE NORTH-WEST, which is
## the cartographic default and the direction relief inversion does not happen
## in.
##
## IT WAS 135 UNTIL THE VISUAL AUDIT, and 135 lights the basin from the
## NORTH-EAST while the comment beside it said north-west. Nothing in a blind
## suite could catch that: the light was on, the surface was shaded, every
## number was right, and the shading was simply coming from the wrong side.
## `test_the_hillshade_comes_from_the_north_west` now pins it as a vector.
const SUN_AZIMUTH_DEGREES := 225.0
const SUN_ALTITUDE_DEGREES := -45.0

## A fill so that a slope facing away from the sun still shows its albedo.
##
## WITHOUT IT A SHADOWED SLOPE IS PURE BLACK, and black is not a spare colour
## here: it sits next to this ramp's low end, so 738 pixels of a 1,024,000-pixel
## frame were reading as the lowest value in the field rather than as ground
## the light did not reach. Measured before and after at 0.15: 738 near-black
## pixels -> 1, with the relief spread WIDER rather than flatter (0.195 ->
## 0.219), because those pixels now carry their field colour instead of none.
const AMBIENT_ENERGY := 0.15

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

var probe: CellProbe = null
## What `show_field` last painted. The probe reads the row that is DRAWN
## rather than one it was told about separately, so the number in the readout
## and the colour under the cursor cannot come from different rows.
var shown: Dictionary = {}

var families: FamilySet = null
var frame_cost: FrameCost = null
var scatter: VegetationScatter = null
var _scatter_nodes: Dictionary = {}      ## life_form -> MultiMeshInstance3D
var scatter_centre_mesh := Vector3.ZERO
var has_scatter := false

var contour_sets: Dictionary = {}        ## window -> ContourSet
var contour_drape: ContourDrape = null
var _contour_mi: MeshInstance3D = null


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
    mat.albedo_color = BARE_ALBEDO
    mat.roughness = 1.0
    # NO SPECULAR. A hillshade is a diffuse relief model; a specular term adds
    # WHITE in proportion to nothing in the data, and white is the one thing
    # this ramp cannot afford -- viridis was chosen because its lightness rises
    # monotonically, and a highlight washing a colour toward white moves it off
    # the ramp entirely. Measured: 43.5% of the overlay's pixels lay on the
    # declared ramp with the default specular, and 99.8% with it off.
    mat.metallic_specular = 0.0
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
    sun.rotation_degrees = Vector3(SUN_ALTITUDE_DEGREES, SUN_AZIMUTH_DEGREES, 0)
    sun.light_energy = 1.1
    add_child(sun)

    # The ambient fill. A WorldEnvironment rather than a second light: a fill
    # light from the opposite side would flatten the relief the first one is
    # there to show, while ambient lifts the floor without touching the shape.
    var env := WorldEnvironment.new()
    env.name = "Ambient"
    var e := Environment.new()
    e.background_mode = Environment.BG_CLEAR_COLOR
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(1, 1, 1)
    e.ambient_light_energy = AMBIENT_ENERGY
    env.environment = e
    add_child(env)

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
    overlay.bind(residence, fixture, BARE_ALBEDO)
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
    shown = {"window": window, "row": row, "day": day, "group": group}
    return true


func clear_field() -> void:
    if _terrain_mat:
        _terrain_mat.albedo_texture = null
        _terrain_mat.albedo_color = BARE_ALBEDO


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


## M4: the world position on the terrain surface under a camera ray.
##
## MARCHED, NOT COLLIDED. A collision shape for this mesh would be a second
## copy of the terrain in the scene, free to drift from the drawn one, and the
## drift would surface as a probe answering confidently about a surface nobody
## can see. The march samples the SAME heightfield the mesh was built from, so
## a hit is a point on the drawn surface by construction rather than by
## agreement between two things.
##
## A NAN sample is not a miss and not a floor: the ray is over one of the
## basin's holes there, and the march carries on past it. Treating NAN as
## height zero would put a lake-level plateau across every hole and stop the
## ray on it.
func world_under_ray(origin: Vector3, dir: Vector3) -> Dictionary:
    if heightfield == null or terrain == null:
        return {"hit": false, "why": "no terrain to march against"}
    var d := dir.normalized()
    var aabb: AABB = _terrain_mi.mesh.get_aabb()
    var reach: float = (maxf(aabb.size.x, aabb.size.z) + origin.distance_to(aabb.get_center())) * 2.0
    var step := PROBE_STEP_FRACTION * heightfield.pixel_size_m
    var t := 0.0
    var last_above := -1.0
    while t < reach:
        var p := origin + d * t
        var h := _surface_y(p)
        if not is_nan(h):
            if p.y <= h:
                if last_above < 0.0:
                    return {"hit": false,
                            "why": "the ray starts under the surface -- nothing above to march"}
                return _refine(origin, d, last_above, t)
            last_above = t
        t += step
    return {"hit": false, "why": "the ray leaves the basin without meeting the surface"}


## Bisection between a t known above the surface and a t known below it.
## Halving is bounded and exact enough at 24 steps -- 1e6 m of reach becomes
## 0.06 m, well under the metre the arcs themselves are rounded to.
func _refine(origin: Vector3, d: Vector3, above: float, below: float) -> Dictionary:
    for _i in PROBE_REFINEMENTS:
        var mid := 0.5 * (above + below)
        var p := origin + d * mid
        var h := _surface_y(p)
        if is_nan(h) or p.y > h:
            above = mid
        else:
            below = mid
    var hit := origin + d * below
    return {"hit": true, "mesh": hit, "world": terrain.mesh_to_world(hit, heightfield),
            "t": below}


func _surface_y(p: Vector3) -> float:
    var w := terrain.mesh_to_world(p, heightfield)
    var h := heightfield.height_at_world(w.x, w.y)
    return NAN if is_nan(h) else h * terrain.exaggeration


## M4: what a world position resolves to, read against the row now painted.
func probe_world(wx: float, wy: float) -> Dictionary:
    if probe == null:
        probe = CellProbe.new()
        probe.bind(heightfield, residence, fixture)
    var vals := PackedFloat64Array()
    if not shown.is_empty() and fixture != null:
        vals = fixture.day_values(shown["window"], shown["row"], shown["day"], shown["group"])
    var r := probe.at_world(wx, wy, vals)
    r.merge(shown)
    return r


## M4: a screen point, through the camera that is current, to a probe result.
func probe_at_screen(cam: Camera3D, screen: Vector2) -> Dictionary:
    if cam == null:
        return {"state": CellProbe.NO_GROUND, "why": "no camera is current"}
    var hit := world_under_ray(cam.project_ray_origin(screen), cam.project_ray_normal(screen))
    if not bool(hit.get("hit", false)):
        var r := {"state": CellProbe.NO_GROUND, "why": str(hit.get("why", "no hit"))}
        r.merge(shown)
        return r
    var w: Vector2 = hit["world"]
    return probe_world(w.x, w.y)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed \
            and event.button_index == MOUSE_BUTTON_LEFT:
        if overlay == null:
            return
        probed.emit(probe_at_screen(get_viewport().get_camera_3d(), event.position))
    elif event is InputEventKey and event.pressed and not event.echo \
            and event.keycode == KEY_G:
        focus_on_scatter()


## M4: load whatever contour sets are vendored, and say which windows have
## one. A window without a set is not a failure -- extraction is per window and
## server-side -- so this reports rather than refuses.
func bind_contours(dir_path: String = ContourSet.DIR) -> Dictionary:
    contour_sets = ContourSet.discover(dir_path)
    var sets := []
    for w in contour_sets:
        sets.append((contour_sets[w] as ContourSet).describe())
    return {
        "ok": not contour_sets.is_empty(),
        "windows": contour_sets.keys(),
        "sets": sets,
        "why": "" if not contour_sets.is_empty() else "no contour set is vendored",
    }


## M4: draw one day's arcs, draped.
##
## THE DAY COMES FROM THE CALLER, which is the scrubber (FieldScrubber owns the
## clock). A layer holding its own day would drift against the field under it
## and show a snowline from one day over a snowpack from another, which is the
## kind of wrongness a viewer reads as physics rather than as a bug.
func show_contours(window: String, day: int) -> Dictionary:
    var cs: ContourSet = contour_sets.get(window, null)
    if _contour_mi != null:
        _contour_mi.visible = cs != null
    if cs == null:
        return {"ok": false, "window": window,
                "why": "no contour set is vendored for %s" % window}
    if heightfield == null or terrain == null:
        return {"ok": false, "why": "no terrain to drape onto"}
    contour_drape = ContourDrape.new()
    var m := contour_drape.build(cs.arcs_for_day(day), heightfield, terrain)
    if _contour_mi == null:
        _contour_mi = MeshInstance3D.new()
        _contour_mi.name = "Contours"
        var cm := StandardMaterial3D.new()
        cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        cm.albedo_color = Color(0.97, 0.99, 1.0)
        _contour_mi.material_override = cm
        add_child(_contour_mi)
    _contour_mi.mesh = m
    var out := contour_drape.describe()
    out["ok"] = m.get_surface_count() > 0
    out["window"] = window
    out["day"] = day
    out["standing"] = cs.standing(day)
    return out


## M5: bind the form archetypes and the frame-cost measurement they are
## priced against. Neither is required for the viewer to run, so both report
## rather than refuse -- the terrain and the fields stand without them.
func bind_families() -> Dictionary:
    families = FamilySet.load_from()
    frame_cost = FrameCost.load_from("multimesh")
    if not families.is_loaded():
        return {"ok": false, "why": families.why_absent}
    var groups := PackedStringArray()
    if fixture != null and fixture.windows.size() > 0:
        groups = fixture.taxon_groups(fixture.windows[0], "band.pft_fractions")
    scatter = VegetationScatter.new()
    scatter.bind(heightfield, residence, fixture, families, frame_cost, terrain)
    return {
        "ok": true,
        "families": Array(families.life_forms()),
        "wire_groups": Array(groups),
        "missing": Array(families.missing_for(groups)),
        "absent_by_ruling": families.not_here(),
        "cost_model": ("" if frame_cost.is_loaded()
                else "no frame-cost measurement: " + frame_cost.why_absent),
    }


## M5: scatter vegetation within the horizon of a world position, for the day
## the terrain is painted with.
##
## THE DAY IS THE SCRUBBER'S, through `shown`. A scatter holding its own day
## would put winter's canopy over summer's ground.
func scatter_at(centre: Vector2, radius_m: float = SCATTER_HORIZON_M,
                bands: Array = VegetationScatter.NO_SCHEDULE,
                ceiling: int = VegetationScatter.MAX_BUILT_INSTANCES) -> Dictionary:
    if scatter == null or not scatter.is_bound():
        return {"ok": false, "why": "no vegetation scatter is bound"}
    if shown.is_empty():
        return {"ok": false, "why": "no row is painted, so there is no day to scatter"}
    var r := scatter.build(str(shown["window"]), int(shown["day"]), centre, radius_m,
            bands, ceiling)
    if not bool(r.get("ok", false)):
        return r
    for life_form in scatter.meshes:
        var node: MultiMeshInstance3D = _scatter_nodes.get(life_form, null)
        if node == null:
            node = MultiMeshInstance3D.new()
            node.name = "Vegetation_%s" % life_form
            # The tint is a shader, not an albedo. Vertex colour carries the
            # authored phenology MASK and the MultiMesh's custom data carries
            # the value computed from the wire; a StandardMaterial3D can only
            # read the first, and reading it as a colour would paint every
            # plant by its own mask.
            var mat := ShaderMaterial.new()
            mat.shader = load(VEGETATION_SHADER)
            node.material_override = mat
            add_child(node)
            _scatter_nodes[life_form] = node
        node.multimesh = scatter.meshes[life_form]
        node.visible = true
    for life_form in _scatter_nodes:
        if not scatter.meshes.has(life_form):
            (_scatter_nodes[life_form] as MultiMeshInstance3D).visible = false

    # Where it stands, and how big it is on screen right now. The second number
    # is the one that explains an empty-looking window: at the overview camera
    # the whole scatter is about a pixel, and a viewer has no way to know that
    # from looking.
    var h := heightfield.height_at_world(centre.x, centre.y)
    var m := terrain.world_to_mesh(centre, heightfield)
    scatter_centre_mesh = Vector3(m.x, (0.0 if is_nan(h) else h) * terrain.exaggeration, m.y)
    has_scatter = true
    r["on_screen_px"] = _on_screen_px(radius_m * 2.0)
    r["focus_key"] = "G"
    return r


## How many pixels across a span of `metres` is under the current camera.
func _on_screen_px(metres: float) -> float:
    if rig == null or get_viewport() == null:
        return NAN
    var height_px := get_viewport().get_visible_rect().size.y
    if height_px <= 0.0:
        return NAN
    if rig.using_ortho() and rig.ortho != null:
        return metres / (rig.ortho.size / height_px)
    if rig.fly == null:
        return NAN
    var d := rig.fly.global_position.distance_to(scatter_centre_mesh)
    if d <= 0.0:
        return NAN
    return metres / (2.0 * d * tan(deg_to_rad(0.5 * rig.fly.fov)) / height_px)


## Take the camera to the last scatter, on the fly camera.
func focus_on_scatter() -> bool:
    if not has_scatter or rig == null:
        return false
    rig.focus_on(scatter_centre_mesh, SCATTER_HORIZON_M)
    return true


func clear_scatter() -> void:
    for life_form in _scatter_nodes:
        (_scatter_nodes[life_form] as MultiMeshInstance3D).visible = false


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
