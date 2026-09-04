class_name AncestorVerdict
extends RefCounted

## How the run behind this fixture scored against its acceptance criteria, so
## that a picture of it carries its own disclaimer.
##
## WHY A PICTURE NEEDS ONE. The basin on screen is an ancestor trace, and it
## fails several of the criteria the simulation is eventually held to -- a
## near-bare snowpack, a melt peak in the wrong season, a burned fraction two
## orders under the floor its window was chosen by. Every one of those renders
## as something: a screenshot of them is a screenshot of a defect, and a
## screenshot with no verdict on it is the one that gets quoted later as a
## picture of the model working.
##
## READ, NEVER TYPED. The verdict belongs to a run and moves when the run
## moves; a count written into a scene is wrong from the first revision that
## fixes one of the criteria, and wrong SILENTLY, because nothing downstream
## can tell an out-of-date constant from a current measurement. So this reads a
## field, and when the field is not there it says the fixture carries no
## verdict rather than supplying one.
##
## THE FIELD IS NOT ON THE WIRE YET. Today's manifests carry `run` with `dir`,
## `base_commit`, `master_seed`, `baseline_period` and `years`, and no verdict
## of any kind, so every fixture in this repo reads as ABSENT. The shape below
## is what this reader accepts, stated here so that the side which emits it has
## something to match rather than something to guess:
##
##     "run": {
##       "base_commit": "...",
##       "acceptance": {
##         "scored_at_commit": "897285d...",
##         "passed": 7, "failed": 5, "not_evaluable": 0,
##         "failed_criteria": [{"id": 1, "name": "...", "renders_as": "..."}]
##       }
##     }
##
## `failed_criteria` may be a list of plain ids; the names are what make the
## banner say something, and their absence is reported rather than filled in.

## What the manifest turned out to carry. Three states, and the middle one is
## the whole reason this class exists: a verdict scored against a DIFFERENT
## commit than the fixture was cut at is not a verdict of this fixture, and it
## is the failure mode that a bare pass/fail count cannot show.
const ABSENT := "absent"
const STALE := "stale"
const SCORED := "scored"

var state: String = ABSENT
var why: String = ""

var passed: int = -1
var failed: int = -1
var not_evaluable: int = -1
var scored_at_commit: String = ""
var base_commit: String = ""
var failed_criteria: Array = []


static func read_from(manifest: Dictionary) -> AncestorVerdict:
    var v := AncestorVerdict.new()
    var run: Dictionary = manifest.get("run", {})
    v.base_commit = str(run.get("base_commit", ""))
    var a = run.get("acceptance", null)
    if typeof(a) != TYPE_DICTIONARY:
        v.state = ABSENT
        v.why = ("this fixture's manifest carries no acceptance verdict, so nothing on screen "
                + "is disclaimed by one")
        return v
    var acc: Dictionary = a
    v.passed = int(acc.get("passed", -1))
    v.failed = int(acc.get("failed", -1))
    v.not_evaluable = int(acc.get("not_evaluable", -1))
    v.scored_at_commit = str(acc.get("scored_at_commit", ""))
    v.failed_criteria = acc.get("failed_criteria", [])
    if v.passed < 0 or v.failed < 0:
        v.state = ABSENT
        v.why = "an acceptance block is present and carries no pass/fail count"
        return v
    # Prefix comparison, because one side abbreviates and the other does not.
    # Equal-length-only would report every short-hashed verdict as stale, which
    # trains a reader to ignore the word.
    if not _same_commit(v.scored_at_commit, v.base_commit):
        v.state = STALE
        v.why = ("scored at %s, but this fixture was cut at %s: the verdict is of a different "
                + "run and does not describe what is drawn") % [
                _short(v.scored_at_commit), _short(v.base_commit)]
        return v
    v.state = SCORED
    return v


static func _same_commit(a: String, b: String) -> bool:
    if a.is_empty() or b.is_empty():
        return false
    var n: int = mini(a.length(), b.length())
    return n >= 7 and a.substr(0, n) == b.substr(0, n)


static func _short(c: String) -> String:
    return "(none)" if c.is_empty() else c.substr(0, mini(12, c.length()))


## The one line a screenshot has to carry. Never empty: an absent verdict is a
## sentence, because a blank space beside a picture reads as nothing to declare.
func headline() -> String:
    match state:
        SCORED:
            return "ancestor trace — acceptance %d pass / %d fail%s, scored at %s" % [
                    passed, failed,
                    "" if not_evaluable <= 0 else " / %d not evaluable" % not_evaluable,
                    _short(scored_at_commit)]
        STALE:
            return "ancestor trace — VERDICT DOES NOT MATCH THIS FIXTURE: " + why
        _:
            return "ancestor trace — NO ACCEPTANCE VERDICT: " + why


## The named fails, which are the half that says how a failure looks on screen.
func named_fails() -> PackedStringArray:
    var out := PackedStringArray()
    for c in failed_criteria:
        if typeof(c) == TYPE_DICTIONARY:
            var d: Dictionary = c
            var s := "criterion %s" % str(d.get("id", "?"))
            if d.has("name"):
                s += " (%s)" % str(d["name"])
            if d.has("renders_as"):
                s += " — renders as %s" % str(d["renders_as"])
            out.append(s)
        else:
            out.append("criterion %s — unnamed in the manifest, so how it renders is not said"
                    % str(c))
    return out
