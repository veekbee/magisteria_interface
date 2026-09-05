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
## THE SHAPE THIS READER ACCEPTS, stated here so that the side which emits it
## has something to match rather than something to guess:
##
##     "run": {
##       "base_commit": "6421064...",
##       "acceptance": {
##         "scored_at_commit": "5317027...",
##         "scored_run_dir": "runs/m0-instrumented-001",
##         "passed": 7, "failed": 5, "not_evaluable": 0,
##         "failed_criteria": [{"id": 1, "name": "...", "renders_as": "..."}],
##         "equivalence": {                     // only when the two differ
##           "to_commit": "6421064...",
##           "fields_compared": 18, "fields_matching": 18,
##           "fields_excluded": [{"field": "outlet_q", "why": "a deliberate gauge change"}]
##         }
##       }
##     }
##
## `ticks`, `state_arrays_identical` and `to_run` are read when present and are
## not required: they enlarge the proof rather than constitute it. The three
## fields that DO constitute it are `to_commit` and the two field counts.
##
## `scored_at_commit` IS THE RUN'S STAMP, not the commit the score artefact came
## to rest at. Only a run stamp is comparable to `run.base_commit`, which is the
## other side of every comparison here; a score-artefact commit would be
## compared against a run stamp and would read as stale forever. This header
## carried the wrong one of the two until the first real verdict was emitted.
##
## `scored_run_dir` and `scored_on_run` are both accepted, because this header
## declared the second and the emitter wrote the first, and refusing a proof
## that checks out over the name of a label neither side reads would be the
## wrong place to be strict. Named here so the two can converge rather than
## drift quietly.
##
## `failed_criteria` may be a list of plain ids; the names are what make the
## banner say something, and their absence is reported rather than filled in.
##
## WHY THERE IS A FOURTH STATE, AND WHY IT IS NOT A FLAG. Commit equality was
## only ever a PROXY for the question that matters, which is whether the
## verdict describes the trajectory being drawn. The first verdict this reader
## will meet breaks the proxy honestly: it was scored on a different run at a
## different commit, and that run's trajectory was proven identical to this
## fixture's field by field. Three states cannot say that -- SCORED would hide
## that a different run was scored, STALE would throw away a proof -- so there
## is a fourth, and it is keyed on the PROOF rather than on a claim.
##
## `equivalence` is therefore checked, not believed. A `same_trajectory: true`
## would be a field any future fixture could assert its way past; a comparison
## with a denominator cannot be. If the block is present and does not check
## out, the state is STALE and the banner says the proof failed -- which is
## louder than a plain STALE, because a broken proof is worse than none.

## What the manifest turned out to carry. The middle two are the whole reason
## this class exists: a verdict scored against a different run is not
## automatically a verdict of this fixture, and it is not automatically NOT one
## either.
const ABSENT := "absent"
const STALE := "stale"
const EQUIVALENT := "equivalent"
const SCORED := "scored"

var state: String = ABSENT
var why: String = ""

var passed: int = -1
var failed: int = -1
var not_evaluable: int = -1
var scored_at_commit: String = ""
var scored_on_run: String = ""
var base_commit: String = ""
var failed_criteria: Array = []
var equivalence: Dictionary = {}


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
    v.scored_on_run = str(acc.get("scored_run_dir", acc.get("scored_on_run", "")))
    v.failed_criteria = acc.get("failed_criteria", [])
    if typeof(acc.get("equivalence", null)) == TYPE_DICTIONARY:
        v.equivalence = acc["equivalence"]
    if v.passed < 0 or v.failed < 0:
        v.state = ABSENT
        v.why = "an acceptance block is present and carries no pass/fail count"
        return v
    # Prefix comparison, because one side abbreviates and the other does not.
    # Equal-length-only would report every short-hashed verdict as stale, which
    # trains a reader to ignore the word.
    if _same_commit(v.scored_at_commit, v.base_commit):
        v.state = SCORED
        return v
    if v.equivalence.is_empty():
        v.state = STALE
        v.why = ("scored at %s, and this fixture was cut at %s with nothing offered to connect "
                + "them: the verdict is of a different run and does not describe what is drawn"
                ) % [_short(v.scored_at_commit), _short(v.base_commit)]
        return v
    var checked := v._check_equivalence()
    if checked != "":
        v.state = STALE
        v.why = ("scored at %s against a fixture cut at %s, with an equivalence claim that does "
                + "not check out: %s") % [_short(v.scored_at_commit), _short(v.base_commit),
                                          checked]
        return v
    v.state = EQUIVALENT
    return v


## Does the offered proof prove what it claims? Returns "" when it does, and
## what failed when it does not.
##
## THE DENOMINATORS ARE THE POINT. A count of matching fields with no count of
## compared fields is a number that gets larger as the comparison gets weaker.
## An excluded field with no reason is a field the proof stepped around.
func _check_equivalence() -> String:
    var to_commit := str(equivalence.get("to_commit", ""))
    if not _same_commit(to_commit, base_commit):
        return ("it proves equivalence to %s, and this fixture was cut at %s"
                % [_short(to_commit), _short(base_commit)])
    var compared := int(equivalence.get("fields_compared", 0))
    var matching := int(equivalence.get("fields_matching", -1))
    if compared <= 0:
        return "it compares no fields at all"
    if matching != compared:
        return "%d of %d compared fields matched, which is not identity" % [matching, compared]
    var excluded = equivalence.get("fields_excluded", [])
    if typeof(excluded) != TYPE_ARRAY:
        return "its excluded-field list is not a list"
    for e in excluded:
        if typeof(e) != TYPE_DICTIONARY:
            return "a field was excluded from the comparison without a reason"
        var d: Dictionary = e
        if str(d.get("field", "")).is_empty() or str(d.get("why", "")).is_empty():
            return ("a field was excluded from the comparison without naming itself or its "
                    + "reason, so the proof cannot be read")
    return ""


static func _same_commit(a: String, b: String) -> bool:
    if a.is_empty() or b.is_empty():
        return false
    var n: int = mini(a.length(), b.length())
    return n >= 7 and a.substr(0, n) == b.substr(0, n)


static func _short(c: String) -> String:
    return "(none)" if c.is_empty() else c.substr(0, mini(12, c.length()))


func _score() -> String:
    return "%d pass / %d fail%s" % [passed, failed,
            "" if not_evaluable <= 0 else " / %d not evaluable" % not_evaluable]


## The one line a screenshot has to carry. Never empty: an absent verdict is a
## sentence, because a blank space beside a picture reads as nothing to declare.
func headline() -> String:
    match state:
        SCORED:
            return "ancestor trace — acceptance %s, scored at %s" % [
                    _score(), _short(scored_at_commit)]
        EQUIVALENT:
            # The different run is named rather than smoothed over. A reader who
            # is told only "7 pass / 5 fail" cannot ask the next question.
            return ("ancestor trace — acceptance %s, scored at %s on %s: a different run, "
                    + "proven identical to this one (%s)") % [
                    _score(), _short(scored_at_commit),
                    "another run" if scored_on_run.is_empty() else scored_on_run, _proof()]
        STALE:
            return "ancestor trace — VERDICT DOES NOT MATCH THIS FIXTURE: " + why
        _:
            return "ancestor trace — NO ACCEPTANCE VERDICT: " + why


## The proof in one clause, including what it left out. An equivalence that
## excluded fields is weaker than one that excluded none, and the banner is the
## wrong place to be tactful about which this is.
func _proof() -> String:
    var parts := PackedStringArray()
    parts.append("%d/%d fields" % [int(equivalence.get("fields_matching", 0)),
                                   int(equivalence.get("fields_compared", 0))])
    if int(equivalence.get("state_arrays_identical", 0)) > 0:
        parts.append("%d state arrays" % int(equivalence.get("state_arrays_identical", 0)))
    if int(equivalence.get("ticks", 0)) > 0:
        parts.append("%d ticks" % int(equivalence.get("ticks", 0)))
    var excluded: Array = equivalence.get("fields_excluded", [])
    if not excluded.is_empty():
        parts.append("%d field%s excluded" % [excluded.size(),
                "" if excluded.size() == 1 else "s"])
    return ", ".join(parts)


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


## What the equivalence proof left out, for a reader who wants the caveat
## rather than the count of it.
func excluded_fields() -> PackedStringArray:
    # FIELDS THAT SHARE A REASON ARE NAMED TOGETHER. The shipped fixture
    # excludes three fields for one gauge change and repeats the same forty
    # words for each, which filled a third of the banner with two copies of
    # nothing and pushed the fifth named fail off the bottom of an 800 px
    # window -- photographed, not supposed. Grouping is shorter and says the
    # truer thing: one instrument change moved all three, and a reader counting
    # distinct reasons is counting what actually happened to the proof.
    var by_reason := {}
    var order: Array = []
    for e in equivalence.get("fields_excluded", []):
        if typeof(e) != TYPE_DICTIONARY:
            continue
        var d: Dictionary = e
        var why := str(d.get("why", "?"))
        if not by_reason.has(why):
            by_reason[why] = []
            order.append(why)
        (by_reason[why] as Array).append(str(d.get("field", "?")))
    var out := PackedStringArray()
    for why in order:
        out.append("%s — %s" % [", ".join(PackedStringArray(by_reason[why] as Array)), why])
    return out
