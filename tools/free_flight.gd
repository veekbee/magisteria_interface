extends SceneTree

## Free flight at walking pace, recorded so that one human session becomes a
## permanent fixture.
##
##     bash tools/free_flight.sh
##     bash tools/free_flight.sh --recentre 25 --at -1212793,1376226
##
## WHY A PERSON HAS TO FLY IT. Every far-field measurement so far is an
## aggregate over a scripted path, and two of the open questions are not
## aggregate questions: where between 0 and 1 a churn becomes visible, and what
## a pan does. Both are perceptual, and the harness's job is not to answer them
## but to make the answer a measurement rather than a ruling in the abstract.
##
## SO THE MARK IS THE INSTRUMENT. SPACE means "that looked wrong". The frame it
## lands on carries the churn, the population, the frame time and the pose, so
## a judgement becomes a row. Several presses give a distribution, and where
## they disagree that is information about the threshold rather than noise.
##
## AND THE TRACE IS THE POINT, NOT THE FLIGHT. What is written is the camera
## path; `tools/replay_flight.sh` scores it again headlessly, forever, without
## the person. A trace that cannot be replayed is a demo.
##
## FIVE METRES PER SECOND, which is not a round number chosen for being round:
## it is the speed the corpus derives for an avatar under its own kinematic
## compression (§3.1c), so tuning here is tuning at the speed the world will be
## seen at. `--speed` moves it and the trace records what was actually
## travelled rather than what was asked for.
##
## IT REFUSES HEADLESS, and unlike the other harnesses it also refuses a window
## that stopped being drawn -- which for an interactive session is not a corner
## case but the normal way a person alt-tabs away.

const EYE_HEIGHT_M := 1.7
const SETTLE_FRAMES := 12

## Metres per second. §3.1c's figure; see the note above.
const WALK_M_S := 5.0

## Degrees of pan per pixel of mouse movement. A quarter-degree puts a full
## turn at about 1,440 px, which is a comfortable arm's sweep rather than a
## flick.
const LOOK_DEGREES_PX := 0.25

## How far the scatter is built around the flyer.
const RADIUS_M := 480.0

## Pitch is clamped rather than free: a camera that rolls past vertical is
## disorienting to fly and produces poses no player would ever hold.
const PITCH_LIMIT_DEGREES := 85.0

## Frames a mark stays lit on screen, so a person can see the press registered.
const MARK_FLASH_FRAMES := 30

enum { SETTLE, PLACE, FLY, WRITE, DONE }


## A SceneTree SCRIPT HEARS NO INPUT EVENTS. Key state can be polled through
## `Input`, but relative mouse motion is only ever delivered as an event, and
## an event needs a Node in the tree to arrive at. This is that Node and it is
## nothing else: it accumulates the motion since it was last read.
class MouseLook extends Node:
    var dx := 0.0
    var dy := 0.0

    func _input(event: InputEvent) -> void:
        if event is InputEventMouseMotion:
            dx += (event as InputEventMouseMotion).relative.x
            dy += (event as InputEventMouseMotion).relative.y

    func take() -> Vector2:
        var v := Vector2(dx, dy)
        dx = 0.0
        dy = 0.0
        return v

var scene: Node = null
var view = null
var stage := SETTLE
var frames := 0
var _stage_frames := 0

var window_name := ""
var row_name := "band.pft.biomass"
var day := 22
var at_world := Vector2.ZERO
var k_fraction := 0.35
var speed_m_s := WALK_M_S
## Metres the camera may travel before the scatter is rebuilt around it. Zero
## is what ships: one build, flown through. Anything above zero is backlog
## 198's inversion, which is the thing that boils.
var recentre_m := 0.0
## Empty until `_place` picks the next free number. A FIXED DEFAULT OVERWRITES
## THE LAST FLIGHT, which is what happened: a second flight landed on the first
## one's path and the only reason the first survived was that it had been
## committed. A flight is somebody's afternoon and cannot be re-taken.
var out_path := ""
var minutes := 0.0

var trace: FlightTrace = null
var cam: Camera3D = null
var _yaw := 0.0
var _pitch := 0.0
var _t0 := 0
var _last_frame_usec := 0
var _prev_census: Dictionary = {}
var _build_centre := Vector2.ZERO
var _last_build_ms := 0.0
var _rebuilt_this_frame := false
var _mark_flash := 0
var _build_flash := 0
var _last_churn := 0.0
var _marks := 0
var _unfocused := 0
var _builds := 0
var _blocked_ms := 0.0
var _k_res := 0.0
var _hud: Label = null
var _look: MouseLook = null


func _initialize() -> void:
    if DisplayServer.get_name() == "headless":
        printerr("free_flight: the display server is 'headless', which draws nothing and "
                + "reports success -- and this harness is a person looking at a screen. "
                + "Run through tools/free_flight.sh.")
        quit(2)
        return
    row_name = _arg("--row", row_name)
    window_name = _arg("--window", window_name)
    day = int(_arg("--day", str(day)))
    k_fraction = float(_arg("--k", str(k_fraction)))
    speed_m_s = float(_arg("--speed", str(speed_m_s)))
    recentre_m = float(_arg("--recentre", str(recentre_m)))
    minutes = float(_arg("--minutes", str(minutes)))
    out_path = _arg("--out", "")
    var at := _arg("--at", "")
    if at != "":
        var parts := at.split(",")
        if parts.size() == 2:
            at_world = Vector2(parts[0].to_float(), parts[1].to_float())
    # THE FAR FIELD IS THE THING BEING LOOKED AT, and at 1280x800 a stand at
    # two hundred metres is a few dozen pixels deep. A bigger window is not a
    # convenience here, it is more of the measurement -- and `k_res`, which
    # sets the individuation horizon, is a function of viewport height, so a
    # larger window individuates further and the trace records which it was.
    var size := _arg("--size", "1280x800").split("x")
    if size.size() == 2:
        DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
    if _has_flag("--fullscreen"):
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    var packed: PackedScene = load("res://scenes/main.tscn")
    scene = packed.instantiate()
    get_root().add_child(scene)


func _process(_delta: float) -> bool:
    frames += 1
    _stage_frames += 1
    var stall := HarnessGuard.stall_note(_stage_name(), _stage_frames)
    if stall != "" and stage != FLY:
        printerr("free_flight: REFUSED. %s" % stall)
        quit(4)
        return true
    if view == null:
        view = scene._terrain
        return false
    match stage:
        SETTLE:
            if _stage_frames > SETTLE_FRAMES:
                _place()
        FLY:
            _fly()
        WRITE:
            _write()
    return false


func _stage_name() -> String:
    return ["settle", "place", "fly", "write", "done"][stage]


func _place() -> void:
    stage = PLACE
    _stage_frames = 0
    # DEEPEST_WINTER BY DEFAULT, NOT THE FIRST WINDOW. "The first" is
    # `largest_fire`, and every far-field measurement in `measurements/` was
    # taken in `deepest_winter` -- a flight in the other one would be tuning
    # against a stand nothing else here has scored. The window is printed on
    # the way in either way, because this defaulting has already produced one
    # artefact that was fine except for being about somewhere else.
    var w: String = window_name
    if w == "":
        w = str(view.fixture.windows[0])
        for cand in view.fixture.windows:
            if str(cand) == "deepest_winter":
                w = "deepest_winter"
    var set_to: Dictionary = scene.scrubber.select(w, row_name, day)
    if not bool(set_to["ok"]):
        printerr("free_flight: %s" % str(set_to["why"]))
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
        printerr("free_flight: the probe did not resolve to ground")
        quit(2)
        return
    at_world = probe["world"]
    scene._on_probed(probe)
    view.focus_on_scatter()
    scene.get_node("UI").visible = false
    view.set_naturalistic(true)
    _k_res = VegetationScatter.resolution_k(
            float(get_root().get_visible_rect().size.y), view.rig.fly.fov)

    cam = view.rig.fly
    cam.far = 6000.0
    cam.near = 0.5
    var surface: float = view.terrain.drawn_surface_y(at_world, view.heightfield)
    var ground: float = view.scatter_centre_mesh.y if is_nan(surface) else surface
    cam.position = Vector3(view.scatter_centre_mesh.x, ground + EYE_HEIGHT_M,
            view.scatter_centre_mesh.z)
    _yaw = 0.0
    _pitch = -6.0
    _apply_look()

    # THE APP'S OWN FLY CONTROLS MOVE AT 40 km/s, which is right for crossing a
    # basin and wrong by four orders of magnitude for walking through a stand.
    # They are switched off rather than retuned: the rig belongs to the viewer
    # and this harness is not it.
    view.rig.set_process(false)
    view.rig.set_process_unhandled_input(false)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _look = MouseLook.new()
    scene.add_child(_look)

    _build(Vector2(at_world.x, at_world.y), true)
    _hud = Label.new()
    _hud.position = Vector2(12, 10)
    _hud.add_theme_color_override("font_color", Color(1, 1, 1))
    _hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    _hud.add_theme_constant_override("outline_size", 6)
    scene.get_node("UI").add_child(_hud)
    scene.get_node("UI").visible = true
    for c in scene.get_node("UI").get_children():
        c.visible = c == _hud

    trace = FlightTrace.new()
    trace.begin({
        "what": ("a person walking through the far field at %s m/s, translating and panning"
                % String.num(speed_m_s, 1)),
        "recorded_at_commit": _git_head(),
        "scene": {
            "window": window_name, "row": row_name, "day": day,
            "at_world_epsg5070": [at_world.x, at_world.y],
        },
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "viewport": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
        "fov_degrees": cam.fov,
        "eye_height_m": EYE_HEIGHT_M,
        "asked_speed_m_s": speed_m_s,
        "individuation_k": k_fraction * _k_res,
        "k_over_k_res": k_fraction,
        "k_resolution": _k_res,
        "scatter_radius_m": RADIUS_M,
        "recentre_m": recentre_m,
        "recentre_means": ("metres the camera may travel before the scatter is rebuilt around "
                + "it. 0 is one build flown through, which is what ships; above 0 is a "
                + "population that follows the camera, which is what a per-place instance "
                + "budget does"),
        "marks_mean": "SPACE, pressed when something looked wrong",
    })
    if out_path == "":
        out_path = _next_free_path()
    _t0 = Time.get_ticks_usec()
    _last_frame_usec = _t0
    stage = FLY
    _stage_frames = 0
    print("free flight: CLICK THE WINDOW to begin -- nothing is recorded until it has focus.")
    print("             W/A/S/D to walk, mouse to look, SPACE to mark, ESC to land.")
    print("             %s m/s, %s, scatter %s m%s"
            % [String.num(speed_m_s, 1), window_name, String.num(RADIUS_M, 0),
               "" if recentre_m <= 0.0 else ", re-centring every %s m" % String.num(recentre_m, 0)])


## One build around a world position, and the census it left behind.
func _build(centre: Vector2, first: bool) -> void:
    var t := Time.get_ticks_usec()
    if not first:
        _prev_census = view.scatter.census.duplicate()
    view.scatter_at(centre, RADIUS_M, [], VegetationScatter.MAX_BUILT_INSTANCES,
            k_fraction * _k_res)
    _build_centre = centre
    _last_build_ms = float(Time.get_ticks_usec() - t) / 1000.0
    _rebuilt_this_frame = true
    _builds += 1
    if not first:
        _blocked_ms += _last_build_ms


func _apply_look() -> void:
    _pitch = clampf(_pitch, -PITCH_LIMIT_DEGREES, PITCH_LIMIT_DEGREES)
    cam.rotation = Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0)


func _fly() -> void:
    var now := Time.get_ticks_usec()
    var frame_ms := float(now - _last_frame_usec) / 1000.0
    _last_frame_usec = now
    var dt := frame_ms / 1000.0

    # A WINDOW THAT LOST FOCUS STOPS BEING DRAWN while the loop keeps ticking,
    # and for an interactive session that is not a corner case -- it is what
    # happens every time a person looks at something else. The frames are
    # recorded and flagged rather than dropped, so a replay can see the gap and
    # a reader can see how much of the flight was not on screen.
    var focused := DisplayServer.window_is_focused()
    # THE FLIGHT BEGINS WHEN THE PERSON DOES. Everything before the window is
    # first clicked is setup, not flying, and counting it as frames-not-drawn
    # would make every flight fail its own focus check for the honest reason
    # that nobody had started yet. After the first frame is recorded, a loss of
    # focus is a real one and is counted.
    if trace.frames.is_empty():
        if not focused:
            _t0 = now
            return
        _t0 = now
        _last_frame_usec = now
        frame_ms = 0.0
        dt = 0.0
    if not focused:
        _unfocused += 1

    var moved := _look.take()
    if moved != Vector2.ZERO:
        _yaw -= moved.x * LOOK_DEGREES_PX
        _pitch -= moved.y * LOOK_DEGREES_PX
        _apply_look()

    _rebuilt_this_frame = false
    var here := Vector3.ZERO
    if Input.is_key_pressed(KEY_W): here -= cam.global_transform.basis.z
    if Input.is_key_pressed(KEY_S): here += cam.global_transform.basis.z
    if Input.is_key_pressed(KEY_A): here -= cam.global_transform.basis.x
    if Input.is_key_pressed(KEY_D): here += cam.global_transform.basis.x
    if here != Vector3.ZERO:
        # FLAT, because a person walks and does not fly into the ground. The
        # look direction sets the heading; the pitch does not lift or sink it.
        here.y = 0.0
        if here.length() > 0.0:
            cam.position += here.normalized() * speed_m_s * dt
    var ground: float = view.terrain.drawn_surface_y(
            view.terrain.mesh_to_world(Vector3(cam.position.x, 0.0, cam.position.z),
                    view.heightfield), view.heightfield)
    if not is_nan(ground):
        cam.position.y = ground + EYE_HEIGHT_M

    var world_here: Vector2 = view.terrain.mesh_to_world(
            Vector3(cam.position.x, 0.0, cam.position.z), view.heightfield)
    if recentre_m > 0.0 and (world_here - _build_centre).length() >= recentre_m:
        _build(world_here, false)

    var cen: Dictionary = view.scatter.census
    var churn := (FlightTrace.churn_between(_prev_census, cen) if _rebuilt_this_frame
            else {"gone_fraction": 0.0, "churn_fraction": 0.0, "gone": 0, "appeared": 0,
                  "survived": FlightTrace.population(cen)})
    var seen := FlightTrace.in_view(cen, cam.global_transform, cam.fov,
            float(DisplayServer.window_get_size().x) / float(DisplayServer.window_get_size().y))

    var mark := FlightTrace.MARK_NONE
    if Input.is_key_pressed(KEY_SPACE) and _mark_flash <= 0:
        mark = FlightTrace.MARK_LOOKED_WRONG
        _marks += 1
        _mark_flash = MARK_FLASH_FRAMES
    _mark_flash = maxi(0, _mark_flash - 1)

    # `frame_ms` IS THE GAP SINCE THE LAST FRAME AND NOTHING ELSE, which means
    # a rebuild below this line lands in the NEXT frame's reading. That is how
    # a flight came back with 26 stalls of 1.8 s and 26 rebuilds and not one of
    # them on the same row. `build_ms` is the blocked time and belongs to the
    # frame that caused it; the two are read together and the artefact says so.
    # WHAT IS RECORDED IS WHAT WAS MEASURED AND CANNOT BE RE-DERIVED, plus the
    # populations the replay's agreement check compares against. The sub-cell
    # count and the symmetric churn fraction are both recomputed by the replay
    # from the census, and the build centre only changes on the frames that
    # rebuilt -- carrying all three on every one of twenty thousand rows was a
    # sixth of a trace to say nothing new.
    var row := {
        "frame_ms": frame_ms,
        "instances": FlightTrace.population(cen),
        "in_view_instances": int(seen["instances"]),
        "gone_fraction": float(churn["gone_fraction"]),
        "rebuilt": _rebuilt_this_frame,
        "build_ms": _last_build_ms if _rebuilt_this_frame else 0.0,
        "mark": mark,
        "drawn": focused,
    }
    if _rebuilt_this_frame:
        row["build_centre_epsg5070"] = [_build_centre.x, _build_centre.y]
    trace.add(float(now - _t0) / 1000.0, cam.global_transform, row)

    if _rebuilt_this_frame:
        _build_flash = MARK_FLASH_FRAMES
        _last_churn = float(churn["gone_fraction"])
    _build_flash = maxi(0, _build_flash - 1)
    if _hud != null:
        # A PERSON CANNOT MARK WHAT THEY CANNOT NAME. The first flight came
        # back with sixteen marks and every one of them was this harness
        # rebuilding, not the far field misbehaving -- which is the annotation
        # key working perfectly on a defect nobody had told the flyer about.
        # The rebuild says so on screen now, so a mark during one is a mark
        # about a known stall and a mark elsewhere is about the view.
        # THE CHURN SHOWN IS THE LAST REBUILD'S, HELD. Churn is an event, not a
        # level: it is zero on every frame that did not rebuild, so a live
        # reading sits at 0.000 for five seconds and then flickers once. What a
        # flyer needs to see is the size of the last thing that happened.
        _hud.text = ("%5.1f ms   %6d in view of %6d   last churn %.3f   marks %d%s%s"
                % [frame_ms, int(seen["instances"]),
                   FlightTrace.population(cen), _last_churn, _marks,
                   "   <-- MARKED" if _mark_flash > 0 else "",
                   "   [REBUILT: the freeze you just saw was this, %.0f ms]" % _last_build_ms
                            if _build_flash > 0 else ""])

    var over := minutes > 0.0 and float(now - _t0) / 60000000.0 >= minutes
    if Input.is_key_pressed(KEY_ESCAPE) or over:
        stage = WRITE
        _stage_frames = 0


func _write() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var dir := out_path.get_base_dir()
    if dir != "" and not DirAccess.dir_exists_absolute(dir):
        DirAccess.make_dir_recursive_absolute(dir)
    var motion := FlightTrace.motion_of(trace.frames)
    var speeds: Array = []
    var turns: Array = []
    for m in motion:
        speeds.append(float((m as Dictionary)["speed_m_s"]))
        turns.append(float((m as Dictionary)["turn_degrees_s"]))
    trace.header["frames"] = trace.frames.size()
    trace.header["seconds"] = (float(trace.frames[-1]["t_ms"]) / 1000.0
            if not trace.frames.is_empty() else 0.0)
    trace.header["marks"] = _marks
    trace.header["frames_not_drawn"] = _unfocused
    trace.header["rebuilds"] = maxi(0, _builds - 1)
    trace.header["blocked_ms_total"] = _blocked_ms
    trace.header["blocked_note"] = ("time the main loop spent inside a scatter rebuild, which "
            + "is time the window was not being redrawn while the flight continued. It is a "
            + "cost of re-centring, not of drawing: `measurements/scatter_cost.json` prices "
            + "the frame, and this is what it costs to BUILD one.")
    trace.header["speed_m_s_measured"] = FlightTrace.quantiles(speeds)
    trace.header["turn_degrees_s_measured"] = FlightTrace.quantiles(turns)

    # A FLIGHT MOSTLY BEHIND ANOTHER WINDOW IS NOT A FLIGHT. It is refused
    # rather than written, because the trace would replay perfectly and the
    # judgement it carries -- which is the whole point of a person being here
    # -- would be about frames nobody saw.
    if trace.frames.size() > 0 and float(_unfocused) / float(trace.frames.size()) > 0.10:
        printerr("free_flight: REFUSED. %d of %d frames were recorded while the window was "
                        % [_unfocused, trace.frames.size()]
                + "not focused, so they were not drawn. The path would replay; the judgement "
                + "would be about frames nobody saw. Nothing written.")
        quit(3)
        return
    if FileAccess.file_exists(out_path):
        var spare := _next_free_path()
        printerr("free_flight: %s already exists and a flight cannot be re-taken. Writing to "
                        % out_path + "%s instead." % spare)
        out_path = spare
    var saved := trace.save(out_path)
    if not bool(saved["ok"]):
        printerr("free_flight: %s" % str(saved["why"]))
        quit(5)
        return
    print("")
    print("flight: %d frames over %s s, %d marks, %d frames not drawn"
            % [trace.frames.size(), String.num(float(trace.header["seconds"]), 1), _marks,
               _unfocused])
    if _builds > 1:
        print("        %d rebuilds blocked %s s of it (%s%%), %s s each"
                % [_builds - 1, String.num(_blocked_ms / 1000.0, 1),
                   String.num(100.0 * _blocked_ms / maxf(1.0, float(trace.header["seconds"])
                            * 1000.0), 1),
                   String.num(_blocked_ms / float(maxi(1, _builds - 1)) / 1000.0, 2)])
    var sp: Dictionary = trace.header["speed_m_s_measured"]
    if not sp.is_empty():
        print("        speed p50 %s m/s (asked %s), turn p50 %s deg/s"
                % [String.num(float(sp["p50"]), 2), String.num(speed_m_s, 1),
                   String.num(float((trace.header["turn_degrees_s_measured"] as Dictionary)["p50"]), 1)])
    var bytes := FileAccess.open(out_path, FileAccess.READ).get_length()
    print("        -> %s  (%.1f MB)" % [out_path, float(bytes) / 1e6])
    if bytes > FlightTrace.COMMITTABLE_BYTES:
        print("        NOTE: over decision 948's %d-byte threshold, so this one is NOT "
                        % FlightTrace.COMMITTABLE_BYTES
                + "committable. Route it through tools/fetch_artefacts.py or fly shorter.")
    print("        replay it: bash tools/replay_flight.sh --trace %s" % out_path)
    stage = DONE
    quit(0)


## The next unused `flight-NN.trace.json`, so no flight lands on another.
func _next_free_path() -> String:
    var dir := "measurements/flights"
    if not DirAccess.dir_exists_absolute(dir):
        DirAccess.make_dir_recursive_absolute(dir)
    for i in range(1, 1000):
        var path := "%s/flight-%02d.trace.json" % [dir, i]
        if not FileAccess.file_exists(path):
            return path
    return "%s/flight-overflow.trace.json" % dir


func _has_flag(name: String) -> bool:
    return OS.get_cmdline_user_args().has(name)


func _arg(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == name and i + 1 < args.size():
            return args[i + 1]
    return fallback


func _git_head() -> String:
    var out: Array = []
    if OS.execute("git", ["rev-parse", "--short", "HEAD"], out, true) != 0:
        return "unknown"
    return str(out[0]).strip_edges()
