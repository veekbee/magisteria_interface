class_name FrameProbe
extends RefCounted

## What a captured frame contains, as numbers rather than as a picture.
##
## THE POINT IS TO MAKE A LOOK REPORTABLE. Three defects this project shipped
## were invisible to a suite of 1,800 passing checks and obvious in a frame:
## the terrain wound inside-out and never drawn, a phenology mask that never
## reached its shader, and nodata rendering as black. Every one of them was
## found by rendering something and measuring it, and every one of them was
## first described as "that looks wrong". This turns that sentence into a
## number a commit message can carry.
##
## IT DOES NOT KNOW WHAT ANYTHING IS. There is no "terrain" here and no
## "vegetation": a frame is pixels, and the classes below are about colour, not
## about meaning. What isolates a subject is the capture -- hiding every layer
## but one -- and not a guess made afterwards about which pixels were which.
##
## The thresholds are stated because they are arbitrary. A pixel is NEUTRAL
## when its channels agree within `NEUTRAL_TOLERANCE`, which catches this
## project's grey background and its grey UI; it is NEAR_BLACK below
## `BLACK_CEILING`, which is where nodata lands when an alpha is ignored. Both
## are display conventions, not measurements, and a caller comparing two frames
## should compare, not threshold.

const NEUTRAL_TOLERANCE := 0.03
const BLACK_CEILING := 0.06


## Colour census of one frame.
##
## `green_minus_red` over the non-neutral pixels is the workhorse: it is the
## axis a seasonal tint moves along, and it changes sign between a senescent
## and a growing canopy while nothing else in this project's palette does.
static func summarise(img: Image) -> Dictionary:
    var total := 0
    var neutral := 0
    var near_black := 0
    var r := 0.0
    var g := 0.0
    var b := 0.0
    var coloured := 0
    for y in img.get_height():
        for x in img.get_width():
            var c := img.get_pixel(x, y)
            total += 1
            if c.r < BLACK_CEILING and c.g < BLACK_CEILING and c.b < BLACK_CEILING:
                near_black += 1
                continue
            if absf(c.r - c.g) < NEUTRAL_TOLERANCE and absf(c.g - c.b) < NEUTRAL_TOLERANCE:
                neutral += 1
                continue
            coloured += 1
            r += c.r
            g += c.g
            b += c.b
    var n := maxf(float(coloured), 1.0)
    return {
        "pixels": total,
        "neutral": neutral,
        "near_black": near_black,
        "coloured": coloured,
        "coloured_fraction": float(coloured) / float(maxi(total, 1)),
        "mean_coloured": [r / n, g / n, b / n],
        "green_minus_red": (g - r) / n,
    }


## What changed between two frames of the same subject.
##
## Reported as a count and as the mean colour of the changed pixels on each
## side, because "these differ" is not a finding: two frames of a scatter
## differ wherever geometry moved, and the question is always whether they
## differ in the way the change was supposed to make them differ.
static func compare(a: Image, b: Image) -> Dictionary:
    if a.get_width() != b.get_width() or a.get_height() != b.get_height():
        return {"ok": false, "why": "the two frames are different sizes"}
    var differing := 0
    var total := 0
    var sa := [0.0, 0.0, 0.0]
    var sb := [0.0, 0.0, 0.0]
    for y in a.get_height():
        for x in a.get_width():
            var ca := a.get_pixel(x, y)
            var cb := b.get_pixel(x, y)
            total += 1
            if ca.is_equal_approx(cb):
                continue
            differing += 1
            sa[0] += ca.r; sa[1] += ca.g; sa[2] += ca.b
            sb[0] += cb.r; sb[1] += cb.g; sb[2] += cb.b
    var n := maxf(float(differing), 1.0)
    return {
        "ok": true,
        "pixels": total,
        "differing": differing,
        "differing_fraction": float(differing) / float(maxi(total, 1)),
        "mean_a": [sa[0] / n, sa[1] / n, sa[2] / n],
        "mean_b": [sb[0] / n, sb[1] / n, sb[2] / n],
        "green_minus_red_a": (sa[1] - sa[0]) / n,
        "green_minus_red_b": (sb[1] - sb[0]) / n,
    }


static func one_line(tag: String, s: Dictionary) -> String:
    var mean: Array = s["mean_coloured"]
    return ("%-18s %5.1f%% coloured  %5.1f%% neutral  %4.1f%% near-black  "
            + "mean (%.2f, %.2f, %.2f)  g-r %+.3f") % [
            tag, 100.0 * float(s["coloured_fraction"]),
            100.0 * float(s["neutral"]) / float(maxi(int(s["pixels"]), 1)),
            100.0 * float(s["near_black"]) / float(maxi(int(s["pixels"]), 1)),
            float(mean[0]), float(mean[1]), float(mean[2]), float(s["green_minus_red"])]
