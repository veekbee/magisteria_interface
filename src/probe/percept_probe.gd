class_name PerceptProbe
extends RefCounted

## `probe.percept`: which term decides how finely one thing is drawn.
##
## THE SHAPE IS §19.8.3'S `min()` AND THE FORMAT IS TWO COLUMNS -- earned and
## affordable -- with the drawn depth as the smaller of them and the binding
## term named. Two columns rather than one ladder because taxonomic depth and
## attribute confidence decouple: a thing can be known to be a specific taxon
## and known imprecisely, or placed only at its life form and measured well.
## A single number would re-conflate them.
##
## THE EARNED COLUMN READS "no B: fixture is truth" AND THAT IS THE POINT.
## There is no producer earning anything yet -- the fixture is the whole world
## at full precision, which is the state a privilege leak looks exactly like.
## Faking a number there would make this instrument useless on the day it
## matters; omitting the column would make the omission invisible. So it is
## printed, honestly empty, and the day a real producer withholds something the
## change shows up in that column and nowhere else.
##
## `NO_ASSET` IS NEVER A `min()` TERM. The asset lookup is required to be the
## identity -- every internal node of the taxonomy has a representative form --
## so a missing asset is ART DEBT and not a smaller percept. Folding it into
## the min() would quietly convert a modelling gap into a design claim about
## what an observer earns, which is exactly the confusion the two columns exist
## to prevent.

## Why the drawn depth is what it is. The vocabulary is fixed here so a reader
## meets the same four words wherever the question is asked.
const NOT_EARNED := "NOT_EARNED"          ## design: the observer has not earned it
const NOT_SENT := "NOT_SENT"              ## wire: earned and withheld. Live only.
const NOT_AFFORDABLE := "NOT_AFFORDABLE"  ## budget: tunable, and this client's own doing
const NO_ASSET := "NO_ASSET"              ## art debt. Printed, never a min() term.

## The rungs this client can draw, coarse to fine. Today it draws every plant
## at `life_form` -- four family archetypes, no species assets -- which is a
## valid transducer for "everything is earned at the life-form rung" and is
## why a mock producer costs nothing to try.
const RUNGS := ["life_form", "functional", "specific"]


## One subject's percept, as the probe prints it.
##
## `earned_rung` is null wherever no producer earns anything, and the caller is
## expected to print the placeholder rather than substitute a number.
##
## `rendered_rung` is what this client actually puts on screen, and it is NOT a
## term. It is reported beside the min() so the two can be seen to disagree --
## which today they do, everywhere, because there are no specific-rung assets.
## That disagreement is art debt, and calling it anything else would turn a
## modelling gap into a claim about what an observer earned.
static func evaluate(affordable_rung: String, earned_rung: Variant,
                     has_asset: bool, rendered_rung: String = "") -> Dictionary:
    var affordable_i := RUNGS.find(affordable_rung)
    var earned_i := -1
    var earned_text := "no B: fixture is truth"
    if typeof(earned_rung) == TYPE_STRING and RUNGS.has(str(earned_rung)):
        earned_i = RUNGS.find(str(earned_rung))
        earned_text = str(earned_rung)

    # THE min() OVER THE TERMS THAT ARE TERMS. An absent earned column does not
    # bind: it is unknown, not zero, and treating it as zero would report every
    # subject as un-earned the moment a producer went quiet -- which is exactly
    # the state this instrument has to be able to tell apart from a real one.
    var bound := affordable_i
    var binding := NOT_AFFORDABLE
    if earned_i >= 0 and earned_i < affordable_i:
        bound = earned_i
        binding = NOT_EARNED
    var drawn: String = RUNGS[bound] if bound >= 0 and bound < RUNGS.size() else affordable_rung

    var out := {
        "earned": earned_text,
        "earned_is_placeholder": earned_i < 0,
        "affordable": affordable_rung,
        "drawn": drawn,
        "binding_term": binding,
        "rendered": rendered_rung,
        "art_debt": false,
    }
    var rendered_i := RUNGS.find(rendered_rung)
    if not has_asset or (rendered_i >= 0 and rendered_i < bound):
        # SAID SEPARATELY AND NEVER FOLDED IN. The asset lookup is required to
        # be the identity -- every internal node has a representative form --
        # so this is a gap in the models rather than a smaller percept.
        out["art_debt"] = true
        out["art_debt_note"] = ("ART DEBT (%s): the min() allows %s and this client draws %s. "
                % [NO_ASSET, drawn, rendered_rung if rendered_rung != "" else "nothing"]
                + "The asset lookup is required to be the identity, so this is a missing model "
                + "and not a claim about what the observer earned.")
    return out


## The lines the console prints. Kept here so the interactive format and any
## headless assertion read the same text.
static func lines(percept: Dictionary) -> PackedStringArray:
    var out := PackedStringArray()
    out.append("  earned     | %s%s" % [str(percept["earned"]),
            "   <- placeholder, not a measurement" if bool(percept["earned_is_placeholder"])
                    else ""])
    out.append("  affordable | %s" % str(percept["affordable"]))
    out.append("  drawn      = %s   (%s)" % [str(percept["drawn"]), str(percept["binding_term"])])
    if str(percept.get("rendered", "")) != "":
        out.append("  rendered   | %s   <- what is on screen, which is not a min() term"
                % str(percept["rendered"]))
    if bool(percept.get("art_debt", false)):
        out.append("  " + str(percept.get("art_debt_note", "ART DEBT")))
    return out
