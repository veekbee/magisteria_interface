extends SceneTree

## What a distance-banded density schedule costs, and what it looks like.
##
##     bash tools/measure_bands.sh
##
## WHY. Beyond a few hundred metres an individual plant is a fraction of a
## pixel and there are millions of it, so the far field has to become a
## collective representation of some kind. Choosing where that starts and how
## the two meet is a design question, and this is the measurement it needs:
## for a set of schedules, what each one costs a frame, how long it takes to
## build, and how much of the screen the vegetation still covers.
##
## COVERAGE IS THE ONE THAT DECIDES THE FADE. If drawing a quarter of a stand
## covers nearly as much screen as drawing all of it, the plants are already
## overlapping and thinning is close to free to look at. If coverage falls with
## density, every step of a fade is visible and the schedule has to be gentle.
## Nothing in the cost model can answer that; only pixels can.
##
## THE CAMERA IS THE MEASUREMENT, and the app's is the wrong one for this
## question. `focus_on_scatter` frames the whole 1,500 m disc from 2,600 m up,
## which is a map view: at that distance a hundred-metre band is a spot in the
## middle of the frame, and coverage measured there says more about the framing
## than about the schedule. A band scheme is for a viewer standing IN the
## scatter, so this puts the camera there -- `--camera eye`, the default -- and
## keeps `--camera overview` for comparison.
##
## EYE HEIGHT IS REAL HEIGHT. The scale is 1:1 in every view, so a 1.7 m eye is
## 1.7 m in mesh space and stands in the right relation to a 2.1 m tree without
## any correction. The multiplication by `terrain.exaggeration` is kept where a
## height becomes a distance, so that a factor reintroduced anywhere would reach
## these numbers rather than silently miss them; it is 1.0 and this file's
## distances are the field's own. What that removes is the caveat this harness
## used to carry -- that a plant subtended about twelve times the angle it would
## in the field, and so every band distance tuned by eye was tuned against that.
##
## IT REFUSES HEADLESS, for the reason everything that times or photographs a
## frame in this repo refuses.

const SETTLE_FRAMES := 12
const WARMUP_FRAMES := 20
const MEASURE_FRAMES := 60

## Written near-to-far. The first four are hard cuts, which isolate the cost of
## a radius from the cost of a fade; the last two are fades, one of them the
## shape a band scheme was sketched as.
const SCHEDULES: Array = [
    {"name": "today", "bands": []},
    {"name": "cut at 100 m", "bands": [{"to_m": 100.0, "keep": 1.0}]},
    {"name": "cut at 200 m", "bands": [{"to_m": 200.0, "keep": 1.0}]},
    {"name": "cut at 300 m", "bands": [{"to_m": 300.0, "keep": 1.0}]},
    {"name": "fade 1/.75/.5/.25 to 300 m", "bands": [
        {"to_m": 100.0, "keep": 1.0}, {"to_m": 150.0, "keep": 0.75},
        {"to_m": 200.0, "keep": 0.5}, {"to_m": 300.0, "keep": 0.25}]},
    {"name": "fade 1/.5/.15/.05 to 1500 m", "bands": [
        {"to_m": 150.0, "keep": 1.0}, {"to_m": 400.0, "keep": 0.5},
        {"to_m": 800.0, "keep": 0.15}, {"to_m": 1500.0, "keep": 0.05}]},
]

## Eye height in real metres; the mesh multiplies it by the exaggeration.
const EYE_HEIGHT_M := 1.7

## Distances the screen-size table is reported at.
const RANGES: Array = [25.0, 50.0, 100.0, 150.0, 200.0, 300.0, 500.0, 1000.0, 1500.0]

enum { SETTLE, PLACE, BASE_WARMUP, BASE, BUILD, WARMUP, MEASURE, COVER, WRITE }

var scene: Node = null
var view = null
var stage := SETTLE
var frames := 0
var at_world := Vector2.ZERO
var window_name := ""
var row_name := "band.pft.biomass"
var day := 22
var out_path := "measurements/scatter_bands.json"
var ceiling := 1500000
var camera_mode := "eye"

var _wall := PackedFloat64Array()
var _drawn_at_start := 0
var baseline := {}
var at := 0
var results: Array = []
var _current: Dictionary = {}


func _initialize() -> void:
    if DisplayServer.get_name() == "headless":
        printerr("measure_bands: the display server is 'headless', which draws nothing and "
                + "reports frame times for work that never happened.")
        quit(2)
        return
    out_path = _arg("--out", out_path)
    window_name = _arg("--window", "")
    row_name = _arg("--row", row_name)
    day = int(_arg("--day", str(day)))
    ceiling = int(_arg("--ceiling", str(ceiling)))
    camera_mode = _arg("--camera", camera_mode)
    var a := _arg("--at", "")
    if a != "":
        var p := a.split(",")
        at_world = Vector2(float(p[0]), float(p[1]))
    var size := _arg("--size", "1280x800").split("x")
    DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
    DisplayServer.window_move_to_foreground()
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    get_root().add_child(scene)


func _process(delta: float) -> bool:
    frames += 1
    if view == null:
        view = scene.get_node("TerrainView")
    match stage:
        SETTLE:
            if frames >= SETTLE_FRAMES:
                _place()
        PLACE:
            pass
        BASE_WARMUP:
            if frames >= WARMUP_FRAMES:
                _start()
        BASE:
            _wall.append(delta * 1000.0)
            if _wall.size() >= MEASURE_FRAMES:
                baseline = _stop()
                _next_schedule()
        BUILD:
            pass
        WARMUP:
            if frames >= WARMUP_FRAMES:
                _start()
        MEASURE:
            _wall.append(delta * 1000.0)
            if _wall.size() >= MEASURE_FRAMES:
                _current["frame_ms"] = _stop()
                _isolate(true)
                frames = 0
                stage = COVER
        COVER:
            if frames >= 8:
                _cover()
        WRITE:
            _write()
            return true
    return false


func _place() -> void:
    stage = PLACE
    var w: String = window_name if window_name != "" else str(view.fixture.windows[0])
    var set_to: Dictionary = scene.scrubber.select(w, row_name, day)
    if not bool(set_to["ok"]):
        printerr("measure_bands: %s" % str(set_to["why"]))
        quit(2)
        return
    window_name = w
    var probe: Dictionary
    if at_world != Vector2.ZERO:
        probe = view.probe_world(at_world.x, at_world.y)
    else:
        probe = view.probe_at_screen(get_root().get_camera_3d(),
                get_root().get_visible_rect().size * 0.5)
    if not probe.has("world"):
        printerr("measure_bands: the probe did not resolve to ground")
        quit(2)
        return
    at_world = probe["world"]
    scene._on_probed(probe)
    _aim_camera()
    _hide_scatter(true)
    frames = 0
    stage = BASE_WARMUP


## Stand in the scatter and look out along the ground, or float above it.
func _aim_camera() -> void:
    view.focus_on_scatter()
    if camera_mode != "eye":
        return
    var cam = view.rig.fly
    var c: Vector3 = view.scatter_centre_mesh
    var lift := float(_arg("--lift", "0"))
    # Ten degrees down: the ground from about thirty metres out to the horizon
    # is in one frame, which is where a band boundary would show if it showed.
    var pitch := float(_arg("--pitch", "10"))
    # ABOVE THE MESH, NOT ABOVE THE HEIGHTFIELD, and the gap between those two
    # is the whole reason a true eye-level view is not available here. The
    # terrain mesh samples the 1,000 m heightfield with stride 4, so its
    # triangles are 4 km across: the camera sits in the middle of one, and a
    # point 1.7 m above the FIELD is routinely underneath the drawn SURFACE,
    # which back-face culling then renders as an empty frame.
    # ABOVE THE DRAWN SURFACE, not above the field. The mesh triangulates
    # samples 4 km apart and the two differ by a mean of 36 m, so
    # an eye placed on the field is underground -- which renders as an empty
    # frame or as a view out from under a slab with no near ground in it. Every
    # coverage row this tool took before `drawn_surface_y` existed was taken
    # from one of those two places.
    var surface: float = view.terrain.drawn_surface_y(at_world, view.heightfield)
    var ground: float = c.y if is_nan(surface) else surface
    var eye := Vector3(c.x, ground + EYE_HEIGHT_M * view.terrain.exaggeration + lift, c.z)
    # near/far is left as `focus_on` set it. Pulling near down to 0.1 against a
    # far plane of 5.9e6 -- the basin's own extent, four times over -- is a
    # ratio of 6e7, and the compatibility renderer draws NOTHING at all through
    # that projection: an empty frame at every camera height tried, which reads
    # exactly like a scatter that failed to build.
    cam.far = maxf(4.0 * TerrainView.SCATTER_HORIZON_M, lift * 4.0)
    cam.position = eye
    # Level, looking north (-Z in mesh space), which is the direction the
    # horizon question is about: everything from underfoot to the far band is
    # in the frame at once, which is exactly where a seam would show.
    cam.look_at_from_position(eye, eye + Vector3(0.0, -tan(deg_to_rad(pitch)), -1.0), Vector3.UP)


func _next_schedule() -> void:
    if at >= SCHEDULES.size():
        stage = WRITE
        return
    var sched: Dictionary = SCHEDULES[at]
    _isolate(false)
    # Today's row uses the shipped ceiling; every other schedule is given room
    # so that what binds is the SCHEDULE and not the builder. Which bound is
    # reported either way -- a row thinned by the ceiling is a measurement of
    # the ceiling wearing a schedule's name.
    var use_ceiling: int = (VegetationScatter.MAX_BUILT_INSTANCES
            if str(sched["name"]) == "today" else ceiling)
    var r: Dictionary = view.scatter_at(at_world, TerrainView.SCATTER_HORIZON_M,
            sched["bands"], use_ceiling)
    _current = {"name": sched["name"], "bands": sched["bands"], "scatter": r}
    if not bool(r.get("ok", false)):
        results.append(_current)
        at += 1
        _next_schedule()
        return
    _hide_scatter(false)
    frames = 0
    stage = WARMUP


func _start() -> void:
    _wall.clear()
    _drawn_at_start = Engine.get_frames_drawn()
    stage = BASE if stage == BASE_WARMUP else MEASURE


func _stop() -> Dictionary:
    var s := FrameStats.summarise(_wall)
    s["frames_drawn"] = Engine.get_frames_drawn() - _drawn_at_start
    s["frames_timed"] = _wall.size()
    return s


## Everything but the plants, so a coverage count is a count of plants.
func _isolate(on: bool) -> void:
    view.get_node("Terrain").visible = not on
    for c in view.get_children():
        if String(c.name).begins_with("Flow") or String(c.name) == "Contours":
            c.visible = not on
    scene.get_node("UI").visible = not on


func _hide_scatter(hidden: bool) -> void:
    for c in view.get_children():
        if String(c.name).begins_with("Vegetation"):
            c.visible = not hidden


func _cover() -> void:
    var img := get_root().get_texture().get_image()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/bands"))
    img.save_png("res://shots/bands/%s.png" % str(_current["name"]).replace(" ", "_").replace("/", "-"))
    var su := FrameProbe.summarise(img)
    _current["coverage"] = {
        "pixels": int(su["coloured"]),
        "fraction_of_frame": float(su["coloured_fraction"]),
        "mean_colour": su["mean_coloured"],
        "green_minus_red": float(su["green_minus_red"]),
    }
    results.append(_current)
    _say(_current)
    at += 1
    _next_schedule()


## How big one plant is on screen, as a function of how far away it is.
##
## THIS IS WHERE "INDIVIDUAL" STOPS MEANING ANYTHING. Below about a pixel, what
## a viewer reads is the aggregate however many instances are drawn, and the
## only thing more instances buy is cost.
##
## Drawn size IS true size at 1:1, so `drawn_height_m` and `height_m` agree and
## a band boundary chosen from real-world intuition is the boundary this table
## measures. The two columns are kept apart anyway, because they answer
## different questions and a factor reintroduced later would separate them again.
func _screen_table() -> Array:
    var out: Array = []
    var cam = view.rig.fly
    var height_px := float(get_root().get_visible_rect().size.y)
    var exaggeration: float = view.terrain.exaggeration
    var form: Dictionary = view.scatter.report.get("form", {})
    for life_form in form:
        var f: Dictionary = form[life_form]
        var h := float(f["height_max_m"])
        var row := {"life_form": life_form, "height_m": h,
                    "drawn_height_m": h * exaggeration,
                    "crown_m": float(f["crown_max_m"]), "pixels_at": {}}
        for d in RANGES:
            var across := 2.0 * float(d) * tan(deg_to_rad(0.5 * cam.fov))
            row["pixels_at"][str(int(d))] = h * exaggeration * height_px / across
        out.append(row)
    return out


func _say(r: Dictionary) -> void:
    var sc: Dictionary = r["scatter"]
    var total := 0
    for g in sc.get("placed", {}):
        total += int(sc["placed"][g])
    var fm: Dictionary = r.get("frame_ms", {})
    var cov: Dictionary = r.get("coverage", {})
    print("%-28s %9d inst  build %7.0f ms  frame p50 %6.2f ms  marginal %6.2f  cover %6d px  bound by %s"
            % [str(r["name"]), total, float(sc.get("build_ms", NAN)),
               float(fm.get("p50", NAN)), float(fm.get("p50", NAN)) - float(baseline["p50"]),
               int(cov.get("pixels", 0)), str(sc.get("share_bound_by", "?"))])


func _write() -> void:
    var doc := {
        "what": ("what a distance-banded density schedule costs and covers, for choosing "
                + "where individual instances stop and a collective representation starts"),
        "measured_at_commit": _git_head(),
        "measured_at_commit_means": ("the HEAD the run was taken against; the commit that "
                + "lands this artefact is its child"),
        # 1:1, and stated anyway because the rule that a measurement names the
        # exaggeration its distances were taken at outlived the exaggeration
        # itself -- which is the point of the rule.
        # `test_a_recorded_distance_names_what_it_is_conditional_on` fails if a
        # measurement carrying metres does not carry this field.
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "host": {
            "gpu": RenderingServer.get_video_adapter_name(),
            "rendering_method": RenderingServer.get_current_rendering_method(),
            "godot": Engine.get_version_info()["string"],
            "viewport": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
            "fov_degrees": view.rig.fly.fov,
            "vsync": "disabled",
        },
        "scene": {
            "window": window_name, "row": row_name, "day": day,
            "at_world_epsg5070": [at_world.x, at_world.y],
            "horizon_m": TerrainView.SCATTER_HORIZON_M,
            "measurement_ceiling": ceiling,
            "shipped_ceiling": VegetationScatter.MAX_BUILT_INSTANCES,
            "camera": camera_mode,
            "camera_note": ("eye = standing in the scatter at %.1f m, which at x%.0f "
                    + "exaggeration is %.1f m in mesh space, looking level to the north; "
                    + "overview = the app's focus_on_scatter, which frames the whole horizon "
                    + "from above")
                    % [EYE_HEIGHT_M, view.terrain.exaggeration,
                            EYE_HEIGHT_M * view.terrain.exaggeration],
            "eye_height_m": EYE_HEIGHT_M,
            "eye_pitch_degrees": float(_arg("--pitch", "10")),
            "eye_lift_m": float(_arg("--lift", "0")),
            "terrain_mesh_triangle_m": view.terrain.stride * view.heightfield.pixel_size_m,
            "heightfield_texel_m": view.heightfield.pixel_size_m,
        },
        "method": {
            "warmup_frames": WARMUP_FRAMES,
            "measured_frames": MEASURE_FRAMES,
            "marginal": ("each schedule's frame time minus the same scene with the scatter "
                    + "hidden, which is the only way to get the scatter's own cost out of "
                    + "a frame that also draws a terrain"),
            "coverage": ("counted with the terrain, flowlines, contours and UI hidden, so a "
                    + "coloured pixel is a plant"),
        },
        "without_scatter": baseline,
        "schedules": results,
        "one_plant_on_screen": _screen_table(),
        "not_covered": ("one machine, one place, one day, one camera distance and one FOV. "
                + "Density is a property of the place -- see scatter_cost.json -- so the "
                + "instance counts here do not transfer to another part of the basin."),
    }
    var f := FileAccess.open(out_path, FileAccess.WRITE)
    f.store_string(JSON.stringify(doc, "  ") + "\n")
    f.close()
    print("")
    for row in doc["one_plant_on_screen"]:
        var px: Dictionary = row["pixels_at"]
        print("%-10s %5.2f m tall (drawn %5.1f m):  " % [str(row["life_form"]),
                float(row["height_m"]), float(row["drawn_height_m"])]
                + "  ".join(PackedStringArray(RANGES.map(func(d):
                        return "%sm %6.2f px" % [str(int(d)), float(px[str(int(d))])]))))
    print("-> %s" % out_path)
    quit(0)


func _git_head() -> String:
    var out := []
    if OS.execute("git", ["rev-parse", "--short", "HEAD"], out, false) != 0 or out.is_empty():
        return "unknown"
    return String(out[0]).strip_edges()


func _arg(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == name and i + 1 < args.size():
            return args[i + 1]
    return fallback
