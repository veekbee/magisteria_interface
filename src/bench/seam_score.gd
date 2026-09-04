class_name SeamScore
extends RefCounted

## Grading a far-field candidate against the instances it stands in for.
##
## THE SCORE IS IN AN ANNULUS, NOT IN A FRAME. A whole-frame metric is mostly
## the near field: at eye level the ground within a hundred metres fills most
## of the picture, so a candidate that got the far field entirely wrong and the
## near field right would score well. The seam is a ring, and the ring is what
## gets measured.
##
## THE TWO QUANTITIES ARE COVERAGE AND MEAN COLOUR PER UNIT GROUND AREA, per
## family, as functions of range. They are the conserved quantities: whatever
## replaces instances at range -- a tint, an impostor, a crossfade of both --
## has to hold their sum to the curve the instances draw. Everything in this
## file exists to make those two measurable rather than assertable.
##
## COVERAGE CAN EXCEED ONE AND THAT IS NOT AN ERROR. It is plant pixels over
## GROUND pixels in the same band, and a tree covers more screen than its own
## footprint. A metric clamped at one would report a closed canopy and a forest
## as the same thing.

## Bands the curve is reported over, as multiples of the seam distance. The
## scoring annulus is the 0.7-1.5x band: near enough to the seam that a
## candidate meeting it there meets it where the eye is looking, far enough
## from the camera that the near field is not in it.
const CURVE_MULTIPLES: Array = [0.25, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0, 4.0]
const SCORE_LO_MULTIPLE := 0.7
const SCORE_HI_MULTIPLE := 1.5

## Luminance buckets for the distribution distance. Coarse deliberately: this
## is asking whether a candidate has the same spread of light and dark as the
## stand, not whether it matches it pixel for pixel, and a fine histogram over
## a few thousand pixels is mostly sampling noise.
const LUMINANCE_BUCKETS := 16

## A pixel counts as inside the mask above this. The mask is one-bit by
## construction; the threshold exists because a rendered edge is antialiased
## and the halfway point is the only defensible place to cut it.
const MASK_THRESHOLD := 0.5


## Range bands, in metres, from a seam distance.
static func bands(seam_m: float) -> Array:
    var out: Array = []
    for i in CURVE_MULTIPLES.size() - 1:
        out.append({"lo_m": seam_m * float(CURVE_MULTIPLES[i]),
                    "hi_m": seam_m * float(CURVE_MULTIPLES[i + 1])})
    return out


static func scoring_band(seam_m: float) -> Dictionary:
    return {"lo_m": seam_m * SCORE_LO_MULTIPLE, "hi_m": seam_m * SCORE_HI_MULTIPLE}


## How many pixels a mask claims.
static func mask_pixels(mask: Image) -> int:
    var n := 0
    for y in mask.get_height():
        for x in mask.get_width():
            if mask.get_pixel(x, y).r >= MASK_THRESHOLD:
                n += 1
    return n


## What a colour frame holds where a mask says to look.
##
## `colour` is the candidate rendered in isolation over a black backdrop, so a
## pixel that is not black is the thing being measured. `mask` is the same view
## rendered through `annulus.gdshader`, so a white pixel is in the band. The
## two must be the same size and the same camera, which is why they are taken
## in one run and never assembled from two.
static func within(mask: Image, colour: Image) -> Dictionary:
    if mask.get_width() != colour.get_width() or mask.get_height() != colour.get_height():
        return {"ok": false, "why": "the mask and the frame are different sizes"}
    var hist := PackedInt32Array()
    hist.resize(LUMINANCE_BUCKETS)
    var lit := 0
    var in_band := 0
    var r := 0.0
    var g := 0.0
    var b := 0.0
    for y in mask.get_height():
        for x in mask.get_width():
            if mask.get_pixel(x, y).r < MASK_THRESHOLD:
                continue
            in_band += 1
            var c := colour.get_pixel(x, y)
            if c.r < FrameProbe.BLACK_CEILING and c.g < FrameProbe.BLACK_CEILING \
                    and c.b < FrameProbe.BLACK_CEILING:
                continue
            lit += 1
            r += c.r
            g += c.g
            b += c.b
            var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
            hist[mini(int(l * float(LUMINANCE_BUCKETS)), LUMINANCE_BUCKETS - 1)] += 1
    var n := maxf(float(lit), 1.0)
    return {
        "ok": true,
        "band_pixels": in_band,
        "lit_pixels": lit,
        "mean_colour": [r / n, g / n, b / n],
        "luminance_histogram": _normalised(hist, lit),
    }


static func _normalised(hist: PackedInt32Array, total: int) -> Array:
    var out: Array = []
    var t := maxf(float(total), 1.0)
    for h in hist:
        out.append(float(h) / t)
    return out


## Plant pixels over ground pixels in one band -- the conserved quantity, on
## screen. `ground_pixels` is the terrain rendered ALONE through the same
## annulus, so it is the screen area that band's ground occupies whether or not
## anything stands on it.
static func coverage(lit_pixels: int, ground_pixels: int) -> float:
    if ground_pixels <= 0:
        return NAN
    return float(lit_pixels) / float(ground_pixels)


## Distance between two colours, in the space the eye is least forgiving about.
##
## Plain Euclidean RGB, and stated as such rather than dressed up: the frames
## being compared come out of one renderer with one palette, so the question is
## "how far apart" and not "how different do these look to a person".
static func colour_error(a: Array, b: Array) -> float:
    return Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(
            Vector3(float(b[0]), float(b[1]), float(b[2])))


## How far apart two luminance distributions are, as the area between their
## cumulative curves -- earth-mover distance on a fixed axis.
##
## L1 BETWEEN THE HISTOGRAMS WOULD BE WRONG HERE. Two distributions one bucket
## apart and two at opposite ends of the range both score the same under L1,
## and the whole question is whether a candidate is a LITTLE too dark or a lot.
static func luminance_distance(a: Array, b: Array) -> float:
    if a.size() != b.size():
        return NAN
    var ca := 0.0
    var cb := 0.0
    var area := 0.0
    for i in a.size():
        ca += float(a[i])
        cb += float(b[i])
        area += absf(ca - cb)
    return area / float(maxi(a.size(), 1))


## Which of a set of candidates is closest to the oracle, and by how much.
##
## THE METRIC HAS TO FAIL THE BAD FRAME. A score that ranks a candidate best
## because it is subtle is a score nobody should trust on anything subtle, so
## the harness always grades a deliberately-wrong baseline alongside and this
## reports the margin between the winner and the rest. A margin near zero is
## the finding, not the ranking.
static func rank(scores: Dictionary) -> Dictionary:
    var order: Array = []
    for name in scores:
        order.append({"candidate": name, "error": float(scores[name])})
    order.sort_custom(func(x, y): return float(x["error"]) < float(y["error"]))
    var out := {"order": order}
    if order.size() >= 2:
        var best := float(order[0]["error"])
        var next := float(order[1]["error"])
        out["margin"] = next - best
        out["margin_ratio"] = (next / best) if best > 0.0 else INF
        out["separates"] = next > best * 1.2
        if not out["separates"]:
            out["why_not"] = ("%s and %s are within 20%% of each other (%.4f against %.4f), "
                    + "so this metric does not tell them apart and cannot be trusted to rank "
                    + "anything subtler") % [str(order[0]["candidate"]),
                            str(order[1]["candidate"]), best, next]
    return out
