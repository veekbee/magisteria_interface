class_name BodyDerivation
extends RefCounted

## Where a body's eyes are, and how fast it can keep moving. Producer-side.
##
## THIS IS THE ONE PIECE OF LANE B WHOSE RESIDENCY IS ALREADY RULED, so it is
## worth stating plainly: EYE HEIGHT IS THE BODY'S, NOT THE CAMERA'S. The
## camera coincides with the observation point and never owns it. Put the
## derivation in the camera rig and it is correct exactly until a second
## consumer exists -- a headless scorer, a second observer, a driver with no
## camera at all -- at which point either it is duplicated or the second
## consumer asks a renderer where a body's eyes are. Both are the failure the
## four-leg test names, and the rig is where it would start.
##
## So this file lives beside the producer, the producer puts its answer in the
## bundle, and everything downstream READS it. `free_flight.gd` and the debug
## player both take their camera height from here rather than from a constant
## of their own.
##
## THE CONSTANTS ARE A STUB'S AND SAY SO. A real envelope -- what a body of
## this stature, in this condition, on this ground, can sustain -- is B's, and
## B does not exist yet. What is written below is ordinary anthropometry and
## one figure the corpus already rules; every one of them is replaced, not
## adjusted, when the derivation crosses the interface for real. Nothing else
## in this repo may hold a second copy of any of them.

## Default adult stature for a dev body, metres. Configuration, not a claim.
const DEFAULT_STATURE_M := 1.80

## Vertex to eye. About the width of a hand, and standing eye height is stature
## less this rather than a fraction of it -- the offset is nearly constant
## across statures where a ratio is not.
const VERTEX_TO_EYE_M := 0.10

## Crouched and prone are fractions of stature, because neither has a vertex
## to measure down from.
const CROUCHED_EYE_FRACTION := 0.62
const PRONE_EYE_FRACTION := 0.15

## Metres per second a body sustains. §3.1c's figure, which is the speed the
## world is ruled to be traversed at under its own kinematic compression -- so
## a dev body walks at the speed the world was designed to be seen at, and the
## tuning done at that speed transfers.
const SUSTAINABLE_SPEED_M_S := 5.0

## Postures scale that speed. Stub values, and the ORDER is the part that
## matters: a body that crouches and gets faster is a defect a test can catch
## without knowing the numbers.
const POSTURE_SPEED_FACTOR := {"standing": 1.0, "crouched": 0.35, "prone": 0.08}


## Height of the eyes above the ground the body stands on, in metres.
static func eye_height_m(stature_m: float, posture: String) -> float:
    if stature_m <= 0.0:
        return 0.0
    match posture:
        "crouched":
            return stature_m * CROUCHED_EYE_FRACTION
        "prone":
            return stature_m * PRONE_EYE_FRACTION
        _:
            return maxf(0.0, stature_m - VERTEX_TO_EYE_M)


## The observation point: the body's own position, raised to the eyes.
##
## `ground_point` is where the body stands, in world metres, as three float64s
## -- easting, elevation, northing. A `Vector3` would round it: this basin's
## eastings pass a million metres, where single precision steps in units of
## about 6 cm, and proprioception is the one thing exact for free. Use
## `ground_from` to lift a scene-side position into this form at the point
## where the precision is already gone.
static func observation_point(ground_point: PackedFloat64Array, stature_m: float,
                              posture: String) -> PackedFloat64Array:
    if ground_point.size() != 3:
        return PackedFloat64Array([0.0, eye_height_m(stature_m, posture), 0.0])
    return PackedFloat64Array([ground_point[0],
            ground_point[1] + eye_height_m(stature_m, posture), ground_point[2]])


## A ground point from a scene-side vector, for callers that only have one.
static func ground_from(v: Vector3) -> PackedFloat64Array:
    return PackedFloat64Array([v.x, v.y, v.z])


## What movement needs, in the form the bundle carries it.
##
## Stature is taken and not used, and that is deliberate rather than left over:
## a real envelope is a function of the body, and a signature that does not ask
## for the body is one every caller has to change on the day it does.
static func locomotion(_stature_m: float, posture: String) -> Dictionary:
    var factor := float(POSTURE_SPEED_FACTOR.get(posture, 1.0))
    return {
        "sustainable_speed_m_s": SUSTAINABLE_SPEED_M_S * factor,
        "stub": ("speeds are a stub's: one ruled traversal figure and a posture factor, "
                + "not an envelope. A body's real sustainable speed is the producer's to "
                + "compute and is replaced here rather than tuned."),
    }
