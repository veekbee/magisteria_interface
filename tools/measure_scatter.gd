extends SceneTree

## Measure what M5's scatter costs a frame, in the viewer that draws it.
##
##     bash tools/measure_scatter.sh
##
## WHY. `measurements/render_cost.json` prices instancing on an empty stage,
## and M5's budget sentences are predictions from that coefficient rather than
## observations of a frame -- including the 1,500 m horizon figure, which the
## scatter reported at runtime and which was committed nowhere. This writes the
## derivation down and checks it against the frame it describes.
##
## IT REFUSES HEADLESS, for the reason the benchmark and the capture refuse:
## `--headless` draws nothing and reports frame times for work that never
## happened, and those numbers look exactly like a very fast GPU.
##
## IT TIMES THE SAME SCENE TWICE, once with the scatter hidden and once with it
## drawn, and the cost is the difference. One timing of the viewer is the
## terrain, the flowlines, the contours, the overlay and the scatter added
## together, and no arithmetic recovers one term of that sum.

const SETTLE_FRAMES := 12

enum { SETTLE, PLACE, REFRAME, BASELINE_WARMUP, BASELINE, SCATTER_WARMUP, SCATTER,
        VERIFY, WRITE }

var scene: Node = null
var view = null
var stage := SETTLE
var frames := 0
var attempt := 1

var out_path := "measurements/scatter_cost.json"
var window_name := ""
var row_name := "band.pft.biomass"
var day := 22
var at_world := Vector2.ZERO
var have_at := false

var _wall := PackedFloat64Array()
var _prims := PackedFloat64Array()
var _draws := PackedFloat64Array()
var _frames_drawn_at_start := 0
var baseline := {}
var scatter := {}
var _img_without: Image = null
var _img_with: Image = null
## What each family contributes on its own, with every other layer hidden.
var per_family: Array = []
var _verify_at := 0
var scatter_report: Dictionary = {}
var probe_state := ""


func _initialize() -> void:
    if DisplayServer.get_name() == "headless":
        printerr("measure_scatter: the display server is 'headless', which draws nothing and "
                + "reports frame times for work that never happened. Run through "
                + "tools/measure_scatter.sh, which does not pass --headless.")
        quit(2)
        return
    out_path = _arg("--out", out_path)
    window_name = _arg("--window", "")
    row_name = _arg("--row", row_name)
    day = int(_arg("--day", str(day)))
    var at := _arg("--at", "")
    if at != "":
        var parts := at.split(",")
        at_world = Vector2(float(parts[0]), float(parts[1]))
        have_at = true

    var size := _arg("--size", "1280x800").split("x")
    DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
    # The same three things the benchmark needs: a window that is actually
    # drawn, no vsync, and no frame cap. With vsync on every frame reads 16.7 ms
    # and this would be measuring the display's refresh rate.
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
            return false
        PLACE:
            return false
        REFRAME:
            if frames >= SETTLE_FRAMES:
                _hide_scatter(true)
                _begin_measure(BASELINE_WARMUP)
            return false
        BASELINE_WARMUP:
            if frames >= ScatterCost.WARMUP_FRAMES:
                _start_sampling(BASELINE)
            return false
        BASELINE:
            _sample(delta)
            if _wall.size() >= ScatterCost.MEASURE_FRAMES:
                baseline = _finish()
                _img_without = get_root().get_texture().get_image()
                _hide_scatter(false)
                _begin_measure(SCATTER_WARMUP)
            return false
        SCATTER_WARMUP:
            if frames >= ScatterCost.WARMUP_FRAMES:
                _start_sampling(SCATTER)
            return false
        SCATTER:
            _sample(delta)
            if _wall.size() >= ScatterCost.MEASURE_FRAMES:
                scatter = _finish()
                _img_with = get_root().get_texture().get_image()
                _begin_verify()
            return false
        VERIFY:
            if frames >= 8:
                _record_family()
            return false
    return true


## Each family alone, with every other layer hidden.
##
## THIS IS WHERE THE PRIMITIVE COUNTER GETS CAUGHT. It is the check the
## benchmark relies on, it is wrong for two of these three multimeshes, and
## the way to say so in an artefact is to record what it reported for each
## family beside how many pixels that family actually put on screen. A note
## saying "the counter is unreliable" is an opinion; the two columns are the
## evidence for it.
func _begin_verify() -> void:
    view.get_node("Terrain").visible = false
    for c in view.get_children():
        if String(c.name).begins_with("Flow") or String(c.name) == "Contours":
            c.visible = false
    scene.get_node("UI").visible = false
    _verify_at = 0
    _next_family()


func _families() -> Array:
    var out: Array = []
    for c in view.get_children():
        if String(c.name).begins_with("Vegetation") and c.multimesh != null \
                and c.multimesh.instance_count > 0:
            out.append(c)
    return out


func _next_family() -> void:
    var fams := _families()
    if _verify_at >= fams.size():
        _end()
        return
    for c in fams:
        c.visible = false
    fams[_verify_at].visible = true
    frames = 0
    stage = VERIFY


func _record_family() -> void:
    var fams := _families()
    var node = fams[_verify_at]
    var img := get_root().get_texture().get_image()
    var su := FrameProbe.summarise(img)
    var life_form := String(node.name).replace("Vegetation_", "")
    var authored: int = view.families.triangles_of(life_form)
    var instances: int = node.multimesh.instance_count
    var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    per_family.append({
        "life_form": life_form,
        "instances": instances,
        "authored_triangles_per_instance": authored,
        "primitives_counted": prims,
        "primitives_expected": instances * authored,
        "counter_tracked_the_instances": absf(float(prims) - float(instances * authored))
                <= 0.01 * float(maxi(instances * authored, 1)),
        "pixels_drawn": int(su["coloured"]),
        "renders": int(su["coloured"]) > 0,
    })
    _verify_at += 1
    _next_family()


## Put the viewer into the state being priced: one window, one row, one day,
## and a scatter at one place. Through the scrubber and the probe, because a
## measurement of a scene assembled some other way is a measurement of a scene
## nobody runs.
func _place() -> void:
    stage = PLACE
    var w: String = window_name if window_name != "" else str(view.fixture.windows[0])
    var set_to: Dictionary = scene.scrubber.select(w, row_name, day)
    if not bool(set_to["ok"]):
        printerr("measure_scatter: %s" % str(set_to["why"]))
        quit(2)
        return
    window_name = w
    var probe: Dictionary
    if have_at:
        probe = view.probe_world(at_world.x, at_world.y)
    else:
        # Screen centre of the opening view, which is reproducible from the
        # command line alone. The world point it resolved to travels in the
        # artefact, so a later run can be pinned to this exact place with --at
        # rather than to this exact framing.
        probe = view.probe_at_screen(get_root().get_camera_3d(),
                get_root().get_visible_rect().size * 0.5)
    probe_state = str(probe.get("state", "?"))
    if not probe.has("world"):
        printerr("measure_scatter: the probe did not resolve to ground: %s" % probe_state)
        quit(2)
        return
    at_world = probe["world"]
    scene._on_probed(probe)
    scatter_report = scene.scatter_report
    if not bool(scatter_report.get("ok", false)):
        printerr("measure_scatter: the scatter refused: %s" % str(scatter_report.get("why", "?")))
        quit(2)
        return
    # The camera goes to the scatter, because the cost of a scatter nobody is
    # looking at is not the question. This is the view the G key gives.
    view.focus_on_scatter()
    frames = 0
    stage = REFRAME


func _hide_scatter(hidden: bool) -> void:
    for c in view.get_children():
        if String(c.name).begins_with("Vegetation"):
            c.visible = not hidden


func _begin_measure(next: int) -> void:
    frames = 0
    stage = next


func _start_sampling(next: int) -> void:
    _wall.clear()
    _prims.clear()
    _draws.clear()
    _frames_drawn_at_start = Engine.get_frames_drawn()
    stage = next


func _sample(delta: float) -> void:
    _wall.append(delta * 1000.0)
    _prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    _draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _finish() -> Dictionary:
    var s := FrameStats.summarise(_wall)
    return {
        "frame_ms": s,
        "primitives_p50": FrameStats.quantile(_prims, 0.5),
        "draw_calls_p50": FrameStats.quantile(_draws, 0.5),
        "frames_drawn": Engine.get_frames_drawn() - _frames_drawn_at_start,
        "frames_timed": _wall.size(),
    }


func _end() -> void:
    var triangles := int(scatter_report.get("triangles_in_frame", 0))
    var changed := FrameProbe.compare(_img_without, _img_with)
    var changed_px := int(changed.get("differing", 0)) if bool(changed.get("ok", false)) else 0
    var suspect := ScatterCost.drew_the_scatter(changed_px,
            int(scatter["frames_drawn"]), int(scatter["frames_timed"]))
    # A window that lost the screen is a transient of the machine, not a
    # property of the scene. Re-measure rather than record a cadence.
    if suspect != "" and attempt < ScatterCost.ATTEMPTS:
        push_warning("measure_scatter: attempt %d -- %s" % [attempt, suspect])
        attempt += 1
        DisplayServer.window_move_to_foreground()
        _hide_scatter(true)
        per_family.clear()
        _begin_measure(BASELINE_WARMUP)
        return

    var marginal := ScatterCost.marginal(scatter["frame_ms"], baseline["frame_ms"])
    var placed: Dictionary = scatter_report.get("placed", {})
    var ns := _ns_per_instance(placed.keys())
    var predicted := ScatterCost.predicted_ms(placed, ns)
    var agree := {}
    if bool(predicted.get("ok", false)) and bool(marginal.get("ok", false)):
        agree = ScatterCost.agreement(float(predicted["ms"]), float(marginal["p50_ms"]))

    var doc := {
        "what": ("what M5's vegetation scatter costs a frame in the viewer that draws it, "
                + "and whether the empty-stage coefficient in render_cost.json predicts it"),
        # The repo HEAD when the run happened, which is the PARENT of whatever
        # commit lands this file: a measurement cannot be taken at the commit
        # that carries it. Stated because the alternative is a reader assuming
        # the two are the same and dating the run one commit late.
        "measured_at_commit": _git_head(),
        "measured_at_commit_means": ("the HEAD the run was taken against; the commit that "
                + "lands this artefact is its child"),
        # 1:1, and stated anyway because the rule that a measurement names the
        # exaggeration its distances were taken at outlived the exaggeration
        # itself -- which is the point of the rule. The shading factor is
        # separate and is recorded beside it: it moves no vertex, so no distance
        # here is conditional on it, but it is a real parameter of the frame
        # being timed. `test_a_recorded_distance_names_what_it_is_conditional_on`
        # fails if a measurement carrying metres does not carry the first field.
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "host": {
            "gpu": RenderingServer.get_video_adapter_name(),
            "rendering_method": RenderingServer.get_current_rendering_method(),
            "godot": Engine.get_version_info()["string"],
            "os": OS.get_name() + " " + OS.get_version(),
            "viewport": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
            "vsync": "disabled",
        },
        "scene": {
            "window": window_name, "row": row_name, "day": day,
            "probe_state": probe_state,
            "at_world_epsg5070": [at_world.x, at_world.y],
            "horizon_m": TerrainView.SCATTER_HORIZON_M,
            "camera": "the fly camera framed on the scatter, which is what the G key gives",
            "also_drawn": ("the terrain with its overlay, the flowlines, the contours and the "
                    + "UI -- all of them in BOTH timings, which is why the difference between "
                    + "the two is the scatter and a single timing would not be"),
        },
        "method": {
            "warmup_frames": ScatterCost.WARMUP_FRAMES,
            "measured_frames": ScatterCost.MEASURE_FRAMES,
            "attempts": attempt,
            "quoted_as": ("nearest-rank quantiles over the measured frames, the same form "
                    + "render_cost.json uses"),
            "verified_by": ("showing the scatter must change the frame in pixels, and the "
                    + "renderer must have drawn at least as many frames as were timed. NOT by "
                    + "the primitive counter, which is what the benchmark uses and which is "
                    + "wrong for two of these three multimeshes -- see per_family"),
        },
        "suspect": suspect,
        "measured": suspect == "",
        "pixels_the_scatter_changed": changed_px,
        "per_family": per_family,
        "without_scatter": baseline,
        "with_scatter": scatter,
        "marginal": marginal,
        "predicted_by_render_cost": predicted,
        "agreement": agree,
        "placed": placed,
        "triangles_in_frame": triangles,
        "per_instance_ns": ns,
        # The derivation the horizon question actually turns on: not what was
        # drawn, but what the wire IMPLIES at this horizon, which is larger than
        # any frame can hold and is the reason a share is drawn at all.
        "implied_at_this_horizon": scatter_report.get("budget", {}),
        "share_drawn": scatter_report.get("share_drawn", 1.0),
        "share_bound_by": scatter_report.get("share_bound_by", ""),
        "frame_budget_ms": ScatterCost.FRAME_BUDGET_MS,
        "not_covered": ("one machine, one renderer, one place in one window on one day. The "
                + "per-instance coefficient this is checked against is itself not portable "
                + "(see render_cost.json), and neither is this."),
    }
    var f := FileAccess.open(out_path, FileAccess.WRITE)
    if f == null:
        printerr("measure_scatter: cannot write %s" % out_path)
        quit(1)
        return
    f.store_string(JSON.stringify(doc, "  ") + "\n")
    f.close()
    _say(doc)
    quit(0 if suspect == "" else 1)


func _ns_per_instance(life_forms: Array) -> Dictionary:
    var out := {}
    if view.frame_cost == null or not view.frame_cost.is_loaded():
        return out
    for g in life_forms:
        if not view.families.has(g):
            continue
        var per: Dictionary = view.frame_cost.per_instance_ns(view.families.triangles_of(g))
        if bool(per["ok"]):
            out[str(g)] = float(per["ns"])
    return out


func _say(doc: Dictionary) -> void:
    var b: Dictionary = doc["without_scatter"]["frame_ms"]
    var s: Dictionary = doc["with_scatter"]["frame_ms"]
    print("scatter cost: %s at %s day %d, %d instances over %d triangles"
            % [doc["scene"]["window"], doc["scene"]["row"], day,
               int(doc["predicted_by_render_cost"].get("instances", 0)),
               int(doc["triangles_in_frame"])])
    print("  frame p50  without %.2f ms   with %.2f ms   marginal %.2f ms"
            % [float(b["p50"]), float(s["p50"]),
               float(doc["marginal"].get("p50_ms", NAN))])
    print("  frame p99  without %.2f ms   with %.2f ms" % [float(b["p99"]), float(s["p99"])])
    if bool(doc["predicted_by_render_cost"].get("ok", false)):
        print("  render_cost.json predicts %.2f ms for the same instances"
                % float(doc["predicted_by_render_cost"]["ms"]))
    if doc["agreement"].has("verdict"):
        print("  %s" % str(doc["agreement"]["verdict"]))
    if not bool(doc["marginal"].get("resolved", true)):
        print("  %s" % str(doc["marginal"]["why_unresolved"]))
    if doc["marginal"].has("p99_note"):
        print("  %s" % str(doc["marginal"]["p99_note"]))
    var implied: Dictionary = doc["implied_at_this_horizon"]
    if bool(implied.get("ok", false)) and implied.has("implied_ms"):
        print("  the whole implied scatter at %.0f m is %d instances / %.0f ms, %.1fx the "
                % [float(doc["scene"]["horizon_m"]), int(implied["implied_total"]),
                   float(implied["implied_ms"]),
                   float(implied["implied_ms"]) / ScatterCost.FRAME_BUDGET_MS]
                + "%.1f ms budget; %.1f%% of it is drawn" % [ScatterCost.FRAME_BUDGET_MS,
                   100.0 * float(doc["share_drawn"])])
    for r in doc["per_family"]:
        print("  %-10s %7d inst  %2d authored tri  counter %10d (%s)  %5d px"
                % [str(r["life_form"]), int(r["instances"]),
                   int(r["authored_triangles_per_instance"]), int(r["primitives_counted"]),
                   "tracks" if bool(r["counter_tracked_the_instances"]) else "DOES NOT TRACK",
                   int(r["pixels_drawn"])])
    if str(doc["suspect"]) != "":
        printerr("  NOT MEASURED: %s" % str(doc["suspect"]))
    print("  -> %s" % out_path)


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
