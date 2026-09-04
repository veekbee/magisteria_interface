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

## `luminance` buckets brightness this finely, and calls a bucket a LEVEL when
## it holds this share of the measured pixels. Both are display conventions in
## the same sense as the two above: 256 is the depth a PNG channel has anyway,
## and a thousandth is small enough to see a thin lit ridge and large enough
## that a stray anti-aliased edge is not a level of its own.
const LUMINANCE_BUCKETS := 256
const LEVEL_SHARE := 0.001

## `ramp_agreement` samples the ramp polyline this many times and calls a pixel
## ON the ramp within this distance in normalised-channel space. The tolerance
## is loose deliberately: it exists to separate "these are the ramp's colours"
## from "these are some other colours entirely", not to audit an interpolation.
const RAMP_SAMPLES := 64
const RAMP_TOLERANCE := 0.12


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
    # Near-black is printed as a COUNT as well as a share. It is the class the
    # overlay's unrealised nodata alpha lands in, and at a hundred pixels of a
    # million a percentage rounds to 0.0% whether the number is 105 or 10,500.
    return ("%-18s %5.1f%% coloured  %5.1f%% neutral  %5.2f%% near-black (%d px)  "
            + "mean (%.2f, %.2f, %.2f)  g-r %+.3f") % [
            tag, 100.0 * float(s["coloured_fraction"]),
            100.0 * float(s["neutral"]) / float(maxi(int(s["pixels"]), 1)),
            100.0 * float(s["near_black"]) / float(maxi(int(s["pixels"]), 1)),
            int(s["near_black"]),
            float(mean[0]), float(mean[1]), float(mean[2]), float(s["green_minus_red"])]


## Relief, as the spread of brightness over the pixels a frame actually drew.
##
## A HILLSHADE IS A CLAIM THAT A SURFACE IS LIT, and the evidence for it is that
## brightness VARIES across a surface of one albedo. A terrain lit flat, a
## terrain whose normals all point up, and a terrain drawn with no light at all
## are three different bugs that render as one even grey -- and a colour census
## cannot tell any of them from a working hillshade, because it reports the
## mean and they all have the same mean.
##
## `levels` counts the brightness buckets holding at least `LEVEL_SHARE` of the
## measured pixels. A flat background contributes ONE. It is the number that
## separates "this frame has a surface in it" from "this frame has a colour in
## it", which is the distinction the inside-out terrain hid for four milestones.
static func luminance(img: Image) -> Dictionary:
    var hist := PackedInt32Array()
    hist.resize(LUMINANCE_BUCKETS)
    var counted := 0
    for y in img.get_height():
        for x in img.get_width():
            var c := img.get_pixel(x, y)
            var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
            if l < BLACK_CEILING:
                continue
            hist[mini(int(l * float(LUMINANCE_BUCKETS)), LUMINANCE_BUCKETS - 1)] += 1
            counted += 1
    if counted == 0:
        return {"counted": 0, "levels": 0, "spread": 0.0,
                "why": "every pixel is below BLACK_CEILING: the frame drew nothing"}
    var levels := 0
    var floor_count := int(ceil(LEVEL_SHARE * float(counted)))
    for h in hist:
        if h >= floor_count:
            levels += 1
    var p05 := _percentile(hist, counted, 0.05)
    var p95 := _percentile(hist, counted, 0.95)
    return {
        "counted": counted,
        "levels": levels,
        "p05": p05,
        "p50": _percentile(hist, counted, 0.50),
        "p95": p95,
        "spread": p95 - p05,
    }


## Nearest-rank, over a histogram rather than a sorted array: a 1280x800 frame
## is a million samples and sorting them to find three numbers is waste.
static func _percentile(hist: PackedInt32Array, counted: int, q: float) -> float:
    var want := maxi(1, int(ceil(q * float(counted))))
    var seen := 0
    for i in hist.size():
        seen += hist[i]
        if seen >= want:
            return (float(i) + 0.5) / float(hist.size())
    return 1.0


## Do this frame's colours come from the declared ramp, or from somewhere else?
##
## MEASURED AS HUE, NOT AS COLOUR. The overlay is an albedo under a light, so
## every ramp colour reaches the screen scaled by whatever the hillshade did to
## it -- comparing raw RGB to the ramp would report a working overlay as
## agreeing with nothing. Dividing each pixel by its own brightest channel
## removes the light's scalar and leaves the ratio between channels, which is
## the part the ramp chose.
##
## It answers a narrow question: are these the ramp's colours? It cannot say
## whether the right CELL got the right one -- that join is the headless
## suite's, and it is checked there.
static func ramp_agreement(img: Image, stops: Array) -> Dictionary:
    var samples := _ramp_samples(stops)
    var n := 0
    var sum := 0.0
    var on := 0
    var worst := 0.0
    for y in img.get_height():
        for x in img.get_width():
            var c := img.get_pixel(x, y)
            if c.r < BLACK_CEILING and c.g < BLACK_CEILING and c.b < BLACK_CEILING:
                continue
            if absf(c.r - c.g) < NEUTRAL_TOLERANCE and absf(c.g - c.b) < NEUTRAL_TOLERANCE:
                continue
            var d := _nearest_hue(Vector3(c.r, c.g, c.b), samples)
            n += 1
            sum += d
            worst = maxf(worst, d)
            if d <= RAMP_TOLERANCE:
                on += 1
    if n == 0:
        return {"coloured": 0, "on_ramp_fraction": 0.0, "mean_distance": 0.0,
                "why": "the frame carries no coloured pixels to compare against a ramp"}
    return {
        "coloured": n,
        "on_ramp_fraction": float(on) / float(n),
        "mean_distance": sum / float(n),
        "worst_distance": worst,
    }


static func _ramp_samples(stops: Array) -> Array:
    var out: Array = []
    for i in RAMP_SAMPLES:
        var u := float(i) / float(RAMP_SAMPLES - 1) * float(stops.size() - 1)
        var k := mini(int(floor(u)), stops.size() - 2)
        var a: Color = stops[k]
        var b: Color = stops[k + 1]
        var c := a.lerp(b, u - float(k))
        out.append(_hue(Vector3(c.r, c.g, c.b)))
    return out


static func _hue(v: Vector3) -> Vector3:
    var m: float = maxf(v.x, maxf(v.y, v.z))
    return v if m <= 0.0 else v / m


static func _nearest_hue(v: Vector3, samples: Array) -> float:
    var h := _hue(v)
    var best := INF
    for s in samples:
        best = minf(best, h.distance_to(s))
    return best
