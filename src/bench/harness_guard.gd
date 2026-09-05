class_name HarnessGuard
extends RefCounted

## The two ways a windowed harness in this project has actually produced a
## complete, plausible, WRONG artefact. Both are refusable, and neither was
## refused until it had happened.
##
## ONE: A CAPTURE THAT DID NOT MOVE. On this platform a window that loses focus
## or is occluded stops being drawn while the main loop keeps ticking, so
## `get_texture().get_image()` goes on returning the last frame that was
## rendered. `measure_motion` lost two complete runs to it: every candidate
## after the freeze scored ONE frozen image against each position's own mask,
## which gives DIFFERENT numbers per position and IDENTICAL ones between
## candidates -- a table that reads as a result and is one photograph. It was
## found by noticing three saved PNGs from three different candidates were
## byte-identical, not by reading the numbers.
##
## TWO: TWO THINGS THAT MUST DIFFER, COMING OUT THE SAME. `measure_seam`'s
## per-family oracles were each built with `only` set, and then the harness
## showed every vegetation node before photographing -- so each "family"
## reference was the same frame with the previous build's instances still in
## it. Again complete and plausible: every score finite, every row in the right
## annulus, a trend that looked like a finding. The tell was three DIFFERENT
## family references reporting the same mean colour to three decimals.
##
## Both tells are one shape: things that cannot be equal came out equal. That
## is an invariant, not a judgement, so it belongs in code.
##
## THREE: A STAGE MACHINE THAT STOPS ADVANCING. A harness whose stage never
## changes sits in its main loop at 1% CPU forever, which looks exactly like a
## slow render. `measure_motion` did it for twenty minutes twice, from a null
## reference that errored inside a stage transition; the throwaway probe that
## did the same ran for THIRTEEN HOURS at 99% of a core before it was noticed,
## and every measurement taken beside it was competing with it. A harness that
## cannot fail is a harness that can hang.

## Frames a stage may sit in before it is called stalled. Generous: a scatter
## build of a few million instances legitimately blocks the loop for seconds,
## and this is meant to catch a machine that has STOPPED, not one that is busy.
const STALL_FRAMES := 3000


## "" when the stage is still moving, or the refusal to print and quit on.
static func stall_note(what: String, frames_in_stage: int,
                       limit: int = STALL_FRAMES) -> String:
    if frames_in_stage < limit:
        return ""
    return ("stalled in '%s' for %d frames with nothing advancing. A stage that stops "
            % [what, frames_in_stage]
            + "changing does not error and does not exit -- it ticks at 1%% CPU and looks "
            + "like a slow render, which is how twenty minutes and then thirteen hours went "
            + "missing. Something before this point failed without saying so.")


## "" when the capture is new, or the refusal when it is the previous frame
## again. `moved` says whether anything in the scene was supposed to change:
## two identical frames are a defect only when something should have differed.
static func capture_note(previous: PackedByteArray, current: PackedByteArray,
                         what: String, moved: bool = true) -> String:
    if not moved or previous.is_empty() or current != previous:
        return ""
    return ("the frame captured for %s is byte-identical to the one before it, and the "
            % what + "scene moved between them -- so the window has stopped being drawn and "
            + "every number after this point is one frozen image scored against a moving "
            + "measurement. Keep the window on screen and in front for the whole run.")


## "" when `key` is new, or the refusal naming both sides of the collision.
##
## `seen` is carried by the caller and mutated here: key -> the label that
## claimed it first. Feed it a signature of whatever must be distinct -- a mean
## colour to three decimals, a pixel count, a hash -- and it says which two
## claimed the same one.
static func distinctness_note(seen: Dictionary, key: String, label: String,
                              what: String) -> String:
    if key.is_empty():
        return ""
    if seen.has(key):
        return ("%s and %s both came out at %s, and %s. Two of them are the same "
                % [str(seen[key]), label, key, what]
                + "measurement wearing different names.")
    seen[key] = label
    return ""


## A signature for a mean colour, at the precision a collision is real at.
## Three decimals: two renders of different things do not agree that far by
## chance, and two renders of the same thing agree exactly.
static func colour_key(mean_colour: Array) -> String:
    if mean_colour.size() < 3:
        return ""
    return "%s|%s|%s" % [String.num(float(mean_colour[0]), 3),
            String.num(float(mean_colour[1]), 3), String.num(float(mean_colour[2]), 3)]
