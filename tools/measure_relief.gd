extends SceneTree

## WHAT THE GROUND ACTUALLY HAS, at the overview and at the tile pyramid.
##
##     bash tools/measure_relief.sh
##
## THIS EXISTS TO SPLIT TWO BLOCKERS THAT WERE WEARING ONE GATE.
##
## `DebugPlayer.walk_available` refuses walk mode while the ground is sampled
## more coarsely than the distance a body covers in a second. It was written as
## one criterion and it was answering two questions at once:
##
##   MACRO-RELIEF -- is the near field one flat triangle? That is what
##   `measurements/README.md` complains about: a viewer standing in the scatter
##   stands in the middle of a single triangle, so near-field vegetation stands
##   on a plane and every eye-level figure taken there is a figure about a
##   plane.
##
##   UNDERFOOT -- does the ground change as a body walks over it? That is a
##   proprioceptive question and it implies metre-scale micro-relief, which is
##   a different product from a terrain pyramid.
##
## The pyramid answers the first and cannot answer the second, so a single
## number reporting "still refuses" hides a 40x improvement in the thing that
## was actually broken. This measures both, separately, against the same
## ground.
##
## HEADLESS BY DESIGN, unlike the seam and motion tools: nothing here is
## measured in pixels. It is two grids and their difference.
##
##   --radius M     the disc a standing body sees near field in (default 480,
##                  which is what tools/free_flight.gd builds)
##   --samples N    how many places to stand (default 64)
##   --out PATH     artefact path (default measurements/ground_relief.json)

const TERRAIN_DIR := "res://assets/terrain/"


func _init() -> void:
    var args := _args()
    var radius := maxf(1.0, float(args.get("radius", "480")))
    var wanted := int(args.get("samples", "64"))
    var out_path := str(args.get("out", "measurements/ground_relief.json"))

    var manifest := _read_json(TERRAIN_DIR + "terrain_export.json")
    var hf := Heightfield.load_from(manifest, TERRAIN_DIR + "heightfield_overview.png")
    if not hf.is_loaded():
        _refuse(out_path, "the overview heightfield did not load")
        return
    var tm := TerrainMesh.new()
    tm.build(hf, 4, 1.0)

    var tp := TilePyramid.load_from()
    if not tp.is_loaded():
        _refuse(out_path, ("no tile pyramid: %s. This measurement compares two grids and "
                + "cannot report on one.") % tp.why_absent)
        return
    var inv := tp.inventory()
    if int(inv["present"]) == 0:
        _refuse(out_path, ("the pyramid is pinned and none of its %d tiles is fetched. "
                + "`python3 tools/fetch_artefacts.py` brings them in; reporting zeros here "
                + "would be a measurement of this clone rather than of the basin.")
                % int(inv["keyed"]))
        return

    # WHERE TO STAND. Deterministic: every valid overview texel, at a fixed
    # stride through the list, so two runs measure the same places and a
    # difference between them is a difference in the data.
    var valid: Array = []
    for ty in range(2, hf.height - 2):
        for tx in range(2, hf.width - 2):
            if not is_nan(hf.height_at_texel(tx, ty)):
                valid.append(Vector2i(tx, ty))
    if valid.is_empty():
        _refuse(out_path, "the overview has no valid ground")
        return
    var step: int = maxi(1, valid.size() / wanted)

    var drawn_sample_m := hf.pixel_size_m * float(tm.stride)
    var native_m := tp.finest_pixel_size_m()

    var places: Array = []
    var residuals: Array = []
    var native_reliefs: Array = []
    var drawn_reliefs: Array = []
    var native_texels: Array = []
    var mesh_vertices: Array = []
    var i := 0
    var skipped_unfetched := 0
    while i < valid.size() and places.size() < wanted:
        var t: Vector2i = valid[i]
        i += step
        # SNAPPED TO A NATIVE TEXEL CENTRE. The overview's texel centres land
        # exactly on native texel CORNERS -- 1000/100 is ten, so an overview
        # centre is 10n + 4.5 native pixels -- and a sample sitting on a tie
        # measures the rounding rule rather than the ground. Found by a first
        # run in which five of sixty places "changed" under a 0.7 m step and
        # the same five under a 5 m step, which is not how ground works.
        var centre := _snap(tp, hf.texel_to_world(float(t.x), float(t.y)), native_m)
        var here := _disc(tp, tm, hf, centre, radius, native_m)
        if not bool(here["ok"]):
            if str(here.get("why", "")) == TilePyramid.NOT_FETCHED:
                skipped_unfetched += 1
            continue
        places.append(here)
        residuals.append(float(here["worst_residual_m"]))
        native_reliefs.append(float(here["native_relief_m"]))
        drawn_reliefs.append(float(here["drawn_relief_m"]))
        native_texels.append(float(here["native_texels_in_disc"]))
        mesh_vertices.append(float(here["mesh_vertices_in_disc"]))

    if places.is_empty():
        _refuse(out_path, "no place could be measured against both grids")
        return

    # THE UNDERFOOT QUESTION, MEASURED RATHER THAN ARGUED, and measured as a
    # DISTANCE rather than as a yes at one step length.
    #
    # "Does a 5 m step change the height" is a question about where the step
    # started: from a texel centre the answer is always no, from within 5 m of
    # a boundary always yes, and the average is the step over the texel. So the
    # measurement walks a line and records how far the body goes between one
    # reported height and the next. That number is a property of the grid, it
    # is what the criterion is really asking about, and it converts to seconds
    # by dividing by a speed rather than by re-running anything.
    var walk_m := float(args.get("walk", "600"))
    var runs: Array = []
    for p in places:
        var c: Vector2 = p["centre"]
        var headings: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.0, 1.0),
                Vector2(0.7071, 0.7071)]
        for heading in headings:
            var last := tp.height_at_world(c.x, c.y)
            var since := 0.0
            var d := 1.0
            while d <= walk_m:
                var q: Vector2 = c + heading * d
                var h := tp.height_at_world(q.x, q.y)
                if is_nan(h):
                    break
                since += 1.0
                if h != last:
                    runs.append(since)
                    since = 0.0
                    last = h
                d += 1.0
    var run_q: Dictionary = FlightTrace.quantiles(runs)
    var underfoot := {}
    for name in {"ruled_5_0_m_s": 5.0, "pandolf_0_7_m_s": 0.7}:
        var speeds := {"ruled_5_0_m_s": 5.0, "pandolf_0_7_m_s": 0.7}
        var speed := float(speeds[name])
        var p50 := float(run_q.get("p50", NAN))
        underfoot[name] = {
            "sustainable_speed_m_s": speed,
            "metres_per_second_of_walking": speed,
            "seconds_between_ground_changes_p50": p50 / speed,
            "meets_the_criterion": p50 <= speed,
            "verdict": (("the ground changes every %s m, which at %s m/s is %s seconds of "
                    + "walking between one height and the next")
                    % [String.num(p50, 1), String.num(speed, 1),
                            String.num(p50 / speed, 1)]),
        }

    var doc := {
        "measurement": "ground relief at the overview and at the tile pyramid",
        "measured_at_utc": Time.get_datetime_string_from_system(true),
        "vertical_exaggeration": tm.exaggeration,
        "_exaggeration_is": ("1:1, and it has to be for this artefact to mean anything: every "
                + "number here is a vertical distance compared with a horizontal one, and an "
                + "exaggerated mesh would inflate the residual against ground that had not "
                + "moved."),
        "grids": {
            "drawn_today": {
                "source": "heightfield_overview.png triangulated at stride %d" % tm.stride,
                "sample_m": drawn_sample_m,
            },
            "native": {
                "source": "tile pyramid z=0",
                "sample_m": native_m,
                "tiles_keyed": int(inv["keyed"]),
                "tiles_present": int(inv["present"]),
            },
            "_why_two_encodings": ("the pyramid decodes with its own offset and scale, not the "
                    + "overview's. Both grids resample with `average`, which pulls extremes in "
                    + "by an amount that depends on pixel footprint; the native grid measures "
                    + "about 53 m higher at the top. A clipped code is a valid code, so "
                    + "decoding a tile with the overview's pair fails silently."),
        },
        "disc": {
            "radius_m": radius,
            "_why": ("what tools/free_flight.gd builds a scatter within, so it is the ground a "
                    + "standing body has near field"),
            "places_measured": places.size(),
            "places_skipped_unfetched": skipped_unfetched,
        },
        "macro_relief": {
            "_question": "is the near field one flat triangle?",
            "native_texels_in_disc": FlightTrace.quantiles(native_texels),
            "mesh_vertices_in_disc": FlightTrace.quantiles(mesh_vertices),
            "_vertices_is": ("how many ground samples the DRAWN mesh has inside the disc a "
                    + "standing body sees near field. Zero or one means the whole near field "
                    + "is inside a single triangle, which is `measurements/README.md`'s "
                    + "blocker stated as a count rather than as a complaint."),
            "native_relief_m": FlightTrace.quantiles(native_reliefs),
            "drawn_relief_m": FlightTrace.quantiles(drawn_reliefs),
            "worst_residual_m": FlightTrace.quantiles(residuals),
            "_residual_is": ("the largest gap between the drawn surface and the native grid "
                    + "inside one disc: how far a plant placed on the drawn plane stands from "
                    + "the ground the data actually has"),
        },
        "underfoot": {
            "_question": "does the ground change as a body walks over it?",
            "_criterion": ("DebugPlayer.walk_available: the ground must change at least once "
                    + "per second of walking, so its sample spacing must be no coarser than "
                    + "the distance the body's own sustainable speed covers in a second"),
            "metres_between_ground_changes": run_q,
            "_measured_by": ("walking %s m from each place on three headings at 1 m steps and "
                    + "recording the distance between one reported height and the next. A "
                    + "distance rather than a yes-or-no at one step length: whether a 5 m step "
                    + "changes the height is a question about where the step started."),
            "by_speed": underfoot,
        },
        "places": places,
    }
    _write(out_path, doc)
    print("relief: near field holds %s mesh vertices and %s native texels (p50)"
            % [String.num(float((doc["macro_relief"]["mesh_vertices_in_disc"] as Dictionary)
                    .get("p50", NAN)), 0),
                    String.num(float((doc["macro_relief"]["native_texels_in_disc"]
                            as Dictionary).get("p50", NAN)), 0)])
    print("relief: %d places, native relief p50 %s m against drawn %s m; residual p50 %s m, "
            % [places.size(),
                    String.num(float((doc["macro_relief"]["native_relief_m"] as Dictionary)
                            .get("p50", NAN)), 1),
                    String.num(float((doc["macro_relief"]["drawn_relief_m"] as Dictionary)
                            .get("p50", NAN)), 1),
                    String.num(float((doc["macro_relief"]["worst_residual_m"] as Dictionary)
                            .get("p50", NAN)), 1)]
            + "max %s m" % String.num(float((doc["macro_relief"]["worst_residual_m"]
                    as Dictionary).get("max", NAN)), 1))
    print("relief: the ground changes every %s m (p50 over %d walked runs)"
            % [String.num(float(run_q.get("p50", NAN)), 1), runs.size()])
    for name in underfoot:
        var u: Dictionary = underfoot[name]
        print("relief: at %s m/s -- %s%s" % [String.num(float(u["sustainable_speed_m_s"]), 1),
                str(u["verdict"]), "" if bool(u["meets_the_criterion"]) else " (REFUSES)"])
    quit(0)


## How many of the drawn mesh's own ground samples fall inside a disc.
##
## The mesh triangulates the heightfield every `stride` texels, so its vertices
## sit on a lattice of `stride x pixel_size` metres. Counting them is the
## direct form of the near-field blocker: a body whose whole visible near field
## contains no mesh vertex is standing in the middle of one triangle, and every
## plant around it stands on a plane.
func _vertices_in(hf: Heightfield, tm: TerrainMesh, centre: Vector2, radius: float) -> int:
    var spacing := hf.pixel_size_m * float(tm.stride)
    var reach := int(ceil(radius / spacing)) + 1
    var t := hf.world_to_texel(centre.x, centre.y)
    var n := 0
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            # Vertices land on texels that are multiples of the stride.
            var vx := (int(round(t.x)) / tm.stride + dx) * tm.stride
            var vy := (int(round(t.y)) / tm.stride + dy) * tm.stride
            var w := hf.texel_to_world(float(vx), float(vy))
            if (w - centre).length() <= radius and not is_nan(hf.height_at_texel(vx, vy)):
                n += 1
    return n


## A world point moved to the centre of the native texel it falls in, so no
## sample sits on a boundary tie.
func _snap(tp: TilePyramid, p: Vector2, native_m: float) -> Vector2:
    var at := tp.locate(p.x, p.y)
    if not bool(at.get("ok", false)):
        return p
    var t: Vector2i = at["texel"]
    return Vector2(tp.origin.x + (float(t.x) + 0.5) * native_m,
            tp.origin.y - (float(t.y) + 0.5) * native_m)


## One disc: what the native grid has in it, and what the drawn surface says.
func _disc(tp: TilePyramid, tm: TerrainMesh, hf: Heightfield, centre: Vector2,
           radius: float, native_m: float) -> Dictionary:
    var at := tp.locate(centre.x, centre.y)
    if not bool(at.get("ok", false)):
        return {"ok": false, "why": "off grid"}
    var avail := tp.availability(str(at["key"]))
    if avail != TilePyramid.PRESENT:
        return {"ok": false, "why": avail}
    var native_lo := INF
    var native_hi := -INF
    var drawn_lo := INF
    var drawn_hi := -INF
    var worst := 0.0
    var taken := 0
    var reach := int(radius / native_m)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            var p := Vector2(centre.x + float(dx) * native_m, centre.y + float(dy) * native_m)
            if (p - centre).length() > radius:
                continue
            var n := tp.height_at_world(p.x, p.y)
            if is_nan(n):
                continue
            var d := tm.drawn_surface_y(p, hf)
            if is_nan(d):
                continue
            taken += 1
            native_lo = minf(native_lo, n)
            native_hi = maxf(native_hi, n)
            drawn_lo = minf(drawn_lo, d)
            drawn_hi = maxf(drawn_hi, d)
            worst = maxf(worst, absf(n - d))
            # Counted at centimetre resolution: two samples reading the same
            # height to the millimetre are the same height for this question.

    if taken < 8:
        return {"ok": false, "why": "only %d samples" % taken}
    return {
        "ok": true,
        "centre": centre,
        "samples": taken,
        "native_relief_m": native_hi - native_lo,
        "drawn_relief_m": drawn_hi - drawn_lo,
        "worst_residual_m": worst,
        "native_texels_in_disc": taken,
        "mesh_vertices_in_disc": _vertices_in(hf, tm, centre, radius),
    }


func _args() -> Dictionary:
    var out := {}
    var argv := OS.get_cmdline_user_args()
    var i := 0
    while i < argv.size():
        var a := str(argv[i])
        if a.begins_with("--") and i + 1 < argv.size():
            out[a.substr(2)] = str(argv[i + 1])
            i += 2
        else:
            i += 1
    return out


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _refuse(path: String, why: String) -> void:
    print("relief: REFUSED -- %s" % why)
    _write(path, {"refused": true, "why": why,
            "measured_at_utc": Time.get_datetime_string_from_system(true)})
    quit(1)


func _write(path: String, doc: Dictionary) -> void:
    var f := FileAccess.open("res://" + path, FileAccess.WRITE)
    if f == null:
        push_error("cannot write %s" % path)
        return
    f.store_string(JSON.stringify(doc, "  ") + "\n")
