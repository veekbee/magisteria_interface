extends SceneTree

## Drive the running application to a described state and photograph it.
##
##     bash tools/screenshot.sh --row band.pft.biomass --days 22,89 --scatter
##
## WHY THIS EXISTS. The headless suite verifies data end to end and cannot see
## the screen. Three defects reached main past 1,800 passing checks -- terrain
## wound inside-out and never drawn, a phenology mask that never reached its
## shader, nodata rendering as black -- and each was found by rendering
## something and looking. This makes that repeatable: a state described on the
## command line, a PNG, and a colour census printed beside it so a finding can
## be quoted rather than gestured at.
##
## IT REFUSES HEADLESS, for the reason the frame-cost benchmark refuses:
## `--headless` draws nothing and reports success, so a capture there is a
## picture of an empty stub that looks exactly like a picture of a bug.
##
## IT DRIVES THE APPLICATION'S OWN PATHS. The day is changed through main's
## `_on_field_changed`, which is what the scrubber calls; the scatter goes
## through `probe_at_screen` and `_on_probed`, which is what a click calls.
## A capture that set up its own scene would photograph a scene nobody runs.

const SETTLE_FRAMES := 10

## Every layer this tool knows how to show or hide by name. Named in one place
## so `--only` and `--hide` cannot drift apart, and so an unknown name is a
## warning rather than a silent no-op.
const LAYERS := ["ui", "terrain", "flowlines", "vegetation", "contours"]

var scene: Node = null
var frames := 0
var stage := 0
var shots: Array = []
var captured: Array = []

var out_dir := "shots"
var window_name := ""
var row_name := ""
var days: Array = []
var want_scatter := false
## The world point the first scatter landed on, reused for every later day.
var scatter_world := Vector2.ZERO
var have_scatter_world := false
var hide: PackedStringArray = PackedStringArray()
var only: PackedStringArray = PackedStringArray()
var no_field := false
## Seam candidate #1's view: the far field as a per-cell tint rather than as
## instances. Off is data view, which is what M2 built.
var natural := false
## Sun azimuths to photograph. More than one turns the light between shots,
## which is the only way to tell a LIT surface from a baked shade map: move the
## light, and only one of the two changes.
var suns: Array = [NAN]
## day x sun, in the order they are shot. One entry per day when no sun is
## given, so the default path is exactly what it was.
var steps: Array = []
var want_camera := ""
## `--backdrop black` clears to black so the sky falls under FrameProbe's
## near-black class and drops out of every measurement. Without it the default
## grey backdrop is most of the frame, and a relief spread reported over the
## whole picture is mostly a statement about the sky.
var backdrop := ""
## A PNG from an EARLIER RUN to compare the last shot against. The in-run
## comparison can only vary what a command line can vary -- a day, a light, a
## layer. It cannot vary the CODE, and "does this change move the picture" is
## the question a capture is most often asked. Two runs and this flag answer
## it; one run cannot.
var compare_path := ""


func _initialize() -> void:
    if DisplayServer.get_name() == "headless":
        printerr("capture: the display server is 'headless', which draws nothing and would "
                + "photograph an empty stub. Run through tools/screenshot.sh, which does "
                + "not pass --headless.")
        quit(2)
        return
    out_dir = _arg("--out", out_dir)
    window_name = _arg("--window", "")
    row_name = _arg("--row", "")
    want_scatter = _has("--scatter")
    for d in _arg("--days", "45").split(","):
        days.append(int(d))
    for h in _arg("--hide", "").split(","):
        if h != "":
            hide.append(h)
    for o in _arg("--only", "").split(","):
        if o != "":
            only.append(o)
    no_field = _has("--no-field")
    natural = _has("--natural")
    want_camera = _arg("--camera", "")
    compare_path = _arg("--compare", "")
    backdrop = _arg("--backdrop", "")
    if backdrop == "black":
        RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
    elif backdrop != "":
        push_warning("capture: --backdrop takes 'black'; %s is not a backdrop" % backdrop)
    if _has("--sun"):
        suns = []
        for a in _arg("--sun", "135").split(","):
            suns.append(float(a))
    for d in days:
        for a in suns:
            steps.append({"day": int(d), "sun": float(a)})
    var size := _arg("--size", "1280x800").split("x")
    DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
    # The window must be on screen and drawn: an occluded one on this platform
    # stops rendering while the main loop keeps running, which the frame-cost
    # benchmark learned the expensive way.
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
    DisplayServer.window_move_to_foreground()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://") + out_dir)

    scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    get_root().add_child(scene)


func _process(_delta: float) -> bool:
    frames += 1
    var view = scene.get_node("TerrainView")
    # The settle wait belongs to the FIRST stage only. Above the stage machine
    # it swallowed every per-day frame count too, so `_set_state` was never
    # reached and every shot photographed the scene's opening state -- two
    # captures of different days came back byte-identical, which is the one
    # result this tool must never produce quietly.
    if stage == 0:
        if frames < SETTLE_FRAMES:
            return false
        _say_verdict()
        if natural:
            # The application's own switch, exaggeration and all: this is a
            # photograph of the viewer, not a measurement holding a variable.
            view.set_naturalistic(true)
        _choose_camera(view)
        stage = 1
        frames = 0
        return false
    if stage - 1 < steps.size():
        var step: Dictionary = steps[stage - 1]
        if frames == 1:
            _aim_sun(view, float(step["sun"]))
            _set_state(view, int(step["day"]))
            # AFTER the state, never only before it. `Contours` and every
            # `Vegetation_*` node is CREATED by the state change and made
            # visible by it, so a visibility pass that ran once at startup
            # hid layers that did not exist yet and left the ones it was
            # asked to hide on screen. `--only contours` photographed the
            # whole basin, and looked like a contour layer covering it.
            _apply_visibility(view)
            return false
        if frames < 6:
            return false
        _shoot(view, step)
        stage += 1
        frames = 0
        return false
    _report()
    quit(0)
    return true


## The picture's own disclaimer. Printed beside every capture because the
## basin drawn here is an ancestor trace that fails several of the criteria the
## model is held to, and a screenshot with no verdict on it is the one that
## gets quoted later as a picture of the model working.
func _say_verdict() -> void:
    var v: AncestorVerdict = scene.verdict
    if v == null:
        print("verdict: the scene reported none, which is itself undisclaimed")
        return
    print("verdict: %s" % v.headline())
    for f in v.named_fails():
        print("verdict:   %s" % f)


## Turn the hillshade. A light that can be moved is how you tell a lit surface
## from a baked shade map: move it, and only one of them changes.
func _aim_sun(view, degrees: float) -> void:
    if is_nan(degrees):
        return
    var sun = view.get_node_or_null("Hillshade")
    if sun == null:
        push_warning("capture: no Hillshade light to aim")
        return
    sun.rotation_degrees = Vector3(-45.0, degrees, 0.0)
    print("state  sun azimuth %.0f deg" % degrees)


func _choose_camera(view) -> void:
    if want_camera == "" or view.rig == null:
        return
    var want_ortho := want_camera == "ortho"
    if view.rig.using_ortho() != want_ortho:
        view.rig.toggle()      # the key the viewer presses, not a private field


## Show or hide whole layers, so a capture isolates one thing rather than
## leaving the measurement to guess which pixels belonged to what.
##
## `--only` wins over `--hide` and is usually what you want: naming the four
## layers you did not want is how a new layer arrives on screen in the middle
## of a shot that was supposed to contain one thing.
func _apply_visibility(view) -> void:
    for what in hide:
        if not LAYERS.has(what):
            push_warning("capture: nothing named %s to hide; layers are %s" % [what, str(LAYERS)])
    for what in only:
        if not LAYERS.has(what):
            push_warning("capture: nothing named %s to show; layers are %s" % [what, str(LAYERS)])
    if only.is_empty() and hide.is_empty():
        return
    for layer in LAYERS:
        var want: bool = only.has(layer) if not only.is_empty() else not hide.has(layer)
        for n in _nodes_for(view, layer):
            n.visible = want


## The nodes a layer name stands for. Matched by name because that is what the
## scene actually has: the flow mesh and the order-coloured lines are separate
## nodes for one river network, and a capture asked to hide "flowlines" that
## hid only one of them would photograph the rivers it was told to remove.
func _nodes_for(view, layer: String) -> Array:
    var out: Array = []
    match layer:
        "ui":
            if scene.has_node("UI"):
                out.append(scene.get_node("UI"))
        "terrain":
            var t = view.get_node_or_null("Terrain")
            if t != null:
                out.append(t)
        "flowlines":
            for c in view.get_children():
                if String(c.name).begins_with("Flow"):
                    out.append(c)
        "vegetation":
            for c in view.get_children():
                if String(c.name).begins_with("Vegetation"):
                    out.append(c)
        "contours":
            var n = view.get_node_or_null("Contours")
            if n != null:
                out.append(n)
    return out


func _set_state(view, day: int) -> void:
    # M1's claim is about a LIT SURFACE, and a painted field covers it: the
    # overlay replaces the terrain's albedo, so relief measured through it is
    # measuring the ramp. Clearing the field is how the hillshade becomes the
    # only thing in the frame that varies.
    if no_field:
        view.clear_field()
        print("state  no field painted: the terrain carries its own albedo")
        return
    var fixture = view.fixture
    var w: String = window_name if window_name != "" else str(fixture.windows[0])
    var rows: PackedStringArray = fixture.row_names(w)
    var r: String = row_name if row_name != "" else str(rows[0])
    if not Array(rows).has(r):
        printerr("capture: %s carries no row %s; it has %s" % [w, r, str(rows)])
        quit(2)
        return
    # THROUGH THE SCRUBBER, which is the application's own path all the way out
    # to the controls. Calling main's `_on_field_changed` painted the terrain
    # and left the widgets reading whatever they had been reading, so a
    # composite shot carried a caption that contradicted its own picture.
    if scene.scrubber != null:
        var set_to: Dictionary = scene.scrubber.select(w, r, day)
        if not bool(set_to["ok"]):
            printerr("capture: %s" % str(set_to["why"]))
            quit(2)
            return
    else:
        scene._on_field_changed(w, r, day, 0)
    if natural:
        var vr: Dictionary = view.view_report
        if not vr.is_empty():
            print("view   exaggeration %.0fx -> %.0fx in %.0f ms (mesh %.0f, drape %.0f, "
                    % [float(vr["from"]), float(vr["to"]), float(vr["total_ms"]),
                       float(vr["mesh_ms"]), float(vr["flowline_drape_ms"])]
                    + "flow+contours %.0f, scatter %.0f)"
                    % [float(vr["flow_and_contours_ms"]), float(vr["scatter_ms"])])
        var tr: Dictionary = view.tint_report
        if bool(tr.get("ok", false)):
            print("tint   %d/%d cells covered, mean cover %.3f, rebuild %.0f ms (cells %.0f ms)"
                    % [int(tr["cells_with_cover"]), int(tr["cells"]),
                       float(tr["mean_cover_where_covered"]), float(tr.get("rebuild_ms", NAN)),
                       float(tr.get("cells_ms", NAN))])
        else:
            print("tint   FAILED: %s" % str(tr.get("why", "?")))
    if not want_scatter:
        return
    # THE PLACE IS HELD CONSTANT ACROSS DAYS. Probing the screen centre again
    # on each day samples wherever the camera has since moved to, so two days
    # come back from two different hillsides and the difference between them is
    # geography rather than season. The first probe fixes the point; the rest
    # re-scatter there. Found by this tool reporting that day 22 was greener
    # than day 89, which is backwards.
    var probe: Dictionary
    if have_scatter_world:
        probe = view.probe_world(scatter_world.x, scatter_world.y)
    else:
        var cam := get_root().get_camera_3d()
        probe = view.probe_at_screen(cam, get_root().get_visible_rect().size * 0.5)
        if probe.has("world"):
            scatter_world = probe["world"]
            have_scatter_world = true
    scene._on_probed(probe)
    if not have_scatter_world:
        push_warning("capture: the centre of the view is not on the terrain; nothing scattered")
        return
    view.focus_on_scatter()
    # THE STATE ACHIEVED, NOT THE STATE ASKED FOR. A capture that reports only
    # pixels leaves the reader to assume the scene reached the state named on
    # the command line; when it silently does not, the pixels are a picture of
    # something else entirely and nothing says so.
    var sr: Dictionary = scene.scatter_report
    if bool(sr.get("ok", false)):
        print("state  probe=%s  scatter day=%d  phenology=%s  placed=%s"
                % [str(probe.get("state", "?")), int(sr["day"]),
                   str(sr["phenology"]["range_drawn"]), str(sr["placed"])])
    else:
        print("state  probe=%s  scatter FAILED: %s"
                % [str(probe.get("state", "?")), str(sr.get("why", "?"))])


func _shoot(view, step: Dictionary) -> void:
    var img := get_root().get_texture().get_image()
    var name: String = "%s_%s_day%02d" % [
            (window_name if window_name != "" else "window"),
            (row_name if row_name != "" else "row").replace(".", "_"), int(step["day"])]
    if suns.size() > 1:
        name += "_sun%03d" % int(step["sun"])
    var path := "res://%s/%s.png" % [out_dir, name]
    img.save_png(path)
    captured.append({"tag": name, "image": img, "path": path})
    print("shot %s -> %s" % [FrameProbe.one_line(name, FrameProbe.summarise(img)), path])
    var lum := FrameProbe.luminance(img)
    if int(lum["counted"]) == 0:
        print("relief THE FRAME IS BLACK: %s" % str(lum["why"]))
    else:
        print("relief %d brightness levels, p05 %.3f p50 %.3f p95 %.3f, spread %.3f over %d px"
                % [int(lum["levels"]), float(lum["p05"]), float(lum["p50"]),
                   float(lum["p95"]), float(lum["spread"]), int(lum["counted"])])
    # ONLY WHERE THE RAMP IS THE SUBJECT. `FieldOverlay.RAMP_STOPS` colours the
    # terrain and nothing else: the flowlines carry FlowDisplay's ramp and the
    # contours are white. Reporting an agreement figure over a frame of rivers
    # would be measuring them against a ramp they were never drawn from, and a
    # low number there would read as a defect rather than as the wrong question.
    if no_field or not _layer_visible(view, "terrain"):
        print("ramp   not measured: the overlay ramp is not what this frame is of")
        return
    var ramp := FrameProbe.ramp_agreement(img, FieldOverlay.RAMP_STOPS)
    if int(ramp["coloured"]) == 0:
        print("ramp   %s" % str(ramp["why"]))
    else:
        # Over EVERY coloured pixel in the frame, which is only the overlay
        # when the overlay is the only thing drawn: a composite carries the
        # flow ramp and the white contours too, and they are not this ramp.
        print("ramp   %.1f%% of %d coloured px lie on the overlay ramp, mean distance %.3f, worst %.3f"
                % [100.0 * float(ramp["on_ramp_fraction"]), int(ramp["coloured"]),
                   float(ramp["mean_distance"]), float(ramp["worst_distance"])])


func _report() -> void:
    if compare_path != "":
        _compare_against_file()
    if captured.size() < 2:
        return
    # Two frames of one subject differ wherever geometry moved. The question is
    # always whether they differ the way the change was meant to make them.
    var first: Dictionary = captured[0]
    var last: Dictionary = captured[captured.size() - 1]
    var d := FrameProbe.compare(first["image"], last["image"])
    if not bool(d["ok"]):
        print("compare: %s" % str(d["why"]))
        return
    if int(d["differing"]) == 0:
        print("compare %s vs %s: THE TWO FRAMES ARE IDENTICAL. Either the state did not "
                % [first["tag"], last["tag"]] + "change, or the thing it changes is not "
                + "drawn. Both are findings; neither is a picture of a difference.")
        return
    var ma: Array = d["mean_a"]
    var mb: Array = d["mean_b"]
    print("compare %s vs %s: %.2f%% of pixels differ; over those, green-minus-red %+.3f -> %+.3f, "
            % [first["tag"], last["tag"], 100.0 * float(d["differing_fraction"]),
               float(d["green_minus_red_a"]), float(d["green_minus_red_b"])]
            + "mean brightness %.3f -> %.3f"
            % [_luma(ma), _luma(mb)])


## Against a frame from a previous run, so a code change can be photographed.
func _compare_against_file() -> void:
    if captured.is_empty():
        return
    var prior := Image.load_from_file(compare_path)
    if prior == null:
        printerr("capture: could not read %s to compare against" % compare_path)
        return
    var last: Dictionary = captured[captured.size() - 1]
    var d := FrameProbe.compare(prior, last["image"])
    if not bool(d["ok"]):
        print("against %s: %s" % [compare_path, str(d["why"])])
        return
    if int(d["differing"]) == 0:
        print("against %s: IDENTICAL. Whatever changed between the two runs did not "
                % compare_path + "reach the frame -- which is a finding, not a null result.")
        return
    var pa: Dictionary = FrameProbe.summarise(prior)
    var pb: Dictionary = FrameProbe.summarise(last["image"])
    print("against %s: %.2f%% of pixels differ; near-black %d -> %d px; coloured %d -> %d px"
            % [compare_path, 100.0 * float(d["differing_fraction"]),
               int(pa["near_black"]), int(pb["near_black"]),
               int(pa["coloured"]), int(pb["coloured"])])
    print("        over the differing pixels, mean brightness %.3f -> %.3f, g-r %+.3f -> %+.3f"
            % [_luma(d["mean_a"]), _luma(d["mean_b"]),
               float(d["green_minus_red_a"]), float(d["green_minus_red_b"])])


## A flipped light redistributes brightness across a surface without changing
## much of its average, so this number is here to be READ ALONGSIDE the
## differing count rather than instead of it: unchanged mean over a fifth of
## the frame differing is what a moved light looks like.
func _layer_visible(view, layer: String) -> bool:
    for n in _nodes_for(view, layer):
        if n.visible:
            return true
    return false


func _luma(c: Array) -> float:
    return 0.2126 * float(c[0]) + 0.7152 * float(c[1]) + 0.0722 * float(c[2])


func _arg(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == name and i + 1 < args.size():
            return args[i + 1]
    return fallback


func _has(name: String) -> bool:
    return OS.get_cmdline_user_args().has(name)
