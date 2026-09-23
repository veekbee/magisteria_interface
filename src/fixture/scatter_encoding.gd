class_name ScatterEncoding
extends RefCounted

## WHICH FIELD QUANTITY DRIVES WHICH GEOMETRIC AXIS, read from a declaration
## rather than decided here. `assets/families/encoding.json` is the only place
## the mapping is chosen; `families.json` declares each axis's legal RANGE and
## says nothing about its source.
##
## WHY THIS IS A FILE AND NOT A RULE IN CODE. The mapping was hardcoded in
## `VegetationScatter.parameters_for()` while `families.json` described it in
## prose, and nothing bound the two. A comment could go wrong without anything
## noticing, and one did: it cited a design section that says nothing about
## crowns. A declaration the code actually reads cannot drift from the code.
##
## WHAT SHIPS IS AGAINST A RULING, AND THIS HEADER USED TO SAY THE QUESTION WAS
## OPEN. It was, until 2026-09-22. **Decision 1111 [OWNER RULING] settles what
## the vegetation display is for: a viewer reads maturity -- size and shape --
## type where earned, and rough density, and A PLANT'S GEOMETRIC AXES FOLLOW AGE
## AND TYPE AND NEVER LOCAL STAND DENSITY.**
##
## IT DISSOLVED THE QUESTION THIS CLASS WAS BUILT AROUND RATHER THAN ANSWERING
## IT. The question was *does the pair want a joint constraint*. 1111 names the
## defect as the HEIGHT channel's SOURCE -- `biomass / cover` is a stand
## quantity -- and the CROWN channel is wrong for the same reason, because
## `cover_fraction` IS local stand density. **Both shipped channels are ruled
## against, not one**, and the two variants built as the question's horns answer
## a question that was never the one ruled.
##
## `current` STILL SHIPS BECAUSE THE REPLACEMENT IS NOT BUILDABLE. 1111 binds
## the shape now and defers the substrate -- *shape bound now, spend later*. The
## source it names is `biomass / stem_density`, and section 23.1175 records a
## ZERO DENOMINATOR on every non-woody pool once backlog 302 lands. **Backlog
## 304 is the substrate and gates the repair.** Shipping a third guess to avoid
## an honest gap is how a wrong encoding acquires users, so the mapping stays
## declared-and-wrong rather than becoming undeclared-and-new.
##
## UNKNOWN NAMES REFUSE. A variant naming a source or constraint this class does
## not implement is refused with the name and the legal set. It is never
## defaulted -- a silently-defaulted encoding produces a picture nobody can
## attribute, which is the failure this whole file exists to prevent.

const DIR := "res://assets/families/"

## The closed sets. Kept beside the refusals that cite them, so a name added to
## one and not the other is a visible edit rather than a silent fallthrough.
const SOURCES := ["cover_fraction", "biomass_per_covered_over_hi",
        "biomass_over_hi", "constant_min", "constant_max"]
const JOINTS := ["none", "crown_tracks_height", "aspect_envelope"]

var name: String = ""                ## the selected variant's key
var what: String = ""                ## its own one-line description
var height_source: String = ""
var crown_source: String = ""
var joint: String = "none"
var min_ratio: float = 0.0
var max_ratio: float = 0.0
var why_absent: String = ""          ## non-empty means REFUSED; read it before use


## Load the declaration and select `variant`, or the file's own `shipped` key.
## Returns an object whose `why_absent` is non-empty on every refusal path --
## the caller checks it. There is no default encoding to fall back to.
static func load_from(dir_path: String = DIR, variant: String = "") -> ScatterEncoding:
    var e := ScatterEncoding.new()
    var path := dir_path + "encoding.json"
    if not FileAccess.file_exists(path):
        e.why_absent = "no encoding declaration at %s; the mapping is not built in" % path
        return e
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        e.why_absent = "%s is not a JSON object" % path
        return e
    var doc: Dictionary = parsed
    var variants: Dictionary = doc.get("variants", {})
    var want := variant if variant != "" else str(doc.get("shipped", ""))
    if want == "":
        e.why_absent = "%s names no `shipped` variant and none was asked for" % path
        return e
    if not variants.has(want):
        e.why_absent = "%s declares no variant %s; it has %s" % [
                path, want, ", ".join(PackedStringArray(variants.keys()))]
        return e
    var v: Dictionary = variants[want]
    e.name = want
    e.what = str(v.get("what", ""))
    e.height_source = str(v.get("height_source", ""))
    e.crown_source = str(v.get("crown_source", ""))
    e.joint = str(v.get("joint_constraint", "none"))
    for pair in [["height_source", e.height_source], ["crown_source", e.crown_source]]:
        if not SOURCES.has(str(pair[1])):
            e.why_absent = "variant %s names %s = %s, which is not a source this build implements (%s)" % [
                    want, str(pair[0]), str(pair[1]), ", ".join(SOURCES)]
            return e
    if not JOINTS.has(e.joint):
        e.why_absent = "variant %s names joint_constraint %s, which is not implemented (%s)" % [
                want, e.joint, ", ".join(JOINTS)]
        return e
    if e.joint == "aspect_envelope":
        if not (v.has("min_ratio") and v.has("max_ratio")):
            e.why_absent = "variant %s asks for an aspect_envelope and declares no min_ratio/max_ratio" % want
            return e
        e.min_ratio = float(v["min_ratio"])
        e.max_ratio = float(v["max_ratio"])
        if e.min_ratio > e.max_ratio:
            e.why_absent = "variant %s declares min_ratio %s above max_ratio %s" % [
                    want, String.num(e.min_ratio, 4), String.num(e.max_ratio, 4)]
            return e
    return e


## The normalised position along a declared range, for one named source. The
## caller has already established `fraction > 0`.
static func t_of(source: String, fraction: float, biomass: float, biomass_hi: float) -> float:
    match source:
        "cover_fraction":
            return clampf(fraction, 0.0, 1.0)
        "biomass_per_covered_over_hi":
            return 0.0 if biomass_hi <= 0.0 else clampf(biomass / fraction / biomass_hi, 0.0, 1.0)
        "biomass_over_hi":
            return 0.0 if biomass_hi <= 0.0 else clampf(biomass / biomass_hi, 0.0, 1.0)
        "constant_min":
            return 0.0
        "constant_max":
            return 1.0
    # Unreachable while `load_from` validates against SOURCES, and reported
    # rather than silently zeroed if that ever stops being true.
    push_error("scatter_encoding: no rule for source %s" % source)
    return NAN


func t_height(fraction: float, biomass: float, biomass_hi: float) -> float:
    return t_of(height_source, fraction, biomass, biomass_hi)


## `crown_tracks_height` is applied HERE rather than after the lerp, because the
## two axes have different declared ranges: taking height's *position* is what
## "follows height" means, and copying its metres would leave the crown range.
func t_crown(fraction: float, biomass: float, biomass_hi: float) -> float:
    if joint == "crown_tracks_height":
        return t_height(fraction, biomass, biomass_hi)
    return t_of(crown_source, fraction, biomass, biomass_hi)


## The envelope, applied after both axes are in metres, because a ratio is a
## statement about metres and not about positions in two different ranges.
##
## TWO CONSTRAINTS CAN BE UNSATISFIABLE TOGETHER AND THAT IS REPORTED, NEVER
## RESOLVED BY PREFERENCE. The envelope asks for `[min_ratio, max_ratio] * height`
## and the family declares `[c_min, c_max]`. Where those intervals do not
## overlap there is no legal crown, and picking either one would produce a plant
## that satisfies a constraint the declaration did not ask for.
func crown_after_joint(height_m: float, crown_m: float,
                       c_min: float, c_max: float) -> Dictionary:
    if joint != "aspect_envelope":
        return {"ok": true, "crown_m": crown_m}
    var lo := maxf(min_ratio * height_m, c_min)
    var hi := minf(max_ratio * height_m, c_max)
    if lo > hi:
        return {"ok": false, "why":
                ("the %s envelope wants a crown in [%s, %s] m at height %s m and the family " +
                 "declares [%s, %s] m; the two do not overlap") % [
                        name, String.num(min_ratio * height_m, 3), String.num(max_ratio * height_m, 3),
                        String.num(height_m, 3), String.num(c_min, 3), String.num(c_max, 3)]}
    return {"ok": true, "crown_m": clampf(crown_m, lo, hi)}
