class_name ConsoleVerbs
extends RefCounted

## What the three prefixes actually do. A BINDING OVER THE TOOLS THAT EXIST,
## not a second implementation of any of them: the probes call the scatter's
## own statics, and a console-launched measurement writes the artefact the
## shell tool writes so a console session stays gate-replayable.
##
## EVERY VERB TAKES ITS POINT FROM THE RETICLE OR FROM ARGUMENTS. That is not a
## convenience: with a point in the arguments the whole probe set runs
## headlessly, which is what lets the gate drive the console rather than trust
## it.

var view: TerrainView = null
var console: DevConsole = null
var body: DebugPlayer = null
var instances: InstanceProbe = null

## THE MEASUREMENT TOOLS, LAUNCHED AND NOT REIMPLEMENTED.
##
## A console-launched measurement has to emit the same artefact as the shell
## tool, and the only way to be certain of that is to run the same program.
## Every one of these is an `extends SceneTree` script that cannot be called
## in-process, so a console binding would otherwise be a second implementation
## of the measurement -- which is how two numbers with one name come to exist.
## Shelling out is not a shortcut here; it is the strongest available form of
## "the same measurement".
const MEASUREMENTS := {
    "seam": ["tools/measure_seam.sh", "measurements/scatter_seam.json"],
    "motion": ["tools/measure_motion.sh", "measurements/scatter_motion.json"],
    "scatter": ["tools/measure_scatter.sh", "measurements/scatter_horizon.json"],
    "bands": ["tools/measure_bands.sh", "measurements/scatter_bands.json"],
    "flight": ["tools/free_flight.sh", "measurements/flights/"],
    "replay": ["tools/replay_flight.sh", "measurements/flight_replay.json"],
}


func bind(console_: DevConsole, view_: TerrainView) -> void:
    console = console_
    view = view_
    instances = InstanceProbe.new()
    instances.bind(view.scatter, view.heightfield, view.fixture, view.cell_probe())

    console.register("view.mode", "data | naturalistic", _view_mode)
    console.register("view.where", "the camera, the reticle, and what is drawn", _view_where)
    console.register("view.capture", "<name> -- a png in shots/", _view_capture)
    console.register("view.embody", "stand a debug body at the reticle", _view_embody)
    console.register("view.disembody", "back to the free dev camera", _view_disembody)


    console.register("probe.cell", "[x y] -- the cell under the reticle", _probe_cell)
    console.register("probe.row", "<row> [x y] -- any carried row here", _probe_row)
    console.register("probe.sub", "<family> [x y] -- the sub-cell's candidates", _probe_sub)
    console.register("probe.instance", "<family> [x y] -- the whole chain", _probe_instance)
    console.register("probe.survive", "<family> <dx> <dy> [x y] -- across a re-centre",
            _probe_survive)
    console.register("probe.percept", "<family> [x y] -- the min(), two columns", _probe_percept)
    console.register("probe.pin", "what this client is standing on", _probe_pin)

    # POSTURE IS A `world.*` VERB AND NOT A `view.*` ONE, on a discriminator
    # worth keeping: in a production player, changing posture is an ACTION THE
    # BODY TAKES -- it goes to B and changes what B reports back, the
    # observation point and the locomotion envelope among it. That is not
    # A-side. A `view.*` verb that would have to become a B-side action the day
    # a real producer exists is in the wrong prefix now, and today it is
    # exactly what `world.*` is for: a dev endpoint writing stub-B state, which
    # does not exist client-side in production.
    #
    # `view.embody` stays A-side. Switching between the three pinned view modes
    # -- dev camera, debug player, player -- is a view-mode change and stays
    # legitimate forever.
    console.register("world.posture", "standing | crouched | prone", _world_posture)
    console.register("world.day", "<n> -- move the moment", _world_day)
    console.register("world.rebuild", "[radius] -- rebuild the scatter here", _world_rebuild)
    console.register("world.reload", "re-read the fixture from disk", _world_reload)
    console.register("world.measure", "<%s> -- run a measurement tool"
            % "|".join(Array(MEASUREMENTS.keys())), _world_measure)


## The point a verb is about: the two arguments if they are there, otherwise
## wherever the reticle is pointing.
func _point(args: PackedStringArray, from: int = 0) -> Dictionary:
    if args.size() >= from + 2:
        return {"ok": true, "world": Vector2(args[from].to_float(), args[from + 1].to_float()),
                "from": "arguments"}
    if view == null:
        return {"ok": false, "why": "no view"}
    var cam := view.get_viewport().get_camera_3d() if view.is_inside_tree() else null
    if cam == null:
        return {"ok": false, "why": ("no camera, so no reticle. Name a point: `<verb> x y` in "
                + "EPSG:5070 metres -- which is also how this runs headlessly.")}
    var size := view.get_viewport().get_visible_rect().size
    var hit := view.probe_at_screen(cam, size * 0.5)
    if not hit.has("world"):
        return {"ok": false, "why": str(hit.get("why", "the reticle is not on the basin"))}
    return {"ok": true, "world": hit["world"], "from": "the reticle"}


# -- view.* ------------------------------------------------------------------

func _view_mode(args: PackedStringArray) -> PackedStringArray:
    if args.is_empty():
        return PackedStringArray(["mode is %s"
                % ("naturalistic" if view.naturalistic else "data")])
    view.set_naturalistic(str(args[0]).begins_with("n"))
    return PackedStringArray(["mode is %s"
            % ("naturalistic" if view.naturalistic else "data")])


func _view_where(_args: PackedStringArray) -> PackedStringArray:
    var out := PackedStringArray()
    var p := _point(PackedStringArray())
    out.append("reticle: %s" % ("(%s, %s)" % [String.num((p["world"] as Vector2).x, 1),
            String.num((p["world"] as Vector2).y, 1)] if bool(p["ok"]) else str(p["why"])))
    out.append("drawn: %s" % str(view.shown))
    if body != null:
        out.append("body: %s at %s, eyes at %s" % [body.posture, str(body.ground),
                str(DebugPlayer.camera_position(view.bundle))])
    return out


func _view_capture(args: PackedStringArray) -> PackedStringArray:
    if DisplayServer.get_name() == "headless":
        return PackedStringArray(["headless: there is no frame to capture. This is a refusal, "
                + "not a failure -- a captured black rectangle is worse than no file."])
    var name := "console" if args.is_empty() else str(args[0])
    var path := "res://shots/%s.png" % name
    var img := view.get_viewport().get_texture().get_image()
    var err := img.save_png(ProjectSettings.globalize_path(path))
    return PackedStringArray(["%s %s" % ["wrote" if err == OK else "could not write", path]])


func _view_embody(args: PackedStringArray) -> PackedStringArray:
    var p := _point(args)
    if not bool(p["ok"]):
        return PackedStringArray([str(p["why"])])
    var w: Vector2 = p["world"]
    var elevation := view.heightfield.height_at_world(w.x, w.y)
    body = DebugPlayer.new()
    body.ground = PackedFloat64Array([w.x, 0.0 if is_nan(elevation) else elevation, w.y])
    body.flying = true
    view.observer = body.observer()
    var walk := DebugPlayer.walk_available(view.bundle,
            view.heightfield.pixel_size_m * float(view.terrain.stride),
            TerrainView.SCATTER_HORIZON_M)
    var out := PackedStringArray()
    out.append("a %s body stands at (%s, %s)" % [body.posture,
            String.num(w.x, 1), String.num(w.y, 1)])
    var speed := DebugPlayer.speed_from(view.bundle)
    out.append("it moves at %s" % ("%s m/s, from the bundle" % String.num(float(speed["m_s"]), 2)
            if bool(speed["ok"]) else str(speed["why"])))
    out.append("walk mode: %s" % ("available" if bool(walk["ok"]) else str(walk["why"])))
    var relief: Dictionary = walk["near_field_is_relief"]
    out.append("near field: %s" % ("relief -- about %s ground samples inside %s m"
            % [String.num(float(relief["samples_in_near_field"]), 0),
                    String.num(float(relief["near_field_radius_m"]), 0)]
            if bool(relief["ok"]) else str(relief["why"])))
    return out


func _view_disembody(_args: PackedStringArray) -> PackedStringArray:
    body = null
    return PackedStringArray(["free dev camera. No observer, and the fixture is truth again -- "
            + "which is a stance, not an absence of one."])


# -- probe.* -----------------------------------------------------------------

func _probe_cell(args: PackedStringArray) -> PackedStringArray:
    var p := _point(args)
    if not bool(p["ok"]):
        return PackedStringArray([str(p["why"])])
    var w: Vector2 = p["world"]
    var vals := PackedFloat64Array()
    if not view.shown.is_empty():
        vals = view.fixture.day_values(str(view.shown["window"]), str(view.shown["row"]),
                int(view.shown["day"]), int(view.shown["group"]))
    var r := view.cell_probe().at_world(w.x, w.y, vals)
    var out := PackedStringArray()
    out.append("point   (%s, %s) from %s" % [String.num(w.x, 1), String.num(w.y, 1),
            str(p["from"])])
    out.append("state   %s" % str(r.get("state", "?")))
    if str(r.get("state", "")) != CellProbe.RESOLVED:
        out.append("        %s" % str(r.get("why", "")))
        return out
    out.append("cell    %s band %d -> cell %d (node axis %d)" % [str(r.get("huc10", "?")),
            int(r.get("band", -1)), int(r.get("cell", -1)), int(r.get("node_axis", -1))])
    out.append("ground  %s m" % String.num(float(r.get("elevation_m", NAN)), 1))
    if bool(r.get("has_value", false)):
        out.append("%s = %s (%s day %d)" % [str(view.shown["row"]),
                String.num(float(r["value"]), 6), str(view.shown["window"]),
                int(view.shown["day"])])
    else:
        out.append("value   %s" % str(r.get("why", "no row drawn")))
    return out


func _probe_row(args: PackedStringArray) -> PackedStringArray:
    if args.is_empty():
        return PackedStringArray(["probe.row <row> [x y]. Rows here: %s"
                % str(view.fixture.row_names(str(view.shown.get("window",
                        view.fixture.windows[0]))))])
    var row := str(args[0])
    var p := _point(args, 1)
    if not bool(p["ok"]):
        return PackedStringArray([str(p["why"])])
    var w: Vector2 = p["world"]
    var window := str(view.shown.get("window", view.fixture.windows[0]))
    var day := int(view.shown.get("day", 0))
    var groups := view.fixture.taxon_groups(window, row)
    var out := PackedStringArray()
    out.append("%s  %s day %d" % [row, window, day])
    if groups.is_empty():
        groups = PackedStringArray([""])
    for gi in groups.size():
        var vals := view.fixture.day_values(window, row, day, gi)
        var r := view.cell_probe().at_world(w.x, w.y, vals)
        var label := "" if str(groups[gi]) == "" else " [%s]" % str(groups[gi])
        if bool(r.get("has_value", false)):
            out.append("  %s%s" % [String.num(float(r["value"]), 6), label])
        else:
            out.append("  %s%s" % [str(r.get("why", str(r.get("state", "?")))), label])
    return out


func _sub_lines(sub: Dictionary) -> PackedStringArray:
    var out := PackedStringArray()
    out.append("texel   %s   sub-cell %s of %d, half %s m" % [str(sub["texel"]),
            str(sub["sub_cell"]), VegetationScatter.BAND_SUBDIVISION,
            String.num(float(sub["half_m"]), 2)])
    # THE COMPOSITION ARITHMETIC, PRINTED. Reading a share as a cover is the
    # mistake this line exists to make impossible to repeat.
    out.append("cover   share %s x (1 - bare %s) = %s" % [
            String.num(float(sub["share"]), 5),
            String.num(float(sub["bare_fraction"]), 5),
            String.num(float(sub["cover"]), 5)])
    if str(sub["state"]) == InstanceProbe.NOT_IMPLIED:
        out.append("state   NOT_IMPLIED -- %s" % str(sub.get("why", "")))
        return out
    out.append("form    %s m tall, %s m crown -> %s per texel, %s per sub-cell" % [
            String.num(float(sub["height_m"]), 2), String.num(float(sub["crown_m"]), 2),
            String.num(float(sub["implied_per_texel"]), 0),
            String.num(float(sub["implied_per_sub_cell"]), 3)])
    if str(sub["state"]) == InstanceProbe.NOT_BUILT:
        out.append("state   NOT_BUILT -- %s" % str(sub.get("why", "")))
        return out
    out.append("horizon k %s -> %s m; this sub-cell is %s m from the build centre (margin %s m)"
            % [String.num(float(sub["individuation_k"]), 3),
                    String.num(float(sub["horizon_m"]), 1),
                    String.num(float(sub["distance_from_build_centre_m"]), 1),
                    String.num(float(sub["horizon_margin_m"]), 1)])
    out.append("draw    keep %s x share %s -> %d of a %d-deep pool" % [
            String.num(float(sub["density_keep"]), 4),
            String.num(float(sub["share_drawn"]), 6), int(sub["drawn"]), int(sub["pool"])])
    out.append("key     %d" % int(sub["placement_key"]))
    return out


func _probe_sub(args: PackedStringArray) -> PackedStringArray:
    if args.is_empty():
        return PackedStringArray(["probe.sub <family> [x y]"])
    var p := _point(args, 1)
    if not bool(p["ok"]):
        return PackedStringArray([str(p["why"])])
    var sub := instances.sub_at(p["world"], str(args[0]))
    if not bool(sub.get("ok", false)):
        return PackedStringArray([str(sub.get("state", "")), str(sub.get("why", ""))])
    var out := _sub_lines(sub)
    var cands := instances.candidates_in(sub, 12)
    for c in cands:
        var pos: Vector2 = c["position_m"]
        out.append("  rank %-4d candidate %-8d (%s, %s)  %s" % [int(c["rank"]),
                int(c["candidate"]), String.num(pos.x, 1), String.num(pos.y, 1),
                str(c["state"])])
    if cands.is_empty():
        out.append("  no candidates: the pool is empty here")
    return out


func _probe_instance(args: PackedStringArray) -> PackedStringArray:
    if args.is_empty():
        return PackedStringArray(["probe.instance <family> [x y]"])
    var p := _point(args, 1)
    if not bool(p["ok"]):
        return PackedStringArray([str(p["why"])])
    var family := str(args[0])
    var r := instances.nearest(p["world"], family)
    if not bool(r.get("ok", false)):
        return PackedStringArray([str(r.get("state", "")), str(r.get("why", ""))])
    var out := _sub_lines(r)
    if r.has("rank"):
        var pos: Vector2 = r["position_m"]
        out.append("plant   rank %d of %d, candidate %d" % [int(r["rank"]), int(r["pool"]),
                int(r["candidate"])])
        out.append("        re-derived at (%s, %s), %s m from the probe" % [
                String.num(pos.x, 2), String.num(pos.y, 2),
                String.num(float(r["distance_from_probe_m"]), 2)])
        out.append("        named by (key, rank) and not by an index -- it is the same plant "
                + "after a rebuild")
    out.append("state   %s%s" % [str(r["state"]),
            "" if str(r.get("why", "")) == "" else " -- " + str(r["why"])])
    out.append_array(_percept_lines(family, r))
    return out


func _percept_lines(family: String, r: Dictionary) -> PackedStringArray:
    var has_asset := view.families != null and view.families.has(family)
    # Affordable is the finest rung this client could draw; earned is null
    # because nothing earns anything yet; rendered is what is actually on
    # screen, which is every plant at its life form.
    var percept := PerceptProbe.evaluate("specific", null, has_asset, "life_form")
    var out := PackedStringArray(["percept"])
    out.append_array(PerceptProbe.lines(percept))
    out.append("  the whole world is drawn at the life-form rung today: four family "
            + "archetypes, no species assets.")
    return out


func _probe_percept(args: PackedStringArray) -> PackedStringArray:
    if args.is_empty():
        return PackedStringArray(["probe.percept <family> [x y]"])
    var p := _point(args, 1)
    if not bool(p["ok"]):
        return PackedStringArray([str(p["why"])])
    var family := str(args[0])
    return _percept_lines(family, instances.nearest(p["world"], family))


func _probe_survive(args: PackedStringArray) -> PackedStringArray:
    if args.size() < 3:
        return PackedStringArray(["probe.survive <family> <dx> <dy> [x y]"])
    var p := _point(args, 3)
    if not bool(p["ok"]):
        return PackedStringArray([str(p["why"])])
    var r := instances.survives(p["world"], str(args[0]),
            args[1].to_float(), args[2].to_float())
    if not bool(r.get("ok", false)):
        return PackedStringArray([str(r.get("state", "")), str(r.get("why", ""))])
    var out := PackedStringArray()
    out.append("was     %s at rank %s" % [str(r["was"]), str(r.get("rank", "?"))])
    out.append("key     %d -> %d" % [int(r["key_before"]), int(r["key_after"])])
    out.append("verdict %s%s" % [str(r["verdict"]),
            "" if str(r.get("why", "")) == "" else " -- " + str(r["why"])])
    return out


func _probe_pin(_args: PackedStringArray) -> PackedStringArray:
    var out := PackedStringArray()
    var f := FileAccess.open("res://contract/PIN", FileAccess.READ)
    if f != null:
        var pin = JSON.parse_string(f.get_as_text())
        if typeof(pin) == TYPE_DICTIONARY:
            var d: Dictionary = pin
            var v: Dictionary = d.get("version", {})
            out.append("contract v%s.%s  sha256 %s" % [str(v.get("major", "?")),
                    str(v.get("minor", "?")), str(d.get("file_sha256", "?")).substr(0, 16)])
            out.append("  emitted at   %s" % str(d.get("emitted_at_commit", "?")))
            out.append("  committed at %s" % str(d.get("artefact_committed_at", "?")))
            out.append("  (the two are different questions: which tree the emitter read, and "
                    + "where the bytes came to rest)")
    var man: Dictionary = view.fixture.manifest
    out.append("fixture  %s" % str(man.get("run", man.get("trace", "unnamed"))))
    out.append("windows  %s" % str(Array(view.fixture.windows)))
    var tp := TilePyramid.load_from()
    if tp.is_loaded():
        var inv := tp.inventory()
        out.append("tiles    %d keyed, %d present, %d not fetched; finest %s m, z=0 is finest"
                % [int(inv["keyed"]), int(inv["present"]), int(inv["not_fetched"]),
                        String.num(float(inv["finest_pixel_size_m"]), 0)])
        out.append("  encoding offset %s scale %s -- NOT the overview's; a clipped code is a "
                % [String.num(tp.offset_m, 6), String.num(tp.scale_m, 9)]
                + "valid code, so decoding a tile with the overview's pair fails silently")
        out.append("  host_base %s" % ("set" if tp.host_base != "" else "NOT SET (a valid clone)"))
    else:
        out.append("tiles    %s" % tp.why_absent)
    if view.bundle != null:
        out.append("producer %s  %s" % [str(view.bundle.producer.get("kind", "?")),
                str(view.bundle.producer.get("provenance", {}))])
    return out


# -- world.* -----------------------------------------------------------------

func _world_posture(args: PackedStringArray) -> PackedStringArray:
    if body == null:
        return PackedStringArray(["no body: `view.embody` first"])
    if args.is_empty() or not PerceptBundle.POSTURES.has(str(args[0])):
        return PackedStringArray(["posture is %s; one of %s" % [body.posture,
                str(PerceptBundle.POSTURES)]])
    body.posture = str(args[0])
    view.observer = body.observer()
    return PackedStringArray(["posture %s" % body.posture])


func _world_day(args: PackedStringArray) -> PackedStringArray:
    if args.is_empty() or view.shown.is_empty():
        return PackedStringArray(["world.day <n>; drawn now: %s" % str(view.shown)])
    var day := int(args[0].to_int())
    var ok := view.show_field(str(view.shown["window"]), str(view.shown["row"]), day,
            int(view.shown["group"]))
    return PackedStringArray(["%s day %d" % ["moved to" if ok else "could not move to", day]])


func _world_rebuild(args: PackedStringArray) -> PackedStringArray:
    if view.scatter == null or not view.scatter.report.get("ok", false):
        return PackedStringArray(["no scatter has been built to rebuild"])
    var centre: Array = view.scatter.report["centre_m"]
    var radius := float(view.scatter.report["radius_m"]) if args.is_empty() \
            else args[0].to_float()
    var r := view.scatter_at(Vector2(float(centre[0]), float(centre[1])), radius)
    return PackedStringArray(["rebuilt: %d texels, share %s, bound by %s" % [
            int(r.get("texels", 0)), String.num(float(r.get("share_drawn", 0.0)), 6),
            str(r.get("share_bound_by", "?"))]])


func _world_measure(args: PackedStringArray) -> PackedStringArray:
    if args.is_empty() or not MEASUREMENTS.has(str(args[0])):
        return PackedStringArray(["world.measure <%s>"
                % "|".join(Array(MEASUREMENTS.keys()))])
    var entry: Array = MEASUREMENTS[str(args[0])]
    var script := ProjectSettings.globalize_path("res://" + str(entry[0]))
    if not FileAccess.file_exists(str(entry[0]).replace("tools/", "res://tools/")):
        return PackedStringArray(["no tool at %s" % str(entry[0])])
    var rest: PackedStringArray = PackedStringArray()
    for i in range(1, args.size()):
        rest.append(str(args[i]))
    var pid := OS.create_process("/bin/bash", PackedStringArray([script]) + rest)
    if pid <= 0:
        return PackedStringArray(["could not launch %s" % str(entry[0])])
    return PackedStringArray([
            "launched %s as pid %d" % [str(entry[0]), pid],
            "it writes %s -- the same artefact the shell tool writes, because it IS the "
                    % str(entry[1]) + "shell tool",
            "the console does not re-implement a measurement: two numbers under one name is "
            + "what that would buy"])


func _world_reload(_args: PackedStringArray) -> PackedStringArray:
    var r := view.bind_fields()
    if not bool(r.get("ok", false)):
        return PackedStringArray(["reload failed: %s" % str(r.get("why", ""))])
    instances.bind(view.scatter, view.heightfield, view.fixture, view.cell_probe())
    return PackedStringArray(["re-read: %d cells, %d px resolved" % [int(r["cells"]),
            int(r["resolved_px"])]])
