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
var _scene_root: Node = null
var _frames: int = 0

## `_ready()` is deferred to the first frame -- it does NOT fire synchronously
## on `add_child` -- so the scene test cannot run inside `_initialize()`. It is
## staged here and asserted from `_process`. That is not a detail: a probe that
## checked immediately after `add_child` reported the panel empty and looked
## exactly like a real defect.
const SCENE_FRAMES := 3


func _initialize() -> void:
    test_real_artefact_loads_clean()
    test_conditional_fields_are_presence_not_empty_string()
    test_major_mismatch_refuses_and_names_both_versions()
    test_unknown_value_kind_is_skipped_and_reported()
    test_wire_rung_outside_its_domain_is_skipped()
    test_a_row_from_a_future_minor_is_masked_never_zeroed()
    test_the_inspector_builds_from_a_document()
    test_the_heightfield_decodes_to_real_elevations()
    test_bicubic_reproduces_texel_values_exactly()
    test_bicubic_does_not_terrace()
    test_a_nodata_neighbourhood_returns_nan_not_a_height()
    test_the_terrain_mesh_holes_rather_than_walls_at_nodata()
    test_a_mesh_position_recovers_the_texel_it_was_sampled_from()
    test_flowlines_drape_and_keep_their_orders()
    test_no_lattice_geometry_reaches_the_scene()
    test_the_camera_rig_offers_both_projections()
    test_the_residence_layer_aligns_with_the_heightfield()
    test_residence_keys_never_land_where_there_is_no_ground()
    test_the_fixture_loads_and_says_what_it_refused()
    test_every_keyed_pixel_joins_to_a_cell()
    test_decoded_values_stay_inside_the_contracts_bounds()
    test_nodata_decodes_to_nan_and_never_to_zero()
    test_the_ramp_is_ordered_and_bounds_come_from_the_contract()
    test_node_rows_arrive_at_full_precision()
    test_every_reach_carries_a_node_so_flow_can_be_drawn()
    test_the_flow_mapping_distinguishes_zero_from_below_scale()
    test_quantisation_uses_the_realised_range_not_the_contracts()
    test_burn_asks_about_magnitude_before_geometry()
    stage_the_main_scene()


func _process(_delta: float) -> bool:
    _frames += 1
    if _frames < SCENE_FRAMES:
        return false
    test_the_main_scene_populated_itself()
    _finish()
    return true


func _finish() -> void:
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
    # `aft` left the envelope at v2.0 with the only row that referenced it.
    # A ladder is owed for an axis a carried row uses, and for no other -- so
    # this checks the rule rather than the pair it happened to produce.
    check(not doc.envelope.taxonomies.is_empty(),
            "a carried row references a taxonomy axis, so a ladder is owed")
    for axis in doc.envelope.taxonomies:
        var used := false
        for r in doc.rows:
            if r.dims.has(axis):
                used = true
        check(used, "ladder %s is declared and no carried row references it" % axis)
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


# --------------------------------------------------------------------------
# the scene as it actually runs
# --------------------------------------------------------------------------

func stage_the_main_scene() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    check(packed != null, "main.tscn did not load as a PackedScene")
    if packed == null:
        return
    _scene_root = packed.instantiate()
    check(_scene_root != null, "main.tscn did not instantiate")
    if _scene_root != null:
        get_root().add_child(_scene_root)


func test_the_main_scene_populated_itself() -> void:
    """The path the application actually takes, which every test above
    bypasses: main.tscn loads, InspectorPanel._ready() reads the artefact off
    disk with nobody handing it one, and the panel fills.

    The tests above construct the panel, assign `document` and call `rebuild()`
    directly. That proves the rendering and proves nothing about the wiring --
    a broken node path, a scene referencing a stale script, or a `_ready` that
    silently does nothing would leave all of them green. Running the scene
    headless proves nothing either: with zero reports and no refusal the app
    prints nothing, so exit 0 is what success AND what doing-nothing look like.
    """
    if _scene_root == null:
        return
    var insp = _scene_root.get_node_or_null("UI/Scroll/Inspector")
    check(insp != null, "main.tscn has no UI/Scroll/Inspector node -- the path in main.gd is stale")
    if insp == null:
        return
    check(insp.document != null,
            "the panel's _ready() did not load the artefact after %d frames" % _frames)
    if insp.document == null:
        return
    check(not insp.document.refused,
            "the scene refused the shipped contract: %s" % insp.document.refusal_reason)
    check(insp.document.rows.size() > 0, "the scene loaded a contract with no rows")
    check(insp.get_child_count() > 0,
            "the panel rendered nothing from a %d-row contract" % insp.document.rows.size())
    print("main scene: %d rows, %d nodes rendered by _ready()"
            % [insp.document.rows.size(), insp.get_child_count()])

    # M1's half of the same scene. The two consume different artefacts and the
    # report says which did what, so a terrain failure cannot hide behind a
    # rendered inspector.
    var rep: Dictionary = _scene_root.terrain_report
    check(rep.get("ok", false), "the scene's terrain did not build: %s" % rep.get("why", "?"))
    if rep.get("ok", false):
        check(int(rep["vertices"]) > 1000, "terrain built %d vertices" % rep["vertices"])
        check(int(rep["reaches_drawn"]) > 20000,
                "terrain drew %d reaches" % rep["reaches_drawn"])
        check(_scene_root.get_node_or_null("TerrainView/Terrain") != null,
                "no Terrain mesh instance in the running scene")
        check(_scene_root.get_node_or_null("TerrainView/Hillshade") != null,
                "no hillshade light -- relief would render flat")
        print("main scene terrain: %d verts, %d reaches"
                % [rep["vertices"], rep["reaches_drawn"]])


# --------------------------------------------------------------------------
# M1 -- the terrain viewer
# --------------------------------------------------------------------------

const TERRAIN_DIR := "res://assets/terrain/"

var _hf: Heightfield = null


func heightfield() -> Heightfield:
    if _hf == null:
        var f := FileAccess.open(TERRAIN_DIR + "terrain_export.json", FileAccess.READ)
        var man: Dictionary = JSON.parse_string(f.get_as_text())
        _hf = Heightfield.load_from(man, TERRAIN_DIR + "heightfield_overview.png")
    return _hf


func test_the_heightfield_decodes_to_real_elevations() -> void:
    """The encoding survives the engine. Height is in two BYTES -- a single
    16-bit channel is loaded as L8 and silently loses the low one -- so what is
    checked is that the decoded range is the basin's, not that a file loaded."""
    var hf := heightfield()
    check(hf.is_loaded(), "the heightfield did not load")
    if not hf.is_loaded():
        return
    var lo := 1e30
    var hi := -1e30
    var n := 0
    for y in range(0, hf.height, 7):
        for x in range(0, hf.width, 7):
            var h := hf.height_at_texel(x, y)
            if not is_nan(h):
                n += 1
                lo = min(lo, h)
                hi = max(hi, h)
    check(n > 10000, "only %d ground texels found" % n)
    check(lo > -50.0 and lo < 50.0, "basin floor decoded as %.1f m" % lo)
    check(hi > 3000.0 and hi < 5000.0, "basin ceiling decoded as %.1f m" % hi)
    print("heightfield: %d ground texels, %.1f .. %.1f m" % [n, lo, hi])


func test_bicubic_reproduces_texel_values_exactly() -> void:
    """Catmull-Rom is interpolating, not approximating: at a texel centre it
    must return that texel. A scheme that merely passes near them would drift
    the whole surface off the data it was built from."""
    var hf := heightfield()
    var worst := 0.0
    var checked := 0
    for y in range(6, hf.height - 6, 97):
        for x in range(6, hf.width - 6, 73):
            var exact := hf.height_at_texel(x, y)
            var interp := hf.height_at(float(x), float(y))
            if is_nan(exact) or is_nan(interp):
                continue
            worst = max(worst, abs(exact - interp))
            checked += 1
    check(checked > 50, "only %d interior samples" % checked)
    check(worst < 1e-6, "bicubic misses texel centres by up to %f m" % worst)


func test_bicubic_does_not_terrace() -> void:
    """§16.5's first visible defect. A midpoint between two different texels
    must lie strictly between them; snapping to either is nearest-neighbour
    wearing an interpolator's name."""
    var hf := heightfield()
    var strictly_between := 0
    var snapped := 0
    for y in range(20, hf.height - 20, 149):
        for x in range(20, hf.width - 20, 113):
            var a := hf.height_at_texel(x, y)
            var b := hf.height_at_texel(x + 1, y)
            var mid := hf.height_at(float(x) + 0.5, float(y))
            if is_nan(a) or is_nan(b) or is_nan(mid) or is_equal_approx(a, b):
                continue
            if is_equal_approx(mid, a) or is_equal_approx(mid, b):
                snapped += 1
            else:
                strictly_between += 1
    check(strictly_between > 5, "only %d interpolated midpoints" % strictly_between)
    check(snapped == 0, "%d midpoints snapped to a neighbour -- that is terracing" % snapped)
    print("bicubic: %d midpoints strictly between neighbours, %d snapped"
            % [strictly_between, snapped])


func test_a_nodata_neighbourhood_returns_nan_not_a_height() -> void:
    """Zero is sea level and this basin's floor is -6.39 m, so a sentinel that
    is also a value would build a plateau at the boundary."""
    var hf := heightfield()
    check(is_nan(hf.height_at_texel(-1, 10)), "a texel left of the raster returned a height")
    check(is_nan(hf.height_at_texel(hf.width + 5, 10)), "a texel right of the raster returned a height")
    check(is_nan(hf.height_at(-4.0, -4.0)), "bicubic outside the raster returned a height")


func test_the_terrain_mesh_holes_rather_than_walls_at_nodata() -> void:
    var hf := heightfield()
    var tm := TerrainMesh.new()
    var m := tm.build(hf, 8, 1.0)
    check(m.get_surface_count() == 1, "the mesh has %d surfaces" % m.get_surface_count())
    check(tm.vertex_count > 1000, "only %d vertices" % tm.vertex_count)
    check(tm.skipped_quads > 0,
            "no quad was skipped -- nodata is being filled rather than left open")
    var aabb := m.get_aabb()
    check(aabb.size.x > 500000.0 and aabb.size.z > 500000.0,
            "the mesh spans %.0f x %.0f m, which is not this basin" % [aabb.size.x, aabb.size.z])
    print("mesh: %d verts, %d quads, %d skipped at nodata"
            % [tm.vertex_count, tm.quad_count, tm.skipped_quads])


func test_a_mesh_position_recovers_the_texel_it_was_sampled_from() -> void:
    """M4's probe reads a world position back off the mesh, and until it did
    nothing ever asked for the inverse. Every vertex sits at a sampled texel,
    so the round trip has to land on one: a half-texel slip is invisible in
    the surface, survives every M1 check, and names the neighbouring cell
    wherever a probe lands near a residence boundary.

    Checked by resampling: the height at the recovered texel must be the
    height the vertex was built with. That pins the offset rather than the
    arithmetic, so it fails whichever of the two transforms drops the term."""
    var hf := heightfield()
    var tm := TerrainMesh.new()
    var m := tm.build(hf, 8, 1.0)
    var verts: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    check(verts.size() > 1000, "only %d vertices to sample" % verts.size())
    var off_grid := 0
    var off_height := 0
    var not_inverse := 0
    var sampled := 0
    for n in range(0, verts.size(), 397):
        var v := verts[n]
        var w := tm.mesh_to_world(v, hf)
        var t := hf.world_to_texel(w.x, w.y)
        if absf(t.x - roundf(t.x)) > 1e-3 or absf(t.y - roundf(t.y)) > 1e-3:
            off_grid += 1
        elif int(roundf(t.x)) % tm.stride != 0 or int(roundf(t.y)) % tm.stride != 0:
            off_grid += 1
        var h := hf.height_at(t.x, t.y)
        if is_nan(h) or absf(h - v.y) > 0.05:
            off_height += 1
        var back := tm.world_to_mesh(w, hf)
        if absf(back.x - v.x) > 1e-3 or absf(back.y - v.z) > 1e-3:
            not_inverse += 1
        sampled += 1
    check(sampled > 20, "only %d vertices sampled" % sampled)
    check(off_grid == 0,
            "%d of %d mesh positions do not land on a sampled texel" % [off_grid, sampled])
    check(off_height == 0,
            "%d of %d recovered positions resample to a different height than the "
            % [off_height, sampled] + "vertex was built with")
    check(not_inverse == 0,
            "%d of %d positions do not survive world -> mesh -> world" % [not_inverse, sampled])
    print("mesh<->world: %d vertices round-trip onto their own texel" % sampled)


func test_flowlines_drape_and_keep_their_orders() -> void:
    """M3 keys streamflow onto the comid, and stream order is what M1 can draw
    with today. A drape that lost either would be decoration."""
    var hf := heightfield()
    var tm := TerrainMesh.new()
    tm.build(hf, 8, 1.0)
    var f := FileAccess.open(TERRAIN_DIR + "flowlines.json", FileAccess.READ)
    var doc: Dictionary = JSON.parse_string(f.get_as_text())
    var drape := FlowlineDrape.new()
    var by_order := drape.build(doc.get("reaches", []), hf, tm)
    check(by_order.size() >= 4, "only %d stream orders drawn" % by_order.size())
    check(drape.reach_count > 20000, "only %d reaches drawn" % drape.reach_count)
    check(drape.dropped_offmap < drape.reach_count / 100,
            "%d reaches fell off the heightfield" % drape.dropped_offmap)
    print("flowlines: %d reaches over %d orders, %d off-map"
            % [drape.reach_count, by_order.size(), drape.dropped_offmap])


func test_no_lattice_geometry_reaches_the_scene() -> void:
    """Decision 890, asserted against the built scene rather than intended.
    Cell outlines and patch grids must not exist as geometry, and there is no
    debugging exception -- the moment they exist, something draws them."""
    var v := TerrainView.new()
    get_root().add_child(v)
    var r := v.build()
    check(r.get("ok", false), "the terrain view did not build: %s" % r.get("why", ""))
    for child in v.get_children():
        var n := String(child.name).to_lower()
        for forbidden in ["cell", "patch", "band", "lattice"]:
            check(not n.contains(forbidden),
                    "a node named for a lattice is in the scene: %s" % child.name)
    check(int(r.get("lattice_geometry", -1)) == 0, "the view reports lattice geometry")
    v.queue_free()


func test_the_camera_rig_offers_both_projections() -> void:
    """A heightfield is read two ways -- relief from a perspective camera, and
    geography from an orthographic one. One camera would make the viewer good
    at only half of what M1 is for."""
    var rig := CameraRig.new()
    get_root().add_child(rig)
    rig.setup(AABB(Vector3.ZERO, Vector3(1000000, 4000, 1500000)))
    check(rig.ortho != null and rig.fly != null, "the rig is missing a camera")
    check(rig.ortho.projection == Camera3D.PROJECTION_ORTHOGONAL, "ortho is not orthographic")
    check(rig.using_ortho(), "the rig should start top-down")
    rig.toggle()
    check(not rig.using_ortho(), "toggle did not switch projection")
    check(rig.fly.current, "the fly camera is not current after toggling")
    rig.queue_free()


# --------------------------------------------------------------------------
# M2 -- field overlays
# --------------------------------------------------------------------------

const FIXTURE_DIR := "res://assets/fixture/"

var _rl: ResidenceLayer = null
var _fl: FixtureLoader = null


func residence() -> ResidenceLayer:
    if _rl == null:
        var f := FileAccess.open(TERRAIN_DIR + "residence_overview.json", FileAccess.READ)
        _rl = ResidenceLayer.load_from(JSON.parse_string(f.get_as_text()),
                TERRAIN_DIR + "residence_overview.png")
    return _rl


func fixture() -> FixtureLoader:
    if _fl == null:
        _fl = FixtureLoader.load_from(FIXTURE_DIR)
    return _fl


func test_the_residence_layer_aligns_with_the_heightfield() -> void:
    """Both layers are built on ONE transform on the server. If they disagree
    here, every field is drawn some pixels off its own terrain and nothing
    else in the client would report it."""
    var rl := residence()
    var hf := heightfield()
    check(rl.is_loaded(), "the residence layer did not load")
    check(rl.width == hf.width and rl.height == hf.height,
            "residence %dx%d against heightfield %dx%d"
            % [rl.width, rl.height, hf.width, hf.height])
    check(rl.node_of_index.size() > 1000,
            "only %d nodes in the index" % rl.node_of_index.size())
    print("residence: %dx%d, %d nodes" % [rl.width, rl.height, rl.node_of_index.size()])


func test_residence_keys_never_land_where_there_is_no_ground() -> void:
    """A key with nothing to draw on would be a place the client cannot show
    and the server thinks exists. The converse IS allowed and measured: some
    ground has no key, and M2 renders it as nodata rather than colouring it."""
    var rl := residence()
    var hf := heightfield()
    var keyed_no_ground := 0
    var ground_no_key := 0
    for y in range(0, rl.height, 3):
        for x in range(0, rl.width, 3):
            var has_key := not rl.key_at(x, y).is_empty()
            var has_ground := not is_nan(hf.height_at_texel(x, y))
            if has_key and not has_ground:
                keyed_no_ground += 1
            elif has_ground and not has_key:
                ground_no_key += 1
    check(keyed_no_ground == 0,
            "%d pixels carry a residence key with no terrain" % keyed_no_ground)
    print("coverage: %d sampled ground pixels have no key (rendered as nodata)"
            % ground_no_key)


func test_the_fixture_loads_and_says_what_it_refused() -> void:
    """A row the build could not carry must be visible to the client. Omitting
    it silently would make an open design question look like a design.

    At v1.0 that row was `node.aft.population` -- 15 palette members against a
    14-wide engine axis. v2.0 made it `internal`, so today there is nothing to
    refuse and the assertion is conditional: IF a row is refused it must carry
    a reason and must not also be carried."""
    var fl := fixture()
    check(fl.is_loaded(), "the fixture did not load")
    check(fl.n_cells > 5000, "only %d cells" % fl.n_cells)
    check(fl.windows.size() >= 2, "only %d windows" % fl.windows.size())
    var rows := fl.row_names(fl.windows[0])
    check(rows.size() >= 6, "only %d rows carried" % rows.size())

    # This asserted that at least one row WAS refused, because
    # `node.aft.population` always was -- the aft palette has 15 members
    # against a 14-wide engine axis. Contract v2.0 made that row `internal`
    # (decision 901: its only writer is unimplemented), so it is no longer in
    # the carried set and there is nothing left for the build to refuse. The
    # property was never "one row is refused"; it is "a refusal is legible",
    # and pinning the count pinned a transient state instead.
    var refused: Dictionary = fl.refused_rows.get(fl.windows[0], {})
    for k in refused:
        check(str(refused[k]).length() > 30, "%s is refused without a reason" % k)
        check(not rows.has(k), "%s is both carried and refused" % k)
    print("fixture: %d cells, %d rows, refused %s" % [fl.n_cells, rows.size(), str(refused.keys())])


func test_every_keyed_pixel_joins_to_a_cell() -> void:
    """The join is the whole of M2. A key that resolves to no cell is a pixel
    the client can locate and cannot colour, and it would show as a hole with
    no explanation."""
    var rl := residence()
    var fl := fixture()
    var joined := 0
    var orphan := 0
    for y in range(0, rl.height, 5):
        for x in range(0, rl.width, 5):
            var k := rl.key_at(x, y)
            if k.is_empty():
                continue
            var huc: String = rl.node_of_index.get(k[0], "")
            if fl.cell_of_key.has("%s|%d" % [huc, k[1]]):
                joined += 1
            else:
                orphan += 1
    check(joined > 10000, "only %d pixels joined" % joined)
    check(orphan == 0, "%d keyed pixels resolve to no cell" % orphan)
    print("join: %d pixels resolved, %d orphaned" % [joined, orphan])


func test_decoded_values_stay_inside_the_contracts_bounds() -> void:
    """The client fixture is quantised over the CONTRACT's bounds, so a decoded
    value outside them means the encoding and the manifest disagree."""
    var fl := fixture()
    var w: String = fl.windows[0]
    var rows := fl.row_names(w)
    var checked := 0
    for row in rows:
        var d: Dictionary = {}
        for k in fl.manifest["client_form"]["rows"]:
            var cand: Dictionary = fl.manifest["client_form"]["rows"][k]
            if str(cand["row"]) == row and str(cand["window"]) == w:
                d = cand
                break
        if d.is_empty():
            continue
        var lo := float(d["lo"])
        var hi := float(d["hi"])
        if hi <= lo:
            continue        # an all-zero row has no range to test
        var vals := fl.day_values(w, row, 0)
        # A row's width is its LATTICE's, not the cell count: node rows are
        # 1,154 wide and band rows 5,684. Asserting one number for both was
        # assuming every carried row lives on the band lattice, which stopped
        # being true the moment M3 needed streamflow.
        var expected := int(d["shape"][1])
        check(vals.size() == expected,
                "%s gave %d values, its shape says %d" % [row, vals.size(), expected])
        for i in range(0, vals.size(), 37):
            var v := vals[i]
            if is_nan(v):
                continue
            check(v >= lo - 1e-4 and v <= hi + 1e-4,
                    "%s decoded %f outside [%f, %f]" % [row, v, lo, hi])
        checked += 1
    check(checked >= 6, "only %d rows checked" % checked)


func test_nodata_decodes_to_nan_and_never_to_zero() -> void:
    """Zero is a real value for every band row here -- a dry cell, an unburnt
    one -- so a sentinel that is also a value would put real-looking data where
    there is none."""
    var fl := fixture()
    var vals := fl.day_values(fl.windows[0], "band.wetness", 0)
    var zeros := 0
    var nans := 0
    for v in vals:
        if is_nan(v):
            nans += 1
        elif v == 0.0:
            zeros += 1
    check(vals.size() > 0, "no values decoded")
    print("band.wetness day 0: %d cells, %d exact zeros, %d NAN" % [vals.size(), zeros, nans])


func test_the_ramp_is_ordered_and_bounds_come_from_the_contract() -> void:
    """A ramp whose lightness is not monotone reads as banded, which is
    terracing invented in the colour. And auto-ranging per day would make the
    scrubber a lie: the same colour would mean a different value each frame."""
    var prev := -1.0
    var monotone := true
    for i in 21:
        var c := FieldOverlay.ramp(float(i) / 20.0)
        var lum: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        if i > 0 and lum < prev - 0.12:
            monotone = false
        prev = max(prev, lum)
    check(monotone, "the ramp's lightness reverses -- it will read as banded")
    check(not FieldOverlay.ramp(0.0).is_equal_approx(FieldOverlay.ramp(1.0)),
            "the ramp's ends are the same colour")

    var fl := fixture()
    var d: Dictionary = fl.manifest["client_form"]["rows"].values()[0]
    check(d.has("lo") and d.has("hi"), "a row carries no bounds")
    check("bounds" in str(fl.manifest["client_form"]["is_a_display_encoding"]).to_lower()
            or "contract" in str(fl.manifest["client_form"]["is_a_display_encoding"]).to_lower(),
            "the client form does not say its bounds are the contract's")


# --------------------------------------------------------------------------
# M3 -- time and flow
# --------------------------------------------------------------------------

func test_node_rows_arrive_at_full_precision() -> void:
    """Streamflow reaches 4.9e-324 and 40.9% of its non-zero values are below
    1e-6. It is shipped as float64 and must be HELD as float64: a
    PackedFloat32Array flushes everything under 1.18e-38 to zero, which moves
    thousands of samples from "below the display scale" to "no flow" -- a
    different statement about the river."""
    var fl := fixture()
    var rows := fl.row_names(fl.windows[0], "node")
    check(rows.has("node.streamflow"), "no node.streamflow row: %s" % str(rows))
    var vals := fl.day_values(fl.windows[0], "node.streamflow", 45)
    check(vals.size() > 1000, "only %d nodes" % vals.size())
    var below_f32 := 0
    var zeros := 0
    for v in vals:
        if v == 0.0:
            zeros += 1
        elif v < 1.18e-38:
            below_f32 += 1
    check(below_f32 > 0,
            "no value below float32's floor survived -- the precision was lost in transit")
    print("streamflow: %d nodes, %d exact zeros, %d below float32's floor"
            % [vals.size(), zeros, below_f32])


func test_every_reach_carries_a_node_so_flow_can_be_drawn() -> void:
    """Flow is per node and geometry is per reach. A reach with no node is a
    river the client can draw and cannot ever light."""
    var f := FileAccess.open(TERRAIN_DIR + "flowlines.json", FileAccess.READ)
    var doc: Dictionary = JSON.parse_string(f.get_as_text())
    var reaches: Array = doc.get("reaches", [])
    var without := 0
    for r in reaches:
        if not r.has("node") or str(r["node"]) == "":
            without += 1
    check(reaches.size() > 20000, "only %d reaches" % reaches.size())
    check(without == 0, "%d reaches carry no node" % without)

    # and the node must resolve to a position on the node axis
    var fl := fixture()
    var unresolved := 0
    for i in range(0, reaches.size(), 97):
        if fl.node_index_of(str(reaches[i]["node"])) < 0:
            unresolved += 1
    check(unresolved == 0, "%d sampled reaches name a node not on the axis" % unresolved)


func test_the_flow_mapping_distinguishes_zero_from_below_scale() -> void:
    """13.2% of samples are exactly zero -- a state, not a small number -- and
    40.9% of the rest are below what any legible ramp resolves. Drawing those
    two the same as each other, or as "very little water", would be this
    project's plausible zero in the one place a viewer would never question."""
    var d := FlowDisplay.new()
    var zero := d.colour_for(0.0)
    var tiny := d.colour_for(1e-20)
    var mid := d.colour_for(1.0)
    check(not zero.is_equal_approx(tiny), "zero and below-scale render identically")
    check(not tiny.is_equal_approx(mid), "below-scale and in-scale render identically")
    check(d.n_zero == 1 and d.n_below == 1 and d.n_in_scale == 1,
            "the display does not count what it did")
    var desc := d.describe()
    check(bool(desc["provisional"]), "the mapping does not declare itself provisional")
    check(str(desc["why_provisional"]).length() > 60, "no reason given for provisionality")


func test_quantisation_uses_the_realised_range_not_the_contracts() -> void:
    """§23.837. Quantising over the contract's bounds gave burned fraction
    THREE of 65,534 codes, because `bounds` is a validity range and not a
    dynamic one. Both ranges must travel with the row."""
    var fl := fixture()
    var seen_narrow := false
    for k in fl.manifest["client_form"]["rows"]:
        var d: Dictionary = fl.manifest["client_form"]["rows"][k]
        if str(d.get("lattice", "band")) == "node":
            continue
        check(d.has("contract_lo") and d.has("contract_hi"),
                "%s does not carry the contract's bounds" % k)
        check(d.has("codes_if_quantised_over_contract"),
                "%s does not say what the contract encoding would have cost" % k)
        var codes: int = int(d["codes_if_quantised_over_contract"])
        if codes < 100:
            seen_narrow = true
            check(float(d["hi"]) - float(d["lo"])
                    < float(d["contract_hi"]) - float(d["contract_lo"]),
                    "%s claims a narrow contract encoding but a full realised range" % k)
    check(seen_narrow,
            "no row would have been narrowed by contract-bounds quantisation -- "
            + "then this test is not exercising §23.837's case")


func test_burn_asks_about_magnitude_before_geometry() -> void:
    """Decision 892 draws a burn perimeter as a real edge. A threshold sweep
    finds thresholds at ANY magnitude -- it always does -- so magnitude has to
    be asked first, or the geometry answers a question nobody put. This trace
    peaks at 4.5e-05 burned fraction, four orders below a legible level."""
    var fl := fixture()
    var be := BurnEdge.new()
    var r := be.measure(fl.day_values(fl.windows[0], "band.burned_fraction", 45))
    check(float(r["max_value"]) > 0.0, "nothing burned at all -- check the fixture")
    check(not bool(r["has_edge"]),
            "a perimeter is claimed on a field peaking at %s"
            % String.num_scientific(float(r["max_value"])))
    check(str(r["verdict"]).contains("drawable"),
            "the verdict does not say why there is no edge: %s" % str(r["verdict"]))

    # and it must find one when there IS one
    var synthetic := PackedFloat64Array()
    synthetic.resize(1000)
    for i in 1000:
        synthetic[i] = 0.9 if i < 80 else 0.0
    var be2 := BurnEdge.new()
    var r2 := be2.measure(synthetic)
    check(bool(r2["has_edge"]),
            "no perimeter found on a field where 8%% of cells are 90%% burned")
    print("burn: %s" % str(r["verdict"]).substr(0, 90))
