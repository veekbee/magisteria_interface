class_name InspectorPanel
extends VBoxContainer

## M2a -- the schema-driven inspector, generated from the artefact ALONE.
##
## No fixture, no terrain, no data of any kind. That is the point of
## building it first: it makes the panel a living consumer of the contract
## from day one, so an envelope defect surfaces while it still costs a
## minor bump rather than after three phases have been built on it.
##
## It displays what a carried row DECLARES -- name, unit, bounds, lattice,
## dims, wire rung, and the taxonomy ladder when the row has one. It shows
## no values, because there are none: a placeholder zero here would be the
## same defect the contract refuses on the wire (§23.819).
##
## Rows the loader skipped are shown too, with the reason. A panel that
## silently rendered eight of ten rows would look exactly like a panel
## rendering ten.

const ARTEFACT_PATH := "res://contract/schema.json"

var document: SchemaTypes.Document = null


func _ready() -> void:
    if document == null:
        document = SchemaLoader.load_from_file(ARTEFACT_PATH)
    rebuild()


## Rebuilt rather than incrementally updated: the artefact is small, and a
## panel that can only be built once cannot be re-pointed at a new one.
func rebuild() -> void:
    for child in get_children():
        child.queue_free()

    if document == null:
        _line("No contract loaded.")
        return

    if document.refused:
        _heading("Contract REFUSED")
        _line(document.refusal_reason)
        _line("No rows are shown, because none may be interpreted.")
        return

    var env := document.envelope
    _heading("Contract v%s" % env.version.as_string())
    _line("digest    %s" % env.content_digest_sha256)
    _line("emitted   %s" % env.emitted_at_commit)
    _line("client    %d.%d" % [SchemaLoader.CLIENT_MAJOR, SchemaLoader.CLIENT_MINOR])
    _line("ladders   %s" % ", ".join(PackedStringArray(env.taxonomies.keys())))

    _heading("Carried rows (%d)" % document.rows.size())
    for row in document.rows:
        _row_block(row, env)

    if not document.reports.is_empty():
        _heading("Reported (%d)" % document.reports.size())
        for r in document.reports:
            _line(r)


func _row_block(row: SchemaTypes.Row, env: SchemaTypes.Envelope) -> void:
    _line("%s   [%s]" % [row.name, row.unit])
    _line("    bounds  %s .. %s" % [row.bounds_low, row.bounds_high])
    _line("    lattice %s   dims %s" % [row.lattice, ", ".join(row.dims)])
    _line("    wire    %s (%s)" % [row.wire_rung, row.value_kind])
    if row.has_taxon_rung:
        var axis := row.taxonomy_axis(env.taxonomies)
        var ladder = env.taxonomies.get(axis, [])
        _line("    taxon   %s on %s ladder [%s]" % [
                row.taxon_rung, axis, ", ".join(PackedStringArray(ladder))])
    if row.has_substrate:
        # Opaque by ruling: the vocabulary is §16.3's, not this repo's.
        _line("    substrate %s (opaque)" % row.substrate)


func _heading(text: String) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 18)
    add_child(l)


func _line(text: String) -> void:
    var l := Label.new()
    l.text = text
    add_child(l)
