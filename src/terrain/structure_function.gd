class_name StructureFunction
extends RefCounted

## Decision 986's walk-mode instrument: the height-difference structure
## function `S_q(l)`, in both of the forms the calibration measures.
##
## WHAT IT REPLACES, AND WHY A SECOND MOMENT WOULD NOT HAVE DONE. This repo
## already had `tools/measure_variogram.gd`, which is half the mean SQUARED
## difference between pairs a lag apart. That is a different statistic and the
## difference is load-bearing: a second moment is dominated by the tail that a
## quantile is chosen to resist, and 986 names a quantile for exactly that
## reason. Reusing the variogram would have been one rename away from grading
## the criterion against a statistic it does not name.
##
## THE HONESTY RULE IS THE WHOLE POINT. A surface declares the spacing it is
## honest at, and below that this returns CANNOT ANSWER rather than a number.
## That clause is what lets a RASTER AND A FUNCTION be asked the same question:
## the detail function is continuous and answers at every lag, while a 1 m DEM
## cannot answer below a metre and must say so instead of interpolating. A
## grader that quietly interpolates below the declared spacing is grading its
## own interpolation -- which is precisely what §23.976 measured in the
## instrument 986 retired, where the reported answer was the sampling step at
## every resolution and therefore any amplitude passed.
##
## BOTH FORMS, MEASURED, NEITHER RULED HERE.
##
##   plain       |z(x+l) - z(x)|                 -- the form 986 names
##   detrended   |z(x+l) - 2z(x) + z(x-l)|       -- the second difference
##
## The plain form on a tilted plane returns the gradient and almost nothing
## else, so on steep ground it grades something that cannot be wrong and barely
## sees the only thing that can. The second difference annihilates any linear
## trend exactly, so it is blind to slope by construction. Which form the bands
## are declared on is a corpus ruling that has not been made, and this file
## measures both so that the ruling can be APPLIED rather than rebuilt. Nothing
## here picks one.
##
## SAMPLED, AND SEEDED THROUGH THIS REPO'S OWN MIXER. A window of any size has
## far more pairs at one lag than anyone wants to visit, and a quantile
## converges on a tiny fraction of them. The offsets come from `StableHash`
## rather than from an engine generator, for the reason everything
## position-seeded here does: an engine's generator moves the answer when the
## engine updates. That makes the SAMPLE SET different from the reference
## implementation's, which draws from numpy -- and that is fine and worth
## saying, because what the two sides compare is the STATISTIC and not the
## draw. Two estimators of one population quantile agree by converging, not by
## visiting the same pairs.

## The two forms. Named rather than passed as a boolean: a caller says which
## statistic it wants and a measurement records which one it holds.
const FORMS := ["plain", "detrended"]

## The measurable range for a fitted law, in metres. The lower bound is where
## real elevation data at basin scale stops; the upper is the parent spacing
## decision 1004 fixed. Both are properties of the DATA rather than choices.
const FIT_LO_M := 1.0
const FIT_HI_M := 100.0

## A flat-constant component at or above this many samples is a flattened water
## surface rather than ground. See `water_share`: this client DECLARES that it
## does not mask, rather than masking badly.
const WATER_COMPONENT_MIN_PX := 10000

## How a lag below the declared native spacing is reported.
##
## `null`, and not a number, not NAN and not zero. The rule is that the
## instrument CANNOT ANSWER, and every one of those three alternatives is a
## thing a surface could legitimately return -- a NAN especially, which is what
## this repo's rasters already give at nodata. An absence that is
## indistinguishable from a value is not an absence.
static func cannot_answer():
    return null


## What is being measured: anything that answers a height at a world position,
## and the spacing it is honest at.
##
## WORLD SPACE RATHER THAN PIXEL INDICES, which is the generalisation the
## honesty rule asks for. The reference implementation takes a raster and a
## cell size because both of its callers hold arrays; this client's principal
## subject is a pure function with no array at all. A surface here is a
## sampler, a declared native spacing and a window, and a raster is the case
## where the sampler reads an array.
var sample: Callable
## Below this lag the instrument refuses. Zero for a continuous function, which
## is a claim it is entitled to make and a raster is not.
var native_m: float = 0.0
## The window sampled, in world metres.
var origin: Vector2 = Vector2.ZERO
var span: Vector2 = Vector2.ZERO
## What this surface is, for a measurement that has to say what it measured.
var what: String = ""
## The share of the window that is flattened water.
##
## NAN AND NOT ZERO WHEN NOTHING LOOKED. Water is not terrain and the detail
## function does not synthesise it; left in a real DEM it does not merely add
## noise, it dominates, because every pair inside one flattened body differs by
## exactly zero and the median goes to zero at every lag. This client does not
## implement the mask -- the reference does, with connected components over
## bit-identical neighbours -- so it reports that it did not look rather than
## reporting that it found none.
var water_share: float = NAN


## A continuous surface: a function of position, honest at every lag.
static func of_function(sampler: Callable, window_origin: Vector2, window_span: Vector2,
                        description: String) -> StructureFunction:
    var s := StructureFunction.new()
    s.sample = sampler
    s.native_m = 0.0
    s.origin = window_origin
    s.span = window_span
    s.what = description
    s.water_share = 0.0     # a synthesised surface has none by construction
    return s


## A sampled surface, honest only at or above the spacing it DECLARES.
##
## Declared and never inferred from the window: a raster resampled to a finer
## grid still answers at its original spacing, and inferring from the array
## would let it claim octaves it does not have -- which is the defect §23.976
## measured in the retired instrument, arriving through the back door.
static func of_raster(sampler: Callable, declared_native_m: float,
                      window_origin: Vector2, window_span: Vector2,
                      description: String) -> StructureFunction:
    var s := StructureFunction.new()
    s.sample = sampler
    s.native_m = maxf(0.0, declared_native_m)
    s.origin = window_origin
    s.span = window_span
    s.what = description
    return s


## Quantile-`q` height swing over ground distance, per lag.
##
## Returns `{lag_m: value}`, with `cannot_answer()` at any lag below the
## surface's declared native spacing.
##
## THE DIRECTIONS ARE THE REFERENCE'S, INCLUDING THE TWO DIAGONALS. That choice
## is not neutral and `directions_note` says what it costs; it is mirrored here
## rather than corrected, because conformance to a published instrument comes
## before improving it and a client that quietly measured a different statistic
## would be the harder defect to find.
func s_of_lag(lags_m: Array, q: float = 0.5, form: String = "plain",
              max_samples: int = 200000, seed: int = 0) -> Dictionary:
    var out := {}
    if not FORMS.has(form):
        return out
    var per_dir: int = maxi(1, max_samples / 4)
    var dirs: Array = ([[0, 1], [1, 0], [1, 1], [1, -1]] if form == "plain"
            else [[0, 1], [1, 0]])
    for raw in lags_m:
        var lag := float(raw)
        if lag <= 0.0 or lag < native_m - 1.0e-9:
            out[lag] = cannot_answer()
            continue
        # The window has to hold the whole stencil: one lag for the plain form,
        # two for the centred second difference.
        var reach := (2.0 * lag) if form == "detrended" else lag
        if reach >= minf(span.x, span.y):
            out[lag] = cannot_answer()
            continue
        var vals := PackedFloat64Array()
        var draw := 0
        # HOISTED. The salt is a property of the form and the lag, and it was
        # being rebuilt per SAMPLE -- a string format and a walk over its bytes,
        # a few million times in one sweep. Constant inside the loop it is
        # constant over.
        var salt := StableHash.of_name("%s|%s" % [form, String.num(lag, 6)])
        for d in dirs:
            var dx := float((d as Array)[0]) * lag
            var dy := float((d as Array)[1]) * lag
            for i in per_dir:
                draw += 1
                var p := _point(seed, salt, draw, reach)
                var v := NAN
                if form == "plain":
                    v = absf(sample.call(p.x + dx, p.y + dy) - sample.call(p.x, p.y))
                else:
                    v = absf(sample.call(p.x + dx, p.y + dy)
                            - 2.0 * sample.call(p.x, p.y)
                            + sample.call(p.x - dx, p.y - dy))
                if is_finite(v):
                    vals.append(v)
        out[lag] = cannot_answer() if vals.is_empty() else quantile(vals, q)
    return out


## One sample point inside the window, inset far enough that the whole stencil
## lands inside it. Seeded through the repo's mixer, so a measurement repeats.
func _point(seed: int, salt: int, draw: int, reach: float) -> Vector2:
    var u := StableHash.unit(StableHash.of5(seed, salt, 0, draw, 0))
    var v := StableHash.unit(StableHash.of5(seed, salt, 1, draw, 0))
    return Vector2(origin.x + reach + u * (span.x - 2.0 * reach),
                   origin.y + reach + v * (span.y - 2.0 * reach))


## The q-quantile of a sample, by the same linear interpolation the reference's
## `numpy.quantile` uses at its default. Stated because a quantile convention
## is exactly the kind of thing two implementations differ on silently.
static func quantile(values: PackedFloat64Array, q: float) -> float:
    if values.is_empty():
        return NAN
    var v := values.duplicate()
    v.sort()
    var pos := clampf(q, 0.0, 1.0) * float(v.size() - 1)
    var lo := int(floor(pos))
    var hi := int(ceil(pos))
    if lo == hi:
        return v[lo]
    return v[lo] + (v[hi] - v[lo]) * (pos - float(lo))


## `S(l) = amplitude * l ** exponent`, by least squares in logs over the
## measurable range. Empty when fewer than three lags can answer.
##
## `parent_spacing_m` is REQUIRED and travels into the row, because it is part
## of what an amplitude means rather than metadata about it: an amplitude at a
## lag is a claim about which octaves are being synthesised, so one number
## under two parents describes two different spectral spans.
static func fit_law(sf: Dictionary, parent_spacing_m: float, form: String,
                    lo_m: float = FIT_LO_M, hi_m: float = FIT_HI_M) -> Dictionary:
    var xs := PackedFloat64Array()
    var ys := PackedFloat64Array()
    for lag in sf:
        var s = sf[lag]
        if s == null:
            continue
        var sv := float(s)
        if sv <= 0.0 or float(lag) < lo_m - 1.0e-9 or float(lag) > hi_m + 1.0e-9:
            continue
        xs.append(log(float(lag)))
        ys.append(log(sv))
    if xs.size() < 3:
        return {}
    if parent_spacing_m <= 0.0:
        return {"refused": ("a calibration row must name the parent it was measured against, "
                + "and this one does not. An amplitude at a lag is a claim about which "
                + "octaves are synthesised; the same number under two parents describes two "
                + "different spectral spans.")}
    var n := float(xs.size())
    var mx := 0.0
    var my := 0.0
    for i in xs.size():
        mx += xs[i]
        my += ys[i]
    mx /= n
    my /= n
    var sxy := 0.0
    var sxx := 0.0
    for i in xs.size():
        sxy += (xs[i] - mx) * (ys[i] - my)
        sxx += (xs[i] - mx) * (xs[i] - mx)
    if sxx <= 0.0:
        return {}
    var b := sxy / sxx
    var la := my - b * mx
    var resid := 0.0
    for i in xs.size():
        var e := ys[i] - (b * xs[i] + la)
        resid += e * e
    return {"amplitude": exp(la), "exponent": b, "parent_spacing_m": parent_spacing_m,
            "form": form, "n_lags": xs.size(), "rms_log_residual": sqrt(resid / n)}


## Both forms on one window, which is what the calibration collects. Neither is
## ruled; both are recorded so that a ruling can be applied to data rather than
## sent back for a re-measurement.
func measure_both(lags_m: Array, parent_spacing_m: float, q: float = 0.5,
                  seed: int = 0) -> Dictionary:
    var out := {"q": q, "native_m": native_m, "what": what,
                "parent_spacing_m": parent_spacing_m, "water_share": water_share,
                "forms": {}}
    for form in FORMS:
        var sf := s_of_lag(lags_m, q, str(form), 200000, seed)
        out["forms"][str(form)] = {
            "s_of_lag": sf,
            "cannot_answer_below_m": native_m,
            "law": fit_law(sf, parent_spacing_m, str(form)),
        }
    return out


## WHAT THE DIAGONAL DIRECTIONS COST, because this instrument grades a criterion
## and an instrument's own bias belongs beside it.
##
## The plain form pools four offsets -- `(l, 0)`, `(0, l)`, `(l, l)`, `(l, -l)`
## -- into one lag bucket. The last two are at a ground distance of `l * sqrt(2)`,
## so half of every sample is measured at a longer lag than the one it is
## reported under. On a tilted plane the height difference for an offset `v` is
## `|g . v|`, so the pooled median is not `|g| * l` but `|g| * l` times a factor
## that depends on the gradient's AZIMUTH: 1.0 when the slope runs along an
## axis and 0.707 when it runs at 45 degrees to one.
##
## The exponent is unaffected -- every direction scales with `l`, so a plane
## still fits exponent 1 exactly -- and the AMPLITUDE is not the gradient. It is
## between 0.6708 and 1.0 of it, worst at an azimuth of 26.57 degrees (which is
## `atan(1/2)`, where the two axis offsets and the two diagonals interleave
## least helpfully) and exact only where the slope runs along a sampling axis.
## Which of those a stratum gets depends on how its hills happen to sit
## relative to the raster's axes, which is a fact about the grid rather than
## about the ground.
static func directions_note() -> String:
    return ("the plain form pools four offsets into one lag bucket and two of them are at "
            + "l*sqrt(2), so half the pairs are measured at a longer lag than they are "
            + "reported under. On a plane the exponent is still exactly 1 and the amplitude "
            + "is between 0.6708 and 1.0 of the gradient depending on the slope's azimuth "
            + "relative to the sampling axes, worst at atan(1/2) = 26.57 degrees. Mirrored "
            + "from the reference rather than "
            + "corrected, because a client quietly measuring a different statistic is the "
            + "harder defect to find.")
