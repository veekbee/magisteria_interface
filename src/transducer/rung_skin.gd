class_name RungSkin
extends RefCounted

## The debug rung-skin: make how coarsely a thing is known VISIBLE, by keying
## its appearance on the precision the bundle carries.
##
## WHY IT EXISTS. A transducer that draws a coarse percept and a fine one the
## same way is indistinguishable from one that never received a coarse percept
## at all. Every rung defect -- a boundary in the wrong place, a subject drawn
## at two rungs, a producer that quietly stopped refining -- looks like correct
## output. The skin turns the rung into something a person walking the basin
## can see, and it is the instrument, not the picture.
##
## DEV BUILDS ONLY, AND THE REASON IS NOT TASTE. Two halves of this idea have
## different standings. Drawing an attribute AT the precision it was given --
## a coarser form for a coarser percept -- is not a skin at all; it is
## rendering the percept, and it is production-legitimate. Adding arbitrary
## perturbation on top is the transducer ADDING something the producer did not
## send, and whether that may ever ship is a corpus question this repo does not
## get to answer. So `DEV_ONLY` is true, the flag is read from the build, and
## the question is named rather than settled.
##
## TWO RULES THE SKIN HAS TO OBEY, AND BOTH ARE LEAK RULES.
##
##   AMPLITUDE KEYS ON CARRIED PRECISION, NEVER ON DISTANCE-TO-TRUTH. Scaling
##   the wobble by how wrong the drawn value is would require the true value,
##   and a skin that needed it would be a consumer reaching past the bundle for
##   the artefact underneath. This file lives in the transducer subtree for
##   exactly that reason: the gate's dependency scan is what enforces the rule,
##   and a bespoke assertion here would be a guard that cannot fail, since
##   nothing in reach IS the truth. Structure, not a test.
##
##   THE SEED KEYS ON THE TOKEN, AND THAT IS MANDATORY. A perturbation seeded
##   on anything that outlives a token -- a subject id, a position, a slot --
##   is a visual fingerprint: the wobble is the same wobble after the token
##   rotates, and a consumer that cannot read the name can still recognise the
##   look. That rebuilds §20.4.3's linkage in the appearance channel, one layer
##   below the thing the rotation was for. Seeding on the token makes the look
##   jump when the name does, which is also the visibility the skin wants.
##
##   CHANNEL-1 FLORA IS THE EXCEPTION AND IT IS NOT A LOOSENING. Background
##   plants carry no token because they are not individuated on the wire at
##   all: existence is keyed on ground, per §16.6's stratified placement, and
##   there is no identity to link. So they seed on the placement key -- which
##   is the same stability, over a thing with nothing to leak.
##
## WHAT IT CONSUMES. Bundle contents and nothing else: the refinement overlay
## for a rung, a token for a seed, a rung name for an amplitude. That was one
## of the tests the bundle's fields were chosen against, and building the skin
## is how the test gets run rather than argued.

## True, and here so that a reader meets the question before the knob. See the
## header: the perturbing half is dev-only pending a corpus question about a
## transducer adding what the producer did not send.
const DEV_ONLY := true

## The ladder, from `PerceptProbe`, which is where this client names it. One
## home per quantity: a second copy here would be free to gain a rung the probe
## does not print.
const RUNGS := PerceptProbe.RUNGS

## The largest per-channel shift the skin applies, at full amplitude. Kept
## small: the skin has to be legible against the palette, not replace it.
const PERTURB_MAX := 0.12

## The per-rung colour step, as a DELTA and not a colour. Large on purpose --
## §17.8.6 rules blend within a rung and switch between rungs, so a rung change
## is already a discontinuity in the drawn form, and the skin amplifies a seam
## that is really there rather than inventing one.
##
## The finest rung's delta is exactly zero, which is the same statement as its
## amplitude being zero: at the finest rung the client draws what it was given,
## unskinned. That is what makes the skin safe to leave on while looking at
## something else.
const RUNG_DELTA := {
    "life_form": Color(0.55, -0.30, 0.45, 0.0),
    "functional": Color(-0.35, 0.40, 0.50, 0.0),
    "specific": Color(0.0, 0.0, 0.0, 0.0),
}


## Whether the skin draws. `dev_build` comes from the build, so a release
## cannot turn it on by forgetting to turn it off.
static func enabled(dev_build: bool) -> bool:
    return DEV_ONLY and dev_build


## Carried precision for a rung, as a fraction of the ladder: 0 at the coarsest
## name the ladder has, 1 at the finest. An unknown name is 1.0 -- NOT 0.0 --
## because an unrecognised rung means the skin does not know how coarse this is
## and the honest response is to add nothing. Defaulting the other way would
## paint the whole basin at full wobble the first time a producer named a rung
## this client had not heard of.
static func precision_of_rung(rung: String) -> float:
    var i := RUNGS.find(rung)
    if i < 0 or RUNGS.size() < 2:
        return 1.0
    return float(i) / float(RUNGS.size() - 1)


## g(precision): the amplitude, converging to zero as the carried precision
## reaches exact. Smoothstep rather than a line, for the reason convention 1
## gives about thresholds generally -- the amplitude's own derivative is zero
## at both ends, so a subject drifting toward a rung boundary does not have the
## wobble stop dead the instant it arrives.
##
## EXACTLY ZERO AT EXACT, not nearly. A skin that left a residue at the finest
## rung would be a permanent lie about the finest thing the client knows.
static func amplitude_for(precision: float) -> float:
    var f := clampf(1.0 - precision, 0.0, 1.0)
    return f * f * (3.0 - 2.0 * f)


## The seed for one attribute of one identified subject. The token, and never
## anything the token replaces.
static func seed_for_subject(token: String, attribute_id: String) -> int:
    return StableHash.of_name("%s/%s" % [token, attribute_id])


## The seed for one attribute of one background plant. The placement key, which
## is the same key §16.6's placement already stands on -- so the skin moves
## with the stand and never moves it.
static func seed_for_placement(placement_key: int, attribute_id: String) -> int:
    return StableHash.of3(placement_key, StableHash.of_name(attribute_id), 0)


## The signed per-channel shift for one seed at one amplitude. Alpha is never
## touched: a skin that could make a thing transparent could make it absent.
static func tint_delta(seed: int, amplitude: float) -> Color:
    var a := clampf(amplitude, 0.0, 1.0) * PERTURB_MAX
    return Color(
            (2.0 * StableHash.unit(StableHash.of3(seed, 1, 0)) - 1.0) * a,
            (2.0 * StableHash.unit(StableHash.of3(seed, 2, 0)) - 1.0) * a,
            (2.0 * StableHash.unit(StableHash.of3(seed, 3, 0)) - 1.0) * a,
            0.0)


## The rung's own step. An unknown rung gets no step, for the same reason an
## unknown rung gets no amplitude.
static func rung_delta(rung: String) -> Color:
    if not RUNG_DELTA.has(rung):
        return Color(0.0, 0.0, 0.0, 0.0)
    return RUNG_DELTA[rung]


## The whole skin for one thing: the rung's step plus its own wobble.
static func shift(rung: String, seed: int) -> Color:
    return rung_delta(rung) + tint_delta(seed, amplitude_for(precision_of_rung(rung)))


## The furthest any one thing at this rung can be moved from its rung's step.
## The bound that decides whether the seam survives the wobble.
static func max_wobble(rung: String) -> float:
    var a := amplitude_for(precision_of_rung(rung)) * PERTURB_MAX
    return a * sqrt(3.0)


## Can two adjacent rungs be told apart after both have been wobbled as far as
## they can go? Returns the margin in colour distance -- positive means yes,
## and by how much.
##
## THIS IS THE SKIN'S OWN ACCEPTANCE TEST, and it is a measurement rather than
## a claim. A skin whose noise straddles its own rung step is worse than no
## skin: it looks like it is reporting something and it is reporting the hash.
static func separation_margin() -> float:
    var worst := INF
    for i in RUNGS.size() - 1:
        var a := str(RUNGS[i])
        var b := str(RUNGS[i + 1])
        var d: Color = rung_delta(b) - rung_delta(a)
        var gap := Vector3(d.r, d.g, d.b).length() - max_wobble(a) - max_wobble(b)
        worst = minf(worst, gap)
    return worst


## The overlay's answer for one cell's life form: the node it is refined to, or
## "" where no overlay is present.
##
## ABSENT IS THE COMMON CASE AND IT IS NOT AN ERROR. An overlay is sent only
## where it is earned, so most cells have none, and "no overlay" means the
## coarse rung rather than a missing read.
static func refined_node(b: PerceptBundle, residence_key: String, life_form: String) -> String:
    if b == null or b.refused:
        return ""
    return b.refined_to(residence_key, life_form)


## Which rung the bundle earns for one cell's flora.
##
## TWO ANSWERS OUT OF A THREE-NAME LADDER, and the gap is honest rather than
## unfinished: this client's flora taxonomy is two deep -- the life forms the
## wire names, and the specific nodes it has assets for -- so `functional` is
## on the ladder, is a rung something else may one day earn, and is returned by
## nothing here. Collapsing the ladder to two names to match would make the
## day a middle rung arrives a schema change instead of a data change.
static func earned_rung(b: PerceptBundle, residence_key: String, life_form: String) -> String:
    return "specific" if refined_node(b, residence_key, life_form) != "" else "life_form"
