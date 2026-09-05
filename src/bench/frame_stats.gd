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
## `unpaced`, when given, is a second reading of the SAME rungs from an
## instrument the frame pacer does not quantise -- the wall-clock mean over the
## measured frames. It is what tells a censored marginal from a real one.
static func marginals(xs: PackedFloat64Array, ys: PackedFloat64Array,
        unpaced := PackedFloat64Array()) -> Dictionary:
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
    # A NON-FINITE RATIO IS NOT A NUMBER TO RECORD. A marginal of zero or below
    # -- one rung measuring no dearer than the one under it, which happens where
    # the frame sits on its fixed-cost floor -- makes the ratio meaningless, and
    # INF here serialises into the artefact as `1e99999`: not valid JSON, and a
    # fabricated magnitude standing exactly where a measurement should be. The
    # absence is stated instead.
    var result := {
        "ok": true,
        "min_ms_per_instance": lo,
        "max_ms_per_instance": hi,
        "per_rung": out,
    }
    if lo > 0.0:
        result["spread"] = hi / lo
        return result

    # A NON-POSITIVE MARGINAL HAS MORE THAN ONE CAUSE, AND THIS USED TO ASSERT
    # THE WRONG ONE. It said "the fixed-cost floor" for every case. There are
    # three, and the difference decides whether a coefficient can be quoted:
    #
    #   CENSORED -- both rungs reported the same frame time because both sat
    #     inside one rung of the paced-delta ladder. Real on this platform:
    #     multimesh|mid measured 64,000 and 128,000 instances at exactly
    #     7.1429 ms each and recorded a marginal of ZERO, which no amount of
    #     288-triangle instances is. The unpaced reading separates them
    #     (6.76 vs 7.27 ms), so it is the discriminator.
    #   NOT THE TIMER -- negative on the unpaced reading too, so something
    #     about the run is non-monotonic. multimesh|low is this: its first two
    #     rungs report DEARER than the rung above them on every instrument and
    #     `cpu_ms` falls across them, which is a process still settling and not
    #     a cost.
    #   THE FLOOR -- what this always claimed, and what it is only entitled to
    #     say when neither of the above applies.
    var worst := 0
    for i in out.size():
        if out[i] == lo:
            worst = i
            break
    var pair := "between rung %d and rung %d" % [worst, worst + 1]
    var why := ("the cheapest marginal is %s ms per instance, at or below zero: a rung that "
            % String.num(lo, 6) + "cost no more than the one below it, %s. " % pair)
    if unpaced.size() == ys.size() and unpaced.size() > worst + 1:
        var dx := xs[worst + 1] - xs[worst]
        var un := (unpaced[worst + 1] - unpaced[worst]) / dx if dx != 0.0 else 0.0
        result["unpaced_ms_per_instance_there"] = un
        if un > 0.0:
            why += ("CENSORED BY THE PACED TIMER: the two rungs reported the same frame "
                    + "time, and the unpaced reading of the same frames separates them at "
                    + "%s ms per instance. The zero is the instrument's, not the scene's."
                    % String.num(un, 6))
        else:
            why += ("NOT THE TIMER: the unpaced reading of the same frames is %s ms per "
                    % String.num(un, 6) + "instance, also at or below zero, so this is a "
                    + "real non-monotonicity in the sweep and wants looking at rather than "
                    + "explaining away as a floor.")
    else:
        why += ("No unpaced reading was supplied, so this cannot tell a censored marginal "
                + "from a real one and does not guess between them.")
    result["spread_undefined_because"] = why

    # THE WARM-UP SIGNATURE, which is what multimesh|low actually had. If the
    # FIRST rung is dearer than some later rung with more instances in it, the
    # sweep was still settling when it started measuring, and every fit through
    # those points is quoting a slope partly made of that.
    if ys.size() > 2:
        var rest := INF
        for i in range(1, ys.size()):
            rest = minf(rest, ys[i])
        if ys[0] > rest:
            result["head_warm_up"] = ("the first rung (%s ms at %d instances) measured DEARER "
                    % [String.num(ys[0], 4), int(xs[0])]
                    + "than a later rung with more instances in it (%s ms). " % String.num(rest, 4)
                    + "That is the sweep still settling, not a cost, and the rungs before the "
                    + "minimum are worth dropping before this fit is quoted.")
    return result
