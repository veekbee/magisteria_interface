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
## WHAT CROSSES NOW AND DID NOT, AND WHAT STILL DOES NOT:
##
##   NODE-LATTICE ROWS CROSS (978). `node.streamflow` is indexed by river node
##   and channel 1 carried one key axis, so it had nowhere to go. It has one:
##   the fields region carries a key axis per lattice, and the node axis is
##   the fixture's own `node_order` -- carried, not reconstructed by splitting
##   the residence key, which 978 rejects as doing A-side a resolution that is
##   already done B-side.
##
##   THE CELL'S OWN YEAR STILL DOES NOT, AND THE ROW IT NEEDS IS WRITTEN (977).
##   The far-field tint mixes phenology by where a cell sits in ITS OWN yearly
##   range, which needs the whole year -- 365 days of a row, for every cell, to
##   draw one day. No bundle carries that: a moment is a moment. 977 rules
##   seasonal position across the wire as `band.phenology_index`, and it is
##   AUTHORED upstream and carried by no artefact here. So the tint waits on
##   transport rather than on a ruling. Not stubbed: a stub here would be this
##   repo authoring a row it does not own.

const KIND := "fixture_passthrough"

var _fl: FixtureLoader = null
var _provenance: Dictionary = {}
var _keys: PackedStringArray = PackedStringArray()
## The node axis, in the engine's own order, straight from the fixture's
## `node_order`. Never derived from `_keys`.
var _node_keys: PackedStringArray = PackedStringArray()

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
    # READ, NOT INFERRED. The ids that appear in `cell_keys` are the same ids,
    # and their order of first appearance agrees with the node order today --
    # which is exactly the kind of agreement that holds until it does not. The
    # fixture emits `node_order` for this purpose and a wrong node index draws
    # the wrong river's flow while looking entirely plausible.
    for huc10 in (fl.manifest.get("node_order", {}).get("ids", []) as Array):
        p._node_keys.append(str(huc10))
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
    b.node_keys = _node_keys
    b.rows = _fields_for(window, day)
    b.refinements = {}
    b.subjects = {}
    return b


## Channel 1 for one moment: every row the fixture carries, at every group,
## each indexed by ITS OWN lattice's key axis.
##
## The fixture's rows are already indexed the way each axis lists them -- band
## rows by cell, node rows by node ordinal -- so the "join" here is the
## identity on both, which is the honest reason the axes are what they are. A
## producer whose storage disagreed would map; this one does not have to, and
## pretending otherwise would be ceremony.
##
## THE LATTICE IS THE FIXTURE'S OWN DECLARATION, and it comes from the same
## place the contract's does. `row_names(window, lattice)` filters on the
## manifest's per-row `lattice` field; nothing here decides which lattice a row
## is on, and nothing infers it from an array's length.
func _fields_for(window: String, day: int) -> Dictionary:
    var ck := "%s|%d" % [window, day]
    if _fields_cache.has(ck):
        return _fields_cache[ck]
    var out := {}
    for lattice in PerceptBundle.AXIS_OF_LATTICE:
        for row in _fl.row_names(window, str(lattice)):
            var groups := _fl.taxon_groups(window, row)
            if groups.is_empty():
                groups = PackedStringArray([""])
            var vals: Array = []
            for gi in groups.size():
                vals.append(_fl.day_values(window, row, day, gi))
            out[row] = {"lattice": str(lattice), "groups": groups, "values": vals}
    _fields_cache[ck] = out
    return out


## Forget the cached moments. The viewer holds one basin for a whole session,
## so this exists for the harnesses that walk many days.
func forget() -> void:
    _fields_cache.clear()
