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

## The window every shot in `shots/` is taken at, and so the height the UI has
## to fit. `tools/screenshot.sh` and `tools/measure_scatter.sh` both default to
## 1280x800; a panel that needs more than this is a panel that is cut in every
## photograph this project takes of itself.
const WINDOW_MIN_H := 800


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
    test_the_terrain_faces_the_camera_that_looks_at_it()
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
    test_contours_index_the_day_the_manifest_says()
    test_contour_arcs_land_on_the_terrain_they_were_extracted_on()
    test_the_contour_line_stays_broken()
    test_no_contour_set_is_invented_for_a_window_that_has_none()
    test_the_probe_tells_the_three_absences_apart()
    test_the_probe_reads_the_row_that_is_drawn()
    test_the_ray_march_lands_on_the_surface_it_marched()
    test_the_series_keeps_what_float32_would_flush_to_zero()
    test_the_plot_separates_no_flow_from_below_the_scale()
    test_the_series_is_indexed_by_the_manifests_node_order()
    test_the_panel_says_why_the_second_node_row_has_no_plot()
    test_quantiles_are_nearest_rank_and_never_interpolate()
    test_the_fit_reports_what_it_costs_to_believe_it()
    test_the_benchmark_refuses_to_measure_frame_cost_headless()
    test_the_fit_survives_a_renderer_with_no_gpu_timer()
    test_the_frame_probe_measures_what_a_look_would_report()
    test_the_frame_probe_can_tell_a_lit_surface_from_a_flat_one()
    test_ramp_agreement_survives_a_light_and_not_a_highlight()
    test_the_hillshade_arrives_from_the_north_west()
    test_the_verdict_is_read_and_never_supplied()
    test_the_scatter_cost_is_a_difference_and_says_when_it_is_not_one()
    test_the_benchmark_ladder_says_which_rungs_the_timer_could_not_separate()
    test_the_empty_stage_coefficient_is_a_floor_and_the_scene_sits_above_it()
    test_the_scatter_measurement_verifies_in_pixels_not_primitives()
    test_every_wire_life_form_resolves_to_a_family()
    test_no_family_is_keyed_below_life_form()
    test_a_parameter_outside_its_range_is_refused_not_clamped()
    test_the_exaggeration_is_applied_after_the_check_not_before()
    test_the_families_hold_the_unit_convention_the_transform_relies_on()
    test_the_cost_model_refuses_outside_its_measured_span()
    test_the_scatter_reports_what_it_could_not_draw()
    test_the_individuation_horizon_is_one_constant_bounded_by_the_camera()
    test_a_density_schedule_is_finer_than_the_texel_it_thins()
    test_pft_fractions_are_a_composition_of_the_cover()
    test_the_tint_takes_wire_shares_unfloored_and_the_drawn_unit_can_change()
    test_the_tint_holds_the_quantity_a_seam_has_to_conserve()
    test_a_recorded_distance_names_what_it_is_conditional_on()
    test_the_seam_metric_fails_the_bad_frame()
    test_plants_stand_on_the_surface_that_is_drawn()
    test_the_shading_is_exaggerated_and_the_geometry_is_not()
    test_the_seam_measurement_ranks_the_null_baseline_worst()
    test_the_project_does_not_import_blend_sources()
    test_phenology_is_the_cell_measured_against_itself()
    test_the_tint_moves_with_the_season_it_is_read_from()
    test_multimesh_custom_data_does_not_read_back_headless()
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

        # THREE RULINGS ABOUT THE TERRAIN'S SURFACE, all made by looking at it
        # and none of them visible to anything else in this file. They are
        # pinned here rather than in the view because what matters is the
        # material the RUNNING SCENE ends up with, which is what was
        # photographed.
        var mi := _scene_root.get_node_or_null("TerrainView/Terrain") as MeshInstance3D
        var mat := (mi.material_override if mi != null else null) as ShaderMaterial
        check(mat != null, "the terrain in the running scene has no ShaderMaterial")
        if mat != null:
            # THE SOURCE, not a property, because the rulings the visual audit
            # made now live in the shader text rather than in material flags.
            # A StandardMaterial3D could be asked whether its specular was
            # zero; a shader has to be read, and reading it is the check.
            var src := (mat.shader.code if mat.shader != null else "")
            check(src.contains("SPECULAR = 0.0"),
                    "the terrain shader does not zero SPECULAR. A specular term adds WHITE in "
                    + "proportion to nothing in the data, and white washes a viridis colour off "
                    + "the ramp: measured, 43.5% of the overlay's pixels lay on the declared "
                    + "ramp with the default term and 99.8% with it off.")
            check(src.contains("ROUGHNESS = 1.0"), "the terrain shader does not pin ROUGHNESS")
            check(not src.contains("render_mode") or not src.contains("blend_mix"),
                    "the terrain shader enables blending. The overlay's nodata was black "
                    + "because alpha was ignored, and turning alpha ON is not the fix: "
                    + "photographed both ways it moved 17.89% of the frame -- 183,000 pixels "
                    + "blended with the sky -- to change a few hundred. Nodata is painted "
                    + "with TerrainView.BARE_ALBEDO instead.")
            check(not src.contains("ALPHA ="),
                    "the terrain shader writes ALPHA, which reintroduces the depth sorting the "
                    + "nodata measurement ruled against")
        var amb := _scene_root.get_node_or_null("TerrainView/Ambient") as WorldEnvironment
        check(amb != null and amb.environment != null
                and amb.environment.ambient_light_energy > 0.0,
                "no ambient fill. With one directional light and no ambient, a slope facing "
                + "away from the sun renders PURE BLACK -- 738 pixels of a 1,024,000-pixel "
                + "frame, sitting next to a ramp whose low end is near-black, so they read as "
                + "the lowest value in the field rather than as unlit ground.")

        # And the nodata colour the overlay was bound with is the terrain's own,
        # so "no measurement here" renders as the ground rather than as a colour.
        var view = _scene_root.get_node_or_null("TerrainView")
        if view != null and view.overlay != null and view.overlay.is_bound():
            var nd: Color = view.overlay.nodata_colour()
            check(nd.a >= 1.0, "nodata is written transparent into a material that ignores "
                    + "alpha, which is how it reached the screen as black")
            check(absf(nd.r - TerrainView.BARE_ALBEDO.r) <= 1.0 / 255.0
                    and absf(nd.g - TerrainView.BARE_ALBEDO.g) <= 1.0 / 255.0
                    and absf(nd.b - TerrainView.BARE_ALBEDO.b) <= 1.0 / 255.0,
                    "nodata is painted %s, not the terrain's own %s"
                    % [str(nd), str(TerrainView.BARE_ALBEDO)])
            # An all-NAN day must produce a texture that is entirely bare ground
            # and contains no ramp colour at all -- the failure this guards is a
            # field of no measurements rendering as a field of low ones.
            var all_nan := PackedFloat64Array()
            all_nan.resize(view.fixture.n_cells)
            all_nan.fill(NAN)
            var img: Image = view.overlay.texture_for(all_nan, 0.0, 1.0).get_image()
            var off := 0
            for y in range(0, img.get_height(), 7):
                for x in range(0, img.get_width(), 7):
                    var px: Color = img.get_pixel(x, y)
                    if absf(px.r - nd.r) > 2.0 / 255.0 or absf(px.g - nd.g) > 2.0 / 255.0 \
                            or absf(px.b - nd.b) > 2.0 / 255.0 or px.a < 1.0:
                        off += 1
            check(off == 0, "%d sampled texels of an all-NAN day are not bare ground" % off)
            print("main scene overlay: nodata %s, %d nodata px of %d"
                    % [str(nd), view.overlay.nodata_px,
                       view.overlay.nodata_px + view.overlay.resolved_px])

    # M4's layer, in the scene the application actually runs. The scrubber owns
    # the clock; the contour layer takes the day from it and never asks for
    # one. Two clocks would show a snowline and a snowpack from different days,
    # which reads as physics rather than as a bug -- so what is checked is that
    # the day the layer drew is the day the scrubber holds.
    if _scene_root.scrubber != null:
        var c: Dictionary = _scene_root.scrubber.current()
        var cd: Dictionary = _scene_root.contour_day_report
        check(_scene_root.legend != null, "no contour legend in the running scene")
        var has_set: bool = _scene_root._terrain.contour_sets.has(c["window"])
        if has_set:
            check(int(cd.get("day", -1)) == int(c["day"]),
                    "the contour layer drew day %s and the scrubber holds day %d"
                    % [str(cd.get("day", "?")), int(c["day"])])
            check(_scene_root.get_node_or_null("TerrainView/Contours") != null,
                    "no Contours mesh instance for a window that has a set")
        else:
            check(not bool(cd.get("ok", false)),
                    "contours were drawn for %s, which has no vendored set" % c["window"])
            check(str(cd.get("why", "")).contains(str(c["window"])),
                    "the layer does not say why %s has no contours" % c["window"])
        # M4's probe, through the input path the application uses. The panel
        # is what a click has to reach: a signal wired to nothing looks exactly
        # like a signal wired correctly until someone clicks.
        var click := InputEventMouseButton.new()
        click.button_index = MOUSE_BUTTON_LEFT
        click.pressed = true
        click.position = Vector2(get_root().size) * 0.5
        get_root().push_input(click)
        check(_scene_root.probe_panel != null, "no probe panel in the running scene")
        # THE DISCLAIMER HAS TO FIT THE WINDOW, and this is the assert that
        # catches it. Photographed at 1280x800 -- the default size every shot
        # in `shots/` is taken at -- the banner ran off the bottom: the fifth
        # named fail stopped mid-sentence, the equivalence exclusions were
        # never visible at all, and the probe panel below was displaced off
        # screen entirely. It renders as a disclaimer that LOOKS complete,
        # which is worse than an empty one.
        #
        # Twenty-six asserts on this banner's text saw none of it, because they
        # read the string and the string was perfect. The headless root is a
        # 64 px stub, but the control column still lays out for real, so the
        # banner's own demanded height is measurable here and is the number
        # that overflowed.
        if _scene_root.verdict_banner != null:
            var vb: Control = _scene_root.verdict_banner
            var needs: float = vb.global_position.y + vb.size.y
            check(needs <= float(WINDOW_MIN_H), "the verdict banner wants %d px of a %d px "
                    % [int(needs), WINDOW_MIN_H]
                    + "window, so at the size this project photographs itself the disclaimer "
                    + "is cut off mid-sentence and whatever follows it never appears. Shorten "
                    + "what it says or move it up the column; do not widen the window, which "
                    + "only moves the size at which this happens.")
            print("banner: %d x %d px, bottom at %d of %d"
                    % [int(vb.size.x), int(vb.size.y), int(needs), WINDOW_MIN_H])

        if _scene_root.probe_panel != null:
            check(_scene_root.probe_panel.state.text != ProbePanel.NOT_PROBED,
                    "a click on the terrain did not reach the probe panel")
            check(not _scene_root.probe_report.is_empty(),
                    "the probe emitted nothing")
            if str(_scene_root.probe_report.get("state", "")) == CellProbe.RESOLVED:
                check(_scene_root.probe_panel.series.values.size() > 0,
                        "a click that resolved to a cell drew no time series")
                check(_scene_root.probe_panel.absent_rows.text.contains("wetland"),
                        "the panel does not say why the second node row is absent")

                # M5 rides on the same click. The scatter needs a place to
                # stand, and main.gd gives it the point the viewer just asked
                # about -- a wiring that exists nowhere else and would look
                # exactly like working code if the signal reached nothing.
                var sr: Dictionary = _scene_root.scatter_report
                check(not sr.is_empty(), "a resolved click scattered nothing")
                check(bool(sr.get("ok", false)),
                        "the scene's scatter failed: %s" % str(sr.get("why", "")))
                if bool(sr.get("ok", false)):
                    var world: Vector2 = _scene_root.probe_report["world"]
                    var at: Array = sr["centre_m"]
                    check(Vector2(float(at[0]), float(at[1])).distance_to(world) < 1.0,
                            "the scatter stood at %s and the probe resolved at %s"
                            % [str(at), str(world)])
                    check(int(sr["day"]) == int(_scene_root.scrubber.current()["day"]),
                            "the scatter drew day %d and the scrubber holds day %d"
                            % [int(sr["day"]), int(_scene_root.scrubber.current()["day"])])
                    check(_scene_root.probe_panel.scatter_line.text.length() > 20,
                            "the scatter did not reach the panel")
                    check(_scene_root.probe_panel.scatter_share.text.contains("share drawn"),
                            "the panel does not surface the share: %s"
                            % _scene_root.probe_panel.scatter_share.text)
                    # Which families are present depends on what grows there,
                    # so the assertion is that every family that placed
                    # instances reached the scene -- not that a chosen one did.
                    var drawn := PackedStringArray()
                    for g in sr["groups"]:
                        if int((sr["placed"] as Dictionary).get(g, 0)) > 0:
                            drawn.append(str(g))
                            check(_scene_root.get_node_or_null(
                                    "TerrainView/Vegetation_%s" % g) != null,
                                    "%s placed instances and reached no node in the scene" % g)
                    check(drawn.size() > 0, "the scatter placed nothing at all here")
                    print("main scene scatter: %d texels, share %s, families %s"
                            % [int(sr["texels"]), String.num(float(sr["share_drawn"]), 5),
                               str(drawn)])

                    # AND IT HAS TO BE REACHABLE. The overview camera shows
                    # 1,545,600 m of basin and the scatter is 3,000 m across, so
                    # the whole of it lands on about a pixel. Both numbers are
                    # right and three orders of magnitude apart -- run as an
                    # application rather than as a test, that is a window with
                    # nothing in it, which is how this was found.
                    var tv: TerrainView = _scene_root.get_node("TerrainView")
                    var overview_px := float(sr["on_screen_px"])
                    check(not is_nan(overview_px),
                            "the scatter does not report its size on screen")
                    check(overview_px < 8.0,
                            "the scatter is %.1f px at the overview camera; this check is "
                            % overview_px + "no longer exercising the case it exists for")
                    check(_scene_root.probe_panel.scatter_where.text.contains("press"),
                            "the panel does not say how to reach a sub-pixel scatter: %s"
                            % _scene_root.probe_panel.scatter_where.text)
                    check(tv.rig.using_ortho(), "the viewer did not start on the overview")
                    check(tv.focus_on_scatter(), "the scatter could not be reached")
                    check(not tv.rig.using_ortho(), "reaching it left the overview current")
                    var close_px := tv._on_screen_px(2.0 * TerrainView.SCATTER_HORIZON_M)
                    check(close_px > overview_px * 100.0,
                            "reaching it moved the scatter from %.2f px to %.2f px"
                            % [overview_px, close_px])
                    var vh := float(get_root().get_visible_rect().size.y)
                    check(close_px > 0.5 * vh,
                            "the scatter fills %.0f px of a %.0f px viewport after reaching it"
                            % [close_px, vh])
                    print("main scene reach: %.2f px at the overview, %.0f px of %.0f after G"
                            % [overview_px, close_px, vh])
            print("main scene probe: %s" % str(_scene_root.probe_report.get("state", "?")))

        print("main scene contours: window %s, %s"
                % [c["window"], "day %d drawn" % int(cd.get("day", -1)) if has_set
                        else str(cd.get("why", ""))])


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


func test_the_terrain_faces_the_camera_that_looks_at_it() -> void:
    """The mesh was wound inside-out and nothing noticed for five milestones.
    Godot culls back faces by default, so the whole basin was invisible from
    above -- while the flowlines over it, LINES and never culled, still drew.
    The viewer showed a river network floating on the background, and every
    test passed: they counted vertices, quads, holes and reaches, and not one
    of them asked whether the surface could be seen.

    THE CONVENTION IS TAKEN FROM THE ENGINE, NOT FROM THIS FILE. Which winding
    Godot treats as front-facing is the engine's business and I had it
    backwards; asserting my own belief about it would pin the bug rather than
    the rule. So a PlaneMesh -- which Godot builds itself, facing +Y -- supplies
    the reference relationship between a triangle's right-hand normal and its
    shading normal, and the terrain has to match it."""
    var reference := _winding_sign(PlaneMesh.new())
    check(reference != 0,
            "the reference PlaneMesh gave no winding sign; the convention cannot be read")

    var hf := heightfield()
    var tm := TerrainMesh.new()
    var mesh := tm.build(hf, 8, 1.0)
    var terrain_sign := _winding_sign(mesh)
    check(terrain_sign != 0, "the terrain mesh gave no consistent winding sign")
    check(terrain_sign == reference,
            "the terrain is wound opposite to a PlaneMesh, so back-face culling hides it "
            + "from every camera above it -- the basin renders only from underneath")
    print("winding: terrain matches PlaneMesh (sign %d)" % terrain_sign)


## +1 or -1 for how a mesh's triangle winding relates to its shading normals,
## or 0 if the mesh does not answer consistently.
##
## The sign itself means nothing; only agreement between two meshes does. That
## is the point: it makes the test independent of which convention the engine
## happens to use.
func _winding_sign(mesh: Mesh) -> int:
    var arrays := mesh.surface_get_arrays(0)
    var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if verts.is_empty() or normals.is_empty() or indices.size() < 3:
        return 0
    var positive := 0
    var negative := 0
    for t in range(0, indices.size(), 3):
        if t > 3000:
            break
        var i0 := indices[t]
        var i1 := indices[t + 1]
        var i2 := indices[t + 2]
        var rhn := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
        if rhn.length() < 1e-9:
            continue
        var shading := (normals[i0] + normals[i1] + normals[i2]).normalized()
        var d := rhn.normalized().dot(shading)
        if d > 0.2:
            positive += 1
        elif d < -0.2:
            negative += 1
    if positive > 0 and negative == 0:
        return 1
    if negative > 0 and positive == 0:
        return -1
    return 0


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


# --------------------------------------------------------------------------
# M4 -- contours
# --------------------------------------------------------------------------

const CONTOUR_DIR := "res://assets/contours/"

var _cs: ContourSet = null


func contours() -> ContourSet:
    if _cs == null:
        var sets := ContourSet.discover(CONTOUR_DIR)
        _cs = sets.get("deepest_winter", ContourSet.new())
    return _cs


func contour_manifest() -> Dictionary:
    var f := FileAccess.open(
            CONTOUR_DIR + "contours_deepest_winter_band_snowpack_swe.json", FileAccess.READ)
    return JSON.parse_string(f.get_as_text())


func test_contours_index_the_day_the_manifest_says() -> void:
    """A day's arcs are found by `byte_offset` and cut apart by
    `arc_vertex_counts`; nothing in the payload marks where one day or one arc
    ends. An index off by one arc reads the next day's geometry and draws it
    as this one's -- a snowline from the wrong day, correct in every other
    respect and impossible to see."""
    var cs := contours()
    check(cs.is_loaded(), "no contour set loaded: %s" % cs.why_absent)
    if not cs.is_loaded():
        return
    var man := contour_manifest()
    var days: Dictionary = man["days"]
    check(cs.day_count() == days.size(),
            "the set offers %d days and the manifest holds %d" % [cs.day_count(), days.size()])

    var checked := 0
    for day in [0, 1, 29, 45, days.size() - 1]:
        var d: Dictionary = days[str(day)]
        var arcs := cs.arcs_for_day(day)
        check(arcs.size() == int(d["arc_count"]),
                "day %d gave %d arcs, the manifest says %d"
                % [day, arcs.size(), int(d["arc_count"])])
        var counts: Array = d["arc_vertex_counts"]
        var total := 0
        var wrong := 0
        for i in mini(arcs.size(), counts.size()):
            var arc: PackedVector2Array = arcs[i]
            if arc.size() != int(counts[i]):
                wrong += 1
            total += arc.size()
        check(wrong == 0, "day %d: %d arcs are not the length the manifest gives" % [day, wrong])
        check(total == int(d["vertex_count"]),
                "day %d read %d vertices, the manifest says %d"
                % [day, total, int(d["vertex_count"])])
        checked += 1
    check(checked == 5, "only %d days indexed" % checked)

    # The offsets are the manifest's claim about the payload, so they are
    # checked against the payload rather than trusted for sitting beside it.
    var at := 0
    var gaps := 0
    for day in days.size():
        var d: Dictionary = days[str(day)]
        if int(d["byte_offset"]) != at:
            gaps += 1
        at += int(d["vertex_count"]) * 8
    check(gaps == 0, "%d day offsets do not follow the day before them" % gaps)
    var bin := FileAccess.open(CONTOUR_DIR + str(man["payload"]["file"]), FileAccess.READ)
    check(bin != null, "the payload named by the manifest did not open")
    if bin != null:
        check(int(bin.get_length()) == at,
                "the payload is %d bytes and the days account for %d" % [bin.get_length(), at])
    print("contours: %d days, %d vertices, %d bytes accounted for"
            % [days.size(), at / 8, at])


func test_contour_arcs_land_on_the_terrain_they_were_extracted_on() -> void:
    """The arcs were extracted on the overview raster's own transform, which
    is what `tools/vendor_contours.py` refuses to vendor against. If that ever
    stopped holding, every arc would sit off its own ground -- so this asks
    the terrain, not the manifest: a vertex's bicubic neighbourhood must be
    valid, or the vertex is off the heightfield and gets dropped and counted
    rather than clamped to a height it does not have."""
    var cs := contours()
    if not cs.is_loaded():
        return
    var hf := heightfield()
    var arcs := cs.arcs_for_day(29)
    var sampled := 0
    var offmap := 0
    for i in range(0, arcs.size(), 2):
        var arc: PackedVector2Array = arcs[i]
        for k in arc.size():
            if is_nan(hf.height_at_world(arc[k].x, arc[k].y)):
                offmap += 1
            sampled += 1
    check(sampled > 500, "only %d vertices sampled" % sampled)
    check(offmap * 100 < sampled,
            "%d of %d sampled vertices are off the heightfield -- the arcs and the "
            % [offmap, sampled] + "terrain are not on one grid")

    var tm := TerrainMesh.new()
    tm.build(hf, 8, 1.0)
    var cd := ContourDrape.new()
    var m := cd.build(arcs, hf, tm)
    check(m.get_surface_count() == 1, "the drape built %d surfaces" % m.get_surface_count())
    check(cd.dropped_offmap * 100 < cd.arcs_in + cd.vertices_drawn,
            "%d vertices were dropped off-map" % cd.dropped_offmap)
    # Some arcs are lost entirely, and the number is the cost of a stated rule
    # rather than a defect: `height_at` returns NAN for any point whose bicubic
    # neighbourhood touches nodata, which is a one-texel border of terrain, and
    # a two-vertex arc that loses one vertex has nothing left to draw. Dropped
    # and counted; never clamped to a height the heightfield does not hold.
    check(cd.arcs_lost * 20 < cd.arcs_in,
            "%d of %d arcs drape to nothing -- more than the one-texel nodata border costs"
            % [cd.arcs_lost, cd.arcs_in])
    print("contour drape: %d arcs, %d runs, %d segments, %d off-map, %d splits, %d arcs lost"
            % [cd.arcs_in, cd.runs_out, cd.segments, cd.dropped_offmap, cd.splits,
               cd.arcs_lost])


func test_the_contour_line_stays_broken() -> void:
    """Decision 890. 39.6% of this boundary is not in the artefact, because it
    falls on divides between nodes that hold no crossing; a continuous
    snowline would be lattice geometry with a physical name on it, and it
    would look better than the honest version for being continuous.

    Two ways the client could close a gap by accident, and both are pinned
    here: joining the end of one arc to the start of the next, and bridging a
    vertex the heightfield could not support."""
    var cs := contours()
    if not cs.is_loaded():
        return
    var hf := heightfield()
    var tm := TerrainMesh.new()
    var mesh := tm.build(hf, 8, 1.0)
    var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var w := []
    for n in 6:
        w.append(tm.mesh_to_world(verts[100 + n], hf))
    var offmap := Vector2(hf.origin_x - 2.0e6, hf.origin_y)
    check(is_nan(hf.height_at_world(offmap.x, offmap.y)),
            "the off-map probe point is on the heightfield after all")

    # two arcs, no gaps: 2 + 2 segments and never a fifth joining them
    var cd := ContourDrape.new()
    cd.build([PackedVector2Array([w[0], w[1], w[2]]),
              PackedVector2Array([w[3], w[4], w[5]])], hf, tm)
    check(cd.segments == 4,
            "two 3-vertex arcs drew %d segments, not 4 -- something joined them" % cd.segments)
    check(cd.runs_out == 2, "two arcs became %d runs" % cd.runs_out)

    # one arc with an unsupported vertex in the middle: it splits, never bridges
    var cd2 := ContourDrape.new()
    cd2.build([PackedVector2Array([w[0], w[1], offmap, w[2], w[3]])], hf, tm)
    check(cd2.dropped_offmap == 1, "%d vertices dropped, expected 1" % cd2.dropped_offmap)
    check(cd2.splits == 1, "the gap did not split the arc (%d splits)" % cd2.splits)
    check(cd2.segments == 2,
            "the gap was bridged: %d segments where the two halves give 2" % cd2.segments)

    # and on the real day, every segment is accounted for inside some run
    var arcs := cs.arcs_for_day(29)
    var read := 0
    for a in arcs:
        read += (a as PackedVector2Array).size()
    var cd3 := ContourDrape.new()
    cd3.build(arcs, hf, tm)
    check(cd3.segments == read - cd3.dropped_offmap - cd3.runs_too_short - cd3.runs_out,
            "%d segments do not account for %d vertices in %d runs"
            % [cd3.segments, read, cd3.runs_out])

    var st := cs.standing(29)
    check(float(st["share_drawn"]) < 1.0,
            "the day claims the whole boundary is drawn, which this artefact does not")
    check(int(st["declined_crossings"]) > 0, "no crossing is recorded as declined")
    check(str(st["verdict"]).contains("declined"),
            "the standing does not say the rest is declined: %s" % str(st["verdict"]))
    check(float(st["corridor_m"]) <= float(st["band_m"]) / 2.0,
            "%.1f m is outside half the %.1f m band the crossing is interpolated in"
            % [float(st["corridor_m"]), float(st["band_m"])])
    print("contour standing day 30: %s" % str(st["verdict"]))


func test_no_contour_set_is_invented_for_a_window_that_has_none() -> void:
    """Extraction is server-side (§16.12.1) and per window. A window with no
    set draws nothing and says why -- there is no client-side fallback to fall
    back to, and a contour computed here would be the generator §16.12 keeps
    off the wire, rebuilt from the data it is meant to be withheld from."""
    var sets := ContourSet.discover(CONTOUR_DIR)
    check(sets.has("deepest_winter"), "no set for deepest_winter: %s" % str(sets.keys()))
    check(not sets.has("largest_fire"),
            "a contour set appeared for largest_fire, which was never extracted")

    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    var bound := v.bind_contours()
    check(bool(bound["ok"]), "no contour set bound: %s" % str(bound.get("why", "")))
    var absent := v.show_contours("largest_fire", 0)
    check(not bool(absent.get("ok", false)), "largest_fire drew contours")
    check(str(absent.get("why", "")).contains("largest_fire"),
            "the refusal does not name the window: %s" % str(absent.get("why", "")))
    var drawn := v.show_contours("deepest_winter", 29)
    check(bool(drawn.get("ok", false)), "deepest_winter drew nothing")
    check(int(drawn.get("segments", 0)) > 1000, "%d segments drawn" % int(drawn.get("segments", 0)))
    var mi := v.get_node_or_null("Contours")
    check(mi != null, "no Contours mesh instance after drawing")

    var legend := ContourLegend.new()
    get_root().add_child(legend)
    legend.setup()
    legend.show_absent("largest_fire")
    check(legend.standing.text.contains("§16.12.1"),
            "the legend does not say where extraction happens: %s" % legend.standing.text)
    legend.show_set(v.contour_sets["deepest_winter"], 29, drawn)
    check(legend.day_line.text.contains("declined"),
            "the legend does not surface the declined share: %s" % legend.day_line.text)
    check(legend.standing.text.contains("PROVISIONAL"),
            "the legend does not carry the threshold's standing: %s" % legend.standing.text)
    legend.queue_free()
    v.queue_free()


# --------------------------------------------------------------------------
# M4 -- the probe
# --------------------------------------------------------------------------

func test_the_probe_tells_the_three_absences_apart() -> void:
    """Two of the three absences are not errors. A point with no ground, a
    point with ground and no residence key (4,973 of them, and `key_at`
    returns [] by design), and a key the fixture cannot join are three
    different statements, and reporting them as one "no data" is what
    ResidenceLayer's header is written against."""
    var hf := heightfield()
    var rl := residence()
    var fl := fixture()
    var cp := CellProbe.new()
    cp.bind(hf, rl, fl)
    check(cp.is_bound(), "the probe did not bind")

    var off := hf.texel_to_world(-500.0, -500.0)
    var no_ground := cp.at_world(off.x, off.y)
    check(str(no_ground["state"]) == CellProbe.NO_GROUND,
            "a point off the raster reported %s" % str(no_ground["state"]))

    # a ground texel with no key, and a ground texel with one, from the raster
    # itself -- neither is constructed, both are conditions the artefacts hold
    var no_key := {}
    var resolved := {}
    for y in range(0, hf.height, 7):
        for x in range(0, hf.width, 7):
            if is_nan(hf.height_at_texel(x, y)):
                continue
            var w := hf.texel_to_world(float(x), float(y))
            var r := cp.at_world(w.x, w.y)
            if str(r["state"]) == CellProbe.NO_KEY and no_key.is_empty():
                no_key = r
            elif str(r["state"]) == CellProbe.RESOLVED and resolved.is_empty():
                resolved = r
        if not no_key.is_empty() and not resolved.is_empty():
            break
    check(not no_key.is_empty(), "no ground texel without a residence key was found")
    check(not resolved.is_empty(), "no texel resolved to a cell")
    if no_key.is_empty() or resolved.is_empty():
        return
    check(not no_key.has("cell"), "a keyless point still reported a cell")
    check(str(no_key["why"]).contains("891"),
            "the empty key is not reported as the ruled answer: %s" % str(no_key["why"]))
    check(int(resolved["cell"]) >= 0, "the resolved point carries no cell")
    check(int(resolved["node_axis"]) >= 0, "the resolved point has no node-axis position")
    check(str(resolved["huc10"]).length() > 0, "the resolved point names no node")

    # the fourth state, which should never occur against these artefacts and
    # is therefore the branch that would otherwise never have run
    var no_cell := cp.for_key("00000000000", 0)
    check(str(no_cell["state"]) == CellProbe.NO_CELL,
            "a key the fixture has never seen reported %s" % str(no_cell["state"]))
    check(str(no_cell["why"]).contains("no cell"),
            "the join failure does not say what disagreed: %s" % str(no_cell["why"]))

    var whys := [str(no_ground["why"]), str(no_key["why"]), str(no_cell["why"])]
    for i in whys.size():
        check(whys[i].length() > 20, "absence %d gives no reason" % i)
        for j in range(i + 1, whys.size()):
            check(whys[i] != whys[j], "two absences give the same reason")
    print("probe: no-ground, no-key at texel %s, resolved at texel %s, no-cell"
            % [str(no_key["texel"]), str(resolved["texel"])])


func test_the_probe_reads_the_row_that_is_drawn() -> void:
    """§16.12 makes the scalar at (x, y) the fine rung. This is a development
    view of the server's own data and is exempt on that ground alone, which is
    why CellProbe says so in the file rather than leaving it to be remembered.

    What is checked here is narrower: the value in the readout is the value
    the terrain is painted with. A probe reading a row it was told about
    separately would print a number for one row under the colours of
    another."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    var bound := v.bind_fields()
    check(bool(bound["ok"]), "the view did not bind fields: %s" % str(bound.get("why", "")))
    check(v.show_field("deepest_winter", "band.snowpack_swe", 29),
            "the view did not paint band.snowpack_swe")

    var hf := v.heightfield
    var found := false
    for y in range(0, hf.height, 11):
        for x in range(0, hf.width, 11):
            var w := hf.texel_to_world(float(x), float(y))
            var r := v.probe_world(w.x, w.y)
            if str(r.get("state", "")) != CellProbe.RESOLVED:
                continue
            check(str(r["row"]) == "band.snowpack_swe",
                    "the probe read %s while band.snowpack_swe is drawn" % str(r["row"]))
            check(int(r["day"]) == 29, "the probe read day %d, day 29 is drawn" % int(r["day"]))
            var vals := v.fixture.day_values("deepest_winter", "band.snowpack_swe", 29)
            var direct := vals[int(r["cell"])]
            if bool(r["has_value"]):
                check(absf(float(r["value"]) - direct) < 1e-12,
                        "the probe read %s and the cell holds %s"
                        % [String.num(float(r["value"]), 9), String.num(direct, 9)])
            else:
                check(is_nan(direct), "the probe found no value where the cell holds one")
            found = true
            break
        if found:
            break
    check(found, "no texel resolved through the view")
    v.queue_free()


func test_the_ray_march_lands_on_the_surface_it_marched() -> void:
    """The probe turns a click into a world position by marching the camera
    ray against the heightfield the mesh was built from, rather than against a
    collision shape -- a second copy of the terrain would be free to disagree
    with the drawn one, and a probe answering about an invisible surface is
    worse than one that answers nothing."""
    var v := TerrainView.new()
    get_root().add_child(v)
    var rep := v.build()
    check(bool(rep["ok"]), "the view did not build")
    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var aabb: AABB = v.terrain.mesh.get_aabb()
    var tested := 0
    var wrong_xy := 0
    var wrong_y := 0
    for n in range(37, verts.size(), 971):
        var target := verts[n]
        var origin := Vector3(target.x, aabb.end.y + 100000.0, target.z)
        var hit := v.world_under_ray(origin, Vector3.DOWN)
        if not bool(hit.get("hit", false)):
            wrong_xy += 1
            continue
        var m: Vector3 = hit["mesh"]
        if absf(m.x - target.x) > 1.0 or absf(m.z - target.z) > 1.0:
            wrong_xy += 1
        if absf(m.y - target.y) > 1.0:
            wrong_y += 1
        tested += 1
    check(tested > 8, "only %d rays hit the surface" % tested)
    check(wrong_xy == 0, "%d rays landed away from the vertex they were aimed at" % wrong_xy)
    check(wrong_y == 0, "%d rays stopped at a height the vertex does not have" % wrong_y)

    var up := v.world_under_ray(Vector3(0.0, aabb.end.y + 1000.0, 0.0), Vector3.UP)
    check(not bool(up.get("hit", false)), "a ray pointing away from the basin hit it")
    check(str(up.get("why", "")).length() > 10, "a miss gives no reason: %s" % str(up))
    check(str(v.probe_at_screen(null, Vector2.ZERO)["state"]) == CellProbe.NO_GROUND,
            "probing with no current camera did not report an absence")
    print("ray march: %d rays land on the vertex they were aimed at" % tested)
    v.queue_free()


# --------------------------------------------------------------------------
# M4 -- per-node time series
# --------------------------------------------------------------------------

func test_the_series_keeps_what_float32_would_flush_to_zero() -> void:
    """The series is read through `day_values`, which returns
    PackedFloat64Array, and it stays float64 all the way to the classification.
    Streamflow reaches 4.9e-324; float32 flushes everything under 1.18e-38 to
    zero, which moves samples out of "below the display scale" and into "no
    flow" -- two different statements about the river (§23.812).

    Proved against the container rather than argued: the same value is put
    through a PackedFloat32Array here and comes back as zero."""
    var fl := fixture()
    var vals := fl.day_values("deepest_winter", "node.streamflow", 45)
    var axis := -1
    var tiny := 0.0
    for i in vals.size():
        if vals[i] != 0.0 and vals[i] < 1.18e-38:
            axis = i
            tiny = vals[i]
            break
    check(axis >= 0, "no value below float32's floor in this window -- nothing to lose")
    if axis < 0:
        return
    var as32 := PackedFloat32Array([tiny])
    check(as32[0] == 0.0,
            "float32 no longer flushes %s -- this test is not testing what it says"
            % String.num_scientific(tiny))
    check(SeriesPlot.band_of(tiny) == SeriesPlot.BELOW,
            "a value below the scale is not classified as below it")
    check(SeriesPlot.band_of(float(as32[0])) == SeriesPlot.ZERO,
            "the flushed value is not classified as no flow, so the loss would be silent")

    var series := SeriesPlot.series_for(fl, "deepest_winter", "node.streamflow", axis)
    check(series is PackedFloat64Array, "the series is not a PackedFloat64Array")
    check(series.size() == fl.days("deepest_winter", "node.streamflow"),
            "the series is %d days and the row holds %d"
            % [series.size(), fl.days("deepest_winter", "node.streamflow")])
    check(series[45] == tiny,
            "day 45 of the series is %s and the row holds %s"
            % [String.num_scientific(series[45]), String.num_scientific(tiny)])
    var survived := 0
    for v in series:
        if v != 0.0 and v < 1.18e-38:
            survived += 1
    check(survived > 0, "no sub-float32 value survived the series read")
    print("series: node axis %d, %d of %d days below float32's floor and not zero"
            % [axis, survived, series.size()])


func test_the_plot_separates_no_flow_from_below_the_scale() -> void:
    """FlowDisplay's answer, reused rather than reinvented: a second scale
    would let a reach and its own time series disagree about whether a day had
    no flow or a little. The two rows sit OUTSIDE the decades, because a
    sample at the axis floor reads as the smallest value on the scale rather
    than as one that is not on it."""
    check(SeriesPlot.band_of(0.0) == SeriesPlot.ZERO, "zero is not classified as no flow")
    check(SeriesPlot.band_of(1e-20) == SeriesPlot.BELOW, "1e-20 is not below the scale")
    check(SeriesPlot.band_of(1.0) == SeriesPlot.IN_SCALE, "1 m3/s is not on the scale")
    check(SeriesPlot.band_of(NAN) == SeriesPlot.NO_VALUE, "nodata is not held apart")

    # the thresholds are FlowDisplay's, not a second set that could drift
    check(SeriesPlot.band_of(pow(10.0, FlowDisplay.DECADE_LO)) == SeriesPlot.IN_SCALE,
            "the bottom decade is not on the scale")
    check(SeriesPlot.band_of(pow(10.0, FlowDisplay.DECADE_LO - 1.0)) == SeriesPlot.BELOW,
            "a decade under the window is not below the scale")

    var yz := SeriesPlot.y_fraction(0.0)
    var yb := SeriesPlot.y_fraction(1e-20)
    var ym := SeriesPlot.y_fraction(1.0)
    check(yz != yb, "no flow and below-scale are drawn at the same height")
    check(yb != ym, "below-scale and on-scale are drawn at the same height")
    check(yb > SeriesPlot.SCALE_BOTTOM and yz > yb,
            "the two rows are not below the decades: %.2f, %.2f" % [yb, yz])
    check(is_nan(SeriesPlot.y_fraction(NAN)), "a day with no value was given a height")
    check(SeriesPlot.y_fraction(100.0) < SeriesPlot.y_fraction(0.1),
            "more flow is not drawn higher")

    # and nothing is joined across the boundary
    check(SeriesPlot.joins(1.0, 10.0), "two on-scale days are not joined")
    check(not SeriesPlot.joins(1.0, 0.0),
            "an on-scale day is joined to a no-flow day, drawing a descent through "
            + "values the river never had")
    check(not SeriesPlot.joins(1.0, 1e-20), "an on-scale day is joined to a below-scale one")
    check(not SeriesPlot.joins(1.0, NAN), "a day with no value is joined to one with a value")


func test_the_series_is_indexed_by_the_manifests_node_order() -> void:
    """`node_order` is what the simulation emits for this purpose. The order
    ids first appear in `cell_keys` agrees with it today, rests on nothing
    anyone promised, and a wrong index plots the wrong river's flow while
    looking entirely plausible."""
    var fl := fixture()
    var ids: Array = fl.manifest["node_order"]["ids"]
    check(ids.size() > 1000, "only %d ids in node_order" % ids.size())
    var wrong := 0
    for i in range(0, ids.size(), 53):
        if fl.node_index_of(str(ids[i])) != i:
            wrong += 1
    check(wrong == 0, "%d sampled ids do not sit where node_order puts them" % wrong)

    # the order cell_keys happens to introduce ids in, which is what this must
    # not be: it agrees today, so agreement is not evidence and the source is
    var first_seen := {}
    var pairs: Array = fl.manifest["cell_keys"]["pairs"]
    for pr in pairs:
        var huc := str(pr[0])
        if not first_seen.has(huc):
            first_seen[huc] = first_seen.size()
    check(first_seen.size() == ids.size(),
            "%d nodes in cell_keys against %d on the axis" % [first_seen.size(), ids.size()])

    var probe := CellProbe.new()
    probe.bind(heightfield(), residence(), fl)
    var checked := 0
    for i in range(0, ids.size(), 211):
        var huc := str(ids[i])
        var r := probe.for_key(huc, 0)
        if str(r["state"]) != CellProbe.RESOLVED:
            continue
        check(int(r["node_axis"]) == i,
                "%s probes to axis %d and node_order puts it at %d"
                % [huc, int(r["node_axis"]), i])
        checked += 1
    check(checked > 0, "no probed key resolved to a node axis")


func test_the_panel_says_why_the_second_node_row_has_no_plot() -> void:
    """M4 asks for two node rows and one of them is not on the wire: contract
    v2.0 advanced its major for "row removed or renamed: node.wetland_extent",
    and the fixture carries eight rows without it. A panel that plotted one
    and omitted the other silently would make an upstream absence look like a
    design decision taken here -- FieldScrubber's case again."""
    var fl := fixture()
    var node_rows := fl.row_names("deepest_winter", "node")
    check(node_rows.has("node.streamflow"), "no node.streamflow: %s" % str(node_rows))
    check(not node_rows.has("node.wetland_extent"),
            "node.wetland_extent is carried after all -- then the panel should plot it")

    var panel := ProbePanel.new()
    get_root().add_child(panel)
    panel.setup(fl)
    check(panel.state.text == ProbePanel.NOT_PROBED, "the panel does not start unprobed")

    var huc := str(fl.manifest["node_order"]["ids"][17])
    var probe := CellProbe.new()
    probe.bind(heightfield(), residence(), fl)
    var r := probe.for_key(huc, 0)
    r["window"] = "deepest_winter"
    r["row"] = "band.snowpack_swe"
    r["day"] = 29
    panel.show_probe(r)

    check(panel.absent_rows.text.contains("node.wetland_extent"),
            "the panel does not name the row it cannot plot: %s" % panel.absent_rows.text)
    check(panel.absent_rows.text.contains("901"),
            "the panel does not cite why the row left: %s" % panel.absent_rows.text)
    check(not panel.absent_rows.text.contains("node.streamflow"),
            "the panel reports the row it CAN plot as absent")
    check(panel.series.values.size() == fl.days("deepest_winter", "node.streamflow"),
            "the plot holds %d days" % panel.series.values.size())
    check(panel.series.marked_day == 29,
            "the plot marks day %d, the probe read day 29" % panel.series.marked_day)
    check(panel.series_caption.text.contains("node.streamflow"),
            "the caption does not name the row plotted: %s" % panel.series_caption.text)
    var counted: int = (int(panel.series.counts["zero"]) + int(panel.series.counts["below"])
            + int(panel.series.counts["in_scale"]) + int(panel.series.counts["no_value"]))
    check(counted == panel.series.values.size(),
            "%d days classified out of %d" % [counted, panel.series.values.size()])
    print("series panel: %s" % panel.series_caption.text)
    panel.queue_free()


# --------------------------------------------------------------------------
# the per-instance frame-cost benchmark (§19.8.9)
# --------------------------------------------------------------------------

func test_quantiles_are_nearest_rank_and_never_interpolate() -> void:
    """A frame budget is blown by the worst frame, so the benchmark quotes
    quantiles rather than a mean -- and a quantile with an unstated rule is not
    comparable with anyone else's. Nearest-rank returns a frame that actually
    happened; interpolating invents a frame time between two real ones and
    reports it as measured."""
    var s := PackedFloat64Array([10.0, 1.0, 3.0, 2.0, 100.0])
    check(FrameStats.quantile(s, 0.0) == 1.0, "q0 is not the smallest sample")
    check(FrameStats.quantile(s, 1.0) == 100.0, "q1 is not the largest sample")
    check(FrameStats.quantile(s, 0.5) == 3.0, "p50 of 5 samples is not the 3rd")
    # every returned value must be a sample, at every quantile
    for i in 101:
        var q := FrameStats.quantile(s, float(i) / 100.0)
        var found := false
        for v in s:
            if v == q:
                found = true
        check(found, "quantile %.2f returned %f, which is not one of the samples" % [float(i) / 100.0, q])
    check(is_nan(FrameStats.quantile(PackedFloat64Array(), 0.5)),
            "an empty run reported a quantile")

    var d := FrameStats.summarise(s)
    check(int(d["n"]) == 5, "summarise counted %d samples" % int(d["n"]))
    check(float(d["max"]) == 100.0 and float(d["min"]) == 1.0, "min/max are wrong")
    # the mean is carried only so it can be compared with p50: this run has one
    # frame at 100 ms and a median of 3, which is the shape a mean would hide
    check(float(d["mean"]) > float(d["p50"]) * 5.0,
            "the fixture no longer has a tail, so it is not testing for one")
    check(float(d["p99"]) == 100.0, "p99 of a 5-frame run is not its worst frame")


func test_the_fit_reports_what_it_costs_to_believe_it() -> void:
    """§19.8.9 asks for a coefficient, and a coefficient is only the right
    shape for the answer if cost is linear in instance count. The fit
    therefore travels with its residual and with the marginal cost between
    rungs: a straight line through a curve has a slope, and the slope is not a
    number anyone should carry away."""
    var xs := PackedFloat64Array([1000.0, 2000.0, 4000.0, 8000.0])
    var linear := PackedFloat64Array([2.0, 3.0, 5.0, 9.0])       # 1 ms + 1 us each
    var f := FrameStats.fit_linear(xs, linear)
    check(bool(f["ok"]), "a clean line did not fit: %s" % str(f.get("why", "")))
    check(absf(float(f["ms_per_instance"]) - 0.001) < 1e-9,
            "slope %s, expected 0.001" % String.num(float(f["ms_per_instance"]), 9))
    check(absf(float(f["intercept_ms"]) - 1.0) < 1e-9, "intercept is not 1 ms")
    check(float(f["r2"]) > 0.9999, "r2 of an exact line is %f" % float(f["r2"]))
    check(float(f["max_rel_residual"]) < 1e-9, "an exact line has a residual")

    # a curve still yields a slope, and the residual is what says not to use it
    var curved := PackedFloat64Array([1.0, 1.1, 1.2, 40.0])
    var g := FrameStats.fit_linear(xs, curved)
    check(bool(g["ok"]), "the curve did not fit at all")
    check(float(g["max_rel_residual"]) > 0.2,
            "a knee reported a %.3f residual -- the fit is not reporting its own cost"
            % float(g["max_rel_residual"]))
    var m := FrameStats.marginals(xs, curved)
    check(bool(m["ok"]), "marginals refused a 4-rung sweep")
    check(float(m["spread"]) > 10.0,
            "a flat-then-knee sweep reports a spread of %.1f between its cheapest and "
            % float(m["spread"]) + "dearest marginal instance")
    var m2 := FrameStats.marginals(xs, linear)
    check(absf(float(m2["spread"]) - 1.0) < 1e-6,
            "a straight line reports a marginal spread of %f" % float(m2["spread"]))

    # A rung that costs no more than the one below it makes the ratio
    # meaningless, and INF here reaches the artefact as `1e99999` -- not valid
    # JSON, and a fabricated magnitude standing where a measurement should be.
    var flat := FrameStats.marginals(xs, PackedFloat64Array([5.0, 5.0, 5.0, 40.0]))
    check(not flat.has("spread"),
            "a zero marginal still reported a ratio: %s" % str(flat.get("spread", "?")))
    check(str(flat.get("spread_undefined_because", "")).length() > 20,
            "the undefined spread gives no reason")

    check(not bool(FrameStats.fit_linear(
            PackedFloat64Array([1.0]), PackedFloat64Array([1.0]))["ok"]),
            "a single point was fitted with a line")
    check(not bool(FrameStats.fit_linear(
            PackedFloat64Array([5.0, 5.0]), PackedFloat64Array([1.0, 2.0]))["ok"]),
            "two samples at one instance count were fitted with a slope")


func test_the_benchmark_refuses_to_measure_frame_cost_headless() -> void:
    """The one thing this suite can assert about the benchmark is the thing
    that matters most: under --headless the display server draws nothing and
    still reports frame times, and those numbers look exactly like a very fast
    GPU. This test runs headless, so the refusal is the observable behaviour
    here -- if it ever stops refusing, the artefact starts carrying frame times
    for work that never happened."""
    check(DisplayServer.get_name() == "headless",
            "this suite is not running headless, so it cannot check the refusal")
    var packed := load("res://scenes/bench_instances.tscn") as PackedScene
    check(packed != null, "bench_instances.tscn did not load")
    if packed == null:
        return
    var bench = packed.instantiate()
    check(bench != null, "the benchmark scene did not instantiate")
    check(bench.get("configs") != null, "the benchmark exposes no configuration list")

    # the plan itself, which needs no display at all
    var plan: Array = bench.plan()
    check(plan.size() == 54, "the plan holds %d configurations" % plan.size())
    var techniques := {}
    var complexities := {}
    var counts := {}
    for c in plan:
        techniques[c["technique"]] = true
        complexities[c["complexity"]] = true
        counts[c["instances"]] = true
    check(techniques.size() == 2,
            "%d techniques swept -- MultiMesh and individual nodes are different "
            % techniques.size() + "coefficients and a single number would hide which")
    check(complexities.size() >= 2,
            "%d mesh complexities -- a per-instance cost quoted without a triangle "
            % complexities.size() + "count does not transfer to M5's archetypes")
    check(counts.size() >= 8, "%d instance counts on the ladder" % counts.size())
    check(counts.has(1000) and counts.has(150000),
            "the ladder does not span the 1e3..1.5e5 range §19.8.4's horizons land in")
    bench.free()


func test_the_fit_survives_a_renderer_with_no_gpu_timer() -> void:
    """`gpu_ms` carries an absence and a reason where the renderer does not
    implement the timer, rather than the zeros it reads -- and the code that
    fits a line across the sweep read `p50` straight off that absence. It threw
    at the very end of the run, after every configuration had been measured, so
    two complete benchmark runs produced results and no coefficients.

    An absence has to be handled everywhere it can appear. This builds the
    shape the fit sees on such a renderer and asks for the fits."""
    var packed := load("res://scenes/bench_instances.tscn") as PackedScene
    var bench = packed.instantiate()
    var rows := []
    for i in 4:
        rows.append({
            "technique": "multimesh", "complexity": "high",
            "instances": 1000 * (i + 1), "measured": true,
            "frame_ms": {"p50": 1.0 + float(i)},
            "gpu_ms": {"available": false, "why": "not implemented under this renderer"},
        })
    # one unmeasured rung, which must contribute nothing rather than a zero
    rows.append({
        "technique": "multimesh", "complexity": "high", "instances": 8000,
        "measured": false, "suspect": "the frames were not drawn",
    })
    bench.results = rows
    var f: Dictionary = bench.fits()
    check(f.has("multimesh|high"), "no fit for the only sweep given: %s" % str(f.keys()))
    if not f.has("multimesh|high"):
        bench.free()
        return
    var one: Dictionary = f["multimesh|high"]
    check(int(one["rungs_measured"]) == 4,
            "%d rungs fitted, and one of the five was unmeasured" % int(one["rungs_measured"]))
    check(bool(one["frame_p50"]["ok"]), "the frame fit failed: %s" % str(one["frame_p50"]))
    check(not bool(one["gpu_p50"]["ok"]),
            "a GPU fit was reported on a renderer that measures no GPU time")
    check(str(one["gpu_p50"]["why"]).length() > 10, "the absent GPU fit gives no reason")
    bench.free()


# --------------------------------------------------------------------------
# M5 -- form archetypes and the vegetation scatter
# --------------------------------------------------------------------------

const FAMILY_DIR := "res://assets/families/"

var _fs: FamilySet = null


func family_set() -> FamilySet:
    if _fs == null:
        _fs = FamilySet.load_from(FAMILY_DIR)
    return _fs


func test_every_wire_life_form_resolves_to_a_family() -> void:
    """The wire decides how many families are owed. `taxon_groups` names the
    group axis of the two vegetation rows, and a group with no family is a
    life form the client can be told about and cannot draw."""
    var fl := fixture()
    var fs := family_set()
    check(fs.is_loaded(), "no families loaded: %s" % fs.why_absent)
    if not fs.is_loaded():
        return
    var groups := fl.taxon_groups("deepest_winter", "band.pft_fractions")
    check(groups.size() == 4, "the wire names %d groups: %s" % [groups.size(), str(groups)])
    check(fs.missing_for(groups).is_empty(),
            "the wire names life forms with no family: %s" % str(fs.missing_for(groups)))
    for g in groups:
        check(fs.mesh_for(g) != null, "family %s carries no mesh" % g)
        check(fs.triangles_of(g) > 0, "family %s reports no triangles" % g)

    # both vegetation rows must name ONE group axis, or a plant would take its
    # width from one life form and its height from another
    check(Array(groups) == Array(fl.taxon_groups("deepest_winter", "band.pft.biomass")),
            "the two vegetation rows name different group axes")

    # and the five the roadmap asks for and the wire cannot key must be
    # recorded as absent WITH the reason, not merely missing
    var absent: Dictionary = fs.not_here().get("animal_families", {})
    check(absent.has("families") and (absent["families"] as Array).size() == 5,
            "the manifest does not record the five animal families as absent")
    check(str(absent.get("why", "")).contains("AFT"),
            "the manifest does not say why they are absent: %s" % str(absent.get("why", "")))
    print("families: %s for wire groups %s" % [str(fs.life_forms()), str(groups)])


func test_no_family_is_keyed_below_life_form() -> void:
    """Palettes are off the wire (decision 894) and the fixture aggregates to
    life form (872, 889), so a per-PFT or per-AFT mesh set has no key it could
    legally be indexed by -- and a size-baked form token is wrong rather than
    imprecise on most of a palette (§23.302, decision 180).

    Checked against the manifest rather than against intent: the family count
    must equal the wire's group count, not the 12-position PFT axis the sim
    aggregates from."""
    var fs := family_set()
    if not fs.is_loaded():
        return
    var fl := fixture()
    var groups := fl.taxon_groups("deepest_winter", "band.pft_fractions")
    check(fs.life_forms().size() == groups.size(),
            "%d families against %d wire groups -- a family set keyed below life form"
            % [fs.life_forms().size(), groups.size()])
    var shape: Array = fl.manifest["client_form"]["rows"]["deepest_winter/band.pft.biomass"]["shape"]
    check(int(shape[2]) == fs.life_forms().size(),
            "the row's group axis is %d wide and there are %d families"
            % [int(shape[2]), fs.life_forms().size()])
    check(str(fs.manifest.get("keyed_by", {}).get("axis", "")) == "life_form",
            "the manifest does not declare life_form as its key")
    check(str(fs.manifest.get("keyed_by", {}).get("never", "")).contains("894"),
            "the manifest does not cite why it is not keyed lower")

    # no family entry may carry a size: the family is authored, the individual
    # is parameters (§17.8.2)
    for life_form in fs.life_forms():
        var entry: Dictionary = fs.families[life_form]
        for forbidden in ["height", "size", "scale", "species", "pft", "aft"]:
            for k in entry:
                check(not str(k).to_lower().contains(forbidden),
                        "family %s carries a baked %s" % [life_form, forbidden])


func test_a_parameter_outside_its_range_is_refused_not_clamped() -> void:
    """A height outside a family's legal range is a computation that went wrong
    upstream. Pulling it to the nearest legal value produces a plausible plant
    and destroys the evidence -- the refusal has to survive as a refusal."""
    var fs := family_set()
    if not fs.is_loaded():
        return
    var r := fs.range_of("tree", "height_m")
    check(not r.is_empty(), "tree declares no height range")
    var too_tall := float(r["max"]) * 2.0
    var too_short := float(r["min"]) * 0.5

    check(fs.check("tree", "height_m", float(r["max"])) == "",
            "a height at the top of the range was refused")
    check(fs.check("tree", "height_m", too_tall) != "", "an over-tall tree was accepted")
    check(fs.check("tree", "height_m", too_short) != "", "an under-tall tree was accepted")
    check(fs.check("tree", "height_m", NAN) != "", "a NAN height was accepted")
    check(fs.check("tree", "girth_m", 1.0) != "",
            "a parameter the family does not declare was accepted")
    check(fs.check("nothing", "height_m", 5.0) != "", "a life form with no family was accepted")

    var bad := fs.instance_transform("tree", Vector3.ZERO, too_tall, 3.0)
    check(not bool(bad["ok"]), "an out-of-range height produced a transform")
    check(str(bad["why"]).contains("legal range"),
            "the refusal does not name the range: %s" % str(bad["why"]))
    var t: Transform3D = bad["transform"]
    check(t == Transform3D.IDENTITY,
            "the refusal returned a usable transform -- a caller ignoring it would draw a plant")
    # the clamped value must NOT appear anywhere in the returned transform
    check(absf(t.basis.get_scale().y - float(r["max"])) > 0.001,
            "the refusal returned the clamped height, which is the thing it is not allowed to do")

    var good := fs.instance_transform("tree", Vector3.ZERO, 20.0, 6.0)
    check(bool(good["ok"]), "a legal tree was refused: %s" % str(good["why"]))
    var gt: Transform3D = good["transform"]
    check(absf(gt.basis.get_scale().y - 20.0) < 1e-4, "the height did not reach the transform")
    check(absf(gt.basis.get_scale().x - 6.0) < 1e-4, "the crown did not reach the transform")


func test_the_exaggeration_is_applied_after_the_check_not_before() -> void:
    """M1 draws this basin at 12x relief, so a plant at true height reads as
    twelve times too short against the ground it stands on. The exaggeration is
    a property of the view and not of the plant: applied BEFORE the range check
    it refused every legal tree in the basin, which is how the first version of
    the scatter placed exactly zero instances out of two and a half million."""
    var fs := family_set()
    if not fs.is_loaded():
        return
    var r := fs.range_of("tree", "height_m")
    var height := 20.0
    check(height * 12.0 > float(r["max"]),
            "the fixture no longer exceeds the range under exaggeration, so this test is idle")
    var out := fs.instance_transform("tree", Vector3.ZERO, height, 6.0, 12.0)
    check(bool(out["ok"]),
            "a legal height was refused once the view's exaggeration was applied: %s"
            % str(out["why"]))
    var t: Transform3D = out["transform"]
    check(absf(t.basis.get_scale().y - height * 12.0) < 1e-3,
            "the exaggeration did not reach the transform: y scale %f" % t.basis.get_scale().y)
    check(absf(t.basis.get_scale().x - 6.0) < 1e-4,
            "the exaggeration reached the crown axis, which is horizontal")


func test_the_families_hold_the_unit_convention_the_transform_relies_on() -> void:
    """An instance transform is scale(crown_m, height_m, crown_m), which is only
    a size if the mesh is one metre tall and one metre across standing on the
    origin plane. The builder normalises the geometry rather than trusting the
    authoring numbers, and this is where that is checked."""
    var fs := family_set()
    if not fs.is_loaded():
        return
    for life_form in fs.life_forms():
        var mesh := fs.mesh_for(life_form)
        var aabb := mesh.get_aabb()
        check(absf(aabb.size.y - 1.0) < 0.01,
                "%s is %.3f m tall at unit scale" % [life_form, aabb.size.y])
        check(absf(aabb.position.y) < 0.01,
                "%s does not stand on the origin plane (base at %.3f)"
                % [life_form, aabb.position.y])
        check(aabb.size.x <= 1.001 and aabb.size.z <= 1.001,
                "%s is %.3f x %.3f across at unit scale" % [life_form, aabb.size.x, aabb.size.z])
        # the phenology mask has to survive export, or a shader has nothing to
        # multiply and every plant tints as one thing
        var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
        check(colours.size() > 0, "%s exported no vertex colours -- no phenology mask" % life_form)
    var woody: Mesh = fs.mesh_for("tree")
    var tc: PackedColorArray = woody.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
    var lo := 2.0
    var hi := -1.0
    for c in tc:
        lo = minf(lo, c.r)
        hi = maxf(hi, c.r)
    check(lo < 0.5 and hi > 0.5,
            "the tree's phenology mask does not separate trunk from canopy (%f..%f)" % [lo, hi])


func test_the_cost_model_refuses_outside_its_measured_span() -> void:
    """The model is a line through the three mesh complexities the benchmark
    measured. Carried past them it is an extrapolation wearing a measurement's
    name, which is the thing §19.8.9 declined to write."""
    var fc := FrameCost.load_from("multimesh")
    check(fc.is_loaded(), "no frame-cost measurement: %s" % fc.why_absent)
    if not fc.is_loaded():
        return
    var span := fc.measured_span()
    check(span.x > 0.0 and span.y > span.x, "the measured span is degenerate: %s" % str(span))
    check(bool(fc.per_instance_ns(int(span.x))["ok"]), "the bottom of the span was refused")
    check(bool(fc.per_instance_ns(int(span.y))["ok"]), "the top of the span was refused")
    var under := fc.per_instance_ns(int(span.x) - 1)
    check(not bool(under["ok"]), "a complexity below the measured span was priced")
    check(str(under["why"]).contains("measured span"),
            "the refusal does not say why: %s" % str(under["why"]))
    check(not bool(fc.per_instance_ns(int(span.y) * 2)["ok"]),
            "a complexity above the measured span was priced")

    # every family must sit inside the span, or it cannot be priced at all
    var fs := family_set()
    for life_form in fs.life_forms():
        var t := fs.triangles_of(life_form)
        check(bool(fc.per_instance_ns(t)["ok"]),
                "family %s at %d triangles cannot be priced by the measurement" % [life_form, t])
    var budget := fc.instances_within_budget(fs.triangles_of("tree"))
    check(budget > 1000, "the budget holds only %d trees" % budget)
    print("cost model: %.2f + %.5f ns per triangle, budget holds %d trees of %d triangles"
            % [fc.intercept_ns, fc.slope_ns_per_triangle, budget, fs.triangles_of("tree")])


func test_the_scatter_reports_what_it_could_not_draw() -> void:
    """The density the wire implies is very often more than a frame holds --
    grass runs to a hundred million instances inside a 1.5 km horizon. The
    scatter draws one stated share across every family and reports it, rather
    than thinning quietly: a picture at a share of 1e-3 is a sample of a stand,
    and it is only readable as one if the number travels with it."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    var bound := v.bind_families()
    check(bool(bound["ok"]), "families did not bind: %s" % str(bound.get("why", "")))
    check(v.show_field("deepest_winter", "band.pft_fractions", 45), "the field did not paint")

    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    var r := v.scatter_at(centre)
    check(bool(r.get("ok", false)), "the scatter did not build: %s" % str(r.get("why", "")))
    if not bool(r.get("ok", false)):
        v.queue_free()
        return

    check(int(r["texels"]) > 0, "the scatter covered no texels")
    check(int(r["day"]) == 45, "the scatter used day %d and the terrain shows 45" % int(r["day"]))
    check(str(r["window"]) == "deepest_winter", "the scatter used the wrong window")
    check(int(r["refused_parameters"]) == 0,
            "%d instances were refused -- the scatter is computing illegal parameters"
            % int(r["refused_parameters"]))

    var implied: Dictionary = r["implied"]
    var placed: Dictionary = r["placed"]
    var total_implied := 0.0
    var total_placed := 0
    for g in r["groups"]:
        total_implied += float(implied.get(g, 0.0))
        total_placed += int(placed.get(g, 0))
    check(total_implied > 0.0, "the wire implied no vegetation at all here")
    check(total_placed > 0, "nothing was placed")
    check(float(r["share_drawn"]) <= 1.0, "a share above one was reported")
    check(str(r["share_bound_by"]).length() > 10,
            "the report does not say what bound the share: %s" % str(r["share_bound_by"]))
    check(absf(float(r["share_drawn"]) * total_implied - float(total_placed))
            < 0.05 * float(total_placed) + 100.0,
            "placed %d does not follow from share %f of implied %f"
            % [total_placed, float(r["share_drawn"]), total_implied])

    var budget: Dictionary = r["budget"]
    check(bool(budget["ok"]), "no budget was computed: %s" % str(budget.get("why", "")))
    check(float(budget["implied_ms"]) > 0.0, "the implied cost is zero")
    check(float(budget["budget_ms"]) > 0.0, "no frame budget came from the measurement")
    print("scatter: %d texels, %s implied at %.0f ms against a %.1f ms budget, share %s (%s)"
            % [int(r["texels"]), String.num(total_implied, 0), float(budget["implied_ms"]),
               float(budget["budget_ms"]), String.num(float(r["share_drawn"]), 5),
               str(r["share_bound_by"])])

    # the scatter must exist in the scene as MultiMesh instances, one per family
    var nodes := 0
    for child in v.get_children():
        if String(child.name).begins_with("Vegetation_"):
            nodes += 1
            check(child is MultiMeshInstance3D,
                    "%s is not a MultiMeshInstance3D" % child.name)
    check(nodes > 0, "no vegetation reached the scene")
    v.queue_free()


func test_the_project_does_not_import_blend_sources() -> void:
    """Godot imports .blend natively by shelling out to Blender, and headless
    with no Blender path configured that fails with "Blender path is invalid or
    not set" -- red gate, over files the project never loads. tools/blender/
    holds the form-archetype SOURCES; the exported .glb is what the client
    reads.

    The guard is here rather than in the shell because re-enabling the importer
    is something the editor does silently, and the failure it causes looks like
    a broken Blender install rather than like a decision that was reversed."""
    check(ProjectSettings.has_setting("filesystem/import/blender/enabled"),
            "this engine has no .blend import setting -- the guard is checking nothing")
    check(not bool(ProjectSettings.get_setting("filesystem/import/blender/enabled", true)),
            "the .blend importer is enabled. tools/blender/ holds sources the project never "
            + "loads, and importing them shells out to Blender, which fails headlessly.")

    # and the sources are really there, or the setting is guarding nothing
    var dir := DirAccess.open("res://tools/blender/")
    var blends := 0
    if dir != null:
        for f in dir.get_files():
            if f.ends_with(".blend"):
                blends += 1
    check(blends > 0,
            "no .blend sources in tools/blender/ -- either they moved or the build never ran")

    # THE COMMENTS IN project.godot ARE NOT ASSERTED HERE, AND THAT IS A
    # RETRACTION. A previous version of this test required them to be present,
    # because the engine had silently deleted them once. But the engine rewrites
    # that file on any run -- including this suite's own import step -- so the
    # assertion turned the gate red for something no change to the code caused,
    # which is exactly the failure tools/verify.sh's header warns about: a gate
    # that fails for unrelated reasons is a gate someone switches off.
    #
    # The setting survives rewrites and is asserted above. The reasons live in
    # tools/blender/README.md and CONTRIBUTING.md, which the engine does not
    # own. Prose does not belong in a file another program writes.

    # the exported families load through the glTF importer, which is a
    # different importer and must not be affected by the setting above
    var fs := family_set()
    check(fs.is_loaded(), "the exported families did not load: %s" % fs.why_absent)
    print("blend import: disabled, %d sources present, %d families load from glTF"
            % [blends, fs.life_forms().size()])


func test_phenology_is_the_cell_measured_against_itself() -> void:
    """Normalised over the ROW's range instead, a cell that never carries much
    biomass would read as permanently wintering and a productive one as
    permanently at peak -- a statement about where a cell sits in the basin,
    not about where it sits in its year."""
    var vs := VegetationScatter.new()
    var season := {
        "lo": PackedFloat64Array([0.0, 2.0, 5.0, 0.0]),
        "hi": PackedFloat64Array([10.0, 4.0, 5.0, 0.0]),
    }
    check(vs.phenology_for(season, 0, 0.0) == 0.0, "a cell at its own trough is not 0")
    check(vs.phenology_for(season, 0, 10.0) == 1.0, "a cell at its own peak is not 1")
    check(absf(vs.phenology_for(season, 0, 5.0) - 0.5) < 1e-9, "the midpoint is not 0.5")
    # cell 1 has a narrow range: the same absolute value reads differently there,
    # which is the whole point of measuring a cell against itself
    check(absf(vs.phenology_for(season, 1, 3.0) - 0.5) < 1e-9,
            "a narrow-range cell is not normalised over its own range")
    check(vs.phenology_for(season, 0, 3.0) != vs.phenology_for(season, 1, 3.0),
            "two cells with different ranges gave one value for one biomass")
    # a cell whose biomass never moves: trough == peak == today, and the
    # ratio's limit is 1 because the day's value IS the cell's maximum
    check(vs.phenology_for(season, 2, 5.0) == 1.0,
            "a cell with no seasonal signal was given a midpoint rather than its own state")
    check(vs.phenology_for(season, 3, 0.0) == 1.0, "a flat zero cell was not handled")
    check(vs.phenology_for(season, 0, NAN) == 1.0, "a NAN biomass produced a NAN tint")
    check(vs.phenology_for(season, 99, 1.0) == 1.0, "an out-of-range cell was not handled")
    for v in [-5.0, 50.0]:
        var p := vs.phenology_for(season, 0, v)
        check(p >= 0.0 and p <= 1.0, "phenology left [0, 1] at biomass %f: %f" % [v, p])


func test_the_tint_moves_with_the_season_it_is_read_from() -> void:
    """§17.8.2 asks for phenology as a mask plus a shader parameter. The mask is
    authored; the parameter has to come from the wire, and a tint that reads the
    same on every day of the window is not reading anything.

    Checked through the scatter's own report rather than through the instances:
    MultiMesh custom data does not read back under the headless renderer, so an
    assertion on the instances would be an assertion on zeros."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    v.bind_families()
    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)

    var seen := []
    for day in [22, 89]:
        check(v.show_field("deepest_winter", "band.pft_fractions", day),
                "the field did not paint for day %d" % day)
        var r := v.scatter_at(centre)
        check(bool(r.get("ok", false)), "the scatter failed on day %d" % day)
        var ph: Dictionary = r["phenology"]
        var span: Array = ph["range_drawn"]
        check(span.size() == 2, "day %d reported no phenology range" % day)
        for x in span:
            check(float(x) >= 0.0 and float(x) <= 1.0,
                    "phenology %f is outside its declared [0, 1] range" % float(x))
        check(int(ph["days_sampled"]) > 1,
                "the seasonal range was taken from %d day(s)" % int(ph["days_sampled"]))
        check(int(r["refused_parameters"]) == 0,
                "%d instances refused on day %d" % [int(r["refused_parameters"]), day])
        seen.append(span)
    check(float(seen[1][0]) - float(seen[0][1]) > 0.2,
            "the tint barely moves between mid-window (%s) and the window's end (%s) -- "
            % [str(seen[0]), str(seen[1])] + "it is not carrying the season")
    print("phenology: mid-window %s, window end %s" % [str(seen[0]), str(seen[1])])

    # and the tint has to reach the scene as a shader, not as a flat albedo:
    # a StandardMaterial3D cannot read custom data at all
    var node := v.get_node_or_null("Vegetation_grass")
    check(node != null, "no grass in the scene to check the material on")
    if node != null:
        check(node.material_override is ShaderMaterial,
                "the scatter's material is %s, which cannot read per-instance custom data"
                % node.material_override.get_class())
        check((node.material_override as ShaderMaterial).shader != null,
                "the scatter's ShaderMaterial carries no shader")
        check((node.multimesh as MultiMesh).use_custom_data,
                "the MultiMesh does not carry custom data, so the tint reaches nothing")
        # With use_colors off, the compatibility renderer delivers COLOR as zero
        # rather than the mesh's vertex colour: the authored mask arrives as 0,
        # every plant renders as bare structure, and the season never shows. It
        # looks like working vegetation, which is how it survived a milestone.
        # Only the FLAG is checkable here -- the instance colours themselves read
        # back black headless like everything else in a MultiMesh, and the values
        # were confirmed by rendering the shader's inputs to a window instead.
        check((node.multimesh as MultiMesh).use_colors,
                "the MultiMesh does not enable instance colours, so COLOR reaches the "
                + "shader as zero and the phenology mask is lost")
    v.queue_free()


func test_multimesh_custom_data_does_not_read_back_headless() -> void:
    """Pinning an ENGINE limitation, not this project's code. Under the dummy
    renderer a MultiMesh has no per-instance store at all: transforms read back
    as the identity, custom data as zeros, and `buffer` is empty, whatever was
    written into them.

    Without this test the next person writes the obvious assertion -- read an
    instance back and compare -- and gets a test that passes by comparing zero
    against zero, or one they debug in the wrong file. The first version of this
    very test asserted that transforms DID round-trip, because it happened to
    write the identity and read the identity back.

    If a future engine starts returning the data, this fails and says so, which
    is the moment to assert on the instances instead of on the scatter's report.
    """
    if DisplayServer.get_name() != "headless":
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_custom_data = true
    mm.mesh = BoxMesh.new()
    mm.instance_count = 2
    var xf := Transform3D(Basis().scaled(Vector3(2.0, 3.0, 4.0)), Vector3(1.0, 2.0, 3.0))
    for i in 2:
        mm.set_instance_transform(i, xf)
        mm.set_instance_custom_data(i, Color(0.75, 0.25, 0.5, 1.0))

    # what DOES survive: the resource's own properties, which is why the scatter
    # test can assert instance counts and the custom-data flag and nothing else
    check(mm.instance_count == 2, "instance_count no longer survives headless")
    check(mm.use_custom_data, "use_custom_data no longer survives headless")

    var back := mm.get_instance_transform(0)
    check(back == Transform3D.IDENTITY,
            "transforms now read back headless as %s -- assert the scatter's instances "
            % str(back) + "directly instead of its report")
    var read := mm.get_instance_custom_data(0)
    check(read.r == 0.0 and read.g == 0.0 and read.b == 0.0,
            "custom data now reads back headless as %s: assert the scatter's instances "
            % str(read) + "directly instead of its report")
    check(mm.buffer.size() == 0,
            "the MultiMesh buffer is %d long headless, so the instances can be checked "
            % mm.buffer.size() + "directly now")


func test_the_frame_probe_measures_what_a_look_would_report() -> void:
    """`tools/screenshot.sh` photographs the running app; this is the half of it
    that can be checked without a screen. The census exists so "that looks
    wrong" becomes a number a commit message can carry -- three defects this
    project shipped were invisible to every data check and obvious in a frame.

    The interesting case is the last one: two frames that differ nowhere. A
    comparison that reported +0.000 -> +0.000 across identical images would look
    like a measured absence of change, and it is not -- it is the absence of a
    measurement. The tool has to say which."""
    var green := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
    green.fill(Color(0.2, 0.5, 0.2))
    var brown := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
    brown.fill(Color(0.5, 0.35, 0.2))
    var grey := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
    grey.fill(Color(0.3, 0.3, 0.3))
    var black := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
    black.fill(Color(0.01, 0.01, 0.01))

    var g := FrameProbe.summarise(green)
    check(int(g["pixels"]) == 64, "the census counted %d of 64 pixels" % int(g["pixels"]))
    check(int(g["coloured"]) == 64, "a green frame reports %d coloured" % int(g["coloured"]))
    check(float(g["green_minus_red"]) > 0.2, "green does not read as green: %f"
            % float(g["green_minus_red"]))
    var b := FrameProbe.summarise(brown)
    check(float(b["green_minus_red"]) < 0.0, "brown does not read as red-dominant")
    # the axis a seasonal tint moves along has to change SIGN between the two
    check(sign(float(g["green_minus_red"])) != sign(float(b["green_minus_red"])),
            "senescent and growing do not separate on green-minus-red, so the one axis "
            + "this tool uses to see a season does not see it")

    var n := FrameProbe.summarise(grey)
    check(int(n["neutral"]) == 64, "a grey frame reports %d neutral" % int(n["neutral"]))
    check(int(n["coloured"]) == 0, "grey was counted as colour")
    var k := FrameProbe.summarise(black)
    check(int(k["near_black"]) == 64, "a black frame reports %d near-black" % int(k["near_black"]))
    check(int(k["neutral"]) == 0, "near-black was also counted as neutral, double-counting it")

    var diff := FrameProbe.compare(green, brown)
    check(bool(diff["ok"]), "comparing two frames failed")
    check(int(diff["differing"]) == 64, "%d of 64 pixels differ" % int(diff["differing"]))
    check(float(diff["green_minus_red_a"]) > 0.0 and float(diff["green_minus_red_b"]) < 0.0,
            "the comparison does not carry each side's own colour")

    var same := FrameProbe.compare(green, green)
    check(int(same["differing"]) == 0, "a frame differs from itself")
    var sized := FrameProbe.compare(green, Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
    check(not bool(sized["ok"]), "two differently sized frames were compared anyway")

    print("frame probe: green g-r %+.2f, brown g-r %+.2f, grey %d neutral, black %d near-black"
            % [float(g["green_minus_red"]), float(b["green_minus_red"]),
               int(n["neutral"]), int(k["near_black"])])


func test_the_frame_probe_can_tell_a_lit_surface_from_a_flat_one() -> void:
    """`summarise` reports the MEAN, and a hillshade that failed is a frame
    whose mean is fine. A terrain lit flat, one whose normals all point up, and
    one drawn with no light at all differ from a working hillshade in the
    SPREAD of brightness and in nothing else -- so this is the half of the
    instrument that can see relief, and these are its two ends.
    """
    var flat := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
    flat.fill(Color(0.5, 0.5, 0.5))
    var lf := FrameProbe.luminance(flat)
    check(int(lf["levels"]) == 1, "a single-colour frame reports %d brightness levels"
            % int(lf["levels"]))
    check(absf(float(lf["spread"])) < 0.01, "a flat frame has a spread of %f"
            % float(lf["spread"]))

    var lit := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
    for y in 64:
        for x in 64:
            var v := 0.1 + 0.8 * float(x) / 63.0
            lit.set_pixel(x, y, Color(v, v, v))
    var ll := FrameProbe.luminance(lit)
    check(int(ll["levels"]) > 20, "a graded frame reports only %d brightness levels"
            % int(ll["levels"]))
    check(float(ll["spread"]) > 0.5, "a frame graded 0.1..0.9 has a spread of %f"
            % float(ll["spread"]))
    check(float(ll["p05"]) < float(ll["p50"]) and float(ll["p50"]) < float(ll["p95"]),
            "the percentiles are not ordered")

    # A frame that drew nothing must say so rather than report a spread of zero,
    # which is what a flat surface ALSO reports. The two must not read alike.
    var dark := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
    dark.fill(Color(0, 0, 0))
    var ld := FrameProbe.luminance(dark)
    check(int(ld["counted"]) == 0, "a black frame counted %d pixels" % int(ld["counted"]))
    check(ld.has("why"), "a black frame reported a spread instead of saying it is black")

    print("frame probe relief: flat %d level, graded %d levels spread %.2f"
            % [int(lf["levels"]), int(ll["levels"]), float(ll["spread"])])


func test_ramp_agreement_survives_a_light_and_not_a_highlight() -> void:
    """The measurement that found the specular defect, and the reason it can be
    trusted: it has to pass a frame that is only the ramp UNDER A LIGHT, and
    fail one where white has been added to it.

    A diffuse light scales all three channels by one number, so it moves a
    pixel along a ray from the origin and leaves the ratio between channels --
    which is the part the ramp chose -- untouched. A specular highlight ADDS
    the light's colour instead, and white added to a saturated ramp colour is a
    different colour, not a brighter one. Measured on the running app: 43.5% of
    the overlay's pixels lay on the declared ramp with the default specular
    term and 99.8% with it off.
    """
    var lit := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
    var washed := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
    for y in 64:
        for x in 64:
            var c := FieldOverlay.ramp(float(x) / 63.0)
            # a plausible hillshade: a scalar per pixel, never the same twice
            var k: float = 0.35 + 0.6 * float(y) / 63.0
            lit.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k))
            # the same surface with a white specular term added on top
            var w := 0.35
            washed.set_pixel(x, y, Color(minf(c.r * k + w, 1.0), minf(c.g * k + w, 1.0),
                                         minf(c.b * k + w, 1.0)))
    var a := FrameProbe.ramp_agreement(lit, FieldOverlay.RAMP_STOPS)
    check(float(a["on_ramp_fraction"]) > 0.95,
            "only %.1f%% of a frame that IS the ramp under a light reads as on the ramp, so "
            % (100.0 * float(a["on_ramp_fraction"]))
            + "the measurement is reporting the light rather than the colour")
    var b := FrameProbe.ramp_agreement(washed, FieldOverlay.RAMP_STOPS)
    check(float(b["on_ramp_fraction"]) < float(a["on_ramp_fraction"]) - 0.3,
            "adding white to every pixel barely moved the agreement (%.2f -> %.2f), so this "
            % [float(a["on_ramp_fraction"]), float(b["on_ramp_fraction"])]
            + "measurement could not have found the specular highlight it did find")

    # And a frame of some other palette entirely must not read as this ramp.
    var alien := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
    alien.fill(Color(0.9, 0.35, 0.1))
    var c := FrameProbe.ramp_agreement(alien, FieldOverlay.RAMP_STOPS)
    check(float(c["on_ramp_fraction"]) < 0.05, "an orange frame reads as %.1f%% viridis"
            % (100.0 * float(c["on_ramp_fraction"])))

    print("ramp agreement: lit %.1f%%, white-washed %.1f%%, alien %.1f%%"
            % [100.0 * float(a["on_ramp_fraction"]), 100.0 * float(b["on_ramp_fraction"]),
               100.0 * float(c["on_ramp_fraction"])])


func test_the_hillshade_arrives_from_the_north_west() -> void:
    """A comment said `# NW, the cartographic default` beside a light that came
    from the NORTH-EAST, and it said so for four milestones. Nothing blind
    could catch it: the light was on, the surface was shaded, every number in
    every report was right, and the shading simply came from the wrong side.
    Relief inversion -- ridges read as valleys -- is what that costs, and it is
    the one hillshade error a reader mistakes for the terrain.

    WHICH WAY IS NORTH IS ASKED OF THE TRANSFORM, not restated from the comment
    beside it. `mesh_to_world` is the only thing in the project that knows, so
    a test that repeated the convention from a docstring would agree with
    whatever the docstring said -- which is exactly how this survived.
    """
    var hf := heightfield()
    var tm := TerrainMesh.new()
    tm.build(hf, 16, 1.0)
    var here := tm.mesh_to_world(Vector3.ZERO, hf)
    var zward := tm.mesh_to_world(Vector3(0.0, 0.0, 1000.0), hf)
    var xward := tm.mesh_to_world(Vector3(1000.0, 0.0, 0.0), hf)
    check(zward.y < here.y, "+Z in mesh space does not go south in EPSG:5070")
    check(xward.x > here.x, "+X in mesh space does not go east in EPSG:5070")

    # Where the photons go. A DirectionalLight3D shines down its own -Z.
    var basis := Basis.from_euler(Vector3(deg_to_rad(TerrainView.SUN_ALTITUDE_DEGREES),
                                          deg_to_rad(TerrainView.SUN_AZIMUTH_DEGREES), 0.0))
    var travel := basis * Vector3(0.0, 0.0, -1.0)
    check(travel.y < 0.0, "the sun shines upward")
    check(travel.x > 0.1, "the light does not travel east, so it does not arrive from the west")
    check(travel.z > 0.1, "the light does not travel south, so it does not arrive from the north")
    print("hillshade: light travels (%.2f, %.2f, %.2f) -- east and south, so it arrives "
            % [travel.x, travel.y, travel.z] + "from the north-west")


func test_the_verdict_is_read_and_never_supplied() -> void:
    """A screenshot of this basin is a screenshot of a run that fails several
    of its acceptance criteria, and the verdict has to travel with the picture.
    The three states are the whole design: today's fixtures carry no verdict at
    all, so ABSENT is not an edge case -- it is the case, and it has to be as
    loud as a failure rather than as quiet as a pass.
    """
    var none := AncestorVerdict.read_from({"run": {"base_commit": "abc1234567"}})
    check(none.state == AncestorVerdict.ABSENT, "a manifest with no acceptance block read as %s"
            % none.state)
    check(none.headline().contains("NO ACCEPTANCE VERDICT"),
            "an absent verdict does not announce itself: %s" % none.headline())
    check(none.passed < 0 and none.failed < 0,
            "an absent verdict supplied counts, which is the one thing it must never do")

    var scored := AncestorVerdict.read_from({"run": {"base_commit": "5317027abcdef",
            "acceptance": {"scored_at_commit": "5317027", "passed": 7, "failed": 5,
                           "not_evaluable": 0,
                           "failed_criteria": [{"id": 1, "name": "snow",
                                                "renders_as": "a near-bare snowpack"}]}}})
    check(scored.state == AncestorVerdict.SCORED, "a matching verdict read as %s" % scored.state)
    check(scored.passed == 7 and scored.failed == 5, "the counts did not survive the read")
    check(scored.headline().contains("7 pass") and scored.headline().contains("5 fail"),
            "the headline does not carry the score: %s" % scored.headline())
    var named := scored.named_fails()
    check(named.size() == 1 and named[0].contains("near-bare snowpack"),
            "the named fail lost how it renders, which is the half a picture needs")

    # An abbreviated hash against a full one is the SAME commit. Reporting that
    # as stale would put the word on a correct verdict and teach a reader to
    # ignore it.
    check(AncestorVerdict.read_from({"run": {"base_commit": "5317027abcdef",
            "acceptance": {"scored_at_commit": "5317027abcdef0000", "passed": 1,
                           "failed": 0}}}).state == AncestorVerdict.SCORED,
            "a full hash and its abbreviation read as two different commits")

    var stale := AncestorVerdict.read_from({"run": {"base_commit": "aaaaaaa1111",
            "acceptance": {"scored_at_commit": "bbbbbbb2222", "passed": 12, "failed": 0}}})
    check(stale.state == AncestorVerdict.STALE,
            "a verdict scored at another commit read as %s" % stale.state)
    check(stale.headline().contains("DOES NOT MATCH"),
            "a stale verdict reads as a passing one: %s" % stale.headline())

    # THE FOURTH STATE, on the numbers it was written for: the verdict was
    # scored on `m0-instrumented-001` at 897285d and this fixture was cut from
    # `millennium-001` at 6421064. Commit equality calls that stale. The
    # trajectory was proven identical field by field, so it is not.
    var proven := {"run": {"base_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
            "acceptance": {"scored_at_commit": "5317027", "scored_run_dir": "m0-instrumented-001",
                    "passed": 7, "failed": 5, "not_evaluable": 0,
                    "equivalence": {"to_commit": "6421064", "to_run": "millennium-001",
                            "method": "M0 purity gate", "ticks": 3650,
                            "state_arrays_identical": 33, "fields_compared": 18,
                            "fields_matching": 18,
                            "fields_excluded": [
                                    {"field": "outlet_q", "why": "a deliberate gauge change"}]}}}}
    var eq := AncestorVerdict.read_from(proven)
    check(eq.state == AncestorVerdict.EQUIVALENT,
            "a verdict scored on a run proven identical to this fixture read as %s" % eq.state)
    check(eq.headline().contains("m0-instrumented-001"),
            "the headline hides which run was actually scored: %s" % eq.headline())
    check(eq.headline().contains("18/18") and eq.headline().contains("3650 ticks"),
            "the headline carries the claim without the proof: %s" % eq.headline())
    check(eq.headline().contains("1 field excluded"),
            "the proof excluded a field and the banner did not say so: %s" % eq.headline())
    check(eq.excluded_fields().size() == 1
            and eq.excluded_fields()[0].contains("gauge"),
            "the excluded field's reason did not survive the read")
    # The emitter writes `scored_run_dir`; this header declared `scored_on_run`.
    # Both are read, so a proof that checks out is not refused over the name of
    # a label neither side interprets.
    var alias := proven.duplicate(true)
    alias["run"]["acceptance"].erase("scored_run_dir")
    alias["run"]["acceptance"]["scored_on_run"] = "m0-instrumented-001"
    check(AncestorVerdict.read_from(alias).headline().contains("m0-instrumented-001"),
            "the older of the two run-name keys stopped being read")

    # THE PROOF IS CHECKED, NOT BELIEVED, and each of these is a way a claim
    # could be true-looking and wrong. All of them fall back to STALE, which is
    # the conservative reading, and say which test failed rather than which
    # word they landed on.
    var broken := {
        "proves equivalence to a third commit": {"to_commit": "deadbee",
                "fields_compared": 18, "fields_matching": 18},
        "compares nothing": {"to_commit": "6421064",
                "fields_compared": 0, "fields_matching": 0},
        "matches most rather than all": {"to_commit": "6421064",
                "fields_compared": 18, "fields_matching": 17},
        "steps around a field without saying why": {"to_commit": "6421064",
                "fields_compared": 18, "fields_matching": 18,
                "fields_excluded": [{"field": "outlet_q"}]},
        "excludes something unnamed": {"to_commit": "6421064",
                "fields_compared": 18, "fields_matching": 18,
                "fields_excluded": ["outlet_q"]},
    }
    for label in broken:
        var bad := AncestorVerdict.read_from({"run": {
                "base_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
                "acceptance": {"scored_at_commit": "5317027", "passed": 7, "failed": 5,
                        "equivalence": broken[label]}}})
        check(bad.state == AncestorVerdict.STALE,
                "an equivalence proof that %s read as %s rather than stale" % [label, bad.state])
        check(bad.headline().contains("does not check out"),
                "a broken proof reads like a missing one, which is quieter than it should be: %s"
                % bad.headline())
    # A missing proof and a broken one must not read alike either: one is a
    # verdict nobody connected to this fixture, the other is a connection that
    # failed, and the second is the more alarming of the two.
    check(not stale.headline().contains("does not check out"),
            "a verdict with no equivalence claim is reported as a failed one")

    # THE BANNER ITSELF, for each state. Headless cannot see the colour, and it
    # can see the text -- which is the half that carries the meaning, and the
    # half that has four branches now rather than three.
    var banner := VerdictBanner.new()
    banner.setup()
    for v in [none, scored, eq, stale]:
        banner.show_verdict(v)
        check(banner._headline.text == v.headline(),
                "the banner did not render the %s headline" % v.state)
        check(banner._headline.text.length() > 20,
                "the %s banner is nearly empty, which reads as nothing to declare" % v.state)
    banner.show_verdict(eq)
    check(banner._fails.visible and banner._fails.text.contains("excluded"),
            "the banner drops the equivalence proof's exclusions: %s" % banner._fails.text)
    banner.show_verdict(none)
    check(not banner._fails.visible, "an absent verdict shows an empty second line")
    banner.free()

    # THE COLOUR, WHICH HEADLESS CANNOT SEE AND ARITHMETIC CAN.
    #
    # Photographed over `band.bare_fraction` with the basin under the controls,
    # the amber headline was ALL BUT INVISIBLE -- it had been drawn straight
    # onto the scene, and amber against the bright end of the ramp is barely a
    # colour difference at all. Twenty-six asserts on this text read the string
    # and the string was perfect. So the banner draws its own plate, and this
    # asserts the thing the picture showed: every state must stay readable over
    # the WORST the ramp can put behind it, which is its brightest stop.
    var worst := FieldOverlay.RAMP_STOPS[FieldOverlay.RAMP_STOPS.size() - 1]
    var plated := VerdictBanner.plate_over(worst)
    for st in [AncestorVerdict.ABSENT, AncestorVerdict.SCORED,
            AncestorVerdict.EQUIVALENT, AncestorVerdict.STALE]:
        var fg := VerdictBanner.colour_for(st)
        var with_plate := VerdictBanner.contrast(fg, plated)
        check(with_plate >= 4.5, "the %s headline sits at %s:1 against the plate over the "
                % [st, String.num(with_plate, 2)]
                + "ramp's brightest stop, under the 4.5:1 a reader needs. The disclaimer "
                + "disappears into the picture it exists to disclaim.")
        # AND THE PLATE IS WHAT DOES IT. Without this the assert above would
        # pass on any dark-ish default and never notice the plate was gone.
        var bare := VerdictBanner.contrast(fg, worst)
        check(bare < 4.5, "the %s headline clears 4.5:1 against the bare ramp, so this test "
                % st + "no longer demonstrates that the plate is what makes it readable — "
                + "either the colour changed or the ramp did, and the pairing needs re-taking")

    # THE EXCLUSIONS ARE GROUPED BY REASON. Three fields excluded for one gauge
    # change printed the same forty words three times, filled a third of the
    # banner, and pushed the fifth named fail off the bottom of an 800 px
    # window. Grouping is not only shorter: a reader counting distinct reasons
    # is counting what actually happened to the proof.
    var gauge := ("the criterion-2 gauge moved from the legacy playa terminal to the "
            + "maximum-contributing-area outlet (Morelos)")
    var three := AncestorVerdict.read_from({"run": {
            "base_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
            "acceptance": {"scored_at_commit": "5317027", "passed": 7, "failed": 0,
                    "equivalence": {"to_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
                            "fields_compared": 18, "fields_matching": 18,
                            "fields_excluded": [
                                    {"field": "outlet_min_daily_q_m3_s", "why": gauge},
                                    {"field": "outlet_peak_q_m3_s", "why": gauge},
                                    {"field": "outlet_peak_doy", "why": gauge}]}}}})
    var grouped := three.excluded_fields()
    check(grouped.size() == 1, "three fields excluded for one reason produced %d line(s); "
            % grouped.size() + "fields sharing a reason are named together")
    if grouped.size() == 1:
        for f in ["outlet_min_daily_q_m3_s", "outlet_peak_q_m3_s", "outlet_peak_doy"]:
            check(str(grouped[0]).contains(f), "grouping dropped %s, so the caveat is now "
                    % f + "smaller than the thing it caveats")
        check(str(grouped[0]).count("criterion-2 gauge moved") == 1,
                "the shared reason is still printed more than once")
    # Two fields excluded for DIFFERENT reasons must stay two lines, or
    # grouping would be hiding a second cause behind the first.
    var two := AncestorVerdict.read_from({"run": {
            "base_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
            "acceptance": {"scored_at_commit": "5317027", "passed": 7, "failed": 0,
                    "equivalence": {"to_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
                            "fields_compared": 2, "fields_matching": 2,
                            "fields_excluded": [
                                    {"field": "a", "why": "one reason"},
                                    {"field": "b", "why": "a different reason"}]}}}})
    check(two.excluded_fields().size() == 2,
            "two fields excluded for two reasons collapsed into one line, which hides a cause")

    # The fixture this repo actually ships, so the state above is not
    # hypothetical and the day it changes, this line says so.
    var shipped := AncestorVerdict.read_from(
            FixtureLoader.load_from("res://assets/fixture/").manifest)
    # ON THE SHIPPED FIXTURE, because the grouping above is only worth having
    # if the artefact this repo actually carries is the shape it was written
    # for. Three excluded fields, one reason, one line.
    var ship_ex := shipped.excluded_fields()
    check(ship_ex.size() <= 1, "the shipped fixture's exclusions render as %d lines; each one "
            % ship_ex.size() + "is a paragraph in a 420 px column and the fifth named fail is "
            + "what falls off the bottom when they multiply")
    print("verdict: the shipped fixture reads %s -- %s" % [shipped.state, shipped.headline()])
    print("verdict: %d named fail(s), %d exclusion line(s) for %d excluded field(s)"
            % [shipped.named_fails().size(), ship_ex.size(),
                    (shipped.equivalence.get("fields_excluded", []) as Array).size()])


func test_the_scatter_cost_is_a_difference_and_says_when_it_is_not_one() -> void:
    """`measurements/scatter_cost.json` is the scatter's frame cost measured in
    the viewer that draws it. Its whole method is subtraction -- one timing of
    the viewer is the terrain, the flowlines, the contours, the overlay and the
    scatter added together, and no arithmetic recovers one term of that sum --
    so the arithmetic is what is checked here. The timing itself cannot be:
    headless draws nothing.
    """
    var busy := {"p50": 4.0, "p95": 4.4, "p99": 4.6}
    var quiet := {"p50": 1.0, "p95": 1.2, "p99": 1.3}
    var m := ScatterCost.marginal(busy, quiet)
    check(bool(m["ok"]) and absf(float(m["p50_ms"]) - 3.0) < 1e-9,
            "the marginal is not the difference of the two p50s")
    check(bool(m["resolved"]), "a 3 ms difference over a 0.4 ms spread read as unresolved")

    # A difference inside the scene's own frame-to-frame spread is not a small
    # cost. It is the absence of a measurement, and the two must not read alike.
    var noisy := {"p50": 1.1, "p95": 3.0, "p99": 3.4}
    var n := ScatterCost.marginal(noisy, quiet)
    check(not bool(n["resolved"]),
            "a 0.1 ms difference under a 1.9 ms spread was reported as a measurement")
    check(n.has("why_unresolved"), "an unresolved marginal did not say why")

    # One stalled frame in the quieter timing lifts its p99 above its own p95;
    # subtracting that yields a p99 "marginal" near zero, which reads as the
    # scatter being free at the tail.
    var stalled := {"p50": 1.0, "p95": 1.2, "p99": 3.4}
    var st := ScatterCost.marginal(busy, stalled)
    check(st.has("p99_note"), "a baseline p99 nearly triple its own p95 passed without a word, "
            + "so the p99 difference reads as the scatter's tail when it is one stalled frame")
    check(not ScatterCost.marginal(busy, {"p50": 1.0, "p95": 1.2, "p99": 1.3}).has("p99_note"),
            "a well-behaved tail was flagged as an outlier")

    # The model's side of the comparison. A family with no priced cost must
    # refuse rather than be counted at zero, which would make the prediction
    # look better the more of it was missing.
    var ns := {"shrub": 20.0, "succulent": 10.0}
    var p := ScatterCost.predicted_ms({"shrub": 1000, "succulent": 2000}, ns)
    check(bool(p["ok"]) and absf(float(p["ms"]) - 0.04) < 1e-9,
            "1,000 x 20 ns + 2,000 x 10 ns is 0.04 ms, not %f" % float(p.get("ms", NAN)))
    check(int(p["instances"]) == 3000, "the instance total did not survive")
    check(not bool(ScatterCost.predicted_ms({"tree": 5}, ns)["ok"]),
            "a family with no priced per-instance cost was silently counted as free")
    check(not bool(ScatterCost.predicted_ms({"shrub": 0}, ns)["ok"]),
            "an empty scatter was priced instead of refused")
    # A family placed zero times is not missing: it has no cost because it has
    # no instances, and refusing there would refuse every real scatter, since
    # `placed` always carries every family the wire names.
    check(bool(ScatterCost.predicted_ms({"shrub": 10, "grass": 0}, ns)["ok"]),
            "a family with no instances was treated as a family with no price")

    # THE INSTRUMENT'S OWN CEILING, which a spread of zero hides rather than
    # reports. `delta` here is paced: past about 2 ms frames land on rungs of a
    # ladder (1/720, 1/360, 1/330, 1/300, 1/270, 1/240, 1/220, 1/210, 1/200,
    # 1/180 s all observed), so a scene sitting inside one rung reports every
    # frame identically. That reads as a perfectly steady measurement and is
    # the absence of one. The 12x run did it: 80 busy frames all at 3.7037 ms,
    # spread 0.020, `resolved` true, and nothing saying the number was a rung.
    var railed := ScatterCost.marginal(
            {"min": 3.7037, "p50": 3.7037, "p95": 3.7037, "p99": 3.7037, "max": 3.7037, "n": 80},
            {"min": 0.099, "p50": 0.800, "p95": 0.820, "p99": 0.854, "max": 0.854, "n": 80})
    check(bool(railed.get("instrument_limited", false)),
            "a timing whose 80 frames were all the same number passed as a measurement of a "
            + "scene, when it is the paced-delta ladder reporting one rung")
    check(str(railed.get("instrument_note", "")).contains("one value"),
            "an instrument-limited marginal did not say what was wrong with it")
    # And the ordinary case must not be flagged, or the note means nothing.
    check(not bool(ScatterCost.marginal(
            {"min": 3.341, "p50": 3.491, "p95": 3.704, "p99": 3.704, "max": 3.704, "n": 80},
            {"min": 0.069, "p50": 0.566, "p95": 1.389, "p99": 1.389, "max": 1.389, "n": 80}
            ).get("instrument_limited", false)),
            "a timing that moved across rungs was called instrument-limited")

    var a := ScatterCost.agreement(2.0, 3.0)
    check(absf(float(a["ratio_observed_over_predicted"]) - 1.5) < 1e-9, "the ratio is wrong")
    check(not bool(a["within_tolerance"]), "1.5x read as agreement")
    check(bool(ScatterCost.agreement(2.0, 2.2)["within_tolerance"]), "1.1x read as disagreement")

    print("scatter cost: marginal %.2f ms resolved=%s, 1.5x agreement=%s"
            % [float(m["p50_ms"]), str(m["resolved"]), str(a["within_tolerance"])])


func test_the_benchmark_ladder_says_which_rungs_the_timer_could_not_separate() -> void:
    """DOES THE PACED TIMER CENSOR `render_cost.json` TOO? Asked of the corpus
    row that cites its coefficients, and answered here on the real ladders
    rather than on a synthetic one, because the artefact is not re-run: the
    determination is that the coefficients stand, and re-measuring them would
    move them by noise and force the citation to be re-taken for nothing.

    The benchmark already carried its own defence. `wall_clock_mean_ms` sits
    beside every rung with the note that "the per-frame delta quantises on this
    platform and a mean that disagrees with p50 is how that shows" — so the
    second, unpaced reading was recorded when this was built, and it is what
    settles the question. `scatter_cost.json` did not inherit that, which is
    why the rung finding surfaced there and not here.

    What the three ladders say:

      HIGH (2400 tri) — five of nine rungs report every frame at one value, so
        pacing is present. It does not matter: the rungs span 0.67 to 60.4 ms,
        each landing on a DIFFERENT rung of the ladder, and the unpaced fit
        gives 3.9963e-4 against the paced 3.9958e-4. Nothing moves.
      MID (288 tri) — genuinely censored. 64,000 and 128,000 instances both
        report exactly 7.1429 ms, so the artefact records a marginal of ZERO
        and used to read it as the fixed-cost floor. It is not: the unpaced
        reading separates them, 6.76 against 7.27 ms. The coefficient still
        moves by 0.1%.
      LOW (12 tri) — NOT censoring, which is the answer that was guessed wrong
        by both sessions. Neither rung either side of the negative marginal is
        pinned, and the negative survives on the unpaced instrument and gets
        worse. It is warm-up: the first two rungs measure dearer than the rung
        above them and `cpu_ms` FALLS across them, which is not work. Drop them
        and r² goes 0.884 to 0.998.
    """
    var f := FileAccess.open("res://measurements/render_cost.json", FileAccess.READ)
    check(f != null, "no measurements/render_cost.json")
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        check(false, "render_cost.json is not an object")
        return
    var by_key := {}
    for r in ((parsed as Dictionary).get("results", []) as Array):
        var d: Dictionary = r
        if not bool(d.get("measured", false)) or str(d.get("technique", "")) != "multimesh":
            continue
        var k := str(d["complexity"])
        if not by_key.has(k):
            by_key[k] = []
        (by_key[k] as Array).append(d)
    check(by_key.size() == 3, "expected three multimesh complexities in render_cost.json, "
            + "found %d — the ladder this reasons about is not the one on disk" % by_key.size())

    var verdicts := {}
    for k in by_key:
        var rows: Array = by_key[k]
        rows.sort_custom(func(a, b): return int(a["instances"]) < int(b["instances"]))
        var xs := PackedFloat64Array()
        var ys := PackedFloat64Array()
        var un := PackedFloat64Array()
        for d in rows:
            xs.append(float(d["instances"]))
            ys.append(float(d["frame_ms"]["p50"]))
            un.append(float(d.get("wall_clock_mean_ms", d["frame_ms"]["p50"])))
        check(un.size() == ys.size(), "multimesh|%s has no unpaced reading beside every rung, "
                % k + "so nothing here can tell a censored marginal from a real one")
        verdicts[k] = FrameStats.marginals(xs, ys, un)

    # HIGH: every marginal positive, so a spread is defined and the ladder is
    # crossed at every step. This is the coefficient the corpus leans on hardest.
    var high: Dictionary = verdicts.get("high", {})
    check(high.has("spread"), "multimesh|high no longer has a defined spread, so its rungs "
            + "stopped being separable and the 2400-triangle coefficient is now quoting the "
            + "instrument: %s" % str(high.get("spread_undefined_because", "")))

    # MID: censored, and the artefact must now say so rather than calling it a floor.
    var mid: Dictionary = verdicts.get("mid", {})
    if not mid.has("spread"):
        check(str(mid.get("spread_undefined_because", "")).contains("CENSORED"),
                "multimesh|mid's zero marginal is not being reported as censored by the "
                + "timer, though the unpaced reading separates the two rungs: %s"
                % str(mid.get("spread_undefined_because", "")))
        check(float(mid.get("unpaced_ms_per_instance_there", -1.0)) > 0.0,
                "the unpaced reading of mid's flat pair is not positive, which would mean "
                + "the zero is real and 128,000 instances cost the same as 64,000")

    # LOW: not the timer, and the warm-up signature is what it actually is.
    var low: Dictionary = verdicts.get("low", {})
    if not low.has("spread"):
        check(str(low.get("spread_undefined_because", "")).contains("NOT THE TIMER"),
                "multimesh|low's negative marginal is being blamed on the paced timer; the "
                + "unpaced reading is negative there too: %s"
                % str(low.get("spread_undefined_because", "")))
    check(low.has("head_warm_up"), "multimesh|low's first rungs no longer measure dearer than "
            + "the rungs above them. That is the warm-up this reasoning rests on, so either "
            + "the sweep was re-run and the finding is stale, or the detector broke.")
    check(not high.has("head_warm_up"),
            "multimesh|high is now flagged as warming up, which would mean the detector fires "
            + "on a clean ladder and says nothing about the dirty one")

    print("ladder: high spread %s | mid %s | low %s%s"
            % [String.num(float(high.get("spread", NAN)), 2),
                    "censored" if not mid.has("spread") else "clean",
                    "not-the-timer" if not low.has("spread") else "clean",
                    ", warm-up at the head" if low.has("head_warm_up") else ""])


func test_the_empty_stage_coefficient_is_a_floor_and_the_scene_sits_above_it() -> void:
    """THE RULING ON `render_cost.json`'s COEFFICIENT, PINNED SO IT CAN FAIL.

    `render_cost.json` prices instancing on an empty stage — no terrain, no
    culling, no LOD — and the corpus cites it. Both of the last two conditions
    have since changed in the viewer: the scatter thins with distance and the
    far field is drawn. The question raised was whether to re-measure the
    coefficient in the scene that now exists.

    THE ANSWER IS NO, AND THIS IS THE CLAIM THAT ANSWER RESTS ON: the empty
    stage is a FLOOR. A coefficient re-measured with a basin under it stops
    being a coefficient and becomes a joint measurement of instancing and one
    scene, which is what `scatter_cost.json` already is — two artefacts of the
    same thing under different names, and neither recoverable from the other.
    So the floor stays, and the scene's distance above it is the figure that
    gets re-measured, because that is the one that moves.

    A floor that is sometimes come in under is not a floor. Ten runs — five at
    12× and five at 1:1, across a 5.6× change in the pixels the scatter draws —
    never went below the prediction, and this fails if one ever does, at which
    point the word "floor" is what has to change and not the artefact.
    """
    var f := FileAccess.open("res://measurements/scatter_cost.json", FileAccess.READ)
    check(f != null, "no measurements/scatter_cost.json")
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    check(typeof(parsed) == TYPE_DICTIONARY, "scatter_cost.json is not an object")
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var doc: Dictionary = parsed
    var predicted: Dictionary = doc.get("predicted_by_render_cost", {})
    var marginal: Dictionary = doc.get("marginal", {})
    check(bool(predicted.get("ok", false)), "the artefact carries no empty-stage prediction")
    check(bool(marginal.get("ok", false)) and bool(marginal.get("resolved", false)),
            "the artefact carries no resolved marginal, so it says nothing about the floor")
    if not (bool(predicted.get("ok", false)) and bool(marginal.get("ok", false))):
        return

    var pred := float(predicted["ms"])
    var obs := float(marginal["p50_ms"])
    check(obs >= pred, "the scene cost %s ms and the empty-stage coefficient predicted %s ms. "
            % [String.num(obs, 3), String.num(pred, 3)]
            + "The empty stage is supposed to be a FLOOR — instancing with nothing drawn over "
            + "it — and a real scene coming in UNDER it means either the floor is not one or "
            + "this scene is drawing less than it claims. The corpus row cites that coefficient "
            + "as a floor; if this is real, the row is wrong and not the artefact.")

    # The other half of the ruling: the floor is only useful if the scene's
    # distance above it is recorded beside it. A ratio the artefact does not
    # carry is a ratio nobody can quote.
    var agree: Dictionary = doc.get("agreement", {})
    check(bool(agree.get("ok", false)) and agree.has("ratio_observed_over_predicted"),
            "the artefact prices the scene and does not record its ratio to the floor, which "
            + "is the whole figure the corpus row needs beside the coefficient")

    # And the floor must be a floor of the same scene: a prediction made for a
    # different instance count than was drawn compares two populations.
    var placed := 0
    for k in (doc.get("placed", {}) as Dictionary):
        placed += int((doc["placed"] as Dictionary)[k])
    check(int(predicted.get("instances", -1)) == placed,
            "the prediction is for %d instances and %d were placed, so the ratio compares two "
            % [int(predicted.get("instances", -1)), placed]
            + "different populations")

    print("floor: scene %s ms over an empty-stage %s ms, ratio %sx"
            % [String.num(obs, 2), String.num(pred, 2),
                    String.num(float(agree.get("ratio_observed_over_predicted", NAN)), 2)])


func test_the_scatter_measurement_verifies_in_pixels_not_primitives() -> void:
    """A CORRECTION TO THE BENCHMARK'S CHECK, and the reason it is worth a test.

    `InstanceBench` verifies a configuration by comparing the primitive counter
    against instances x triangles, and there that check is sound. It is not
    sound over M5's families: measured on the running viewer, the counter
    reported 5,216,256 primitives for a 108,672-instance MultiMesh -- exactly
    108,672 x 48 -- and a constant 20 for a 10,947-instance one beside it. The
    20 did not move when `visible_instance_count` was set to 100 and then to 1,
    so it was not counting instances at all; and all three families were
    drawing, because the pixels they put on screen scaled with instance count
    while the counter did not.

    So the check that survives is the weaker one: showing the scatter has to
    change the frame. It cannot say how many instances arrived, and it does not
    pass a frame the scatter is missing from, which is the property that
    matters.
    """
    check(ScatterCost.drew_the_scatter(4411, 80, 80) == "",
            "a frame that changed 4,411 pixels over 80 drawn frames was called suspect")
    check(ScatterCost.drew_the_scatter(0, 80, 80) != "",
            "showing the scatter changed nothing and the run was accepted, so the two "
            + "timings are of one scene and their difference is the cost of nothing")
    var short := ScatterCost.drew_the_scatter(4411, 12, 80)
    check(short != "", "80 frames were timed while 12 were drawn and the run was accepted")
    check(short.contains("cadence"),
            "the refusal does not name what it is refusing: %s" % short)


func test_the_individuation_horizon_is_one_constant_bounded_by_the_camera() -> void:
    """THE HORIZON RULE: `d_f = k x height_f`, one shared k for every family,
    so a per-family distance is derived rather than tuned. Four tuned numbers
    can drift apart; one constant cannot, and there is one knob to sweep
    instead of a product of four.

    THE PREMISE IS EXACTLY TRUE AND IS A PINHOLE IDENTITY. Individuation range
    is proportional to apparent size, so the range at which an object falls
    below one pixel is `k_res x height` with `k_res = H / (2 tan(fov/2))` --
    a property of the CAMERA, identical for every family. Checked here against
    `scatter_bands.json`'s own pixel table rather than asserted: shrub,
    succulent and tree all give 521 at 1280x800 and 75 degrees, and so does
    the formula. That is worth knowing before sweeping k, because it means k
    is not free -- individuation stops at or before resolution, and the sweep
    is looking for how far before.
    """
    # The camera constant, from the formula and from the measured ranges.
    var k_res := VegetationScatter.resolution_k(800.0, 75.0)
    check(absf(k_res - 521.3) < 0.5, "k_res at 1280x800 / 75 degrees is %s, not ~521.3"
            % String.num(k_res, 2))
    check(VegetationScatter.resolution_k(0.0, 75.0) == 0.0
                    and VegetationScatter.resolution_k(800.0, 0.0) == 0.0,
            "a degenerate camera returned a horizon constant instead of zero")

    var f := FileAccess.open("res://measurements/scatter_bands.json", FileAccess.READ)
    if f != null:
        var parsed = JSON.parse_string(f.get_as_text())
        if typeof(parsed) == TYPE_DICTIONARY:
            var rows := _rows_with(parsed, "pixels_at")
            check(rows.size() > 0, "scatter_bands.json carries no screen-size table, so the "
                    + "premise this rule rests on cannot be checked against a measurement")
            for r in rows:
                var row: Dictionary = r
                var h := float(row["height_m"])
                var px: Dictionary = row["pixels_at"]
                # px * d is constant for a pinhole, so any row gives the
                # one-pixel range. Take them all and require they agree.
                for d_str in px:
                    var one_px_range := float(d_str) * float(px[d_str])
                    var k_here := one_px_range / h
                    check(absf(k_here - k_res) / k_res < 0.02,
                            "%s at %s m gives k = %s, against the camera's %s. Individuation "
                                    % [str(row["life_form"]), str(d_str),
                                            String.num(k_here, 0), String.num(k_res, 0)]
                            + "range is supposed to be proportional to size with ONE constant; "
                            + "if the families disagree, the horizon rule needs a per-family "
                            + "term and is no longer one knob.")

    # The rule itself: linear in both, and degenerate inputs give no horizon
    # rather than a nonsense one.
    check(absf(VegetationScatter.individuation_horizon_m(4.0, 500.0) - 2000.0) < 1e-9,
            "a 4 m object at k = 500 should individuate to 2,000 m")
    check(absf(VegetationScatter.individuation_horizon_m(0.5, 500.0) - 250.0) < 1e-9,
            "the horizon is not linear in height")
    check(VegetationScatter.individuation_horizon_m(4.0, 0.0) == 0.0,
            "k = 0 is the rule being off and must not produce a horizon")
    check(VegetationScatter.individuation_horizon_m(-1.0, 500.0) == 0.0,
            "a negative height produced a horizon")

    # THE BRIEF'S ARITHMETIC, CHECKED AGAINST THIS REPO'S FAMILIES -- and it
    # does not come out. Count inside a family's own horizon is
    # `cover x pi k^2 x height^2 / crown_area`, so "size cancels and the budget
    # is one scalar" needs `height^2 / crown_area` to be the same for every
    # family. It is not: the brief's own caveat says height sets the horizon
    # while crown sets the cover, and that is exactly where it comes apart.
    var fam := FileAccess.open("res://assets/families/families.json", FileAccess.READ)
    check(fam != null, "no families.json")
    if fam == null:
        return
    var doc = JSON.parse_string(fam.get_as_text())
    if typeof(doc) != TYPE_DICTIONARY:
        return
    var families: Dictionary = (doc as Dictionary).get("families", {})
    var factor := {}
    for name in families:
        var pars: Dictionary = (families[name] as Dictionary).get("parameters", {})
        if not (pars.has("height_m") and pars.has("crown_m")):
            check(false, "%s declares no height or crown range, so it supplies one number to "
                    % name + "two formulas and the horizon rule cannot be applied to it")
            continue
        var h_max := float((pars["height_m"] as Dictionary)["max"])
        var c_max := float((pars["crown_m"] as Dictionary)["max"])
        var crown_area: float = PI * (0.5 * c_max) * (0.5 * c_max)
        factor[name] = (h_max * h_max) / crown_area if crown_area > 0.0 else INF
    var lo := INF
    var hi := 0.0
    for name in factor:
        lo = minf(lo, float(factor[name]))
        hi = maxf(hi, float(factor[name]))
    var said := PackedStringArray()
    for name in factor:
        said.append("%s %s" % [name, String.num(float(factor[name]), 1)])
    # A SELF-RETIRING ASSERT. It fails if the families ever become uniform
    # enough that the cancellation really does hold -- at which point the
    # budget CAN be one scalar and this note is what is stale, not the brief.
    check(hi / lo > 2.0, "height^2/crown_area now spans only %sx across the families (%s), so "
            % [String.num(hi / lo, 1), ", ".join(said)]
            + "size really does cancel and the per-family instance budget really is one "
            + "scalar. That is the brief's claim and it did not hold when this was written "
            + "(64x); if it holds now, drop this check and the note beside it.")
    print("horizon: k_res %s at 1280x800/75deg; height^2/crown_area spans %sx (%s)"
            % [String.num(k_res, 0), String.num(hi / lo, 1), ", ".join(said)])


## Every dictionary anywhere in `node` that carries `key`.
static func _rows_with(node: Variant, key: String) -> Array:
    var out: Array = []
    if typeof(node) == TYPE_DICTIONARY:
        var d: Dictionary = node
        if d.has(key) and d.has("life_form") and d.has("height_m"):
            out.append(d)
        for k in d:
            out.append_array(_rows_with(d[k], key))
    elif typeof(node) == TYPE_ARRAY:
        for v in (node as Array):
            out.append_array(_rows_with(v, key))
    return out


func test_a_density_schedule_is_finer_than_the_texel_it_thins() -> void:
    """A REGRESSION FOR A BUG THAT LOOKED LIKE A WORKING MEASUREMENT.

    The residence and height rasters are the 1,000 m overview -- the export
    declares a tile pyramid and does not emit it -- so a 1,500 m horizon is
    nine texels. Applied per texel, schedules cutting at 100 m, 200 m and 300 m
    all keep exactly the centre texel and nothing else, and the first run of
    `tools/measure_bands.sh` duly reported three byte-identical instance counts
    under three different names. Nothing errored; the artefact was simply an
    answer to a question nobody asked.

    So a schedule subdivides the texel it is thinning, and what is checked here
    is that three different radii produce three different scatters.
    """
    check(absf(VegetationScatter.keep_at(9999.0, []) - 1.0) < 1e-9,
            "an empty schedule thinned something")
    var sched: Array = [{"to_m": 100.0, "keep": 1.0}, {"to_m": 300.0, "keep": 0.25}]
    check(absf(VegetationScatter.keep_at(50.0, sched) - 1.0) < 1e-9, "inside the first band")
    check(absf(VegetationScatter.keep_at(100.0, sched) - 1.0) < 1e-9, "on the first boundary")
    check(absf(VegetationScatter.keep_at(200.0, sched) - 0.25) < 1e-9, "inside the second band")
    check(absf(VegetationScatter.keep_at(301.0, sched)) < 1e-9,
            "past the last band, which keeps nothing")

    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    if not bool(v.bind_families().get("ok", false)):
        v.queue_free()
        return
    v.show_field("deepest_winter", "band.pft_fractions", 45)
    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    # A tiny ceiling: what is compared is `implied_after_bands`, which the
    # schedule decides and the ceiling never touches, so there is no reason to
    # spend seconds filling MultiMeshes to find it out.
    var seen: Array = []
    var implications: Array = []
    for radius in [100.0, 200.0, 300.0]:
        var r := v.scatter_at(centre, TerrainView.SCATTER_HORIZON_M,
                [{"to_m": radius, "keep": 1.0}], 2000)
        check(bool(r.get("ok", false)), "the scatter refused a schedule: %s"
                % str(r.get("why", "")))
        seen.append(float(r.get("implied_after_bands", 0.0)))
        implications.append(float(r.get("implied_total", 0.0)))
    check(seen[0] < seen[1] and seen[1] < seen[2],
            "cutting at 100, 200 and 300 m implied %s instances -- a schedule finer than the "
            % str(seen) + "1,000 m texel it thins is being applied at the texel's resolution, "
            + "so every radius under a kilometre is the same radius")
    # Roughly as the area grows, which is what says the subdivision is radial
    # and not merely different. Loose, because the density is per cell and the
    # disc crosses more than one.
    var ratio: float = seen[2] / maxf(seen[0], 1.0)
    check(ratio > 3.0 and ratio < 30.0,
            "300 m implies %.1fx what 100 m does; the areas differ by 9x" % ratio)

    var full := v.scatter_at(centre, TerrainView.SCATTER_HORIZON_M, [], 2000)
    check(float(full["implied_after_bands"]) > seen[2],
            "the unbanded scatter implied no more than a 300 m cut of it")
    # THE SCHEDULE MUST NOT TOUCH THE IMPLICATION. `implied` is what the wire
    # says is on the ground and `implied_after_bands` is what this frame chose
    # to draw; a schedule that moved the first would turn a drawing decision
    # into data, which is the failure this whole layer is arranged against.
    implications.append(float(full["implied_total"]))
    for i in implications.size():
        check(absf(float(implications[i]) - float(implications[0])) < 1.0,
                "schedule %d reports %.0f implied where the first reports %.0f: a drawing "
                % [i, float(implications[i]), float(implications[0])]
                + "decision is changing what the wire is said to imply")
    print("bands: 100 m implies %.0f, 200 m %.0f, 300 m %.0f, no schedule %.0f"
            % [seen[0], seen[1], seen[2], float(full["implied_total"])])
    v.queue_free()


func test_pft_fractions_are_a_composition_of_the_cover() -> void:
    """THE PROPERTY THAT LICENSES HOW THIS CLIENT READS TWO ROWS.

    `band.pft_fractions` and `band.bare_fraction` are both declared `fraction`
    in [0, 1] and the contract says what neither is a fraction OF. The data
    settles it: the four groups sum to 1.0000 in every cell, while bare runs
    0.05 to 0.95 and averages 0.475. Both cannot be absolute -- a cell cannot be
    95% bare and 100% covered -- so the one that always sums to one is the
    composition, and a life form's ground cover is its share scaled by
    `1 - bare_fraction`.

    This client read the share as a cover from M5 until the far-field tint made
    it visible by rendering every cell at full canopy. So the reading rests on a
    property rather than on a declaration, and the property is asserted here:
    if a later fixture stops summing to one, this fails and
    `VegetationScatter.ground_cover` is what has to be revisited.
    """
    var fl := FixtureLoader.load_from("res://assets/fixture/")
    if not fl.is_loaded():
        return
    for w in fl.windows:
        var window := str(w)
        var groups := fl.taxon_groups(window, "band.pft_fractions")
        check(groups.size() > 0, "%s names no taxon groups" % window)
        var bare := fl.day_values(window, "band.bare_fraction", 0)
        check(not bare.is_empty(), "%s carries no band.bare_fraction" % window)
        var per_group: Array = []
        for gi in groups.size():
            per_group.append(fl.day_values(window, "band.pft_fractions", 0, gi))
        var cells := 0
        var empty := 0
        var sums_to_one := 0
        var tracks_cover := 0
        var err_one := 0.0
        var err_cover := 0.0
        var bare_lo := INF
        var bare_hi := -INF
        for cell in fl.n_cells:
            var s := 0.0
            var any := false
            for gi in groups.size():
                var v: PackedFloat64Array = per_group[gi]
                if cell < v.size() and not is_nan(v[cell]):
                    s += v[cell]
                    any = true
            if not any:
                continue
            cells += 1
            var b: float = bare[cell] if cell < bare.size() else NAN
            if not is_nan(b):
                bare_lo = minf(bare_lo, b)
                bare_hi = maxf(bare_hi, b)
            # A cell with no vegetation at all sums to ZERO, not to one. A
            # composition is a composition of something.
            if s < 1e-3:
                empty += 1
                continue
            err_one += absf(s - 1.0)
            if absf(s - 1.0) < 1e-3:
                sums_to_one += 1
            if not is_nan(b):
                err_cover += absf(s - (1.0 - b))
                if absf(s - (1.0 - b)) < 1e-3:
                    tracks_cover += 1
        var covered := cells - empty
        check(covered > 1000, "%s: only %d cells carry any cover at all" % [window, covered])
        # THE DISCRIMINATOR IS THE SECOND CHECK, not the first. "Sums to one"
        # could be a coincidence of a basin that happens to be fully vegetated;
        # "does not track 1 - bare anywhere, over a basin where bare spans
        # 0.04 to 1.00" cannot be. Both are asserted, and the second is the one
        # that would catch the rows swapping meaning.
        check(float(sums_to_one) / float(covered) > 0.99,
                "%s: only %d of %d covered cells have their four pft fractions summing to 1 "
                % [window, sums_to_one, covered] + "(mean error %s). They are read as a "
                % String.num(err_one / float(covered), 6) + "COMPOSITION scaled by "
                + "1 - bare_fraction; if that is no longer what they are, "
                + "VegetationScatter.ground_cover is wrong and every implied-instance figure "
                + "in measurements/ with it.")
        check(float(tracks_cover) / float(covered) < 0.01,
                "%s: %d of %d covered cells have pft fractions summing to 1 - bare_fraction, "
                % [window, tracks_cover, covered] + "which is what ABSOLUTE cover would look "
                + "like. The two readings differ by 1/(1 - bare) -- 1.9x on this basin's mean "
                + "-- and this client had the wrong one from M5 until the far-field tint "
                + "rendered every cell at full canopy.")
        check(bare_hi - bare_lo > 0.5,
                "%s: bare_fraction spans only %.3f..%.3f. The spread is what makes the two "
                % [window, bare_lo, bare_hi] + "readings distinguishable at all.")
        print("cover: %s %d/%d covered cells sum to 1 (mean err %s), %d track 1-bare "
                % [window, sums_to_one, covered, String.num(err_one / float(covered), 6),
                   tracks_cover]
                + "(mean err %s); %d cells carry none, bare spans %.3f..%.3f"
                % [String.num(err_cover / float(covered), 4), empty, bare_lo, bare_hi])


func test_a_recorded_distance_names_what_it_is_conditional_on() -> void:
    """TRAP 3 AS A GUARD RATHER THAN AS A DISCIPLINE.

    The scale is 1:1 now, so no distance here is conditional on a factor — and
    the rule outlived the factor, which is the point of it. When relief and
    plant height were multiplied by twelve and horizontal distance was not, a
    plant subtended about twelve times the angle it would in the field, and
    "record any tuned distance as conditional on the factor" was the right rule
    and exactly the kind that goes stale: a transcribed caveat outlives the
    number it qualifies. This docstring was itself that caveat for one commit.

    So the factor goes in the artefact and this asserts that it is there: a
    measurement carrying metres must carry the exaggeration those metres were
    taken at.

    AND THAT THEY ALL AGREE, which is the half that has teeth. Asserting each
    artefact names *a* factor caught nothing when the scale actually changed:
    the artefacts that were re-taken went to 1.0 one at a time, and
    `scatter_cost.json` — which was not re-taken — kept naming 12.0 and pricing
    a scene nobody drew any more, while this test passed on it and on the files
    that disagreed with it. A directory at two scales is not a set of
    measurements; it is one set and one relic, and no file in it says which it
    is. Only the comparison between them can.
    """
    var dir := DirAccess.open("res://measurements/")
    check(dir != null, "no measurements/ directory")
    if dir == null:
        return
    var checked := 0
    ## factor -> the artefacts taken at it, so a mixed directory names both sides.
    var factors := {}
    for name in dir.get_files():
        if not name.ends_with(".json"):
            continue
        var f := FileAccess.open("res://measurements/" + name, FileAccess.READ)
        var parsed = JSON.parse_string(f.get_as_text())
        if typeof(parsed) != TYPE_DICTIONARY:
            continue
        var doc: Dictionary = parsed
        var metres := _distance_keys(doc, "")
        if metres.is_empty():
            continue
        checked += 1
        check(doc.has("vertical_exaggeration"),
                "measurements/%s records distances in metres (%s) and does not record the "
                % [name, ", ".join(metres.slice(0, 4))]
                + "vertical exaggeration they were taken at. Plant height and relief carry the "
                + "factor and horizontal distance does not, so a range here is not a range in "
                + "the field, and a reader has no way to know by how much.")
        if doc.has("vertical_exaggeration"):
            check(float(doc["vertical_exaggeration"]) > 0.0,
                    "measurements/%s records an exaggeration of %s" % [name,
                            str(doc["vertical_exaggeration"])])
            var f_ := float(doc["vertical_exaggeration"])
            # Array, not PackedStringArray: the packed arrays are value types, so
            # appending through a dictionary lookup appends to a copy and the
            # message comes out naming no files at all -- which is how this was
            # first written and what blinding it showed.
            if not factors.has(f_):
                factors[f_] = []
            (factors[f_] as Array).append(name)
    check(checked > 0, "no measurement artefact carries a distance, which is unlikely enough "
            + "to be a bug in this test rather than a property of the repo")
    var seen := factors.keys()
    seen.sort()
    var by_factor := PackedStringArray()
    for f_ in seen:
        by_factor.append("x%s: %s" % [String.num(f_, 2),
                ", ".join(PackedStringArray(factors[f_] as Array))])
    check(seen.size() <= 1, "measurements/ holds distances taken at %d different vertical "
            % seen.size()
            + "exaggerations — %s. " % " | ".join(by_factor)
            + "Every metre in the minority group describes a render nobody draws any more. "
            + "Re-take those artefacts, or mark them superseded and move them out of this "
            + "directory; do not hand-edit the factor, which would leave the distances wrong "
            + "and the label right.")
    print("distances: %d measurement artefact(s) carry metres, all at %s"
            % [checked, "x" + String.num(float(seen[0]), 2) if seen.size() == 1 else "MIXED"])


## Keys anywhere in a document whose name says they hold metres.
static func _distance_keys(node: Variant, prefix: String) -> PackedStringArray:
    var out := PackedStringArray()
    if typeof(node) == TYPE_DICTIONARY:
        for k in (node as Dictionary):
            var name := str(k)
            var path := name if prefix.is_empty() else prefix + "." + name
            if name.ends_with("_m") or name.ends_with("_metres") or name.contains("_m_"):
                out.append(path)
            out.append_array(_distance_keys((node as Dictionary)[k], path))
    elif typeof(node) == TYPE_ARRAY:
        for i in (node as Array).size():
            out.append_array(_distance_keys((node as Array)[i], "%s[%d]" % [prefix, i]))
    return out


func test_the_tint_takes_wire_shares_unfloored_and_the_drawn_unit_can_change() -> void:
    """TWO REQUIREMENTS THAT PULL AGAINST EACH OTHER, and both are the seam's.

    ONE. Trace shares are grass's main mode of existence -- median share 0.88%
    across the reference basin, half of it under 1% -- and they correctly draw
    NO INDIVIDUALS, because a hundredth of a texel's ground does not resolve
    into a plant anyone sees. They must still TINT. A presence floor anywhere
    in the tint's composition input would delete grass from half the basin by
    construction, and it would look like a basin without much grass rather than
    like a floor.

    TWO. The drawn unit is a per-family choice -- a patch of sward, not one
    tussock -- and changing it must not change the ground covered. Count is
    `cover x texel_area / crown_area`, so cover falls out of the product
    exactly; that is what makes the unit free to change and is the whole reason
    the grass unit could be widened to fix the population imbalance the horizon
    rule exposed.
    """
    # TWO first, because it is arithmetic and needs no fixture.
    var texel_area := 1_000_000.0
    var cover := 0.0655
    var covered := PackedFloat64Array()
    for crown in [0.086, 0.313, 0.5, 4.0]:
        var crown_area: float = PI * (0.5 * crown) * (0.5 * crown)
        var count := cover * texel_area / crown_area
        covered.append(count * crown_area)
    for i in covered.size():
        check(absf(covered[i] - cover * texel_area) < 1e-6,
                "a %s m drawn unit covers %s m2 of a %s m2 texel, not the %s the wire says. "
                        % [str(i), String.num(covered[i], 1), String.num(texel_area, 0),
                                String.num(cover * texel_area, 1)]
                + "Cover conservation is what makes the proxy unit free to choose; without it, "
                + "widening the unit is a change to the data and not to the drawing.")

    # And the unit that was actually chosen: grass's crown floor has to keep
    # `height^2 / crown_area` at order 1-5, which is the number that decides
    # whether one family swamps the frame under the horizon rule.
    var fam := FileAccess.open("res://assets/families/families.json", FileAccess.READ)
    if fam != null:
        var doc = JSON.parse_string(fam.get_as_text())
        if typeof(doc) == TYPE_DICTIONARY:
            var g: Dictionary = ((doc as Dictionary).get("families", {}) as Dictionary).get(
                    "grass", {})
            var pars: Dictionary = g.get("parameters", {})
            if pars.has("crown_m"):
                # Trace-cover cells get the RANGE MINIMUM, so the floor is the
                # value that matters: `t_crown` is the cover fraction itself.
                var c_min := float((pars["crown_m"] as Dictionary)["min"])
                var h := 0.631      # measured realised height at the place that carries grass
                var factor: float = (h * h) / (PI * (0.5 * c_min) * (0.5 * c_min))
                check(factor <= 8.0, "grass's crown floor of %s m puts height^2/crown_area at "
                        % String.num(c_min, 3)
                        + "%s for a %s m plant. It was 68.5 at an 0.086 m tussock and grass took "
                                % [String.num(factor, 1), String.num(h, 2)]
                        + "77-87% of every drawn population; the drawn unit was widened to a "
                        + "patch to bring it to order 1-5. Narrowing it again brings that back.")

    # ONE needs the shipped fixture, because a trace share is a property of the
    # data and a synthetic one would only test the arithmetic again.
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    if not bool(v.bind_families().get("ok", false)):
        v.queue_free()
        return
    var window := "deepest_winter"
    var day := 22
    var colours := v.tint.cell_colours(window, day)
    if not bool(v.tint.report.get("ok", false)):
        v.queue_free()
        return
    var groups := v.fixture.taxon_groups(window, "band.pft_fractions")
    var bare := v.fixture.day_values(window, "band.bare_fraction", day)
    var trace := 0
    var trace_tinted := 0
    var smallest := INF
    for gi in groups.size():
        var fr := v.fixture.day_values(window, "band.pft_fractions", day, gi)
        for cell in fr.size():
            var cov := VegetationScatter.ground_cover(fr[cell],
                    NAN if cell >= bare.size() else bare[cell])
            if is_nan(cov) or cov <= 0.0 or cov >= 0.01:
                continue
            trace += 1
            smallest = minf(smallest, cov)
            if cell < colours.size() and colours[cell].a > 0.0:
                trace_tinted += 1
    check(trace > 0, "no cell in the shipped fixture carries a trace share under 1%, so this "
            + "test proves nothing about floors. Either the fixture changed or the reading did.")
    check(trace_tinted == trace, "%d of %d trace-share cell-groups reach the tint. The rest are "
            % [trace_tinted, trace]
            + "being floored away, and a floor here deletes grass from most of the basin -- "
            + "which renders as a basin with little grass in it rather than as a bug.")
    print("tint: %d trace cell-groups under 1%% cover, smallest %s, all tinted"
            % [trace, String.num(smallest, 9)])
    v.queue_free()


func test_the_tint_holds_the_quantity_a_seam_has_to_conserve() -> void:
    """COVERAGE AND MEAN COLOUR PER UNIT GROUND AREA, per family, as functions
    of range. That is the invariant any future crossfade has to hold, and until
    now it lived only in a brief — load-bearing prose in a file nothing checks,
    which is the failure mode this project keeps re-finding.

    Two of the three are pinned here, because they are properties of the tint
    and not of a render: coverage must be exactly the ground the wire says is
    vegetated, and mean colour must be the families' colours weighted by the
    ground each covers. The third, the range dependence, is a property of a
    frame and belongs to the seam harness.
    """
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    if not bool(v.bind_families().get("ok", false)):
        v.queue_free()
        return
    var window := "deepest_winter"
    var day := 22
    var colours := v.tint.cell_colours(window, day)
    var r: Dictionary = v.tint.report
    check(bool(r.get("ok", false)), "the tint did not build: %s" % str(r.get("why", "")))
    if not bool(r.get("ok", false)):
        v.queue_free()
        return
    check(colours.size() == v.fixture.n_cells, "the tint coloured %d of %d cells"
            % [colours.size(), v.fixture.n_cells])

    # COVERAGE IS 1 - bare_fraction, exactly, because the composition sums to
    # one. If this ever drifts, the tint is covering ground the instances do
    # not and the seam is a density step by construction.
    var bare := v.fixture.day_values(window, "band.bare_fraction", day)
    var worst := 0.0
    var compared := 0
    var mean_cover := 0.0
    for cell in colours.size():
        if cell >= bare.size() or is_nan(bare[cell]):
            continue
        var want: float = clampf(1.0 - bare[cell], 0.0, 1.0)
        # Only where the composition is present; a fully bare cell names a mix
        # and covers nothing, and both sides agree on zero there.
        if want <= 0.0:
            check(colours[cell].a <= 1.0 / 255.0,
                    "cell %d is fully bare and the tint covers %.3f of it"
                    % [cell, colours[cell].a])
            continue
        if colours[cell].a <= 0.0:
            continue
        compared += 1
        mean_cover += colours[cell].a
        worst = maxf(worst, absf(colours[cell].a - want))
    check(compared > 1000, "only %d cells could be compared" % compared)
    check(worst < 5e-3, "the tint's coverage departs from 1 - bare_fraction by %s at worst"
            % String.num(worst, 5))
    # And it is not near one, which is what the bug looked like.
    var mean := mean_cover / float(maxi(compared, 1))
    check(mean < 0.9, "the tint covers %s of the mean cell. Full canopy everywhere is what "
            % String.num(mean, 4) + "reading the composition as a cover looked like.")

    # MEAN COLOUR IS THE PALETTE'S, not something else: every cell's colour has
    # to be a mix of the three constants both ends of the seam share.
    var off := 0
    for cell in colours.size():
        if colours[cell].a <= 0.0:
            continue
        var c := colours[cell]
        if c.r < 0.0 or c.r > 1.0 or c.g < 0.0 or c.g > 1.0 or c.b < 0.0 or c.b > 1.0:
            off += 1
    check(off == 0, "%d cells carry a colour outside [0,1]" % off)
    check(r["foliage_fraction"].size() > 0,
            "the tint does not report the authored mask it mixed with, so the one number the "
            + "far field shares with the instance shader is not in the record")
    print("tint: coverage matches 1-bare within %s over %d cells, mean cover %s, foliage %s"
            % [String.num(worst, 5), compared, String.num(mean, 3),
               str(r["foliage_fraction"])])
    v.queue_free()


func test_the_seam_metric_fails_the_bad_frame() -> void:
    """The scoring half of the seam harness. Its arithmetic can be checked
    blind; what it scores cannot, because a candidate is a render.

    THE DISCIPLINE IS `ramp_agreement`'s. A metric is only worth pointing at a
    subtle candidate if it visibly fails an unsubtle one, so the harness always
    grades a deliberately-wrong baseline alongside and `rank` reports the margin
    rather than only the winner. A margin near zero is the finding.
    """
    # Bands are a curve around a seam, and the scoring annulus is a slice of it
    # that excludes the near field -- where a whole-frame metric would be mostly
    # ground within a hundred metres and would rank a candidate on the half of
    # the picture the seam is not in.
    var bands := SeamScore.bands(200.0)
    check(bands.size() == SeamScore.CURVE_MULTIPLES.size() - 1,
            "%d bands from %d multiples" % [bands.size(), SeamScore.CURVE_MULTIPLES.size()])
    check(float(bands[0]["lo_m"]) < float(bands[0]["hi_m"]), "a band runs backwards")
    var score := SeamScore.scoring_band(200.0)
    check(float(score["lo_m"]) == 140.0 and float(score["hi_m"]) == 300.0,
            "the scoring annulus is %s, not 0.7-1.5x the seam" % str(score))

    # A mask and a frame, hand-made so the answer is known: the left half is in
    # the band, and half of THAT is lit.
    var mask := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
    var colour := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
    mask.fill(Color.BLACK)
    colour.fill(Color.BLACK)
    for y in 8:
        for x in 4:
            mask.set_pixel(x, y, Color.WHITE)
            if y < 4:
                colour.set_pixel(x, y, Color(0.2, 0.4, 0.1))
    var w := SeamScore.within(mask, colour)
    check(bool(w["ok"]), "the mask and the frame did not compare")
    check(int(w["band_pixels"]) == 32, "%d pixels in the band, not 32" % int(w["band_pixels"]))
    check(int(w["lit_pixels"]) == 16, "%d lit, not 16" % int(w["lit_pixels"]))
    var mean: Array = w["mean_colour"]
    check(absf(float(mean[1]) - 0.4) < 0.01, "the mean colour is of the lit pixels only")
    check(SeamScore.mask_pixels(mask) == 32, "the mask count disagrees with the band count")

    # Coverage is plant pixels over GROUND pixels in the same band, and it may
    # exceed one: a tree covers more screen than its own footprint, and a metric
    # clamped at one would report a closed canopy and a forest as the same.
    check(absf(SeamScore.coverage(16, 32) - 0.5) < 1e-9, "coverage is not the ratio")
    check(SeamScore.coverage(64, 32) > 1.0, "coverage was clamped at one")
    check(is_nan(SeamScore.coverage(16, 0)), "coverage over no ground returned a number")

    # The distribution distance has to see WHERE two histograms differ and not
    # only that they do -- one bucket apart and opposite ends of the range score
    # the same under L1, and the whole question is a little too dark or a lot.
    var a := [1.0, 0.0, 0.0, 0.0]
    var near := [0.0, 1.0, 0.0, 0.0]
    var far := [0.0, 0.0, 0.0, 1.0]
    var d_near := SeamScore.luminance_distance(a, near)
    var d_far := SeamScore.luminance_distance(a, far)
    check(d_far > d_near * 2.0,
            "a distribution three buckets away scores %s against one bucket away at %s, so this "
            % [String.num(d_far, 4), String.num(d_near, 4)]
            + "metric cannot tell a little too dark from a lot")
    check(absf(SeamScore.luminance_distance(a, a)) < 1e-9, "a histogram differs from itself")

    # And the ranking, which is where a metric that cannot separate has to say
    # so rather than name a winner.
    var clear := SeamScore.rank({"range_matched": 0.01, "constant": 0.05, "null": 0.4})
    check(str(clear["order"][0]["candidate"]) == "range_matched", "the ranking is not by error")
    check(bool(clear["separates"]), "a 5x gap was called inseparable")
    var muddy := SeamScore.rank({"a": 0.100, "b": 0.105})
    check(not bool(muddy["separates"]), "a 5% gap was called a result")
    check(str(muddy["why_not"]).contains("cannot be trusted"),
            "an inseparable ranking does not say it is one: %s" % str(muddy.get("why_not", "")))
    print("seam metric: annulus %s, coverage 16/32 = %.2f, %d bands, far/near histogram %.1fx"
            % [str(score), SeamScore.coverage(16, 32), bands.size(), d_far / maxf(d_near, 1e-9)])


func test_plants_stand_on_the_surface_that_is_drawn() -> void:
    """M5 PLACED EVERY INSTANCE ON THE HEIGHTFIELD AND THE TERRAIN DRAWS A
    TRIANGULATION OF IT.

    `TerrainMesh.build` samples the field every `stride` texels — 4 km apart on
    the 1,000 m overview — so the surface that renders between samples is a
    plane and the field beneath it is not. Measured over 3,916 mid-quad points
    at 1:1: the two differ by a mean of 36 m and by up to 640 m. Plants placed
    on the field float above the ground or are buried under it by tens of
    metres.

    From the overview camera, where the basin is 1.5 million metres across, that
    is invisible, and four milestones of screenshots did not show it. The seam
    harness photographed 1.65 million instances as a patch on the horizon, which
    is what finally did.

    Two things are checked: that the drawn surface agrees with the field exactly
    at the sample points (so it IS the same surface, interpolated differently),
    and that it disagrees between them by enough to matter.
    """
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    var hf := v.heightfield
    var tm := v.terrain
    var verts: PackedVector3Array = tm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

    # AT a mesh vertex the two must agree: the triangulation passes through its
    # own samples, so any disagreement there is a transform bug and not coarseness.
    var checked := 0
    var worst_at_node := 0.0
    for i in range(0, verts.size(), 977):
        var w := tm.mesh_to_world(verts[i], hf)
        var drawn := tm.drawn_surface_y(w, hf)
        if is_nan(drawn):
            continue
        checked += 1
        worst_at_node = maxf(worst_at_node, absf(drawn - verts[i].y))
    check(checked > 20, "only %d mesh vertices could be compared" % checked)
    check(worst_at_node < 1.0,
            "the drawn surface misses its own vertices by %s m: it is not reproducing the "
            % String.num(worst_at_node, 3)
            + "triangulation, which means the diagonal it splits quads along is wrong")

    # BETWEEN vertices they must differ, or none of this mattered.
    var rng := RandomNumberGenerator.new()
    rng.seed = 20260904
    var n := 0
    var total := 0.0
    var worst := 0.0
    for i in 800:
        var base := tm.mesh_to_world(verts[rng.randi_range(0, verts.size() - 1)], hf)
        var w := base + Vector2(rng.randf_range(-2000.0, 2000.0),
                                rng.randf_range(-2000.0, 2000.0))
        var field := hf.height_at_world(w.x, w.y)
        var drawn := tm.drawn_surface_y(w, hf)
        if is_nan(field) or is_nan(drawn):
            continue
        var gap := absf(field * tm.exaggeration - drawn)
        n += 1
        total += gap
        worst = maxf(worst, gap)
    check(n > 200, "only %d mid-quad points were valid" % n)
    # Five metres, against a measured 36. The threshold is a floor on "this
    # still matters", not a restatement of the measurement -- and it is in true
    # metres, because the geometry is 1:1 and mesh space is world space.
    check(total / float(maxi(n, 1)) > 5.0,
            "the drawn surface and the field differ by only %s m on average. If that is now "
            % String.num(total / float(maxi(n, 1)), 1)
            + "small the stride has changed and this guard has stopped guarding anything; if "
            + "it is zero, something is sampling the field where it should sample the mesh.")

    # And the scatter's own centre stands on the drawn surface, not the field --
    # the same call every instance makes.
    v.bind_fields()
    if bool(v.bind_families().get("ok", false)):
        v.show_field("deepest_winter", "band.pft_fractions", 22)
        var centre := tm.mesh_to_world(verts[5000], hf)
        var r := v.scatter_at(centre, 400.0, [], 2000)
        if bool(r.get("ok", false)):
            var want := tm.drawn_surface_y(centre, hf)
            check(absf(v.scatter_centre_mesh.y - want) < 1.0,
                    "the scatter centre stands at %s and the drawn surface is at %s"
                    % [String.num(v.scatter_centre_mesh.y, 2), String.num(want, 2)])
            var field_y: float = hf.height_at_world(centre.x, centre.y) * tm.exaggeration
            check(absf(v.scatter_centre_mesh.y - field_y) > 1.0 or absf(want - field_y) < 1.0,
                    "the scatter centre is on the field rather than on the drawn surface")
    print("surface: drawn matches its vertices within %s m and the field by %s m on average "
            % [String.num(worst_at_node, 3), String.num(total / float(maxi(n, 1)), 1)]
            + "between them (worst %s)" % String.num(worst, 1))
    v.queue_free()


func test_the_seam_measurement_ranks_the_null_baseline_worst() -> void:
    """The seam harness's own finding, held in the gate.

    The metric is only worth pointing at a subtle candidate if it visibly fails
    an unsubtle one, so every run grades the null baseline — what ships today —
    alongside the tint. If the tint ever stops beating it, either the tint
    regressed or the metric did, and both are worth failing for.

    The numbers are read from the artefact rather than restated, so a re-run
    that moves them moves this test with it.
    """
    var path := "res://measurements/scatter_seam.json"
    if not FileAccess.file_exists(path):
        return
    var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
    check(typeof(parsed) == TYPE_DICTIONARY, "the seam artefact is not a JSON object")
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var runs: Array = (parsed as Dictionary).get("runs", [])
    check(runs.size() >= 4, "the seam artefact carries %d run(s); sufficiency is a claim about "
            % runs.size() + "places and days and one row of it is not evidence for the claim")
    var places := {}
    var days := {}
    var worst_ratio := INF
    for r in runs:
        var run: Dictionary = r
        if not bool(run.get("measured", true)):
            continue
        places[str(run["scene"]["at_world_epsg5070"])] = true
        days[str(run["scene"]["window"]) + str(run["scene"]["day"])] = true
        var e: Dictionary = run["errors_against_oracle"]["isolated_colour"]
        check(e.has("null") and e.has("constant"),
                "a run scored neither the null baseline nor the tint")
        var tint := float(e["constant"])
        var null_err := float(e["null"])
        check(tint > 0.0, "the tint scored a colour error of exactly zero, which is a frame "
                + "that was not drawn rather than a perfect match")
        worst_ratio = minf(worst_ratio, null_err / tint)
        check(null_err > tint,
                "the null baseline (%s) scored better than the tint (%s) at %s day %d. Either "
                % [String.num(null_err, 4), String.num(tint, 4),
                   str(run["scene"]["window"]), int(run["scene"]["day"])]
                + "the candidate regressed or the metric stopped discriminating; a metric that "
                + "cannot fail the frame that ships today cannot grade anything subtler.")
    check(places.size() >= 2, "every run stands in the same place; place-dependence is measured "
            + "and one place cannot show sufficiency")
    check(days.size() >= 2, "every run draws the same day")
    check(worst_ratio > 2.0,
            "the tint's worst margin over the null baseline is only %sx" % String.num(worst_ratio, 2))
    print("seam: %d runs over %d places and %d day(s); the tint beats what ships today by at "
            % [runs.size(), places.size(), days.size()]
            + "least %sx on annulus colour" % String.num(worst_ratio, 1))


func test_the_shading_is_exaggerated_and_the_geometry_is_not() -> void:
    """The 1:1 decision's one concession, and the line it must not cross.

    Vertical exaggeration is out of this project's geometry — terrain, plants
    and the distances between them are true scale, so `cover = count × crown
    area` holds by construction. What that costs is relief: at true normals this
    basin hillshades to thirteen brightness levels and a map camera cannot read
    it. So the gradient is steepened where the LIGHT reads it, and nowhere else.

    A normal is a lighting input; a vertex position is a geometric claim. This
    holds those apart: every vertex must sit at its true height, and the normals
    must not be the ones true heights would give — because if they were, the
    concession would have quietly stopped working, and a flat basin looks like a
    basin.
    """
    var hf := heightfield()
    var true_scale := TerrainMesh.new()
    true_scale.build(hf, 8, 1.0, 12.0)
    var flat_lit := TerrainMesh.new()
    flat_lit.build(hf, 8, 1.0, 1.0)

    var va: PackedVector3Array = true_scale.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var vb: PackedVector3Array = flat_lit.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var na: PackedVector3Array = true_scale.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    var nb: PackedVector3Array = flat_lit.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    check(va.size() == vb.size() and va.size() > 1000, "the two builds differ in vertex count")
    if va.size() != vb.size():
        return

    # GEOMETRY IS IDENTICAL. The shading factor must move nothing that anything
    # stands on, or the scatter, the drapes and the camera are all misplaced by
    # it -- which is the defect that cost this project four milestones.
    var moved := 0.0
    for i in va.size():
        moved = maxf(moved, va[i].distance_to(vb[i]))
    check(moved < 1e-4,
            "steepening the shading moved a vertex by %s m. It is a lighting parameter; a mesh "
            % String.num(moved, 5) + "that moves with it puts everything standing on the ground "
            + "somewhere the ground is not.")

    # And the vertex heights are the field's own, unmultiplied.
    var worst := 0.0
    var checked := 0
    for i in range(0, va.size(), 401):
        var w := true_scale.mesh_to_world(va[i], hf)
        var field := hf.height_at_world(w.x, w.y)
        if is_nan(field):
            continue
        checked += 1
        worst = maxf(worst, absf(va[i].y - field))
    check(checked > 20, "only %d vertices could be checked against the field" % checked)
    check(worst < 1.0, "a vertex sits %s m from the height the field gives it, so the geometry "
            % String.num(worst, 3) + "is not 1:1")

    # SHADING IS NOT IDENTICAL, or the concession is not being made.
    var turned := 0.0
    for i in na.size():
        turned = maxf(turned, na[i].angle_to(nb[i]))
    check(turned > deg_to_rad(20.0),
            "the steepened normals differ from the true ones by at most %.1f degrees. The "
            % rad_to_deg(turned) + "hillshade is reading true gradients, which over 4 km of "
            + "relief across 1,000 km of basin is thirteen brightness levels of flat.")
    check(TerrainView.EXAGGERATION == 1.0,
            "the view builds geometry at %s, not 1:1" % String.num(TerrainView.EXAGGERATION, 2))
    print("scale: geometry 1:1 within %s m of the field; shading normals turn up to %.0f degrees"
            % [String.num(worst, 4), rad_to_deg(turned)])
