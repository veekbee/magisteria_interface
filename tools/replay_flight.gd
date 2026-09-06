extends SceneTree

## Score a recorded flight again, headlessly, without the person who flew it.
##
##     bash tools/replay_flight.sh --trace measurements/flights/scripted.trace.json
##     bash tools/replay_flight.sh --synthesise measurements/flights/scripted.trace.json
##
## THIS IS WHY THE TRACE EXISTS. An interactive harness produces a judgement
## nobody can reproduce. Recording the path and replaying it turns one human
## session into a fixture: the same frames, the same populations, the same
## churn, on any machine, forever.
##
## HEADLESS ON PURPOSE, WHICH IS THE OPPOSITE OF EVERY OTHER HARNESS HERE. The
## others photograph frames and therefore refuse the dummy renderer. This one
## photographs nothing: what it recomputes is the POPULATION -- which instances
## existed and how the set changed -- and that is pure arithmetic over the
## scatter's own census. It is exact rather than sampled, and it is exact
## because placement is a function of the ground: two builds that admit one
## sub-cell hold prefixes of one fixed order, so what they share is a minimum.
##
## AND FRAME TIME DOES NOT COME BACK. A frame that is not drawn costs nothing,
## so the frame times in the artefact are the flight's own measurements carried
## through, never re-derived. The artefact says so per column rather than
## leaving a reader to assume.
##
## THE AGREEMENT CHECK IS THE POINT OF STORING BOTH. The trace records what the
## flight measured; the replay recomputes it from the poses alone. Where they
## disagree, either the flight was not deterministic or the replay is not
## faithful, and both are worth knowing before a number is quoted off either.

const EYE_HEIGHT_M := 1.7
const SETTLE_FRAMES := 12

## Headings the in-view count is bucketed into. Twelve buckets of 30 degrees:
## fine enough to see a lobe, coarse enough that a three-minute flight puts
## frames in most of them.
const HEADING_BUCKETS := 12

## Frames of context kept either side of a mark.
const MARK_WINDOW := 12

## Seconds after a stall within which a mark is taken to be ABOUT that stall.
## Generous, and generous on purpose: a person notices a freeze, waits to see
## whether it resolves, and then decides to report it. The first flown trace
## put fifteen of its sixteen marks between 2.0 and 2.1 s after a rebuild,
## which is that sequence with a very steady hand on it.
const STALL_REACTION_S := 4.0

enum { SETTLE, PLACE, RUN, WRITE, DONE }

var scene: Node = null
var view = null
var stage := SETTLE
var _stage_frames := 0

var trace_path := "measurements/flights/scripted.trace.json"
var out_path := "measurements/flight_replay.json"
var synthesise := ""
var append_to_existing := false
var synth_seconds := 60.0
var synth_fps := 60.0
var synth_recentre := 25.0

var trace: FlightTrace = null
var rows: Array = []
var frame_at := 0
var _prev_census: Dictionary = {}
var _build_centre := Vector2.ZERO
var _builds := 0
var _k := 0.0
var _radius := 480.0
var _fov := 75.0
var _aspect := 1.6


func _initialize() -> void:
    trace_path = _arg("--trace", trace_path)
    out_path = _arg("--out", out_path)
    synthesise = _arg("--synthesise", synthesise)
    append_to_existing = OS.get_cmdline_user_args().has("--append")
    synth_seconds = float(_arg("--seconds", str(synth_seconds)))
    synth_recentre = float(_arg("--recentre", str(synth_recentre)))
    var packed: PackedScene = load("res://scenes/main.tscn")
    scene = packed.instantiate()
    get_root().add_child(scene)


func _process(_delta: float) -> bool:
    _stage_frames += 1
    var stall := HarnessGuard.stall_note(_stage_name(), _stage_frames)
    if stall != "":
        printerr("replay_flight: REFUSED. %s" % stall)
        quit(4)
        return true
    if view == null:
        view = scene._terrain
        return false
    match stage:
        SETTLE:
            if _stage_frames > SETTLE_FRAMES:
                _place()
        RUN:
            _run()
        WRITE:
            _write()
    return false


func _stage_name() -> String:
    return ["settle", "place", "run", "write", "done"][stage]


func _place() -> void:
    stage = PLACE
    _stage_frames = 0
    if synthesise != "":
        _synthesise()
        return
    var loaded := FlightTrace.load_from(trace_path)
    if not bool(loaded["ok"]):
        printerr("replay_flight: %s" % str(loaded["why"]))
        quit(2)
        return
    trace = loaded["trace"]
    _enter_scene(trace.header)
    stage = RUN
    _stage_frames = 0
    print("replaying %d frames of %s" % [trace.frames.size(), trace_path])


## Put the world in the state the flight was flown in.
##
## FROM THE TRACE'S HEADER, NOT FROM THIS MACHINE. The field of view and the
## aspect ratio decide what a heading has in front of it, and a replay on a
## differently sized window would silently answer a different question. They
## are read back from the flight rather than from the viewport that is not
## being drawn.
func _enter_scene(header: Dictionary) -> void:
    var about: Dictionary = header["scene"]
    var set_to: Dictionary = scene.scrubber.select(str(about["window"]), str(about["row"]),
            int(about["day"]))
    if not bool(set_to["ok"]):
        printerr("replay_flight: %s" % str(set_to["why"]))
        quit(2)
        return
    _k = float(header["individuation_k"])
    _radius = float(header["scatter_radius_m"])
    _fov = float(header["fov_degrees"])
    var vp: Array = header["viewport"]
    _aspect = float(vp[0]) / float(vp[1])
    var at: Array = about["at_world_epsg5070"]
    var probe: Dictionary = view.probe_world(float(at[0]), float(at[1]))
    if probe.has("world"):
        scene._on_probed(probe)
    _build(Vector2(float(at[0]), float(at[1])), true)


func _build(centre: Vector2, first: bool) -> void:
    if not first:
        _prev_census = view.scatter.census
    view.scatter_at(centre, _radius, [], VegetationScatter.MAX_BUILT_INSTANCES, _k)
    _build_centre = centre
    _builds += 1


# --------------------------------------------------------------------------
# the replay
# --------------------------------------------------------------------------

func _run() -> void:
    # A budget per tick rather than the whole flight in one, so the stall guard
    # still means something and a long trace does not look like a hang.
    var until := Time.get_ticks_msec() + 400
    while frame_at < trace.frames.size():
        _score_frame(frame_at)
        frame_at += 1
        if Time.get_ticks_msec() > until:
            if frame_at % 200 < 8:
                print("  frame %d/%d" % [frame_at, trace.frames.size()])
            _stage_frames = 0
            return
    stage = WRITE
    _stage_frames = 0


func _score_frame(i: int) -> void:
    var row: Dictionary = trace.frames[i]
    var pose := FlightTrace.pose_of(row)
    var world_here: Vector2 = view.terrain.mesh_to_world(
            Vector3(pose.origin.x, 0.0, pose.origin.z), view.heightfield)

    # THE RULE IS RE-APPLIED, NOT THE RECORDED FLAG READ BACK. Deriving the
    # rebuild from the poses is what makes this a replay rather than a
    # playback; the recorded flag is then something to disagree with, and the
    # artefact reports where it does.
    var recentre := float(trace.header.get("recentre_m", 0.0))
    var rebuilt := false
    if recentre > 0.0 and (world_here - _build_centre).length() >= recentre:
        _build(world_here, false)
        rebuilt = true

    var cen: Dictionary = view.scatter.census
    var churn := (FlightTrace.churn_between(_prev_census, cen) if rebuilt
            else {"gone_fraction": 0.0, "churn_fraction": 0.0, "gone": 0, "appeared": 0,
                  "survived": 0})
    var seen := FlightTrace.in_view(cen, pose, _fov, _aspect)
    rows.append({
        "frame": i,
        "t_ms": float(row["t_ms"]),
        "heading_degrees": _heading_of(pose),
        "pitch_degrees": _pitch_of(pose),
        "rebuilt": rebuilt,
        "build_centre_epsg5070": [_build_centre.x, _build_centre.y],
        "rebuilt_in_flight": bool(row.get("rebuilt", false)),
        "instances": FlightTrace.population(cen),
        "instances_in_flight": int(row.get("instances", -1)),
        "in_view_instances": int(seen["instances"]),
        "in_view_in_flight": int(row.get("in_view_instances", -1)),
        "gone_fraction": float(churn["gone_fraction"]),
        "gone_fraction_in_flight": float(row.get("gone_fraction", 0.0)),
        "churn_fraction": float(churn["churn_fraction"]),
        "frame_ms_in_flight": float(row.get("frame_ms", 0.0)),
        # THE BUILD'S OWN DURATION, WHICH IS THE STALL. It was already being
        # recorded before anyone knew to look for it -- what was missing was
        # anything that read it as blocked time rather than as a cost.
        "blocked_ms_in_flight": float(row.get("build_ms", 0.0)),
        "mark": int(row.get("mark", FlightTrace.MARK_NONE)),
        "drawn_in_flight": bool(row.get("drawn", true)),
    })


## Compass heading in degrees, 0 north, from the camera's own forward.
static func _heading_of(pose: Transform3D) -> float:
    var f := -pose.basis.z
    return fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)


## How far above or below level the camera looks. Carried because a heading
## comparison is only meaningful between frames at a comparable attitude: a
## camera pitched at the sky has nothing in front of it whatever its heading,
## and averaging those into a bucket makes a heading look empty when it is not.
static func _pitch_of(pose: Transform3D) -> float:
    var f := -pose.basis.z
    return rad_to_deg(asin(clampf(f.y, -1.0, 1.0)))


# --------------------------------------------------------------------------
# a scripted trace, so the instrument is testable before anyone flies it
# --------------------------------------------------------------------------

## A walked path with a pan in it, written in the trace's own format.
##
## NOT A FLIGHT AND IT SAYS SO IN ITS OWN HEADER. It exists so the replay, the
## churn arithmetic and the gate have something to run against on a machine
## with nobody at it -- and so that the day a person does fly, the instrument
## has already been shown to work. What it cannot supply is the one thing a
## person is here for: it carries NO MARKS, so the threshold question stays
## exactly as open as it was.
func _synthesise() -> void:
    var w: String = str(view.fixture.windows[0])
    for cand in view.fixture.windows:
        if str(cand) == "deepest_winter":
            w = "deepest_winter"
    var about := {"window": w, "row": "band.pft.biomass", "day": 22,
                  "at_world_epsg5070": [-1212793.0, 1376226.0]}
    var set_to: Dictionary = scene.scrubber.select(str(about["window"]), str(about["row"]),
            int(about["day"]))
    if not bool(set_to["ok"]):
        printerr("replay_flight: %s" % str(set_to["why"]))
        quit(2)
        return
    var probe: Dictionary = view.probe_world(float(about["at_world_epsg5070"][0]),
            float(about["at_world_epsg5070"][1]))
    if not probe.has("world"):
        printerr("replay_flight: the probe did not resolve to ground")
        quit(2)
        return
    scene._on_probed(probe)
    view.focus_on_scatter()
    var k_res := VegetationScatter.resolution_k(800.0, 75.0)

    var t := FlightTrace.new()
    t.begin({
        "what": ("a SCRIPTED walk with a pan in it -- not a flight. It exists so the replay "
                + "and the gate have a path to score with nobody at the machine."),
        "flown_by": ("a script. No person saw these frames, so the trace carries no marks and "
                + "says nothing about what is visible. That answer needs a person."),
        "recorded_at_commit": _git_head(),
        "scene": about,
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "viewport": [1280, 800],
        "fov_degrees": 75.0,
        "eye_height_m": EYE_HEIGHT_M,
        "asked_speed_m_s": 5.0,
        "individuation_k": 0.35 * k_res,
        "k_over_k_res": 0.35,
        "k_resolution": k_res,
        "scatter_radius_m": 480.0,
        "recentre_m": synth_recentre,
        "recentre_means": ("metres the camera may travel before the scatter is rebuilt around "
                + "it. 0 is one build flown through, which is what ships; above 0 is a "
                + "population that follows the camera, which is what a per-place instance "
                + "budget does"),
        "marks_mean": "none: a script cannot judge",
        "frame_ms_is": ("the script's own cadence, not a measurement of anything. A real "
                + "flight's frame_ms is measured; this one is 1/fps by construction."),
    })

    var centre: Vector2 = probe["world"]
    var start: Vector3 = view.scatter_centre_mesh
    var surface: float = view.terrain.drawn_surface_y(centre, view.heightfield)
    var ground: float = start.y if is_nan(surface) else surface
    var n := int(synth_seconds * synth_fps)
    var dt := 1.0 / synth_fps
    for i in n:
        var time := float(i) * dt
        # WALK AND PAN AT THE SAME TIME, because a person does. The pan is a
        # slow sweep rather than a flick: two full sweeps over the walk, which
        # puts the heading through every bucket twice and lets the same ground
        # be seen from two directions.
        var yaw := 60.0 * sin(TAU * time / (synth_seconds * 0.5))
        var pitch := -6.0
        # The path itself is a straight walk north, so heading and travel are
        # independent and the pan's effect is separable from the walk's.
        var pos := Vector3(start.x, ground + EYE_HEIGHT_M, start.z - 5.0 * time)
        var here_ground: float = view.terrain.drawn_surface_y(
                view.terrain.mesh_to_world(Vector3(pos.x, 0.0, pos.z), view.heightfield),
                view.heightfield)
        if not is_nan(here_ground):
            pos.y = here_ground + EYE_HEIGHT_M
        var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
        t.add(time * 1000.0, Transform3D(basis, pos), {
            "frame_ms": dt * 1000.0,
            "mark": FlightTrace.MARK_NONE,
            "drawn": false,
        })
    t.header["frames"] = t.frames.size()
    t.header["seconds"] = synth_seconds
    t.header["marks"] = 0
    t.header["frames_not_drawn"] = t.frames.size()
    var motion := FlightTrace.motion_of(t.frames)
    var speeds: Array = []
    var turns: Array = []
    for m in motion:
        speeds.append(float((m as Dictionary)["speed_m_s"]))
        turns.append(float((m as Dictionary)["turn_degrees_s"]))
    t.header["speed_m_s_measured"] = FlightTrace.quantiles(speeds)
    t.header["turn_degrees_s_measured"] = FlightTrace.quantiles(turns)
    var dir := synthesise.get_base_dir()
    if dir != "" and not DirAccess.dir_exists_absolute(dir):
        DirAccess.make_dir_recursive_absolute(dir)
    var saved := t.save(synthesise)
    if not bool(saved["ok"]):
        printerr("replay_flight: %s" % str(saved["why"]))
        quit(5)
        return
    print("synthesised %d frames over %s s -> %s"
            % [t.frames.size(), String.num(synth_seconds, 0), synthesise])
    stage = DONE
    quit(0)


# --------------------------------------------------------------------------
# the artefact
# --------------------------------------------------------------------------

func _write() -> void:
    var churn: Array = []
    var in_view: Array = []
    var pop: Array = []
    var frame_ms: Array = []
    var pitch: Array = []
    var blocked: Array = []
    var blocked_total := 0.0
    var empty_frames := 0
    var compared := 0
    var disagreed := 0
    var worst_disagreement := 0
    var rebuilds := 0
    for r in rows:
        var row: Dictionary = r
        # CHURN IS AN EVENT, NOT A LEVEL. Only a rebuild can change the
        # population, so quantiles over every frame are quantiles over a list
        # that is mostly zero by construction -- 1,794 zeros and six numbers
        # reads as a p95 of 0.0 and says nothing. The rebuild frames are the
        # sample; the count of them is the other half of the statistic.
        if bool(row["rebuilt"]):
            churn.append(float(row["gone_fraction"]))
            rebuilds += 1
        in_view.append(float(row["in_view_instances"]))
        pop.append(float(row["instances"]))
        frame_ms.append(float(row["frame_ms_in_flight"]))
        pitch.append(float(row["pitch_degrees"]))
        if float(row["blocked_ms_in_flight"]) > 0.0:
            blocked.append(float(row["blocked_ms_in_flight"]))
            blocked_total += float(row["blocked_ms_in_flight"])
        if int(row["in_view_instances"]) == 0:
            empty_frames += 1
        if int(row["instances_in_flight"]) >= 0:
            compared += 1
            var d: int = absi(int(row["instances"]) - int(row["instances_in_flight"]))
            if d > 0:
                disagreed += 1
                worst_disagreement = maxi(worst_disagreement, d)

    var by_heading: Array = []
    for b in HEADING_BUCKETS:
        by_heading.append({"from_degrees": float(b) * 360.0 / float(HEADING_BUCKETS),
                           "frames": 0, "in_view_total": 0.0})
    for r in rows:
        var row2: Dictionary = r
        var b2 := int(floor(float(row2["heading_degrees"]) / (360.0 / float(HEADING_BUCKETS))))
        b2 = clampi(b2, 0, HEADING_BUCKETS - 1)
        var bucket: Dictionary = by_heading[b2]
        bucket["frames"] = int(bucket["frames"]) + 1
        bucket["in_view_total"] = float(bucket["in_view_total"]) + float(row2["in_view_instances"])
    var lo := -1.0
    var hi := 0.0
    for b3 in by_heading:
        var bucket3: Dictionary = b3
        if int(bucket3["frames"]) == 0:
            bucket3["in_view_mean"] = null
            continue
        var mean := float(bucket3["in_view_total"]) / float(bucket3["frames"])
        bucket3["in_view_mean"] = mean
        bucket3.erase("in_view_total")
        hi = maxf(hi, mean)
        lo = mean if lo < 0.0 else minf(lo, mean)

    # WHAT A MARK WAS ABOUT, WHICH IS NOT THE SAME QUESTION AS WHAT THE FRAME
    # HELD. The first flown trace came back with sixteen marks, and every one
    # of them was within about two seconds of a scatter rebuild blocking the
    # main loop for 1.8 s. The flyer was not marking the far field; they were
    # marking a freeze, and reported it as one. A mark analysis that only
    # quoted the churn and the population at that frame would have shown
    # sixteen unremarkable rows and lost the finding entirely.
    #
    # So every mark is placed against the nearest preceding stall, in seconds
    # of flight rather than frames -- a person reacts in time, not in frames,
    # and a stall makes frames stop happening.
    var stalls: Array = []
    for r3 in rows:
        var row3: Dictionary = r3
        if float(row3["blocked_ms_in_flight"]) > 0.0:
            stalls.append(row3)
    var marks := FlightTrace.marks_in(trace.frames, MARK_WINDOW)
    var at_marks: Array = []
    var marks_after_a_stall := 0
    for m in marks:
        var mark: Dictionary = m
        var i: int = int(mark["frame"])
        var w: Array = mark["window_frames"]
        var worst := 0.0
        for j in range(int(w[0]), mini(i + 1, rows.size())):
            worst = maxf(worst, float((rows[j] as Dictionary)["gone_fraction"]))
        var since := -1.0
        var stall_ms := 0.0
        for st in stalls:
            var stall: Dictionary = st
            if int(stall["frame"]) <= i:
                since = (float(mark["t_ms"]) - float(stall["t_ms"])) / 1000.0
                stall_ms = float(stall["blocked_ms_in_flight"])
        var near := since >= 0.0 and since <= STALL_REACTION_S
        if near:
            marks_after_a_stall += 1
        at_marks.append({
            "frame": i,
            "t_ms": float(mark["t_ms"]),
            "seconds_since_the_last_stall": since if since >= 0.0 else null,
            "that_stall_blocked_ms": stall_ms if since >= 0.0 else null,
            "within_reaction_of_a_stall": near,
            "gone_fraction_at_mark": (float((rows[i] as Dictionary)["gone_fraction"])
                    if i < rows.size() else null),
            "worst_gone_fraction_in_the_window_before": worst,
            "frame_ms_at_mark": (float((rows[i] as Dictionary)["frame_ms_in_flight"])
                    if i < rows.size() else null),
            "in_view_at_mark": (int((rows[i] as Dictionary)["in_view_instances"])
                    if i < rows.size() else null),
        })

    var flight_ms := (float((rows[rows.size() - 1] as Dictionary)["t_ms"])
            if not rows.is_empty() else 0.0)
    var run := {
        "what": ("a recorded walk through the far field, scored again from its poses alone"),
        "trace": trace_path,
        "trace_header": trace.header,
        "replayed_at_commit": _git_head(),
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "frames": rows.size(),
        "builds": _builds,
        "replay_agreement": {
            "frames_compared": compared,
            "frames_disagreeing_on_population": disagreed,
            "worst_disagreement_instances": worst_disagreement,
            # A CHECK THAT COMPARED NOTHING IS NOT A CHECK THAT PASSED, and
            # this one compares nothing on a synthesised trace by construction:
            # a script builds no scatter, so it records no population to
            # disagree with. Saying "exact" there would be the shape of defect
            # this repo keeps finding in its own harnesses.
            "ok": disagreed == 0 and compared > 0,
            "ran": compared > 0,
            "why_not": ("" if compared > 0 else "this trace records no per-frame population, "
                    + "which is what a synthesised path looks like: nothing was built while "
                    + "it was written, so there is nothing to disagree with. The check goes "
                    + "live the first time a flown trace is replayed."),
            "what": ("the flight recorded what it measured; this recomputed it from the poses "
                    + "alone. They have to agree exactly, because placement is a function of "
                    + "the ground and the rebuild rule is a function of the path. A "
                    + "disagreement means the flight was not deterministic or this replay is "
                    + "not faithful, and neither is a thing to quote a number over."),
            "not_compared": ("frame time. A headless frame is not drawn and costs nothing, so "
                    + "the milliseconds in this artefact are the FLIGHT's measurements "
                    + "carried through and are never re-derived."),
        },
        "per_frame": {
            "rebuilds": rebuilds,
            "gone_fraction_at_rebuilds": FlightTrace.quantiles(churn),
            "gone_fraction_is": ("over the frames that REBUILT, which are the only frames that "
                    + "can churn. %d of %d here. A quantile over every frame would be a "
                            % [rebuilds, rows.size()]
                    + "quantile over a list that is zero by construction."),
            "instances": FlightTrace.quantiles(pop),
            "in_view_instances": FlightTrace.quantiles(in_view),
            "frame_ms_in_flight": FlightTrace.quantiles(frame_ms),
            "what": ("per frame, not per step. At 5 m/s the dolly's 20 m step is four seconds "
                    + "of travel, and everything between two samples is invisible to a "
                    + "sampled metric."),
            "frame_ms_note": ("the frame timer on this platform lands on a paced ladder: read "
                    + "differences to about half a millisecond and do not tune against "
                    + "smaller ones. A spread of zero is the absence of a measurement."),
        },
        "churn_is_zero_by_construction": float(trace.header.get("recentre_m", 0.0)) <= 0.0,
        "churn_note": ("with `recentre_m` at 0 the scatter is built once and flown through, so "
                + "the population cannot change and a churn of exactly 0 is the calibration "
                + "rather than a result -- the same role `static` plays in "
                + "scatter_motion.json. Above 0 the population follows the camera and the "
                + "churn is a measurement."),
        "by_heading": by_heading,
        "heading_spread": {
            "lowest_mean_in_view": lo if lo >= 0.0 else null,
            "highest_mean_in_view": hi,
            "ratio": (hi / lo) if lo > 0.0 else null,
            "frames_with_nothing_in_view": empty_frames,
            "pitch_degrees": FlightTrace.quantiles(pitch),
            "read_the_ratio_against_the_pitch": ("a heading is only comparable with another at "
                    + "a comparable attitude. A camera pitched at the sky has nothing in "
                    + "front of it whatever its heading, so a bucket full of those reads as "
                    + "an empty heading and drives the ratio to nothing. If "
                    + "`frames_with_nothing_in_view` is not small, or the pitch quantiles "
                    + "reach the clamp, the spread is about where the camera was pointing up "
                    + "and down and not about heading at all."),
            "what": ("what a HEADING has in front of it, which a translation-only dolly never "
                    + "sampled. A pan cannot churn -- the scatter is built around a centre and "
                    + "a rotation does not move it, so churn is exactly 0 for any pan, always, "
                    + "and is a metric that cannot fail on what it is pointed at. This is the "
                    + "statistic a pan is measured by instead."),
            "counted_per_sub_cell": ("a sub-cell is in view or out as a whole, and it is 31 m "
                    + "across against a seam of hundreds. This counts what a heading admits, "
                    + "not what a renderer would clip: no near or far plane is applied."),
        },
        "stalls": {
            "count": stalls.size(),
            "blocked_ms_total": blocked_total,
            "blocked_share_of_flight": (blocked_total / maxf(1.0, flight_ms)),
            "blocked_ms": FlightTrace.quantiles(blocked),
            "what": ("time the main loop spent inside a scatter REBUILD, during which the "
                    + "window is not redrawn while the flight goes on. This is the cost of "
                    + "re-centring, and it is a different quantity from the frame cost in "
                    + "scatter_cost.json: that one prices DRAWING the scatter, this one "
                    + "prices BUILDING it."),
        },
        "marks": at_marks,
        "marks_after_a_stall": marks_after_a_stall,
        "marks_note": ("a person pressing a key when something looked wrong. Every mark is "
                + "placed against the nearest preceding stall, because the first flown trace "
                + "came back with every one of its marks inside two seconds of a rebuild: the "
                + "flyer was marking a freeze, not the far field. `marks_after_a_stall` equal "
                + "to `marks` means this flight measured the harness and says nothing about "
                + "what is visible; well under it means the marks are about the view."),
        "not_covered": ("one path, one place, one day, one k. THE NEAR FIELD HAS NO GROUND "
                + "until the tile pyramid lands -- the terrain is triangulated every 4 km on "
                + "the overview, so at eye level the surface under the plants is an "
                + "interpolated plane and not a hillside. Eye-level judgement is limited by "
                + "that and this artefact does not generalise past it. Frame time is not "
                + "replayable and is carried from the flight. Nothing here says what a "
                + "different walking speed does."),
    }
    var doc := {
        "_what": "a recorded flight, replayed and scored",
        "vertical_exaggeration": view.terrain.exaggeration,
        "shading_exaggeration": view.terrain.shading_exaggeration,
        "runs": [run],
    }
    # ONE ARTEFACT, ONE RUN PER FLIGHT. Two flights of the same place at two
    # settings are one measurement in two parts -- the second only means
    # anything against the first -- so `--append` keeps them together rather
    # than making the newer one erase the older one's evidence.
    if append_to_existing and FileAccess.file_exists(out_path):
        var prior = JSON.parse_string(FileAccess.open(out_path, FileAccess.READ).get_as_text())
        if typeof(prior) == TYPE_DICTIONARY and (prior as Dictionary).has("runs"):
            var kept: Array = []
            for r4 in ((prior as Dictionary)["runs"] as Array):
                if str((r4 as Dictionary).get("trace", "")) != trace_path:
                    kept.append(r4)
            kept.append(run)
            doc["runs"] = kept
    var f := FileAccess.open(out_path, FileAccess.WRITE)
    if f == null:
        printerr("replay_flight: could not write %s" % out_path)
        quit(5)
        return
    f.store_string(JSON.stringify(doc, "  ", false) + "\n")
    f.close()
    var q: Dictionary = run["per_frame"]["gone_fraction_at_rebuilds"]
    var agree: Dictionary = run["replay_agreement"]
    print("")
    print("replay: %d frames, %d builds, agreement %s"
            % [rows.size(), _builds,
               ("exact over %d frames" % compared) if bool(agree["ok"])
                        else ("NOT RUN -- the trace records no populations to compare"
                                if compared == 0 else "BROKEN on %d frames" % disagreed)])
    if q.is_empty():
        print("        churn: no frame rebuilt, so the population never changed")
    else:
        print("        churn over %d rebuilds: p50 %s  max %s"
                % [rebuilds, String.num(float(q["p50"]), 4), String.num(float(q["max"]), 4)])
    if stalls.size() > 0:
        print("        %d stalls blocked %s s of %s s flown (%s%%), p50 %s ms each"
                % [stalls.size(), String.num(blocked_total / 1000.0, 1),
                   String.num(flight_ms / 1000.0, 1),
                   String.num(100.0 * blocked_total / maxf(1.0, flight_ms), 1),
                   String.num(float((run["stalls"]["blocked_ms"] as Dictionary)["p50"]), 0)])
    if not at_marks.is_empty():
        print("        %d of %d marks fell within %ss of a stall"
                % [marks_after_a_stall, at_marks.size(), String.num(STALL_REACTION_S, 0)])
    print("        in view by heading: %s to %s instances (%sx)"
            % [String.num(lo, 0), String.num(hi, 0),
               "--" if lo <= 0.0 else String.num(hi / lo, 2)])
    print("        -> %s" % out_path)
    stage = DONE
    quit(0)


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
