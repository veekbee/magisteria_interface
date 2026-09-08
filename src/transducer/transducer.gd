class_name Transducer
extends RefCounted

## THE BOUNDARY. Everything under `src/transducer/` consumes a `PerceptBundle`
## and reads no artefact behind one.
##
## WHY THERE IS A DIRECTORY AND NOT A LIST. The guard this boundary exists for
## is a dependency scan, and a scan needs to be able to say what it scanned. A
## list of files rots the first time someone adds one; a path is a predicate,
## and a file is inside the boundary or it is not. So membership is where the
## file lives, and moving a file in is the whole of the decision to hold it to
## the rule.
##
## WHAT THE RULE ACTUALLY FORBIDS. Not the fixture -- the fixture is fine, it
## is what the client has today. What it forbids is a consumer reaching PAST a
## bundle for the file underneath, because that is the reach that silently
## survives the day the bundle stops carrying everything. A transducer that can
## fall back to the truth is not a transducer, and the failure is invisible:
## every pixel is right, and stays right until a real producer withholds
## something and the fallback quietly supplies it anyway.
##
## WHAT IS INSIDE IT TODAY, AND WHAT IS NOT.
##
##   Inside: the channel-1 ground paint. `FieldOverlay` binds its pixel-to-cell
##   join to a bundle's key axis and paints rows out of bundles.
##
##   Outside, with reasons rather than by omission -- the reasons are the
##   finding, and each is a producer-side question this repo must not answer
##   alone:
##
##     the far-field tint reads a cell's WHOLE YEAR to place one day in its
##     seasonal range. A bundle is one moment. Either seasonal position is a
##     carried row -- how far through its year this ground looks, which is a
##     thing an observer could plausibly see -- or the tint is asking for
##     something nobody perceives.
##
##     the vegetation scatter reads the same year through the tint's rule, and
##     additionally reads the fixture manifest for its quantisation bounds.
##
##     the flow drape reads `node.streamflow`, which is indexed by river node
##     and not by residence key, so channel 1 as it stands has nowhere to put
##     it.
##
##     the dev UI -- the scrubber, the series plot, the probe panel -- reads
##     the artefact ON PURPOSE and is not transducer code. `CellProbe` is the
##     same: a development view of data the client holds whole, exempt by
##     context, and never a template for anything a player sees.
##
## A BOUNDARY WITH ONE FILE INSIDE IT IS NOT A BOUNDARY, and the gate's scan is
## written so that it says so: it fails on an empty subtree rather than passing
## over nothing, and it is checked against a synthetic violation so that a scan
## which has stopped being able to see one cannot report green.

## The subtree, as a path. The gate's scan reads this rather than a literal.
const SUBTREE := "res://src/transducer/"

## Files here that are the boundary's own declaration rather than consumers of
## the bundle. Exactly this file: it names the rule and enforces none of it.
const NOT_A_CONSUMER := ["transducer.gd"]


## Every GDScript in the subtree, by resource path.
static func scripts() -> PackedStringArray:
    var out := PackedStringArray()
    var d := DirAccess.open(SUBTREE)
    if d == null:
        return out
    for f in d.get_files():
        if f.ends_with(".gd"):
            out.append(SUBTREE + f)
    out.sort()
    return out
