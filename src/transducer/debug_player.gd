class_name DebugPlayer
extends RefCounted

## A body in a dev context. The harness for the Godot leg of the four-leg test,
## runnable before B exists.
##
## WHAT MAKES IT A BODY RATHER THAN A CAMERA WITH LEGS. Everything it needs to
## move, it reads out of the bundle it was handed: where its eyes are, and how
## fast it can keep going. Neither is a constant in this file, and that is the
## cheap consonance test -- if the speed came from a constant here, this would
## be a camera with a walk animation and the seam would be decorative. It moves
## at the speed the producer says the body sustains, and when the producer says
## nothing it does not move and says why.
##
## THE CAMERA COINCIDES WITH THE OBSERVATION POINT AND NEVER DECIDES IT. This
## file does not know a stature from a posture; it passes both to the producer
## as part of what the body IS and places the camera at the answer.
##
## NO RENDERING, ON PURPOSE. `step` and `settle` are arithmetic over a bundle
## and a delta, so the gate walks a body headlessly and a recorded walk replays
## with no window. A player that could only be checked by looking at it is one
## nobody checks.
##
## TWO PHASES PER FRAME, and the shape is forced by the world rather than
## chosen: `step` proposes where the body goes, and only then can anything ask
## how high the ground is there, so `settle` puts it down afterwards. Fly mode
## skips the second half.

## Where a body's feet are and which way it faces. World metres -- easting,
## elevation, northing -- at float64, for the reason `PerceptBundle` gives.
var ground: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var heading_degrees: float = 0.0
var pitch_degrees: float = 0.0

## What the body IS. Configuration for a dev session; the producer turns it
## into an observation point, and nothing here interprets it.
var stature_m: float = BodyDerivation.DEFAULT_STATURE_M
var posture: String = "standing"
var session: String = "debug-player"

## Fly mode leaves the body unclamped; walk mode puts it on the ground. Walk is
## gated -- see `walk_available`.
var flying: bool = true

## The last thing `step` did, for a readout that does not have to guess.
var last: Dictionary = {}


## The observer half of a producer's question. Body, and nothing else: no
## radius, no filter, no detail level.
func observer() -> Dictionary:
    return {
        "session": session,
        "stature_m": stature_m,
        "posture": posture,
        "ground_point": ground,
    }


## Advance the body by one frame's worth of its OWN sustainable speed.
##
## `intent` is a direction in the body's frame -- x right, y forward -- and is
## normalised, so holding two keys is not a diagonal speed bonus. It carries no
## magnitude: a body has one sustainable speed and this is not the place that
## decides otherwise.
func step(bundle: PerceptBundle, delta: float, intent: Vector2) -> Dictionary:
    var speed := speed_from(bundle)
    if not bool(speed["ok"]):
        last = {"ok": false, "moved_m": 0.0, "why": str(speed["why"])}
        return last
    var v := float(speed["m_s"])
    var dir := intent
    if dir.length() > 1.0:
        dir = dir.normalized()
    var yaw := deg_to_rad(heading_degrees)
    # Heading zero looks along +north. Right is a quarter turn clockwise from it.
    var forward := Vector2(sin(yaw), cos(yaw))
    var right := Vector2(forward.y, -forward.x)
    var move := (forward * dir.y + right * dir.x) * v * maxf(0.0, delta)
    ground[0] += move.x
    ground[2] += move.y
    last = {"ok": true, "moved_m": move.length(), "speed_m_s": v,
            "posture": posture, "why": ""}
    return last


## Put the body on the ground. Called with the elevation at wherever `step`
## just left it; NAN means there is no ground there, and the body stays where
## it was vertically rather than falling through the world.
func settle(elevation_m: float) -> void:
    if flying or is_nan(elevation_m):
        return
    ground[1] = elevation_m


## The speed the BUNDLE says this body sustains.
##
## A missing locomotion field is a refusal and not a default. A default here
## would be a constant in this file wearing the producer's name, which is the
## exact thing the seam exists to prevent, and it would move at a plausible
## speed forever without anyone noticing the producer had stopped answering.
static func speed_from(bundle: PerceptBundle) -> Dictionary:
    if bundle == null:
        return {"ok": false, "m_s": 0.0, "why": "no bundle"}
    var loco: Dictionary = bundle.locomotion
    if not loco.has("sustainable_speed_m_s"):
        return {"ok": false, "m_s": 0.0, "why": ("the bundle carries no sustainable speed, so "
                + "this body does not move. A default here would be a constant of the "
                + "transducer's wearing the producer's name.")}
    var v := float(loco["sustainable_speed_m_s"])
    if v <= 0.0:
        return {"ok": false, "m_s": 0.0, "why": "the bundle reports a speed of %s m/s"
                % String.num(v, 3)}
    return {"ok": true, "m_s": v, "why": ""}


## Where the camera goes: exactly where the bundle says the eyes are.
static func camera_position(bundle: PerceptBundle) -> Vector3:
    return Vector3.ZERO if bundle == null else bundle.as_vector3()


## WHAT THE GROUND UNDER THIS BODY ACTUALLY IS -- two findings, not one.
##
## THIS WAS ONE CRITERION AND IT WAS ANSWERING TWO QUESTIONS. Written as "the
## ground must change at least once per second of walking", it refused at
## 4,000 m sampling and would have gone on refusing at 100 m, reporting the
## same word for two states that are nothing alike. The tile pyramid is what
## made that visible: it moves one of the two blockers by a factor of forty and
## does not touch the other, so a single verdict would have hidden the change
## entirely. Measured in `measurements/ground_relief.json`.
##
##   NEAR FIELD IS RELIEF -- is the ground a body sees around it more than one
##   flat triangle? Derived: the near field must hold more than one ground
##   sample, so the sample spacing must be no coarser than the radius the near
##   field is built to. This is the blocker `measurements/README.md` names, and
##   the measurement states it as a count: at 4,000 m sampling a 480 m disc
##   holds ZERO mesh vertices; at 100 m it holds sixty-nine.
##
##   CHANGES UNDERFOOT -- does the ground change as the body walks over it? The
##   criterion is unchanged: sample spacing no coarser than the distance this
##   body's own sustainable speed covers in a second. It is a proprioceptive
##   question and it implies metre-scale relief.
##
## WALK MODE GATES ON THE SECOND, and the number was not moved to make it open.
## At 100 m the ground changes every hundred metres of walking -- twenty
## seconds at the ruled 5 m/s, and a hundred and forty at the 0.7 m/s a real
## load-bearing envelope would report. The DEM under the pyramid is 92.6 m
## native, so no pyramid built from it can meet this; what walk mode wants is a
## SECOND PRODUCT -- synthesised micro-relief, or a detail mesh -- and inventing
## relief that is not in the data is adding rather than subtracting, which is a
## question for the corpus and not for this file.
##
## So the refusal stands, and it has changed character rather than degree: from
## "there is no ground here" to "there is ground, and it is smooth at the scale
## a body feels".
static func ground_findings(bundle: PerceptBundle, ground_sample_m: float,
                            near_field_radius_m: float) -> Dictionary:
    var speed := speed_from(bundle)
    var reach := float(speed["m_s"]) if bool(speed["ok"]) else NAN
    var relief_ok := ground_sample_m > 0.0 and ground_sample_m <= near_field_radius_m
    var samples := 0.0
    if ground_sample_m > 0.0:
        # The disc's area over one sample's, which is the count a measurement
        # of the same disc reports.
        samples = PI * near_field_radius_m * near_field_radius_m \
                / (ground_sample_m * ground_sample_m)
    var near_field := {
        "ok": relief_ok,
        "ground_sample_m": ground_sample_m,
        "near_field_radius_m": near_field_radius_m,
        "samples_in_near_field": samples,
        "why": ("" if relief_ok else
                ("the near field is %s m across and the ground is sampled every %s m, so a "
                        % [String.num(2.0 * near_field_radius_m, 0),
                                String.num(ground_sample_m, 0)]
                        + "body stands in the middle of one triangle and everything around it "
                        + "stands on a plane")),
    }
    if not bool(speed["ok"]):
        return {"near_field_is_relief": near_field,
                "changes_underfoot": {"ok": false, "why": str(speed["why"])}}
    var underfoot_ok := ground_sample_m > 0.0 and ground_sample_m <= reach
    var underfoot := {
        "ok": underfoot_ok,
        "ground_sample_m": ground_sample_m,
        "one_second_m": reach,
        "seconds_between_changes": ground_sample_m / reach if reach > 0.0 else INF,
        "why": ("" if underfoot_ok else
                ("the ground is sampled every %s m and this body covers %s m in a second, so "
                        % [String.num(ground_sample_m, 1), String.num(reach, 1)]
                        + "it walks for %s seconds between one ground sample and the next. "
                                % String.num(ground_sample_m / reach, 0)
                        + "Metre-scale relief is not a terrain product: the DEM under the "
                        + "pyramid is 92.6 m native, so this waits on a SECOND product and "
                        + "not on a finer pyramid.")),
    }
    return {"near_field_is_relief": near_field, "changes_underfoot": underfoot}


## Whether walk mode is honest yet. Gates on the underfoot finding; reports the
## other, because the two moved apart and a caller that saw one word would not
## know that the ground stopped being a plane.
static func walk_available(bundle: PerceptBundle, ground_sample_m: float,
                           near_field_radius_m: float) -> Dictionary:
    var f := ground_findings(bundle, ground_sample_m, near_field_radius_m)
    var under: Dictionary = f["changes_underfoot"]
    var out := f.duplicate()
    out["ok"] = bool(under["ok"])
    out["ground_sample_m"] = ground_sample_m
    out["one_second_m"] = under.get("one_second_m", NAN)
    out["why"] = str(under.get("why", ""))
    return out
