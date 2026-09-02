extends SceneTree

## Hand-rolled headless tests. No framework, deliberately (see README):
## `godot --headless --script res://tests/run_headless.gd`.
##
## What is under test is the LOADER'S POLICY, not its plumbing. The artefact
## states its own mismatch rules, so each test below names the clause it
## pins. The real artefact is exercised too, but only for the things a real
## file can say that a fixture cannot -- that conditional presence actually
## occurs in it, and that the shipped contract loads clean.

var _failures: Array[String] = []
var _checks: int = 0


func _initialize() -> void:
    test_real_artefact_loads_clean()
    test_conditional_fields_are_presence_not_empty_string()
    test_major_mismatch_refuses_and_names_both_versions()
    test_unknown_value_kind_is_skipped_and_reported()
    test_wire_rung_outside_its_domain_is_skipped()
    test_a_row_from_a_future_minor_is_masked_never_zeroed()
    test_the_inspector_builds_from_a_document()

    print("")
    if _failures.is_empty():
        print("OK -- %d checks passed" % _checks)
        quit(0)
    else:
        for f in _failures:
            printerr("FAIL: %s" % f)
        printerr("%d of %d checks failed" % [_failures.size(), _checks])
        quit(1)


func check(cond: bool, what: String) -> void:
    _checks += 1
    if not cond:
        _failures.append(what)


# --------------------------------------------------------------------------
# the real artefact
# --------------------------------------------------------------------------

func test_real_artefact_loads_clean() -> void:
    var doc := SchemaLoader.load_from_file("res://contract/schema.json")
    check(not doc.refused, "the shipped contract was refused: %s" % doc.refusal_reason)
    check(doc.envelope != null, "no envelope parsed from the shipped contract")
    if doc.envelope == null:
        return
    check(doc.envelope.version.major == SchemaLoader.CLIENT_MAJOR,
            "shipped contract's major is not the client's")
    check(doc.rows.size() > 0, "shipped contract yielded no rows")
    check(doc.envelope.taxonomies.has("pft") and doc.envelope.taxonomies.has("aft"),
            "both taxonomy ladders should be declared in the envelope")
    # A skip here would mean the shipped artefact carries something this build
    # cannot read -- which is exactly what CI exists to catch on a bump.
    check(doc.reports.is_empty(),
            "the shipped contract produced reports, which the pinned version should not: %s"
            % str(doc.reports))
    print("real artefact: v%s, %d rows, %d reports"
            % [doc.envelope.version.as_string(), doc.rows.size(), doc.reports.size()])


func test_conditional_fields_are_presence_not_empty_string() -> void:
    ## row_form_note: "`taxon_rung` is present iff `dims` carry a decision 846
    ## taxonomy row, and `substrate` iff declared -- absent rather than null".
    var doc := SchemaLoader.load_from_file("res://contract/schema.json")
    var with_taxon := 0
    var with_substrate := 0
    for row in doc.rows:
        if row.has_taxon_rung:
            with_taxon += 1
            check(row.taxon_rung != "", "%s has taxon_rung present but empty" % row.name)
            check(row.taxonomy_axis(doc.envelope.taxonomies) != "",
                    "%s carries a taxon_rung but no dim matches a declared ladder" % row.name)
        if row.has_substrate:
            with_substrate += 1
    check(with_taxon > 0, "no row carries taxon_rung -- conditional presence is untested")
    # Not a bug: no quantity declares a substrate yet, because the vocabulary
    # is §16.3's unruled side. Asserted so that the day one does, this says so.
    check(with_substrate == 0,
            "a row now declares `substrate` (%d of them) -- the vocabulary is §16.3's; check that "
            % with_substrate + "the value is a ruled one before relaxing this")
    print("conditional presence: %d rows with taxon_rung, %d with substrate"
            % [with_taxon, with_substrate])


# --------------------------------------------------------------------------
# the mismatch clauses, on constructed artefacts
# --------------------------------------------------------------------------

func _artefact(version: Dictionary, rows: Array) -> String:
    return JSON.stringify({
        "artefact": "test",
        "version": version,
        "content_digest_sha256": "deadbeef",
        "provenance": {"commit": "repo@0000000000000000000000000000000000000000"},
        "envelope": {
            "wire_rung_domain": {"field": ["internal", "coarse", "fine"]},
            "taxonomies": {"pft": ["life_form", "functional", "specific"]},
        },
        "rows": rows,
    })


func _row(name: String, extra: Dictionary = {}) -> Dictionary:
    var r := {
        "name": name, "unit": "fraction", "bounds": [0.0, 1.0], "lattice": "band",
        "dims": ["node", "band"], "value_kind": "field", "wire_rung": "fine", "since": 0,
    }
    for k in extra:
        r[k] = extra[k]
    return r


func test_major_mismatch_refuses_and_names_both_versions() -> void:
    ## "Major mismatch REFUSES, naming both versions and this sha."
    var text := _artefact({"major": SchemaLoader.CLIENT_MAJOR + 1, "minor": 0},
                          [_row("band.wetness")])
    var doc := SchemaLoader.load_from_text(text)
    check(doc.refused, "a major mismatch must refuse")
    check(doc.rows.is_empty(), "a refused contract must yield no rows")
    check(doc.refusal_reason.contains("%d.0" % (SchemaLoader.CLIENT_MAJOR + 1)),
            "refusal must name the artefact's version: %s" % doc.refusal_reason)
    check(doc.refusal_reason.contains("deadbeef"),
            "refusal must name the artefact's sha: %s" % doc.refusal_reason)


func test_unknown_value_kind_is_skipped_and_reported() -> void:
    ## §20.4.4: "A client meeting a value_kind its envelope version does not
    ## know skips the row as it would an unknown name." `subject` is the live
    ## case -- it has no declared domain (§24 gap 153).
    var text := _artefact({"major": SchemaLoader.CLIENT_MAJOR, "minor": SchemaLoader.CLIENT_MINOR},
                          [_row("band.wetness"), _row("thing.mood", {"value_kind": "subject"})])
    var doc := SchemaLoader.load_from_text(text)
    check(doc.rows.size() == 1, "the unknown value_kind row should have been skipped")
    check(doc.row_named("thing.mood") == null, "the skipped row must not be present at all")
    check(_reported(doc, SchemaLoader.SKIP_UNKNOWN_VALUE_KIND),
            "a skip must be reported, never silent: %s" % str(doc.reports))


func test_wire_rung_outside_its_domain_is_skipped() -> void:
    var text := _artefact({"major": SchemaLoader.CLIENT_MAJOR, "minor": SchemaLoader.CLIENT_MINOR},
                          [_row("band.wetness", {"wire_rung": "telepathic"})])
    var doc := SchemaLoader.load_from_text(text)
    check(doc.rows.is_empty(), "a wire_rung outside the declared domain must not be carried")
    check(_reported(doc, SchemaLoader.SKIP_WIRE_RUNG_OUTSIDE_DOMAIN),
            "domain violation must be reported: %s" % str(doc.reports))


func test_a_row_from_a_future_minor_is_masked_never_zeroed() -> void:
    ## "Same major, client minor ahead: proceed, masking rows whose `since`
    ## exceeds the client's minor as undeclared -- NEVER as zero."
    var text := _artefact({"major": SchemaLoader.CLIENT_MAJOR, "minor": SchemaLoader.CLIENT_MINOR},
                          [_row("band.wetness"),
                           _row("band.future", {"since": SchemaLoader.CLIENT_MINOR + 1})])
    var doc := SchemaLoader.load_from_text(text)
    check(not doc.refused, "a minor difference must not refuse")
    check(doc.row_named("band.future") == null,
            "a row ahead of the client's minor must be ABSENT, not present with a default")
    check(doc.row_named("band.wetness") != null, "the known row must still be carried")
    check(_reported(doc, SchemaLoader.SKIP_SINCE_AHEAD_OF_CLIENT),
            "masking must be reported: %s" % str(doc.reports))


func _reported(doc, needle: String) -> bool:
    for r in doc.reports:
        if r.contains(needle):
            return true
    return false


# --------------------------------------------------------------------------
# the panel
# --------------------------------------------------------------------------

func test_the_inspector_builds_from_a_document() -> void:
    ## M2a's whole claim is that the panel is generated from the artefact
    ## alone. So: give it one, and check it produced something per row.
    var panel := InspectorPanel.new()
    panel.document = SchemaLoader.load_from_file("res://contract/schema.json")
    panel.rebuild()
    var n := panel.get_child_count()
    check(n >= panel.document.rows.size(),
            "the panel rendered %d nodes for %d rows" % [n, panel.document.rows.size()])
    panel.free()
    print("inspector: %d nodes rendered" % n)
