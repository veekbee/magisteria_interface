class_name ProvenanceClaim
extends RefCounted

## WHAT THE FIXTURE SAYS ABOUT ITSELF, read rather than assumed.
##
## The manifest has always carried a per-window provenance block -- which water
## year, which day the window opens on, why it was chosen, what the replay
## restored and what it seeded, how much of it carries vegetation -- and until
## this class nothing in the client read ANY of it. Only the acceptance verdict
## had a reader.
##
## THE COST OF THAT WAS MEASURED, NOT SUPPOSED. For four months `restore_delta`
## declared that six of the fixture's arrays were a fresh build's seed rather
## than the run's state -- `band.phenology_index` among them, a row this client
## draws -- and no viewer was ever told. Nothing was concealed: the producing
## side published it, in the manifest this repo vendors, and this side had
## nowhere to put it. A second instance surfaced the same week: the two windows'
## `start_doy` values disagreed about their own convention, one calendar and one
## water-year, and the contradiction had shipped for months because no reader
## existed to be confused by it.
##
## ONE READER RATHER THAN A PATCH PER FIELD. Both of those would have been fixed
## by adding one line to one panel, and the next field to arrive unread would
## have needed another. What was missing was a place for the question "what does
## this artefact declare about itself, and what does it decline to say".
##
## THE RULE THIS CLASS EXISTS TO ENFORCE, and it is the one that cost a day:
## **an absent declaration is never a default, and a weight that is not real is
## never a weight.** `area_weighted_mean` returns NAN and a reason where the
## areas are missing or are a placeholder, and never silently falls back to an
## unweighted mean -- because an unweighted mean mistaken for a weighted one is
## exactly how two sides agreed on a wrong number to four decimal places.

## What the fixture says about its restore, which is a claim about whether the
## arrays drawn are the run's state at all.
const RESTORE_CLEAN := "clean"
const RESTORE_SEEDED := "seeded"
const RESTORE_UNDECLARED := "undeclared"

var restore_state: String = RESTORE_UNDECLARED
## Per window: the rows the replay seeded rather than restored. A row here is
## NOT this run's state, and one that is also carried is a row being drawn.
var seeded_by_window: Dictionary = {}
var windows: PackedStringArray = PackedStringArray()
var carried: PackedStringArray = PackedStringArray()

## `cell_areas_m2`, and whether its weights are the DEM's or a placeholder.
var areas: PackedFloat64Array = PackedFloat64Array()
var weights_are_real: bool = false
## Whether the block is THERE, which is a different question from whether its
## weights are real, and the two reach different surfaces. See `banner_lines`.
var areas_declared: bool = false
var areas_why_absent: String = ""

var _windows: Dictionary = {}


static func read_from(manifest: Dictionary) -> ProvenanceClaim:
    var p := ProvenanceClaim.new()
    p._windows = manifest.get("windows", {})
    for w in p._windows:
        p.windows.append(str(w))
    var cs: Dictionary = manifest.get("carried_set", {})
    for n in cs.get("names", []):
        p.carried.append(str(n))

    # THE RESTORE, AND ABSENT IS ITS OWN STATE. `null` is a fixture saying "the
    # restore was clean"; a missing key is a fixture that has not said. Those
    # are different claims and collapsing them would reproduce the four months.
    var seeded_anywhere := false
    for w in p._windows:
        var spec: Dictionary = p._windows[w]
        var replay: Dictionary = spec.get("replay", {})
        var seeded := PackedStringArray()
        for r in replay.get("seeded_not_restored", []):
            seeded.append(str(r))
        p.seeded_by_window[str(w)] = seeded
        if not seeded.is_empty():
            seeded_anywhere = true
    if not manifest.has("restore_delta"):
        p.restore_state = RESTORE_UNDECLARED
    elif seeded_anywhere or manifest.get("restore_delta") != null:
        p.restore_state = RESTORE_SEEDED
    else:
        p.restore_state = RESTORE_CLEAN

    var ca = manifest.get("cell_areas_m2", null)
    if typeof(ca) != TYPE_DICTIONARY:
        p.areas_why_absent = ("this fixture declares no `cell_areas_m2`, so no area-weighted "
                + "quantity can be computed from it")
    else:
        p.areas_declared = true
        var d: Dictionary = ca
        # THE FLAG IS READ BEFORE THE VALUES AND GATES THEM. The producing side
        # says a placeholder-weighted run is a DIFFERENT ARTEFACT from a
        # DEM-weighted one; taking the numbers and ignoring the flag would make
        # this client the place that erased that distinction.
        p.weights_are_real = bool(d.get("weights_are_real", false))
        if not p.weights_are_real:
            p.areas_why_absent = ("`cell_areas_m2.weights_are_real` is false: these are the "
                    + "equal-split placeholder, and a run weighted by it is a different "
                    + "artefact from one weighted by the DEM")
        else:
            for v in d.get("values", []):
                p.areas.append(float(v))
            if p.areas.is_empty():
                p.areas_why_absent = "`cell_areas_m2` declares real weights and carries no values"
    return p


## The area-weighted mean of a per-cell row, or NAN with a reason.
##
## NEVER AN UNWEIGHTED FALLBACK. This is the whole point of the class. An
## unweighted mean returned where a weighted one was asked for is a number that
## looks right, is close enough to be believed, and is a different statistic --
## which is how an area-weighted cover of 0.6103 and an unweighted count of
## 0.6105 were read as agreement for a day. If the weights are absent or a
## placeholder, the answer is NAN and `areas_why_absent` says why.
func area_weighted_mean(values: PackedFloat64Array) -> float:
    if areas.is_empty() or not weights_are_real:
        return NAN
    if values.size() != areas.size():
        return NAN
    var num := 0.0
    var den := 0.0
    for i in values.size():
        var v := values[i]
        if is_nan(v):
            continue
        num += v * areas[i]
        den += areas[i]
    return NAN if den <= 0.0 else num / den


## Everything the fixture declares about one window, for a reader who has the
## room. `{}` for a window the fixture does not carry.
func window_facts(window: String) -> Dictionary:
    if not _windows.has(window):
        return {}
    var s: Dictionary = _windows[window]
    var out := {}
    for k in ["water_year", "start_doy", "days", "note", "chosen_by"]:
        if s.has(k):
            out[k] = s[k]
    var density: Dictionary = s.get("density", {})
    if not density.is_empty():
        out["density"] = density
    return out


## THE LINES A CONSOLE PRINTS: everything, including the fields that are fine.
## A disclosure that only ever speaks when something is wrong cannot be
## distinguished from one that is not running.
func lines() -> PackedStringArray:
    var out := PackedStringArray()
    match restore_state:
        RESTORE_CLEAN:
            out.append("restore: clean -- every array is this run's state")
        RESTORE_SEEDED:
            out.append("restore: SEEDED -- " + _seeded_sentence())
        _:
            out.append("restore: NOT DECLARED -- this fixture does not say whether its arrays "
                    + "are the run's state or a fresh build's seed")
    for w in windows:
        var f := window_facts(w)
        if f.is_empty():
            continue
        var bits := PackedStringArray()
        if f.has("water_year"):
            bits.append("WY %d" % int(f["water_year"]))
        if f.has("days") and f.has("start_doy"):
            bits.append("%d days from doy %d" % [int(f["days"]), int(f["start_doy"])])
        elif not f.has("start_doy"):
            bits.append("no start_doy declared, so these days sit on no calendar")
        if f.has("note"):
            bits.append(str(f["note"]))
        var density: Dictionary = f.get("density", {})
        if density.has("vegetated_cells") and density.has("n_cells"):
            bits.append("%d of %d cells vegetated" % [int(density["vegetated_cells"]),
                                                      int(density["n_cells"])])
        else:
            bits.append("no vegetation density declared")
        out.append("window %s: %s" % [w, "; ".join(bits)])
    out.append("area weights: " + ("real, %d cells, basis declared" % areas.size()
            if weights_are_real and not areas.is_empty() else "UNUSABLE -- " + areas_why_absent))
    return out


## THE LINES A BANNER SHOWS, which are only the ones that disclaim the picture.
##
## A clean restore, a declared window and real weights say nothing here: the
## banner is 420 px of an 800 px window and it is already carrying an acceptance
## verdict, its staleness and four renderings. What reaches it is what a viewer
## would otherwise read the picture wrongly without.
func banner_lines() -> PackedStringArray:
    var out := PackedStringArray()
    if restore_state == RESTORE_SEEDED:
        out.append("restore: " + _seeded_sentence())
    elif restore_state == RESTORE_UNDECLARED:
        out.append("this fixture does not declare whether its arrays are the run's state "
                + "or a fresh build's seed")
    for w in windows:
        if not _windows.has(w):
            continue
        if not (_windows[w] as Dictionary).has("start_doy"):
            out.append("window %s declares no start day, so its time axis is uncalibrated" % w)
    # DECLARED-BUT-PLACEHOLDER REACHES THE BANNER AND ABSENT DOES NOT, and the
    # difference is deliberate rather than a convenience.
    #
    # This class's rule is that an absent declaration is never a DEFAULT --
    # honoured by `area_weighted_mean` returning NAN rather than an unweighted
    # number, and by `lines()` saying so every run. That is not the same as
    # every absence disclaiming the picture. A fixture carrying no
    # `cell_areas_m2` misrepresents nothing on screen; it makes one statistic
    # unavailable, and the console is where that belongs.
    #
    # A PLACEHOLDER IS A CLAIM ABOUT WHAT YOU ARE LOOKING AT. The producing
    # side's own field note says a run weighted by the equal-split is a
    # DIFFERENT ARTEFACT from one weighted by the DEM. A fixture that declares
    # weights and hands over the placeholder has said something about itself
    # that a reader of the picture needs, so it comes here.
    if areas_declared and not weights_are_real:
        out.append("area weights are a placeholder, not the DEM's: " + areas_why_absent)
    return out


## The seeded rows, with the ones a viewer may be DRAWING named first. A seeded
## row nobody can select is a fact about the build; a seeded row on screen is a
## fact about what they are looking at.
func _seeded_sentence() -> String:
    var drawn := PackedStringArray()
    var unseen := PackedStringArray()
    for w in seeded_by_window:
        for r in seeded_by_window[w] as PackedStringArray:
            if carried.has(r):
                if not drawn.has(r):
                    drawn.append(r)
            elif not unseen.has(r):
                unseen.append(r)
    if drawn.is_empty() and unseen.is_empty():
        return "the fixture declares a restore delta and names no rows for it"
    var parts := PackedStringArray()
    if not drawn.is_empty():
        parts.append("%s %s a fresh build's seed rather than this run's state, and %s drawn"
                % [", ".join(drawn), "is" if drawn.size() == 1 else "are",
                   "is" if drawn.size() == 1 else "are"])
    if not unseen.is_empty():
        parts.append("%s likewise, and not carried here" % ", ".join(unseen))
    return "; ".join(parts)
