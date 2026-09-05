extends SceneTree

## Grade a far-field candidate against the instances it stands in for.
##
##     bash tools/measure_seam.sh --seam 120 --exaggeration 12
##
## THE QUESTION. Beyond a few hundred metres a plant is a fraction of a pixel
## and there are tens of millions of it, so the far field has to become a
## collective representation. Candidate #1 is the cheapest: a per-cell
## vegetation tint on the terrain, no new geometry. Whether it is sufficient is
## not arguable, and this is the arithmetic that decides.
##
## THE ORACLE IS INSTANCES AT FULL DENSITY out to 2.5x the seam. It is not the
## full 52 M the wire implies -- that cannot be built -- and the brief's reason
## for the cut ("beyond 2-3x the seam everything is sub-pixel") is measurably
## false: a tree is 91 px at 300 m drawn. The defensible reason is narrower and
## is the one used here: the score is taken in an ANNULUS, and geometry beyond
## the annulus is behind it and cannot occlude it. `--oracle-check` measures
## that rather than asserting it, by scoring the same annulus against a deeper
## oracle and reporting the difference.
##
## THE SCORE IS IN AN ANNULUS, 0.7-1.5x the seam. A whole-frame metric is mostly
## the near field -- at eye level the ground within a hundred metres fills the
## picture -- so a candidate that got the far field entirely wrong would score
## well. `src/bench/annulus.gdshader` masks a range band as one bit, which is
## the only form that survives this renderer's sRGB output.
##
## TWO SCORES PER CANDIDATE. Isolated -- vegetation only, everything else black
## -- because the colour targets were measured in isolation. And in-situ,
## because a tint can match the stand in isolation and still fight the overlay
## and the hillshade. Instances are isolated by hiding the ground; a tint IS the
## ground, so the terrain shader isolates itself (`isolate_vegetation`).
##
## THE METRIC HAS TO FAIL THE BAD FRAME, so a deliberately wrong baseline is
## graded alongside every run and `SeamScore.rank` reports the margin. A metric
## that cannot separate a constant tint from a range-matched one is a metric
## nobody should point at anything subtler.
##
## IT REFUSES HEADLESS, and the eye camera brings the far plane down with it:
## `near` 0.1 against the rig's basin-scale far draws nothing at all here.

const SETTLE_FRAMES := 12
const HOLD_FRAMES := 8
const TIME_FRAMES := 40
const EYE_HEIGHT_M := 1.7
const EYE_PITCH_DEGREES := 10.0

## Multiples of the seam the oracle is built out to, and the deeper one
## `--oracle-check` compares it against.
const ORACLE_MULTIPLE := 2.5
const ORACLE_CHECK_MULTIPLE := 5.0

## Grid the range curve is fitted over. Coarse and stated: the curve has two
## parameters and eight bands to fit them to, and a finer grid would be
## precision the data does not carry.
const K0_STEPS := 21
const R0_CHOICES: Array = [40.0, 60.0, 80.0, 120.0, 160.0, 220.0, 300.0, 420.0, 600.0]

enum { SETTLE, PLACE, MASK, CANDIDATE, WRITE, DONE }

var scene: Node = null
var view = null
var stage := SETTLE
var frames := 0

var seam_m := 120.0
var exaggeration := 12.0
var window_name := ""
var row_name := "band.pft.biomass"
var day := 22
var at_world := Vector2.ZERO
var out_path := "measurements/scatter_seam.json"
var shots_dir := "shots/seam"
var oracle_check := false
## Runs accumulate into one artefact: sufficiency is a claim about places and
## days, and one row of it is not evidence for the claim.
var append_to_existing := false

var bands: Array = []
var ground_px: Array = []          ## per band, terrain-only pixels in it
var masks: Array = []              ## per band, the mask image
var mask_at := 0

var jobs: Array = []
var job_at := 0
var job_step := 0
var results: Array = []
var _saved_overrides: Dictionary = {}
var _baseline_ms := NAN
var _wall := PackedFloat64Array()
var curve := {"k0": 1.0, "r0": 200.0, "fitted": false}


func _initialize() -> void:
    if DisplayServer.get_name() == "headless":
        printerr("measure_seam: the display server is 'headless', which draws nothing.")
        quit(2)
        return
    seam_m = float(_arg("--seam", str(seam_m)))
    exaggeration = float(_arg("--exaggeration", str(exaggeration)))
    window_name = _arg("--window", "")
    row_name = _arg("--row", row_name)
    day = int(_arg("--day", str(day)))
    out_path = _arg("--out", out_path)
    shots_dir = _arg("--shots", shots_dir)
    oracle_check = _has("--oracle-check")
    append_to_existing = _has("--append")
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
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://") + shots_dir)

    scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    # The exaggeration is a property of the view and every distance measured
    # here is conditional on it, so it is set BEFORE the terrain is built and
    # travels in the artefact.
    scene.get_node("TerrainView").exaggeration = exaggeration
    get_root().add_child(scene)
    bands = SeamScore.bands(seam_m)


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
        MASK:
            if frames >= HOLD_FRAMES:
                _take_mask()
        CANDIDATE:
            _run_candidate(delta)
        WRITE:
            _write()
            return true
    return false


func _place() -> void:
    stage = PLACE
    var w: String = window_name if window_name != "" else str(view.fixture.windows[0])
    var set_to: Dictionary = scene.scrubber.select(w, row_name, day)
    if not bool(set_to["ok"]):
        printerr("measure_seam: %s" % str(set_to["why"]))
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
        printerr("measure_seam: the probe did not resolve to ground")
        quit(2)
        return
    at_world = probe["world"]
    scene._on_probed(probe)
    _aim_camera()
    scene.get_node("UI").visible = false
    # BLACK, because an isolated render is scored by which pixels are NOT black.
    # Left at the default grey the sky counts as vegetation, every masked pixel
    # reads as lit, and coverage comes back at exactly 1.0 for every candidate
    # including the ones that draw nothing -- which is what the first run of
    # this harness reported. Set here rather than before the scene loads: the
    # WorldEnvironment the terrain adds takes the default clear colour as it
    # stood when it was created.
    RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
    var env = view.get_node_or_null("Ambient")
    if env != null and env.environment != null:
        env.environment.background_color = Color(0, 0, 0, 1)
    jobs = _plan()
    _begin_masks()


## The candidates, in the order they have to run: the oracle first, because the
## range curve the matched tint is attenuated by is FITTED to it, and a curve
## chosen before the thing it describes was measured is a constant.
func _plan() -> Array:
    var out: Array = [
        {"name": "oracle", "kind": "instances", "cut_m": seam_m * ORACLE_MULTIPLE},
        {"name": "null", "kind": "instances", "cut_m": 0.0},
        {"name": "constant", "kind": "tint", "cut_m": seam_m, "matched": false},
        {"name": "range_matched", "kind": "tint", "cut_m": seam_m, "matched": true},
    ]
    if oracle_check:
        out.insert(1, {"name": "oracle_deeper", "kind": "instances",
                       "cut_m": seam_m * ORACLE_CHECK_MULTIPLE})
    return out


func _aim_camera() -> void:
    view.focus_on_scatter()
    var cam = view.rig.fly
    # ABOVE THE DRAWN SURFACE, not above the field. The mesh triangulates
    # samples 4 km apart, so "field height plus eye height" is routinely
    # underneath it -- and from under a slab there is no near ground in frame at
    # all, which the first runs of this harness reported as empty range bands.
    var surface: float = view.terrain.drawn_surface_y(at_world, view.heightfield)
    var ground: float = view.scatter_centre_mesh.y if is_nan(surface) else surface
    var eye := Vector3(view.scatter_centre_mesh.x, ground + EYE_HEIGHT_M * exaggeration,
            view.scatter_centre_mesh.z)
    # The far plane comes down with the near one. Left at the rig's basin scale
    # against a near of a metre or two, this renderer draws nothing at all.
    cam.far = maxf(8.0 * seam_m, 4000.0)
    cam.position = eye
    cam.look_at_from_position(eye, eye + Vector3(0.0, -tan(deg_to_rad(EYE_PITCH_DEGREES)), -1.0),
            Vector3.UP)


# --------------------------------------------------------------------------
# the range masks -- one per band, terrain only, candidate-independent
# --------------------------------------------------------------------------

func _begin_masks() -> void:
    mask_at = 0
    _next_mask()


func _next_mask() -> void:
    if mask_at >= bands.size():
        _restore_overrides()
        _show_all()
        job_at = 0
        job_step = 0
        frames = 0
        stage = CANDIDATE
        return
    _hide_everything_but_terrain()
    var b: Dictionary = bands[mask_at]
    _override_all(_annulus_material(float(b["lo_m"]), float(b["hi_m"])))
    frames = 0
    stage = MASK


func _take_mask() -> void:
    var img := get_root().get_texture().get_image()
    masks.append(img)
    var n := SeamScore.mask_pixels(img)
    ground_px.append(n)
    var b: Dictionary = bands[mask_at]
    img.save_png("res://%s/mask_x%d_%03d_%03d.png" % [shots_dir, int(exaggeration),
            int(float(b["lo_m"])), int(float(b["hi_m"]))])
    var su := FrameProbe.summarise(img)
    print("mask   %4.0f-%4.0f m: %8d px in band | frame %d neutral %d near-black %d coloured"
            % [float(b["lo_m"]), float(b["hi_m"]), n, int(su["neutral"]),
               int(su["near_black"]), int(su["coloured"])])
    mask_at += 1
    _next_mask()


func _annulus_material(lo: float, hi: float) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = load("res://src/bench/annulus.gdshader")
    m.set_shader_parameter("lo_m", lo)
    m.set_shader_parameter("hi_m", hi)
    return m


func _override_all(m: ShaderMaterial) -> void:
    for n in _drawables():
        if not _saved_overrides.has(n):
            _saved_overrides[n] = n.material_override
        n.material_override = m


func _restore_overrides() -> void:
    for n in _saved_overrides:
        n.material_override = _saved_overrides[n]
    _saved_overrides.clear()


func _drawables() -> Array:
    var out: Array = []
    var t = view.get_node_or_null("Terrain")
    if t != null:
        out.append(t)
    return out


# --------------------------------------------------------------------------
# the candidates
# --------------------------------------------------------------------------

func _run_candidate(delta: float) -> void:
    if job_at >= jobs.size():
        stage = WRITE
        return
    var job: Dictionary = jobs[job_at]
    match job_step:
        0:
            _apply_candidate(job)
            frames = 0
            job_step = 1
        1:
            if frames < HOLD_FRAMES:
                return
            _wall.clear()
            job_step = 2
        2:
            _wall.append(delta * 1000.0)
            if _wall.size() < TIME_FRAMES:
                return
            job["frame_ms"] = FrameStats.summarise(_wall)
            job["in_situ"] = _capture(job, "insitu")
            _isolate(true)
            frames = 0
            job_step = 3
        3:
            if frames < HOLD_FRAMES:
                return
            job["isolated"] = _capture(job, "isolated")
            _isolate(false)
            _score(job)
            results.append(job)
            _say(job)
            if str(job["name"]) == "oracle":
                _fit_curve(job)
            job_at += 1
            job_step = 0
            frames = 0


func _apply_candidate(job: Dictionary) -> void:
    var kind := str(job["kind"])
    var cut: float = float(job["cut_m"])
    view.set_naturalistic(kind == "tint")
    if kind == "tint":
        view.set_range_curve(bool(job.get("matched", false)),
                float(curve["k0"]), float(curve["r0"]))
        job["curve"] = curve.duplicate()
    var t0 := Time.get_ticks_usec()
    var schedule: Array = ([] if cut <= 0.0 else [{"to_m": cut, "keep": 1.0}])
    var ceiling: int = (VegetationScatter.MAX_BUILT_INSTANCES if cut <= 0.0 else 4000000)
    var r: Dictionary = view.scatter_at(at_world, TerrainView.SCATTER_HORIZON_M,
            schedule, ceiling)
    job["build_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
    job["scatter"] = {
        "ok": bool(r.get("ok", false)),
        "placed": r.get("placed", {}),
        "share_drawn": r.get("share_drawn", NAN),
        "share_bound_by": r.get("share_bound_by", ""),
        "implied_after_bands": r.get("implied_after_bands", NAN),
    }
    if kind == "tint":
        job["tint"] = view.tint_report.duplicate()
    _show_all()


func _isolate(on: bool) -> void:
    # Instances are isolated by hiding the ground they stand on; a tint IS the
    # ground, so the shader blacks out everything the coverage mask did not pick.
    view.get_node("Terrain").visible = not on or view.naturalistic
    view.set_isolate_vegetation(on)
    for c in view.get_children():
        if String(c.name).begins_with("Flow") or String(c.name) == "Contours":
            c.visible = not on


## Everything back on, INCLUDING the instances. The mask pass hides them and an
## earlier version of this never turned them back on, so every candidate was
## graded on a frame with no vegetation in it: the oracle scored zero coverage
## and the two tints tied, which reads as a metric that cannot separate rather
## than as a scene that was not drawn.
func _show_all() -> void:
    view.get_node("Terrain").visible = true
    view.set_isolate_vegetation(false)
    for c in view.get_children():
        var n := String(c.name)
        if n.begins_with("Flow") or n == "Contours" or n.begins_with("Vegetation"):
            c.visible = true


func _hide_everything_but_terrain() -> void:
    view.get_node("Terrain").visible = true
    for c in view.get_children():
        if String(c.name).begins_with("Flow") or String(c.name) == "Contours" \
                or String(c.name).begins_with("Vegetation"):
            c.visible = false


func _capture(job: Dictionary, what: String) -> Image:
    var img := get_root().get_texture().get_image()
    img.save_png("res://%s/x%d_%s_%s_%s_d%d_%s.png" % [shots_dir, int(exaggeration),
            window_name, str(job["name"]), row_name.replace(".", "_"), day, what])
    return img


func _score(job: Dictionary) -> void:
    var per_band: Array = []
    for i in bands.size():
        var b: Dictionary = bands[i]
        var iso := SeamScore.within(masks[i], job["isolated"])
        var sit := SeamScore.within(masks[i], job["in_situ"])
        # NULL RATHER THAN NaN. `JSON.stringify` writes NaN as a bare `nan`,
        # which nothing -- including this tool's own `--append` -- can parse
        # back: an artefact carrying one silently becomes a fresh artefact on
        # the next run, and four measured runs went that way once.
        var cov: Variant = SeamScore.coverage(int(iso["lit_pixels"]), ground_px[i])
        if is_nan(float(cov)):
            cov = null
        per_band.append({
            "lo_m": b["lo_m"], "hi_m": b["hi_m"],
            "ground_pixels": ground_px[i],
            "coverage": cov,
            "isolated_mean_colour": iso["mean_colour"],
            "isolated_lit": iso["lit_pixels"],
            "in_situ_mean_colour": sit["mean_colour"],
            "isolated_luminance": iso["luminance_histogram"],
            "in_situ_luminance": sit["luminance_histogram"],
        })
    job["bands"] = per_band
    job["scoring_band"] = SeamScore.scoring_band(seam_m)
    job.erase("isolated")
    job.erase("in_situ")


## The band the score is taken in, as an index into `bands`.
func _scoring_index() -> int:
    var s := SeamScore.scoring_band(seam_m)
    var best := 0
    var closest := INF
    for i in bands.size():
        var mid: float = 0.5 * (float(bands[i]["lo_m"]) + float(bands[i]["hi_m"]))
        var want: float = 0.5 * (float(s["lo_m"]) + float(s["hi_m"]))
        if absf(mid - want) < closest:
            closest = absf(mid - want)
            best = i
    return best


## Fit the range curve to the oracle's own binned colour, rather than choosing
## it. `k(r) = k0 + (1 - k0) exp(-r / r0)` against the ratio of each band's
## brightness to the nearest band's, least squares over a stated grid.
func _fit_curve(oracle: Dictionary) -> void:
    var xs := PackedFloat64Array()
    var ys := PackedFloat64Array()
    var near := NAN
    for b in oracle["bands"]:
        var c: Array = b["isolated_mean_colour"]
        var lum := 0.2126 * float(c[0]) + 0.7152 * float(c[1]) + 0.0722 * float(c[2])
        if int(b["isolated_lit"]) < 200 or lum <= 0.0:
            continue
        if is_nan(near):
            near = lum
        xs.append(0.5 * (float(b["lo_m"]) + float(b["hi_m"])))
        ys.append(lum / near)
    if xs.size() < 3:
        curve = {"k0": 1.0, "r0": 200.0, "fitted": false,
                 "why": ("only %d bands carried enough lit pixels to fit a curve to, so the "
                        + "range-matched candidate is the constant one under another name and "
                        + "the ranking between them means nothing") % xs.size()}
        return
    var best_k := 1.0
    var best_r := 200.0
    var best_err := INF
    for ki in K0_STEPS:
        var k0 := float(ki) / float(K0_STEPS - 1)
        for r0 in R0_CHOICES:
            var err := 0.0
            for i in xs.size():
                var want := k0 + (1.0 - k0) * exp(-float(xs[i]) / float(r0))
                err += pow(want - float(ys[i]), 2.0)
            if err < best_err:
                best_err = err
                best_k = k0
                best_r = float(r0)
    curve = {"k0": best_k, "r0": best_r, "fitted": true,
             "residual": sqrt(best_err / float(xs.size())),
             "bands_fitted": xs.size(),
             "from": "the oracle's own binned isolated brightness, relative to its nearest band"}
    print("curve  k0 %.3f  r0 %.0f m  rms %.4f over %d bands"
            % [best_k, best_r, float(curve["residual"]), xs.size()])


func _say(job: Dictionary) -> void:
    var i := _scoring_index()
    var b: Dictionary = job["bands"][i]
    var c: Array = b["isolated_mean_colour"]
    var placed := 0
    for g in job["scatter"].get("placed", {}):
        placed += int(job["scatter"]["placed"][g])
    print("%-14s %8d inst  build %6.0f ms  frame p50 %6.2f  annulus %.0f-%.0f m: "
            % [str(job["name"]), placed, float(job["build_ms"]),
               float(job["frame_ms"]["p50"]), float(b["lo_m"]), float(b["hi_m"])]
            + "cover %s  colour (%.3f, %.3f, %.3f) over %d ground px"
            % ["--" if b["coverage"] == null else String.num(float(b["coverage"]), 3),
               float(c[0]), float(c[1]), float(c[2]),
               int(b["ground_pixels"])])


func _write() -> void:
    var i := _scoring_index()
    var oracle: Dictionary = {}
    for r in results:
        if str(r["name"]) == "oracle":
            oracle = r
    var colour_err: Dictionary = {}
    var cover_err: Dictionary = {}
    var lum_err: Dictionary = {}
    if not oracle.is_empty():
        var ob: Dictionary = oracle["bands"][i]
        for r in results:
            if str(r["name"]) == "oracle":
                continue
            var rb: Dictionary = r["bands"][i]
            colour_err[str(r["name"])] = SeamScore.colour_error(
                    ob["isolated_mean_colour"], rb["isolated_mean_colour"])
            var rc = rb["coverage"]
            var oc = ob["coverage"]
            cover_err[str(r["name"])] = (0.0 if rc == null or oc == null
                    else absf(float(rc) - float(oc)))
            lum_err[str(r["name"])] = SeamScore.luminance_distance(
                    ob["in_situ_luminance"], rb["in_situ_luminance"])
    # A RUN WITH NO GROUND IN ITS SCORING ANNULUS IS NOT A RESULT. It comes back
    # as zero error for every candidate, which reads as a perfect tie rather
    # than as a camera looking at nothing -- so it is recorded as unmeasured
    # with the reason, the way the frame-cost benchmark records a configuration
    # whose frames were not drawn.
    var measured: bool = int(ground_px[i]) > 0
    var run := {
        "measured": measured,
        "why_not": ("" if measured else
                ("no ground at all in the %.0f-%.0f m annulus at this place: the camera is on "
                + "a surface that falls away, and every candidate ties at zero error because "
                + "none of them was scored on anything")
                % [float(bands[i]["lo_m"]), float(bands[i]["hi_m"])]),
        "vertical_exaggeration": exaggeration,
        "scene": {
            "window": window_name, "row": row_name, "day": day,
            "at_world_epsg5070": [at_world.x, at_world.y],
            "seam_m": seam_m,
            "oracle_m": seam_m * ORACLE_MULTIPLE,
            "eye_height_m": EYE_HEIGHT_M,
            "eye_pitch_degrees": EYE_PITCH_DEGREES,
            "camera": "eye level on the DRAWN surface, looking north, pitched down",
        },
        "range_curve": curve,
        "range_curve_note": ("" if float(curve.get("k0", 1.0)) < 0.999 else
                ("the fit returned k0 = 1.000, so there is no range darkening to match here "
                + "and `range_matched` IS `constant` -- identical uniforms, identical frames. "
                + "The two tying is arithmetic, not a metric that cannot separate them.")),
        "scoring_band": SeamScore.scoring_band(seam_m),
        "errors_against_oracle": {
            "isolated_colour": colour_err,
            "coverage": cover_err,
            "in_situ_luminance": lum_err,
        },
        "ranking": {
            "by_colour": SeamScore.rank(colour_err),
            "by_coverage": SeamScore.rank(cover_err),
        },
        "candidates": results,
    }
    var doc := {
        "what": ("what a far-field candidate costs and how far it sits from the instances it "
                + "stands in for, scored in an annulus around the seam"),
        "measured_at_commit": _git_head(),
        "measured_at_commit_means": ("the HEAD the run was taken against; the commit that "
                + "lands this artefact is its child"),
        "vertical_exaggeration": exaggeration,
        "host": {
            "gpu": RenderingServer.get_video_adapter_name(),
            "rendering_method": RenderingServer.get_current_rendering_method(),
            "godot": Engine.get_version_info()["string"],
            "viewport": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
            "fov_degrees": view.rig.fly.fov,
        },
        "method": {
            "annulus": ("one binary mask render per band through annulus.gdshader; a depth "
                    + "image does not survive this renderer's sRGB output"),
            "ground_pixels": "the terrain rendered ALONE through the same annulus",
            "coverage": "plant pixels over ground pixels in the band; may exceed 1",
            "isolated": ("instances with the ground hidden; a tint with the ground written "
                    + "black by the shader, because a tint IS the ground"),
            "curve": ("the range-matched candidate's attenuation is FITTED to the oracle's own "
                    + "binned brightness in this run, not chosen"),
            "camera": ("placed on TerrainMesh.drawn_surface_y, not on the heightfield. The two "
                    + "differ by a mean of 426 m in mesh space and an eye on the field is "
                    + "underground."),
        },
        "runs": [run],
        "not_covered": ("one machine and one seam distance. No crossfade is measured: each "
                + "candidate is scored as if it were the whole far field."),
    }
    if append_to_existing and FileAccess.file_exists(out_path):
        var prior = JSON.parse_string(FileAccess.open(out_path, FileAccess.READ).get_as_text())
        if typeof(prior) == TYPE_DICTIONARY and (prior as Dictionary).has("runs"):
            var runs: Array = (prior as Dictionary)["runs"]
            runs.append(run)
            (prior as Dictionary)["runs"] = runs
            (prior as Dictionary)["measured_at_commit"] = doc["measured_at_commit"]
            doc = prior
    var f := FileAccess.open(out_path, FileAccess.WRITE)
    f.store_string(JSON.stringify(doc, "  ") + "\n")
    f.close()
    print("")
    for k in ["by_colour", "by_coverage"]:
        var rk: Dictionary = run["ranking"][k]
        var line := "%s: " % k
        for o in rk.get("order", []):
            line += "%s %s   " % [str(o["candidate"]), String.num(float(o["error"]), 4)]
        if rk.has("separates"):
            line += "-> %s" % ("separates" if bool(rk["separates"]) else "DOES NOT SEPARATE")
        print(line)
    if not measured:
        printerr("measure_seam: NOT MEASURED -- %s" % str(run["why_not"]))
    if str(run["range_curve_note"]) != "":
        print("note: %s" % str(run["range_curve_note"]))
    print("-> %s   shots: %s" % [out_path, shots_dir])
    stage = DONE
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


func _has(name: String) -> bool:
    return OS.get_cmdline_user_args().has(name)
