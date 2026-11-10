class_name DressingLoad
extends RefCounted

## THE DRESSING'S LOAD AND ITS IDENTITY — `docs/roadmap/client.md` G-9, window 1
## (decision 2129, owner ruling 2130). NOTHING HERE DRAWS.
##
## A dressing is four files. They are FETCHED AND NEVER COMMITTED: the pin
## beside them is the claim, the fetch tool is the only sanctioned way they
## arrive, and a clone with none of them is a working clone. This class answers
## two questions and refuses to guess at either:
##
##   * are the bytes here, and
##   * are they THE dressing the pin names.
##
## WHY FETCHED, SINCE THEY ARE SMALL. Every other fetched artefact in this tree
## is fetched because decision 948 puts it over a size line. These four are
## UNDER it — the largest is about 7.3 MB against a 10,485,760-byte threshold —
## and are fetched anyway. 948 partitions how a large artefact is hosted;
## whether a public tree may carry a simulation artefact's CONTENT is decision
## 973's question, and it was answered *fetched by pin*. A reader who checks the
## sizes against the pyramid's reasoning will find it does not apply, and this
## paragraph is here so that absence of a size argument is not read as a defect.
##
## TWO DIGESTS, TWO DOMAINS, AND THE PIN CARRIES BOTH UNDER THEIR OWN NAMES.
## This is §23.1745, and it exists because two lanes read one phrase differently:
##
##   `manifest_sha256`  the MANIFEST FILE's bytes. §22.8.9 calls this value
##                      `base_dressing` — the dressing an authored pin file says
##                      its author looked at.
##   `dressing_sha256`  the DRESSING'S CONTENT: all four files, in `FILES`'
##                      order, each contributing its name, a NUL, its byte
##                      length in decimal, a NUL, then its bytes. This is the
##                      value an owner's ruling names.
##
## They are both right and they are different numbers. **Neither is copied from
## anywhere**: both are recomputed here from the bytes on disk and compared with
## the pin, because a check that copies its expectation from the thing it checks
## cannot fail. The name and length prefixes are load-bearing — a plain
## concatenation of the same four files in the same order gives a different
## digest — so `FILES`' order and the prefix form are part of the contract and
## not an implementation detail.
##
## ⚠ THE SCHEDULE STAMPS ARE TWO DIFFERENT DIGESTS AND THIS CLASS COMPARES
## NOTHING ACROSS THEM. A manifest carries the schedule's CONTENT digest.
## A pin file carries the schedule's PLAN digest, which decision 2128 (ii)
## named `schedule_plan_digest` and which is what the emission tool now
## requires. Decision 2127 left the content digest alone when it added the
## plan digest, so the older spelling on a manifest IS CORRECT AND IS NOT A
## MISSED RENAME — do not "fix" it, and do not assert one against the other.
## They are digests over different domains, and comparing them would be two
## correct numbers at different bases read as one. A manifest cut before the
## plan digest existed carries no plan digest at all, and THAT IS NOT A LOAD
## FAILURE: it resolves through the schedule's own digest table, which is not
## this repo's to hold.
##
## NO STRING FROM THE MANIFEST APPEARS IN THIS FILE. The manifest's free text,
## its tool and record paths, its seed and its settlement identifiers are the
## simulation's to hold and not this tree's to republish (decision 973, with the
## manifest's prose read and reported before a byte was staged). This class
## reads digests and byte counts.
##
## [AMENDED at G-9 W3, 2026-11-09] IT NOW SURFACES EXACTLY TWO MANIFEST FIELDS,
## and the sentence that stood here said it surfaced none and that the drawing
## window would take what it needed through the reference instead. That was
## written at W1 and is no longer true, so it is corrected rather than left to
## be read as a rule this file breaks:
##
##   `pins_digest()`  the manifest's `pins` field, which is the digest of the
##                    committed pin file. The binding the explorer enforces
##                    before drawing a pin over this dressing lives there, in
##                    the data, and reading it anywhere else would be a second
##                    copy of it.
##   `era_starts()`   the eras and their first years, which are the viewer's
##                    slider ticks and no second set of years (decision 2129
##                    (c)). Era NAMES are interface and may be shown as tick
##                    labels, ruled at W3's construal Q4 on the same line as the
##                    palette's class names (decision 2129 (b), (f)).
##
## THE RULE THAT DID NOT CHANGE is the one that matters: these are VALUES READ
## AT RUNTIME from a fetched file, not strings written into this public tree. No
## `generated_by`, no `what`, no `readings`, no record path, no seed, no
## settlement or plant identifier is surfaced, named or republished here.

## The pin is the manifest: nothing here walks a directory, because a walk
## answers "what is on this disk" and the question is "what did the producing
## run write".
const PIN_PATH := "res://assets/dressing/da6-compact/PIN"
const DIR := "res://assets/dressing/da6-compact/"

## ORDER IS PART OF THE DIGEST, not a convenience. See the header.
const FILES: Array[String] = ["manifest.json", "tiles.jsonl", "features.jsonl",
        "routes.jsonl"]

## TWO ABSENCES, AND TELLING THEM APART IS THE POINT. A clone that never
## fetched is valid and the checks that need bytes must say so rather than
## report a mismatch; bytes that are here and wrong are a defect. A single
## boolean would collapse the two and report the valid state as the broken one.
const NOT_FETCHED := "NOT_FETCHED"
const PRESENT := "PRESENT"

var state: String = NOT_FETCHED
var why_absent: String = ""           ## non-empty only when state is NOT_FETCHED
var pin: Dictionary = {}

## What the pin claims.
var pinned_manifest_sha256: String = ""
var pinned_dressing_sha256: String = ""
## What the bytes on disk actually are, recomputed here.
var computed_manifest_sha256: String = ""
var computed_dressing_sha256: String = ""
## Per-file: name -> {pinned, computed, agrees}
var per_file: Dictionary = {}

var identity_problems: Array = []     ## empty exactly when the identity holds


static func load_from(pin_path: String = PIN_PATH, dir: String = DIR) -> DressingLoad:
    var d := DressingLoad.new()
    if not FileAccess.file_exists(pin_path):
        d.why_absent = ("no dressing pin at %s. The dressing is fetched, not committed "
                + "(decision 2129 on decision 973's question); the fetch tool writes "
                + "nothing without one.") % pin_path
        return d
    var f := FileAccess.open(pin_path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        d.why_absent = "%s is not a JSON object" % pin_path
        return d
    d.pin = parsed
    d.pinned_manifest_sha256 = str(d.pin.get("manifest_sha256", ""))
    d.pinned_dressing_sha256 = str(d.pin.get("dressing_sha256", ""))

    var absent := PackedStringArray()
    for name in FILES:
        if not FileAccess.file_exists(dir + name):
            absent.append(name)
    if not absent.is_empty():
        # A VALID CLONE, NOT A DEFECT, and it must not be reported as one.
        d.why_absent = ("the dressing is pinned but not fetched: %s absent under %s. "
                + "Run the fetch tool against this pin; nothing else brings them in.")\
                % [", ".join(absent), dir]
        return d

    d.state = PRESENT
    d._recompute(dir)
    return d


## The prefixed form the recorder writes, for both digests, so a value from here
## is comparable with a pin and with an owner's ruling without re-prefixing.
static func _prefixed(hex: String) -> String:
    return "sha256:" + hex


static func _sha256_of(chunks: Array) -> String:
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    for c: PackedByteArray in chunks:
        ctx.update(c)
    return ctx.finish().hex_encode()


## One file's contribution to the dressing's digest: name, NUL, decimal length,
## NUL, bytes. Separate from the loop so the prefix form has ONE definition.
static func _contribution(name: String, bytes: PackedByteArray) -> Array:
    var nul := PackedByteArray([0])
    return [name.to_utf8_buffer(), nul, str(bytes.size()).to_utf8_buffer(), nul, bytes]


func _recompute(dir: String) -> void:
    var chain: Array = []
    var files_claimed: Dictionary = pin.get("files", {})
    for name in FILES:
        var bytes := FileAccess.get_file_as_bytes(dir + name)
        var hex := DressingLoad._sha256_of([bytes])
        var claimed := str(files_claimed.get(name, ""))
        per_file[name] = {"pinned": claimed, "computed": hex, "bytes": bytes.size(),
                "agrees": claimed == hex}
        if claimed == "":
            identity_problems.append("%s: the pin carries no sha256 for it, so the "
                    % name + "transport cannot be checked at all")
        elif claimed != hex:
            identity_problems.append("%s: the fetched bytes are not the pin's. pin %s, "
                    % [name, claimed] + "computed %s" % hex)
        chain.append_array(DressingLoad._contribution(name, bytes))

    computed_manifest_sha256 = DressingLoad._prefixed(
            str(per_file["manifest.json"]["computed"]))
    computed_dressing_sha256 = DressingLoad._prefixed(DressingLoad._sha256_of(chain))

    if pinned_manifest_sha256 == "":
        identity_problems.append("the pin names no manifest_sha256")
    elif pinned_manifest_sha256 != computed_manifest_sha256:
        identity_problems.append(("manifest_sha256 disagrees: pin %s, computed %s. This is "
                + "the manifest FILE's bytes, which §22.8.9 calls base_dressing.")
                % [pinned_manifest_sha256, computed_manifest_sha256])
    if pinned_dressing_sha256 == "":
        identity_problems.append("the pin names no dressing_sha256")
    elif pinned_dressing_sha256 != computed_dressing_sha256:
        identity_problems.append(("dressing_sha256 disagrees: pin %s, computed %s. This is "
                + "the four files' content digest, not the manifest file's bytes.")
                % [pinned_dressing_sha256, computed_dressing_sha256])


func is_present() -> bool:
    return state == PRESENT


## True only when the bytes are here AND they are the dressing the pin names.
func identity_holds() -> bool:
    return state == PRESENT and identity_problems.is_empty()


## The manifest's `pins` field: the committed pin file's digest, in the
## recorder's prefixed form. "" when absent, which a caller must treat as a
## refusal to bind rather than as a pin file that matches.
func pins_digest() -> String:
    if pin.is_empty() or state != PRESENT:
        return ""
    var man := _manifest()
    return str(man.get("pins", ""))


## The eras and the first year of each, for the slider's ticks. {} when absent.
func era_starts() -> Dictionary:
    if state != PRESENT:
        return {}
    var man := _manifest()
    var e = man.get("era_starts", {})
    return e if typeof(e) == TYPE_DICTIONARY else {}


## The manifest, parsed from the fetched bytes on demand.
##
## NOT CACHED AT LOAD, deliberately. The load's job is presence and identity,
## and parsing a 319 KB document to answer a question nobody asked would make
## every identity check pay for the drawing window's needs. Callers that want
## several fields can hold the result themselves.
func _manifest() -> Dictionary:
    var parsed = JSON.parse_string(
            FileAccess.get_file_as_string(DIR + "manifest.json"))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## The slider's ticks: the eras' first years, grouped, sorted, clamped to
## [lo, hi]. Derived from the manifest's own `era_starts` and NO SECOND SET OF
## YEARS (decision 2129 (c); owner ruling 2059 Q3 rejected *different years*).
##
## ⚠ TWO ERAS SHARE A YEAR IN THIS DRESSING, AND A TICK LIST KEYED BY YEAR
## SILENTLY LOSES ONE. `walking` and `rail_streetcar` both begin at 1877, so
## five eras yield FOUR distinct positions. A Dictionary keyed on the year --
## the obvious shape, and the one this returned first -- keeps whichever era is
## read last and drops the other with no error anywhere: the slider would show
## four ticks, look entirely reasonable, and the owner would never be shown that
## an era existed. So a tick carries a LIST of era names, and a year with two
## eras names both.
##
## Era names are interface and may be shown as labels (W3's construal Q4, on the
## same line as the palette's class names: decision 2129 (b), (f)). They are
## read from the fetched manifest as data and declared nowhere in this tree.
static func era_ticks(era_starts: Dictionary, lo: int, hi: int) -> Array:
    var by_year := {}
    for name in era_starts:
        var y := int(era_starts[name])
        if y < lo or y > hi:
            continue
        if not by_year.has(y):
            by_year[y] = PackedStringArray()
        var names: PackedStringArray = by_year[y]
        names.append(str(name))
        by_year[y] = names
    var years: Array = by_year.keys()
    years.sort()
    var out: Array = []
    for y: int in years:
        var names: PackedStringArray = by_year[y]
        names.sort()
        out.append({"year": y, "eras": names})
    return out
