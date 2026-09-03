class_name SchemaLoader
extends RefCounted

## Reads the channel-1 schema artefact. Envelope first, then rows.
##
## THE POLICY HERE IS NOT INVENTED. The artefact states its own mismatch
## rules in `version_rule.mismatch`, verbatim:
##
##   "Checked unilaterally before the first delta is interpreted. Major
##    mismatch REFUSES, naming both versions and this sha. Same major,
##    server minor ahead: proceed, skipping AND REPORTING unknown names.
##    Same major, client minor ahead: proceed, masking rows whose `since`
##    exceeds the client's minor as undeclared -- never as zero."
##
## Every branch below is one clause of that. Where this file and the
## artefact disagree, the artefact wins and this file is the bug.
##
## THE THREE THINGS THAT ARE NEVER ZERO. "Never as zero" is the artefact's
## own phrase and it governs three cases here: a row masked as undeclared, a
## row skipped for an unknown `value_kind`, and a row whose `wire_rung` is
## outside its declared domain are all ABSENT, never present-with-a-default.
## A plausible zero is indistinguishable from a real measurement (§23.819).
##
## ENVELOPE FIRST, and not as a style preference: the envelope carries the
## version pair that decides whether the rows may be read at all, and the
## ladder set that a row's `taxon_rung` is validated against. Reading rows
## first would mean validating them against a contract not yet known.

## What this build was written against. Bumped deliberately, by a human,
## when the client is updated to a new artefact -- never read from the
## artefact itself, which would make every mismatch check vacuous.
## v2.0 is the first major advance this contract has taken. It removed
## `node.aft.population` and `node.wetland_extent` (their only writers are
## unimplemented subsystems, so they published as plausible zeros), dropped the
## `aft` ladder with its only referencing row, and removed `master_seed`,
## `subsystem_set` and the excluded-row count from the envelope. Before the bump
## this build refused the artefact and yielded zero rows, naming both versions
## and the artefact sha -- which is the mismatch rule working, and is the reason
## the constant is bumped by hand rather than read from the file.
const CLIENT_MAJOR: int = 2
const CLIENT_MINOR: int = 0

## Reasons a row did not make it into `Document.rows`. Reported, never silent.
const SKIP_UNKNOWN_VALUE_KIND := "unknown-value-kind"
const SKIP_WIRE_RUNG_OUTSIDE_DOMAIN := "wire-rung-outside-domain"
const SKIP_SINCE_AHEAD_OF_CLIENT := "since-ahead-of-client"
const SKIP_MALFORMED := "malformed-row"


static func load_from_text(text: String) -> SchemaTypes.Document:
    var doc := SchemaTypes.Document.new()
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return _refuse(doc, "artefact is not a JSON object")
    return _load(doc, parsed as Dictionary)


static func load_from_file(path: String) -> SchemaTypes.Document:
    var doc := SchemaTypes.Document.new()
    if not FileAccess.file_exists(path):
        return _refuse(doc, "no artefact at %s" % path)
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return _refuse(doc, "cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
    return load_from_text(f.get_as_text())


static func _refuse(doc: SchemaTypes.Document, why: String) -> SchemaTypes.Document:
    doc.refused = true
    doc.refusal_reason = why
    doc.reports.append("REFUSED: %s" % why)
    return doc


static func _load(doc: SchemaTypes.Document, raw: Dictionary) -> SchemaTypes.Document:
    # ---- envelope -------------------------------------------------------
    var env := SchemaTypes.Envelope.new()

    var vraw = raw.get("version")
    if typeof(vraw) != TYPE_DICTIONARY:
        return _refuse(doc, "artefact declares no version pair")
    env.version = SchemaTypes.Version.new(int(vraw.get("major", -1)), int(vraw.get("minor", -1)))
    if env.version.major < 0 or env.version.minor < 0:
        return _refuse(doc, "artefact's version pair is not two non-negative integers")

    env.content_digest_sha256 = str(raw.get("content_digest_sha256", ""))
    var prov = raw.get("provenance", {})
    if typeof(prov) == TYPE_DICTIONARY:
        env.emitted_at_commit = str(prov.get("commit", ""))
        env.generated_at_utc = str(prov.get("generated_at_utc", ""))

    var eraw = raw.get("envelope", {})
    if typeof(eraw) == TYPE_DICTIONARY:
        var d = eraw.get("wire_rung_domain", {})
        if typeof(d) == TYPE_DICTIONARY:
            env.wire_rung_domain = d
        var t = eraw.get("taxonomies", {})
        if typeof(t) == TYPE_DICTIONARY:
            env.taxonomies = t
    doc.envelope = env

    # ---- the version gate, before a single row is interpreted -----------
    if env.version.major != CLIENT_MAJOR:
        return _refuse(doc, ("major version mismatch: artefact %s, client %d.%d, artefact sha %s. "
                + "A major advance means a carried row was removed, renamed or changed, a ladder "
                + "changed, or an envelope field was removed or re-semanticised -- none of which "
                + "this build can interpret.") % [
                    env.version.as_string(), CLIENT_MAJOR, CLIENT_MINOR,
                    env.content_digest_sha256])

    if env.version.minor > CLIENT_MINOR:
        doc.reports.append(("server minor ahead: artefact %s, client %d.%d. Proceeding; unknown "
                + "names are skipped and reported below.") % [
                    env.version.as_string(), CLIENT_MAJOR, CLIENT_MINOR])
    elif env.version.minor < CLIENT_MINOR:
        doc.reports.append(("client minor ahead: artefact %s, client %d.%d. Rows whose `since` "
                + "exceeds %d are masked as undeclared -- never as zero.") % [
                    env.version.as_string(), CLIENT_MAJOR, CLIENT_MINOR, env.version.minor])

    # ---- rows -----------------------------------------------------------
    var rows_raw = raw.get("rows", [])
    if typeof(rows_raw) != TYPE_ARRAY:
        return _refuse(doc, "artefact's `rows` is not an array")

    for entry in rows_raw:
        if typeof(entry) != TYPE_DICTIONARY:
            doc.reports.append("%s: a row is not an object" % SKIP_MALFORMED)
            continue
        var row := _row_from(entry as Dictionary)
        if row == null:
            doc.reports.append("%s: %s" % [SKIP_MALFORMED, JSON.stringify(entry)])
            continue

        # §20.4.4: a client meeting a value_kind its envelope version does
        # not know skips the row as it would an unknown name. The domain
        # dictionary IS the set of known kinds -- not a hardcoded list here,
        # which would go stale the moment `subject` is authored (gap 153).
        if not env.wire_rung_domain.has(row.value_kind):
            doc.reports.append("%s: %s declares value_kind=%s, which this envelope does not define"
                    % [SKIP_UNKNOWN_VALUE_KIND, row.name, row.value_kind])
            continue

        var allowed = env.wire_rung_domain[row.value_kind]
        if typeof(allowed) == TYPE_ARRAY and not (row.wire_rung in allowed):
            doc.reports.append("%s: %s declares wire_rung=%s, outside %s's domain %s"
                    % [SKIP_WIRE_RUNG_OUTSIDE_DOMAIN, row.name, row.wire_rung,
                       row.value_kind, str(allowed)])
            continue

        # "masking rows whose `since` exceeds the client's minor as
        # undeclared -- never as zero". Only meaningful within a major,
        # which the gate above has already established.
        if row.since > CLIENT_MINOR:
            doc.reports.append("%s: %s has since=%d, ahead of client minor %d -- undeclared, not zero"
                    % [SKIP_SINCE_AHEAD_OF_CLIENT, row.name, row.since, CLIENT_MINOR])
            continue

        if row.has_taxon_rung:
            var axis := row.taxonomy_axis(env.taxonomies)
            if axis == "":
                doc.reports.append(("note: %s carries taxon_rung=%s but no dim matches a declared "
                        + "ladder; kept, because the ladder set is the envelope's and a client "
                        + "must not rule on it") % [row.name, row.taxon_rung])
            elif not (row.taxon_rung in env.taxonomies[axis]):
                doc.reports.append(("note: %s declares taxon_rung=%s, absent from %s's ladder %s; "
                        + "kept and reported") % [row.name, row.taxon_rung, axis,
                                                  str(env.taxonomies[axis])])

        doc.rows.append(row)

    return doc


## Returns null for a row missing a required field. Typed rather than bare,
## because an untyped return makes `var row := _row_from(...)` uninferable at
## the call site -- which is a parse error, not a warning, and took the whole
## project's import down with it on the first CI run.
static func _row_from(entry: Dictionary) -> SchemaTypes.Row:
    if not entry.has("name") or not entry.has("value_kind") or not entry.has("wire_rung"):
        return null
    var r := SchemaTypes.Row.new()
    r.name = str(entry["name"])
    r.unit = str(entry.get("unit", ""))
    var b = entry.get("bounds", [])
    if typeof(b) == TYPE_ARRAY and b.size() == 2:
        r.bounds_low = float(b[0])
        r.bounds_high = float(b[1])
    r.lattice = str(entry.get("lattice", ""))
    var dims = entry.get("dims", [])
    if typeof(dims) == TYPE_ARRAY:
        for d in dims:
            r.dims.append(str(d))
    r.value_kind = str(entry["value_kind"])
    r.wire_rung = str(entry["wire_rung"])

    # Conditional fields: PRESENCE is the signal, per the artefact's own
    # row_form_note -- "absent rather than null, mirroring the registry's
    # requiredness". `substrate` is treated as opaque: this contract binds
    # its presence and stability only, and its vocabulary is §16.3's side.
    if entry.has("taxon_rung"):
        r.has_taxon_rung = true
        r.taxon_rung = str(entry["taxon_rung"])
    if entry.has("substrate"):
        r.has_substrate = true
        r.substrate = str(entry["substrate"])

    r.since = int(entry.get("since", 0))
    return r
