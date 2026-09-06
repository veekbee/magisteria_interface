extends SceneTree

## Roadmap item 2: motion metrics. Static sufficiency does not cover temporal
## defects, and the far-field verdict so far is entirely static.
##
##     bash tools/measure_motion.sh --seam 120
##
## WHAT POPS, AND WHY NOTHING DOES TODAY. The scatter is built once around a
## place and does not follow the camera, so dollying changes the VIEW and not
## the population: there is nothing to pop. Backlog 198 proposes solving the
## horizon from an instance budget PER PLACE, which makes the population a
## function of where the camera is -- and then every camera step re-decides
## which instances exist. That is the defect this harness has to be able to see
## BEFORE the inversion lands, which is why it is built now and against a
## deliberately popping control rather than after.
##
## SO THE CONTROL IS THE INVERSION ITSELF. `rebuilt` re-scatters around the
## camera at every step, which is what a per-place budget does. `static` is what
## ships. A metric that cannot separate those two cannot be trusted to catch the
## thing it exists for -- the `ramp_agreement` discipline, one axis over: the
## check has to fail the bad frame.
##
## THE SCORE IS A DISCONTINUITY, NOT A DIFFERENCE. Every frame differs from the
## last because the camera moved; that is not a defect, it is the dolly. What a
## pop looks like is a JUMP in a quantity that should vary smoothly, so the
## score is the worst adjacent-step delta against the median adjacent-step
## delta. A smooth ramp scores near 1; a pop scores high however fast the ramp
## underneath it is.
##
## IT REFUSES HEADLESS, for the reason everything that photographs a frame in
## this repo refuses.

const SETTLE_FRAMES := 12
const HOLD_FRAMES := 6
const EYE_HEIGHT_M := 1.7
const EYE_PITCH_DEGREES := 10.0

## Steps along the view axis, and how far back the dolly starts. Sixteen steps
## over two seam-lengths puts each step at about 15 m, which is a tenth of a
## typical horizon -- fine enough that a horizon crossing lands inside one step
## rather than being spread over several and averaged away.
const STEPS := 12
const SPAN_MULTIPLE := 2.0

## The lateral step for the parallax pair, in metres. Small: the pair is asking
## whether the far field moves like the ground it stands on, and a large step
## changes what is in frame instead.
const LATERAL_M := 4.0

## How far the scatter is built around the camera, as a multiple of the seam.
##
## NOT the viewer's 1,500 m horizon: nothing outside the scoring annulus
## (0.7-1.5 x seam) is measured, and the `rebuilt` control re-scatters at every
## step. Building fourteen 1,500 m discs took long enough per step that the
## WINDOW STOPPED BEING COMPOSITED mid-run and the captures went stale -- the
## harness now refuses that, and this is what stops it happening.
const RADIUS_MULTIPLE := 4.0

enum { SETTLE, PLACE, MASKS, RUN, WRITE, DONE }

var scene: Node = null
var view = null
var stage := SETTLE
var frames := 0

var seam_m := 120.0
var window_name := ""
var row_name := "band.pft.biomass"
var day := 22
var at_world := Vector2.ZERO
var k_fraction := 0.35
var out_path := "measurements/scatter_motion.json"
var shots_dir := "shots/motion"
var append_to_existing := false

## Camera positions, and the annulus mask at each. THE MASK DEPENDS ONLY ON
## WHERE THE CAMERA IS -- it is the terrain through a range shader and no
## candidate is in it -- so it is taken once per position and reused by all
## three, rather than three times per position.
var positions: Array = []
var masks: Array = []
var ground_px: Array = []
var mask_at := 0
## The last frame captured, and the renderer's own drawn-frame counter at that
## moment. Both are checked before a capture is believed.
var _last_bytes := PackedByteArray()
var _last_drawn := 0
var _stage_frames := 0
## Every candidate's frame at every position, kept so two candidates can be
## compared AT THE SAME CAMERA POSITION -- which is the only comparison here
## with no camera motion in it.
var frames_by: Dictionary = {}
## The instance set at the previous dolly position of the current candidate,
## and the churn between each consecutive pair.
var _prev_pop: Dictionary = {}
var churn: Array = []
var cand_at := 0
var pos_at := 0
var samples: Array = []
var _saved_overrides: Dictionary = {}
var _ground_y := 0.0
var _forward := Vector3(0.0, 0.0, -1.0)
var k_res := 0.0


func _initialize() -> void:
    if DisplayServer.get_name() == "headless":
        printerr("measure_motion: the display server is 'headless', which draws nothing and "
                + "reports success. Run through tools/measure_motion.sh.")
        quit(2)
        return
    seam_m = float(_arg("--seam", str(seam_m)))
    window_name = _arg("--window", "")
    row_name = _arg("--row", row_name)
    day = int(_arg("--day", str(day)))
    k_fraction = float(_arg("--k", str(k_fraction)))
    out_path = _arg("--out", out_path)
    shots_dir = _arg("--shots", shots_dir)
    append_to_existing = _has("--append")
    var at := _arg("--at", "")
    if at != "":
        var parts := at.split(",")
        at_world = Vector2(float(parts[0]), float(parts[1]))
    # SMALLER THAN THE OTHER HARNESSES, ON PURPOSE. Every score here is a RATIO
    # of deltas, so absolute pixel counts cancel and resolution buys nothing --
    # while `SeamScore.within` walks every pixel in GDScript, 56 times a run.
    # At 1280x800 that is minutes of pure CPU with no frame drawn, which is
    # exactly when this platform stops compositing the window and the captures
    # go stale. A quarter of the pixels is a quarter of the exposure.
    var size := _arg("--size", "640x400").split("x")
    if size.size() == 2:
        DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + shots_dir))
    var packed := load("res://scenes/main.tscn") as PackedScene
    scene = packed.instantiate()
    get_root().add_child(scene)
    Engine.max_fps = 0


func _process(delta: float) -> bool:
    frames += 1
    _stage_frames += 1
    var stall := HarnessGuard.stall_note(_stage_name(), _stage_frames)
    if stall != "":
        printerr("measure_motion: REFUSED. %s" % stall)
        quit(4)
        return true
    # NOT IN `_initialize`. `TerrainView` is an `@onready` member of the main
    # scene, so it is null until the node has entered the tree and run `_ready`
    # -- and reading it too early leaves `view` at Nil, after which every call
    # on it errors, `_place` aborts halfway, the stage never advances and the
    # harness sits at 1% CPU looking like a slow render rather than a broken
    # one. Cost two runs and twenty minutes each before the output was read
    # without a `tail` in front of it.
    if view == null:
        view = scene.get_node("TerrainView")
    match stage:
        SETTLE:
            if frames >= SETTLE_FRAMES:
                _place()
        MASKS:
            if frames >= HOLD_FRAMES:
                _take_mask()
        RUN:
            if frames >= HOLD_FRAMES:
                _take_frame()
        WRITE:
            _write()
            stage = DONE
            return true
        DONE:
            return true
    return false


func _stage_name() -> String:
    match stage:
        SETTLE: return "settle"
        PLACE: return "place"
        MASKS: return "mask %d/%d" % [mask_at + 1, positions.size()]
        RUN: return "frame %s %d/%d" % [str(CANDIDATES[cand_at]["name"]) if cand_at
                < CANDIDATES.size() else "?", pos_at + 1, positions.size()]
        WRITE: return "write"
    return "done"


func _place() -> void:
    stage = PLACE
    var w: String = window_name if window_name != "" else str(view.fixture.windows[0])
    var set_to: Dictionary = scene.scrubber.select(w, row_name, day)
    if not bool(set_to["ok"]):
        printerr("measure_motion: %s" % str(set_to["why"]))
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
        printerr("measure_motion: the probe did not resolve to ground")
        quit(2)
        return
    at_world = probe["world"]
    scene._on_probed(probe)
    view.focus_on_scatter()
    scene.get_node("UI").visible = false
    RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
    var env = view.get_node_or_null("Ambient")
    if env != null and env.environment != null:
        env.environment.background_color = Color(0, 0, 0, 1)
    var surface: float = view.terrain.drawn_surface_y(at_world, view.heightfield)
    _ground_y = view.scatter_centre_mesh.y if is_nan(surface) else surface
    view.rig.fly.far = maxf(8.0 * seam_m, 4000.0)
    k_res = VegetationScatter.resolution_k(
            float(get_root().get_visible_rect().size.y), view.rig.fly.fov)
    positions = _plan()
    mask_at = 0
    _begin_mask()


## One flat list of shots, because a nested loop over candidates, steps and the
## two renders each needs would be a state machine with three counters in it.
func _plan() -> Array:
    var out: Array = []
    for i in STEPS:
        out.append({"step": i, "lateral_m": 0.0, "parallax": false,
                    "back_m": SPAN_MULTIPLE * seam_m * (1.0 - float(i) / float(STEPS - 1))})
    # THE PARALLAX PAIR, at the middle of the dolly: one step sideways and
    # nothing else changed. A tint painted on the ground and a plant standing on
    # it shift by the same angle at the same range, so this is not asking which
    # moves more -- it asks whether the far field moves WITH the ground at all,
    # which anything camera-locked would not.
    var mid: float = SPAN_MULTIPLE * seam_m * 0.5
    out.append({"step": -1, "back_m": mid, "lateral_m": 0.0, "parallax": true})
    out.append({"step": -2, "back_m": mid, "lateral_m": LATERAL_M, "parallax": true})
    return out


const CANDIDATES: Array = [
    {"name": "static", "rebuild": false, "tint": false, "veg": true},
    {"name": "rebuilt", "rebuild": true, "tint": false, "veg": true},
    {"name": "tint", "rebuild": false, "tint": true, "veg": false},
]


## Pass one: the masks, one per camera position, candidate-independent.
func _begin_mask() -> void:
    if mask_at >= positions.size():
        _restore_terrain()
        cand_at = 0
        pos_at = 0
        _begin_frame()
        return
    var pos: Dictionary = positions[mask_at]
    _aim(_eye_at(float(pos["back_m"]), float(pos["lateral_m"])))
    _hide_all_but_terrain()
    var band := SeamScore.scoring_band(seam_m)
    _override_terrain(_annulus_material(float(band["lo_m"]), float(band["hi_m"])))
    frames = 0
    _stage_frames = 0
    stage = MASKS


func _take_mask() -> void:
    var img := get_root().get_texture().get_image()
    masks.append(img)
    ground_px.append(SeamScore.mask_pixels(img))
    print("mask %2d/%d at %5.0f m back, %4.1f m across: %7d px in the annulus"
            % [mask_at + 1, positions.size(), float(positions[mask_at]["back_m"]),
                    float(positions[mask_at]["lateral_m"]), int(ground_px[mask_at])])
    mask_at += 1
    _begin_mask()


## Pass two: each candidate at each position, scored against that position's
## mask. The scatter is rebuilt only where the candidate says to.
func _begin_frame() -> void:
    if cand_at >= CANDIDATES.size():
        _restore_terrain()
        stage = WRITE
        frames = 0
        _stage_frames = 0
        return
    var cand: Dictionary = CANDIDATES[cand_at]
    var pos: Dictionary = positions[pos_at]
    if pos_at == 0:
        _prev_pop = {}
    var eye := _eye_at(float(pos["back_m"]), float(pos["lateral_m"]))
    view.set_naturalistic(bool(cand["tint"]))
    if bool(cand["rebuild"]) or pos_at == 0:
        # A REBUILD FOLLOWS THE CAMERA, WHICH IS THE POINT OF THE CONTROL. The
        # eye is in mesh space and `scatter_at` wants EPSG:5070, so the camera's
        # ground position is converted back rather than passed.
        var w2: Vector2 = at_world
        if bool(cand["rebuild"]):
            w2 = view.terrain.mesh_to_world(Vector3(eye.x, 0.0, eye.z), view.heightfield)
        # The tint candidate needs a scatter only so the day is bound; one
        # instance is enough, and `veg` keeps it out of the frame.
        view.scatter_at(w2, RADIUS_MULTIPLE * seam_m, [],
                1 if not bool(cand["veg"]) else 4000000,
                0.0 if not bool(cand["veg"]) else k_fraction * k_res)
    _aim(eye)
    _isolate(true, bool(cand["veg"]))
    frames = 0
    _stage_frames = 0
    stage = RUN


func _take_frame() -> void:
    var cand: Dictionary = CANDIDATES[cand_at]
    var pos: Dictionary = positions[pos_at]
    var img := get_root().get_texture().get_image()
    _refuse_if_stale(img, "%s at step %d" % [str(cand["name"]), int(pos["step"])])
    if not frames_by.has(str(cand["name"])):
        frames_by[str(cand["name"])] = {}
    (frames_by[str(cand["name"])] as Dictionary)[pos_at] = img
    _record(cand, pos, img)
    if bool(cand["veg"]) and not bool(pos["parallax"]):
        _churn_against(_population(_eye_at(float(pos["back_m"]), float(pos["lateral_m"]))),
                int(pos["step"]), str(cand["name"]))
    print("frame %-8s %2d/%d" % [str(cand["name"]), pos_at + 1, positions.size()])
    _isolate(false, true)
    pos_at += 1
    if pos_at >= positions.size():
        pos_at = 0
        cand_at += 1
    _begin_frame()


func _record(cand: Dictionary, pos: Dictionary, img: Image) -> void:
    var within := SeamScore.within(masks[pos_at], img)
    var cov: Variant = SeamScore.coverage(int(within["lit_pixels"]), ground_px[pos_at])
    if is_nan(float(cov)):
        cov = null
    samples.append({
        "candidate": str(cand["name"]),
        "step": int(pos["step"]),
        "back_m": pos["back_m"],
        "lateral_m": pos["lateral_m"],
        "parallax": bool(pos["parallax"]),
        "ground_pixels": ground_px[pos_at],
        "lit_pixels": within["lit_pixels"],
        "coverage": cov,
        "mean_colour": within["mean_colour"],
        "luminance": within["luminance_histogram"],
    })
    if int(pos["step"]) <= 0 or int(pos["step"]) == STEPS - 1:
        img.save_png("res://%s/%s_%s_step%d%s.png" % [shots_dir, window_name,
                str(cand["name"]), int(pos["step"]),
                "_lateral" if float(pos["lateral_m"]) != 0.0 else ""])


func _eye_at(back_m: float, lateral_m: float) -> Vector3:
    var c: Vector3 = view.scatter_centre_mesh
    return Vector3(c.x + lateral_m, _ground_y + EYE_HEIGHT_M, c.z + back_m)


func _aim(eye: Vector3) -> void:
    var cam = view.rig.fly
    cam.position = eye
    cam.look_at_from_position(eye, eye + Vector3(0.0, -tan(deg_to_rad(EYE_PITCH_DEGREES)), -1.0),
            Vector3.UP)


## Both refusals live in `HarnessGuard`, because this harness is not the only
## one that can be handed a frozen frame.
func _refuse_if_stale(img: Image, what: String) -> void:
    var bytes := img.get_data()
    var note := HarnessGuard.capture_note(_last_bytes, bytes, what)
    if note == "":
        note = ("" if Engine.get_frames_drawn() > _last_drawn
                else "the renderer drew no frames since the last capture, at %s" % what)
    if note != "":
        printerr("measure_motion: REFUSED. %s" % note)
        quit(3)
        return
    _last_bytes = bytes
    _last_drawn = Engine.get_frames_drawn()


func _annulus_material(lo: float, hi: float) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = load("res://src/bench/annulus.gdshader")
    m.set_shader_parameter("lo_m", lo)
    m.set_shader_parameter("hi_m", hi)
    return m


func _override_terrain(m: ShaderMaterial) -> void:
    var t = view.get_node_or_null("Terrain")
    if t == null:
        return
    if not _saved_overrides.has(t):
        _saved_overrides[t] = t.material_override
    t.material_override = m


func _restore_terrain() -> void:
    for n in _saved_overrides:
        n.material_override = _saved_overrides[n]
    _saved_overrides.clear()


func _hide_all_but_terrain() -> void:
    view.get_node("Terrain").visible = true
    for c in view.get_children():
        var n := String(c.name)
        if n.begins_with("Vegetation") or n.begins_with("Flow") or n == "Contours":
            c.visible = false


## `veg` false hides the instances outright. The tint candidate is the far
## field WITHOUT them -- one ground colour standing in for the stand -- and a
## frame with both in it measures neither.
func _isolate(on: bool, veg: bool) -> void:
    view.get_node("Terrain").visible = not on or view.naturalistic
    view.set_isolate_vegetation(on)
    for c in view.get_children():
        var n := String(c.name)
        if n.begins_with("Flow") or n == "Contours":
            c.visible = not on
        elif n.begins_with("Vegetation_"):
            c.visible = veg and view.scatter.meshes.has(n.substr("Vegetation_".length()))


# --------------------------------------------------------------------------
# the score: a discontinuity, not a difference
# --------------------------------------------------------------------------

## Adjacent-step deltas for one candidate, and the ratio that is the score.
##
## Every step differs from the last because the camera moved 15 m. That is the
## dolly, not a defect. A POP is a jump in a quantity that should vary smoothly
## with camera position, so the number that matters is the WORST adjacent delta
## against the MEDIAN one: a smooth ramp scores near 1 however steep it is, and
## a pop scores high however gentle the ramp under it is.
func _score(name: String) -> Dictionary:
    var rows: Array = []
    for s in samples:
        if str(s["candidate"]) == name and not bool(s["parallax"]):
            rows.append(s)
    rows.sort_custom(func(a, b): return int(a["step"]) < int(b["step"]))
    if rows.size() < 3:
        return {"ok": false, "why": "a discontinuity needs three steps; %d taken" % rows.size()}
    var d_cov := PackedFloat64Array()
    var d_col := PackedFloat64Array()
    for i in range(1, rows.size()):
        var a: Dictionary = rows[i - 1]
        var b: Dictionary = rows[i]
        if a["coverage"] != null and b["coverage"] != null:
            d_cov.append(absf(float(b["coverage"]) - float(a["coverage"])))
        d_col.append(SeamScore.colour_error(a["mean_colour"], b["mean_colour"]))
    var out := {"ok": true, "steps": rows.size(),
                "step_m": absf(float(rows[1]["back_m"]) - float(rows[0]["back_m"]))}
    for pair in [["coverage", d_cov], ["colour", d_col]]:
        var label: String = pair[0]
        var d: PackedFloat64Array = pair[1]
        if d.is_empty():
            continue
        var worst := 0.0
        for v in d:
            worst = maxf(worst, v)
        var med := FrameStats.quantile(d, 0.5)
        out[label] = {
            "worst_step_delta": worst,
            "median_step_delta": med,
            # The median can be zero for a candidate that does not move at all
            # (a tint at a range the camera has not reached), and a ratio
            # against zero is not a number. Say the absence instead.
            "pop_ratio": (worst / med) if med > 0.0 else null,
            "why_no_ratio": null if med > 0.0 else ("every adjacent step differed by zero, so "
                    + "there is no smooth rate to measure a jump against: this candidate did "
                    + "not change over the dolly at all"),
            "at_step": _argmax(d) + 1,
        }
    var lat := _parallax(name)
    if not lat.is_empty():
        out["parallax"] = lat
    return out


## The lateral pair: one step sideways, nothing else changed.
func _parallax(name: String) -> Dictionary:
    var moved: Dictionary = {}
    var still: Dictionary = {}
    for s in samples:
        if str(s["candidate"]) != name or not bool(s["parallax"]):
            continue
        if float(s["lateral_m"]) != 0.0:
            moved = s
        else:
            still = s
    if moved.is_empty() or still.is_empty():
        return {}
    var out := {
        "lateral_m": LATERAL_M,
        "colour_delta": SeamScore.colour_error(still["mean_colour"], moved["mean_colour"]),
        "luminance_distance": SeamScore.luminance_distance(
                still["luminance"], moved["luminance"]),
    }
    if still["coverage"] != null and moved["coverage"] != null:
        out["coverage_delta"] = absf(float(moved["coverage"]) - float(still["coverage"]))
    return out


## WHAT RE-SCATTERING ACTUALLY CHANGES, with the camera held still.
##
## The dolly scores above cannot see popping and this is why: coverage and mean
## colour are means over thousands of pixels, while a pop is LOCAL -- one plant
## where there was none. Re-centring the horizon disc on a camera 15 m away
## changes the population only at the disc's rim, which is the far edge of the
## annulus and sub-pixel there, so the aggregate barely moves. Measured: the
## deliberately re-scattering control came out SMOOTHER than the static scene,
## and the tint, which is painted on the ground and cannot pop at all, scored
## the worst ratio of the three.
##
## So this compares two candidates AT THE SAME CAMERA POSITION. Same camera,
## same terrain, same day: the only difference is which instances exist, and
## the fraction of annulus pixels that differ IS the population change, with no
## motion to compensate for. Its worst step against its median is a pop; a
## difference that is large but steady is a different scene, not a flickering
## one.
## THE POPULATION ITSELF, WHICH IS WHERE POPPING ACTUALLY LIVES.
##
## The image metrics above cannot see a pop and the reasons are measured: an
## aggregate over thousands of pixels is blind to a local event, and a
## per-pixel difference between consecutive frames is swamped by the camera
## having moved twenty metres. Motion-compensating that difference needs the
## DEPTH of the plants, not of the ground under them, and depth written through
## an sRGB viewport has already cost this project one harness.
##
## So the measurement moves off the screen and onto the thing being measured. A
## pop is an instance that exists in one frame and not the next; the instance
## set is exact, cheap, and cannot be handed a frozen frame. `static` must
## churn EXACTLY ZERO -- it is one build, dollied through -- which is a
## calibration no image metric here could offer.
##
## Weighted by apparent size, because a plant that vanishes at 400 m is
## sub-pixel and one that vanishes at 40 m is a hole in the picture: each
## instance counts for the pixels it subtends, `height x k_res / distance`, and
## zero where the camera cannot see it. The px fraction can exceed 1 when a
## population turns over completely -- appeared and gone are both counted
## against what is there now.
func _population(eye: Vector3) -> Dictionary:
    var out := {}
    var at_origin := 0
    var total := 0
    for lf in view.scatter.meshes:
        var mm: MultiMesh = view.scatter.meshes[lf]
        for i in mm.instance_count:
            var t := mm.get_instance_transform(i)
            var o := t.origin
            total += 1
            if o == Vector3.ZERO:
                at_origin += 1
                continue
            # MEMBERSHIP IS EXISTENCE, NOT VISIBILITY. Filtering the set by
            # what the camera can see makes the WINDOW's movement look like
            # churn: the first version did that and `static` -- one build,
            # dollied through, which cannot churn at all -- came out at 0.12
            # instead of 0. The camera enters only in the WEIGHT, so an
            # instance behind the eye or past the dolly's reach counts as a
            # member and contributes no pixels.
            var d := Vector2(o.x - eye.x, o.z - eye.z).length()
            var px := 0.0
            if o.z < eye.z and d > 0.0 and d <= RADIUS_MULTIPLE * seam_m:
                px = t.basis.get_scale().y * k_res / d
            out["%s|%d|%d" % [lf, int(round(o.x * 10.0)), int(round(o.z * 10.0))]] = px
    # THE STUB TELL. Under a renderer without a per-instance store every
    # transform reads back as the identity, and a churn computed from that
    # would be zero for every candidate -- a clean table meaning nothing.
    if total > 0 and at_origin == total:
        printerr("measure_motion: REFUSED. All %d instance transforms read back at the "
                % total + "origin, so the per-instance store is not readable here and every "
                + "churn below would be zero by construction rather than by measurement.")
        quit(6)
    return out


## What changed between this position and the last one of the same candidate.
func _churn_against(pop: Dictionary, step: int, cand: String) -> void:
    if _prev_pop.is_empty():
        _prev_pop = pop
        return
    var appeared := 0
    var gone := 0
    var appeared_px := 0.0
    var gone_px := 0.0
    var here_px := 0.0
    for k in pop:
        here_px += float(pop[k])
        if not _prev_pop.has(k):
            appeared += 1
            appeared_px += float(pop[k])
    for k in _prev_pop:
        if not pop.has(k):
            gone += 1
            gone_px += float(_prev_pop[k])
    churn.append({
        "candidate": cand, "step": step,
        "population": pop.size(), "previous_population": _prev_pop.size(),
        "appeared": appeared, "gone": gone,
        "appeared_px": appeared_px, "gone_px": gone_px,
        "population_px": here_px,
        "churn_fraction": (float(appeared + gone) / float(pop.size() + _prev_pop.size())
                if pop.size() + _prev_pop.size() > 0 else 0.0),
        "churn_px_fraction": ((appeared_px + gone_px) / here_px) if here_px > 0.0 else 0.0,
    })
    _prev_pop = pop


func _churn_score(name: String) -> Dictionary:
    var rows: Array = []
    for c in churn:
        if str((c as Dictionary)["candidate"]) == name:
            rows.append(c)
    if rows.is_empty():
        return {"ok": false, "why": "no consecutive pair was compared for %s" % name}
    var worst := 0.0
    var worst_px := 0.0
    var total := 0.0
    for c in rows:
        worst = maxf(worst, float((c as Dictionary)["churn_fraction"]))
        worst_px = maxf(worst_px, float((c as Dictionary)["churn_px_fraction"]))
        total += float((c as Dictionary)["churn_fraction"])
    return {
        "ok": true, "pairs": rows.size(),
        "worst_churn_fraction": worst,
        "mean_churn_fraction": total / float(rows.size()),
        "worst_churn_px_fraction": worst_px,
        "per_pair": rows,
        "what": ("the share of instances that exist in one dolly step and not the next, and "
                + "the same share weighted by the pixels each subtends. `static` is one build "
                + "dollied through, so anything but zero for it is this instrument lying."),
    }


func _cross(a: String, b: String) -> Dictionary:
    if not (frames_by.has(a) and frames_by.has(b)):
        return {"ok": false, "why": "one of %s, %s was not captured" % [a, b]}
    var per := PackedFloat64Array()
    var by_pos: Array = []
    for i in positions.size():
        var fa: Dictionary = frames_by[a]
        var fb: Dictionary = frames_by[b]
        if not (fa.has(i) and fb.has(i)):
            continue
        var f := _changed_fraction(masks[i], fa[i], fb[i])
        by_pos.append({"step": int(positions[i]["step"]), "changed_fraction": f,
                       "ground_pixels": ground_px[i]})
        if not bool(positions[i]["parallax"]):
            per.append(f)
    if per.size() < 3:
        return {"ok": false, "why": "needs three dolly positions; %d compared" % per.size()}
    var worst := 0.0
    var mean := 0.0
    for v in per:
        worst = maxf(worst, v)
        mean += v
    mean /= float(per.size())
    var med := FrameStats.quantile(per, 0.5)
    return {
        "ok": true, "between": [a, b],
        "worst_changed_fraction": worst,
        "median_changed_fraction": med,
        "mean_changed_fraction": mean,
        "pop_ratio": (worst / med) if med > 0.0 else null,
        "per_position": by_pos,
        "what": ("the share of annulus pixels that differ between the two candidates at the "
                + "SAME camera position, so nothing here is camera motion"),
    }


## The share of masked pixels where two frames differ beyond a threshold.
## The threshold is loose enough to ignore shading dither and tight enough that
## an instance appearing or vanishing counts.
func _changed_fraction(mask: Image, a: Image, b: Image) -> float:
    var w := mini(a.get_width(), b.get_width())
    var h := mini(a.get_height(), b.get_height())
    var n := 0
    var changed := 0
    for y in h:
        for x in w:
            if mask.get_pixel(x, y).r < SeamScore.MASK_THRESHOLD:
                continue
            n += 1
            var ca := a.get_pixel(x, y)
            var cb := b.get_pixel(x, y)
            if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.08:
                changed += 1
    return NAN if n == 0 else float(changed) / float(n)


func _argmax(d: PackedFloat64Array) -> int:
    var best := 0
    for i in d.size():
        if d[i] > d[best]:
            best = i
    return best


func _write() -> void:
    var scored: Dictionary = {}
    for name in ["static", "rebuilt", "tint"]:
        scored[name] = _score(name)
    var run := {
        "what": ("what the far field does when the camera MOVES, which static sufficiency does "
                + "not cover"),
        "measured_at_commit": _git_head(),
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "scene": {
            "window": window_name, "row": row_name, "day": day,
            "at_world_epsg5070": [at_world.x, at_world.y],
            "seam_m": seam_m,
            "annulus": SeamScore.scoring_band(seam_m),
            "eye_height_m": EYE_HEIGHT_M,
            "eye_pitch_degrees": EYE_PITCH_DEGREES,
        },
        "scatter_radius_m": RADIUS_MULTIPLE * seam_m,
        "viewport": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
        "dolly": {
            "steps": STEPS,
            "span_m": SPAN_MULTIPLE * seam_m,
            "step_m": SPAN_MULTIPLE * seam_m / float(STEPS - 1),
            "along": "the view axis, ending at the place the scatter is centred on",
        },
        "individuation_k": k_fraction * k_res,
        "k_over_k_res": k_fraction,
        "k_resolution": k_res,
        "candidates": {
            "static": "the horizon rule as it ships: one build around the place, dollied through",
            "rebuilt": ("re-scattered around the CAMERA at every step -- what solving the horizon "
                    + "from a per-place budget does. The deliberately popping control, and the "
                    + "reason this harness exists before that inversion does"),
            "tint": "the far-field tint alone, painted on the ground",
        },
        "scores": scored,
        "population_churn": {
            "static": _churn_score("static"),
            "rebuilt": _churn_score("rebuilt"),
        },
        "population_change": {
            "static_vs_rebuilt": _cross("static", "rebuilt"),
            "static_vs_tint": _cross("static", "tint"),
        },
        "samples": samples,
        "not_covered": ("one place, one day, one dolly axis, one k. A lateral pair is not a "
                + "pan: the camera translates and does not rotate, so nothing here says what "
                + "happens when a viewer turns."),
    }
    var doc := {
        "_what": "motion metrics for the far field",
        # AT THE TOP AS WELL AS IN THE RUN. The guard that keeps every
        # measurement naming the scale it was taken at reads the document, and
        # it caught this artefact on its first run -- which is the guard doing
        # exactly its job on a file that did not exist when it was written.
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "runs": [run],
    }
    if append_to_existing and FileAccess.file_exists(out_path):
        var prior = JSON.parse_string(FileAccess.open(out_path, FileAccess.READ).get_as_text())
        if typeof(prior) == TYPE_DICTIONARY and (prior as Dictionary).has("runs"):
            var runs: Array = (prior as Dictionary)["runs"]
            runs.append(run)
            (prior as Dictionary)["runs"] = runs
            doc = prior
    var f := FileAccess.open(out_path, FileAccess.WRITE)
    f.store_string(JSON.stringify(doc, "  ", false) + "\n")
    f.close()
    for name in scored:
        var sc: Dictionary = scored[name]
        if not bool(sc.get("ok", false)):
            print("%-9s %s" % [name, str(sc.get("why", ""))])
            continue
        var cov: Dictionary = sc.get("coverage", {})
        var col: Dictionary = sc.get("colour", {})
        print("%-9s coverage worst %s / median %s = %s   colour worst %s / median %s = %s"
                % [name,
                        String.num(float(cov.get("worst_step_delta", NAN)), 4),
                        String.num(float(cov.get("median_step_delta", NAN)), 4),
                        "--" if cov.get("pop_ratio", null) == null
                                else String.num(float(cov["pop_ratio"]), 2) + "x",
                        String.num(float(col.get("worst_step_delta", NAN)), 4),
                        String.num(float(col.get("median_step_delta", NAN)), 4),
                        "--" if col.get("pop_ratio", null) == null
                                else String.num(float(col["pop_ratio"]), 2) + "x"])
        var par: Dictionary = sc.get("parallax", {})
        if not par.is_empty():
            print("          parallax over %s m: colour %s  coverage %s"
                    % [String.num(float(par["lateral_m"]), 1),
                            String.num(float(par["colour_delta"]), 4),
                            String.num(float(par.get("coverage_delta", NAN)), 4)])
    for name in ["static", "rebuilt"]:
        var ch := _churn_score(name)
        if bool(ch.get("ok", false)):
            print("%-9s instance churn: worst %s of the set, %s of its pixels, over %d pairs"
                    % [name, String.num(float(ch["worst_churn_fraction"]), 4),
                            String.num(float(ch["worst_churn_px_fraction"]), 4),
                            int(ch["pairs"])])
    for pair in [["static", "rebuilt"], ["static", "tint"]]:
        var c := _cross(str(pair[0]), str(pair[1]))
        if not bool(c.get("ok", false)):
            continue
        print("%-9s vs %-8s annulus pixels changed: worst %s  median %s  ratio %s"
                % [str(pair[0]), str(pair[1]),
                        String.num(float(c["worst_changed_fraction"]), 4),
                        String.num(float(c["median_changed_fraction"]), 4),
                        "--" if c["pop_ratio"] == null else String.num(float(c["pop_ratio"]), 2)])
    print("-> %s   shots: %s" % [out_path, shots_dir])


func _git_head() -> String:
    var o: Array = []
    OS.execute("git", ["rev-parse", "--short", "HEAD"], o)
    return "" if o.is_empty() else str(o[0]).strip_edges()


func _arg(name: String, fallback: String) -> String:
    var args := OS.get_cmdline_user_args()
    for i in args.size():
        if args[i] == name and i + 1 < args.size():
            return args[i + 1]
    return fallback


func _has(name: String) -> bool:
    return OS.get_cmdline_user_args().has(name)
