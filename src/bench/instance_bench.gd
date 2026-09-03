class_name InstanceBench
extends Node3D

## The per-instance frame-cost benchmark. §19.8.9's second instrument.
##
## §19.8 prices the individual tier's rendering and every term in it is
## measured except one: per-instance frame cost, which requires the engine.
## The corpus declines to estimate it, because a plausible-looking number with
## nothing behind it is worse than a named absence. This measures it.
##
## WHAT IT DOES NOT DRAW, AND WHY. There is no terrain here, no fixture, no
## residence layer -- a placeholder mesh instanced over a flat area is the
## instrument. Putting M1's basin underneath would make the number a joint
## measurement of two things, and neither would be recoverable from it.
##
## TWO TECHNIQUES, BECAUSE THEY ARE TWO COEFFICIENTS. §19.8's model says
## nothing about whether the client instances through a MultiMesh or through
## individual nodes, and the two differ by enough that a single number would be
## silently conditional on a technique nobody declared. Both are measured.
##
## MESH COMPLEXITY IS THE SECOND AXIS. A per-instance cost quoted without the
## triangle count it was measured at does not transfer to M5's archetypes,
## which do not exist yet. Three complexities are swept, and the artefact
## reports whether cost is linear in instances at fixed complexity -- if it is
## not, the word "coefficient" is the wrong shape for the answer and that is
## the finding rather than a footnote.
##
## IT REFUSES TO RUN HEADLESS, AND THAT IS THE POINT OF THE FILE. Under
## `--headless` the display server is a stub and the rendering driver draws
## nothing; every frame comes back at a few microseconds. Those numbers look
## exactly like a fast GPU. So the benchmark checks the display server it got
## and writes a refusal instead of a measurement -- the same discipline as the
## contract loader's, one artefact over.

# --------------------------------------------------------------------------
# the measurement's own parameters, all of which travel with its result
# --------------------------------------------------------------------------

## §19.8.4's example horizons put a cell's tree count somewhere between about
## 1e3 and 1.5e5 instances. The ladder is geometric across that range rather
## than a list of interesting values: a rung chosen for landing on a
## particular quantile would make the sweep an answer to one question instead
## of a curve any question can be read off.
const COUNTS: Array[int] = [1000, 2000, 4000, 8000, 16000, 32000, 64000, 128000, 150000]

## The budget the answer is against: §16.10's fixed 33.3 ms client frame.
const FRAME_BUDGET_MS := 33.3

## Stop climbing a sweep once a rung costs this much. The rungs above it
## cannot fit either, and measuring them buys a bigger number for the same
## conclusion at several minutes a rung.
const ABANDON_ABOVE_MS := 8.0 * FRAME_BUDGET_MS

## Stop climbing if building the scene takes this long. Construction cost is
## not frame cost, but a technique that cannot be built inside a scene load is
## already answered, and it is reported rather than waited out.
const ABANDON_BUILD_MS := 8000.0

const WARMUP_FRAMES := 20
const MEASURE_FRAMES := 80

## Instances are scattered over a flat square of this side, at this height,
## seen from directly above. Trees at a horizon distance are a few pixels
## tall, so this is the regime the horizon question is actually about; a
## close-up view would measure fill rate instead of instancing.
const FOOTPRINT_M := 1000.0
const INSTANCE_HEIGHT_M := 4.0
const VIEWPORT := Vector2i(1280, 720)
const FOV_DEGREES := 60.0

## Seeded, so two runs on one machine differ by the machine and not by the
## layout. The seed travels in the artefact.
const PLACEMENT_SEED := 20260903

enum { BUILD, WARMUP, MEASURE, WRITE, DONE }

var out_path: String = ""
var configs: Array = []
var results: Array = []

var _state := BUILD
var _at := 0
var _frames := 0
var _wall := PackedFloat64Array()
var _gpu := PackedFloat64Array()
var _cpu := PackedFloat64Array()
var _build_ms := 0.0
var _stage: Node3D = null
var _camera: Camera3D = null
var _meshes: Dictionary = {}
var _abandoned: Dictionary = {}      ## "technique|complexity" -> why


func _ready() -> void:
    out_path = _arg("--out", "")
    if DisplayServer.get_name() == "headless":
        # A stub display server reports microsecond frames for any scene at
        # all. Writing that as a coefficient would be the plausible number
        # this whole measurement exists instead of.
        _write({
            "refused": true,
            "why": ("the display server is 'headless', which draws nothing and reports "
                    + "frame times for work that never happened. Per-instance frame cost "
                    + "requires the engine actually rendering (§19.8.9); run this "
                    + "windowed on the machine whose coefficient you want."),
        })
        get_tree().quit(1)
        return

    DisplayServer.window_set_size(VIEWPORT)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

    _meshes = _build_meshes()
    _stage = Node3D.new()
    add_child(_stage)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-60.0, 40.0, 0.0)
    add_child(sun)

    _camera = Camera3D.new()
    _camera.fov = FOV_DEGREES
    # Straight down from the altitude at which the footprint fills the frame
    # vertically: every instance is in frustum, which is the honest worst case
    # for a budget question -- culling is not what a full cell costs.
    _camera.position = Vector3(0.0, 0.5 * FOOTPRINT_M / tan(deg_to_rad(0.5 * FOV_DEGREES)), 0.0)
    _camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    _camera.far = 100000.0
    _camera.current = true
    add_child(_camera)

    configs = plan()
    print("bench: %d configurations, %s, %s" % [configs.size(),
            RenderingServer.get_video_adapter_name(),
            RenderingServer.get_current_rendering_method()])


## Every configuration, in the order they are measured: ascending instance
## count within a technique and complexity, so a sweep can be abandoned from
## below once a rung is hopeless.
static func plan() -> Array:
    var out: Array = []
    for technique in ["multimesh", "nodes"]:
        for complexity in ["low", "mid", "high"]:
            for n in COUNTS:
                out.append({"technique": technique, "complexity": complexity, "instances": n})
    return out


func _build_meshes() -> Dictionary:
    var low := BoxMesh.new()
    low.size = Vector3(INSTANCE_HEIGHT_M * 0.25, INSTANCE_HEIGHT_M, INSTANCE_HEIGHT_M * 0.25)
    var mid := SphereMesh.new()
    mid.radial_segments = 16
    mid.rings = 8
    mid.radius = INSTANCE_HEIGHT_M * 0.25
    mid.height = INSTANCE_HEIGHT_M
    var high := SphereMesh.new()
    high.radial_segments = 48
    high.rings = 24
    high.radius = INSTANCE_HEIGHT_M * 0.25
    high.height = INSTANCE_HEIGHT_M
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.24, 0.42, 0.20)
    for m in [low, mid, high]:
        m.material = mat
    return {"low": low, "mid": mid, "high": high}


static func triangles_of(mesh: Mesh) -> int:
    return mesh.get_faces().size() / 3


func _process(_delta: float) -> void:
    match _state:
        BUILD:
            _begin_config()
        WARMUP:
            _frames += 1
            if _frames >= WARMUP_FRAMES:
                _wall.clear()
                _gpu.clear()
                _cpu.clear()
                _state = MEASURE
        MEASURE:
            _sample()
            if _wall.size() >= MEASURE_FRAMES:
                _end_config()
        WRITE:
            _write(report())
            _state = DONE
            get_tree().quit(0)


func _sample() -> void:
    var vp := get_viewport().get_viewport_rid()
    # Wall time between frames with vsync off, and the engine's own measured
    # render times. They answer different questions -- the wall clock is what a
    # viewer waits, the GPU figure is what the card did -- and a coefficient
    # taken from only one of them cannot be checked against the other.
    _wall.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
            + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
    _gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
    _cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))


func _begin_config() -> void:
    if _at >= configs.size():
        _state = WRITE
        return
    var cfg: Dictionary = configs[_at]
    var sweep := "%s|%s" % [cfg["technique"], cfg["complexity"]]
    if _abandoned.has(sweep):
        results.append({
            "technique": cfg["technique"], "complexity": cfg["complexity"],
            "instances": cfg["instances"], "measured": false,
            "why": str(_abandoned[sweep]),
        })
        _at += 1
        return

    for c in _stage.get_children():
        _stage.remove_child(c)
        c.queue_free()

    var t0 := Time.get_ticks_usec()
    var mesh: Mesh = _meshes[cfg["complexity"]]
    var n: int = int(cfg["instances"])
    var rng := RandomNumberGenerator.new()
    rng.seed = PLACEMENT_SEED
    var half := 0.5 * FOOTPRINT_M

    if str(cfg["technique"]) == "multimesh":
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = mesh
        mm.instance_count = n
        for i in n:
            mm.set_instance_transform(i, Transform3D(Basis(), Vector3(
                    rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))))
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        _stage.add_child(mmi)
    else:
        for i in n:
            var mi := MeshInstance3D.new()
            mi.mesh = mesh
            mi.position = Vector3(rng.randf_range(-half, half), 0.0,
                                  rng.randf_range(-half, half))
            _stage.add_child(mi)
    _build_ms = float(Time.get_ticks_usec() - t0) / 1000.0

    _frames = 0
    _state = WARMUP


func _end_config() -> void:
    var cfg: Dictionary = configs[_at]
    var wall := FrameStats.summarise(_wall)
    var gpu := FrameStats.summarise(_gpu)
    var cpu := FrameStats.summarise(_cpu)
    results.append({
        "technique": cfg["technique"],
        "complexity": cfg["complexity"],
        "triangles_per_instance": triangles_of(_meshes[cfg["complexity"]]),
        "instances": cfg["instances"],
        "measured": true,
        "build_ms": _build_ms,
        "frame_ms": wall,
        "gpu_ms": gpu,
        "cpu_ms": cpu,
    })
    print("bench: %-9s %-4s %7d  build %8.1f ms  frame p50 %7.2f  p99 %7.2f  gpu p50 %7.2f"
            % [cfg["technique"], cfg["complexity"], int(cfg["instances"]), _build_ms,
               float(wall["p50"]), float(wall["p99"]), float(gpu["p50"])])

    var sweep := "%s|%s" % [cfg["technique"], cfg["complexity"]]
    if float(wall["p50"]) > ABANDON_ABOVE_MS:
        _abandoned[sweep] = ("not measured: %d instances already cost %.1f ms at p50, "
                + "more than %.0fx the %.1f ms budget, so every rung above it is "
                + "answered") % [int(cfg["instances"]), float(wall["p50"]),
                        ABANDON_ABOVE_MS / FRAME_BUDGET_MS, FRAME_BUDGET_MS]
    elif _build_ms > ABANDON_BUILD_MS:
        _abandoned[sweep] = ("not measured: building %d instances took %.1f s, and a "
                + "technique that cannot be constructed inside a scene load is answered "
                + "before its frame cost is") % [int(cfg["instances"]), _build_ms / 1000.0]

    _at += 1
    _state = BUILD


# --------------------------------------------------------------------------
# the artefact
# --------------------------------------------------------------------------

## Per (technique, complexity), the straight line through the measured rungs
## and what it costs to believe it.
func fits() -> Dictionary:
    var by: Dictionary = {}
    for r in results:
        if not bool(r.get("measured", false)):
            continue
        var k := "%s|%s" % [r["technique"], r["complexity"]]
        if not by.has(k):
            by[k] = {"x": PackedFloat64Array(), "y": PackedFloat64Array(),
                     "g": PackedFloat64Array()}
        by[k]["x"].append(float(r["instances"]))
        by[k]["y"].append(float(r["frame_ms"]["p50"]))
        by[k]["g"].append(float(r["gpu_ms"]["p50"]))
    var out: Dictionary = {}
    for k in by:
        out[k] = {
            "frame_p50": FrameStats.fit_linear(by[k]["x"], by[k]["y"]),
            "frame_p50_marginals": FrameStats.marginals(by[k]["x"], by[k]["y"]),
            "gpu_p50": FrameStats.fit_linear(by[k]["x"], by[k]["g"]),
            "rungs_measured": by[k]["x"].size(),
        }
    return out


func report() -> Dictionary:
    return {
        "artefact": "per-instance frame cost, measured on one machine",
        "ruled_by": ["§19.8", "§19.8.4", "§19.8.6", "§19.8.9", "§16.10"],
        "answers": ("§19.8.9's one unmeasured coefficient. It is a measurement of THIS "
                + "engine on THIS machine and is not portable; the host block is part of "
                + "the result, not provenance decorating it."),
        "generated_by": "scenes/bench_instances.tscn via tools/run_benchmark.sh",
        "generated_at_utc": Time.get_datetime_string_from_system(true),
        "budget_ms": FRAME_BUDGET_MS,
        "host": host(),
        "method": method(),
        "results": results,
        "fits": fits(),
        "not_here": {
            "other_hardware": ("the coefficient is per machine and per renderer. Nothing "
                    + "here extrapolates to another GPU, and the numbers should be "
                    + "re-measured rather than scaled."),
            "terrain": ("no basin is drawn. This measures instancing alone; a scene with "
                    + "M1's terrain under it would measure two things at once."),
            "culling": ("every instance is in frustum by construction. A real view culls, "
                    + "so these are the costs of a cell wholly in view."),
            "shading": ("one unshaded-complexity opaque material, no shadows, no "
                    + "transparency, no LOD. M5's archetypes will differ and this is the "
                    + "floor rather than the estimate."),
        },
    }


func host() -> Dictionary:
    return {
        "os": "%s %s" % [OS.get_name(), OS.get_version()],
        "cpu": OS.get_processor_name(),
        "cpu_threads": OS.get_processor_count(),
        "gpu": RenderingServer.get_video_adapter_name(),
        "gpu_vendor": RenderingServer.get_video_adapter_vendor(),
        "gpu_api": RenderingServer.get_video_adapter_api_version(),
        "godot": Engine.get_version_info().get("string", ""),
        "rendering_method": RenderingServer.get_current_rendering_method(),
        "rendering_driver": OS.get_current_rendering_driver_name(),
        "display_server": DisplayServer.get_name(),
        "headless": DisplayServer.get_name() == "headless",
        "vsync": "disabled",
    }


func method() -> Dictionary:
    var vp := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2.ZERO
    return {
        "viewport_px": [int(vp.x), int(vp.y)],
        "footprint_m": FOOTPRINT_M,
        "instance_height_m": INSTANCE_HEIGHT_M,
        "camera": ("directly overhead at the altitude where the footprint fills the frame "
                + "vertically, %.0f° vertical FOV. Every instance is in frustum." % FOV_DEGREES),
        "placement": "uniform random in the square, seed %d" % PLACEMENT_SEED,
        "warmup_frames": WARMUP_FRAMES,
        "measure_frames": MEASURE_FRAMES,
        "quantiles": "nearest-rank: p99 of 80 frames is the 80th-ranked frame, not an interpolation",
        "frame_ms": "engine process + physics time per frame, vsync disabled",
        "gpu_ms": "RenderingServer's own measured viewport render time",
        "abandon_rule": ("a sweep stops climbing once a rung exceeds %.0f ms at p50 or "
                + "takes over %.0f s to build; the rungs above are reported unmeasured "
                + "with the reason") % [ABANDON_ABOVE_MS, ABANDON_BUILD_MS / 1000.0],
    }


func _write(doc: Dictionary) -> void:
    var text := JSON.stringify(doc, "  ") + "\n"
    if out_path == "":
        print(text)
        return
    var f := FileAccess.open(out_path, FileAccess.WRITE)
    if f == null:
        push_error("bench: cannot write %s" % out_path)
        return
    f.store_string(text)
    print("bench: wrote %s" % out_path)


func _arg(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == name and i + 1 < args.size():
            return args[i + 1]
    return fallback
