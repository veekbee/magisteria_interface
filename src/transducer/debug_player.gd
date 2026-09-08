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


## WHETHER WALK MODE IS HONEST YET, given the ground that actually exists.
##
## The blocker is A1 and it is not this repo's to lift: the terrain export
## triangulates the heightfield every 4 km, so a body standing in the scatter
## stands in the middle of one flat triangle and near-field vegetation stands
## on a plane. Walking on that is not walking on ground, and anything tuned
## against it is tuned against a plane.
##
## THE CRITERION IS DERIVED, NOT AUTHORED: the ground must change at least once
## per second of walking, so the sample spacing has to be no coarser than the
## distance the body's own sustainable speed covers in a second. Both numbers
## come from outside this file -- one from the terrain, one from the bundle --
## which is what stops this being a threshold somebody picked. It is the
## client's own criterion and not a ruling; what resolution the tile pyramid
## lands at is what decides whether it opens.
static func walk_available(bundle: PerceptBundle, ground_sample_m: float) -> Dictionary:
    var speed := speed_from(bundle)
    if not bool(speed["ok"]):
        return {"ok": false, "why": str(speed["why"])}
    var reach := float(speed["m_s"])
    if ground_sample_m <= reach:
        return {"ok": true, "why": "", "ground_sample_m": ground_sample_m,
                "one_second_m": reach}
    return {"ok": false, "ground_sample_m": ground_sample_m, "one_second_m": reach,
            "why": ("the ground is sampled every %s m and this body covers %s m in a second, "
                    % [String.num(ground_sample_m, 1), String.num(reach, 1)]
                    + "so it would walk for %s seconds between one ground sample and the next. "
                            % String.num(ground_sample_m / reach, 0)
                    + "That is a plane, not terrain, and nothing measured on it is a "
                    + "measurement of walking. Waits on the tile pyramid.")}
