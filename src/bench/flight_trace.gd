class_name FlightTrace
extends RefCounted

## A recorded camera path, and everything needed to score it again without the
## person who flew it.
##
## THE PROBLEM THIS SOLVES. An interactive harness produces a judgement nobody
## can reproduce, which is the opposite of every other measurement in this repo.
## The fix is the one the project already makes: record the trace, pin it, and
## replay it headlessly forever after. A trace that cannot be replayed is a
## demo; a trace that can is an instrument.
##
## WHAT IS RECORDED IS THE PATH, NOT THE RESULT. A frame's pose is the input; a
## frame's population, churn and cost are outputs, and replay recomputes them.
## Both are stored, so a replay that disagrees with the flight is visible rather
## than silent -- and one of them is EXPECTED to disagree, which is the next
## paragraph.
##
## FRAME TIME DOES NOT REPLAY AND MUST NOT BE PRETENDED TO. A headless replay
## draws nothing, so a frame it "takes" costs nothing; the frame times in a
## trace are measurements from the flight and stay that way. What replays
## exactly is the population -- which instances existed, where, and how the set
## changed between frames -- because placement is a function of the ground. The
## artefact says which of its columns is which.
##
## ORIENTATION IS A QUATERNION. Euler angles would need a convention recorded
## beside them and would be one more thing to get wrong on the way back in.

## Pose components, so a reader of the JSON knows what the four numbers are.
const POSE_FIELDS := "position is the camera in MESH space; orientation is a quaternion (x, y, z, w)"

## The mark a person presses when something looked wrong. Zero is no mark.
const MARK_NONE := 0
const MARK_LOOKED_WRONG := 1

## The size over which this repo does not commit a file (decision 948). A trace
## is not exempt: it is a measurement input like any other, and one long enough
## to cross this has to arrive through `tools/fetch_artefacts.py` instead. The
## gate checks the directory rather than trusting the format to stay small.
const COMMITTABLE_BYTES := 10485760

var header: Dictionary = {}
var frames: Array = []


## Start a trace. `about` carries the scene the flight is over -- everything a
## replay needs to rebuild the same world.
func begin(about: Dictionary) -> void:
    header = about.duplicate(true)
    header["pose_fields"] = POSE_FIELDS
    frames = []


## Values a frame is assumed to hold when it does not say otherwise. A flight is
## sixteen thousand rows and most of them are ordinary: nothing rebuilt, nothing
## was marked, the window was drawn. Writing that out per frame is most of a
## trace by weight and none of it by meaning.
const FRAME_DEFAULTS := {
    "gone_fraction": 0.0,
    "build_ms": 0.0,
    "mark": MARK_NONE,
    "rebuilt": false,
    "drawn": true,
}

## Metres the position is written to. A millimetre is three orders below the
## centimetre placement quantises world coordinates to, so this is exact for
## every purpose in this repo and about half the length of the float that
## produced it.
const POSITION_QUANTUM := 0.001

## The quaternion's. A millionth is about a ten-thousandth of a degree.
const ORIENTATION_QUANTUM := 0.000001

## THESE ARE A GUARANTEE OF THE WRITER AND NOT OF EVERY COMMITTED TRACE, and
## the difference is not academic: the one trace the gate actually replays does
## not satisfy them. Measured over the four traces in `measurements/flights/`,
## against the nearest representable multiple rather than against decimal
## divisibility -- `0.001` is not a binary fraction, so an exact-multiple test
## on a 240 km easting measures its own tolerance and not the artefact:
##
##   flight-01/02/03   0 of 48,552 / 68,118 / 74,112 positions off-quantum,
##                     0 of 64,736 / 90,824 / 98,816 orientations
##   scripted          2,998 of 5,400 positions, 7,192 of 7,200 orientations,
##                     worst orientation residue 5e-07 -- half a quantum, which
##                     is what unsnapped values look like
##
## `scripted.trace.json` was recorded at af3d023, before `add` snapped anything.
## So the paragraph below -- "rounding to a millimetre ... loses nothing" --
## describes what this writer does today and NOT what the pinned artefact
## contains, and a reader who took it as a property of the traces would be
## reading a guarantee off the wrong side of a rule that changed.
##
## `quantum_violations_in` is how that is checked rather than remembered.


## One frame. `pose` is the camera's transform; the rest is what was measured.
##
## ROUNDED AND SPARSE, AND BOTH ARE ABOUT SIZE RATHER THAN TASTE. A four-minute
## flight is 24,000 rows, and written at full float precision with every field
## on every row it came to 15 MB -- over the threshold above which this repo
## does not commit a file at all (decision 948). Rounding to a millimetre and
## omitting the fields that hold their default takes the same flight to under
## 8 MB and loses nothing: the quanta are far below anything that changes a
## build, and a reader that wants `rebuilt` on a frame that did not rebuild is
## asking for `false`.
func add(t_ms: float, pose: Transform3D, measured: Dictionary) -> void:
    var q := pose.basis.get_rotation_quaternion()
    var row := {
        "t_ms": snappedf(t_ms, POSITION_QUANTUM),
        "position": [snappedf(pose.origin.x, POSITION_QUANTUM),
                     snappedf(pose.origin.y, POSITION_QUANTUM),
                     snappedf(pose.origin.z, POSITION_QUANTUM)],
        "orientation": [snappedf(q.x, ORIENTATION_QUANTUM),
                        snappedf(q.y, ORIENTATION_QUANTUM),
                        snappedf(q.z, ORIENTATION_QUANTUM),
                        snappedf(q.w, ORIENTATION_QUANTUM)],
    }
    for k in measured:
        var v = measured[k]
        if FRAME_DEFAULTS.has(k) and typeof(v) == typeof(FRAME_DEFAULTS[k]) \
                and v == FRAME_DEFAULTS[k]:
            continue
        row[k] = snappedf(float(v), 0.0001) if typeof(v) == TYPE_FLOAT else v
    frames.append(row)


## The pose of frame `i`, back out of the trace.
static func pose_of(row: Dictionary) -> Transform3D:
    var p: Array = row["position"]
    var o: Array = row["orientation"]
    var q := Quaternion(float(o[0]), float(o[1]), float(o[2]), float(o[3])).normalized()
    return Transform3D(Basis(q), Vector3(float(p[0]), float(p[1]), float(p[2])))


func to_dict() -> Dictionary:
    return {
        "_what": ("a recorded camera path over the basin, and the statistics measured along "
                + "it. Replayable: tools/replay_flight.sh scores it again headlessly."),
        "header": header,
        "frames": frames,
    }


func save(path: String) -> Dictionary:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return {"ok": false, "why": "could not write %s" % path}
    f.store_string(JSON.stringify(to_dict(), "  ", false) + "\n")
    f.close()
    return {"ok": true, "frames": frames.size(), "path": path}


## How far each of a trace's frames sits from the quanta this writer declares.
##
## AGAINST THE NEAREST REPRESENTABLE MULTIPLE, not against decimal divisibility.
## `snappedf(x, 0.001)` returns `round(x / 0.001) * 0.001`, and neither `0.001`
## nor that product is a binary fraction -- so `x / 0.001` for an easting in the
## hundreds of thousands carries about 2e-8 of its own rounding, and a test
## asking whether the quotient is an integer to 1e-9 reports every trace as
## violating, including the three that do not. That was the first cut of this,
## and it would have had me telling the other side that their writer was broken.
##
## Returns `{"positions": n, "orientations": n, "worst_orientation_m": f, ...}`.
static func quantum_violations_in(frames: Array) -> Dictionary:
    var off_p := 0
    var off_o := 0
    var n_p := 0
    var n_o := 0
    var worst := 0.0
    for row in frames:
        var f: Dictionary = row
        for v in (f.get("position", []) as Array):
            n_p += 1
            if _off_quantum(float(v), POSITION_QUANTUM):
                off_p += 1
        for v2 in (f.get("orientation", []) as Array):
            n_o += 1
            var d := absf(float(v2) - roundf(float(v2) / ORIENTATION_QUANTUM)
                    * ORIENTATION_QUANTUM)
            if _off_quantum(float(v2), ORIENTATION_QUANTUM):
                off_o += 1
                worst = maxf(worst, d)
    return {"positions": off_p, "positions_checked": n_p,
            "orientations": off_o, "orientations_checked": n_o,
            "worst_orientation_residue": worst}


## The tolerance is the value's OWN representation error plus a sliver of the
## quantum, because both are real and neither is the thing being measured.
static func _off_quantum(v: float, q: float) -> bool:
    var nearest := roundf(v / q) * q
    return absf(v - nearest) > maxf(absf(v), 1.0) * 4e-16 + q * 1e-9


static func load_from(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "why": "no trace at %s" % path}
    var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {"ok": false, "why": "%s is not a trace document" % path}
    var doc: Dictionary = parsed
    if not doc.has("header") or not doc.has("frames"):
        return {"ok": false, "why": "%s has no header or no frames" % path}
    var t := FlightTrace.new()
    t.header = doc["header"]
    t.frames = doc["frames"]
    if t.frames.is_empty():
        return {"ok": false, "why": "%s records no frames" % path}
    return {"ok": true, "trace": t}


# --------------------------------------------------------------------------
# what changed between two builds, without either of them being drawn
# --------------------------------------------------------------------------

## Churn between two population censuses.
##
## THIS IS EXACT, NOT SAMPLED, AND IT IS EXACT BECAUSE OF THE PLACEMENT RULE.
## A census is sub-cell -> [count, x, y, z]. Two builds that admit the same
## sub-cell hold the first `n_a` and the first `n_b` plants of ONE fixed order,
## so the plants they share are the first `min(n_a, n_b)` -- set intersection
## collapses to a minimum and the whole comparison is three sums. Against a
## per-build random sequence, two builds shared nothing whatever the counts
## said, and no census could have told the difference.
##
## TWO FRACTIONS, NAMED APART, because reading one as the other has already
## cost a prediction. `gone_fraction` is what left, over what was there --
## `1 - survival`, and the quantity a disc-overlap argument predicts.
## `churn_fraction` is the symmetric difference over the two populations
## summed, which is what `scatter_motion.json` reports and roughly twice the
## first when the populations are similar.
static func churn_between(before: Dictionary, after: Dictionary) -> Dictionary:
    var survived := 0
    var before_total := 0
    var after_total := 0
    for k in before:
        var n: int = int((before[k] as Array)[0])
        before_total += n
        if after.has(k):
            survived += mini(n, int((after[k] as Array)[0]))
    for k in after:
        after_total += int((after[k] as Array)[0])
    var gone := before_total - survived
    var appeared := after_total - survived
    var both := before_total + after_total
    return {
        "before": before_total,
        "after": after_total,
        "survived": survived,
        "gone": gone,
        "appeared": appeared,
        "gone_fraction": (float(gone) / float(before_total)) if before_total > 0 else 0.0,
        "churn_fraction": (float(appeared + gone) / float(both)) if both > 0 else 0.0,
        "sub_cells": before.size(),
    }


## How many of a census's instances lie in front of the camera, and how many
## sub-cells they sit in.
##
## A COUNT PER SUB-CELL, NOT PER PLANT, and the difference is stated rather
## than hidden: the census carries one position per sub-cell, so a sub-cell is
## in or out as a whole. A sub-cell is 31 m across and the seam is hundreds, so
## this is a count of what a heading has in front of it and not a claim about
## any individual plant.
##
## NO NEAR OR FAR PLANE. The pyramid is the fov and the aspect and nothing
## else, so this counts what a heading admits rather than what a renderer would
## clip. Distance culling belongs to the horizon rule, which has already run.
static func in_view(cen: Dictionary, pose: Transform3D, fov_degrees: float,
                    aspect: float) -> Dictionary:
    var inv := pose.affine_inverse()
    var half_v := tan(deg_to_rad(0.5 * maxf(1.0, fov_degrees)))
    var half_h := half_v * maxf(0.01, aspect)
    var instances := 0
    var cells := 0
    for k in cen:
        var e: Array = cen[k]
        var local := inv * Vector3(float(e[1]), float(e[2]), float(e[3]))
        # The camera looks down its own -Z.
        var d := -local.z
        if d <= 0.0:
            continue
        if absf(local.y) > half_v * d or absf(local.x) > half_h * d:
            continue
        cells += 1
        instances += int(e[0])
    return {"instances": instances, "sub_cells": cells}


## Total instances in a census.
static func population(cen: Dictionary) -> int:
    var n := 0
    for k in cen:
        n += int((cen[k] as Array)[0])
    return n


# --------------------------------------------------------------------------
# what the flight itself was, read back off the poses
# --------------------------------------------------------------------------

## Speed and turn rate per frame, derived from the poses rather than trusted
## from whatever the harness thought it was doing.
##
## A HARNESS THAT REPORTS ITS OWN SETTING IS NOT MEASURING. The move speed is a
## constant in the flight tool; what a person actually travelled is the
## distance between consecutive recorded poses over the time between them, and
## the two differ whenever a frame was long, a key was tapped, or two axes were
## held at once.
static func motion_of(frames: Array) -> Array:
    var out: Array = []
    for i in range(1, frames.size()):
        var a: Dictionary = frames[i - 1]
        var b: Dictionary = frames[i]
        var dt := (float(b["t_ms"]) - float(a["t_ms"])) / 1000.0
        var pa := pose_of(a)
        var pb := pose_of(b)
        var d := (pb.origin - pa.origin).length()
        var turn := rad_to_deg(pa.basis.get_rotation_quaternion().angle_to(
                pb.basis.get_rotation_quaternion()))
        out.append({
            "frame": i,
            "dt_s": dt,
            "step_m": d,
            "speed_m_s": (d / dt) if dt > 0.0 else 0.0,
            "turn_degrees": turn,
            "turn_degrees_s": (turn / dt) if dt > 0.0 else 0.0,
        })
    return out


## Nearest-rank quantiles over a list of floats, the form every artefact here
## quotes. Returns {} for an empty list rather than a zero that reads as one.
static func quantiles(values: Array) -> Dictionary:
    if values.is_empty():
        return {}
    var v := values.duplicate()
    v.sort()
    return {
        "n": v.size(),
        "min": float(v[0]),
        "p50": float(v[int(ceil(0.50 * v.size())) - 1]),
        "p95": float(v[int(ceil(0.95 * v.size())) - 1]),
        "max": float(v[v.size() - 1]),
        "mean": _mean(v),
    }


static func _mean(v: Array) -> float:
    if v.is_empty():
        return 0.0
    var t := 0.0
    for x in v:
        t += float(x)
    return t / float(v.size())


## The frames a person marked, with a window of context around each.
##
## THE MARK IS THE MEASUREMENT. Where between 0 and 1 a churn becomes visible
## is a design judgement, and the alternative to ruling it in the abstract is
## to bind a key to "that looked wrong" and read the statistics off the trace
## at that timestamp. Several presses give a distribution rather than a number,
## and the disagreement between presses is itself information.
##
## `window` frames either side, because a person presses a key AFTER seeing
## something and reaction time is not zero.
static func marks_in(frames: Array, window: int = 12) -> Array:
    var out: Array = []
    for i in frames.size():
        var row: Dictionary = frames[i]
        if int(row.get("mark", MARK_NONE)) == MARK_NONE:
            continue
        out.append({
            "frame": i,
            "t_ms": float(row["t_ms"]),
            "window_frames": [maxi(0, i - window), mini(frames.size() - 1, i + window)],
            "reaction_note": ("a key is pressed AFTER the thing it is about, so the window "
                    + "before the mark is where the event is and the mark itself is a "
                    + "lower bound on when it was seen"),
        })
    return out
