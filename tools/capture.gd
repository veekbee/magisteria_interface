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
        _apply_hiding(view)
        stage = 1
        frames = 0
        return false
    if stage - 1 < days.size():
        var day: int = days[stage - 1]
        if frames == 1:
            _set_state(view, day)
            return false
        if frames < 6:
            return false
        _shoot(view, day)
        stage += 1
        frames = 0
        return false
    _report()
    quit(0)
    return true


## Hide whole layers, so a capture isolates one thing rather than leaving the
## measurement to guess which pixels belonged to what.
func _apply_hiding(view) -> void:
    for what in hide:
        match what:
            "ui":
                if scene.has_node("UI"):
                    scene.get_node("UI").queue_free()
            "terrain":
                view.get_node("Terrain").visible = false
            "flowlines":
                for c in view.get_children():
                    if String(c.name).begins_with("Flow"):
                        c.visible = false
            "vegetation":
                for c in view.get_children():
                    if String(c.name).begins_with("Vegetation"):
                        c.visible = false
            "contours":
                var n = view.get_node_or_null("Contours")
                if n != null:
                    n.visible = false
            _:
                push_warning("capture: nothing named %s to hide" % what)


func _set_state(view, day: int) -> void:
    var fixture = view.fixture
    var w: String = window_name if window_name != "" else str(fixture.windows[0])
    var rows: PackedStringArray = fixture.row_names(w)
    var r: String = row_name if row_name != "" else str(rows[0])
    if not Array(rows).has(r):
        printerr("capture: %s carries no row %s; it has %s" % [w, r, str(rows)])
        quit(2)
        return
    # the application's own path, so a capture cannot diverge from a scrub
    scene._on_field_changed(w, r, day, 0)
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


func _shoot(view, day: int) -> void:
    var img := get_root().get_texture().get_image()
    var name: String = "%s_%s_day%02d" % [
            (window_name if window_name != "" else "window"),
            (row_name if row_name != "" else "row").replace(".", "_"), day]
    var path := "res://%s/%s.png" % [out_dir, name]
    img.save_png(path)
    captured.append({"tag": name, "image": img, "path": path})
    print("shot %s -> %s" % [FrameProbe.one_line(name, FrameProbe.summarise(img)), path])


func _report() -> void:
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
    print("compare %s vs %s: %.2f%% of pixels differ; over those, green-minus-red %+.3f -> %+.3f"
            % [first["tag"], last["tag"], 100.0 * float(d["differing_fraction"]),
               float(d["green_minus_red_a"]), float(d["green_minus_red_b"])])


func _arg(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == name and i + 1 < args.size():
            return args[i + 1]
    return fallback


func _has(name: String) -> bool:
    return OS.get_cmdline_user_args().has(name)
