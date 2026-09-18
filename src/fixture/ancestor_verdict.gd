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
## `ticks`, `to_run` and the state-array pair -- `state_arrays_compared` with
## `state_arrays_bit_identical` -- are read when present and are not required:
## they enlarge the proof rather than constitute it. The three fields that DO
## constitute it are `to_commit` and the two field counts.
##
## THE STATE-ARRAY PAIR IS NAMED HERE THE WAY THE EMITTER WRITES IT. This block
## asked for `state_arrays_identical`, a single count; the emitter has always
## written a count and a bool under different names, so that clause reached no
## viewer until the names were reconciled. A header that declares a shape
## nobody emits is a shape nobody emits.
##
## THE STATE AXIS IS THE RUN'S STAMP, not the commit the score artefact came to
## rest at. Only a run stamp is comparable to `run.base_commit`, which is the
## other side of every comparison here; a score-artefact commit would be
## compared against a run stamp and would read as stale forever. This header
## carried the wrong one of the two until the first real verdict was emitted.
##
## SO IT IS READ FROM `scored_run_stamp_commit` FIRST AND `scored_at_commit`
## ONLY AS A FALLBACK. The producing side is renaming it additively, because a
## cross-boundary rename is not settled until the far side has read it back --
## the new key and a deprecated alias ship together and the alias goes on this
## reader's word. Preferring the new name now means the alias can be dropped
## without a flag day, and until the next re-cut the fallback is the only key
## present, so this path is live rather than aspirational.
##
## AND THE NAME WAS WORTH MOVING. `scored_at_commit` names the axis it is not:
## computing `sim_changed_since_scoring` from it yields FIVE changed files where
## the derived list carries four, adding `sim/seeds.py`, which reads as the
## operator's declaration under-reporting in the most trajectory-relevant file
## in the set. This reader has carried the correcting sentence since it was
## written and its author still built most of that false alarm before reading
## the emitter. The name is also already taken by the OTHER axis in a sibling
## artefact of theirs, on a live pair of commits rather than in principle, which
## is what settled which side moves.
##
## `scoring_code_commit` -- the CODE axis, and what the drift list is derived
## from -- is read when present and is not compared to anything here. It is
## carried so a reader of this object can see both axes rather than reconstruct
## the second from prose.
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
##
## AND THERE IS A FIFTH, ON A DIFFERENT AXIS. `equivalence` proves that the
## verdict's run is this fixture's run, which is a statement about STATE. It
## says nothing about CODE, and the payload of a replayed fixture is stepped
## forward at whatever the engine is on the day of the replay. So a verdict can
## hold a clean 18-of-18 proof and still describe a snowpack the drawn data no
## longer has -- 17.4 mm against a payload whose mean is thirty-five times that
## -- with the proof entirely honest and the mismatch one key away, unread.
##
##     "stale_against_replay": {
##       "replayed_at_commit": "...",
##       "declared_by_the_operator": "why it is still the right verdict to ship",
##       "what_the_equivalence_proof_below_does_not_cover": "..."
##     }
##
## THE TWO AXES ARE NOT COLLAPSED. `state` becomes DECLARED_STALE, and
## `underlying_state` keeps whatever the state proof said, because "the state
## proof holds AND the code moved" is the whole content of this case and a
## single enum value cannot carry it. DECLARED_STALE reads louder than
## EQUIVALENT and quieter than a failed proof, which is the ordering the
## declaration deserves: the run really is this run, and the verdict really
## does not describe what is drawn.
##
## CHECKED, NOT BELIEVED, FOR THE SAME REASON THE PROOF IS. A declaration whose
## operator reason is missing is a declaration that says nothing, and a
## declaration whose replay commit is the commit it was scored at declares a
## drift that did not happen. Either way the block cannot be read, and an
## unreadable declaration of staleness is reported as plain STALE -- louder,
## because the fixture is asserting something about itself that does not hold
## together. The reason travelling with the number IS the declaration; without
## it there is nothing to show a person but a word.

## What the manifest turned out to carry. The middle two are the whole reason
## this class exists: a verdict scored against a different run is not
## automatically a verdict of this fixture, and it is not automatically NOT one
## either.
const ABSENT := "absent"
const STALE := "stale"
const EQUIVALENT := "equivalent"
const SCORED := "scored"
## The verdict's run is this fixture's run and its CODE is not: declared by the
## operator rather than detected here, and carrying the operator's reason.
const DECLARED_STALE := "declared_stale"

var state: String = ABSENT
var why: String = ""
## What the state axis said before the replay axis was applied. Equal to
## `state` except under DECLARED_STALE, where it is SCORED or EQUIVALENT --
## the proof that still holds and is not thrown away by the staleness.
var underlying_state: String = ABSENT

var passed: int = -1
var failed: int = -1
var not_evaluable: int = -1
var scored_at_commit: String = ""

## The CODE axis, read when the artefact carries it and compared to nothing.
## `sim_changed_since_scoring` is derived from this commit, which is the
## arithmetic a consumer otherwise has to reconstruct from prose.
var scoring_code_commit: String = ""

## Which key the state axis actually came from, so a report can say whether this
## artefact has been re-cut since the rename and the alias can be retired on
## evidence rather than on a date.
var scored_run_stamp_key: String = "scored_at_commit"
var scored_on_run: String = ""
var base_commit: String = ""
var failed_criteria: Array = []
## The fourth state's names. A criterion that could not be evaluated is NOT a
## failure and must never be rendered as one -- see `named_not_evaluable`.
var not_evaluable_criteria: Array = []
var equivalence: Dictionary = {}
var stale_against_replay: Dictionary = {}
var replayed_at_commit: String = ""
## The operator's reason, verbatim. Carried to the banner because a declared
## staleness whose reason stays in the manifest has declared nothing to anyone
## looking at the picture.
var declared_by_the_operator: String = ""
var not_covered_by_the_proof: String = ""


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
    # THE NEW KEY FIRST, THE ALIAS SECOND, AND NEITHER DEFAULTED TO THE OTHER
    # AXIS. `scoring_code_commit` is deliberately not a fallback here: it is a
    # real key in the same block holding a real commit, so accepting it would
    # substitute the code axis for the state one and compare it against
    # `base_commit`, which is exactly the confusion the rename exists to end.
    v.scored_at_commit = str(acc.get("scored_run_stamp_commit",
            acc.get("scored_at_commit", "")))
    v.scoring_code_commit = str(acc.get("scoring_code_commit", ""))
    v.scored_run_stamp_key = ("scored_run_stamp_commit"
            if acc.has("scored_run_stamp_commit") else "scored_at_commit")
    v.scored_on_run = str(acc.get("scored_run_dir", acc.get("scored_on_run", "")))
    v.failed_criteria = acc.get("failed_criteria", [])
    v.not_evaluable_criteria = acc.get("not_evaluable_criteria", [])
    if typeof(acc.get("equivalence", null)) == TYPE_DICTIONARY:
        v.equivalence = acc["equivalence"]
    if typeof(acc.get("stale_against_replay", null)) == TYPE_DICTIONARY:
        v.stale_against_replay = acc["stale_against_replay"]
        v.replayed_at_commit = str(v.stale_against_replay.get("replayed_at_commit", ""))
        v.declared_by_the_operator = str(
                v.stale_against_replay.get("declared_by_the_operator", ""))
        v.not_covered_by_the_proof = str(v.stale_against_replay.get(
                "what_the_equivalence_proof_below_does_not_cover", ""))
    if v.passed < 0 or v.failed < 0:
        v.state = ABSENT
        v.why = "an acceptance block is present and carries no pass/fail count"
        return v
    # Prefix comparison, because one side abbreviates and the other does not.
    # Equal-length-only would report every short-hashed verdict as stale, which
    # trains a reader to ignore the word.
    if _same_commit(v.scored_at_commit, v.base_commit):
        v.underlying_state = SCORED
    elif v.equivalence.is_empty():
        v.state = STALE
        v.underlying_state = STALE
        v.why = ("scored at %s, and this fixture was cut at %s with nothing offered to connect "
                + "them: the verdict is of a different run and does not describe what is drawn"
                ) % [_short(v.scored_at_commit), _short(v.base_commit)]
        return v
    else:
        var checked := v._check_equivalence()
        if checked != "":
            v.state = STALE
            v.underlying_state = STALE
            v.why = ("scored at %s against a fixture cut at %s, with an equivalence claim that "
                    + "does not check out: %s") % [_short(v.scored_at_commit),
                                                   _short(v.base_commit), checked]
            return v
        v.underlying_state = EQUIVALENT

    # THE REPLAY AXIS, APPLIED SECOND AND ONLY OVER A STATE PROOF THAT HELD. A
    # failed proof has already returned: it is the louder finding, and layering
    # a declared staleness on top of it would bury the thing that is actually
    # broken under the thing somebody remembered to declare.
    if v.stale_against_replay.is_empty():
        v.state = v.underlying_state
        return v
    var unreadable := v._check_staleness()
    if unreadable != "":
        v.state = STALE
        v.why = ("this fixture declares its verdict stale against the replay and the "
                + "declaration cannot be read: %s") % unreadable
        return v
    v.state = DECLARED_STALE
    v.why = ("scored at %s and replayed at %s: the run is this fixture's run and the code is "
            + "not, so the verdict describes a trajectory this payload no longer has. The "
            + "operator shipped it anyway, declaring: %s") % [
            _short(v.scored_at_commit), _short(v.replayed_at_commit),
            v.declared_by_the_operator]
    return v


## Does the staleness declaration hold together? "" when it does.
##
## THE REASON IS WHAT IS BEING CHECKED. A `stale_against_replay` with no
## `declared_by_the_operator` is a fixture marking itself stale and offering
## nobody a way to judge whether that was the right call -- which is strictly
## worse than not declaring, because the word arrives on screen with nothing
## behind it. And a declaration whose replay commit is the commit the verdict
## was scored at declares a drift that did not happen: a flag that cannot be
## wrong is the shape this repo keeps finding, and it would put a permanent
## warning on every future fixture that copied the block forward.
func _check_staleness() -> String:
    if declared_by_the_operator.is_empty():
        return ("it carries no `declared_by_the_operator`, so the staleness would reach a "
                + "reader as a word with no reason attached to it")
    if replayed_at_commit.is_empty():
        return "it names no `replayed_at_commit`, so there is nothing to say the code moved from"
    if _same_commit(replayed_at_commit, scored_at_commit):
        return ("it declares staleness against %s, which is the commit the verdict was scored "
                + "at: no code moved, so the declaration describes nothing"
                ) % _short(replayed_at_commit)
    return ""


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
        DECLARED_STALE:
            # The score is still stated, because it is still a real score of a
            # real run; what the sentence takes away is the claim that it
            # describes what is on screen. The operator's reason rides in
            # `why`, which the banner puts on its own line rather than here --
            # a headline that ran to two hundred characters would be truncated
            # in exactly the screenshot this panel exists to survive.
            return ("ancestor trace — acceptance %s, DECLARED STALE AGAINST THIS REPLAY: "
                    + "scored at %s, payload replayed at %s") % [
                    _score(), _short(scored_at_commit), _short(replayed_at_commit)]
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
    # THE STATE-ARRAY CLAUSE IS TWO FIELDS AND THIS READ A THIRD NAME FOR
    # NEITHER. The emitter writes `state_arrays_compared` -- a count -- beside
    # `state_arrays_bit_identical`, a bool. This header declared
    # `state_arrays_identical`, a count no emitter has ever written, so the
    # clause has never once reached a viewer. Renaming the bool onto the old
    # key would be worse than the silence it replaced: read through `int()`, a
    # `true` renders as "1 state arrays". THE COUNT IS THE NUMBER AND THE BOOL
    # IS WHAT LICENSES PRINTING IT as agreement.
    #
    # The old name is still accepted as a count, because it is what this header
    # asked for and refusing a proof over a label neither side reads would be
    # strict in the wrong place.
    var arrays := int(equivalence.get("state_arrays_compared",
            equivalence.get("state_arrays_identical", 0)))
    if arrays > 0:
        # A DECLARATION AGAINST INTEREST IS BELIEVED AND ONE IN ITS OWN FAVOUR
        # IS NOT. A `false` here can only weaken the sentence, so it is carried
        # into it; a `true` adds nothing the counts do not already carry, which
        # is why this does not gate the proof. What constitutes the proof is
        # `to_commit` and the two field counts -- see `_check_equivalence` --
        # and a bool is exactly the shape a future fixture could assert its way
        # past.
        var bits: Variant = equivalence.get("state_arrays_bit_identical", true)
        if typeof(bits) == TYPE_BOOL and not bool(bits):
            parts.append("%d state arrays NOT bit-identical" % arrays)
        else:
            parts.append("%d state arrays" % arrays)
    if int(equivalence.get("ticks", 0)) > 0:
        parts.append("%d ticks" % int(equivalence.get("ticks", 0)))
    var excluded: Array = equivalence.get("fields_excluded", [])
    if not excluded.is_empty():
        parts.append("%d field%s excluded" % [excluded.size(),
                "" if excluded.size() == 1 else "s"])
    return ", ".join(parts)


## The criteria that could not be evaluated, named, and kept OUT of the fails.
##
## `not_evaluable` was a bare count for as long as the count existed: the banner
## said "1 not evaluable" and nothing said WHICH, so the one state that is
## neither pass nor fail was the only one a viewer could not look into. This
## client asked the producing side for the block and it is emitted now, so the
## count has names.
##
## THE SEPARATION IS THE POINT AND NOT A LAYOUT CHOICE. The shipped criterion
## here is the surface-fire regime, whose own text opens "not a fire-model
## failure and the banner should not read as one" -- the regime is MET and what
## cannot be evaluated is the survival contrast. Folded in beside the fails, on
## a line the banner prefixes with "fails:", it would assert in the layout the
## exact thing its sentence denies. So it is a separate list with its own
## heading, and a caller that wants one flat list has to ask for both.
## `budget` trims the RENDERING, at a sentence end where one fits, exactly as
## `staleness_lines` does and for the same reason: this panel has to fit an
## 800 px window and a criterion's rendering is a paragraph. Zero means no
## trim, which is what the console and `tools/capture.gd` pass.
##
## MEASURED, BECAUSE THE FIRST CUT OF THIS DID NOT TRIM. The shipped
## not-evaluable rendering is 330 characters and it took the banner to 678 px
## with its bottom at 864 of 800 -- the overflow assert caught it on the first
## green-everything-else run, which is the assert working rather than a near
## miss. The criterion itself is not too long; an untrimmed paragraph in a
## 420 px column is.
func named_not_evaluable(budget: int = 0) -> PackedStringArray:
    return _named(not_evaluable_criteria,
            "could not be evaluated and how it is not said", budget)


## The named fails, which are the half that says how a failure looks on screen.
##
## `budget` TRIMS THESE TOO, and it did not until the panel overflowed twice.
## Staleness lines were trimmed, the not-evaluable line was trimmed, and the
## fails -- three renderings, 750 characters on the shipped fixture, the bulk
## of the panel -- were carried whole. That inconsistency was invisible for as
## long as the total happened to fit, and the first fixture to add a fourth
## rendering put the banner one pixel over an 800 px window. One pixel is not
## a margin; it is the next slightly longer criterion name going red.
##
## The invariant this restores is that the panel's height is bounded by the
## NUMBER of lines rather than by how verbose the producing side chose to be.
## Nothing is lost: the console and `tools/capture.gd` pass no budget and print
## every rendering whole.
func named_fails(budget: int = 0) -> PackedStringArray:
    return _named(failed_criteria, "unnamed in the manifest, so how it renders is not said",
            budget)


## ONE RENDERING FOR BOTH LISTS, so the two cannot drift in how they name a
## criterion or in what they say when the manifest carries a bare id.
## `bare_reason` is the sentence for an entry that is an id and nothing else --
## which differs between the two, because an unnamed fail and an unnamed
## not-evaluable leave a reader wanting different things.
func _named(criteria: Array, bare_reason: String, budget: int = 0) -> PackedStringArray:
    var out := PackedStringArray()
    for c in criteria:
        if typeof(c) == TYPE_DICTIONARY:
            var d: Dictionary = c
            var s := "criterion %s" % str(d.get("id", "?"))
            if d.has("name"):
                s += " (%s)" % str(d["name"])
            if d.has("renders_as"):
                # THE NAME IS NEVER TRIMMED AND THE RENDERING IS. A cut that
                # ate "criterion 7 (surface-fire regime)" would save the space
                # and lose the only part a reader needs to look the rest up.
                s += " — renders as %s" % _fit(str(d["renders_as"]), budget)
            out.append(s)
        else:
            out.append("criterion %s — %s" % [str(c), bare_reason])
    return out


## The lines a DECLARED_STALE verdict adds under the headline. Empty for every
## other state.
##
## THE DECLARATION IS THE POINT AND IT GOES FIRST. `what_the_..._does_not_cover`
## is the emitter's own statement of the proof's limit, and it is carried
## verbatim rather than paraphrased: it is the sentence that tells a reader
## which parts of the picture the 18-of-18 still covers, and a summary of it
## written here would be this client's opinion of somebody else's caveat.
## `budget` trims each line to about that many characters, at a sentence end
## where there is one and at a word boundary otherwise, marking the cut. Zero
## means no trim, which is what the console and `tools/capture.gd` pass.
##
## A DELIBERATE TRIM IS NOT THE DEFECT THE BANNER TEST CATCHES. That defect is a
## panel that overflows its window, cuts mid-sentence and silently hides
## everything below it -- a disclaimer that LOOKS complete. A line ending in an
## ellipsis says it is not complete, and the whole text is one `print` away in
## the same run.
##
## WHAT THE SHIPPED DECLARATION COSTS, re-measured at the `m3-001` landing
## because both halves of the old note stopped being true. It is 735 characters
## now, not 250. And its FIRST sentence is 39 characters of provenance -- two
## commit hashes -- with the reason in the second, where the old note said the
## first sentence carried it. The 150-character budget happens to keep both:
## the cut lands at the sentence end 134 characters in, so the reason survives
## the trim. That is the artefact's shape being kind rather than this function
## being careful, and it is worth knowing which.
func staleness_lines(budget: int = 0) -> PackedStringArray:
    var out := PackedStringArray()
    if state != DECLARED_STALE:
        return out
    out.append("declared by the operator: " + _fit(declared_by_the_operator, budget))
    if not not_covered_by_the_proof.is_empty():
        out.append("the equivalence proof does not cover: "
                + _fit(not_covered_by_the_proof, budget))
    else:
        # Said rather than omitted. A proof offered beside a staleness with no
        # statement of its limit is a proof whose scope the reader has to guess.
        out.append("the equivalence proof states no limit of its own, so what it still "
                + "covers is not said")
    return out


## One line cut to a budget, at a sentence end if one fits and at a word
## otherwise. The cut is always marked: a trimmed line that does not say it is
## trimmed is the same lie as an overflowing one, in less space.
static func _fit(text: String, budget: int) -> String:
    if budget <= 0 or text.length() <= budget:
        return text
    var head := text.substr(0, budget)
    var stop := head.rfind(". ")
    if stop > budget / 3:
        # Keeps the full stop: the sentence ended, and only what came after it
        # was dropped.
        return head.substr(0, stop + 1) + " …"
    var space := head.rfind(" ")
    return (head if space <= 0 else head.substr(0, space)) + " …"


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
