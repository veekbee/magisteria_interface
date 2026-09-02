class_name SchemaTypes
extends RefCounted

## Typed structures for the channel-1 schema artefact (§20.4.4, decisions
## 893-895). Types only -- no parsing, no policy. `schema_loader.gd` owns
## both.
##
## Fields mirror the artefact's own `row_form` exactly, including which
## ones are CONDITIONAL. `taxon_rung` is present iff `dims` carry a
## taxonomy axis, and `substrate` iff declared -- absent rather than null,
## mirroring the registry's requiredness. Representing "absent" as an
## empty string would erase that distinction on the one field whose
## vocabulary is not yet ruled, so both carry an explicit `has_` flag.


## One carried quantity.
class Row extends RefCounted:
    var name: String = ""
    var unit: String = ""
    var bounds_low: float = 0.0
    var bounds_high: float = 0.0
    var lattice: String = ""
    var dims: PackedStringArray = PackedStringArray()
    var value_kind: String = ""
    var wire_rung: String = ""

    ## Conditional. See the class docstring -- absent is not "".
    var has_taxon_rung: bool = false
    var taxon_rung: String = ""
    var has_substrate: bool = false
    var substrate: String = ""

    var since: int = 0

    ## Which taxonomy axis this row is dimensioned on, or "" for none.
    ## Derived from `dims` against the envelope's declared ladders rather
    ## than assumed from the name: `band.pft.biomass` happens to spell its
    ## axis, and nothing in the contract promises that it always will.
    func taxonomy_axis(ladders: Dictionary) -> String:
        for d in dims:
            if ladders.has(d):
                return d
        return ""

    func _to_string() -> String:
        return "Row(%s %s %s/%s)" % [name, unit, lattice, wire_rung]


## The declared version pair. Ordering is by major then minor; `since` is
## only comparable WITHIN a major, which is why the emitter resets it at a
## major advance and why nothing here compares a `since` across one.
class Version extends RefCounted:
    var major: int = 0
    var minor: int = 0

    func _init(a: int = 0, b: int = 0) -> void:
        major = a
        minor = b

    func as_string() -> String:
        return "%d.%d" % [major, minor]


## Everything above the rows.
class Envelope extends RefCounted:
    ## value_kind -> allowed wire_rung values. Declared for "field" only;
    ## "subject" has no authored domain (§24 gap 153).
    var wire_rung_domain: Dictionary = {}
    ## axis name -> ordered rungs, coarsest first. Ladders name rungs.
    ## Palettes -- the members -- are excluded at every rung (§23.773) and
    ## must never be reconstructed or hardcoded here.
    var taxonomies: Dictionary = {}
    var version: Version = null
    var content_digest_sha256: String = ""
    var emitted_at_commit: String = ""
    var generated_at_utc: String = ""


## The artefact as a whole, plus what the loader had to say about it.
class Document extends RefCounted:
    var envelope: Envelope = null
    var rows: Array = []            ## of Row, in artefact order
    var reports: Array = []         ## of String -- see SchemaLoader.reports
    var refused: bool = false
    var refusal_reason: String = ""

    func row_named(n: String):
        for r in rows:
            if r.name == n:
                return r
        return null
