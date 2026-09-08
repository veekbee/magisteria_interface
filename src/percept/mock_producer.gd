class_name MockProducer
extends RefCounted

## A producer that EARNS something, so the transducer has a rung boundary to
## cross. Passthrough channel 1, plus a scripted refinement overlay.
##
## WHAT IT IS FOR. Under the passthrough the client draws every plant at its
## life form, which is a valid transducer for "everything is earned at the
## life-form rung" -- and a valid transducer that never changes rung cannot
## test the one rule that matters about changing rung. This is the smallest
## producer that makes the boundary exist.
##
## IT IS NOT THE MOCK PRODUCER. There is no token issuer here, no channel-2
## subject, no per-attribute precision. Channel-1 flora needs none of those:
## existence is keyed on ground rather than on a token, so a refinement overlay
## is a whole rung ladder by itself. What is here is the part B6 cannot exist
## without, and the rest belongs to its own round.
##
## EVERY CONSTANT BELOW IS FAKE AND SAYS SO. That is not modesty, it is what
## keeps a mock publishable: a scripted earned function with plausible numbers
## would be a claim about how much an observer earns at a distance, and how
## much an observer earns is not this repo's to state. These are round numbers
## chosen to put a boundary somewhere a person can walk across.
##
## AND THE CHOICE OF WHICH TAXON IS FAKE TWICE OVER. The client's fixture
## aggregates to life form, so nothing on the wire says which specific plant
## stands on any particular ground. The mock picks one deterministically from
## the cell's own key. What is real here is only that a split EXISTS and where
## its boundary falls; which taxon lands where is invented.

const KIND := "mock"

## Metres, measured to a CELL'S CENTROID. Inside this the observer earns the
## specific rung; outside it, the life form.
##
## FAKE, like everything else here. But the SCALE is not free, and finding that
## out is the useful thing this producer did. Channel 1 is keyed by residence
## cell and a cell in this basin averages 126 km2 -- about eleven kilometres
## across -- so THE FINEST RUNG BOUNDARY CHANNEL 1 CAN EXPRESS FOR FLORA IS A
## CELL BOUNDARY. A distance rule in metres, which is the shape an earned
## function takes for SUBJECTS because a subject carries its own position, has
## no key to land on here: at 250 m it would refine either every cell in the
## build or none of them, and the boundary would be invisible either way.
##
## Seven kilometres is chosen so the observer's own cell is refined and its
## neighbours usually are not, which puts the boundary on the cell edge the
## viewer is standing next to. That is a real boundary and it is cell-shaped,
## and its being cell-shaped is a fact about the wire rather than about the
## mock.
const SPECIFIC_WITHIN_M := 7000.0

## The axis a refinement key names: the life-form node being refined.
const AXIS := "life_form"

var _base: FixturePassthrough = null
var _fs: FamilySet = null
var _nodes_by_parent: Dictionary = {}   ## life form -> [node, ...], sorted


static func over(base: FixturePassthrough, fs: FamilySet) -> MockProducer:
    var m := MockProducer.new()
    m._base = base
    m._fs = fs
    for node in fs.nodes():
        var parent := fs.parent_of(str(node))
        if parent == "":
            continue
        if not m._nodes_by_parent.has(parent):
            m._nodes_by_parent[parent] = []
        (m._nodes_by_parent[parent] as Array).append(str(node))
    for parent in m._nodes_by_parent:
        (m._nodes_by_parent[parent] as Array).sort()
    return m


func is_ready() -> bool:
    return _base != null and _base.is_ready() and not _nodes_by_parent.is_empty()


## A bundle with a refinement overlay on it.
##
## `cell_centres` maps a residence key to where that cell is, in world metres,
## because the scripted earned function is a distance and the producer is the
## side that knows where the observer stands. The transducer passes no radius,
## no filter and no detail level -- see the producer contract; a knob a
## consumer can turn is a knob a consumer can turn too far.
func bundle_for(window: String, day: int, observer: Dictionary,
                cell_centres: Dictionary) -> PerceptBundle:
    var b := _base.bundle_for(window, day, observer)
    b.producer = {"kind": KIND, "id": "mock-distance-v0",
                  "provenance": {
                      "earned_function": "distance_v0",
                      "specific_within_m": SPECIFIC_WITHIN_M,
                      "_fake": ("every constant in this producer is invented. How much an "
                              + "observer earns at a distance is not the client's to state, "
                              + "and a plausible number here would be a claim rather than a "
                              + "stub."),
                      "taxon_choice": ("deterministic from the cell key. The wire aggregates "
                              + "to life form, so which specific plant stands on which ground "
                              + "is not carried and is invented here. Only the existence of "
                              + "the split and where its boundary falls are real."),
                  }}
    b.refinements = _refine(b.observation_point, cell_centres)
    return b


## The overlay: `"<cell key>|<life form>" -> node`, present only where earned.
##
## PRESENT ONLY WHERE EARNED IS THE DISCIPLINE, not a detail. An overlay
## everywhere is the same statement as no overlay at all, and a mock that
## refined the whole basin would be a passthrough wearing a mock's name.
func _refine(eye: PackedFloat64Array, cell_centres: Dictionary) -> Dictionary:
    var out := {}
    if eye.size() != 3:
        return out
    var ex := eye[0]
    var ey := eye[2]
    for key in cell_centres:
        var c: Vector2 = cell_centres[key]
        if Vector2(c.x - ex, c.y - ey).length() > SPECIFIC_WITHIN_M:
            continue
        for parent in _nodes_by_parent:
            var choices: Array = _nodes_by_parent[parent]
            var pick := _choose(str(key), str(parent), choices.size())
            out["%s|%s" % [str(key), str(parent)]] = str(choices[pick])
    return out


## Which of a parent's taxa this cell gets. Deterministic, so a replay of the
## same moment produces the same bytes.
##
## FNV-1a, WRITTEN HERE AND DELIBERATELY NOT THE PLACEMENT HASH. Sharing a seed
## with placement would tie a mock's arbitrary choice to where plants stand: a
## change to this file would move the stand, and a mock has to be replaceable
## without touching what is drawn where. Different jobs, different hashes, and
## `String.hash()` is neither because it is an engine internal free to change.
static func _choose(cell_key: String, parent: String, n: int) -> int:
    if n <= 1:
        return 0
    var h: int = 0x811c9dc5
    for b in ("%s/%s" % [cell_key, parent]).to_utf8_buffer():
        h = ((h ^ int(b)) * 16777619) & 0x7fffffff
    return h % n
