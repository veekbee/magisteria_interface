class_name TokenIssuer
extends RefCounted

## The toy issuer: an opaque wire name for a subject, per observer, rotated at
## decision 368's three boundaries.
##
## WHAT IT IS FOR, AND WHY A TOY IS WORTH BUILDING. §20.4.3 rules that a
## subject's name on the wire is issued per `(observer, subject)` rather than
## globally, and that it rotates when the observer's rung changes, when the
## subject leaves the promotion envelope, and on restoration. Nothing in this
## repo produces subjects yet, so nothing here is load-bearing for a pixel.
## What it IS load-bearing for is the consumer: a client that treats a token as
## a durable identity works perfectly against a producer that never rotates
## one, and breaks on the day a real one does. This makes rotation something
## the gate can exercise before live B exists, which is the whole of the ask.
##
## THE ISSUER IS THE PRODUCER'S AND ITS STATE NEVER CROSSES. The salt below is
## the reason a token is opaque rather than merely unfamiliar: without it the
## derivation is a pure function of a subject's identity, and a party holding a
## list of subjects could recompute every token for every observer. The salt
## stays on this side of the interface; only the token is carried.
##
## A TOKEN NEEDS STATE THAT OUTLIVES THE RESIDENT ENTRY, AND THAT SETTLES
## WHERE THE ISSUER LIVES.
##
## §20.4.5 asks that one `(world, observer, moment)` produce one bundle byte
## for byte -- decision 180's percept-as-pure-function extended to the document
## that carries it. (Filed against 180 here first, wrongly: 180 is the prefix
## invariant, about what a percept may SAY. This is about what a document may
## be NAMED, and the correction matters because the wrong rule is the one a
## later reader finds.)
##
## Two of the three boundaries are functions of the present state -- mix the
## rung in, mix the epoch in. The third is not: "has left the envelope and come
## back" is history, and a derivation from state alone hands a returning
## subject the name it left with. So an issuer must keep something, and the
## counter below is that something.
##
## "PURE FUNCTION OF THE MOMENT" NEVER MEANT "RECOMPUTABLE FROM NOTHING": a
## moment is a world state, and every registered array in a simulation is
## history by that test. So the question is not whether the issuer holds state
## but WHOSE state it is. This one is client-local, which genuinely is outside
## `(world, observer, moment)` -- so determinism HERE is over the episode, and
## replaying one moment out of the middle of a session does not reproduce it.
## Held by B as registered state, restored under decision 932's mapping like
## anything else, it is inside the world and §20.4.5 holds unchanged.
##
## WHICH IS THE ACTUAL CONSEQUENCE, AND IT IS A CONSTRAINT RATHER THAN A
## WEAKENING: a transducer holding state that determines wire content is
## authoring the wire. **The token issuer cannot be the transducer.** It is B's,
## and this file is correctly a toy -- not because it is unfinished, but
## because the finished one cannot live in this repo at all.
##
## LIVE B DOES NOT WORK LIKE THIS, AND THE DIFFERENCE IS THE POINT OF SAYING SO.
##
## Decision 1021 rules the wire token a KEYED HASH over `(subject, observer,
## earned rung, the observer's restoration count, envelope-entry tick)`, under a
## server-side key that is not derivable from the world seed. Read against the
## counter below, that is a fourth option none of the three considered here:
##
##   Every one of its five components is already in the envelope, so the issuer
##   owns NO DURABLE STATE OF ITS OWN -- no monotone counter, no per-subject
##   exit count kept forever. The three boundaries fall out of the components
##   rather than out of bookkeeping: the rung is in the key, the restoration
##   count is in the key, and a subject that leaves and returns enters at a
##   different tick.
##
##   And because all five are world state, `(world, observer, moment)` determines
##   the token, so §20.4.5's determinism holds UNCHANGED. The narrowing above is
##   a property of this toy's client-local counter and of nothing else. A reader
##   who found the narrowing here and carried it to the wire would be filing a
##   limitation against a design that does not have it.
##
##   THE RESTORATION COUNT IS WHY IT WORKS, and it is the same argument as the
##   one below: the count lives on the world side of the restoration line, where
##   the character's memory does not. An issuer whose rotation state were part
##   of what restoration restores would roll back with it and reissue the
##   pre-restoration tokens -- the third instance of a rotation that rotates
##   back, and the one that would have looked most like working.
##
##   ONE CASE THE ENTRY TICK CANNOT SEPARATE, recorded because it is the obvious
##   question: a subject that leaves the envelope and returns WITHIN A SINGLE
##   TICK enters at the tick it left and keeps its name. At tick rate that is not
##   an observable absence, so it is a bound rather than a defect -- but it is
##   the kind of bound that should be written down before somebody discovers it
##   and reads it as one.
##
## WHAT DOES NOT CHANGE. The issuer is still not the transducer. The per-subject
## ordinal kept in the resident map is still REJECTED and still on record as
## rejected -- see the counter below -- because the failure it produces looks
## exactly like the mechanism working.
##
## WHAT IT DOES NOT DO, SAID PLAINLY. Rotation closes the durable case: a
## client cannot carry a name across episodes and re-identify a subject from
## memory with no further evidence. It does not close linkage WITHIN an
## episode, where a subject's position is unchanged either side of a rotation
## and any consumer can match the two. §20.4.3 states that bound; this
## implementation does not exceed it, and the gate shows the within-episode
## match succeeding so that nobody reads rotation as more than it is.

## The three boundaries, named. A rotation always reports which one caused it,
## because "the token changed" and "the token changed FOR THE REASON I
## expected" are different observations and only the second one is a test.
const RUNG_CHANGE := "rung_change"
const ENVELOPE_EXIT := "envelope_exit"
const RESTORATION := "restoration"
const BOUNDARIES := [RUNG_CHANGE, ENVELOPE_EXIT, RESTORATION]

## Issued tokens are this many hex digits. Sixteen and not eight: the resident
## map is bounded by envelope occupancy, but the ISSUANCE COUNT is not, and a
## session issuing tens of thousands of tokens over its length collides at 32
## bits often enough to matter. Two mixes, concatenated.
const TOKEN_HEX := 16

var _session: String = ""
## Producer-side and never carried. See the header.
var _salt: int = 0
## Advances on restoration only. Mixed into every derivation so that the third
## boundary is visible in the arithmetic and not only in the bookkeeping.
var _epoch: int = 0
## The issuance counter. ONE INTEGER, and it is what makes re-entry safe: the
## map entry is dropped at envelope exit, so a per-subject ordinal kept in that
## entry would restart at zero and hand a returning subject the token it had
## before -- an exit rotation that rotates back. A monotone counter cannot do
## that, and costs O(1) rather than O(subjects ever seen).
var _issued: int = 0

## subject id -> {"token": String, "rung": String}. THE RESIDENT SET, and its
## size is the thing worth watching: it is bounded by how many subjects are in
## the envelope, never by how many exist. A map sized against the roster would
## be correct, bounded, and wrong by orders of magnitude.
var _live: Dictionary = {}

## Bookkeeping, for the gate and for a probe. Counts per boundary.
var _rotations: Dictionary = {}


## `salt` is the producer's own secret for this session. A caller passing the
## same salt twice gets the same episode back, which is what a replay wants and
## what two different observers must not have.
static func for_session(observer_session: String, salt: int) -> TokenIssuer:
    var t := TokenIssuer.new()
    t._session = observer_session
    t._salt = salt
    for b in BOUNDARIES:
        t._rotations[b] = 0
    return t


## This subject is in the envelope, at this rung. Returns its token now.
##
## A FIRST SIGHT AND A RE-ENTRY ARE THE SAME CALL, deliberately: the map is the
## only record of whether a subject is resident, and an absent entry means a
## token has to be issued either way. Telling the two apart would be a second
## piece of state free to disagree with the map.
func observe(subject_id: String, rung: String) -> String:
    if not _live.has(subject_id):
        return _issue(subject_id, rung)
    var e: Dictionary = _live[subject_id]
    if str(e["rung"]) != rung:
        _rotations[RUNG_CHANGE] = int(_rotations[RUNG_CHANGE]) + 1
        return _issue(subject_id, rung)
    return str(e["token"])


## The subject has left the promotion envelope. Its entry goes; its next
## appearance is a new token.
##
## The rotation is counted HERE rather than at the re-issue, because a subject
## that leaves and never returns has still rotated -- the name it had is spent.
## Counting at re-entry would report zero for an envelope nobody came back to,
## which is a count keyed on the wrong event.
func left_envelope(subject_id: String) -> void:
    if not _live.has(subject_id):
        return
    _live.erase(subject_id)
    _rotations[ENVELOPE_EXIT] = int(_rotations[ENVELOPE_EXIT]) + 1


## The third boundary. Every live token is spent at once and the epoch moves.
func restore() -> void:
    _rotations[RESTORATION] = int(_rotations[RESTORATION]) + _live.size()
    _live.clear()
    _epoch += 1


## The token a subject carries right now, or "" if it is not in the envelope.
## "" is an answer and not a failure: outside the envelope a subject has no
## name, which is the point of the exit boundary.
func token_for(subject_id: String) -> String:
    if not _live.has(subject_id):
        return ""
    return str((_live[subject_id] as Dictionary)["token"])


func is_resident(subject_id: String) -> bool:
    return _live.has(subject_id)


## How many subjects hold a token. The occupancy bound, as a number.
func resident() -> int:
    return _live.size()


func issued() -> int:
    return _issued


func epoch() -> int:
    return _epoch


## Rotations so far, by boundary.
func rotations() -> Dictionary:
    return _rotations.duplicate()


## The derivation. Opaque to anyone without the salt, distinct per observer,
## and fresh at every issuance because the counter is in it.
func _issue(subject_id: String, rung: String) -> String:
    _issued += 1
    var name_h := StableHash.of_name("%s %s" % [_session, subject_id])
    var a := StableHash.of3(_salt ^ name_h, _issued, _epoch)
    var b := StableHash.of3(StableHash.mix32(_salt + 0x51ed270b), name_h, _issued)
    var token := "%08x%08x" % [a, b]
    _live[subject_id] = {"token": token, "rung": rung}
    return token
