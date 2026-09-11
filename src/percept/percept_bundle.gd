class_name PerceptBundle
extends RefCounted

## What one observer is given about one moment. The seam the client draws from.
##
## THE POINT OF IT. Today the viewer reads a fixture: a file holding the whole
## basin at full precision, which is to say everything, for everyone, always.
## That is a development convenience and it is the opposite of what a client is
## eventually handed -- one observer's share, already coarsened, with the
## mechanism that decided the coarsening on the far side of the interface. This
## class is that share, as a container. Nothing here decides what an observer
## earns; the producer does, and under the passthrough producer the answer is
## "the fixture, verbatim", which is exactly a stub.
##
## WHAT IT CARRIES, IN THE ORDER THE SKETCH NAMES:
##   header    -- which producer, which observer session, which moment
##   body      -- the percept of self: where the eyes are, the posture, what
##                movement needs. `readouts` is empty in v0, deliberately.
##   fields    -- channel 1, the ambient background: the carried rows on ONE KEY
##                AXIS PER LATTICE, plus a refinements overlay (empty here)
##   subjects  -- channel 2, individuated things (empty under passthrough)
##
## THE SCHEMA IS CLOSED, AND THE CLOSURE IS THE ENFORCEMENT. `from_dict`
## refuses a document carrying any name this file does not declare, rather than
## ignoring it. That is the direction that holds: a denylist has to be kept
## current against everything that must never cross and is one forgotten entry
## from being wrong, while a closed schema admits nothing by accident and
## nothing by addition elsewhere. It also means this file states what DOES
## cross and never what does not, which is the only form of the rule that can
## live in a public repo.
##
## CHANNEL 1 IS THE SHIPPED CONTRACT AND DOES NOT FORK IT. The rows here are
## `contract/schema.json`'s rows, at their carried values, under their own
## names. One home per quantity: the bundle CONTAINS the contract rather than
## re-deriving it, so a row cannot come to mean two things by being described
## twice.
##
## ONE KEY AXIS PER LATTICE, AND NO ROW IS PROJECTED ONTO ANOTHER'S (978).
## Band rows ride the residence key, `huc10|band`. Node rows ride the node key,
## which is the same HUC10 id the residence key's first component carries and
## the flowline export's `node` field joins reaches to -- so the flow drape's
## join is an identity against geometry the client already holds.
##
## A ROW'S LATTICE IS READ FROM THE CONTRACT AND NEVER INFERRED. Every row in
## `contract/schema.json` declares `lattice`, and `node.streamflow` has shipped
## with `dims=["node"]` since v1.0; only this prototype's single-axis fields
## region collapsed it. Inferring an axis from an array's length would agree
## today and draw the wrong river's flow the day two lattices happen to match.
##
## THE TWO ACCESSORS ARE SEPARATE ON PURPOSE. `value_at` takes a residence key
## and `node_value_at` takes a node key; there is no accessor that takes "a
## key" and works out which space it is in. Such a thing would accept a
## residence key for a node row and answer plausibly, which is the projection
## 978 forbids arriving through a convenience.
##
## STORED COLUMNAR, READ AS A MAPPING. The sketch's form is
## `cells {residence_key -> {row -> value}}` and `value_at` answers exactly
## that. Underneath, each row is a packed array indexed by its own axis -- the
## same information transposed, and the difference between a dictionary of
## 45,000 entries rebuilt every time the day changes and fourteen array reads.
## A key axis is a property of the world, not of the moment, so a consumer
## binds to it once and every later bundle from the same world reuses that
## bind.
##
## DETERMINISTIC (decision 180): one (world, observer, moment) produces one
## bundle, byte for byte, so a recorded stream replays.

const SCHEMA_VERSION := {"major": 0, "minor": 1}

## The producer kinds this schema knows. `live` is named here and produced by
## nothing in this repo -- the schema is the same one either way, which is the
## property that makes a mock worth building.
const PRODUCER_KINDS := ["fixture_passthrough", "mock", "live"]

## Postures. A body is in one of them; the observation point is derived from
## the posture and the stature together, never carried as a free number.
const POSTURES := ["standing", "crouched", "prone"]

## Every name a bundle document may hold, at each level. `from_dict` refuses
## anything else -- see the header for why this is a whitelist and not the
## other kind.
const DECLARED := {
    "root": ["header", "body", "fields", "subjects"],
    "header": ["schema_version", "producer", "observer_session", "moment"],
    "producer": ["kind", "id", "provenance"],
    "moment": ["window", "day", "tick"],
    "body": ["observation_point", "posture", "locomotion", "readouts"],
    "fields": ["cell_keys", "node_keys", "rows", "refinements"],
    "row": ["lattice", "groups", "values"],
}

## Which declared key axis each lattice rides. The mapping lives here rather
## than at each call site, so "which axis is this row on" has one answer and a
## third lattice is one entry rather than a search.
const AXIS_OF_LATTICE := {"band": "cell_keys", "node": "node_keys"}

# -- header ------------------------------------------------------------------
var producer: Dictionary = {}           ## {kind, id, provenance}
var observer_session: String = ""       ## opaque; identity of a session, nothing about the body
var moment: Dictionary = {}             ## {window, day, tick}

# -- body --------------------------------------------------------------------
## Where the eyes are, in world metres (EPSG:5070 easting, elevation, northing).
## DERIVED BY THE PRODUCER from stature and posture. The camera coincides with
## it; the camera never decides it. See `BodyDerivation`.
##
## THREE FLOAT64s AND NOT A `Vector3`, which is not fussiness. Godot's Vector3
## is single precision, and this basin's eastings run past a million metres --
## where float32 steps in units of about 6 cm. A body knows where it is
## exactly, and that exactness is the one thing in this schema that costs
## nothing to earn, so it is not spent on a container. `as_vector3` is there
## for the render side, where the precision is going to be lost anyway and
## losing it deliberately at a named place is the difference between a
## concession and a bug.
var observation_point: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var posture: String = "standing"
## What movement needs, and no more: v0 carries a sustainable speed. The
## envelope arithmetic that produces it is the producer's.
var locomotion: Dictionary = {}
## EMPTY IN V0, and empty on purpose rather than for want of time: what a body
## reports about itself crosses in a masked form whose design is not settled,
## and pulling it in early would drag a whole substance model into a schema
## that so far needs a camera and legs.
var readouts: Array = []

# -- fields (channel 1) ------------------------------------------------------
## The key axis: `"huc10|band"`, the same string the residence raster resolves
## to. A property of the world; identical across moments.
var cell_keys: PackedStringArray = PackedStringArray()
var _index: Dictionary = {}              ## residence key -> axis position, built on first ask
## THE NODE KEY AXIS: HUC10 ids in the engine's node order. The same ids the
## residence key's first component carries, but the ORDER is the engine's own
## and is read from the fixture's `node_order` rather than inferred from where
## an id first appears in `cell_keys` -- that inference agrees today, rests on
## cells being grouped by node ordinal, which nothing promises, and a wrong
## node index draws the wrong river's flow while looking entirely plausible.
##
## And it is carried, never reconstructed. 978 rejects splitting the residence
## key string client-side: that is a resolution done A-side of a resolution
## decision 891 already does B-side.
var node_keys: PackedStringArray = PackedStringArray()
var _node_index: Dictionary = {}         ## node key -> axis position, built on first ask
## row name -> {"lattice": String, "groups": PackedStringArray,
##              "values": Array[PackedFloat64Array]}
## One entry per group; a row with no taxon axis has exactly one, named "".
var rows: Dictionary = {}
## Conditional overlays, present only where earned. Empty under passthrough,
## which is what makes passthrough passthrough: an overlay everywhere is the
## same statement as no overlay at all.
var refinements: Dictionary = {}

# -- subjects (channel 2) ----------------------------------------------------
## token -> subject percept. Empty under BOTH stand-in producers, which
## §20.4.5 states as a rule and not as a stage: the fixture individuates
## nothing, so subjects invented from it would be a mock wearing a stub's name.
## The keys are §20.4.3's per-observer tokens, and `TokenIssuer` is the toy
## issuer that mints them -- built so a consumer's handling of rotation can be
## exercised before a producer with real subjects exists, not so that this
## region can be filled early.
##
## AND THE CLOSED WHITELIST STOPS AT THIS REGION'S DOOR. Every other level of
## the document is checked against `DECLARED`; the inside of a subject is not,
## because what a subject percept CONTAINS is not ruled anywhere this repo can
## read, and declaring it here would be the prototype authoring the corpus
## rather than conforming to it. So the gap is named: today the region is
## always empty and the hole cannot be reached, and the day a producer fills it
## the structure rule has a hole exactly where channel 2's content goes. That
## is a question for the side that owns §20.4.5, and it is in the handback.
var subjects: Dictionary = {}

## Set when a document was refused, with the reason. A refused bundle is not a
## partially-loaded one: nothing is read out of it.
var refused: bool = false
var refusal: String = ""


## The observation point where a scene needs one, at the precision a scene has.
## Single precision: see `observation_point` for why that is a place and not an
## accident.
func as_vector3() -> Vector3:
    if observation_point.size() != 3:
        return Vector3.ZERO
    return Vector3(observation_point[0], observation_point[1], observation_point[2])


## The value one cell carries for one BAND row -- the sketch's `cells` mapping,
## as a lookup. NAN where the cell is unkeyed, the row absent, or the wire said
## nodata; never 0.0, which is a real value for every row here.
##
## REFUSES A NODE ROW rather than indexing it with a residence position. The
## two axes are different lengths today -- 5,684 against 1,154 -- so most such
## reads would fall off the end and the rest would be a plausible number from
## the wrong river.
func value_at(residence_key: String, row: String, group: int = 0) -> float:
    if lattice_of(row) != "band":
        return NAN
    var i := index_of(residence_key)
    if i < 0:
        return NAN
    var vals := row_values(row, group)
    return NAN if i >= vals.size() else vals[i]


## The value one river node carries for one NODE row. Its own key space, and
## the symmetric refusal: a band row asked for by node key is the same mistake
## the other way.
func node_value_at(node_key: String, row: String, group: int = 0) -> float:
    if lattice_of(row) != "node":
        return NAN
    var i := node_index_of(node_key)
    if i < 0:
        return NAN
    var vals := row_values(row, group)
    return NAN if i >= vals.size() else vals[i]


## Which lattice a row rides, or "" if the bundle does not carry it. The
## default for a row that arrived without one is "band", which is what every
## row before 978 was.
func lattice_of(row: String) -> String:
    if not rows.has(row):
        return ""
    return str((rows[row] as Dictionary).get("lattice", "band"))


## The key axis a row is indexed by, whichever lattice it is on.
func axis_for(row: String) -> PackedStringArray:
    var axis := str(AXIS_OF_LATTICE.get(lattice_of(row), ""))
    if axis == "node_keys":
        return node_keys
    if axis == "cell_keys":
        return cell_keys
    return PackedStringArray()


## Row names on one lattice, or all of them when `lattice` is "".
func row_names_on(lattice: String = "") -> PackedStringArray:
    var out := PackedStringArray()
    for k in rows:
        if lattice == "" or lattice_of(str(k)) == lattice:
            out.append(str(k))
    out.sort()
    return out


## The row as the axis indexes it. Empty if the bundle does not carry it.
func row_values(row: String, group: int = 0) -> PackedFloat64Array:
    var r: Dictionary = rows.get(row, {})
    var vals: Array = r.get("values", [])
    if group < 0 or group >= vals.size():
        return PackedFloat64Array()
    return vals[group]


## The group axis of a taxon-dimensioned row, in the order it is indexed.
func row_groups(row: String) -> PackedStringArray:
    var r: Dictionary = rows.get(row, {})
    return r.get("groups", PackedStringArray())


func row_names() -> PackedStringArray:
    var out := PackedStringArray()
    for k in rows:
        out.append(str(k))
    out.sort()
    return out


## Position of one key on the residence axis, or -1. The reverse map is built
## on first ask and kept: it depends on the world and not on the moment.
func index_of(residence_key: String) -> int:
    if _index.is_empty() and not cell_keys.is_empty():
        for i in cell_keys.size():
            _index[cell_keys[i]] = i
    return int(_index.get(residence_key, -1))


## The same, on the node axis.
func node_index_of(node_key: String) -> int:
    if _node_index.is_empty() and not node_keys.is_empty():
        for i in node_keys.size():
            _node_index[node_keys[i]] = i
    return int(_node_index.get(node_key, -1))


## HOW AN OVERLAY IS KEYED, IN ONE PLACE. A refinement names a cell and the
## taxon axis being refined within it, so the key is the pair. The format lives
## here rather than at the producer that writes it, because the reader is a
## different file from the writer and a string format with two authors is a
## format that can drift between them by a character.
static func refinement_key(residence_key: String, axis_node: String) -> String:
    return "%s|%s" % [residence_key, axis_node]


## The node one cell's axis is refined to, or "" where no overlay is present.
##
## "" IS THE COARSE RUNG, NOT A MISSED READ. Overlays are sent only where they
## are earned, so absence is the common case and the answer a consumer wants:
## draw the axis node itself. A caller that treated absence as a failure would
## refuse most of the basin.
func refined_to(residence_key: String, axis_node: String) -> String:
    return str(refinements.get(refinement_key(residence_key, axis_node), ""))


## Two bundles share a key axis when they describe the same world. A consumer
## that bound its own join against one may reuse it against the other, and this
## is the question it asks before doing so -- a mispainted basin is exactly what
## a silent axis change would look like.
func same_axis_as(other: PerceptBundle) -> bool:
    # BOTH AXES. A consumer holding a flow join and a ground join has bound two
    # of them, and an answer of "yes" that covered only one would be exactly as
    # wrong as no check at all for the half it did not look at.
    return (other != null and cell_keys == other.cell_keys
            and node_keys == other.node_keys)


## Everything the schema declares must be true of a bundle before it is used.
## Returns `{"ok": bool, "why": String}` -- a refusal is a first-class answer
## here, not an exception.
func check() -> Dictionary:
    if refused:
        return {"ok": false, "why": refusal}
    if not PRODUCER_KINDS.has(str(producer.get("kind", ""))):
        return {"ok": false, "why": "producer kind %s is not one this schema knows"
                % str(producer.get("kind", ""))}
    if observer_session == "":
        return {"ok": false, "why": "no observer session"}
    if not POSTURES.has(posture):
        return {"ok": false, "why": "posture %s is not one of %s" % [posture, str(POSTURES)]}
    if str(moment.get("window", "")) == "":
        return {"ok": false, "why": "no moment"}
    if not readouts.is_empty():
        return {"ok": false, "why": ("this schema version carries no readouts, and one arrived. "
                + "Interoception crosses in a masked form that v0 does not define; a readout "
                + "here would be an unmasked one by default.")}
    for row in rows:
        var r: Dictionary = rows[row]
        var groups: PackedStringArray = r.get("groups", PackedStringArray())
        var vals: Array = r.get("values", [])
        if groups.size() != vals.size():
            return {"ok": false, "why": "row %s has %d groups and %d value arrays"
                    % [str(row), groups.size(), vals.size()]}
        # AGAINST THE ROW'S OWN AXIS, NOT AGAINST THE RESIDENCE AXIS (978).
        # This loop used to compare every row to `cell_keys.size()`, which is
        # the single-axis fields region collapsing a lattice that has been
        # declared separately since v1.0. A node row was 1,154 long against a
        # 5,684-cell axis and the only way to satisfy the check was not to
        # carry it.
        var lat := str(r.get("lattice", "band"))
        if not AXIS_OF_LATTICE.has(lat):
            return {"ok": false, "why": ("row %s declares lattice `%s`, which has no key axis "
                    % [str(row), lat] + "in this schema. A lattice arrives by being declared "
                    + "here with an axis, never by a row naming it.")}
        var axis := axis_for(str(row))
        if axis.is_empty():
            return {"ok": false, "why": ("row %s rides the %s lattice and the bundle carries no "
                    % [str(row), lat] + "key axis for it. A row with no axis is a column of "
                    + "numbers nobody can join.")}
        for v in vals:
            if (v as PackedFloat64Array).size() != axis.size():
                return {"ok": false, "why": ("row %s is %d long against a %d-key %s axis"
                        % [str(row), (v as PackedFloat64Array).size(), axis.size(), lat])}
    return {"ok": true, "why": ""}


## The wire form. JSON-able, and the same document for the same inputs.
##
## `with_fields` false writes the header and the body alone, for a stream that
## records a body every frame against a channel 1 that changes once a day.
## The digest travels either way, so a reader can say WHICH channel 1 a
## bodies-only frame was carrying rather than assuming the last one it saw.
func to_dict(with_fields: bool = true) -> Dictionary:
    var out := {
        "header": {
            "schema_version": SCHEMA_VERSION.duplicate(),
            "producer": producer.duplicate(true),
            "observer_session": observer_session,
            "moment": moment.duplicate(),
        },
        "body": {
            "observation_point": Array(observation_point),
            "posture": posture,
            "locomotion": locomotion.duplicate(),
            "readouts": readouts.duplicate(),
        },
    }
    if not with_fields:
        return out
    var rows_out := {}
    for row in row_names():
        var r: Dictionary = rows[row]
        var vals: Array = []
        for v in (r.get("values", []) as Array):
            vals.append(Array(v as PackedFloat64Array))
        rows_out[row] = {"lattice": str(r.get("lattice", "band")),
                         "groups": Array(r.get("groups", PackedStringArray())),
                         "values": vals}
    out["fields"] = {
        "cell_keys": Array(cell_keys),
        "node_keys": Array(node_keys),
        "rows": rows_out,
        "refinements": refinements.duplicate(true),
    }
    out["subjects"] = subjects.duplicate(true)
    return out


## Read a document back, refusing anything the schema does not declare.
static func from_dict(doc: Dictionary) -> PerceptBundle:
    var b := PerceptBundle.new()
    var bad := _undeclared(doc, "root")
    if bad != "":
        return _refuse(b, bad)
    var header: Dictionary = doc.get("header", {})
    bad = _undeclared(header, "header")
    if bad != "":
        return _refuse(b, bad)
    var version: Dictionary = header.get("schema_version", {})
    if int(version.get("major", -1)) != int(SCHEMA_VERSION["major"]):
        return _refuse(b, "schema major %s against this client's %s"
                % [str(version.get("major", "?")), str(SCHEMA_VERSION["major"])])
    b.producer = header.get("producer", {})
    bad = _undeclared(b.producer, "producer")
    if bad != "":
        return _refuse(b, bad)
    b.observer_session = str(header.get("observer_session", ""))
    b.moment = header.get("moment", {})
    bad = _undeclared(b.moment, "moment")
    if bad != "":
        return _refuse(b, bad)

    var body: Dictionary = doc.get("body", {})
    bad = _undeclared(body, "body")
    if bad != "":
        return _refuse(b, bad)
    var p: Array = body.get("observation_point", [])
    if p.size() != 3:
        return _refuse(b, "the observation point is not three numbers")
    b.observation_point = PackedFloat64Array([float(p[0]), float(p[1]), float(p[2])])
    b.posture = str(body.get("posture", ""))
    b.locomotion = body.get("locomotion", {})
    b.readouts = body.get("readouts", [])

    var fields: Dictionary = doc.get("fields", {})
    bad = _undeclared(fields, "fields")
    if bad != "":
        return _refuse(b, bad)
    for k in (fields.get("cell_keys", []) as Array):
        b.cell_keys.append(str(k))
    for k in (fields.get("node_keys", []) as Array):
        b.node_keys.append(str(k))
    var rows_in: Dictionary = fields.get("rows", {})
    for row in rows_in:
        var r: Dictionary = rows_in[row]
        # THE ROW LEVEL IS CLOSED TOO, and this is the structure rather than
        # the content: `lattice`, `groups`, `values` are the shape of a row and
        # an undeclared name here is a document carrying something the schema
        # does not have. What versions instead is which ROW NAMES arrive --
        # unknown ones are skipped and reported per the mismatch rule, because
        # rows are the additive half the version pair already governs.
        var bad_row := _undeclared(r, "row")
        if bad_row != "":
            return _refuse(b, "row %s: %s" % [str(row), bad_row])
        var groups := PackedStringArray()
        for g in (r.get("groups", []) as Array):
            groups.append(str(g))
        var vals: Array = []
        for v in (r.get("values", []) as Array):
            var packed := PackedFloat64Array()
            for x in (v as Array):
                packed.append(float(x))
            vals.append(packed)
        b.rows[str(row)] = {"lattice": str(r.get("lattice", "band")),
                            "groups": groups, "values": vals}
    b.refinements = fields.get("refinements", {})
    b.subjects = doc.get("subjects", {})
    return b


static func _refuse(b: PerceptBundle, why: String) -> PerceptBundle:
    b.refused = true
    b.refusal = why
    return b


## The name of the first key at this level that the schema does not declare,
## as a sentence, or "" when every key is one it knows.
static func _undeclared(d: Dictionary, level: String) -> String:
    var declared: Array = DECLARED.get(level, [])
    for k in d:
        if not declared.has(str(k)):
            return ("%s carries `%s`, which this schema does not declare. The schema is closed: "
                    % [level, str(k)]
                    + "a field arrives by being declared here, never by being sent.")
    return ""
