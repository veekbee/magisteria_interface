class_name FrameStats
extends RefCounted

## The statistics the per-instance frame-cost benchmark reports. §19.8.9.
##
## QUANTILES, NEVER A MEAN. The unit of failure is one frame, not a run of
## them: a budget is blown by the worst frame a viewer sees, and §19.8.6's
## conclusion rests on that unit. A configuration that misses one frame in
## twenty at 60 ms and makes the other nineteen at 8 ms has a comfortable mean
## and a visible stutter, and the mean is the number that hides it.
##
## THE QUANTILE RULE IS NEAREST-RANK, AND IT IS STATED RATHER THAN ASSUMED.
## Interpolating between samples invents a frame time that did not occur;
## p99 of 80 frames is the 80th-ranked frame, which is a frame that happened.
## The artefact carries this definition, because a p99 with an unstated rule
## is not comparable with anyone else's.
##
## THE FIT IS REPORTED WITH ITS RESIDUAL, so a caller can see whether
## "coefficient" is the right shape for the answer at all. If cost is not
## linear in instance count, a single ms-per-instance number is a worse answer
## than the curve, and the residual is what says so.

## Nearest-rank quantile: the ceil(q * n)-th smallest sample, 1-indexed.
## `q` is a fraction, so p99 is `quantile(s, 0.99)`.
static func quantile(samples: PackedFloat64Array, q: float) -> float:
    if samples.is_empty():
        return NAN
    var s := samples.duplicate()
    s.sort()
    var rank := int(ceil(clampf(q, 0.0, 1.0) * float(s.size())))
    return s[clampi(rank - 1, 0, s.size() - 1)]


## The whole distribution, in the shape the artefact records it.
##
## The mean is carried too, and only so that it can be compared with p50: a
## mean well above the median is the signature of a tail, which is the thing
## this benchmark exists to see.
static func summarise(samples: PackedFloat64Array) -> Dictionary:
    if samples.is_empty():
        return {"n": 0}
    var total := 0.0
    var lo := INF
    var hi := -INF
    for v in samples:
        total += v
        lo = minf(lo, v)
        hi = maxf(hi, v)
    return {
        "n": samples.size(),
        "min": lo,
        "p50": quantile(samples, 0.50),
        "p95": quantile(samples, 0.95),
        "p99": quantile(samples, 0.99),
        "max": hi,
        "mean": total / float(samples.size()),
    }


## Least squares `y = a + b * x`, with what it costs to believe it.
##
## `b` is the per-instance coefficient §19.8.9 names. `r2` and
## `max_rel_residual` are what decide whether quoting `b` alone is honest:
## a fit that misses a rung by 40% has a coefficient in the arithmetic sense
## and not in the sense anyone wants to multiply by.
static func fit_linear(xs: PackedFloat64Array, ys: PackedFloat64Array) -> Dictionary:
    var n := mini(xs.size(), ys.size())
    if n < 2:
        return {"ok": false, "why": "a line needs two points; %d given" % n}
    var sx := 0.0
    var sy := 0.0
    for i in n:
        sx += xs[i]
        sy += ys[i]
    var mx := sx / float(n)
    var my := sy / float(n)
    var sxy := 0.0
    var sxx := 0.0
    for i in n:
        sxy += (xs[i] - mx) * (ys[i] - my)
        sxx += (xs[i] - mx) * (xs[i] - mx)
    if sxx == 0.0:
        return {"ok": false, "why": "every sample is at the same instance count"}
    var b := sxy / sxx
    var a := my - b * mx
    var ss_res := 0.0
    var ss_tot := 0.0
    var worst := 0.0
    for i in n:
        var pred := a + b * xs[i]
        ss_res += (ys[i] - pred) * (ys[i] - pred)
        ss_tot += (ys[i] - my) * (ys[i] - my)
        if ys[i] != 0.0:
            worst = maxf(worst, absf(ys[i] - pred) / absf(ys[i]))
    return {
        "ok": true,
        "intercept_ms": a,
        "ms_per_instance": b,
        "r2": 1.0 - (ss_res / ss_tot) if ss_tot > 0.0 else 1.0,
        "max_rel_residual": worst,
        "points": n,
    }


## The marginal cost between consecutive rungs, which is what a fit averages
## over. Reported separately because a straight line through a curve has a
## slope, and the slope is not a coefficient anyone should carry away: the
## spread between the cheapest and dearest marginal instance is the fact.
static func marginals(xs: PackedFloat64Array, ys: PackedFloat64Array) -> Dictionary:
    var n := mini(xs.size(), ys.size())
    if n < 2:
        return {"ok": false, "why": "a marginal needs two rungs; %d given" % n}
    var out := PackedFloat64Array()
    for i in range(1, n):
        var dx := xs[i] - xs[i - 1]
        if dx == 0.0:
            continue
        out.append((ys[i] - ys[i - 1]) / dx)
    if out.is_empty():
        return {"ok": false, "why": "no two rungs are at different instance counts"}
    var lo := INF
    var hi := -INF
    for v in out:
        lo = minf(lo, v)
        hi = maxf(hi, v)
    return {
        "ok": true,
        "min_ms_per_instance": lo,
        "max_ms_per_instance": hi,
        "spread": (hi / lo) if lo > 0.0 else INF,
        "per_rung": out,
    }
