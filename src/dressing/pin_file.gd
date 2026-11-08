class_name PinFile
extends RefCounted

## THE EXPLORER'S AUTHORING SURFACE — the client repo's half of the dressing
## arc's DA-9, carried here as `docs/roadmap/client.md` G-8.
##
## It builds one `pins.json` in §22.8.4's form and nothing else: pin rows, never
## a tile, a feature row or an engine row. The file is placed by magisteria's
## emission tool (§25 backlog 690), which is NOT in this repo by decision
## 2075's own rejection.
##
## THE TOOL'S PATH IS DELIBERATELY NOT NAMED HERE AND SHOULD NOT BE ADDED. This
## tree is public; that one is not, and a private repo's file names are its
## internals. G-8's own `Want` cites the tool by backlog number and so does
## this file. The number resolves for anyone who can read the corpus, and
## leaks nothing to anyone who cannot.
##
## WHAT THIS CANNOT TELL YOU, AND THE AUTHOR HAS TO KNOW IT. This class checks
## the FORM of a pin file. It cannot check the things that matter most:
##
##   * whether `base_dressing` names a dressing that exists,
##   * whether a pin lies inside the base dressing's footprint,
##   * whether a pin is inside its bound,
##   * whether the schedule stamp is one the emission tool will accept.
##
## **All four are refusals only the emission tool can make**, because all four
## need magisteria's committed data, and a reader of it here would be a SECOND
## COPY OF A BOUND — which is the defect the tool's own construal Q4 exists to
## prevent. One repo does not fix the other. So an author finds out through the
## tool's `--check`, and this class is deliberately the weaker gate.
##
## WHAT IS DELIBERATELY NOT HERE. No `generated_by`: the tool strips any it is
## given and writes its own, so a value from here would not survive and the
## placed file is always attributed to the tool. **The property "re-emitting one
## input gives the same bytes" is the TOOL's canonical output, not this class's**
## -- nothing here promises byte-stability, and whitespace from here does not
## matter because the tool re-serialises.
##
## PROVENANCE IS ON EVERY PIN, AND §22.8.4'S TABLE UNDERSTATES THAT. The table
## names `authored_by` on `zone` and `feature` only; the section's prose says
## *provenance is on every pin*, and the emission tool refuses any pin without
## it, of any kind. The prose and the tool govern, so this class requires it on
## all seven. There is no file-level `authored_by` -- it is not a key the format
## admits, and emitting one would be refused by name.

## The format's whole top-level set, from the emission tool's own `TOP_KEYS`.
## `generated_by` is in the tool's set and is NOT written here, per above.
const TOP_KEYS := ["what", "form", "ruled_by", "base_dressing",
        "schedule_content_digest", "pins"]

## §22.8.4's seven kinds. A kind this class does not know is refused by name
## rather than passed through: an unknown kind reaching the tool would be
## refused there anyway, and later, with less of the author's context around it.
const KINDS := ["zone", "feature", "route", "centre", "cap", "renew", "sink"]

## Required fields per kind, from §22.8.4's table, plus `authored_by` on every
## one. `feature` is the one kind whose geometry is a choice -- a point OR a
## polygon -- so it is checked separately rather than listed here.
const REQUIRED := {
    "zone": ["polygon", "class", "from"],
    "feature": ["type", "from"],
    "route": ["class", "endpoints", "from"],
    "centre": ["point", "from"],
    "cap": ["polygon", "from"],
    "renew": ["polygon", "from"],
    "sink": ["type", "point", "from", "classes", "share"],
}

## The route classes §22.8.4 names. A route of another class is refused here.
const ROUTE_CLASSES := ["rail", "road", "canal", "streetcar", "freeway"]

## The sink types §22.8.4 names.
const SINK_TYPES := ["landfill", "incinerator", "outfall", "sewage_works",
        "impoundment"]

var base_dressing: String = ""
var schedule_content_digest: String = ""
var pins: Array = []
## Non-empty means REFUSED. Read it before using the file; nothing here throws.
var why_refused: String = ""


## Open an authoring surface over a base dressing.
##
## BOTH DIGESTS ARE THE CALLER'S AND ARE COPIED UNCHANGED. `base_dressing` is
## the sha256 of a committed `data/dressing/*/manifest.json`'s OWN BYTES at the
## magisteria HEAD -- not any value stored inside the manifest, which is a
## different number. `schedule_content_digest` is the schedule's stamp as the
## author was given it; **nothing here derives it**, because deriving it would
## put a second copy of a register value in this repo.
##
## ONLY THEIR SHAPE IS CHECKED, `sha256:` and 64 hex digits, which is the same
## check the tool's own `form_problems` runs. Whether either names anything real
## is the tool's refusal and cannot be made here.
static func over(base_dressing: String, schedule_content_digest: String) -> PinFile:
    var pf := PinFile.new()
    pf.base_dressing = base_dressing
    pf.schedule_content_digest = schedule_content_digest
    var bad := PackedStringArray()
    for pair in [["base_dressing", base_dressing],
                 ["schedule_content_digest", schedule_content_digest]]:
        var why := _digest_shape_problem(str(pair[1]))
        if why != "":
            bad.append("%s %s" % [str(pair[0]), why])
    if not bad.is_empty():
        pf.why_refused = ", ".join(bad)
    return pf


## `sha256:` followed by exactly 64 lowercase hex digits, or the reason it is not.
static func _digest_shape_problem(v: String) -> String:
    if v == "":
        return "is empty; the emission tool refuses a null or absent digest"
    if not v.begins_with("sha256:"):
        return "is %s, which does not begin `sha256:`" % JSON.stringify(v)
    var hex := v.substr(7)
    if hex.length() != 64:
        return "carries %d hex digits after `sha256:`, not 64" % hex.length()
    for i in hex.length():
        var c := hex[i]
        if not ((c >= "0" and c <= "9") or (c >= "a" and c <= "f")):
            return "carries %s, which is not a lowercase hex digit" % JSON.stringify(c)
    return ""


## Add one pin. Returns false and sets `why_refused` on the first problem; the
## pin is NOT added, so a refused file never half-carries one.
##
## REFUSES RATHER THAN DEFAULTS, EVERY TIME. A missing `from`, a missing
## `authored_by`, an unknown kind: each is named. Nothing is filled in, because
## a defaulted pin is an authored claim nobody made.
func add_pin(pin: Dictionary) -> bool:
    var why := _pin_problem(pin)
    if why != "":
        why_refused = why
        return false
    pins.append(pin.duplicate(true))
    return true


func _pin_problem(pin: Dictionary) -> String:
    var id = pin.get("pin_id")
    var label: String = JSON.stringify(id) if id != null else "#%d" % pins.size()
    if id == null or str(id) == "":
        return "pin %s: no `pin_id`" % label
    if pin.get("authored_by") == null or str(pin.get("authored_by")) == "":
        return ("pin %s: no `authored_by` -- provenance is on every pin (§22.8.4), " % label
                + "and there is no file-level `authored_by` to inherit")
    var kind := str(pin.get("kind", ""))
    if not KINDS.has(kind):
        return "pin %s: kind %s is not one of %s" % [label, JSON.stringify(kind), str(KINDS)]
    for f in REQUIRED[kind]:
        if not pin.has(f) or pin[f] == null:
            return "pin %s: kind %s needs `%s`" % [label, kind, str(f)]
    # `feature` carries a point OR a polygon; one of them, not neither.
    if kind == "feature" and not (pin.has("point") or pin.has("polygon")):
        return "pin %s: a `feature` needs a `point` or a `polygon`" % label
    if kind == "route" and not ROUTE_CLASSES.has(str(pin.get("class", ""))):
        return "pin %s: route class %s is not one of %s" % [
                label, JSON.stringify(pin.get("class")), str(ROUTE_CLASSES)]
    if kind == "sink" and not SINK_TYPES.has(str(pin.get("type", ""))):
        return "pin %s: sink type %s is not one of %s" % [
                label, JSON.stringify(pin.get("type")), str(SINK_TYPES)]
    for existing in pins:
        if str((existing as Dictionary).get("pin_id", "")) == str(id):
            return "pin %s: a pin with that `pin_id` is already here" % label
    return ""


## The file, as the emission tool reads it. Empty dictionary when refused.
##
## WHITESPACE HERE DOES NOT MATTER: the tool re-serialises canonically. This is
## `indent=1`-ish for a human reading a diff, and claims no byte-stability.
func to_document() -> Dictionary:
    if why_refused != "":
        return {}
    return {
        "what": ("pin rows authored over a committed dressing, in §22.8.4's form"
                + " -- placed by magisteria's emission tool (§25 backlog 690)"),
        "form": "§22.8.4 pins; the explorer's emission format is §22.8.9 (decision 2075)",
        "ruled_by": "decision 2075",
        "base_dressing": base_dressing,
        "schedule_content_digest": schedule_content_digest,
        "pins": pins.duplicate(true),
    }


func to_json() -> String:
    var doc := to_document()
    return "" if doc.is_empty() else JSON.stringify(doc, " ", false) + "\n"
