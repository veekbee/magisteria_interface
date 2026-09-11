class_name StratumGrade
extends RefCounted

## Decision 1019's grading form, built so that the values are the only thing
## still missing.
##
## WHAT 1019 RULED, AND THE SHAPE IT FORCES. Gap 164 asked which difference
## `S_q(l)` is taken on and was ruled by refusing all three of its forks: each
## of convention 6's two clauses gets its own instrument rather than one form
## serving both. The second difference carries BOTH clauses -- the per-stratum
## band and the cross-stratum spread -- because it cancels the gradient at
## every azimuth exactly, so a comparison between strata reads roughness and not
## prevailing aspect. The plain first difference is retired as a roughness gate
## and kept as property 3's coarse-lag instrument, which is the same disposition
## 986 gave `changes_underfoot`: wrong as a gate, right as a probe.
##
## THE STRATA ARE NOT A TABLE. There is no stratum-to-landform correspondence to
## look up, and a hand-authored one would be a constant nobody identified while
## one read off the synthesiser's output would be the thing §23.425 forbids. The
## strata ARE the membership functions -- the same continuous weights
## `DetailField.weights_for` computes at runtime -- evaluated on real HAND and
## slope. Evaluated the same way on both sides, calibration and runtime cannot
## disagree about which ground is which.
##
## THE SUPPORT IS THE WINDOW, membership per point within it, never a
## catchment median. That is not a detail of sampling: at median support the
## joint corner *flat and high above drainage* had one qualifying catchment in
## the whole basin, because a catchment holding a mesa almost always holds its
## bounding slopes too. The stratum was nearly invisible to the statistic and
## not to a body standing on it.
##
## AND A STRATUM WITHOUT COVERAGE GETS A REFUSED BAND, NOT A TOLERANCE OF ZERO.
## The two are opposite: a refusal says nobody measured this, and a zero
## tolerance says everything fails. Neither is "it passed", which is what a
## silent skip would have produced.

## The form, and there is one. Named rather than passed, so that a caller
## cannot quietly grade on the retired one.
const FORM := "detrended"

## Below this many EFFECTIVE samples a stratum's band is refused rather than
## estimated.
##
## A SAMPLING-SUFFICIENCY FLOOR AND NOT A COVERAGE THRESHOLD, which matters
## because §23.425 forbids choosing a threshold from the data it grades. This
## one is a property of quantile estimation and of nothing else: a median's
## standard error is about `1.25 * sigma / sqrt(n)`, so 256 effective samples
## put it near 8% of a spread -- the same order as the narrowest band widths
## anyone has measured, which is the point at which the estimate stops being
## the thing being compared. Effective and not raw, because membership weights
## mean a thousand samples at weight 0.01 are not a thousand samples: the count
## is `(sum w)^2 / sum w^2`, which is the usual one.
const MIN_EFFECTIVE_SAMPLES := 256.0

## Why a grade is absent, as named things rather than as a number nobody can
## tell from a measurement.
const NO_LAYERS := "NO_LAYERS"            ## no real HAND or slope to evaluate membership on
const NO_COVERAGE := "NO_COVERAGE"        ## the stratum is not in these windows
const NO_BANDS := "NO_BANDS"              ## measured, and nothing published to measure against


## The q-quantile of values carrying weights.
##
## The weights are memberships, so this is what "membership-weighted" means
## arithmetically: a sample counts as much as the stratum is present where it
## was taken, and a position that is half floor and half slope contributes to
## both bands at half strength rather than being assigned to one.
static func weighted_quantile(values: PackedFloat64Array, weights: PackedFloat64Array,
                              q: float) -> float:
    if values.is_empty() or values.size() != weights.size():
        return NAN
    var order: Array = []
    for i in values.size():
        order.append(i)
    order.sort_custom(func(a: int, b: int) -> bool: return values[a] < values[b])
    var total := 0.0
    for w in weights:
        total += w
    if total <= 0.0:
        return NAN
    var target := clampf(q, 0.0, 1.0) * total
    var run := 0.0
    for i in order:
        run += weights[i]
        if run >= target:
            return values[i]
    return values[order[order.size() - 1]]


## Effective sample count for a weighted set: `(sum w)^2 / sum w^2`.
static func effective_n(weights: PackedFloat64Array) -> float:
    var s := 0.0
    var s2 := 0.0
    for w in weights:
        s += w
        s2 += w * w
    return 0.0 if s2 <= 0.0 else (s * s) / s2


## One window, every stratum the rows declare, at every lag.
##
## Returns `{"ok", "why", "strata": {name: {lag: value|null, "n_effective": f}}}`.
##
## THE SURFACE IS THE DRAWN GROUND AND NOT THE DETAIL TERM ALONE. The bands are
## measured from real 1 m ground, which carries its terrain, so grading only
## what this client synthesises would compare two different quantities. The
## parent's own contribution at these lags is small and is REPORTED rather than
## assumed -- see `parent_share`.
static func over_window(df: DetailField, hf: Heightfield, centre: Vector2, span: float,
                        lags: Array, q: float = 0.5, samples_per_lag: int = 600,
                        seed: int = 0) -> Dictionary:
    return over_windows(df, hf, [centre], span, lags, q, samples_per_lag, seed)


## SEVERAL WINDOWS, WHICH IS WHAT 1019 MEANS BY CROSS-WINDOW AND IS NOT AN
## OPTIMISATION.
##
## One window of a few kilometres is almost always one landform: measured here,
## a 3 km window over real basin left four of five strata below the sampling
## floor at every lag, so nothing could be compared to anything and convention
## 6's spread clause had one stratum to spread. That is the support rule
## working rather than failing -- a stratum is refused where it is not, instead
## of being handed the window's own median under its name -- and it is why
## window sourcing has to cover the joint HAND-by-slope membership space rather
## than a few places that happen to be adjacent.
##
## The samples are POOLED before the quantile rather than the quantiles
## averaged: a weighted quantile of a union is a statistic, and a mean of
## quantiles is not one.
static func over_windows(df: DetailField, hf: Heightfield, centres: Array, span: float,
                         lags: Array, q: float = 0.5, samples_per_lag: int = 600,
                         seed: int = 0) -> Dictionary:
    if df == null or not df.is_loaded() or hf == null:
        return {"ok": false, "why": NO_LAYERS, "strata": {}}
    # REAL HAND AND SLOPE OR NOTHING. 1019 rules the strata are the membership
    # functions evaluated on real inputs; a clone without the layers can
    # evaluate them on a re-derived lattice gradient and no HAND at all, which
    # would be a different stratification wearing the same name.
    if df.classifier_source().begins_with("the parent lattice"):
        return {"ok": false, "why": NO_LAYERS, "strata": {}}

    var strata := df.landforms()
    var acc := {}
    for name in strata:
        acc[str(name)] = {}
    var half := span * 0.5
    var windows := 0
    for raw in lags:
        var lag := float(raw)
        var reach := 2.0 * lag * sqrt(2.0)
        if reach >= span:
            for name in strata:
                (acc[str(name)] as Dictionary)[lag] = null
            continue
        var salt := StableHash.of_name("1019|%s" % String.num(lag, 6))
        var vals := PackedFloat64Array()
        var wts := {}
        for name in strata:
            wts[str(name)] = PackedFloat64Array()
        windows = 0
        for ci in centres.size():
            var centre: Vector2 = centres[ci]
            windows += 1
        # SIXTEEN DIRECTIONS, EVENLY. A continuous surface is under no lattice
        # restriction, so the offsets span the half-circle -- see
        # `StructureFunction.directions_for`, which this mirrors rather than
        # re-derives.
            for i in samples_per_lag:
                _collect(df, hf, centre, half, span, reach, lag, salt, seed, ci, i,
                        strata, vals, wts)
        for name in strata:
            var arr: PackedFloat64Array = wts[str(name)]
            var n_eff := effective_n(arr)
            var entry: Dictionary = acc[str(name)]
            entry[lag] = (null if n_eff < MIN_EFFECTIVE_SAMPLES
                    else weighted_quantile(vals, arr, q))
            entry["n_effective"] = maxf(float(entry.get("n_effective", 0.0)), n_eff)
    return {"ok": true, "why": "", "windows": windows, "strata": acc}


## One sample: a stencil centred in the window, its membership, and the second
## difference of the drawn ground across it.
static func _collect(df: DetailField, hf: Heightfield, centre: Vector2, half: float,
                     span: float, reach: float, lag: float, salt: int, seed: int,
                     window: int, i: int, strata: PackedStringArray,
                     vals: PackedFloat64Array, wts: Dictionary) -> void:
            var u := StableHash.unit(StableHash.of5(seed, salt, window * 3 + 0, i, 0))
            var v := StableHash.unit(StableHash.of5(seed, salt, window * 3 + 1, i, 0))
            var th := PI * StableHash.unit(StableHash.of5(seed, salt, window * 3 + 2, i, 0))
            var px := centre.x - half + reach + u * (span - 2.0 * reach)
            var py := centre.y - half + reach + v * (span - 2.0 * reach)
            var dx := cos(th) * lag
            var dy := sin(th) * lag
            var here := Vector2(px, py)
            var slope_deg := df.slope_degrees_at(here)
            var hand := df.hand_m(here)
            var z0 := _ground(df, hf, px, py, slope_deg, hand)
            var zp := _ground(df, hf, px + dx, py + dy, slope_deg, hand)
            var zm := _ground(df, hf, px - dx, py - dy, slope_deg, hand)
            if not (is_finite(z0) and is_finite(zp) and is_finite(zm)):
                return
            vals.append(absf(zp - 2.0 * z0 + zm))
            # THE MEMBERSHIP AT THE CENTRE OF THE STENCIL, which is where the
            # sample is. A pair straddling a membership boundary contributes to
            # both bands in the proportion the middle of it sits in, which is
            # the continuous reading of "a window contributes to each landform's
            # band with its membership weight".
            var w := df.weights_for(slope_deg, hand)
            for name in strata:
                var arr: PackedFloat64Array = wts[str(name)]
                arr.append(float(w.get(str(name), 0.0)))
                wts[str(name)] = arr


## The drawn ground: the parent lattice plus the conditioned detail term.
static func _ground(df: DetailField, hf: Heightfield, x: float, y: float,
                    slope_deg: float, hand: float) -> float:
    var base := hf.height_at_world(x, y)
    if is_nan(base):
        return NAN
    return base + df.detail_at64(x, y, slope_deg, hand)


## How much of the second difference the PARENT carries at each lag, as a share.
##
## Measured rather than assumed, because the claim "the parent is smooth at
## these lags so grading the detail term alone would do" is exactly the kind of
## thing that is true until the lag range moves. If this ever approaches 1 the
## grade is reading the terrain the lattice already carries, which is the
## premise §23.999 used to refuse fork (c).
static func parent_share(df: DetailField, hf: Heightfield, centre: Vector2, span: float,
                         lags: Array, samples: int = 400, seed: int = 0) -> Dictionary:
    var out := {}
    var half := span * 0.5
    for raw in lags:
        var lag := float(raw)
        var reach := 2.0 * lag * sqrt(2.0)
        if reach >= span:
            out[lag] = null
            continue
        var salt := StableHash.of_name("parent|%s" % String.num(lag, 6))
        var whole := PackedFloat64Array()
        var bare := PackedFloat64Array()
        var unit := PackedFloat64Array()
        for i in samples:
            var u := StableHash.unit(StableHash.of5(seed, salt, 0, i, 0))
            var v := StableHash.unit(StableHash.of5(seed, salt, 1, i, 0))
            var th := PI * StableHash.unit(StableHash.of5(seed, salt, 2, i, 0))
            var px := centre.x - half + reach + u * (span - 2.0 * reach)
            var py := centre.y - half + reach + v * (span - 2.0 * reach)
            var dx := cos(th) * lag
            var dy := sin(th) * lag
            var here := Vector2(px, py)
            var sd := df.slope_degrees_at(here)
            var hd := df.hand_m(here)
            var p0 := hf.height_at_world(px, py)
            var pp := hf.height_at_world(px + dx, py + dy)
            var pm := hf.height_at_world(px - dx, py - dy)
            if not (is_finite(p0) and is_finite(pp) and is_finite(pm)):
                continue
            var d0 := df.detail_at64(px, py, sd, hd)
            var dp := df.detail_at64(px + dx, py + dy, sd, hd)
            var dm := df.detail_at64(px - dx, py - dy, sd, hd)
            bare.append(absf(pp - 2.0 * p0 + pm))
            whole.append(absf((pp + dp) - 2.0 * (p0 + d0) + (pm + dm)))
            unit.append(1.0)
        if whole.is_empty():
            out[lag] = null
            continue
        var w := weighted_quantile(whole, unit, 0.5)
        var b := weighted_quantile(bare, unit, 0.5)
        out[lag] = 0.0 if w <= 0.0 else b / w
    return out


## Convention 6's second clause: do the strata tell each other apart?
##
## A synthesiser whose playa and talus agree passes every per-stratum band and
## fails the criterion, which is why this is a separate question and not a
## consequence of the first. Reported as the ratio between the loudest and
## quietest stratum at each lag, and the pair it came from -- a number with no
## names attached would say that something spreads without saying what.
static func spread(measured: Dictionary, lags: Array) -> Dictionary:
    var strata: Dictionary = measured.get("strata", {})
    var out := {}
    for raw in lags:
        var lag := float(raw)
        var lo := INF
        var hi := 0.0
        var lo_name := ""
        var hi_name := ""
        for name in strata:
            var s = (strata[name] as Dictionary).get(lag, null)
            if s == null or float(s) <= 0.0:
                continue
            if float(s) < lo:
                lo = float(s)
                lo_name = str(name)
            if float(s) > hi:
                hi = float(s)
                hi_name = str(name)
        out[lag] = (null if lo_name == "" or hi_name == "" or lo_name == hi_name
                else {"ratio": hi / lo, "loudest": hi_name, "quietest": lo_name})
    return out


## WHETHER THE TWO CLAUSES CAN BE GRADED AT ALL, AND IF NOT, WHICH THING IS
## MISSING.
##
## A MISSING BAND AND A MISSING MEASUREMENT BOTH MEAN NOT GRADEABLE, AND
## NEITHER MEANS FAILED. An earlier cut of this returned `ok: false` for a
## stratum with no published band, which the gate reads as UNMET -- a claim
## that the ground is wrong on the strength of nobody having measured it. 1019
## says a landform without coverage gets a REFUSED band and not a tolerance of
## zero, and a refusal has to travel as a refusal the whole way to the gate.
##
## AND THE TWO REFUSALS ARE NOT THE SAME REFUSAL, which is why this exists
## separately from `evidence` returning an empty dictionary. "The bands are not
## published" is waiting on the producing side; "this window set does not cover
## the stratum" is waiting on window sourcing, and is a thing the caller could
## act on. Reporting one word for both would hide the half that is actionable.
static func gradeable(measured: Dictionary, bands: Dictionary = {}) -> Dictionary:
    if not bool(measured.get("ok", false)):
        return {"ok": false, "why": str(measured.get("why", NO_LAYERS))}
    var strata: Dictionary = measured.get("strata", {})
    if strata.is_empty():
        return {"ok": false, "why": NO_COVERAGE}
    var uncovered := PackedStringArray()
    var unbanded := PackedStringArray()
    for name in strata:
        var entry: Dictionary = strata[name]
        var measured_lags := 0
        for lag in entry:
            if typeof(lag) == TYPE_FLOAT and entry[lag] != null:
                measured_lags += 1
        if measured_lags == 0:
            uncovered.append(str(name))
        elif (bands.get(str(name), {}) as Dictionary).is_empty():
            unbanded.append(str(name))
    if not uncovered.is_empty():
        return {"ok": false, "why": "%s: %s" % [NO_COVERAGE, str(uncovered)],
                "uncovered": uncovered}
    if not unbanded.is_empty():
        return {"ok": false, "why": "%s: %s" % [NO_BANDS, str(unbanded)],
                "unbanded": unbanded}
    return {"ok": true, "why": ""}


## The evidence `DebugPlayer.walk_available` consumes for 986's second and third
## conditions.
##
## BOTH STAY UNGRADED WHILE NO BANDS ARE PUBLISHED, and that is the honest
## answer rather than a held opinion: a measurement with nothing to measure
## against is a number, not a verdict. When the bands land this returns `ok`
## against them and nothing else here changes.
static func evidence(measured: Dictionary, spread_by_lag: Dictionary,
                     bands: Dictionary = {}) -> Dictionary:
    if not bool(measured.get("ok", false)):
        return {}
    var strata: Dictionary = measured.get("strata", {})
    if not bool(gradeable(measured, bands)["ok"]):
        return {}
    var band_ok := true
    var why := PackedStringArray()
    for name in strata:
        var band: Dictionary = bands[str(name)]
        var entry2: Dictionary = strata[name]
        for lag in entry2:
            if typeof(lag) != TYPE_FLOAT or entry2[lag] == null:
                continue
            var b: Array = band.get(lag, [])
            if b.size() != 2:
                continue
            var sv := float(entry2[lag])
            if sv < float(b[0]) or sv > float(b[1]):
                band_ok = false
                why.append("%s at %s m: %s outside [%s, %s]"
                        % [str(name), String.num(float(lag), 1), String.num(sv, 4),
                                String.num(float(b[0]), 4), String.num(float(b[1]), 4)])
    var spread_ok := true
    var seen := 0
    for lag in spread_by_lag:
        if spread_by_lag[lag] == null:
            continue
        seen += 1
        if float((spread_by_lag[lag] as Dictionary)["ratio"]) < float(bands.get("_min_spread", 2.0)):
            spread_ok = false
    if seen == 0:
        # Convention 6's second clause cannot be answered from one stratum, and
        # answering it anyway is the failure mode the clause exists to catch.
        return {}
    return {
        "bands": {"ok": band_ok, "why": " / ".join(why), "strata": strata.keys()},
        "spread": {"ok": spread_ok, "why": JSON.stringify(spread_by_lag)},
    }
