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

## How far an offset's ground distance may sit from the requested lag and still
## be reported under it. The reference's number: tight enough that the reported
## lag is the lag.
const DIRECTION_TOLERANCE := 0.02

## How many directions a CONTINUOUS surface samples a lag along. A function has
## no lattice, so it is not restricted to offsets that land on cells and can
## take the circle evenly -- sixteen over the half-circle, because `|dz|` is
## symmetric under negating the offset and the other half would be the same
## sixteen numbers.
const FUNCTION_DIRECTIONS := 16

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
## The spacing of the lattice a sampled surface sits on, or 0 for a continuous
## one. Distinct from `native_m`, which is what the surface is HONEST at: a
## raster resampled finer has a smaller cell and the same honest spacing.
var cell_m: float = 0.0
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
                      description: String, lattice_cell_m: float = 0.0) -> StructureFunction:
    var s := StructureFunction.new()
    s.sample = sampler
    s.native_m = maxf(0.0, declared_native_m)
    s.cell_m = lattice_cell_m if lattice_cell_m > 0.0 else maxf(0.0, declared_native_m)
    s.origin = window_origin
    s.span = window_span
    s.what = description
    return s


## Integer cell offsets whose ground distance IS the requested lag.
##
## THE FIRST CUT OF THIS INSTRUMENT POOLED FOUR OFFSETS INTO ONE BUCKET and two
## of them were at `step * sqrt(2)`, so half of every sample was reported under
## a shorter lag than it was taken at. That inflates a power law's quantile by
## `2^(H/2)` on half its samples -- +10.5% at H=0.55 against +25.8% at H=1.20
## across these rows -- so it biased strata against each other BY THEIR OWN
## EXPONENTS, which is the one comparison decision 986's cross-stratum clause
## is made of. It was invisible to every exponent check, because `S(l) = k*s*l`
## has log-log slope 1 for any direction-independent `k`.
##
## AXIS-ONLY WOULD TRADE ONE DIRECTIONAL ARTEFACT FOR ANOTHER. On a plane the
## first difference over a fixed distance is `|g . v|`, so two directions read
## a gradient at between 0.500 and 1.000 of its magnitude depending on azimuth.
## Over this family the reading is the isotropic median of `|cos|` -- 0.707 at
## every azimuth from step 5 up.
##
## BELOW STEP 5 IT DEGENERATES TO THE AXES, HONESTLY: no integer offset has a
## ground distance near 3 cells except the two axial ones, so a raster genuinely
## cannot sample a diagonal there. That is a property of a lattice, and it is
## why decision 1019 keeps the plain form for coarse lags only.
static func direction_family(step: int, tol: float = DIRECTION_TOLERANCE) -> Array:
    var out: Array = []
    var lim := step + 2
    for dr in range(0, lim + 1):
        for dc in range(-lim, lim + 1):
            if dr == 0 and dc <= 0:
                continue
            if absf(sqrt(float(dr * dr + dc * dc)) - float(step)) <= tol * float(step):
                out.append(Vector2i(dr, dc))
    return out if not out.is_empty() else [Vector2i(0, step), Vector2i(step, 0)]


## The world-metre offsets this surface samples one lag along.
##
## A LATTICE AND A FUNCTION ANSWER THIS DIFFERENTLY, and the difference is the
## honesty rule again one level down. A raster can only be offset by whole
## cells, so it takes the family above and inherits its coarse-lag degeneracy.
## A continuous function is under no such restriction: it can be offset by the
## exact distance in any direction at all, so it takes the circle evenly and
## reads 0.707 on a plane at EVERY lag rather than only from step 5 up.
##
## Which means decision 1019's "plain form at coarse lags only" is a constraint
## on RASTERS and not on the published function. Worth knowing before the rule
## is read as a property of the statistic.
func directions_for(lag: float) -> Array:
    var out: Array = []
    if cell_m > 0.0:
        var step := int(round(lag / cell_m))
        if step < 1:
            return out
        for d in direction_family(step):
            var v: Vector2i = d
            out.append(Vector2(float(v.x) * cell_m, float(v.y) * cell_m))
        return out
    for i in FUNCTION_DIRECTIONS:
        var th := PI * float(i) / float(FUNCTION_DIRECTIONS)
        out.append(Vector2(cos(th) * lag, sin(th) * lag))
    return out


## Quantile-`q` height swing over ground distance, per lag.
##
## Returns `{lag_m: value}`, with `cannot_answer()` at any lag below the
## surface's declared native spacing.
##
## EVERY SAMPLE IS REPORTED UNDER THE DISTANCE IT WAS TAKEN AT. See
## `directions_for`: the surface decides its own offsets, and neither the plain
## nor the detrended form pools two ground distances into one bucket.
func s_of_lag(lags_m: Array, q: float = 0.5, form: String = "plain",
              max_samples: int = 200000, seed: int = 0,
              legacy_pooled: bool = false) -> Dictionary:
    var out := {}
    if not FORMS.has(form):
        return out
    for raw in lags_m:
        var lag := float(raw)
        if lag <= 0.0 or lag < native_m - 1.0e-9:
            out[lag] = cannot_answer()
            continue
        # The window has to hold the whole stencil: one lag for the plain form,
        # two for the centred second difference.
        # The stencil's reach, which for a pooled diagonal is longer than the
        # lag and for the corrected family is exactly it.
        var reach := (2.0 * lag * sqrt(2.0)) if form == "detrended" else lag * sqrt(2.0)
        if reach >= minf(span.x, span.y):
            out[lag] = cannot_answer()
            continue
        # THE RETIRED SAMPLING, KEPT ONLY AS A CONTROL. Convention 6 as amended
        # asks that a mechanism asserted to act be shown acting -- the effect
        # beside its absence when the mechanism is off. This is the "off": the
        # four pooled offsets the first cut used, so the gate can show that
        # correcting them changed the answer rather than asserting it did.
        # Nothing in the client calls this with `legacy_pooled` true except
        # that control.
        var dirs: Array = ([Vector2(lag, 0.0), Vector2(0.0, lag),
                Vector2(lag, lag), Vector2(lag, -lag)] if legacy_pooled
                else directions_for(lag))
        if dirs.is_empty():
            out[lag] = cannot_answer()
            continue
        var per_dir: int = maxi(1, max_samples / dirs.size())
        var vals := PackedFloat64Array()
        var draw := 0
        # HOISTED. The salt is a property of the form and the lag, and it was
        # being rebuilt per SAMPLE -- a string format and a walk over its bytes,
        # a few million times in one sweep. Constant inside the loop it is
        # constant over.
        var salt := StableHash.of_name("%s|%s" % [form, String.num(lag, 6)])
        for d in dirs:
            var off: Vector2 = d
            var dx := off.x
            var dy := off.y
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


## WHAT THE POOLED DIRECTIONS COST, kept because the defect is instructive and
## the control that demonstrates it is still in the gate.
##
## The first cut of this instrument pooled four offsets -- `(l,0)`, `(0,l)`,
## `(l,l)`, `(l,-l)` -- into one lag bucket, and the last two are at a ground
## distance of `l*sqrt(2)`. So half of every sample was measured at a longer lag
## than it was reported under.
##
## THE EXPONENT NEVER SAW IT, which is why it survived a test suite that checks
## exponents: `S(l) = k*s*l` has log-log slope 1 for any direction-independent
## `k`, so every exponent check passed. What moved was the AMPLITUDE, by
## `2^(H/2)` on half the samples -- so the inflation was a function of the
## exponent, and it biased strata against each other by the very quantity that
## distinguishes them. Decision 986's cross-stratum clause is that comparison.
##
## On a plane it showed as an azimuth dependence: the pooled reading was
## between 0.6708 and 1.0 of the gradient, worst at `atan(1/2)`. Corrected, a
## continuous surface reads the isotropic median of `|cos|` -- 0.7071 -- at
## every azimuth and every lag.
static func directions_note() -> String:
    return ("every sample is reported under the distance it was taken at. A lattice surface "
            + "takes `direction_family(step)`, which degenerates to the axes below step 5 "
            + "because no integer offset sits near 3 cells otherwise; a continuous surface "
            + "takes the circle evenly and has no such floor. The retired pooling -- four "
            + "offsets, two of them at l*sqrt(2) -- inflated a power law's quantile by "
            + "2^(H/2) on half its samples, which is +10.5% at H=0.55 against +25.8% at "
            + "H=1.20, and biased strata against each other by their own exponents.")
