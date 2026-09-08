class_name FixturePassthrough
extends RefCounted

## The degenerate producer: the fixture, handed over as a bundle.
##
## WHAT MAKES IT WORTH BUILDING. It earns nothing and hides nothing -- channel
## 1 is the carried rows at full carried precision, channel 2 is empty, and no
## overlay is ever refined because the observer's competence is not modelled at
## all. So it changes nothing about what the viewer draws, and that is its
## acceptance test: if a pixel moves, this is not a passthrough.
##
## What it does change is the SHAPE of the dependency. A consumer that reads a
## bundle reads the same interface a mock and a live producer present, so the
## day the fixture stops being the truth the consumer does not have to be
## rewritten -- and, more usefully now, the day a consumer needs something the
## bundle cannot carry, it finds out here rather than three producers later.
## Two such findings are already recorded: see WHAT DOES NOT CROSS below.
##
## THE PRODUCER SIDE IS ALLOWED TO READ THE FIXTURE. It is standing in for B,
## and B holds the world. The rule the dependency scan enforces is about the
## far side: a consumer in `src/transducer/` reads bundles and never reaches
## past one for the file underneath.
##
## WHAT DOES NOT CROSS, AND WHY IT IS WORTH SAYING OUT LOUD:
##
##   NODE-LATTICE ROWS. `node.streamflow` is indexed by river node, not by
##   residence cell, and channel 1 is keyed by residence key. A reach's flow is
##   plainly something an observer could perceive, so this is a gap in the
##   schema and not in the fixture: what key a node row rides on is a question
##   for whoever lands the bundle corpus-side, and inventing an answer here
##   would be inventing a wire.
##
##   THE CELL'S OWN YEAR. The far-field tint mixes phenology by where a cell
##   sits in ITS OWN yearly range, which needs the whole year -- 365 days of a
##   row, for every cell, to draw one day. No bundle carries that: a moment is
##   a moment. Either the seasonal position is itself a carried row (a percept:
##   how far through its year this ground looks) or the tint is asking for
##   something no observer has. That is a producer-side question, so the tint
##   stays on the fixture and outside the transducer subtree until it is
##   answered.

const KIND := "fixture_passthrough"

var _fl: FixtureLoader = null
var _provenance: Dictionary = {}
var _keys: PackedStringArray = PackedStringArray()

## Cached channel 1, keyed by "window|day": the fields are a property of the
## moment, and a viewer asks for the same moment many times over while the
## person moves through it.
var _fields_cache: Dictionary = {}


## `id` names the producer instance so a recorded stream can say which one made
## it; `provenance` carries the fixture's own digest, which is what a replay
## checks a trace against.
static func over(fl: FixtureLoader, id: String = "viewer") -> FixturePassthrough:
    var p := FixturePassthrough.new()
    p._fl = fl
    p._provenance = {
        "fixture_manifest_digest": str(fl.manifest.get("digest_sha256",
                fl.manifest.get("client_form", {}).get("sha256", ""))),
        "fixture_run": str(fl.manifest.get("run", fl.manifest.get("trace", ""))),
    }
    p._provenance["_note"] = ("a passthrough's provenance is the artefact it passed through. "
            + "A trace replayed against a different one is a different experiment.")
    var pairs: Array = fl.manifest.get("cell_keys", {}).get("pairs", [])
    for pr in pairs:
        p._keys.append("%s|%d" % [str(pr[0]), int(pr[1])])
    return p


func is_ready() -> bool:
    return _fl != null and _fl.is_loaded() and not _keys.is_empty()


## One bundle for one observer at one moment.
##
## `observer` is `{session, stature_m, posture, ground_point}` -- what a body
## IS, not what it wants. There is no radius here, no filter, no detail level:
## every knob that shapes content is the producer's, and a transducer that
## could ask for more detail could ask for more than it earned.
func bundle_for(window: String, day: int, observer: Dictionary) -> PerceptBundle:
    var b := PerceptBundle.new()
    b.producer = {"kind": KIND, "id": str(observer.get("producer_id", "viewer")),
                  "provenance": _provenance.duplicate()}
    b.observer_session = str(observer.get("session", ""))
    b.moment = {"window": window, "day": day, "tick": int(observer.get("tick", 0))}

    var stature := float(observer.get("stature_m", BodyDerivation.DEFAULT_STATURE_M))
    var posture := str(observer.get("posture", "standing"))
    b.posture = posture
    b.observation_point = BodyDerivation.observation_point(
            observer.get("ground_point", PackedFloat64Array([0.0, 0.0, 0.0])),
            stature, posture)
    b.locomotion = BodyDerivation.locomotion(stature, posture)
    b.readouts = []

    b.cell_keys = _keys
    b.rows = _fields_for(window, day)
    b.refinements = {}
    b.subjects = {}
    return b


## Channel 1 for one moment: every band-lattice row the fixture carries, at
## every group, indexed by the shared key axis.
##
## The fixture's band rows are already indexed by cell in the order `cell_keys`
## lists them, so the "join" here is the identity -- which is the honest reason
## the axis is what it is. A producer whose storage disagreed would map; this
## one does not have to, and pretending otherwise would be ceremony.
func _fields_for(window: String, day: int) -> Dictionary:
    var ck := "%s|%d" % [window, day]
    if _fields_cache.has(ck):
        return _fields_cache[ck]
    var out := {}
    for row in _fl.row_names(window, "band"):
        var groups := _fl.taxon_groups(window, row)
        if groups.is_empty():
            groups = PackedStringArray([""])
        var vals: Array = []
        for gi in groups.size():
            vals.append(_fl.day_values(window, row, day, gi))
        out[row] = {"groups": groups, "values": vals}
    _fields_cache[ck] = out
    return out


## Forget the cached moments. The viewer holds one basin for a whole session,
## so this exists for the harnesses that walk many days.
func forget() -> void:
    _fields_cache.clear()
