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
    say_if_the_fixture_is_absent()
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
    test_the_wide_branch_has_a_witness_that_is_not_the_fixture()
    test_a_published_scalar_is_read_from_its_bits_and_never_from_its_decimal()
    test_both_new_readers_run_on_the_shape_the_fixture_actually_ships()
    test_the_client_declares_exactly_the_rows_its_fixture_carries()
    test_the_tint_takes_phenology_from_the_wire_when_the_row_is_carried()
    test_an_envelope_does_not_refuse_a_value_for_being_uncertain()
    test_every_reach_carries_a_node_so_flow_can_be_drawn()
    test_the_flow_mapping_distinguishes_zero_from_below_scale()
    test_quantisation_uses_the_realised_range_not_the_contracts()
    test_burn_asks_about_magnitude_before_geometry()
    test_contours_index_the_day_the_manifest_says()
    test_contour_arcs_land_on_the_terrain_they_were_extracted_on()
    test_the_contour_line_stays_broken()
    test_no_contour_set_is_invented_for_a_window_that_has_none()
    test_the_probe_tells_the_three_absences_apart()
    test_a_verdict_stale_against_its_replay_is_not_absorbed_into_equivalent()
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
    test_the_budget_solve_divides_by_the_floors_measured_multiplier()
    test_the_empty_stage_coefficient_is_a_floor_and_the_scene_sits_above_it()
    test_the_scatter_measurement_verifies_in_pixels_not_primitives()
    test_every_wire_life_form_resolves_to_a_family()
    test_no_family_is_keyed_below_life_form_off_the_wire()
    test_a_parameter_outside_its_range_is_refused_not_clamped()
    test_the_exaggeration_is_applied_after_the_check_not_before()
    test_the_families_hold_the_unit_convention_the_transform_relies_on()
    test_the_cost_model_refuses_outside_its_measured_span()
    test_the_scatter_reports_what_it_could_not_draw()
    test_the_individuation_horizon_is_one_constant_bounded_by_the_camera()
    test_placement_is_a_function_of_where_and_thins_by_a_stable_prefix()
    test_two_builds_over_the_same_ground_place_the_same_plants()
    test_a_census_is_the_stand_a_headless_replay_can_score()
    test_a_flight_trace_round_trips_and_a_pan_cannot_churn()
    test_no_committed_trace_is_over_the_size_this_repo_commits()
    test_every_committed_trace_holds_the_quanta_its_writer_declares()
    test_the_pinned_flight_replays_to_what_the_artefact_says()
    test_a_density_schedule_is_finer_than_the_texel_it_thins()
    test_pft_fractions_are_a_composition_of_the_cover()
    test_the_tint_takes_wire_shares_unfloored_and_the_drawn_unit_can_change()
    test_the_tint_holds_the_quantity_a_seam_has_to_conserve()
    test_a_recorded_distance_names_what_it_is_conditional_on()
    test_the_seam_metric_fails_the_bad_frame()
    test_plants_stand_on_the_surface_that_is_drawn()
    test_the_shading_is_exaggerated_and_the_geometry_is_not()
    test_the_harness_guards_refuse_what_they_were_written_for()
    test_the_motion_metrics_and_which_of_them_detects_popping()
    test_the_solved_horizon_discriminates_rather_than_returning_its_ceiling()
    test_every_recorded_seam_run_says_which_question_it_answers()
    test_a_per_family_reference_holds_only_that_family()
    test_a_family_is_scored_in_its_own_annulus_or_not_at_all()
    test_the_seam_measurement_separates_the_tint_from_the_null()
    test_the_project_does_not_import_blend_sources()
    test_phenology_is_the_cell_measured_against_itself()
    test_the_tint_moves_with_the_season_it_is_read_from()
    test_multimesh_custom_data_does_not_read_back_headless()
    test_the_bundle_admits_only_what_it_declares()
    test_the_same_moment_produces_the_same_bundle()
    test_the_passthrough_earns_nothing_and_hides_nothing()
    test_the_bundle_paints_the_pixels_the_fixture_did()
    test_an_overlay_refuses_a_bundle_it_did_not_bind_against()
    test_the_observation_point_is_the_bodys_and_never_the_cameras()
    test_the_transducer_subtree_consumes_the_bundle_and_never_the_fixture()
    test_the_body_moves_at_the_speed_the_bundle_reports()
    test_walk_mode_is_refused_while_the_ground_is_a_plane()
    test_a_recorded_walk_replays_and_cannot_outrun_its_own_locomotion()
    test_the_console_partitions_its_verbs_from_birth()
    test_the_percept_min_names_what_binds_and_never_folds_art_debt()
    test_the_probe_re_derives_what_the_build_placed()
    test_a_re_centre_that_moved_a_key_is_a_defect_and_not_churn()
    test_the_console_answers_headless_from_a_named_point()
    test_the_tiles_do_not_decode_with_the_overviews_constants()
    test_an_unwritten_tile_is_empty_ground_and_not_a_missing_fetch()
    test_the_pyramid_makes_the_near_field_relief_and_does_not_open_walk_mode()
    test_a_node_with_no_asset_draws_its_parent_and_says_it_is_art_debt()
    test_the_mock_earns_a_rung_and_its_boundary_is_cell_shaped()
    test_no_subject_is_drawn_at_two_rungs_and_the_guard_can_fire()
    test_walking_the_boundary_switches_the_rung_once_and_never_both()
    test_the_detail_is_exactly_zero_at_every_parent_sample()
    test_the_detail_tells_a_playa_from_a_talus_slope()
    test_one_ground_for_every_consumer_or_none_at_all()
    test_the_detail_rows_say_that_they_are_invented()
    test_the_finest_level_is_the_one_chosen_and_z_zero_is_it()
    test_a_tile_in_flight_is_not_empty_ground()
    test_the_patch_rim_lies_on_the_coarse_plane_exactly()
    test_a_rebuild_moves_no_shared_vertex()
    test_the_patch_never_takes_ground_away()
    test_the_ground_refuses_a_patch_it_is_not_standing_on()
    test_the_near_field_gains_the_data_s_own_samples()
    test_the_detail_vanishes_on_the_patch_and_appears_below_it()
    test_one_row_serves_two_parents()
    test_a_level_switch_moves_no_plant()
    test_a_patch_refines_its_own_level_and_not_the_overview()
    test_the_view_turns_detail_on_for_both_surfaces_or_neither()
    test_the_patch_keeps_ground_the_native_grid_does_not_have()
    test_the_layers_ride_the_pyramids_own_grid()
    test_aspect_is_read_through_its_validity_byte_and_never_around_it()
    test_a_layer_decodes_into_the_range_its_pin_declares()
    test_the_classifier_reads_the_layers_and_can_reach_the_margin()
    test_the_golden_bundle_carries_exactly_what_the_schema_declares()
    test_the_golden_bundle_loads_checks_and_round_trips()
    test_the_schema_refuses_an_undeclared_name_at_every_level()
    test_no_consumer_paints_one_lattices_row_through_the_others_join()
    test_probe_row_reads_a_node_row_through_the_residence_layers_own_node_id()
    test_the_flow_drape_paints_from_a_bundle_and_never_from_the_fixture()
    test_a_withheld_node_draws_as_no_information_and_not_as_no_water()
    test_the_amplitude_field_has_no_step_on_a_class_boundary()
    test_the_blend_cannot_break_the_exactness_at_a_parent_node()
    test_hand_conditions_the_amplitude_and_absence_is_full_strength()
    test_the_detail_is_band_limited_below_the_parent_spacing()
    test_the_field_is_c1_and_says_which_term_binds()
    test_a_token_rotates_at_all_three_boundaries_and_nowhere_else()
    test_a_rotation_is_not_an_erasure_and_the_map_rides_the_envelope()
    test_the_skin_keys_on_precision_and_dies_with_the_token()
    test_the_detail_function_conforms_to_its_published_vectors()
    test_the_five_part_hash_is_the_general_one()
    test_the_structure_function_refuses_below_the_spacing_it_declares()
    test_the_plain_form_reports_the_slope_and_the_detrended_form_cannot_see_it()
    test_the_instrument_repeats_and_recovers_a_known_exponent()
    test_walk_mode_is_shut_for_986s_reasons_and_itemises_which()
    test_the_strata_are_the_membership_functions_on_real_ground()
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
    # THE CLIENT IS ONE MINOR BEHIND THE ARTEFACT, DELIBERATELY, AND THIS PINS
    # THAT RATHER THAN TOLERATING IT.
    #
    # This read `doc.reports.is_empty()` -- right while the client was written
    # against the pinned version, and wrong the moment v2.1 landed with
    # `band.phenology_index` (decision 977) ahead of `CLIENT_MINOR`. The
    # constant is not bumped until the fixture carrying the row exists, so the
    # correct state is a masked row and two reports about it.
    #
    # Relaxing this to "reports are allowed" would have thrown away the check
    # entirely. What it asserts instead is the EXACT lag: which rows are
    # carried, which one is masked, and that the mask is reported as
    # undeclared rather than as a zero. When the fixture lands and the
    # constant moves, this test fails and tells whoever moved it what to
    # expect -- which is the same two-file discipline the pin itself has.
    var carried := PackedStringArray()
    for r in doc.rows:
        carried.append(r.name)
    var ahead := doc.masked_rows
    # AGAINST THE ARTEFACT'S OWN COUNT, so a row that vanished for a third
    # reason -- malformed, unknown value_kind, a rung outside its domain --
    # cannot hide inside "carried plus masked".
    var raw = JSON.parse_string(FileAccess.open("res://contract/schema.json",
            FileAccess.READ).get_as_text())
    var declared := int((raw as Dictionary).get("row_count", -1))
    check(doc.rows.size() + ahead.size() == declared,
            "%d carried plus %d masked does not account for the artefact's %d rows"
            % [doc.rows.size(), ahead.size(), declared])
    for name in ahead:
        check(not carried.has(str(name)),
                "%s is both carried and masked" % str(name))
        check(doc.row_named(str(name)) == null,
                "%s is masked and still reachable by name, which is the difference between "
                % str(name) + "undeclared and zero")
    var since_reports := 0
    for rep in doc.reports:
        if str(rep).begins_with(SchemaLoader.SKIP_SINCE_AHEAD_OF_CLIENT):
            since_reports += 1
        else:
            check(str(rep).contains("server minor ahead"),
                    "the shipped contract produced a report that is not the expected lag: %s"
                    % str(rep))
    check(since_reports == ahead.size(),
            "%d rows are ahead of this client and %d were reported; a mask that is not "
            % [ahead.size(), since_reports] + "reported is a row that vanished")
    print("real artefact: v%s, %d rows carried, %d masked ahead of client minor %d (%s)"
            % [doc.envelope.version.as_string(), doc.rows.size(), ahead.size(),
                    SchemaLoader.CLIENT_MINOR, str(Array(ahead))])


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


## ONE SENTENCE AT THE TOP, BEFORE THE THIRTY-EIGHT.
##
## The fixture binary is fetched rather than committed (decision 948) and a
## run without it fails 38 checks -- every one of them reading `... gave 0
## values, its shape says 5684`, none of them naming the file. CI was red for
## thirty commits that way: the cause appeared once, as a `push_error` on line
## 33 of a hundred-line log, and the symptom appeared thirty-eight times at the
## bottom where anyone would look.
##
## SO THIS DOES NOT SKIP AND IT DOES NOT PASS. The failures below are real --
## the suite cannot check a decoder against an artefact that is not there, and
## turning 1,526 checks into skips would let a green run mean half a gate. It
## says what is wrong once, in front, in the words that name the fix.
func say_if_the_fixture_is_absent() -> void:
    var fl := fixture()
    if fl.is_loaded():
        return
    print("")
    print("---- THE FIXTURE BINARY IS NOT HERE, AND EVERYTHING BELOW FOLLOWS FROM THAT ----")
    print("  missing: %s" % fl.binary_path())
    print("  it is fetched, never committed (decision 948): 28 MB against a 10 MB threshold.")
    print("  bring it in:  python3 tools/fetch_artefacts.py")
    print("  the gate does that for you and requires it:  bash tools/verify.sh")
    print("  the failures after this line are one missing file wearing many names.")
    print("")


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
    """A row the fixture stores wide is HELD wide: a PackedFloat32Array flushes
    everything under 1.18e-38 to zero, which moves samples from "below the
    display scale" to "no flow" -- a different statement about the river.

    KEYED ON THE DECLARED WIDTH, NOT ON `node.streamflow`. The emitting side
    measures each row's width per build and ships a row wide only while its
    values need it, so a row's width is a property of the run. This check named
    streamflow and asserted that something in it fell below float32's floor,
    which made a correctly-narrowed fixture arrive here as "the precision was
    lost in transit" -- a true artefact reported as a defect in the reader, and
    the accusation pointing at the one component that had done nothing wrong.
    It now finds its subject by asking the manifest which rows are wide.

    Measured on the fixture in hand: `node.streamflow` is the ONLY unquantised
    row, at 17.41% of samples below float32's floor in `largest_fire` and 5.38%
    in `deepest_winter`, smallest 5e-324. So the witness count below is 1, and
    a narrowing takes it to 0 -- which is why it is printed every run rather
    than left to be inferred from a test that stopped being about anything."""
    var fl := fixture()
    var wide := fl.unquantised_rows(fl.windows[0])
    var carried := 0
    for row in wide:
        var vals := fl.day_values(fl.windows[0], row, 45)
        check(vals.size() > 0, "%s is declared wide and decoded to nothing" % row)
        check(vals is PackedFloat64Array,
                "%s came back in a narrower container than it is stored in" % row)
        var below_f32 := 0
        var zeros := 0
        var smallest := INF
        for v in vals:
            if v == 0.0:
                zeros += 1
            elif not is_nan(v):
                smallest = minf(smallest, v)
                if v < 1.18e-38:
                    below_f32 += 1
        carried += below_f32
        # Not "there must be small values" -- that is the run's business. What
        # is checked is that whatever small values ARE here came through: the
        # same number put through float32 is zero, so if the reader had
        # narrowed anywhere the count would be 0 and this comparison shows it.
        if below_f32 > 0:
            check(PackedFloat32Array([smallest])[0] == 0.0,
                    "%s's smallest value %s does not flush through float32, so this "
                    % [row, String.num_scientific(smallest)]
                    + "comparison is no longer showing what it says")
        print("wide row %s: %d cells, %d exact zeros, %d below float32's floor, smallest %s"
                % [row, vals.size(), zeros, below_f32, String.num_scientific(smallest)])
    # THE WITNESS COUNT IS REPORTED WHETHER OR NOT IT IS ZERO. A fixture with no
    # wide row is legitimate and is not failed here, but it leaves `day_values`'
    # wide branch with no witness in the artefact -- which is what
    # `test_the_wide_branch_has_a_witness_that_is_not_the_fixture` is for, and
    # this line is how somebody notices the day it happens.
    print("wide rows in the fixture: %d, carrying %d sub-float32 samples on day 45"
            % [wide.size(), carried])


func test_both_new_readers_run_on_the_shape_the_fixture_actually_ships() -> void:
    """`DECLARED_STALE` and `PublishedBits` were built against a fixture that
    carried neither field: green, and never once exercised against the shape
    they exist for. That is the state my own §2 warned about -- a branch whose
    only witness is absent, passing while proving nothing -- and it applied to
    the two things written to answer it.

    The values below are the shipped ones, quoted from `fixture_v1.json` at
    magisteria@9169af5a61cd because this repo cannot clone the private one.
    They are a witness the re-vendor does not have to arrive for."""
    # ---- PublishedBits, on every wide row the fixture declares -------------
    var shipped := [
        ["largest_fire/band.pft.biomass", "9.02759206434e-312", "0x000001a96de74c92"],
        ["largest_fire/band.snowpack_swe", "6.970155342103717e-41", "0x3798499619cc2340"],
        ["deepest_winter/band.pft.biomass", "6.278069149686167e-168", "0x1d37b1755cff1e35"],
        ["deepest_winter/band.snowpack_swe", "7.363574367240632e-58", "0x34127d1f84982978"],
    ]
    var lost_through_the_decimal := 0
    for row in shipped:
        var name: String = row[0]
        var block := {"min_nonzero_magnitude": JSON.parse_string(str(row[1])),
                "min_nonzero_bits": str(row[2])}
        var from_bits := PublishedBits.of_named(block, FixtureLoader.MIN_NONZERO_BITS_KEY)
        check(PublishedBits.to_hex(from_bits) == str(row[2]),
                "%s did not read back from its pattern: %s"
                % [name, PublishedBits.to_hex(from_bits)])
        check(from_bits > 0.0, "%s read back as %s, and a minimum NON-ZERO magnitude cannot be "
                % [name, PublishedBits.to_hex(from_bits)] + "zero or negative")
        var from_decimal := float(block["min_nonzero_magnitude"])
        if from_decimal != from_bits:
            lost_through_the_decimal += 1
            print("min_nonzero %s: pattern %s, decimal %s"
                    % [name, PublishedBits.to_hex(from_bits),
                       PublishedBits.to_hex(from_decimal)])
    # THE MECHANISM SHOWN ACTING. If every decimal happened to parse exactly,
    # reading the pattern would be a precaution rather than a fix, and this
    # test would be passing for a reason that is not the reason it exists.
    check(lost_through_the_decimal > 0,
            "all four shipped decimals parse exactly in this engine, so nothing here "
            + "demonstrates why the patterns are published")

    # ---- AND THE READER DOES NOT CONSULT THE DECIMAL, AT ALL --------------
    # Stated as a property rather than trusted: the same pattern beside a
    # decimal that is flatly wrong must return the pattern's value. A reader
    # that cross-checked would fire here, and it would fire on a correct file.
    var lying := {"min_nonzero_magnitude": 1.0, "min_nonzero_bits": "0x000001a96de74c92"}
    check(PublishedBits.to_hex(PublishedBits.of_named(lying, "min_nonzero_bits"))
                    == "0x000001a96de74c92",
            "the reader let a decimal beside the pattern change its answer")

    # ---- THE float32 ROW, which the brief warned would fire ---------------
    # It does not, and the reason is worth writing down. `dec` and `bits` here
    # are TWO SPELLINGS OF ONE DOUBLE -- checked below -- so no comparison
    # between them can disagree. What genuinely differs by design is the
    # declared minimum against the smallest value actually PRESENT in the
    # narrowed row, because the declaration is measured before the narrowing
    # and the file holds the value after it. That is a different comparison
    # and nothing here makes it.
    var f32_row := {"min_nonzero_magnitude": 0.03540878028907135,
            "min_nonzero_bits": "0x3fa2211982aa6630", "dtype": "float32 little-endian"}
    var declared := PublishedBits.of_named(f32_row, "min_nonzero_bits")
    check(declared == float(f32_row["min_nonzero_magnitude"]),
            "the float32 row's decimal and pattern are not the same double: %s against %s"
            % [PublishedBits.to_hex(declared),
               PublishedBits.to_hex(float(f32_row["min_nonzero_magnitude"]))])
    # AND THE DECLARED VALUE IS THE PRE-NARROWING ONE, which is the evidence
    # for the paragraph above: a float32 value re-widened has 29 zero mantissa
    # bits, and this has none.
    check(PackedFloat32Array([declared])[0] != declared,
            "the declared minimum survives a float32 round trip, so it is the narrowed value "
            + "rather than the measurement taken before narrowing, and the reason the two "
            + "differ is not what this says it is")
    print("min_nonzero float32 row: declared %s, nearest float32 %s"
            % [PublishedBits.to_hex(declared),
               PublishedBits.to_hex(float(PackedFloat32Array([declared])[0]))])

    # ---- DECLARED_STALE, on the shipped declaration -----------------------
    var shipped_manifest := {"run": {
            "base_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
            "acceptance": {
                "scored_at_commit": "5317027b6543de846a4c53745996f0ed70d61119",
                "scored_run_dir": "runs/m0-instrumented-001",
                "passed": 7, "failed": 5, "not_evaluable": 0,
                "failed_criteria": [{"id": 1, "name": "seasonal snowpack",
                        "renders_as": "a near-bare snowpack overlay"}],
                "equivalence": {"to_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
                        "fields_compared": 18, "fields_matching": 18},
                "stale_against_replay": {
                    "replayed_at_commit": "66fa05134deff7f9b7ca9fe371298c8d6aceac58",
                    "declared_by_the_operator": ("Owner-authorised 2026-09-11. This is the last "
                            + "scored verdict and it is stale against this payload's code: the "
                            + "melt gate (1ca6a0c) and swe_50's per-band build (245aec4) landed "
                            + "after the scoring."),
                    "what_the_equivalence_proof_below_does_not_cover": ("the proof compares this "
                            + "verdict's RUN with this fixture's run. Both are state. The "
                            + "verdict's CODE and the replay's code are different here and "
                            + "nothing below compares them.")}}}}
    var v := AncestorVerdict.read_from(shipped_manifest)
    check(v.state == AncestorVerdict.DECLARED_STALE,
            "the shipped declaration read as %s" % v.state)
    check(v.underlying_state == AncestorVerdict.EQUIVALENT,
            "the shipped 18/18 proof was not kept: underlying is %s" % v.underlying_state)
    # THE COMMITS ARE FULL-LENGTH HERE AND WERE SHORT IN THE SYNTHETIC CASE.
    # The prefix comparison is what lets a short-hashed verdict through, and a
    # reader that only ever saw one length would not have exercised it.
    check(v.headline().contains("66fa0513"),
            "the headline does not carry the replay commit: %s" % v.headline())
    check(v.staleness_lines().size() == 2
                    and str(v.staleness_lines()[0]).contains("Owner-authorised"),
            "the shipped operator declaration did not reach the reader: %s"
            % str(v.staleness_lines()))
    check(str(v.staleness_lines()[1]).contains("Both are state"),
            "the shipped statement of what the proof does not cover was dropped: %s"
            % str(v.staleness_lines()[1]))
    var banner := VerdictBanner.new()
    banner.setup()
    banner.show_verdict(v)
    check(banner._fails.visible and banner._fails.text.contains("Owner-authorised"),
            "the shipped declaration does not reach the picture: %s" % banner._fails.text)
    banner.free()
    print("verdict: shipped declaration reads %s (underlying %s)"
            % [v.state, v.underlying_state])


## A fixture carrying `band.phenology_index`, written here because no vendored
## one carries it and the wire branch would otherwise never run.
func _fixture_with_a_phenology_row(values: PackedFloat64Array) -> FixtureLoader:
    var dir := "user://phenology_witness/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
    var bin := PackedByteArray()
    bin.resize(values.size() * 8)
    for i in values.size():
        bin.encode_double(i * 8, values[i])
    var bf := FileAccess.open(dir + "witness.bin", FileAccess.WRITE)
    bf.store_buffer(bin)
    bf.close()
    var pairs := []
    for i in values.size():
        pairs.append(["w", i])
    var manifest := {
        "client_form": {"file": "witness.bin", "rows": {
            "w/band.phenology_index": {
                "window": "w", "row": "band.phenology_index",
                "shape": [1, values.size()], "dtype": "float64 little-endian",
                "byte_offset": 0, "lattice": "band", "lo": 0.0, "hi": 1.0}}},
        "windows": ["w"],
        "cell_keys": {"pairs": pairs},
    }
    var mf := FileAccess.open(dir + "fixture_client.json", FileAccess.WRITE)
    mf.store_string(JSON.stringify(manifest))
    mf.close()
    return FixtureLoader.load_from(dir)


func test_the_client_declares_exactly_the_rows_its_fixture_carries() -> void:
    """THE THREE-WAY TIE THAT NOTHING HELD. `CLIENT_MINOR` says which rows this
    client declares, `assets/fixture/PIN` records which the vendored fixture
    carries, and the fixture itself holds the bytes. All three have to agree and
    none of them checked the others.

    MEASURED, BY MOVING THE CONSTANT AND RUNNING THE GATE. With `CLIENT_MINOR`
    at 1 against the fixture in hand -- eight carried rows, nine declared -- the
    suite passed at 4,054 checks and printed `9 rows carried, 0 masked`. Green.
    The contract test whose comment promises it will "fail and tell whoever
    moved it what to expect" does not fail: at equal minors the version reports
    stop being emitted and the loop that inspects them has nothing to iterate,
    so it loses three checks and says ALL GREEN. Absence and pass, identical.

    WHY IT MATTERS NOW rather than in the abstract: the re-vendor is one atomic
    operation -- fetch, PIN, `carried_rows`, `contract_version`, `CLIENT_MINOR`
    -- and until this check existed, a HALF-DONE one was undetectable in either
    direction. Bump without fetch and the client declares it reads a row its own
    fixture has not got; fetch without bump and the row sits masked while the
    bytes for it are on disk."""
    var doc := SchemaLoader.load_from_file("res://contract/schema.json")
    check(doc.rows.size() > 0, "the contract declared no rows at all")
    var declared := PackedStringArray()
    for r in doc.rows:
        declared.append(r.name)
    declared.sort()

    # WHAT THE FIXTURE ACTUALLY HOLDS, from the bytes rather than from the PIN,
    # because the PIN is a claim about the bytes and this is the one place that
    # can tell the two apart.
    var fl := fixture()
    var carried := PackedStringArray()
    for w in fl.windows:
        for r in fl.row_names(w):
            if not carried.has(r):
                carried.append(r)
    carried.sort()

    check(Array(declared) == Array(carried),
            "this client declares %s at CLIENT_MINOR %d and its fixture carries %s. "
                    % [str(Array(declared)), SchemaLoader.CLIENT_MINOR, str(Array(carried))]
            + "A row declared and not carried is a client claiming to read something it has "
            + "not got; a row carried and not declared is bytes on disk nothing may read. "
            + "If the re-vendor is in progress, it is half done.")

    # AND THE PIN AGREES WITH BOTH, since it is what `fetch_artefacts.py` acts
    # on and a stale one sends the next clone to the wrong bytes.
    var pin_f := FileAccess.open("res://assets/fixture/PIN", FileAccess.READ)
    check(pin_f != null, "no fixture PIN")
    if pin_f == null:
        return
    var pin: Dictionary = JSON.parse_string(pin_f.get_as_text())
    var pinned := PackedStringArray()
    for r in (pin.get("carried_rows", []) as Array):
        pinned.append(str(r))
    pinned.sort()
    check(Array(pinned) == Array(carried),
            "the PIN records carried_rows %s and the fixture holds %s"
            % [str(Array(pinned)), str(Array(carried))])

    # The PIN's contract version is a string like "2.0"; the client's major and
    # minor are the two halves of what it is allowed to read.
    var pin_version := str(pin.get("contract_version", ""))
    var want_version := "%d.%d" % [SchemaLoader.CLIENT_MAJOR, SchemaLoader.CLIENT_MINOR]
    check(pin_version == want_version,
            "the PIN was vendored against contract %s and this client reads at %s. These move "
                    % [pin_version, want_version]
            + "together or the fixture and the constant are describing different contracts.")
    print("contract tie: %d rows declared at minor %d, %d carried, PIN at %s"
            % [declared.size(), SchemaLoader.CLIENT_MINOR, carried.size(), pin_version])


func test_the_tint_takes_phenology_from_the_wire_when_the_row_is_carried() -> void:
    """Decision 977 rules seasonal position crosses as a carried row derived
    server-side, and names CLIENT-SIDE RE-DERIVATION among the things it turns
    down. `phenology_for` is that re-derivation: it samples the trough and peak
    of whatever days this window holds, which are not the relaxation-maintained
    annual normals the server keeps and does not ship. So the stand-in is not an
    approximation of the row, it is a different quantity over the same range.

    THIS BRANCH HAS NO WITNESS IN ANY VENDORED ARTEFACT. No fixture here carries
    the row -- `carried_rows` in `assets/fixture/PIN` is eight rows and this is
    not one of them -- so the wire path would sit green and unexercised until a
    re-vendor, which is the state the width sweep was written about. The witness
    below is written by the test."""
    var sc := VegetationScatter.new()
    var want := PackedFloat64Array([0.0, 0.25, 1.0, NAN])
    var fl := _fixture_with_a_phenology_row(want)
    check(fl.days("w", VegetationScatter.PHENOLOGY_ROW) == 1,
            "the witness fixture does not carry the row")
    sc.bind(null, null, fl, null, null, null)

    # ---- THE WIRE SIDE ----------------------------------------------------
    check(sc.phenology_source("w") == VegetationScatter.PHENOLOGY_FROM_WIRE,
            "a fixture carrying the row still reports %s" % sc.phenology_source("w"))
    check(sc.phenology_uncertainty("w") == VegetationScatter.ROW_PHENOLOGY_UNCERTAINTY,
            "the wire's declared uncertainty did not follow the source: %s"
            % str(sc.phenology_uncertainty("w")))
    var row := sc.phenology_row_for("w", 0)
    check(row.size() == want.size(), "the row read back %d of %d cells"
            % [row.size(), want.size()])

    # A season whose stand-in answer is FAR from every wire value, so that a
    # blend, an average or a fallback would be visible rather than plausible.
    var season := {"lo": PackedFloat64Array([0.0, 0.0, 0.0, 0.0]),
            "hi": PackedFloat64Array([1.0, 1.0, 1.0, 1.0])}
    for cell in 3:
        var got := sc.phenology_at(row, season, cell, 0.5)
        check(got == want[cell],
                "cell %d read %s from the wire and the row holds %s -- the stand-in reached it"
                % [cell, String.num(got, 6), String.num(want[cell], 6)])
    # The stand-in would answer 0.5 for every one of those, so the three values
    # above being 0.0, 0.25 and 1.0 is what shows the wire is doing the work.
    check(sc.phenology_for(season, 0, 0.5) == 0.5,
            "the stand-in no longer answers 0.5 here, so the contrast this check rests on "
            + "is gone and the comparison proves nothing")

    # A CELL THE SERVER DID NOT ANSWER FOR STAYS UNANSWERED. Backfilling it
    # from the stand-in would put a number this client invented under the row's
    # name, which is the rejected mechanism wearing the carried row's label.
    check(is_nan(sc.phenology_at(row, season, 3, 0.5)),
            "a NAN in the carried row was backfilled from the stand-in")
    # And past the end of the row is also unanswered, not wrapped or clamped.
    check(is_nan(sc.phenology_at(row, season, 99, 0.5)),
            "a cell past the end of the carried row was answered")

    # ---- AND ON THE SHIPPED FIXTURE, WHICH NOW CARRIES THE ROW ------------
    # These four asserted the stand-in until 31efcab, with a failure message
    # saying that a wire reading meant T1 was unblocked and the handback needed
    # re-reading. It did, they fired, and this is that inversion: the same four
    # facts asserted the other way, on real bytes rather than on a witness the
    # test wrote for itself.
    var live := fixture()
    var sc2 := VegetationScatter.new()
    sc2.bind(null, null, live, null, null, null)
    var w: String = live.windows[0]
    check(sc2.phenology_source(w) == VegetationScatter.PHENOLOGY_FROM_WIRE,
            "the shipped fixture reports %s; it carries the row, so the wire is the source"
            % sc2.phenology_source(w))
    check(sc2.phenology_uncertainty(w) == VegetationScatter.ROW_PHENOLOGY_UNCERTAINTY,
            "the wire is the source and the declared uncertainty is %s rather than the row's"
            % String.num(sc2.phenology_uncertainty(w), 4))
    var live_row := sc2.phenology_row_for(w, 0)
    check(not live_row.is_empty(),
            "the shipped fixture carries the row and returned no values for it")

    # THE ROW IS A FRACTION AND THE CONTRACT SAYS SO. Checked against real
    # values rather than trusted: a row arriving outside its declared bounds is
    # how a unit change reaches a colour ramp unnoticed.
    var lo := INF
    var hi := -INF
    var nan_cells := 0
    for i in live_row.size():
        if is_nan(live_row[i]):
            nan_cells += 1
        else:
            lo = minf(lo, live_row[i])
            hi = maxf(hi, live_row[i])
    check(nan_cells < live_row.size(), "every cell of the carried row is NAN")
    check(lo >= 0.0 and hi <= 1.0,
            "the carried row spans [%s, %s], outside the fraction its contract declares"
            % [String.num(lo, 6), String.num(hi, 6)])
    # AND IT DISCRIMINATES. Convention 6's second clause on this row: a
    # basin-wide constant at a fixed day would place every cell at the same
    # point of its own year, which is the insufficiency calendar day already has.
    check(hi - lo > 0.01,
            "the carried row spans only %s across the basin on one day, so it discriminates "
                    % String.num(hi - lo, 6)
            + "no better than the calendar day decision 977 turned down")
    print("phenology: shipped fixture uses %s, %d cells, span [%s, %s], %d NAN"
            % [sc2.phenology_source(w), live_row.size(), String.num(lo, 4),
               String.num(hi, 4), nan_cells])


func test_an_envelope_does_not_refuse_a_value_for_being_uncertain() -> void:
    """`band.phenology_index` arrives at about 2% residual, permanently -- a
    deeper replay does not improve it. Its declared range here is [0, 1], which
    is the row's OWN bounds, so the two values a seasonal index spends most of
    its time at, dormant and peak, sit exactly on the edges. A 2%-uncertain 1.0
    arrives as 1.02 about as often as 0.98.

    And the caller does not merely flag a refused parameter, it drops the plant.
    So the strict check would have thinned dormant and peak stands seasonally,
    every individual refusal correct, reporting the ground when what it had was
    uncertainty."""
    var fs := family_set()
    if not fs.is_loaded() or fs.life_forms().is_empty():
        check(false, "no families loaded, so the envelope cannot be exercised")
        return
    var life: String = fs.life_forms()[0]
    var r := fs.range_of(life, "phenology")
    check(not r.is_empty(), "%s declares no phenology range" % life)
    var hi := float(r["max"])
    var u := VegetationScatter.ROW_PHENOLOGY_UNCERTAINTY

    # THE THREE OUTCOMES, each on a value chosen to land in exactly one of them.
    check(str(fs.verdict_on(life, "phenology", hi, u)["state"]) == FamilySet.INSIDE,
            "a value on the edge is not inside")
    var just_over := hi + u * 0.5
    check(str(fs.verdict_on(life, "phenology", just_over, u)["state"])
                    == FamilySet.WITHIN_UNCERTAINTY,
            "%s is outside by half the uncertainty and did not read as uncertain" % str(just_over))
    var well_over := hi + u * 4.0
    check(str(fs.verdict_on(life, "phenology", well_over, u)["state"]) == FamilySet.OUTSIDE,
            "%s is outside by four times the uncertainty and did not read as outside"
            % str(well_over))

    # THE CONTROL, which is what shows the uncertainty is what moved it rather
    # than the edge. The same value with nothing declared is refused, as it was.
    check(str(fs.verdict_on(life, "phenology", just_over, 0.0)["state"]) == FamilySet.OUTSIDE,
            "with no uncertainty declared, a value outside the range was not refused")
    check(fs.check(life, "phenology", just_over) != "",
            "the strict check stopped refusing, so the two paths no longer differ and this "
            + "test is comparing a thing against itself")

    # AN UNCERTAINTY NOBODY STATED IS NOT LICENCE, and neither is a nonsense one.
    for bad in [-1.0, NAN]:
        check(str(fs.verdict_on(life, "phenology", just_over, bad)["state"]) == FamilySet.OUTSIDE,
                "an uncertainty of %s widened the envelope" % str(bad))

    # AND THE THIRD OUTCOME IS NOT A WIDER RANGE. A value inside must not be
    # reported as merely-not-provably-outside, or the caller loses the
    # distinction the third state exists to make.
    check(str(fs.verdict_on(life, "phenology", hi * 0.5, u)["state"]) == FamilySet.INSIDE,
            "a value in the middle of the range read as uncertain")
    # A missing range is not an uncertainty question: there is no edge to be
    # near, so the strict refusal survives verbatim rather than being softened.
    var no_such := fs.verdict_on(life, "no_such_parameter", 0.5, 1000.0)
    check(str(no_such["state"]) == FamilySet.OUTSIDE
                    and str(no_such["why"]).contains("no legal range"),
            "an undeclared parameter was absorbed into the uncertainty case: %s" % str(no_such))

    # TODAY'S SOURCE DECLARES NOTHING, and that is stated rather than assumed:
    # `phenology_for` clamps, so it cannot leave the envelope and has no
    # uncertainty against it. The line moves when the row is wired.
    # BOUND TO THE SHIPPED FIXTURE, not left on the default. An unbound scatter
    # reports the stand-in whatever any fixture carries, so this check could not
    # have failed -- it would have read 0.0 the day the row landed and gone on
    # saying the envelope was unexercised.
    var sc := VegetationScatter.new()
    sc.bind(null, null, fixture(), null, null, null)
    var live_window: String = fixture().windows[0]
    # LIVE ON REAL DATA SINCE 31efcab, which is what the old message asked for.
    check(sc.phenology_uncertainty(live_window) == u,
            "the shipped fixture carries the row and declares an uncertainty of %s rather "
                    % String.num(sc.phenology_uncertainty(live_window), 4)
            + "than the row's %s, so the envelope's third outcome is not armed on real data"
                    % String.num(u, 4))
    print("phenology: envelope [%s, %s], row uncertainty %s, this build declares %s"
            % [String.num(float(r["min"]), 3), String.num(hi, 3), String.num(u, 3),
               String.num(sc.phenology_uncertainty(live_window), 3)])


func test_a_published_scalar_is_read_from_its_bits_and_never_from_its_decimal() -> void:
    """Godot cannot read a small decimal back. Measured here rather than cited:
    every subnormal decimal parses to exactly 0.0, and a plain decimal is exact
    through seventeen digits after the point and degrades from the eighteenth,
    reaching 35% by 1e-17. So an artefact publishes the pattern, and a reader
    that falls back to the decimal has undone the publishing -- in exactly the
    case the publishing exists for, because small is when the decimal is wrong.

    THE SUBJECT IS LIVE IN THE FIXTURE IN HAND. `node.streamflow` publishes
    `min_nonzero_magnitude: 5e-324`, and that is what this engine does with it."""
    # THE READER, on patterns whose values are known exactly.
    check(PublishedBits.of_hex("0x0000000000000001") != 0.0,
            "the bottom denormal did not survive its pattern")
    check(PublishedBits.of_hex("3ff0000000000000") == 1.0,
            "1.0 did not come back from its pattern")
    check(PublishedBits.of_hex("0000000000000000") == 0.0, "zero did not come back")
    check(PublishedBits.to_hex(PublishedBits.of_hex("0x000001a96de74c92"))
                    == "0x000001a96de74c92",
            "a pattern did not survive a round trip through the reader")
    # A SHORT PATTERN IS REFUSED RATHER THAN PADDED. "0x1" padded is the bottom
    # denormal and "0x1" truncated is whatever survived the truncation, and
    # nothing downstream can tell those apart.
    for bad in ["0x1", "", "not hex at all", "0x000000000000000g", "0x00000000000000001"]:
        check(is_nan(PublishedBits.of_hex(bad)),
                "'%s' was read as a number rather than refused" % bad)

    # ALL THREE PUBLISHED FORMS, because there are three and the dispatch that
    # asked which to settle on counted two. The nested pair and the `_bits`
    # suffix are the two it named; `origin_hex` in the rows' parent block is a
    # third, from the same amendment as the first.
    var nested := {"d_m": {"dec": -0.062078866473279655, "hex": "0xbfafc8cd1a8d0ca1"}}
    var flat_bits := {"min_nonzero_magnitude": 9.02759206434e-312,
            "min_nonzero_bits": "0x000001a96de74c92"}
    var flat_hex := {"origin": [-1809292.9365744274, 2356726.304046243],
            "origin_hex": ["0xc13b9b8cefc35778", "0x4141fafb26eafcbf"]}
    check(PublishedBits.to_hex(PublishedBits.of(nested, "d_m")) == "0xbfafc8cd1a8d0ca1",
            "the nested form did not read back")
    # AND THIS IS THE ONE THAT FAILED WHEN IT WAS WRITTEN AS `of(...)`. The
    # value is `min_nonzero_magnitude`; the pattern is `min_nonzero_bits`. A
    # reader following the obvious rule looks for `min_nonzero_magnitude_bits`,
    # finds nothing and returns NAN -- on a value that is published. The flat
    # form's sibling name is not derivable, so it is named rather than derived.
    check(is_nan(PublishedBits.of(flat_bits, "min_nonzero_magnitude")),
            "the derived sibling name found something, so the pairing is predictable after "
            + "all and this whole paragraph is wrong")
    check(PublishedBits.to_hex(PublishedBits.of_named(flat_bits, "min_nonzero_bits"))
                    == "0x000001a96de74c92",
            "the flat form did not read back from its stated key")
    check(PublishedBits.to_hex(
                    PublishedBits.of_named(flat_bits, FixtureLoader.MIN_NONZERO_BITS_KEY))
                    == "0x000001a96de74c92",
            "the key the loader will use is not the key the fixture publishes")
    check(PublishedBits.to_hex(PublishedBits.of_element(flat_hex, "origin", 1))
                    == "0x4141fafb26eafcbf",
            "the parallel-array form did not read back at index 1")
    for pair in [[nested, "d_m"], [flat_hex, "origin"]]:
        check(PublishedBits.is_protected(pair[0] as Dictionary, str(pair[1])),
                "%s read as naked" % str(pair[1]))
    # A PARALLEL ARRAY IS NOT A SCALAR, and asking for it as one must refuse
    # rather than hand back element zero: a caller that forgot the index would
    # be off by a whole axis instead of by an ulp, and a corner's two axes are
    # both plausible numbers.
    check(is_nan(PublishedBits.of(flat_hex, "origin")),
            "a parallel-array publication answered a scalar read")
    check(PublishedBits.why_absent(flat_hex, "origin").contains("of_element"),
            "the refusal does not say how to read it: %s"
            % PublishedBits.why_absent(flat_hex, "origin"))
    check(is_nan(PublishedBits.of_element(flat_hex, "origin", 7)),
            "an index past the end answered")

    # AND A BARE DECIMAL IS NAKED IN ALL THREE VOCABULARIES.
    var naked := {"amplitude_m_at_parent": 0.020196332177435345}
    check(not PublishedBits.is_protected(naked, "amplitude_m_at_parent"),
            "a bare decimal read as protected")
    check(is_nan(PublishedBits.of(naked, "amplitude_m_at_parent")),
            "a bare decimal was read as a number")
    check(PublishedBits.why_absent(naked, "amplitude_m_at_parent").contains("bare decimal"),
            "the refusal does not name the case")

    # THE LIVE PARENT BLOCK, which is the one this client actually refines from.
    var rows_f := FileAccess.open("res://assets/detail/detail_rows.json", FileAccess.READ)
    if rows_f != null:
        var rows: Dictionary = JSON.parse_string(rows_f.get_as_text())
        var parent: Dictionary = rows["parent"]
        check(PublishedBits.is_protected(parent, "origin"),
                "the detail lattice corner is published without a pattern, which decision 985 "
                + "spent three re-vendors establishing that it must not be")
        # THE CONTROL: the corner's DECIMAL does not read back to the corner, so
        # the protection is load-bearing rather than decorative.
        var from_bits := DetailField.scalar_element_of(parent, "origin", 0)
        var e0: Variant = (parent["origin"] as Array)[0]
        var from_decimal := float((e0 as Dictionary)["dec"]) if typeof(e0) == TYPE_DICTIONARY \
                else float(e0)
        check(from_bits != from_decimal,
                "the corner's decimal and its pattern now agree, so `origin_hex` is no longer "
                + "doing anything here and this check has stopped demonstrating why it exists")
        print("985 corner: pattern %s, decimal %s"
                % [PublishedBits.to_hex(from_bits), PublishedBits.to_hex(from_decimal)])
        # AND THE PARAMETER BLOCK BESIDE IT IS NOT PROTECTED AT ALL. Named
        # rather than counted: these are inputs to `d(x, y)`, so the two sides
        # evaluate the same function from different numbers and the conformance
        # tolerance absorbs it.
        var unprotected := PackedStringArray()
        for lf in (rows["landforms"] as Dictionary):
            var block: Dictionary = rows["landforms"][lf]
            for k in block:
                if str(k).begins_with("_") or typeof(block[k]) == TYPE_STRING:
                    continue
                if typeof(block[k]) == TYPE_DICTIONARY:
                    continue
                # AN INTEGER NEEDS NO PATTERN AND IS NOT COUNTED. This is the
                # one field outside the 45 this client reported and the 50 the
                # artefact asserts from its own structure: five landforms x ten
                # fields is 50, and `octaves_at_parent` is the tenth. It is a
                # count of octaves, exact in any parser, and wrapping it would
                # publish a pattern for a number that cannot be misread.
                var bare := float(block[k])
                if bare == floor(bare):
                    continue
                if not PublishedBits.is_protected(block, str(k)):
                    unprotected.append("%s.%s" % [lf, str(k)])
        print("985 rows: %d landform scalars published without a pattern" % unprotected.size())
        # INVERTED AT 31efcab, WHICH IS WHAT THE OLD MESSAGE ASKED FOR. Every
        # landform scalar now carries a pattern, so the assertion is that it
        # stays that way rather than that it has not happened yet.
        check(unprotected.is_empty(),
                "%d landform scalar(s) are published without a pattern: %s. They are inputs to "
                        % [unprotected.size(), str(Array(unprotected))]
                + "d(x, y), so the two sides would evaluate the same function from different "
                + "numbers with the conformance tolerance absorbing the difference.")

    # THE CONTROL, AND IT IS THE WHOLE ARGUMENT. The same value by both routes:
    # through its pattern it arrives, through its decimal it is gone.
    var subnormal := PublishedBits.of_hex("0x0000000000000001")
    check(subnormal != 0.0 and float(JSON.parse_string("5e-324")) == 0.0,
            "this engine now reads 5e-324 as a non-zero, so the reason this class exists "
            + "has changed and its header needs re-taking")

    # AND ON THE SHIPPED FIXTURE. The row publishes a decimal today and the bits
    # arrive with the re-vendor; NAN is the honest answer to a field that cannot
    # be read, and it is reported rather than substituted.
    var fl := fixture()
    var w := fl.windows[0]
    var wide := fl.unquantised_rows(w)
    if not wide.is_empty():
        var row: String = wide[0]
        var d: Dictionary = fl.manifest["client_form"]["rows"]["%s/%s" % [w, row]]
        var m := fl.min_nonzero_of(w, row)
        if d.has(FixtureLoader.MIN_NONZERO_BITS_KEY):
            check(not is_nan(m), "the fixture publishes the pattern and the reader refused it")
            check(m != 0.0, "the published minimum non-zero magnitude read back as zero")
            print("min_nonzero: %s reads %s from its pattern" % [row, PublishedBits.to_hex(m)])
        else:
            check(is_nan(m),
                    "%s publishes no pattern in `client_form` and the reader answered %s "
                    % [row, str(m)] + "anyway -- it fell back to the decimal, which is the one "
                    + "thing it must not do")

            # AND THE PATTERN EXISTS, IN A DIFFERENT BLOCK, FOR A DIFFERENT
            # NUMBER. 31efcab put `min_nonzero_bits` under `windows/<w>/series/`
            # and not under `client_form/rows/`, and the two blocks do not hold
            # the same value: `series` is measured on the float64 array the
            # replay produced, `client_form` on the row as it is actually
            # stored. Measured here, exactly:
            #
            #     client_form  4.4166631708114284e-36
            #     series       4.416663345104293e-36
            #     client_form == float32(series)   -- exactly, bit for bit
            #
            # So this is not a missing pattern on one number. It is a pattern
            # published for the PRE-narrowing measurement while the block that
            # describes the shipped bytes carries a bare decimal. A reader that
            # took the series bits as this row's minimum would be off by the
            # narrowing and would think it had read them carefully.
            var series: Dictionary = (fl.manifest.get("windows", {}) as Dictionary) \
                    .get(w, {}).get("series", {}).get(row, {})
            if series.has(FixtureLoader.MIN_NONZERO_BITS_KEY):
                var pre := PublishedBits.of_named(series, FixtureLoader.MIN_NONZERO_BITS_KEY)
                var post := float(d.get("min_nonzero_magnitude", NAN))
                check(pre != post,
                        "the two blocks now agree at %s, so the narrowing this check describes "
                                % PublishedBits.to_hex(pre)
                        + "has stopped happening and the paragraph above needs re-taking")
                check(PackedFloat32Array([pre])[0] == PackedFloat32Array([post])[0],
                        "client_form's %s and series's %s do not agree even at float32, so the "
                                % [PublishedBits.to_hex(post), PublishedBits.to_hex(pre)]
                        + "two blocks differ for some reason other than the narrowing")
                # AND THE COST OF THAT BLOCK CARRYING NO PATTERN, MEASURED. The
                # correct narrowed value is 0x38977ba680000000. This engine
                # reads the decimal beside it as 0x38977ba680000001 -- one ulp
                # out, and not a float32-representable number at all, so the
                # value cannot even be recognised as the narrowed one. It
                # survives only because nothing here needs it to better than
                # float32.
                check(post != float(PackedFloat32Array([pre])[0]),
                        "this engine now reads client_form's decimal to exactly the narrowed "
                        + "value, so the argument for putting a pattern in that block has "
                        + "changed and this paragraph needs re-taking")
                print("min_nonzero: %s -- series %s (pre-narrowing, with bits), client_form %s "
                        % [row, PublishedBits.to_hex(pre), PublishedBits.to_hex(post)]
                        + "(the stored bytes, decimal only)")
            else:
                print("min_nonzero: %s publishes a decimal only, in both blocks" % row)


func test_the_wide_branch_has_a_witness_that_is_not_the_fixture() -> void:
    """`day_values` decodes a declared-wide row by a different path from a
    quantised one, and today exactly one shipped row takes that path. The
    emitting side narrows a row when its values stop needing the width, so the
    fixture can stop carrying a wide row at any build -- and then the branch
    goes untested while every test still passes, until some later row is
    shipped wide and lands on a path nothing has run in months.

    So the branch gets a witness the fixture cannot take away: a two-cell row
    written here, declared float64, holding the bottom denormal and a value
    that only float64 can separate from it. Read back through the real loader,
    not through a reimplementation of it -- a second decoder would be free to
    agree with itself while disagreeing with the one that runs."""
    var dir := "user://wide_witness/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
    # BOTH VALUES COME FROM BITS. A subnormal written as a decimal literal is
    # 0.0 by the time the parser is done with it -- see the note in
    # `test_the_series_keeps_what_float32_would_flush_to_zero` -- so a witness
    # built from `5e-324` would be two zeros agreeing with each other, which is
    # the exact failure it is here to rule out.
    var tiny := _f64("0x0000000000000001")
    var near := _f64("0x0000000000100000")
    check(tiny != 0.0 and near != 0.0 and tiny != near,
            "the witness values did not survive construction: %s, %s"
            % [_bits(tiny), _bits(near)])
    var bin := PackedByteArray()
    bin.resize(16)
    bin.encode_double(0, tiny)
    bin.encode_double(8, near)
    var bf := FileAccess.open(dir + "wide_witness.bin", FileAccess.WRITE)
    check(bf != null, "could not write the witness bin")
    if bf == null:
        return
    bf.store_buffer(bin)
    bf.close()
    # Shaped exactly as the loader reads a manifest -- `file`, and every row
    # descriptor carrying its own `window` and `row`. Getting this wrong is how
    # the first cut failed: `row_names` found nothing, so `unquantised_rows`
    # returned empty and the failure read as the width lookup being broken.
    var manifest := {
        "client_form": {
            "file": "wide_witness.bin",
            "rows": {"w/probe.row": {
                "window": "w", "row": "probe.row",
                "shape": [1, 2], "dtype": "float64 little-endian",
                "byte_offset": 0, "lattice": "node", "lo": 0.0, "hi": 1.0}},
        },
        "windows": ["w"],
        "cell_keys": {"pairs": [["w", 0], ["w", 1]]},
    }
    var mf := FileAccess.open(dir + "fixture_client.json", FileAccess.WRITE)
    mf.store_string(JSON.stringify(manifest))
    mf.close()

    var fl := FixtureLoader.load_from(dir)
    check(fl.dtype_of("w", "probe.row").begins_with("float64"),
            "the loader did not read the declared width back: %s"
            % fl.dtype_of("w", "probe.row"))
    check(Array(fl.unquantised_rows("w")) == ["probe.row"],
            "the wide row was not found by width: %s" % str(fl.unquantised_rows("w")))
    var got := fl.day_values("w", "probe.row", 0)
    check(got.size() == 2, "the witness row decoded to %d cells" % got.size())
    if got.size() != 2:
        return
    check(got[0] == tiny, "the bottom denormal came back as %s" % _bits(got[0]))
    check(got[1] == near, "the second denormal came back as %s" % _bits(got[1]))
    # THE CONTROL. Both values exist and are distinct only in float64; through
    # the narrow container they are the same number, and that number is zero.
    # Without this the check above would pass on a decoder that had lost them.
    var narrowed := PackedFloat32Array([got[0], got[1]])
    check(narrowed[0] == 0.0 and narrowed[1] == 0.0,
            "float32 no longer flushes these, so the witness is not witnessing")
    check(got[0] != got[1], "the two witness values are not distinct in float64")
    print("wide branch: witnessed off-fixture, %s and %s distinct in float64 and "
            % [_bits(got[0]), _bits(got[1])] + "both zero in float32")


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

    # AND THE FOURTH STATE, WHICH THIS FILE WAS DRAWING AS THE FIRST.
    # `colour_for(NAN)` returned NO_FLOW: a reach nothing was known about was
    # drawn as a channel with no water in it, in a file whose whole subject is
    # not doing that. Harmless against a fixture that answers for every node;
    # the plausible-zero in its purest form against a producer that withholds.
    var unknown := d.colour_for_absence(FlowDisplay.NOT_KEYED)
    check(not unknown.is_equal_approx(zero),
            "nothing-known and no-water render identically, which is the plausible zero this "
            + "display exists to avoid")
    check(not unknown.is_equal_approx(mid), "nothing-known renders as a value on the ramp")
    check(d.colour_for(NAN).is_equal_approx(unknown),
            "a NAN value renders as something other than nothing-known")
    # THREE REASONS, COUNTED APART. One colour is a display decision; one count
    # would lose the only distinction that matters later -- a defect in the
    # map, the percept working, and the world.
    d.colour_for_absence(FlowDisplay.NO_NODE)
    check(d.n_not_keyed == 1 and d.n_no_node == 1 and d.n_nodata == 1,
            "the three ways of knowing nothing are not counted apart: %s"
            % str(d.describe()["counts"]))


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


## The shape the dispatch published, with a clean 18-of-18 proof beside a
## declared staleness -- both true at once, which is the case the fifth state
## exists for.
func _declared_stale_manifest() -> Dictionary:
    return {"run": {"base_commit": "6421064b2450bc448e457e0cc099249a2e77a65a",
            "acceptance": {"scored_at_commit": "5317027", "scored_run_dir": "m0-instrumented-001",
                    "passed": 7, "failed": 5, "not_evaluable": 0,
                    "failed_criteria": [{"id": 1, "name": "snowpack",
                            "renders_as": "a near-bare snowpack overlay"}],
                    "equivalence": {"to_commit": "6421064", "fields_compared": 18,
                            "fields_matching": 18},
                    "stale_against_replay": {
                            "replayed_at_commit": "b9287f1",
                            "declared_by_the_operator": "the melt gate and swe_50's per-band "
                                    + "build landed after scoring; the criteria this verdict "
                                    + "fails are still the criteria it fails",
                            "what_the_equivalence_proof_below_does_not_cover":
                                    "the code the payload was stepped forward at"}}}}


func _declared_stale_verdict() -> AncestorVerdict:
    return AncestorVerdict.read_from(_declared_stale_manifest())


func test_a_verdict_stale_against_its_replay_is_not_absorbed_into_equivalent() -> void:
    """`equivalence` proves the verdict's RUN is this fixture's run. That is a
    statement about state, and a replayed payload is stepped forward at today's
    code, so a verdict can hold a clean 18-of-18 and still describe a snowpack
    the drawn data no longer has. Nothing compared the code, so the reader saw
    18/18, reported EQUIVALENT, and the staleness sat one key away unread.

    TWO AXES, NOT ONE ENUM. The proof still holds and is not thrown away:
    `underlying_state` keeps it while `state` carries the staleness. The point
    of the exercise is that both readings survive, because "the run really is
    this run AND the verdict does not describe what is drawn" is the whole
    content of the case."""
    var m := _declared_stale_manifest()
    var v := AncestorVerdict.read_from(m)
    check(v.state == AncestorVerdict.DECLARED_STALE,
            "a declared-stale verdict read as %s" % v.state)
    check(v.underlying_state == AncestorVerdict.EQUIVALENT,
            "the equivalence proof was thrown away by the staleness: underlying is %s"
            % v.underlying_state)

    # THE CONTROL, which is the half that shows the mechanism acting. The same
    # manifest without the declaration is the old reading exactly -- so the new
    # state is keyed on the block and not on anything that moved beside it.
    var without := _declared_stale_manifest()
    without["run"]["acceptance"].erase("stale_against_replay")
    var w := AncestorVerdict.read_from(without)
    check(w.state == AncestorVerdict.EQUIVALENT,
            "the same verdict without the declaration read as %s, so the new state is not "
            % w.state + "keyed on the declaration")
    check(w.staleness_lines().is_empty(),
            "a verdict with no declaration offered staleness lines")

    # LOUDER THAN EQUIVALENT AND QUIETER THAN A FAILED PROOF, in the words a
    # person actually sees rather than in the constant's spelling.
    check(v.headline().contains("DECLARED STALE"),
            "the headline does not say the verdict is stale: %s" % v.headline())
    check(not v.headline().contains("does not check out"),
            "a declared staleness reads as a failed proof, which is louder than it should be: %s"
            % v.headline())
    check(v.headline().contains("7 pass / 5 fail"),
            "the score stopped being stated, and it is still a real score: %s" % v.headline())
    check(v.headline().contains("b9287f1"),
            "the headline does not say what the payload was replayed at: %s" % v.headline())

    # THE REASON TRAVELS WITH THE NUMBER. That is the entire justification for
    # shipping a stale verdict rather than dropping it, so a reader who cannot
    # see the reason has been given the disclaimer without the grounds for it.
    var lines := v.staleness_lines()
    check(lines.size() == 2, "expected the declaration and the proof's limit, got %s"
            % str(lines))
    check(lines[0].contains("the melt gate"),
            "the operator's own reason did not survive the read: %s" % lines[0])
    check(lines[1].contains("stepped forward"),
            "what the proof does not cover was dropped: %s" % lines[1])
    check(v.why.contains("the melt gate"),
            "the reason does not reach `why`, which is what main.gd warns with: %s" % v.why)

    # A DECLARATION IS CHECKED, NOT BELIEVED -- the same discipline the proof
    # gets, because it is the same kind of claim. Each of these is a block that
    # looks like a declaration and cannot be read as one, and all fall back to
    # STALE: the fixture is asserting something about itself that does not hold
    # together, which is worse than declaring nothing.
    var unreadable := {
        "carries no operator reason": {"replayed_at_commit": "b9287f1"},
        "names no replay commit": {"declared_by_the_operator": "because"},
        "declares staleness against the commit it was scored at": {
                "replayed_at_commit": "5317027", "declared_by_the_operator": "because"},
        "offers an empty reason": {"replayed_at_commit": "b9287f1",
                "declared_by_the_operator": ""},
    }
    for label in unreadable:
        var bad_m := _declared_stale_manifest()
        bad_m["run"]["acceptance"]["stale_against_replay"] = unreadable[label]
        var bad := AncestorVerdict.read_from(bad_m)
        check(bad.state == AncestorVerdict.STALE,
                "a declaration that %s read as %s rather than stale" % [label, bad.state])
        check(bad.why.contains("cannot be read"),
                "an unreadable declaration does not say so: %s" % bad.why)

    # A FAILED PROOF STAYS THE LOUDER FINDING. A fixture whose equivalence does
    # not check out and which also declares a staleness must report the broken
    # proof: the declaration is the thing somebody remembered to write down,
    # and burying a failure under it is how the failure stops being read.
    var both := _declared_stale_manifest()
    both["run"]["acceptance"]["equivalence"]["fields_matching"] = 17
    var b := AncestorVerdict.read_from(both)
    check(b.state == AncestorVerdict.STALE,
            "a broken proof beside a declared staleness read as %s" % b.state)
    check(b.headline().contains("does not check out"),
            "the broken proof was buried under the declaration: %s" % b.headline())

    # AND IT APPLIES OVER A SCORED VERDICT TOO, not only over an equivalence.
    # The replay axis is independent of the state axis: a verdict scored on
    # this very run is just as stale if the payload was stepped forward.
    var same_run := _declared_stale_manifest()
    same_run["run"]["acceptance"]["scored_at_commit"] = "6421064"
    same_run["run"]["acceptance"].erase("equivalence")
    var sr := AncestorVerdict.read_from(same_run)
    check(sr.state == AncestorVerdict.DECLARED_STALE,
            "a scored-on-this-run verdict declared stale read as %s" % sr.state)
    check(sr.underlying_state == AncestorVerdict.SCORED,
            "the underlying state was lost: %s" % sr.underlying_state)

    # THE FIXTURE IN HAND CARRIES NO DECLARATION, and the check says so rather
    # than assuming it. When the re-vendor lands this line moves, and it moving
    # is the notice that the new state has a real subject.
    var live := AncestorVerdict.read_from(fixture().manifest)
    print("verdict: shipped fixture reads %s (underlying %s), declaration %s"
            % [live.state, live.underlying_state,
               "absent" if live.stale_against_replay.is_empty() else "present"])


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
    float32 flushes everything under 1.18e-38 to zero, which moves samples out
    of "below the display scale" and into "no flow" -- two different statements
    about the river (§23.812).

    Proved against the container rather than argued: the same value is put
    through a PackedFloat32Array here and comes back as zero.

    IN TWO HALVES, BECAUSE ONLY ONE OF THEM IS THE FIXTURE'S BUSINESS. The plot
    can mis-classify a sub-float32 sample whether or not any shipped row
    currently holds one, so that half runs off a value chosen here. The other
    half needs a real row and finds it by declared width; when the fixture has
    none it says so, because a row narrowed upstream is a fact about the run and
    not a loss in transit."""
    # THE CLASSIFICATION HALF DOES NOT DEPEND ON THE FIXTURE. It is a property
    # of the plot, so it is asserted on a value chosen here: a fixture that
    # stops carrying sub-float32 values would otherwise take this check with it
    # while the plot's ability to mis-classify one stayed exactly where it was.
    # FROM BITS, NOT FROM A DECIMAL LITERAL. `5e-324` written here compiles to
    # exactly 0.0 -- Godot flushes EVERY subnormal decimal to zero, in the
    # source lexer and in the JSON parser alike, and not only at the bottom of
    # the range: `1e-310` goes the same way. Measured, because the first cut of
    # this check was written as a literal and passed its float32 comparison for
    # the wrong reason while `band_of` correctly classified the zero it had
    # actually been handed. The values this plot exists to keep apart cannot be
    # written down in this language; they reach the client as raw bytes in the
    # bin or they do not reach it.
    var floor_probe := _f64("0x0000000000000001")
    check(floor_probe != 0.0, "the bottom denormal did not survive its own construction")
    check(PackedFloat32Array([floor_probe])[0] == 0.0,
            "float32 no longer flushes %s -- this test is not testing what it says"
            % String.num_scientific(floor_probe))
    check(SeriesPlot.band_of(floor_probe) == SeriesPlot.BELOW,
            "a value below the scale is not classified as below it")
    check(SeriesPlot.band_of(0.0) == SeriesPlot.ZERO,
            "the flushed value is not classified as no flow, so the loss would be silent")

    # THE ARTEFACT HALF asks the fixture for a witness by width rather than by
    # name, and says so when it has none instead of reading its absence as the
    # reader having lost something.
    var fl := fixture()
    var wide := fl.unquantised_rows("deepest_winter")
    if wide.is_empty():
        print("series: no wide row in deepest_winter -- the read path is unwitnessed here")
        return
    var row := wide[0]
    var vals := fl.day_values("deepest_winter", row, 45)
    var axis := -1
    var tiny := 0.0
    for i in vals.size():
        if vals[i] != 0.0 and vals[i] < 1.18e-38:
            axis = i
            tiny = vals[i]
            break
    if axis < 0:
        print("series: %s carries nothing below float32's floor on day 45" % row)
        return

    var series := SeriesPlot.series_for(fl, "deepest_winter", row, axis)
    check(series is PackedFloat64Array, "the series is not a PackedFloat64Array")
    check(series.size() == fl.days("deepest_winter", row),
            "the series is %d days and the row holds %d"
            % [series.size(), fl.days("deepest_winter", row)])
    check(series[45] == tiny,
            "day 45 of the series is %s and the row holds %s"
            % [String.num_scientific(series[45]), String.num_scientific(tiny)])
    var survived := 0
    for v in series:
        if v != 0.0 and v < 1.18e-38:
            survived += 1
    check(survived > 0, "no sub-float32 value survived the series read")
    print("series: %s axis %d, %d of %d days below float32's floor and not zero"
            % [row, axis, survived, series.size()])


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


func test_no_family_is_keyed_below_life_form_off_the_wire() -> void:
    """Palettes are off the wire (decision 894) and the fixture aggregates to
    life form (872, 889), so a per-PFT or per-AFT mesh set has no key it could
    legally be indexed by OFF THE WIRE -- and a size-baked form token is wrong
    rather than imprecise on most of a palette (§23.302, decision 180).

    THE RULE IS NARROWED HERE RATHER THAN REPEALED, and the distinction is the
    whole of B6. What the wire cannot key, it still cannot key: `families` must
    equal the wire's group count and nothing indexes off the fixture below it.
    What changed is that a key can arrive from somewhere else -- a producer's
    refinement carries a taxon node, and the node IS the key. So `specific` is
    allowed to exist and is held to the same parameter rule: authored form,
    computed individual, no baked size anywhere.

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
    # is parameters (§17.8.2). THE SAME RULE APPLIES TO A SPECIFIC NODE -- it
    # is a named taxon, which is exactly where the temptation to bake a height
    # lives, and a producer sending a node is not a producer sending a size.
    for entry_name in Array(fs.life_forms()) + Array(fs.nodes()):
        var entry: Dictionary = fs.families.get(entry_name, fs.specific.get(entry_name, {}))
        for forbidden in ["height", "size", "scale", "species", "pft", "aft"]:
            for k in entry:
                check(not str(k).to_lower().contains(forbidden),
                        "family %s carries a baked %s" % [str(entry_name), forbidden])
    # And `keyed_by` has to state the narrowed rule, not the old absolute one:
    # a reader meeting only the old sentence would delete `specific` as illegal.
    check(str(fs.manifest.get("keyed_by", {}).get("and_below", "")).contains("refinement"),
            "the manifest does not say a taxon node may key an asset where a producer sends "
            + "one, so the rule reads as forbidding what B6 does")


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
    var budget := fc.instances_within_budget(fs.triangles_of("tree"),
            VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS)
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
    # Decision 951 on a real build: the head this scatter solved for is what
    # the CORRECTED budget holds, not what the empty stage would.
    var spent_ms := float(budget["instances"]) * float(budget["mean_ns_per_instance"]) / 1.0e6
    check(absf(spent_ms - float(budget["budget_ms_effective"])) < 0.01,
            "the affordable head spends %s ms and the effective budget is %s ms"
            % [String.num(spent_ms, 3), String.num(float(budget["budget_ms_effective"]), 3)])
    check(absf(float(budget["budget_ms_effective"])
                    * VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS
                    - float(budget["budget_ms"])) < 1.0e-6,
            "the effective budget is not the nominal one divided by the multiplier")
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
    for v in [none, scored, eq, stale, _declared_stale_verdict()]:
        banner.show_verdict(v)
        check(banner._headline.text == v.headline(),
                "the banner did not render the %s headline" % v.state)
        check(banner._headline.text.length() > 20,
                "the %s banner is nearly empty, which reads as nothing to declare" % v.state)
    banner.show_verdict(eq)
    check(banner._fails.visible and banner._fails.text.contains("excluded"),
            "the banner drops the equivalence proof's exclusions: %s" % banner._fails.text)
    # THE OPERATOR'S REASON REACHES THE PICTURE, which is the whole content of
    # the declaration. A banner that says DECLARED STALE and not why has moved
    # the problem from the manifest to the screenshot rather than solving it.
    var ds := _declared_stale_verdict()
    banner.show_verdict(ds)
    check(banner._fails.visible and banner._fails.text.contains("the melt gate"),
            "the operator's declared reason did not reach the banner: %s" % banner._fails.text)
    check(banner._fails.text.find("declared by the operator")
                    < banner._fails.text.find("criterion 1"),
            "the staleness is printed below the fails it qualifies: %s" % banner._fails.text)
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
            AncestorVerdict.EQUIVALENT, AncestorVerdict.DECLARED_STALE,
            AncestorVerdict.STALE]:
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


func test_the_budget_solve_divides_by_the_floors_measured_multiplier() -> void:
    """DECISION 951, PINNED AT BOTH SOLVE SITES.

    `render_cost.json`'s per-instance coefficient is measured on an empty stage
    -- no terrain, no culling, no LOD -- so a budget spent against it is spent
    against a frame nobody plays. At the basin's densest cells the thinning was
    already engaged, one cell drawing 6.8% of its implied stand, and the frame
    still measured 36 to 49 ms against a 33.3 ms budget: two of five drew
    everything, believing they fit, and did not.

    This test asserts the LIVE relationship, not the old disclosure. It was
    written when the correction was quoted and deliberately not applied, and
    §19.8.9 has since answered -- so what it checks now is that a solve divides
    by the multiplier, that the multiplier is the one `scatter_cost.json`
    measures, and that neither solve site can quietly answer the empty stage
    instead.
    """
    var fc := FrameCost.load_from()
    if fc.budget_ms > 0.0:
        var tri := family_set().triangles_of("tree")
        var corrected := fc.instances_within_budget(tri,
                VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS)
        var floor_only := fc.instances_within_budget(tri, 1.0)
        check(corrected > 0 and floor_only > corrected,
                "the corrected budget (%d) does not sit below the floor's own (%d), so the "
                        % [corrected, floor_only]
                + "multiplier is not being applied")
        check(absf(float(floor_only) / float(corrected)
                        - VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS) < 0.02,
                "floor/corrected is %sx and the multiplier is %sx"
                % [String.num(float(floor_only) / float(corrected), 3),
                        String.num(VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS, 2)])
        print("budget: %d trees at the floor, %d once decision 951 is applied"
                % [floor_only, corrected])

    var f := FileAccess.open("res://measurements/scatter_cost.json", FileAccess.READ)
    if f == null:
        check(false, "no scatter_cost.json to check the quoted ratio against")
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var ratio := float(((parsed as Dictionary).get("agreement", {}) as Dictionary).get(
            "ratio_observed_over_predicted", NAN))
    check(not is_nan(ratio), "scatter_cost.json records no observed/predicted ratio")
    if is_nan(ratio):
        return
    check(absf(ratio - VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS) < 0.15,
            "the scatter quotes the empty stage as under-predicting by %sx and the artefact "
            % String.num(VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS, 2)
            + "now measures %sx. The quoted figure is what a reader uses to know what the "
                    % String.num(ratio, 3)
            + "budget is worth, so it has to track the measurement it came from.")
    # PARENTHESISED, AND IT WAS NOT. `%` binds tighter than `+` in GDScript, so
    # the format was applied to "solve divides by it" alone -- a fragment with
    # no specifiers -- and the engine reported "not all arguments converted"
    # while the line printed its own format string. `verify.sh` greps for
    # `SCRIPT ERROR` and this is an `ERROR`, so it survived every green run.
    print(("budget: the empty stage under-predicts by %sx measured, %sx quoted, and the "
                    + "solve divides by it")
            % [String.num(ratio, 3), String.num(VegetationScatter.EMPTY_STAGE_UNDER_PREDICTS, 2)])


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


func test_placement_is_a_function_of_where_and_thins_by_a_stable_prefix() -> void:
    """THE PRIMITIVES UNDER THE PLACEMENT RULE, CHECKED SEPARATELY FROM A BUILD.

    Placement has to be a pure function of the ground, because the scatter is
    rebuilt around a camera that moves. Two properties carry that, and this
    checks both directly rather than inferring them from a picture:

      1. THE ORDER IS A PERMUTATION. `candidate_at(i, n, key)` for i in [0, n)
         has to hit every candidate exactly once. If it collided, a sub-cell
         would draw the same plant twice and be short one; if it missed, part
         of the stand would be unreachable at any share.
      2. THINNING IS A PREFIX, so the set at m-1 is the set at m minus one
         plant. That is what makes a falling share thin the stand and a rising
         one restore it, and it is the half of the fix a build test cannot see
         -- a build test can only compare two shares it happens to produce.

    AND THE HASH IS PINNED. `String.hash()` and `RandomNumberGenerator` are
    engine internals free to change between Godot versions, and a placement
    that moves on an engine update is the defect this scheme exists to remove.
    So the mixer is ours and its values are nailed down here.
    """
    # 1. pinned, so an engine or refactor change cannot move the basin's plants
    check(VegetationScatter.mix32(0) == 0, "mix32(0) moved")
    check(VegetationScatter.mix32(1) == 2261973619,
            "mix32(1) is %d, not 2261973619 -- the mixer changed, and with it every plant"
            % VegetationScatter.mix32(1))
    check(VegetationScatter.stable_hash([1, 2, 3]) == 3403123636,
            "stable_hash([1,2,3]) is %d, not 3403123636"
            % VegetationScatter.stable_hash([1, 2, 3]))
    check(VegetationScatter.stable_hash([3, 2, 1]) == 1313732382,
            "stable_hash is order-insensitive, so [x,y] and [y,x] are the same ground")
    check(VegetationScatter.family_key("grass") == 2993663101
                    and VegetationScatter.family_key("tree") == 1837839573,
            "family_key moved; the families would swap stands")

    # the 32-bit discipline: GDScript ints are 64-bit and signed, so a mixer
    # that overflowed would produce negatives -- and a negative hash is a
    # jitter outside its own sub-cell, which is a plant in the wrong place
    var left_32_bits := 0
    var not_a_fraction := 0
    for i in 512:
        var h := VegetationScatter.stable_hash([i, -i * 7919, i * 104729])
        if h < 0 or h > 0xFFFFFFFF:
            left_32_bits += 1
        var u := VegetationScatter.hash01(h)
        if u < 0.0 or u >= 1.0:
            not_a_fraction += 1
    check(left_32_bits == 0, "%d of 512 hashes left 32 bits; the mixer is overflowing"
            % left_32_bits)
    check(not_a_fraction == 0, "%d of 512 hashes did not read as a fraction of 1"
            % not_a_fraction)

    # 2. a permutation, at sizes that exercise every domain shape. One check
    # over all of them: this either holds everywhere or the scheme is broken.
    var not_a_permutation: Array = []
    var walk_overran: Array = []
    for n in [1, 2, 3, 5, 17, 64, 65, 1000, 4096, 4097]:
        var key := VegetationScatter.stable_hash([20260903, n, 11])
        var seen := {}
        var overrun := 0
        for i in n:
            var c := VegetationScatter.candidate_at(i, n, key)
            if c < 0:
                overrun += 1
            elif c < n:
                seen[c] = true
        if overrun > 0:
            walk_overran.append("%d at n=%d" % [overrun, n])
        if seen.size() != n:
            not_a_permutation.append("n=%d hit %d" % [n, seen.size()])
    check(walk_overran.is_empty(), "the cycle walk overran its limit: %s"
            % ", ".join(PackedStringArray(walk_overran)))
    check(not_a_permutation.is_empty(),
            "candidate_at is not a permutation (%s). A sub-cell would draw some plants twice "
                    % ", ".join(PackedStringArray(not_a_permutation))
            + "and never reach others.")

    # 3. the prefix nests, which is the whole of the thinning claim
    var pool := 777
    var nest_key := VegetationScatter.stable_hash([20260903, 4242, 7])
    var previous := {}
    var redrawn := 0
    for m in range(1, pool + 1):
        var c := VegetationScatter.candidate_at(m - 1, pool, nest_key)
        if previous.has(c):
            redrawn += 1
        previous[c] = true
    check(redrawn == 0,
            "growing the share re-drew %d of %d candidates instead of adding one at a time. "
                    % [redrawn, pool]
            + "Thinning that re-rolls is the churn this replaced.")


func test_two_builds_over_the_same_ground_place_the_same_plants() -> void:
    """THE END-TO-END HALF: what the primitives buy in a real build.

    The defect was measured, not theorised. One 21.8 m dolly step with the
    scatter rebuilt around the camera replaced 33,117 of 36,081 instances and
    kept EIGHT (`measurements/scatter_motion.json`, and the finding it records).
    The cause was a single random stream seeded per build and consumed in the
    order the disc was scanned, so the disc's own extent renumbered every
    position inside it.

    So: build the same day at the same place twice, at two radii, and require
    the inner disc to hold the SAME PLANTS. Under the old rule the larger build
    scans more ground before reaching the middle and every position in the
    middle moves. The comparison is the report's XOR digest, because instance
    transforms cannot be read back under the dummy renderer -- the digest is
    order-independent for exactly this reason, since the two builds do not
    visit the shared ground in the same order.

    THE FRAME BUDGET IS OFF ON PURPOSE. A larger radius implies more plants and
    therefore a smaller share, and a smaller share draws FEWER plants in the
    middle -- correctly, and it would still be a subset. This test is about
    whether they are the same plants, so it removes the one variable that
    changes how many.
    """
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    var bound := v.bind_families()
    check(bool(bound["ok"]), "families did not bind: %s" % str(bound.get("why", "")))
    check(v.show_field("deepest_winter", "band.pft_fractions", 22), "the field did not paint")

    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    # ABOVE THE SHIPPED CEILING ON PURPOSE. The ceiling bounds what a frame
    # spends building; this build is neither a frame nor shipped, and letting
    # it bind would thin the larger disc and make this a comparison of a stand
    # against a sample of one.
    var head := 400000

    # ONE SPARSE FAMILY, so the whole implied stand fits under the build
    # ceiling and both shares are 1.0. Grass alone runs to millions inside
    # 800 m; two builds of it would be two samples at two different shares,
    # and a subset is not what this test can compare.
    var small := v.scatter_at(centre, 1800.0, VegetationScatter.NO_SCHEDULE, head, 0.0,
            "tree", false)
    # the same ground, reached across a disc of twice the area and one more
    # ring of texels, so the scan order through the middle is not the same
    var large := v.scatter_at(centre, 2600.0, VegetationScatter.NO_SCHEDULE, head, 0.0,
            "tree", false)
    if not bool(small.get("ok", false)) or not bool(large.get("ok", false)):
        check(false, "a scatter did not build: %s / %s"
                % [str(small.get("why", "")), str(large.get("why", ""))])
        v.queue_free()
        return

    check(float(small["share_drawn"]) == 1.0 and float(large["share_drawn"]) == 1.0,
            "a share below 1 (%s / %s) makes this a comparison of two samples rather than "
                    % [String.num(float(small["share_drawn"]), 4),
                            String.num(float(large["share_drawn"]), 4)]
            + "of two stands, and the test cannot mean what it says")

    var a: Dictionary = small["placement"]
    var b: Dictionary = large["placement"]
    check(int(a["walk_overruns"]) == 0 and int(b["walk_overruns"]) == 0,
            "the candidate permutation overran its cycle-walk limit, which drops plants")

    var a_d: Dictionary = a["digest"]
    var a_n: Dictionary = a["digest_instances"]
    var b_d: Dictionary = b["digest"]
    var b_n: Dictionary = b["digest_instances"]
    # 1,000 m, because a texel is a kilometre and an instance sits up to 707 m
    # from its texel's centre: both builds scanned every texel that could put a
    # plant inside this ring, and the 2,000 m ring is one only the larger did.
    var ring := "1000"
    check(int(a_n[ring]) > 200,
            "only %d instances landed inside %s m; too few for this to prove anything"
            % [int(a_n[ring]), ring])
    check(int(a_n[ring]) == int(b_n[ring]),
            "the %s m disc holds %d plants in the small build and %d in the large one. The "
                    % [ring, int(a_n[ring]), int(b_n[ring])]
            + "same ground on the same day has to imply the same number.")
    check(int(a_d[ring]) == int(b_d[ring]),
            "the plants inside %s m are in DIFFERENT PLACES depending on how much ground was "
                    % ring
            + "scanned around them (digest %d against %d). Placement has gone back to "
                    % [int(a_d[ring]), int(b_d[ring])]
            + "depending on visit order, which is the churn measured in scatter_motion.json.")
    print("placement: %d plants within 1,000 m, digest %d, identical whether the build "
            % [int(a_n[ring]), int(a_d[ring])]
            + "reached them across 1,800 m or 2,600 m")

    # AND AGAIN THROUGH THE OTHER BRANCH. With no horizon rule and no schedule
    # the texel is not subdivided at all; with one, every texel becomes 32x32
    # sub-cells and placement runs on a different grid with a different key.
    # The path the seam work actually uses is the second one, so testing only
    # the first would leave the shipped path unchecked.
    var k := 0.35 * VegetationScatter.resolution_k(400.0, 75.0)
    var small_k := v.scatter_at(centre, 1800.0, VegetationScatter.NO_SCHEDULE, head, k,
            "tree", false)
    var large_k := v.scatter_at(centre, 2600.0, VegetationScatter.NO_SCHEDULE, head, k,
            "tree", false)
    if bool(small_k.get("ok", false)) and bool(large_k.get("ok", false)):
        var ka: Dictionary = small_k["placement"]
        var kb: Dictionary = large_k["placement"]
        var kn_a: Dictionary = ka["digest_instances"]
        var kn_b: Dictionary = kb["digest_instances"]
        var kd_a: Dictionary = ka["digest"]
        var kd_b: Dictionary = kb["digest"]
        # The horizon is measured from the build centre, so the two builds cut
        # the same ground only where BOTH reach -- 500 m, well inside the
        # smaller build's own tree horizon at this k.
        var kring := "500"
        check(int(kn_a[kring]) > 200,
                "only %d instances landed inside %s m under the horizon rule"
                % [int(kn_a[kring]), kring])
        check(int(kn_a[kring]) == int(kn_b[kring]) and int(kd_a[kring]) == int(kd_b[kring]),
                "under the horizon rule the %s m disc holds %d/%d plants at digest %d/%d. "
                        % [kring, int(kn_a[kring]), int(kn_b[kring]),
                                int(kd_a[kring]), int(kd_b[kring])]
                + "The subdivided path is the one the seam work uses, and it has gone back to "
                + "depending on how much ground was scanned around it.")
    else:
        check(false, "the horizon-rule builds did not complete: %s / %s"
                % [str(small_k.get("why", "")), str(large_k.get("why", ""))])

    # AND THE DEFECT ITSELF: RE-CENTRING. Everything above changes how much
    # ground was scanned and leaves the centre alone. What was measured in
    # scatter_motion.json was a camera that MOVED, and no ring measured from a
    # build's own centre can compare two builds around two cameras. The texel
    # can: it is ground, so whichever build reaches it, it holds the same
    # plants -- and a texel both builds covered whole must agree exactly.
    var moved := v.scatter_at(centre + Vector2(21.8, 13.1), 1800.0,
            VegetationScatter.NO_SCHEDULE, head, 0.0, "tree", false)
    if not bool(moved.get("ok", false)):
        check(false, "the re-centred build did not complete: %s" % str(moved.get("why", "")))
        v.queue_free()
        return
    var here: Dictionary = (small["placement"] as Dictionary)["digest_by_texel"]
    var there: Dictionary = (moved["placement"] as Dictionary)["digest_by_texel"]
    var shared := 0
    var disagreed: Array = []
    for tkey in here:
        if not there.has(tkey):
            continue
        var one: Array = here[tkey]
        var two: Array = there[tkey]
        # Only texels BOTH builds covered whole are comparable; a texel the
        # disc clipped in one of them correctly holds fewer plants.
        if int(one[1]) != int(two[1]):
            continue
        shared += 1
        if int(one[0]) != int(two[0]):
            disagreed.append(str(tkey))
    check(shared >= 4,
            "only %d texels were covered whole by both builds; a 25 m step should leave most "
                    % shared
            + "of an 1,800 m disc in common, so this test is not exercising re-centring")
    check(disagreed.is_empty(),
            "%d of %d texels hold the same NUMBER of plants in both builds and put them in "
                    % [disagreed.size(), shared]
            + "DIFFERENT PLACES (%s). Moving the camera 25 m re-drew the stand, which is the "
                    % ", ".join(PackedStringArray(disagreed))
            + "defect scatter_motion.json measured: 36,081 instances, eight survivors.")
    print("placement: %d texels held plant for plant across a 25 m re-centring" % shared)

    # ONCE MORE THROUGH THE SUBDIVIDED PATH, which is the one that draws the
    # seam. A schedule that keeps everything forces the 32x32 sub-grid without
    # the horizon removing any of it, so both builds hold whole texels and the
    # counts are comparable -- which they are not under a horizon rule, because
    # the cut is measured from the camera and correctly takes different
    # sub-cells at different places.
    var all_kept: Array = [{"to_m": 1.0e9, "keep": 1.0}]
    var sub_a := v.scatter_at(centre, 1800.0, all_kept, head, 0.0, "tree", false)
    var sub_b := v.scatter_at(centre + Vector2(21.8, 13.1), 1800.0, all_kept, head, 0.0,
            "tree", false)
    if bool(sub_a.get("ok", false)) and bool(sub_b.get("ok", false)):
        var sa: Dictionary = (sub_a["placement"] as Dictionary)["digest_by_texel"]
        var sb: Dictionary = (sub_b["placement"] as Dictionary)["digest_by_texel"]
        var sub_shared := 0
        var sub_bad: Array = []
        for tkey2 in sa:
            if not sb.has(tkey2):
                continue
            var p1: Array = sa[tkey2]
            var p2: Array = sb[tkey2]
            if int(p1[1]) != int(p2[1]):
                continue
            sub_shared += 1
            if int(p1[0]) != int(p2[0]):
                sub_bad.append(str(tkey2))
        check(sub_shared >= 4 and sub_bad.is_empty(),
                "on the subdivided grid, %d texels matched by count and %d of them put the "
                        % [sub_shared, sub_bad.size()]
                + "plants somewhere else (%s)" % ", ".join(PackedStringArray(sub_bad)))
    else:
        check(false, "the subdivided re-centring builds did not complete")
    v.queue_free()


func test_a_census_is_the_stand_a_headless_replay_can_score() -> void:
    """THE PIECE THAT MAKES A REPLAY POSSIBLE AT ALL.

    Instance transforms read back as the identity under the dummy renderer, so
    a headless harness cannot ask a MultiMesh what it holds. That is fine for a
    photograph and fatal for a replay, which has to know what population every
    frame of a recorded flight had.

    So the build keeps a census beside the meshes: sub-cell -> count and a
    position. Two claims are checked here rather than assumed:

      1. IT IS THE STAND, not a summary of it. The census sums to exactly what
         the report says was placed, family by family.
      2. CHURN COLLAPSES TO A MINIMUM. Two builds that admit one sub-cell hold
         the first n_a and the first n_b plants of ONE fixed order, so what
         they share is the first min(n_a, n_b) -- which is only true because
         placement is a stable prefix of a positional order. Against the
         per-build random sequence this replaced, two builds shared nothing
         whatever their counts said, and no census could have told them apart.
    """
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    var bound := v.bind_families()
    check(bool(bound["ok"]), "families did not bind: %s" % str(bound.get("why", "")))
    check(v.show_field("deepest_winter", "band.pft_fractions", 22), "the field did not paint")
    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)

    var r := v.scatter_at(centre, 1500.0)
    check(bool(r.get("ok", false)), "the scatter did not build: %s" % str(r.get("why", "")))
    if not bool(r.get("ok", false)):
        v.queue_free()
        return
    var cen: Dictionary = v.scatter.census
    var placed: Dictionary = r["placed"]
    var total := 0
    for g in placed:
        total += int(placed[g])
    check(FlightTrace.population(cen) == total,
            "the census holds %d plants and the report says %d were placed. A replay scored "
                    % [FlightTrace.population(cen), total]
            + "off this would be scoring a different stand than the one drawn.")
    check(cen.size() > 0 and cen.size() < total,
            "the census has %d entries for %d plants; it is meant to be one row per sub-cell"
            % [cen.size(), total])

    # A build of the same ground with the population thinned: with the share
    # halved, every sub-cell keeps a PREFIX of what it kept before, so the
    # census arithmetic must report gone-only and nothing appearing.
    var before: Dictionary = v.scatter.census
    var half: Dictionary = v.scatter_at(centre, 1500.0, VegetationScatter.NO_SCHEDULE,
            maxi(1, int(total / 2)))
    check(bool(half.get("ok", false)), "the thinned scatter did not build")
    if not bool(half.get("ok", false)):
        v.queue_free()
        return
    var after: Dictionary = v.scatter.census
    var churn: Dictionary = FlightTrace.churn_between(before, after)
    check(int(churn["before"]) == total,
            "churn_between read %d plants before, against %d placed" % [int(churn["before"]), total])
    check(int(churn["after"]) < int(churn["before"]),
            "halving the build ceiling did not thin the stand")
    check(int(churn["appeared"]) == 0,
            "thinning the stand made %d plants APPEAR. Lowering a share is supposed to remove "
                    % int(churn["appeared"])
            + "candidates from a fixed order, never to re-draw them -- which is the whole of "
            + "why a crossfade has something bounded to hide.")
    check(int(churn["survived"]) == int(churn["after"]),
            "%d of the %d plants in the thinned stand are not in the fuller one it came from"
            % [int(churn["after"]) - int(churn["survived"]), int(churn["after"])])
    check(float(churn["gone_fraction"]) > 0.0 and float(churn["gone_fraction"]) <= 1.0,
            "gone_fraction came out at %s" % String.num(float(churn["gone_fraction"]), 4))

    # And the identity that keeps the two fractions apart, because reading one
    # as the other has already cost a prediction.
    var symmetric := float(int(churn["appeared"]) + int(churn["gone"]))
    check(absf(float(churn["churn_fraction"])
                    - symmetric / float(int(churn["before"]) + int(churn["after"]))) < 1e-9,
            "churn_fraction is not the symmetric difference over both populations")
    v.queue_free()


func test_a_flight_trace_round_trips_and_a_pan_cannot_churn() -> void:
    """A TRACE THAT CANNOT BE REPLAYED IS A DEMO.

    The pose has to come back out of JSON as the pose that went in, or a
    replay scores a path nobody flew. Checked to a tolerance far under
    anything that could change a build: placement quantises world position to
    the centimetre, so a pose that round-trips to a micron is exact for every
    purpose here.

    AND THE PAN CLAIM IS STRUCTURAL, WHICH IS WHY IT IS ASSERTED RATHER THAN
    MEASURED. The scatter is built around a centre; a rotation does not move
    the centre; so the population is identical and churn is exactly zero for
    any pan, always. A metric that cannot fail on what it is pointed at is not
    the metric for pans -- what a heading has IN FRONT of it is, and that has
    to actually vary with heading or it is no better.
    """
    var t := FlightTrace.new()
    t.begin({"what": "a test", "recentre_m": 0.0})
    var poses: Array = [
        Transform3D(Basis.from_euler(Vector3(0.1, 0.9, 0.0)), Vector3(12345.5, 1713.25, -987.75)),
        Transform3D(Basis.from_euler(Vector3(-0.4, -2.7, 0.0)), Vector3(-500.125, 40.0, 6.5)),
    ]
    for i in poses.size():
        t.add(float(i) * 16.0, poses[i], {"mark": FlightTrace.MARK_NONE})
    var doc = JSON.parse_string(JSON.stringify(t.to_dict(), "  ", false))
    check(typeof(doc) == TYPE_DICTIONARY, "the trace did not serialise to a document")
    if typeof(doc) != TYPE_DICTIONARY:
        return
    var back: Array = (doc as Dictionary)["frames"]
    check(back.size() == poses.size(), "the trace lost frames on the way through JSON")
    for i in back.size():
        var got: Transform3D = FlightTrace.pose_of(back[i])
        var want: Transform3D = poses[i]
        check((got.origin - want.origin).length() < 1e-6,
                "frame %d came back %s m from where it was recorded"
                % [i, String.num((got.origin - want.origin).length(), 9)])
        check(rad_to_deg(got.basis.get_rotation_quaternion().angle_to(
                        want.basis.get_rotation_quaternion())) < 1e-4,
                "frame %d came back pointing somewhere else" % i)

    # A pan: same position, different heading. The census is untouched by
    # construction, so churn is zero -- and what is in front of the camera is
    # not, or the substitute metric is no better than the one it replaces.
    var cen := {
        "tree|1|1": [10, 0.0, 0.0, -100.0],
        "tree|2|2": [20, 0.0, 0.0, 100.0],
    }
    var facing := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 0.0)), Vector3.ZERO)
    var turned := Transform3D(Basis.from_euler(Vector3(0.0, PI, 0.0)), Vector3.ZERO)
    var still: Dictionary = FlightTrace.churn_between(cen, cen)
    check(int(still["gone"]) == 0 and int(still["appeared"]) == 0
                    and float(still["gone_fraction"]) == 0.0,
            "a population compared with itself churned, which no pan can do")
    var ahead: Dictionary = FlightTrace.in_view(cen, facing, 75.0, 1.6)
    var behind: Dictionary = FlightTrace.in_view(cen, turned, 75.0, 1.6)
    check(int(ahead["instances"]) == 10 and int(behind["instances"]) == 20,
            "turning around showed %d then %d instances, against 10 and 20. If a heading does "
                    % [int(ahead["instances"]), int(behind["instances"])]
            + "not change what is counted, the pan metric measures nothing.")

    var q: Dictionary = FlightTrace.quantiles([3.0, 1.0, 2.0, 4.0])
    check(float(q["p50"]) == 2.0 and float(q["max"]) == 4.0 and float(q["min"]) == 1.0,
            "nearest-rank quantiles came out at %s" % str(q))
    check(FlightTrace.quantiles([]).is_empty(),
            "an empty sample returned numbers, which read as a measurement of zero")


func test_no_committed_trace_is_over_the_size_this_repo_commits() -> void:
    """DECISION 948'S THRESHOLD IS ABOUT FILES, AND A TRACE IS A FILE.

    A flight is a measurement input like the fixture, and the rule for an input
    over 10 MB is the same either way: it does not go in the tree, it arrives
    through `tools/fetch_artefacts.py` against a digest. This repo is public and
    a commit is forever, so the check belongs before the push and not after.

    IT WAS NEEDED. The first three flown traces were committed at 10.0, 14.0 and
    15.3 MB -- two of them over -- because the size was checked once when the
    only trace was a 637 KB scripted path and never again once real flights
    started arriving twenty times larger. Rounding the pose to a millimetre and
    dropping the fields that hold their default took the same three to 5.1, 7.1
    and 7.7 MB, which is what makes "a trace is a fixture you can replay from a
    clone" true rather than aspirational.

    The check is on the DIRECTORY rather than on the format, because the format
    staying small is a hope and a long enough flight will still cross this.
    """
    var dir := DirAccess.open("res://measurements/flights")
    check(dir != null, "no measurements/flights directory")
    if dir == null:
        return
    var traces := 0
    var over: Array = []
    var total := 0
    for name in dir.get_files():
        if not name.ends_with(".trace.json"):
            continue
        traces += 1
        var f := FileAccess.open("res://measurements/flights/" + name, FileAccess.READ)
        if f == null:
            continue
        var bytes := f.get_length()
        total += bytes
        if bytes > FlightTrace.COMMITTABLE_BYTES:
            over.append("%s at %.1f MB" % [name, float(bytes) / 1e6])
    check(traces > 0, "no traces are committed, so the replay has nothing to score")
    check(over.is_empty(),
            "%s over decision 948's %.1f MB threshold. A trace that large does not go in the "
                    % [", ".join(PackedStringArray(over)),
                            float(FlightTrace.COMMITTABLE_BYTES) / 1e6]
            + "tree; it arrives through tools/fetch_artefacts.py against a digest. This repo "
            + "is public and a commit is forever.")
    print("flights: %d traces committed, %.1f MB total, largest under the %.0f MB threshold"
            % [traces, float(total) / 1e6, float(FlightTrace.COMMITTABLE_BYTES) / 1e6])


## The one trace that predates `FlightTrace.add`'s snapping, and why it is not
## simply re-snapped. Re-snapping would move the poses by up to half a quantum,
## and `flight_replay.json` is a scored replay OF THIS TRACE committed beside
## it -- so the trace and its replay would have to move together, which is a
## re-run rather than an edit. Named here with its reason rather than fixed
## quietly or left unsaid.
const TRACE_PREDATING_THE_QUANTA := "scripted.trace.json"


func test_every_committed_trace_holds_the_quanta_its_writer_declares() -> void:
    """`FlightTrace` rounds position to a millimetre and orientation to a
    millionth, and its header says the rounding "loses nothing". That is a
    guarantee about what the WRITER does, and nothing checked it against what
    the committed traces CONTAIN -- so the guarantee has been read as a
    property of the artefacts since it was written, and for the one trace the
    gate actually replays it is not true.

    MEASURED AGAINST THE NEAREST REPRESENTABLE MULTIPLE. The first cut asked
    whether `v / 0.001` was an integer, which it cannot be: neither 0.001 nor
    the snapped product is a binary fraction, and at a 240 km easting the
    quotient carries 2e-8 of its own rounding. That version reported all four
    traces as violating, including the three that are exact -- a test measuring
    its own tolerance and calling it a finding."""
    var dir := DirAccess.open("res://measurements/flights")
    check(dir != null, "no flights directory")
    if dir == null:
        return
    var names := PackedStringArray()
    for f in dir.get_files():
        if f.ends_with(".trace.json"):
            names.append(f)
    names.sort()
    check(names.size() >= 2, "only %d trace(s) committed, so the rule cannot be shown both "
            % names.size() + "holding and failing")

    var holding := 0
    var failing := PackedStringArray()
    for name in names:
        var loaded: Dictionary = FlightTrace.load_from("res://measurements/flights/" + name)
        check(bool(loaded["ok"]), "%s did not load: %s" % [name, str(loaded.get("why", ""))])
        if not bool(loaded["ok"]):
            continue
        var t: FlightTrace = loaded["trace"]
        var v := FlightTrace.quantum_violations_in(t.frames)
        var bad := int(v["positions"]) + int(v["orientations"])
        print("trace %s: %d/%d positions and %d/%d orientations off-quantum%s"
                % [name, int(v["positions"]), int(v["positions_checked"]),
                   int(v["orientations"]), int(v["orientations_checked"]),
                   "" if bad == 0 else ", worst orientation residue %s"
                           % String.num_scientific(float(v["worst_orientation_residue"]))])
        if bad == 0:
            holding += 1
        else:
            failing.append(name)
            # HALF A QUANTUM IS WHAT UNSNAPPED LOOKS LIKE. If the residue were
            # tiny this would be float noise and the tolerance would be wrong;
            # at half the quantum the values simply never went through `add`.
            check(float(v["worst_orientation_residue"]) > FlightTrace.ORIENTATION_QUANTUM * 0.1,
                    "%s is off-quantum by only %s, which is nearer to a tolerance problem in "
                            % [name, String.num_scientific(
                                    float(v["worst_orientation_residue"]))]
                    + "this check than to a trace that never went through the writer")

    # TWO-SIDED, AND BOTH SIDES ARE REAL ARTEFACTS. The rule holds on every
    # trace recorded since the writer snapped, and fails on the one recorded
    # before -- which is what shows the check can tell the difference at all.
    check(holding > 0, "no committed trace satisfies the declared quanta, so either the writer "
            + "stopped snapping or this check cannot see that it does")
    check(Array(failing) == [TRACE_PREDATING_THE_QUANTA],
            "the traces that miss the declared quanta are %s; the one known to predate the "
                    % str(failing)
            + "snapping is %s. A new one here is a trace written by something that is not "
                    % TRACE_PREDATING_THE_QUANTA
            + "`FlightTrace.add`, and an empty list means the known one was re-recorded and "
            + "this exception should go.")
    print("traces: %d of %d hold the declared quanta; %s predates the rule"
            % [holding, names.size(), TRACE_PREDATING_THE_QUANTA])


func test_the_pinned_flight_replays_to_what_the_artefact_says() -> void:
    """ONE RECORDED PATH, SCORED THE SAME WAY FOREVER.

    The whole argument for recording a flight is that the measurement outlives
    the session. That is a claim about THIS repo on THIS commit, so it is
    checked the way every other artefact here is: the trace is loaded, its
    shape is asserted, and the committed replay is required to be about the
    trace that is committed beside it.

    WHAT IS NOT CHECKED HERE, AND IT IS THE POINT OF THE WHOLE HARNESS. The
    scripted trace carries no marks, because a script cannot judge. The
    threshold between an invisible churn and a visible one stays exactly as
    unmeasured as it was, and the artefact has to keep saying so rather than
    quietly reading as a result.
    """
    var loaded: Dictionary = FlightTrace.load_from(
            "res://measurements/flights/scripted.trace.json")
    check(bool(loaded["ok"]), "the pinned trace did not load: %s" % str(loaded.get("why", "")))
    if not bool(loaded["ok"]):
        return
    var t: FlightTrace = loaded["trace"]
    check(t.frames.size() > 100, "the pinned trace is %d frames, too short to score"
            % t.frames.size())
    var h: Dictionary = t.header
    for field in ["scene", "viewport", "fov_degrees", "individuation_k", "scatter_radius_m",
                  "recentre_m"]:
        check(h.has(field), "the trace header has no `%s`, so a replay cannot rebuild the "
                % field + "world it was flown in")
    check(str(h.get("flown_by", "")).length() > 0,
            "the pinned trace does not say who flew it. A scripted path and a person's are "
            + "different evidence and the artefact must not blur them.")
    check(int(h.get("marks", -1)) == 0,
            "the scripted trace carries %d marks. A script cannot judge what looked wrong, "
                    % int(h.get("marks", -1))
            + "and a mark from one would be a measurement of nothing.")

    # THE SPEED IS THE RULED ONE, checked off the poses rather than off the
    # setting. A harness that reports its own constant is not measuring.
    var motion: Array = FlightTrace.motion_of(t.frames)
    var speeds: Array = []
    for m in motion:
        speeds.append(float((m as Dictionary)["speed_m_s"]))
    var sq: Dictionary = FlightTrace.quantiles(speeds)
    check(absf(float(sq["mean"]) - 5.0) < 0.25,
            "the pinned path travels at %s m/s, against the 5.0 m/s the corpus derives for an "
                    % String.num(float(sq["mean"]), 2)
            + "avatar. Tuning at the wrong speed is tuning against a world nobody sees.")
    var turns: Array = []
    for m2 in motion:
        turns.append(float((m2 as Dictionary)["turn_degrees_s"]))
    check(float(FlightTrace.quantiles(turns)["max"]) > 1.0,
            "the pinned path never turns, so it exercises nothing a dolly did not")

    var f := FileAccess.open("res://measurements/flight_replay.json", FileAccess.READ)
    check(f != null, "no flight_replay.json")
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    check(typeof(parsed) == TYPE_DICTIONARY, "flight_replay.json is not a document")
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var runs: Array = (parsed as Dictionary)["runs"]
    check(runs.size() > 0, "flight_replay.json records no runs")
    # EVERY RUN, NOT THE FIRST. The artefact holds one run per flight and the
    # flights are a series -- a null result at one churn level only means
    # anything against the level below it -- so a check that read runs[0] would
    # stop checking exactly as the evidence started accumulating.
    for r5 in runs:
        _check_one_flight_run(r5, t)


func _check_one_flight_run(r5: Variant, t: FlightTrace) -> void:
    var run: Dictionary = r5
    # THE COMMITTED REPLAY IS OF WHATEVER WAS LAST FLOWN, which is the point:
    # the artefact is the real measurement, and the scripted path above is the
    # fixture that keeps the instrument testable with nobody at the machine.
    # What is required is that the two are consistent -- the replay has to be
    # of a trace that is actually committed, and of the same number of frames.
    var of_trace: String = str(run["trace"]).get_file()
    check(FileAccess.file_exists("res://measurements/flights/" + of_trace),
            "flight_replay.json is a replay of %s, which is not committed. An artefact whose "
                    % of_trace
            + "input is missing cannot be re-taken and is a screenshot of a number.")
    var replayed: Dictionary = FlightTrace.load_from(
            "res://measurements/flights/" + of_trace)
    if bool(replayed["ok"]):
        var rt: FlightTrace = replayed["trace"]
        check(int(run["frames"]) == rt.frames.size(),
                "the replay scored %d frames and %s has %d"
                % [int(run["frames"]), of_trace, rt.frames.size()])

    # THE AGREEMENT CHECK MUST NOT READ AS PASSED WHEN IT COMPARED NOTHING.
    # A synthesised trace records no populations, so there is nothing to
    # disagree with -- and a harness that called that "exact" would be the
    # exact shape of defect this repo keeps finding in its own instruments.
    var agree: Dictionary = run["replay_agreement"]
    check(agree.has("ran") and agree.has("frames_compared"),
            "the replay agreement does not say whether it compared anything")
    if int(agree["frames_compared"]) == 0:
        check(not bool(agree["ok"]) and str(agree["why_not"]).length() > 20,
                "the agreement check compared no frames and still reported ok")
    else:
        check(bool(agree["ok"]) == (int(agree["frames_disagreeing_on_population"]) == 0),
                "the agreement verdict does not follow from its own count")

    # Churn is quoted over the frames that could churn, and the artefact says
    # which those are.
    var per: Dictionary = run["per_frame"]
    check(per.has("gone_fraction_at_rebuilds") and per.has("rebuilds"),
            "the replay quotes churn without saying how many frames could churn")
    if int(per["rebuilds"]) == 0:
        check((per["gone_fraction_at_rebuilds"] as Dictionary).is_empty(),
                "no frame rebuilt and a churn distribution was reported anyway")
    check(str(run["not_covered"]).find("tile pyramid") >= 0,
            "the replay does not record that the near field has no ground until the pyramid "
            + "lands, which is what limits eye-level judgement")

    # THE STALL ANALYSIS IS NOT OPTIONAL, and this is why. The first flown
    # trace came back with sixteen marks, and a mark analysis that quoted only
    # the churn and the population at each of them showed sixteen unremarkable
    # rows: churn 0.0000, a normal frame, a normal population. Every one of
    # them was in fact within two seconds of the harness blocking its own main
    # loop for 1.8 s to rebuild the scatter. The flyer was reporting a freeze
    # and the instrument was answering a different question.
    #
    # So a replay that reports marks must also report what they were near. A
    # mark analysis that cannot distinguish "the far field looked wrong" from
    # "the harness stopped" is not evidence about the far field.
    check(run.has("stalls"), "the replay does not report stalls, so a mark cannot be told "
            + "apart from the harness blocking its own loop")
    var stalls: Dictionary = run["stalls"]
    check(stalls.has("count") and stalls.has("blocked_share_of_flight"),
            "the stall block does not say how much of the flight was spent inside a rebuild")
    var flown_marks: Array = run["marks"]
    if flown_marks.is_empty():
        check(int(run.get("marks_after_a_stall", 0)) == 0,
                "no marks were recorded and some were attributed to stalls")
    else:
        check(run.has("marks_after_a_stall"),
                "the replay reports %d marks without saying how many were near a stall, which "
                        % flown_marks.size()
                + "is the difference between a finding about the far field and a finding "
                + "about this harness")
        for m in flown_marks:
            var mark: Dictionary = m
            for field2 in ["seconds_since_the_last_stall", "within_reaction_of_a_stall",
                           "worst_gone_fraction_in_the_window_before"]:
                check(mark.has(field2),
                        "a mark is missing `%s`, so it cannot be read against anything" % field2)


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
    settles it: the four groups sum to 1.0000 in 99.7% of covered cells, while
    bare runs 0.05 to 0.95 and averages 0.475. Both cannot be absolute -- a cell
    cannot be 95% bare and 100% covered -- so the one that sums to one is the
    composition, and a life form's ground cover is its share scaled by
    `1 - bare_fraction`.

    NOT EVERY CELL, AND THE THRESHOLD IS NOT WHAT TO CHANGE WHEN THIS FAILS.
    Upstream divides by `tot + EPS_V` inside a branch already gated on
    `tot > EPS_V`, so the epsilon is redundant where it is applied and acts as a
    mass sink; the sum is exactly `tot / (tot + EPS_V)` and a cell near the gate
    loses part of its composition. Measured here: 16 of `deepest_winter`'s 5,612
    covered cells sum below 0.99 at day 22, worst 0.696. The 99% below is
    headroom over a known defect, not a tolerance for sloppiness -- its
    population grows with run length (12 cells at year 25, 182 at year 1000 of
    the M0 trace), so this WILL fail for a real reason. When it does, the fix is
    upstream; loosening the threshold would convert a working alarm into a
    permanently silent one.

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
    # Which cells the upstream epsilon defect has eaten, so this can say whether
    # it is pinning REACHABILITY (its job) over numbers that are also RIGHT
    # (not its job, and not currently true everywhere).
    var per: Array = []
    for gi in groups.size():
        per.append(v.fixture.day_values(window, "band.pft_fractions", day, gi))
    var broken_cell := {}
    for cell in v.fixture.n_cells:
        var sum := 0.0
        for gi in groups.size():
            var vv: PackedFloat64Array = per[gi]
            if cell < vv.size() and not is_nan(vv[cell]):
                sum += vv[cell]
        if sum >= 1e-3 and sum < 0.99:
            broken_cell[cell] = sum
    var trace := 0
    var trace_tinted := 0
    var trace_in_broken := 0
    var smallest := INF
    for gi in groups.size():
        var fr: PackedFloat64Array = per[gi]
        for cell in fr.size():
            var cov := VegetationScatter.ground_cover(fr[cell],
                    NAN if cell >= bare.size() else bare[cell])
            if is_nan(cov) or cov <= 0.0 or cov >= 0.01:
                continue
            trace += 1
            smallest = minf(smallest, cov)
            if broken_cell.has(cell):
                trace_in_broken += 1
            if cell < colours.size() and colours[cell].a > 0.0:
                trace_tinted += 1
    check(trace > 0, "no cell in the shipped fixture carries a trace share under 1%, so this "
            + "test proves nothing about floors. Either the fixture changed or the reading did.")
    check(trace_tinted == trace, "%d of %d trace-share cell-groups reach the tint. The rest are "
            % [trace_tinted, trace]
            + "being floored away, and a floor here deletes grass from most of the basin -- "
            + "which renders as a basin with little grass in it rather than as a bug.")
    # THIS PINS REACHABILITY, NOT CORRECTNESS. That a trace share reaches the
    # tint says nothing about whether the share is right, and upstream's epsilon
    # defect means some of them are not: a cell whose composition sums to 0.70
    # has lost mass, and its trace groups are wrong in a direction this cannot
    # see. The overlap is zero today and grows with run length, so it is printed
    # rather than asserted -- an assert would either be vacuous now or start
    # failing for something this test is not about.
    print("tint: %d trace cell-groups under 1%% cover, smallest %s, all tinted; "
            % [trace, String.num(smallest, 9)]
            + "%d of them in a cell the upstream epsilon defect has eaten (%d such cells)"
            % [trace_in_broken, broken_cell.size()])
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
    # THE HOLE AT ZERO, WHICH THE SEAM RE-TAKE WALKED INTO. `next > best * 1.2`
    # is a question about a RATIO, and when the winner scores exactly 0.0 the
    # ratio is infinite for any non-zero runner-up -- so the rule declared a
    # separation on a margin of 7.07e-06 of a colour distance, against a
    # renderer whose finest expressible step is 1/255. Measured at 2e60b17 on
    # the real artefact, not constructed here.
    var at_zero := SeamScore.rank({"win": 0.0, "next": 7.066670605127e-06},
            SeamScore.COLOUR_NOISE_FLOOR)
    check(not bool(at_zero["separates"]),
            "a winner at exactly 0.0 beside a runner-up 7e-06 away reads as separation, which "
            + "is the ratio rule's hole at zero: any non-zero second place divides an "
            + "infinite ratio out of a zero best")
    check(str(at_zero.get("why_not", "")).contains("same measurement"),
            "the refusal does not say it is a floor problem: %s" % str(at_zero.get("why_not")))
    # AND THE CONTROL: the same shape, above the floor, still separates. Without
    # this the floor could be any number at all, including one that refuses
    # everything.
    var above := SeamScore.rank({"win": 0.0, "next": 0.05}, SeamScore.COLOUR_NOISE_FLOOR)
    check(bool(above["separates"]),
            "a real separation from a zero best was refused by the floor")
    # The coverage floor is one pixel of the band it was measured over, so it
    # follows the measurement rather than being a constant somebody chose.
    check(SeamScore.coverage_noise_floor(9027) > SeamScore.coverage_noise_floor(23154),
            "a smaller band does not get a coarser coverage floor, so the floor is not a "
            + "property of the measurement")

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


func test_the_harness_guards_refuse_what_they_were_written_for() -> void:
    """THREE FAILURES THAT EACH PRODUCED A COMPLETE, PLAUSIBLE, WRONG ARTEFACT,
    made refusable after the fact. None of them was caught by reading numbers.

    A FROZEN CAPTURE. A window that loses focus here stops being drawn while
    the main loop ticks on, so `get_image()` returns the last frame rendered.
    Two whole `measure_motion` runs scored one frozen image against each
    position's own mask -- different numbers per position, identical between
    candidates. Found by noticing three saved PNGs were byte-identical.

    TWO THINGS THAT MUST DIFFER, COMING OUT THE SAME. `measure_seam`'s
    per-family oracles were each built with `only` set and then photographed
    with every vegetation node shown, so each was the previous build's
    instances. The tell was three DIFFERENT references reporting one mean
    colour to three decimals.

    A STAGE MACHINE THAT STOPS. A null reference inside a stage transition
    leaves the harness ticking at 1% CPU forever, which looks like a slow
    render. Twenty minutes twice here; thirteen hours for a throwaway probe,
    beside every measurement being taken at the time.
    """
    # A frozen capture, and the two cases that are NOT one.
    var a := PackedByteArray([1, 2, 3])
    var b := PackedByteArray([1, 2, 4])
    check(HarnessGuard.capture_note(a, a, "step 3") != "",
            "an identical capture across a camera move passed as a measurement")
    check(HarnessGuard.capture_note(a, b, "step 3") == "",
            "a capture that changed was refused")
    check(HarnessGuard.capture_note(a, a, "step 3", false) == "",
            "two identical frames were refused where nothing was supposed to move, which "
            + "would refuse every legitimate still")
    check(HarnessGuard.capture_note(PackedByteArray(), a, "step 0") == "",
            "the first capture of a run has nothing to compare against and was refused")

    # Distinctness, and that the message names BOTH sides of the collision.
    var seen := {}
    check(HarnessGuard.distinctness_note(seen, "0.320|0.266|0.119", "oracle_grass", "x") == "",
            "the first claim on a signature was refused")
    var clash := HarnessGuard.distinctness_note(seen, "0.320|0.266|0.119", "oracle_shrub", "x")
    check(clash != "", "two references reporting one mean colour to three decimals passed")
    check(clash.contains("oracle_grass") and clash.contains("oracle_shrub"),
            "the collision does not name both sides, so it says a duplicate exists and not "
            + "which two: %s" % clash)
    check(HarnessGuard.distinctness_note(seen, "0.1|0.2|0.3", "oracle_tree", "x") == "",
            "a distinct signature was refused")
    check(HarnessGuard.distinctness_note(seen, "", "unscored", "x") == "",
            "a candidate with no signature at all was reported as a collision rather than "
            + "as having nothing to compare")

    # Three decimals, because two renders of different things do not agree that
    # far by chance and two renders of one thing agree exactly.
    check(HarnessGuard.colour_key([0.32001, 0.26599, 0.11902])
                    == HarnessGuard.colour_key([0.32004, 0.26601, 0.11898]),
            "the colour signature splits two roundings of one frame")
    check(HarnessGuard.colour_key([0.320, 0.266, 0.119])
                    != HarnessGuard.colour_key([0.330, 0.266, 0.119]),
            "the colour signature collapses two genuinely different frames")
    check(HarnessGuard.colour_key([]) == "", "an absent colour produced a signature")

    # And the stall.
    check(HarnessGuard.stall_note("mask 3/14", 10) == "",
            "a stage ten frames in was called stalled")
    check(HarnessGuard.stall_note("mask 3/14", HarnessGuard.STALL_FRAMES) != "",
            "a stage that has not advanced in %d frames passed as progress"
            % HarnessGuard.STALL_FRAMES)
    check(HarnessGuard.stall_note("mask 3/14", HarnessGuard.STALL_FRAMES).contains("mask 3/14"),
            "the stall does not say WHERE it stalled, which is the whole of the diagnosis")
    print("guards: frozen capture, colliding signature and stalled stage all refuse")


func test_the_motion_metrics_and_which_of_them_detects_popping() -> void:
    """ROADMAP ITEM 2. THE METRIC IT SPECIFIES DOES NOT WORK; A SECOND ONE DOES.

    The item asks for "a scripted dolly through the seam scoring worst
    frame-pair delta in the annulus". Built, run, and it does not do the job it
    was wanted for. `rebuilt` re-scatters around the camera at every step --
    which is what solving the horizon from a per-place budget does, and the
    defect backlog 198 buys -- and the metric ranks it as SMOOTHER than the
    static scene it is supposed to be worse than. The tint, which is painted on
    the ground and cannot pop at all, scores worst of the three.

    Three measured reasons: coverage SATURATES (static sits at 1.000 for most
    of the dolly, so the median adjacent delta is exactly zero and there is no
    ratio); the ratio is UNSTABLE near zero (a candidate that barely varies
    gets a huge score from one ordinary step); and an aggregate over thousands
    of pixels is BLIND to a local event by construction, which is what a pop is.

    So the measurement moved off the screen and onto the instance set, where a
    pop is exactly what it is: something that exists in one frame and not the
    next. That separates cleanly -- 0.0000 against 1.0000 -- and carries a
    calibration no image metric here could offer, because the static scene is
    one build and MUST churn zero.

    Both are asserted. The first is self-retiring: if a future image metric
    does separate the control, it fails and the note beside it is what is
    stale.
    """
    var f := FileAccess.open("res://measurements/scatter_motion.json", FileAccess.READ)
    if f == null:
        check(false, "no measurements/scatter_motion.json -- run tools/measure_motion.sh")
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        check(false, "scatter_motion.json is not an object")
        return
    var runs: Array = (parsed as Dictionary).get("runs", [])
    check(runs.size() > 0, "scatter_motion.json carries no runs")
    for run_v in runs:
        var run: Dictionary = run_v
        var sc: Dictionary = run.get("scores", {})
        for name in ["static", "rebuilt", "tint"]:
            check(sc.has(name), "the run does not score '%s'. All three are needed: the "
                    % name + "control that pops, the scene that ships, and the one that "
                    + "cannot pop and calibrates the other two.")
            if not sc.has(name):
                continue
            var one: Dictionary = sc[name]
            check(one.has("parallax"), "%s has no lateral-step pair, which is the other half "
                    % name + "of the roadmap item")
        var reb: Dictionary = (sc.get("rebuilt", {}) as Dictionary).get("colour", {})
        var sta: Dictionary = (sc.get("static", {}) as Dictionary).get("colour", {})
        if reb.get("pop_ratio", null) == null or sta.get("pop_ratio", null) == null:
            continue
        var r := float(reb["pop_ratio"])
        var t := float(sta["pop_ratio"])
        check(r <= t * 1.5, "the dolly metric now ranks the re-scattering control at %sx "
                % String.num(r, 2)
                + "against %sx for the static scene -- it SEPARATES them, which it did not "
                        % String.num(t, 2)
                + "when this was written (5.98x against 5.13x, the wrong way round). If that "
                + "is real, the metric works and this test and the note beside it are what "
                + "need retiring.")
        # And the same-camera comparison: a difference that is large but STEADY
        # is two different scenes, not one flickering. 77-85% of annulus pixels
        # differ between static and rebuilt at every position, at a ratio of
        # 1.1 -- steady, so it is not churn either.
        var cross: Dictionary = (run.get("population_change", {}) as Dictionary).get(
                "static_vs_rebuilt", {})
        if bool(cross.get("ok", false)) and cross.get("pop_ratio", null) != null:
            check(float(cross["pop_ratio"]) < 2.0,
                    "the same-camera difference between static and rebuilt now spikes "
                    + "(%sx worst over median). That IS churn rather than two steady scenes, "
                            % String.num(float(cross["pop_ratio"]), 2)
                    + "and it would be the popping signal this harness could not find.")

        # THE METRIC THAT DOES WORK, and the calibration that says so.
        #
        # A pop is an instance that exists in one frame and not the next, so
        # the measurement belongs on the instance set rather than on the
        # screen. `static` is ONE BUILD dollied through and cannot churn: a
        # non-zero reading there is the instrument counting its own measurement
        # window moving, which is exactly what the first version did (0.12
        # instead of 0, from filtering membership by what the camera could
        # see). Zero is not a nice-to-have here; it is the whole calibration.
        var churn: Dictionary = run.get("population_churn", {})
        var st: Dictionary = churn.get("static", {})
        var rb: Dictionary = churn.get("rebuilt", {})
        if bool(st.get("ok", false)):
            check(float(st["worst_churn_fraction"]) == 0.0,
                    "the static scene churned %s of its instance set across a dolly step. It "
                    % String.num(float(st["worst_churn_fraction"]), 4)
                    + "is one build being looked at from different places -- it CANNOT churn "
                    + "-- so this is the instrument measuring the movement of its own window "
                    + "and every reading beside it is inflated by the same amount.")
        if bool(st.get("ok", false)) and bool(rb.get("ok", false)):
            check(float(rb["worst_churn_fraction"]) > 0.5,
                    "the re-scattering control churned only %s of its set. It re-decides which "
                    % String.num(float(rb["worst_churn_fraction"]), 4)
                    + "instances exist at every camera step, so a low reading means the "
                    + "instrument stopped seeing the one thing it was built to see.")
    print("motion: the dolly metric does not separate the control; the instance churn does")


func test_the_solved_horizon_discriminates_rather_than_returning_its_ceiling() -> void:
    """§24 gap 170 item (ii). Decision 1030 makes the frame budget the invariant
    and decision 949's constant the ceiling, so `k(place)` is only doing work
    where it comes out BELOW `0.35 * k_res`. A solve returning the ceiling
    everywhere discriminates nothing -- it would mean the line item is generous,
    not that the form works -- which is the document's own spread convention
    applied to the solve's own output.

    HEADLESS, WHICH IS WHY IT IS HERE AT ALL. Every term is arithmetic over wire
    quantities and committed coefficients: `cover_f`, `height_f` and
    `crown_area_f` from the fixture through `implication`, `c_f` from
    `render_cost.json`, `B_eff` from the line item and decision 951's
    multiplier, `k_res` from a declared camera. Item (i) needs frames and a
    person; this half does not, so the assertion most likely to falsify the form
    can be taken before anyone spends a windowed session."""
    var f := FileAccess.open("res://measurements/horizon_solve.json", FileAccess.READ)
    check(f != null, "no measurements/horizon_solve.json -- run tools/measure_horizon_solve.sh")
    if f == null:
        return
    var doc: Dictionary = JSON.parse_string(f.get_as_text())
    var ceiling := float((doc["camera"] as Dictionary)["ceiling"])
    check(ceiling > 0.0, "the artefact records no ceiling")
    # WHICH RULING THIS SOLVES, beside which client cut measured it. A solve is
    # only as current as the decision it encodes, and `measured_at_commit`
    # answers a different question -- it would keep moving while the formula
    # went stale underneath it.
    var ruled: Dictionary = doc.get("ruled_by", {})
    check(str(ruled.get("decision", "")) != "",
            "the solve does not say which decision it implements, so nothing connects these "
            + "numbers to the ruling they validate")
    check(str(ruled.get("corpus_commit", "")).length() >= 7,
            "the solve names decision %s and not the corpus it was read at"
            % str(ruled.get("decision", "?")))
    var windows: Array = doc.get("windows", [])
    check(windows.size() >= 1, "the solve was evaluated over no window")
    for wd in windows:
        var d: Dictionary = wd
        var name := str(d["window"])
        check(int(d["cells"]) > 100, "%s: only %d cells carried cover" % [name, int(d["cells"])])

        # THE SPREAD ITSELF. Both halves: something below the ceiling, and the
        # ceiling actually reached -- a solve pinned below it everywhere would
        # mean the ceiling never binds, which is a different finding and would
        # equally not be a discriminating solve.
        var lo := float(d["k_min"])
        var hi := float(d["k_max"])
        check(lo < ceiling * 0.9,
                "%s: the solved k bottoms out at %s against a ceiling of %s, so the solve "
                        % [name, String.num(lo, 3), String.num(ceiling, 3)]
                + "returns its ceiling almost everywhere and is discriminating nothing -- the "
                + "line item is generous rather than the form working")
        check(hi >= ceiling * 0.999,
                "%s: the solved k never reaches its ceiling (max %s of %s), so decision 949's "
                        % [name, String.num(hi, 3), String.num(ceiling, 3)]
                + "constant never binds here and the drawn world moves everywhere, which is "
                + "the regression the ceiling exists to prevent")
        var at := int(d["cells_at_ceiling"])
        check(at > 0 and at < int(d["cells"]),
                "%s: %d of %d cells sit at the ceiling, so it is all one state"
                % [name, at, int(d["cells"])])

        # AND THE DROP-TO-TINT CLAUSE GOVERNS A REAL POPULATION -- item (iii).
        # Zero would mean the clause is untested by this basin, which is worth
        # knowing rather than reading as "no problem".
        var under := int(d["pairs_under_floor"])
        check(int(d["pairs"]) > 0, "%s: no (cell, family) pairs at all" % name)
        print("gap 170: %s -- k %s..%s against a ceiling of %s, %d of %d cells at it; %d of %d "
                % [name, String.num(lo, 2), String.num(hi, 2), String.num(ceiling, 2),
                   at, int(d["cells"]), under, int(d["pairs"])]
                + "pairs under the placement floor")
        if under == 0:
            print("gap 170: %s -- NO pair falls under the placement floor, so decision 1030's "
                    % name + "drop-to-tint clause has no subject in this window")

        # A FAMILY WITH NO COST COEFFICIENT IS EXCLUDED FROM THE SOLVE, and that
        # has to be visible: its cover is missing from the denominator, so the
        # solved k for that cell is too HIGH and the budget it claims is not the
        # budget it would spend.
        var missing: Array = d.get("families_without_a_cost_coefficient", [])
        check(missing.is_empty(),
                "%s: %s -- those families are outside the measured triangle span, so they are "
                        % [name, str(missing)]
                + "absent from the denominator and every solved k here is too high")


func test_every_recorded_seam_run_says_which_question_it_answers() -> void:
    """An unlabelled baseline and a grade look identical. Four runs with errors,
    rankings and DOES NOT SEPARATE verdicts, sitting in an artefact with no
    statement of which question they answer, get read as the answer to whatever
    question is asked next -- and the four in hand are a PRE-REPAIR CONTROL,
    ruled so by the owner because a sufficiency verdict taken against a basin
    the §8.2 repair will substantially redraw is not a verdict anyone could
    cite afterwards.

    PER RUN, WHICH IS THE PART THAT NEEDED THINKING ABOUT. `--append` puts runs
    of different kinds in one artefact -- the control and the grading session
    that follows it -- so a file-level label would be wrong for half of them the
    moment the second session lands. And a run without `--append` rewrites the
    whole document, so a top-level field would not survive that either. A label
    the next run silently deletes is worse than no label, because it reads as
    present right up until it is not."""
    var f := FileAccess.open("res://measurements/scatter_seam.json", FileAccess.READ)
    check(f != null, "no measurements/scatter_seam.json")
    if f == null:
        return
    var doc: Dictionary = JSON.parse_string(f.get_as_text())
    var runs: Array = doc.get("runs", [])
    check(runs.size() > 0, "the seam artefact records no runs")
    var undeclared := 0
    var roles := {}
    for r in runs:
        var role := str((r as Dictionary).get("role", ""))
        check(role != "", "a recorded run carries no `role` at all, so nothing in the artefact "
                + "says which question its numbers answer")
        if role.contains("not declared at capture"):
            undeclared += 1
        roles[role] = true
    check(undeclared == 0,
            "%d of %d recorded runs were captured without `--role`, so the artefact cannot say "
                    % [undeclared, runs.size()]
            + "whether they are a baseline or a grade -- which is the one distinction a later "
            + "reader cannot recover from the numbers")
    # THE CONTROL IS NAMED AS A CONTROL, and says what it is a control FOR: a
    # baseline with no stated subject is a baseline for whatever a reader has in
    # mind.
    for role in roles:
        check(str(role).contains("control") or str(role).contains("grade"),
                "a run's role says neither control nor grade: %s" % str(role))
    check(str(roles.keys()[0]).contains("magisteria@"),
            "the role does not name the sim commit it is a control for, so it cannot be "
            + "compared against anything later")
    # AND THE DEFAULT REALLY IS THE UNDECLARED ONE, so the check above has a
    # subject rather than being a rule about a string nobody writes.
    check(str(roles.keys()[0]) != "not declared at capture",
            "the recorded role IS the tool's default, so nobody declared anything")
    print("seam roles: %d run(s), %d distinct role(s), 0 undeclared"
            % [runs.size(), roles.size()])


func test_a_per_family_reference_holds_only_that_family() -> void:
    """FOUND BY OPENING THE PNG, AND BY NOTHING ELSE.

    Each family's reference is built with `only` set, so the scatter holds that
    family and no other. The harness then showed every `Vegetation_*` node
    before photographing it -- and a MultiMesh node KEEPS its previous mesh when
    a build does not mention its family, so showing them all resurrected the
    last build's instances. The `oracle_grass` frame came back full of trees and
    shrubs with grass as a fringe along the bottom.

    It produced a complete, plausible table: every score finite, every row in
    the right annulus, ordering that looked like a result. The tell was in the
    numbers and I missed it -- three DIFFERENT family references reporting the
    same mean colour to three decimals -- so that is what is asserted here,
    beside the cheaper structural check.
    """
    var f := FileAccess.open("res://measurements/scatter_seam.json", FileAccess.READ)
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var checked := 0
    for run_v in ((parsed as Dictionary).get("runs", []) as Array):
        var run: Dictionary = run_v
        var seen := {}
        for cand_v in (run.get("candidates", []) as Array):
            var cand: Dictionary = cand_v
            var name := str(cand.get("name", ""))
            if not name.begins_with("oracle_"):
                continue
            var lf := name.substr("oracle_".length())
            var sc: Dictionary = cand.get("scatter", {})
            # The BUILD held one family.
            check(str(sc.get("only_life_form", "")) == lf,
                    "%s was built without `only` set to %s, so it is a reference for one "
                    % [name, lf] + "family drawn from a scatter holding all of them")
            var nonzero := PackedStringArray()
            for g in (sc.get("placed", {}) as Dictionary):
                if int((sc["placed"] as Dictionary)[g]) > 0:
                    nonzero.append(str(g))
            check(nonzero.size() <= 1, "%s placed %s. A per-family reference that holds more "
                    % [name, ", ".join(nonzero)] + "than its own family is not one.")
            # And the FRAME held one family. Two references that drew different
            # families cannot agree to three decimals on mean colour; when they
            # do, they are the same frame under different names.
            var bands_a: Array = cand.get("bands", [])
            if bands_a.is_empty():
                continue
            var mid: Dictionary = bands_a[bands_a.size() / 2]
            var col: Array = mid.get("isolated_mean_colour", [])
            if col.size() < 3:
                continue
            var key := "%s|%s|%s" % [String.num(float(col[0]), 3), String.num(float(col[1]), 3),
                    String.num(float(col[2]), 3)]
            check(not seen.has(key), "%s and %s photographed the same mean colour (%s). Two "
                    % [name, str(seen.get(key, "?")), key]
                    + "references of DIFFERENT families cannot agree to three decimals: one "
                    + "build's instances are still on screen under the other's name.")
            seen[key] = name
            checked += 1
    if checked > 0:
        print("references: %d per-family oracle(s), each holding only its own family" % checked)


func test_a_family_is_scored_in_its_own_annulus_or_not_at_all() -> void:
    """THE POLARITY THIS FEATURE EXISTS TO KEEP. A per-family score that
    silently graded every family in ONE family's annulus is the plausible
    artefact this harness has produced four times: it would come back as a
    tidy table of numbers, all of them measured, none of them of the thing the
    column says. So the artefact carries each row's own annulus and its own
    horizon, and this asserts the two agree.

    AND THAT A ROW THE REFERENCE CANNOT REACH IS REFUSED RATHER THAN SCORED.
    Per-family horizons span 16 m to 8.5 km at the pinned place; the oracle is
    cut at 2.5x the seam and the scatter draws nothing past its radius. An
    annulus beyond the shallower of those has no instances in it -- not the
    candidate's and not the oracle's -- and what a score there measures is NEAR
    vegetation painted over FAR ground, because the mask marks a pixel by the
    range of the terrain behind it. That comes back as coverage near 1.0 and a
    tiny colour error, which reads as agreement and is two empty annuli
    agreeing. Measured: 13 of 21 rows at the pinned place are refused.
    """
    var f := FileAccess.open("res://measurements/scatter_seam.json", FileAccess.READ)
    check(f != null, "no measurements/scatter_seam.json")
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        check(false, "scatter_seam.json is not an object")
        return
    var runs: Array = (parsed as Dictionary).get("runs", [])
    var rows := 0
    var scored := 0
    var refused := 0
    for run_v in runs:
        var run: Dictionary = run_v
        # Per family now: each family's reference is cut to its own deepest
        # annulus, so one run-level depth would be four different claims.
        var reach_of: Dictionary = run.get("reference_reach_m", {}) if typeof(
                run.get("reference_reach_m", {})) == TYPE_DICTIONARY else {}
        # A run whose reference was thinned has to say so where a reader lands,
        # not on one job three screens down: every score in it is flattered by
        # the sampling and none of them is safe to quote.
        var sampled: Variant = run.get("reference_is_a_sample", null)
        for cand_v in (run.get("candidates", []) as Array):
            var cand: Dictionary = cand_v
            if str(cand.get("name", "")) == "oracle" and cand.has("oracle_is_a_sample"):
                check(sampled != null, "a run's oracle drew a sample of its own stand and the "
                        + "run does not say so at the top. Every per-family score in it is "
                        + "flattered by exactly the sampling.")
            for row_v in (cand.get("per_family", []) as Array):
                var row: Dictionary = row_v
                rows += 1
                if not bool(row.get("measurable", false)):
                    refused += 1
                    check(str(row.get("why", "")) != "",
                            "a refused per-family row does not say why, which makes it "
                            + "indistinguishable from one nobody took")
                    continue
                scored += 1
                # ITS OWN ANNULUS: [0.7, 1.5] x this family's own horizon.
                var d := float(row["horizon_m"])
                var lo := float(row["annulus_lo_m"])
                var hi := float(row["annulus_hi_m"])
                check(absf(lo - d * SeamScore.SCORE_LO_MULTIPLE) < 0.5
                                and absf(hi - d * SeamScore.SCORE_HI_MULTIPLE) < 0.5,
                        "%s was scored in %s-%s m against its own horizon of %s m. The annulus "
                                % [str(row["family"]), String.num(lo, 0), String.num(hi, 0),
                                        String.num(d, 0)]
                        + "has to be [%s, %s] x that horizon, or the row is one family's score "
                                % [String.num(SeamScore.SCORE_LO_MULTIPLE, 2),
                                        String.num(SeamScore.SCORE_HI_MULTIPLE, 2)]
                        + "taken in another family's band and every column in the table is a "
                        + "measurement of something the header does not name.")
                check(row.has("colour_error"),
                        "%s claims to be measurable and carries no error against the oracle"
                        % str(row["family"]))
                var reach := float(row.get("reference_reach_m",
                        reach_of.get(str(row["family"]), NAN)))
                if not is_nan(reach):
                    check(hi <= reach + 0.5, "%s was SCORED out to %s m against a reference "
                            % [str(row["family"]), String.num(hi, 0)]
                            + "that only reaches %s m. Past that there are no instances to "
                                    % String.num(reach, 0)
                            + "compare, and the agreement is two empty annuli agreeing.")
    check(rows > 0, "no per-family rows in scatter_seam.json, so nothing here is checked -- "
            + "run `bash tools/measure_seam.sh --sweep-k` or drop this test")
    print("annuli: %d per-family row(s), %d scored in their own annulus, %d refused for reach"
            % [rows, scored, refused])


func test_the_seam_measurement_separates_the_tint_from_the_null() -> void:
    """WHAT THIS TEST ASSERTS CHANGED, AND THE REASON IS THE POINT.

    It used to assert that the tint beat the null baseline — what ships today —
    by at least 2x on annulus colour, which was the harness's own finding held
    in the gate. That margin was an artefact of a defect in the harness: a tint
    candidate still BUILDS a scatter, and `measure_seam`'s isolation hid the
    terrain and the flowlines but never the instances, so the tint's *isolated*
    frame was the tint with the plants drawn on top of it. It was scoring the
    oracle and calling it the tint.

    Measured with the tint alone, it does not beat the null baseline by 2x. At
    one of the four pinned scenes it does not beat it at all. That is a finding
    about the candidate and it belongs in `measurements/README.md`, not in an
    assertion that would have to be loosened every time the news got worse.

    SO WHAT IS HELD HERE IS THE METRIC, NOT THE VERDICT: that both baselines
    were scored, that the scores are of frames that were actually drawn, and
    that the metric can still tell two visibly different candidates apart. A
    harness that cannot separate them cannot grade anything, whichever way the
    ranking comes out.

    The exactly-zero refusal below is what caught the defect, on a run that was
    meant to be a routine re-take. It stays.
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
        check(null_err > 0.0, "the null baseline scored exactly zero, which is not a frame")
        # THE METRIC MUST STILL SEPARATE THEM. A flat colour over the ground and
        # the stand it stands in for are visibly different frames; a score that
        # cannot tell them apart is measuring nothing, whichever of the two it
        # ends up preferring. This is deliberately a check on the INSTRUMENT and
        # not on which candidate wins.
        check(absf(null_err - tint) > 0.005,
                "the null baseline (%s) and the tint (%s) scored within 0.005 of each other at "
                        % [String.num(null_err, 4), String.num(tint, 4)]
                + "%s day %d. Those are visibly different frames and a metric that cannot "
                        % [str(run["scene"]["window"]), int(run["scene"]["day"])]
                + "separate them cannot grade anything subtler.")
        worst_ratio = minf(worst_ratio, null_err / tint)
    check(places.size() >= 2, "every run stands in the same place; place-dependence is measured "
            + "and one place cannot show sufficiency")
    check(days.size() >= 2, "every run draws the same day")
    # RECORDED, NOT ASSERTED. The margin is the finding and it is currently
    # under 1 at one scene, which means the tint loses to what ships today
    # there. Printing it keeps it in front of a reader of the gate output
    # without the gate pretending to a verdict the numbers do not support.
    print("seam: %d runs over %d places and %d day(s); the tint's worst margin over what ships "
            % [runs.size(), places.size(), days.size()]
            + "today is %sx on annulus colour%s" % [String.num(worst_ratio, 2),
                    "" if worst_ratio > 1.0 else " -- IT LOSES, see measurements/README.md"])


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


# ============================================================================
# Phase 8 lane B1: the stub-B seam.
# ============================================================================

## An observer good enough to produce a bundle for, with nothing in it that a
## transducer chose. Stature and posture are what a BODY is; there is no
## radius, no filter and no detail level, because a knob a consumer can turn is
## a knob a consumer can turn too far.
func _dev_observer() -> Dictionary:
    return {
        "session": "gate",
        "stature_m": BodyDerivation.DEFAULT_STATURE_M,
        "posture": "standing",
        "ground_point": PackedFloat64Array([100.0, 0.0, -200.0]),
    }


func test_the_bundle_admits_only_what_it_declares() -> void:
    """THE CLOSED SCHEMA IS THE LEAK GUARD, and it is the only form of that
    guard that can live in a public repo.

    The alternative is a denylist: a written list of everything that must never
    cross, which is one forgotten entry from being wrong, and which discloses
    the vocabulary of the thing it is protecting merely by naming it. A
    whitelist says what DOES cross. Anything else is refused unread -- not
    dropped, not ignored, refused -- so a field cannot arrive by being sent, by
    being added upstream, or by a producer and a consumer agreeing privately.
    """
    var fl := fixture()
    var p := FixturePassthrough.over(fl)
    check(p.is_ready(), "the passthrough producer did not come up over the fixture")
    var b := p.bundle_for(fl.windows[0], 0, _dev_observer())
    var ok := b.check()
    check(bool(ok["ok"]), "a passthrough bundle did not check: %s" % str(ok["why"]))

    var doc := b.to_dict()
    var back := PerceptBundle.from_dict(doc)
    check(not back.refused, "a bundle this schema wrote was refused reading it back: %s"
            % back.refusal)

    # An undeclared field at each level, refused where it arrives.
    for level in [["body", "competence_hint"], ["header", "earned_rung"],
            ["fields", "truth"], ["root", "evidence"]]:
        var bad := b.to_dict()
        if str(level[0]) == "root":
            bad[str(level[1])] = 1
        else:
            (bad[str(level[0])] as Dictionary)[str(level[1])] = 1
        var r := PerceptBundle.from_dict(bad)
        check(r.refused, "`%s` was accepted at %s -- the schema is not closed"
                % [str(level[1]), str(level[0])])
        check(r.refusal.contains(str(level[1])),
                "the refusal does not name the field that caused it: %s" % r.refusal)

    # A major version this client does not speak is a refusal, not a masking.
    var future := b.to_dict()
    (future["header"] as Dictionary)["schema_version"] = {"major": 99, "minor": 0}
    check(PerceptBundle.from_dict(future).refused, "a future major was read anyway")

    # And a readout, which v0 does not define a masked form for.
    var withreadout := b.to_dict()
    (withreadout["body"] as Dictionary)["readouts"] = [{"id": "thirst", "value": 0.5}]
    var rr := PerceptBundle.from_dict(withreadout)
    check(not rr.refused, "a readout is a declared field and should parse")
    check(not bool(rr.check()["ok"]),
            "a bundle carrying a readout passed its own check, and v0 defines no masked form "
            + "for one -- so it would have crossed unmasked by default")
    print("bundle: %d cells, %d rows, closed schema refuses undeclared fields at four levels"
            % [b.cell_keys.size(), b.rows.size()])


func test_the_same_moment_produces_the_same_bundle() -> void:
    """DECISION 180 IS WHAT MAKES A BUNDLE STREAM WORTH RECORDING. Same world,
    same observer, same moment, same bytes -- so a stream replays, and a replay
    that disagrees is a defect rather than a re-roll.

    Checked as bytes rather than as a structure on purpose: a dictionary
    compare would pass on two documents whose keys arrive in different orders,
    and it is the DOCUMENT that gets written to a file."""
    var fl := fixture()
    var p := FixturePassthrough.over(fl)
    var one := JSON.stringify(p.bundle_for(fl.windows[0], 3, _dev_observer()).to_dict())
    p.forget()
    var two := JSON.stringify(p.bundle_for(fl.windows[0], 3, _dev_observer()).to_dict())
    check(one == two, "two bundles for one moment differ (%d vs %d bytes)"
            % [one.length(), two.length()])

    var other := JSON.stringify(p.bundle_for(fl.windows[0], 4, _dev_observer()).to_dict())
    check(one != other, "two different days produced the same bundle, so the moment is not "
            + "reaching the fields")

    # A bodies-only frame still says which channel 1 it was standing in.
    var light := p.bundle_for(fl.windows[0], 3, _dev_observer()).to_dict(false)
    check(not light.has("fields"), "a bodies-only frame carried channel 1 anyway")
    check((light["header"] as Dictionary).has("moment"),
            "a bodies-only frame does not say which moment it belongs to")
    print("bundle: deterministic at %d bytes with fields, %d without"
            % [one.length(), JSON.stringify(light).length()])


func test_the_passthrough_earns_nothing_and_hides_nothing() -> void:
    """A PASSTHROUGH THAT REFINES ANYTHING IS A MOCK WEARING A STUB'S NAME.

    The fixture models no observer, so there is nothing it could have earned:
    channel 2 is empty, no overlay is refined, and channel 1 is the carried
    rows at their carried values. The last of those is checked against the
    loader cell by cell rather than by counting rows -- a bundle that carried
    the right row names and the wrong numbers would look identical from the
    outside."""
    var fl := fixture()
    var window := fl.windows[0]
    var p := FixturePassthrough.over(fl)
    var b := p.bundle_for(window, 12, _dev_observer())

    check(b.subjects.is_empty(), "the passthrough invented %d subjects" % b.subjects.size())
    check(b.refinements.is_empty(), "the passthrough refined %d overlays" % b.refinements.size())
    check(b.readouts.is_empty(), "the passthrough carried a readout")
    check(str(b.producer.get("kind", "")) == FixturePassthrough.KIND,
            "the bundle does not stamp which producer made it")

    # EVERY ROW ON EVERY LATTICE, which is the assertion 978 moved.
    #
    # This read `fl.row_names(window, "band")` and counted against it, which was
    # exactly right while the fields region had one key axis and became the
    # thing keeping node rows out the moment it had two. It is the existing
    # assertion the conformance edit had to touch, and it is not a relaxation:
    # the bundle must carry the fixture's rows on BOTH lattices now, and each
    # row is still compared value by value rather than by name.
    var by_lattice := {}
    var expected := 0
    for lattice in PerceptBundle.AXIS_OF_LATTICE:
        by_lattice[str(lattice)] = fl.row_names(window, str(lattice))
        expected += (by_lattice[str(lattice)] as PackedStringArray).size()
    check(int(by_lattice["node"].size()) > 0,
            "the fixture carries no node-lattice row, so this check cannot see 978 at all")
    check(expected > 0 and b.rows.size() == expected,
            "the bundle carries %d rows against %d in the fixture (%d band, %d node)"
            % [b.rows.size(), expected, by_lattice["band"].size(), by_lattice["node"].size()])
    var compared := 0
    var worst := 0.0
    var per_lattice := {}
    for lattice in by_lattice:
        for row in (by_lattice[lattice] as PackedStringArray):
            check(b.lattice_of(row) == str(lattice),
                    "the bundle files %s on the %s lattice and the fixture says %s"
                    % [row, b.lattice_of(row), str(lattice)])
            # AND AGAINST ITS OWN AXIS. A node row measured against the
            # residence axis is the projection 978 forbids, arriving through a
            # test rather than through the schema.
            check(b.axis_for(row).size() == fl.day_values(window, row, 12, 0).size(),
                    "row %s is indexed by a %d-key axis and carries %d values"
                    % [row, b.axis_for(row).size(),
                            fl.day_values(window, row, 12, 0).size()])
            var groups := b.row_groups(row)
            for gi in groups.size():
                var mine := b.row_values(row, gi)
                var theirs := fl.day_values(window, row, 12, gi)
                check(mine.size() == theirs.size(),
                        "row %s group %d is %d long in the bundle and %d in the fixture"
                        % [row, gi, mine.size(), theirs.size()])
                for i in mini(mine.size(), theirs.size()):
                    if is_nan(theirs[i]):
                        check(is_nan(mine[i]),
                                "row %s cell %d is nodata and the bundle carries %f"
                                % [row, i, mine[i]])
                        continue
                    worst = maxf(worst, absf(mine[i] - theirs[i]))
                    compared += 1
                    per_lattice[str(lattice)] = int(per_lattice.get(str(lattice), 0)) + 1
    check(compared > 10000, "only %d values were compared" % compared)
    check(int(per_lattice.get("node", 0)) > 1000,
            "only %d node values were compared" % int(per_lattice.get("node", 0)))
    check(worst == 0.0, "the bundle moved a carried value by %s" % String.num(worst, 12))

    # THE TWO KEY SPACES DO NOT MIX, and the refusals are the guard.
    var a_cell := b.cell_keys[0]
    var a_node := b.node_keys[0]
    check(not is_nan(b.value_at(a_cell, "band.wetness")),
            "a band row could not be read by residence key")
    check(not is_nan(b.node_value_at(a_node, "node.streamflow")),
            "a node row could not be read by node key")
    check(is_nan(b.value_at(a_cell, "node.streamflow")),
            "a node row answered to a residence key, which is the projection 978 forbids")
    check(is_nan(b.node_value_at(a_node, "band.wetness")),
            "a band row answered to a node key")
    check(b.node_value_at(a_node, "node.streamflow")
                    == fl.day_values(window, "node.streamflow", 12, 0)[
                            fl.node_index_of(a_node)],
            "the bundle's node axis disagrees with the fixture's node ordinal")

    # The key axis is the world's, not the moment's.
    var later := p.bundle_for(window, 40, _dev_observer())
    check(b.same_axis_as(later), "two moments of one world do not share a key axis")
    print("passthrough: %d values carried verbatim (%s), %d subjects, %d refinements"
            % [compared, str(per_lattice), b.subjects.size(), b.refinements.size()])


func test_the_bundle_paints_the_pixels_the_fixture_did() -> void:
    """B1'S ACCEPTANCE TEST: ZERO BEHAVIOUR CHANGE.

    Making the viewer a bundle consumer is worth nothing if it moves a pixel,
    and 'the tests still pass' is a weaker claim than the one owed -- most of
    them do not look at the ground. So the two paths are run side by side and
    the images compared BYTE FOR BYTE: the same row, the same day, painted
    through the bundle and painted from the loader directly.

    If this ever fails, the passthrough has started deciding something."""
    var rl := residence()
    var fl := fixture()
    var p := FixturePassthrough.over(fl)
    var window := fl.windows[0]
    var row := "band.wetness"
    var b := p.bundle_for(window, 7, _dev_observer())

    var overlay := FieldOverlay.new()
    overlay.bind(rl, b, TerrainView.BARE_ALBEDO)
    check(overlay.is_bound(), "the overlay did not bind against the bundle's key axis")
    check(overlay.resolved_px > 100000,
            "only %d pixels resolved through the bundle's axis" % overlay.resolved_px)

    var through := overlay.paint_row(b, row, 0, 0.0, 1.0)
    check(bool(through["ok"]), "the bundle path did not paint: %s" % str(through.get("why", "")))
    if not bool(through["ok"]):
        return
    var direct := overlay.texture_for(fl.day_values(window, row, 7), 0.0, 1.0)
    var a := (through["texture"] as ImageTexture).get_image().get_data()
    var c := direct.get_image().get_data()
    check(a.size() == c.size() and a.size() > 0,
            "the two images are %d and %d bytes" % [a.size(), c.size()])
    var differing := 0
    for i in mini(a.size(), c.size()):
        if a[i] != c[i]:
            differing += 1
    check(differing == 0, "%d bytes of %d differ between the bundle path and the fixture path"
            % [differing, a.size()])
    print("seam: %d px painted through a bundle, %d bytes identical to the fixture path"
            % [overlay.resolved_px, a.size()])


func test_an_overlay_refuses_a_bundle_it_did_not_bind_against() -> void:
    """The join is an array of cell indices, and against another key axis every
    one of them names a different patch of ground. There is no way to see that
    on screen: a basin painted through the wrong join looks like a basin. So it
    is refused rather than checked by eye."""
    var rl := residence()
    var fl := fixture()
    var p := FixturePassthrough.over(fl)
    var b := p.bundle_for(fl.windows[0], 1, _dev_observer())
    var overlay := FieldOverlay.new()
    overlay.bind(rl, b, TerrainView.BARE_ALBEDO)

    var stranger := p.bundle_for(fl.windows[0], 2, _dev_observer())
    stranger.cell_keys = PackedStringArray(["someone|0", "else|1"])
    var r := overlay.paint_row(stranger, "band.wetness", 0, 0.0, 1.0)
    check(not bool(r["ok"]), "the overlay painted a bundle from another key axis")
    check(str(r["why"]).contains("axis"), "the refusal does not say why: %s" % str(r["why"]))
    print("seam: an overlay refuses a bundle whose key axis is not the one it bound against")


func test_the_observation_point_is_the_bodys_and_never_the_cameras() -> void:
    """THE ONE RESIDENCY QUESTION IN THIS LANE THAT IS ALREADY RULED: eye height
    is B's. The camera coincides with the observation point and never owns it.

    Put the derivation in a camera rig and it is correct exactly until a second
    consumer exists -- a headless scorer, a second observer, a driver with no
    camera at all -- and then it is either duplicated or a renderer is being
    asked where a body's eyes are.

    So this checks two things: that the derivation answers, and that nobody
    downstream holds a second copy of the answer."""
    var stature := BodyDerivation.DEFAULT_STATURE_M
    var standing := BodyDerivation.eye_height_m(stature, "standing")
    var crouched := BodyDerivation.eye_height_m(stature, "crouched")
    var prone := BodyDerivation.eye_height_m(stature, "prone")
    check(standing < stature and standing > crouched and crouched > prone and prone > 0.0,
            "eye heights are not ordered by posture: %s standing, %s crouched, %s prone"
            % [String.num(standing, 3), String.num(crouched, 3), String.num(prone, 3)])

    # An easting a Vector3 could not hold: single precision steps in about 6 cm
    # out here, and a body's own position is the one thing exact for free.
    var ground := PackedFloat64Array([-1237456.127, 1234.0, 1908765.379])
    var eye := BodyDerivation.observation_point(ground, stature, "standing")
    check(eye[0] == ground[0] and eye[2] == ground[2],
            "the derivation moved the body sideways")
    check(absf(eye[1] - (ground[1] + standing)) < 1.0e-12,
            "the observation point is not the ground plus the eye height")
    check(absf(eye[0] - Vector3(float(ground[0]), 0.0, 0.0).x) > 0.0,
            "a Vector3 round-trips this easting exactly, so the float64 carriage is "
            + "buying nothing and the comment above it is wrong")

    # A body that crouches and gets faster is a defect visible without knowing
    # any of the numbers.
    var fast := float(BodyDerivation.locomotion(stature, "standing")["sustainable_speed_m_s"])
    var slow := float(BodyDerivation.locomotion(stature, "crouched")["sustainable_speed_m_s"])
    check(fast > slow and slow > 0.0, "crouching is not slower than standing")

    # NO SECOND HOME. Nothing that draws may hold an eye height of its own.
    for path in ["res://src/ui/camera_rig.gd", "res://src/terrain/terrain_view.gd",
            "res://tools/free_flight.gd"]:
        var f := FileAccess.open(path, FileAccess.READ)
        check(f != null, "cannot read %s" % path)
        if f == null:
            continue
        var text := f.get_as_text()
        check(not text.contains("EYE_HEIGHT"),
                "%s holds an eye height of its own. It is the body's: take it from "
                        % path
                + "BodyDerivation, or the day a second consumer needs one there are two.")
    print("body: eyes at %s m standing, %s crouched, %s prone from a %s m stature"
            % [String.num(standing, 3), String.num(crouched, 3), String.num(prone, 3),
                    String.num(stature, 2)])


## Names a transducer file may not mention: the artefact behind the bundle, in
## each of the forms someone would reach for it by.
const REACHES_PAST_THE_BUNDLE := ["FixtureLoader", "fixture_client", "assets/fixture"]


## The scan itself, as a function of TEXT so the gate can check it against a
## violation that does not exist on disk.
##
## COMMENT LINES ARE STRIPPED FIRST, deliberately. A rule that cannot be
## explained in the file it governs is a rule the next person deletes; the
## boundary comment in `field_overlay.gd` should be free to say what it does not
## reach for. What is scanned is what runs.
static func _reaches_past_the_bundle(source: String) -> PackedStringArray:
    var found := PackedStringArray()
    var code := ""
    for line in source.split("\n"):
        if line.strip_edges().begins_with("#"):
            continue
        code += line + "\n"
    for needle in REACHES_PAST_THE_BUNDLE:
        if code.contains(needle):
            found.append(str(needle))
    return found


func test_the_transducer_subtree_consumes_the_bundle_and_never_the_fixture() -> void:
    """THE GUARD B1 IS REQUIRED TO LEAVE BEHIND.

    What it forbids is not the fixture -- the fixture is what the client has
    today -- but a consumer reaching PAST a bundle for the file underneath.
    That reach is invisible while a passthrough is producing: every pixel is
    right, and stays right until a real producer withholds something and the
    fallback quietly supplies it anyway.

    THE HARD PART IS NOT THE SCAN, IT IS WHAT IT SCANS. A scan over `src/ui/`
    would fail on correct code -- the scrubber and the series plot read the
    artefact on purpose and are not transducer code. A scan over nothing passes
    while proving nothing, which is worse than failing. So membership is a
    path: `Transducer.SUBTREE`, stated at the subtree root, and this test
    refuses an empty one and checks its own predicate against a violation
    before believing a green.
    """
    var files := Transducer.scripts()
    check(files.size() >= 2, "the transducer subtree holds %d scripts. A boundary with nothing "
            % files.size() + "inside it passes this test by scanning nothing.")

    var consumers := 0
    for path in files:
        var f := FileAccess.open(path, FileAccess.READ)
        check(f != null, "cannot read %s" % path)
        if f == null:
            continue
        var source := f.get_as_text()
        var name := path.get_file()
        var bad := _reaches_past_the_bundle(source)
        check(bad.is_empty(), "%s reaches past the bundle for %s. Everything under %s consumes "
                % [name, str(bad), Transducer.SUBTREE]
                + "a PerceptBundle and reads no artefact behind one.")
        if Transducer.NOT_A_CONSUMER.has(name):
            continue
        check(source.contains("PerceptBundle"),
                "%s is in the transducer subtree and never mentions a bundle. Either it "
                        % name
                + "consumes one or it does not belong inside the boundary.")
        consumers += 1
    check(consumers >= 1, "the subtree holds no consumer at all")

    # THE NEGATIVE CONTROL. A scan that has stopped being able to see a
    # violation reports the same green as a clean tree, so it is shown one.
    check(not _reaches_past_the_bundle("var x: FixtureLoader = null").is_empty(),
            "the scan does not fire on a plain reference, so its green means nothing")
    check(not _reaches_past_the_bundle("\tvar p := \"res://assets/fixture/\"").is_empty(),
            "the scan does not fire on a direct artefact path")
    # And the other way: prose may name what a file does not do.
    check(_reaches_past_the_bundle("## never a FixtureLoader here\nvar x := 1").is_empty(),
            "the scan fires on a comment, so the boundary cannot be explained where it applies")
    print("transducer: %d scripts under %s, %d consumers, none reaching past a bundle"
            % [files.size(), Transducer.SUBTREE, consumers])


# ============================================================================
# Phase 8 lane B2: the debug player.
# ============================================================================

func test_the_body_moves_at_the_speed_the_bundle_reports() -> void:
    """THE CHEAP CONSONANCE TEST. A player whose speed is a constant of its own
    is a camera with a walk animation, and it would pass every test that only
    looks at whether it moved. So the speed is doubled IN THE BUNDLE and the
    body is required to notice.

    And the refusal matters as much as the movement: a producer that says
    nothing about locomotion gets a body that does not move, not a body that
    falls back on a plausible number and travels at it forever."""
    var fl := fixture()
    var p := FixturePassthrough.over(fl)
    var b := p.bundle_for(fl.windows[0], 0, _dev_observer())

    var body := DebugPlayer.new()
    body.ground = PackedFloat64Array([0.0, 0.0, 0.0])
    body.heading_degrees = 0.0
    var r := body.step(b, 1.0, Vector2(0.0, 1.0))
    check(bool(r["ok"]), "the body did not move: %s" % str(r.get("why", "")))
    var one := float(r["moved_m"])
    var declared := float(b.locomotion["sustainable_speed_m_s"])
    check(absf(one - declared) < 1.0e-9,
            "a second of walking covered %s m against a declared %s m/s"
            % [String.num(one, 4), String.num(declared, 4)])

    # Change the producer's answer; the body must change with it.
    b.locomotion["sustainable_speed_m_s"] = declared * 2.0
    var faster := body.step(b, 1.0, Vector2(0.0, 1.0))
    check(absf(float(faster["moved_m"]) - declared * 2.0) < 1.0e-9,
            "the bundle doubled the speed and the body covered %s m. It is not reading the "
                    % String.num(float(faster["moved_m"]), 4)
            + "locomotion field, which makes it a camera with legs.")

    # Two keys are not a diagonal bonus.
    b.locomotion["sustainable_speed_m_s"] = declared
    var diag := body.step(b, 1.0, Vector2(1.0, 1.0))
    check(absf(float(diag["moved_m"]) - declared) < 1.0e-6,
            "a diagonal covered %s m against a straight %s"
            % [String.num(float(diag["moved_m"]), 4), String.num(declared, 4)])

    # No locomotion, no movement, and a sentence saying so.
    var mute := p.bundle_for(fl.windows[0], 0, _dev_observer())
    mute.locomotion = {}
    var still := body.step(mute, 1.0, Vector2(0.0, 1.0))
    check(not bool(still["ok"]) and float(still["moved_m"]) == 0.0,
            "a body with no locomotion field moved %s m" % String.num(float(still["moved_m"]), 4))
    check(str(still["why"]).length() > 20, "it does not say why it did not move")

    # The camera goes where the eyes are and nowhere else.
    check(DebugPlayer.camera_position(b) == b.as_vector3(),
            "the camera does not coincide with the reported observation point")
    print("player: %s m/s from the bundle, doubled in the bundle and followed, mute bundle "
            % String.num(declared, 2) + "refused")


func test_walk_mode_is_refused_while_the_ground_is_a_plane() -> void:
    """THE NEAR FIELD IS STILL A PLANE, AND THAT IS NO LONGER THE GATE.

    The terrain export triangulates the heightfield every few kilometres, so a
    body standing in the scatter stands in the middle of one flat triangle.
    That finding is real, is measured here, and moved when the pyramid landed.

    WHAT CHANGED IS WHAT IT DECIDES. This test used to end by refining the
    sample to a metre and asserting that walk mode OPENED -- "it is a gate and
    not a wall". Decision 986 retired that instrument: §23.976 measured it
    returning the sampling step at every resolution, so it reports the grid
    rather than the ground and any function of any amplitude passes it. The
    test asserting the gate could open was therefore asserting the defect, and
    it is inverted below: metre ground must NOT open walk mode, because how
    finely the ground is sampled is not one of 986's three conditions."""
    var fl := fixture()
    var p := FixturePassthrough.over(fl)
    var b := p.bundle_for(fl.windows[0], 0, _dev_observer())
    var hf := heightfield()

    # THE STRIDE THE VIEWER ACTUALLY DRAWS AT, not a stride this test chose.
    # A gate that picked its own would report a blocker of its own invention.
    var v := TerrainView.new()
    var drawn_sample := hf.pixel_size_m * float(v.stride)
    var near_field := TerrainView.SCATTER_HORIZON_M
    var verdict := DebugPlayer.walk_available(b, drawn_sample, near_field)
    check(not bool(verdict["ok"]),
            "walk mode opened on ground sampled every %s m" % String.num(drawn_sample, 0))
    check(str(verdict["why"]).contains("not gradeable"),
            "the refusal does not name what it waits on: %s" % str(verdict["why"]))

    # THE NEAR FIELD HALF IS UNCHANGED AND STILL MOVES. At today's sampling a
    # body stands on a plane; at the pyramid's 100 m it does not. Keeping the
    # two findings apart is what let that improvement be visible at all.
    var today := DebugPlayer.ground_findings(b, drawn_sample, near_field)
    check(not bool((today["near_field_is_relief"] as Dictionary)["ok"]),
            "the near field reads as relief at %s m sampling" % String.num(drawn_sample, 0))
    var tiled := DebugPlayer.ground_findings(b, 100.0, near_field)
    check(bool((tiled["near_field_is_relief"] as Dictionary)["ok"]),
            "the pyramid's 100 m does not make the near field relief, and the measurement "
            + "counts sixty-nine ground samples in a 480 m disc where the drawn mesh has none")

    # THE DEMOTED PROBE REPORTS A SPACING AND DECIDES NOTHING.
    var probe: Dictionary = tiled["native_spacing_probe"]
    check(float(probe["effective_native_m"]) == 100.0,
            "the probe reports %s m where the surface is sampled every 100 m"
                    % String.num(float(probe["effective_native_m"]), 1))
    check(not probe.has("ok"), "the probe still returns a verdict")

    # THE INVERSION. Metre ground was the case that used to open this gate.
    # Nothing about 986's conditions changes when the sample gets finer, so
    # nothing about the verdict may either -- and if this ever fails, the old
    # instrument has been re-keyed into the gate by somebody who read the
    # outcome and not the reason.
    var fine := DebugPlayer.walk_available(b, 1.0, near_field)
    check(not bool(fine["ok"]),
            "metre ground opened walk mode. Sampling finer is not one of decision 986's "
            + "three conditions, and a gate that opens on it is keyed to the instrument "
            + "§23.976 retired for reporting its own step.")
    check(JSON.stringify(fine["conditions"]) == JSON.stringify(verdict["conditions"]),
            "refining the ground from %s m to 1 m changed which conditions stand, so the "
                    % String.num(drawn_sample, 0)
            + "sample spacing is still deciding the gate through another door")
    print("player: walk refused at %s m sampling (stride %d) and still refused at 1 m -- the "
            % [String.num(drawn_sample, 0), v.stride]
            + "near field is a plane today and relief at the pyramid's 100 m, and neither "
            + "is what decides it")
    v.free()


func test_a_recorded_walk_replays_and_cannot_outrun_its_own_locomotion() -> void:
    """A BUNDLE STREAM IS A FIXTURE YOU CAN REPLAY FROM A CLONE, and it is
    recorded because a walk nobody can re-score is a demo.

    Two things are checked on the way back. That the file survives the trip --
    channel 1 stored once per moment, bodies per frame, and the poses identical
    afterwards. And the invariant that separates a body from a camera: no frame
    moved further than the speed the bundle itself reported would allow. A
    transducer helping itself to more speed than it was given shows up there
    and nowhere else, so the check is shown a tampered frame before its green
    is believed."""
    var fl := fixture()
    var p := FixturePassthrough.over(fl)
    var body := DebugPlayer.new()
    body.ground = PackedFloat64Array([-1237456.127, 1500.0, 1908765.379])
    var stream: BundleStream = null
    var walked: Array = []
    var dt := 1.0 / 60.0
    for i in 120:
        var day := 0 if i < 60 else 1
        var b := p.bundle_for(fl.windows[0], day, body.observer())
        if stream == null:
            stream = BundleStream.opened(b)
        stream.add(b, float(i) * dt)
        walked.append(b.as_vector3())
        body.heading_degrees = float(i)
        body.step(b, dt, Vector2(0.0, 1.0))

    check(stream.frames.size() == 120, "%d frames recorded" % stream.frames.size())
    check(stream.moments.size() == 2,
            "%d moments stored for two days of walking -- channel 1 is being written per frame"
            % stream.moments.size())

    var doc := JSON.stringify(stream.to_dict())
    var back := BundleStream.from_dict(JSON.parse_string(doc))
    check(back.frames.size() == stream.frames.size(), "the stream lost frames on the way back")
    var worst := 0.0
    for i in back.frames.size():
        var pt: Array = ((back.frames[i] as Dictionary)["body"] as Dictionary)["observation_point"]
        worst = maxf(worst, (Vector3(float(pt[0]), float(pt[1]), float(pt[2]))
                - (walked[i] as Vector3)).length())
    check(worst < 1.0e-6, "a replayed observation point sits %s m from the recorded one"
            % String.num(worst, 9))

    var outran := back.outran_its_speed()
    check(outran.is_empty(), "%d frames outran the speed their own bundle reported, worst %s m "
            % [outran.size(), "" if outran.is_empty()
                    else String.num(float((outran[0] as Dictionary)["moved_m"]), 3)]
            + "against what it was allowed")

    # THE NEGATIVE CONTROL: a body teleported one metre must be caught, or the
    # check above is a green that means nothing.
    var tampered := BundleStream.from_dict(JSON.parse_string(doc))
    var f: Dictionary = tampered.frames[50]
    var pt2: Array = (f["body"] as Dictionary)["observation_point"]
    pt2[0] = float(pt2[0]) + 1.0
    check(not tampered.outran_its_speed().is_empty(),
            "a body moved a metre in a sixtieth of a second and the check did not fire")

    var size := stream.over_committable()
    print("stream: %d frames, %d moments, %d bytes%s, no frame outran its locomotion"
            % [stream.frames.size(), stream.moments.size(), int(size["bytes"]),
                    ", OVER the committable size" if bool(size["over"]) else ""])


# ============================================================================
# Phase 8 lane B3: the console and the probe set.
# ============================================================================

func test_the_console_partitions_its_verbs_from_birth() -> void:
    """THE PARTITION IS THE ITEM, AND THE VERBS ARE ITS SHAPE. What a console
    does is easy to add later; which of its verbs may exist in which build is
    not, and a flat namespace makes that unanswerable without reading all of
    them.

    The enforcement is at REGISTRATION and not at execution. A verb that exists
    and declines is a verb somebody finds a way to call; a verb that was never
    registered cannot be reached. So the test asks a console built against a
    live producer for its probe verbs and requires them to be MISSING, with a
    sentence saying they are absent by construction rather than switched off.
    """
    var dev := DevConsole.new()
    dev.producer_kind = "fixture_passthrough"
    dev.dev_build = true
    check(dev.register("view.x", "", func(_a): return ""), "a view verb was refused")
    check(dev.register("probe.x", "", func(_a): return ""), "a probe verb was refused")
    check(dev.register("world.x", "", func(_a): return ""), "a world verb was refused")
    for n in dev.names():
        var ok := false
        for p in DevConsole.PREFIXES:
            if str(n).begins_with(p):
                ok = true
        check(ok, "verb `%s` belongs to no prefix" % str(n))

    # Against a live producer there is no artefact, so there is nothing to probe.
    var live := DevConsole.new()
    live.producer_kind = "live"
    live.dev_build = true
    check(not live.register("probe.cell", "", func(_a): return ""),
            "probe.cell registered against a live producer")
    check(live.names().is_empty() or not Array(live.names()).has("probe.cell"),
            "probe.cell exists against a live wire")
    var why := str(live.absent_prefixes().get("probe.", ""))
    check(why.contains("truth never arrives"),
            "the absence is not explained as one: %s" % why)
    var answer := live.run("probe.cell")
    check(answer.size() >= 2 and str(answer[1]).length() > 20,
            "running an absent verb does not say why it is absent: %s" % str(answer))

    # A production build has no world.* at all.
    var prod := DevConsole.new()
    prod.producer_kind = "fixture_passthrough"
    prod.dev_build = false
    check(not prod.register("world.reload", "", func(_a): return ""),
            "world.reload registered in a production build")
    check(str(prod.absent_prefixes().get("world.", "")).contains("never a transducer function"),
            "the world.* absence does not say what it is not")

    # And an unprefixed verb is refused outright.
    check(not dev.register("reload", "", func(_a): return ""),
            "an unprefixed verb was accepted, so the namespace is flat after all")
    # Controls are Nodes and these never entered the tree, so they are freed
    # here rather than left to the leak report at exit.
    dev.free()
    live.free()
    prod.free()
    print("console: three prefixes, probe.* absent against live, world.* absent in production")


func test_the_percept_min_names_what_binds_and_never_folds_art_debt() -> void:
    """`probe.percept` IS TWO COLUMNS AND ONE min(), and two things about the
    format are load-bearing rather than cosmetic.

    The earned column reads "no B: fixture is truth" because there is no
    producer earning anything yet -- which is the state a privilege leak looks
    exactly like. A faked number there would make this instrument useless on
    the day it matters.

    And a missing asset is ART DEBT, never a min() term. The asset lookup is
    required to be the identity, so its absence is a gap in the models; folding
    it in would convert a modelling gap into a claim about what an observer
    earned."""
    var no_b := PerceptProbe.evaluate("life_form", null, true, "life_form")
    check(bool(no_b["earned_is_placeholder"]), "the earned column claims to be a measurement")
    check(str(no_b["earned"]).contains("no B"), "the placeholder does not say what it stands in "
            + "for: %s" % str(no_b["earned"]))
    check(str(no_b["binding_term"]) == PerceptProbe.NOT_AFFORDABLE,
            "with no earned term, something other than the budget is binding: %s"
            % str(no_b["binding_term"]))

    # An earned term below the affordable one binds, and says so.
    var earned := PerceptProbe.evaluate("specific", "functional", true, "functional")
    check(str(earned["drawn"]) == "functional" and str(earned["binding_term"])
                    == PerceptProbe.NOT_EARNED,
            "an earned rung below the affordable one did not bind: %s" % str(earned))

    # Art debt is reported and is NOT the binding term of a percept claim.
    var debt := PerceptProbe.evaluate("specific", "specific", false, "life_form")
    check(bool(debt["art_debt"]), "a missing asset is not reported")
    check(str(debt["art_debt_note"]).contains("ART DEBT"),
            "art debt does not print as art debt")
    var lines := PerceptProbe.lines(debt)
    var joined := ""
    for l in lines:
        joined += str(l) + "\n"
    check(joined.contains("earned") and joined.contains("affordable") and joined.contains("drawn"),
            "the format is not two columns and a min(): %s" % joined)
    check(joined.contains("ART DEBT"), "the art-debt line does not reach the output")
    print("percept: earned | affordable | drawn = min, with art debt printed beside it")


func test_the_probe_re_derives_what_the_build_placed() -> void:
    """SELECTION BY RE-DERIVATION IS THE WHOLE DISCIPLINE, and this is what it
    buys. The probe never picks an instance -- it cannot, since transforms do
    not read back headless -- it recomputes the sub-cell's candidates from the
    hash, calling the same statics the build called.

    So a disagreement between the probe and the build can only mean a build
    defect, and this test is what turns that property into a check: for every
    sub-cell the build recorded a census entry for, the probe is asked how many
    plants belong there, and the answers have to be the same number."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    v.bind_families()
    v.show_field("deepest_winter", "band.pft_fractions", 45)
    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    var r := v.scatter_at(centre)
    check(bool(r.get("ok", false)), "no scatter to probe: %s" % str(r.get("why", "")))
    if not bool(r.get("ok", false)):
        v.queue_free()
        return

    var probe := InstanceProbe.new()
    probe.bind(v.scatter, v.heightfield, v.fixture, v.cell_probe(), v.families)
    check(probe.is_bound(), "the instance probe did not bind to the build")

    var q := VegetationScatter.PLACEMENT_QUANTUM
    var checked := 0
    var agreed := 0
    var states := {}
    for key in v.scatter.census:
        if checked >= 40:
            break
        var parts := str(key).split("|")
        if parts.size() != 3:
            continue
        var family := str(parts[0])
        var at := Vector2(float(parts[1].to_int()) / q, float(parts[2].to_int()) / q)
        var sub := probe.sub_at(at, family)
        if not bool(sub.get("ok", false)):
            continue
        checked += 1
        states[str(sub["state"])] = int(states.get(str(sub["state"]), 0)) + 1
        var built := int((v.scatter.census[key] as Array)[0])
        if int(sub.get("drawn", -1)) == built:
            agreed += 1
        else:
            check(false, "the build placed %d plants in %s and the probe re-derives %d"
                    % [built, str(key), int(sub.get("drawn", -1))])
    check(checked >= 10, "only %d census sub-cells could be probed" % checked)
    check(agreed == checked, "%d of %d sub-cells disagreed" % [checked - agreed, checked])

    # The nearest plant is named by ground and rank, and its re-derived
    # position is inside the sub-cell it belongs to.
    var any := ""
    for key2 in v.scatter.census:
        any = str(key2)
        break
    var p2 := str(any).split("|")
    var pt := Vector2(float(p2[1].to_int()) / q, float(p2[2].to_int()) / q)
    var near := probe.nearest(pt, str(p2[0]))
    check(bool(near.get("ok", false)) and near.has("position_m"),
            "the probe named no plant at a sub-cell the build placed in: %s"
            % str(near.get("why", near.get("state", "?"))))
    if near.has("position_m"):
        var pos: Vector2 = near["position_m"]
        var origin: Vector2 = near["origin_m"]
        var half := float(near["half_m"])
        check(absf(pos.x - origin.x) <= half + 1.0e-6 and absf(pos.y - origin.y) <= half + 1.0e-6,
                "a re-derived plant stands outside its own sub-cell")

    # AND THE ABSENCES ARE NAMED THINGS. Ground the build never reached is
    # NOT_BUILT and says so, rather than reading as a plant that is not there.
    var far := Vector2(centre.x + 400000.0, centre.y)
    var outside := probe.sub_at(far, "tree")
    if bool(outside.get("ok", false)):
        check(str(outside["state"]) == InstanceProbe.NOT_BUILT,
                "ground outside the build radius reports %s" % str(outside["state"]))
    print("probe: %d census sub-cells re-derived, all agreeing with the build; states %s"
            % [checked, str(states)])
    v.queue_free()


func test_a_re_centre_that_moved_a_key_is_a_defect_and_not_churn() -> void:
    """`probe.survive` IS THE INTERACTIVE TWIN OF THE CHURN METRIC: which
    plant, and why, rather than how many.

    Its three exits are three different findings, and only one is a bug.
    Thinning and the horizon are drawing decisions doing their job. A MOVED KEY
    is not churn at all -- placement is a function of ground, so the same
    ground under a different camera must produce the same key -- and it is
    reported as the defect it would be."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    v.bind_families()
    v.show_field("deepest_winter", "band.pft_fractions", 45)
    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    var r := v.scatter_at(centre)
    if not bool(r.get("ok", false)):
        v.queue_free()
        return
    var probe := InstanceProbe.new()
    probe.bind(v.scatter, v.heightfield, v.fixture, v.cell_probe(), v.families)

    var q := VegetationScatter.PLACEMENT_QUANTUM
    var verdicts := {}
    var tested := 0
    for key in v.scatter.census:
        if tested >= 12:
            break
        var parts := str(key).split("|")
        if parts.size() != 3:
            continue
        var at := Vector2(float(parts[1].to_int()) / q, float(parts[2].to_int()) / q)
        var s := probe.survives(at, str(parts[0]), 25.0, 25.0)
        if not bool(s.get("ok", false)):
            continue
        tested += 1
        verdicts[str(s["verdict"])] = int(verdicts.get(str(s["verdict"]), 0)) + 1
        check(str(s["verdict"]) != InstanceProbe.EXITS_KEY_MOVED,
                "a 25 m re-centre moved the placement key at %s. Placement is a function of "
                        % str(key)
                + "ground (§16.6); this is the defect the whole scheme exists to remove.")
        check(int(s["key_before"]) == int(s["key_after"]),
                "the key changed with the camera at %s" % str(key))
    check(tested >= 5, "only %d instances could be followed across a re-centre" % tested)
    print("survive: %d instances across a 25 m re-centre, verdicts %s" % [tested, str(verdicts)])
    v.queue_free()


func test_the_console_answers_headless_from_a_named_point() -> void:
    """A CONSOLE-LAUNCHED MEASUREMENT HAS TO BE THE SAME MEASUREMENT, or the
    console is a second implementation of every tool it binds. The way that is
    kept true is that every probe verb takes its point from the reticle OR from
    arguments -- and with a point in the arguments the whole set runs
    headlessly, which is how the gate drives it rather than trusting it."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    v.bind_families()
    v.show_field("deepest_winter", "band.pft_fractions", 45)
    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    v.scatter_at(centre)

    var console := DevConsole.new()
    console.producer_kind = str(v.bundle.producer.get("kind", ""))
    console.dev_build = true
    var verbs := ConsoleVerbs.new()
    verbs.bind(console, v)
    for expected in ["view.help", "probe.cell", "probe.instance", "probe.sub", "probe.row",
            "probe.survive", "probe.percept", "probe.pin", "world.day", "world.rebuild"]:
        check(Array(console.names()).has(expected), "the console has no %s" % expected)

    # POSTURE MOVED PREFIX, AND THE DISCRIMINATOR IS PINNED HERE. In a
    # production player, changing posture is an action the body takes: it goes
    # to B and changes what B reports back. A `view.*` verb that would have to
    # become a B-side action the day a real producer exists is in the wrong
    # prefix now, and a dev endpoint writing stub-B state is what `world.*` is
    # for -- so it disappears in production, correctly, along with the console.
    check(Array(console.names()).has("world.posture"),
            "posture is not a world verb")
    check(not Array(console.names()).has("view.posture"),
            "view.posture still exists, so both prefixes claim the same verb")

    var at := "%f %f" % [centre.x, centre.y]
    var cell := console.run("probe.cell " + at)
    check(cell.size() >= 3, "probe.cell answered %d lines" % cell.size())
    var joined := ""
    for l in cell:
        joined += str(l) + "\n"
    check(joined.contains("cell") and joined.contains("node axis"),
            "probe.cell does not name the cell it resolved: %s" % joined)

    var sub := console.run("probe.sub tree " + at)
    var sub_text := ""
    for l in sub:
        sub_text += str(l) + "\n"
    check(sub_text.contains("share") and sub_text.contains("bare"),
            "probe.sub does not print the composition arithmetic, which is the one thing that "
            + "format exists for: %s" % sub_text)

    var per := console.run("probe.percept tree " + at)
    var per_text := ""
    for l in per:
        per_text += str(l) + "\n"
    check(per_text.contains("no B: fixture is truth"),
            "probe.percept does not print the honest earned placeholder: %s" % per_text)

    var pin := console.run("probe.pin")
    var pin_text := ""
    for l in pin:
        pin_text += str(l) + "\n"
    check(pin_text.contains("contract v2.0"), "probe.pin does not read the contract pin: %s"
            % pin_text)

    # A CONSOLE-LAUNCHED MEASUREMENT IS THE SHELL TOOL. Not run here -- these
    # need a window and minutes -- but the binding is checked: every named tool
    # exists on disk, and an unknown name is a usage line rather than a launch.
    check(Array(console.names()).has("world.measure"), "the console cannot launch a measurement")
    for tool_name in ConsoleVerbs.MEASUREMENTS:
        var entry: Array = ConsoleVerbs.MEASUREMENTS[tool_name]
        check(FileAccess.file_exists("res://" + str(entry[0])),
                "world.measure %s names %s, which is not there" % [str(tool_name), str(entry[0])])
    var usage := console.run("world.measure nonsense")
    check(usage.size() == 1 and str(usage[0]).begins_with("world.measure <"),
            "an unknown measurement did not answer with a usage line: %s" % str(usage))

    # THE STREAMING VERBS, DRIVEN THE SAME WAY. `probe.tile` has to name the
    # four states apart -- a tile in flight reported as empty ground is the
    # near field flattening while every count says healthy -- and `view.stream`
    # is `view.*` because it changes what this client holds and draws and
    # touches no fixture, which is where the three prefixes are partitioned.
    check(Array(console.names()).has("view.stream"), "the console cannot stream")
    check(Array(console.names()).has("probe.tile"), "the console cannot read a tile's state")
    var tile := console.run("probe.tile " + at)
    var tile_text := ""
    for l in tile:
        tile_text += str(l) + "\n"
    check(tile_text.contains("z=0"), "probe.tile does not report the finest level: %s"
            % tile_text)
    check(tile_text.contains("FINEST") or tile_text.contains("valid clone"),
            "probe.tile does not say which end of the pyramid z=0 is: %s" % tile_text)
    var streamed := console.run("view.stream " + at)
    var stream_text := ""
    for l in streamed:
        stream_text += str(l) + "\n"
    # EITHER OUTCOME IS CORRECT AND ONLY ONE OF THEM IS A NUMBER. A clone with
    # no tiles fetched must say so rather than draw a patch of nothing.
    check(stream_text.contains("patch at z=") or stream_text.contains("no patch:"),
            "view.stream neither built a patch nor said why not: %s" % stream_text)
    if stream_text.contains("patch at z="):
        check(stream_text.contains("rebuilds when the body passes"),
                "view.stream does not say when it will rebuild: %s" % stream_text)
        check(v.ground.patch != null,
                "a patch was drawn that the ground the scatter stands on does not hold")
        console.run("view.stream off")
        check(v.ground.patch == null, "the patch came down on screen and not underfoot")

    # STANDING A BODY STREAMS THE GROUND IT IS ABOUT TO STAND ON, and does
    # NOT open walk mode. The near-field half of the criterion was refusing on
    # a flat triangle that is no longer there; the underfoot half still refuses
    # at 100 m -- 20 s of walking between one height and the next at the stub's
    # speed -- and the guard is unchanged. This is the check that the second
    # sentence stays true now that the first one has moved.
    var emb := console.run("view.embody " + at)
    var emb_text := ""
    for l in emb:
        emb_text += str(l) + "\n"
    check(emb_text.contains("ground: sampled every"),
            "view.embody does not say how finely the ground under the body is drawn: %s"
            % emb_text)
    check(emb_text.contains("walk mode: "), "view.embody does not report walk mode: %s"
            % emb_text)
    check(not emb_text.contains("walk mode: available"),
            "streaming the near field opened walk mode. It must not: the underfoot half of "
            + "the criterion is about metre-scale ground and 100 m tiles are not that. %s"
            % emb_text)
    console.run("view.stream off")

    # An unknown verb is a sentence, not a stack trace.
    var miss := console.run("probe.nonsense")
    check(miss.size() >= 1 and str(miss[0]).contains("no verb"),
            "an unknown verb answered %s" % str(miss))
    print("console: %d verbs answering headless from a named point; view.stream says \"%s\""
            % [console.names().size(), (str(streamed[0]) if streamed.size() > 0 else "nothing")])
    console.free()
    v.queue_free()


# ============================================================================
# A1: the tile pyramid, and what it does and does not open.
# ============================================================================

func test_the_tiles_do_not_decode_with_the_overviews_constants() -> void:
    """THE ONE MISTAKE HERE THAT IS SILENT.

    Both grids resample with `average`, which pulls extremes in by an amount
    that depends on pixel footprint, so the native grid's constants are wider
    than the overview's at both ends. A clipped code is a valid code: decode a
    tile with the overview's `offset_m` / `scale_m_per_step` and the basin's
    real peaks come back flattened with nothing to report it.

    So the pyramid carries its own encoding in its own pin, refuses to run
    without one rather than falling back on the pair it can see, and this
    measures what the wrong pair would have cost."""
    var tp := TilePyramid.load_from()
    if not tp.is_loaded():
        print("tiles: %s -- skipping, and saying so" % tp.why_absent)
        return
    var hf := heightfield()
    check(absf(tp.offset_m - hf.offset_m) > 1.0e-9 or absf(tp.scale_m - hf.scale_m) > 1.0e-12,
            "the tile pin carries the overview's own constants, so either the pyramid was "
            + "vendored from the wrong report or this check has stopped discriminating")

    # What the wrong pair costs, in metres, on real ground.
    var inv := tp.inventory()
    if int(inv["present"]) == 0:
        print("tiles: %d keyed, none fetched -- `python3 tools/fetch_artefacts.py`. "
                % int(inv["keyed"]) + "The checks that need them are not running.")
        return
    var worst := 0.0
    var sampled := 0
    for ty in range(200, 1200, 97):
        for tx in range(200, 900, 89):
            var w := hf.texel_to_world(float(tx), float(ty))
            var at := tp.locate(w.x, w.y)
            if not bool(at["ok"]) or tp.availability(str(at["key"])) != TilePyramid.PRESENT:
                continue
            var right := tp.height_at_world(w.x, w.y)
            if is_nan(right):
                continue
            # The same code read through the overview's pair.
            var code := (right - tp.offset_m) / tp.scale_m
            var wrong := hf.offset_m + code * hf.scale_m
            worst = maxf(worst, absf(right - wrong))
            sampled += 1
    check(sampled > 20, "only %d tile samples could be compared" % sampled)
    check(worst > 1.0, "the two encodings differ by at most %s m over %d samples, so the "
            % [String.num(worst, 3), sampled]
            + "warning they carry is about nothing and one of them is wrong")
    print("tiles: the overview's constants misread this pyramid by up to %s m over %d samples"
            % [String.num(worst, 2), sampled])


func test_an_unwritten_tile_is_empty_ground_and_not_a_missing_fetch() -> void:
    """§5.1a'S DISTINCTION, WHICH IS WHY THE PIN LISTS KEYS AT ALL.

    254 of 600 tiles at z=0 are entirely nodata and the emitter skips them, so
    absent-and-unkeyed is a fact about the basin. Absent-and-keyed is a fact
    about this clone. Reporting both as "no tile" would make a failed fetch
    look like empty ground, which is the one confusion that turns a broken
    transport into a plausible picture."""
    var tp := TilePyramid.load_from()
    if not tp.is_loaded():
        return
    # A corner of the grid the emitter never wrote: z=0 is 20 x 30 tiles and
    # the basin does not fill it.
    check(tp.availability("0/0_0.png") == TilePyramid.EMPTY_GROUND,
            "0/0_0.png is not reported as empty ground: %s" % tp.availability("0/0_0.png"))
    check(tp.availability("0/99_99.png") == TilePyramid.EMPTY_GROUND,
            "a tile outside the grid is not empty ground")
    var keyed := ""
    for k in tp.keys:
        keyed = str(k)
        break
    check(keyed != "", "the pin keys no tiles at all")
    check(tp.availability(keyed) in [TilePyramid.PRESENT, TilePyramid.NOT_FETCHED],
            "a keyed tile reports %s" % tp.availability(keyed))

    var inv := tp.inventory()
    check(int(inv["keyed"]) == 496, "the pin keys %d tiles and the run wrote 496"
            % int(inv["keyed"]))
    check(float(inv["finest_pixel_size_m"]) == 100.0,
            "the finest level is %s m" % String.num(float(inv["finest_pixel_size_m"]), 1))
    # z=0 IS THE FINEST, and reading it the other way loads the coarsest tiles
    # into the near field -- which looks like the pyramid not working rather
    # than like the pyramid being read upside down.
    check(tp.pixel_size_of(0) < tp.pixel_size_of(5),
            "z=0 is not the finest level, so the polarity is being read backwards")
    print("tiles: %d keyed, %d present, %d not fetched, finest %s m, z=0 is finest"
            % [int(inv["keyed"]), int(inv["present"]), int(inv["not_fetched"]),
                    String.num(float(inv["finest_pixel_size_m"]), 0)])


func test_the_pyramid_makes_the_near_field_relief_and_does_not_open_walk_mode() -> void:
    """THE ANSWER TO WHAT THE PYRAMID DOES, PINNED AGAINST THE MEASUREMENT.

    Two blockers were wearing one gate. The pyramid moves one of them by a
    factor of forty and does not touch the other, and this is what stops that
    being reported as "still refuses":

      the near field held ZERO mesh vertices inside the disc a standing body
      sees, and holds sixty-nine ground samples at the pyramid's 100 m;

      the ground still changes only every hundred metres of walking, which is
      twenty seconds at the ruled speed and worse at a real envelope's.

    If the second ever passes here, either a finer product landed or the
    criterion was relaxed -- and the second is the failure this test exists to
    catch, because relaxing a threshold to open a gate buys less than the
    refusal it replaces."""
    var f := FileAccess.open("res://measurements/ground_relief.json", FileAccess.READ)
    if f == null:
        check(false, "no ground_relief.json: run `bash tools/measure_relief.sh`")
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        check(false, "ground_relief.json is not a JSON object")
        return
    var doc: Dictionary = parsed
    if bool(doc.get("refused", false)):
        print("relief: the measurement refused -- %s" % str(doc.get("why", "")))
        return
    var macro: Dictionary = doc["macro_relief"]
    var vertices := float((macro["mesh_vertices_in_disc"] as Dictionary)["p50"])
    var texels := float((macro["native_texels_in_disc"] as Dictionary)["p50"])
    check(vertices <= 1.0, "the drawn mesh has %s vertices in the near field, so the blocker "
            % String.num(vertices, 0) + "measurements/README.md names is no longer what it says")
    check(texels > 20.0, "the pyramid puts only %s ground samples in the same disc"
            % String.num(texels, 0))
    check(texels / maxf(vertices, 1.0) > 20.0,
            "the pyramid improves the near field by less than twentyfold")

    var change_m := float((doc["underfoot"]["metres_between_ground_changes"]
            as Dictionary)["p50"])
    check(change_m > 5.0,
            "the ground now changes every %s m, which would meet the underfoot criterion at "
                    % String.num(change_m, 1)
            + "the ruled 5 m/s. Either a metre-scale product landed -- in which case say so "
            + "and open walk mode deliberately -- or this measurement moved to make it pass.")

    var residual := float((macro["worst_residual_m"] as Dictionary)["p50"])
    check(residual > 1.0, "the drawn surface now sits within %s m of the native grid"
            % String.num(residual, 2))
    print("relief: near field %s mesh vertices against %s native texels; ground changes every "
            % [String.num(vertices, 0), String.num(texels, 0)]
            + "%s m; a plant on the drawn plane stands %s m from the data's own ground (p50)"
                    % [String.num(change_m, 0), String.num(residual, 1)])


# ============================================================================
# B6: specific-rung assets, and the rung boundary.
# ============================================================================

func test_a_node_with_no_asset_draws_its_parent_and_says_it_is_art_debt() -> void:
    """§17.8.6 REQUIRES THE ASSET LOOKUP TO BE THE IDENTITY: every internal node
    of the taxonomy has a representative form, so a node always draws
    something. That is what makes a missing model ART DEBT rather than a
    smaller percept -- if the lookup could fail, a modelling gap would start
    reading as a claim about what the observer earned.

    And the specific forms inherit their parent's parameter ranges EXACTLY. A
    narrower span for a named taxon would be calibration this client authored
    and no producer sent."""
    var fs := family_set()
    if not fs.is_loaded():
        return
    var nodes := fs.nodes()
    check(nodes.size() >= 2, "only %d specific-rung nodes; B6 asks for two or three"
            % nodes.size())

    var parents := {}
    for node in nodes:
        var r := fs.resolve(str(node))
        check(bool(r["ok"]), "node %s resolves to nothing" % str(node))
        check(str(r["rung"]) == FamilySet.SPECIFIC_RUNG,
                "node %s draws at %s" % [str(node), str(r["rung"])])
        check(not bool(r["art_debt"]), "node %s is reported as art debt and has an asset"
                % str(node))
        var parent := fs.parent_of(str(node))
        check(fs.has(parent), "node %s refines %s, which is not a family" % [str(node), parent])
        parents[parent] = int(parents.get(parent, 0)) + 1
        # RANGES INHERITED EXACTLY.
        for param in ["height_m", "crown_m"]:
            var mine := fs.range_of(str(node), param)
            var theirs := fs.range_of(parent, param)
            check(mine == theirs, "node %s narrows %s against its parent %s: %s vs %s"
                    % [str(node), param, parent, str(mine), str(theirs)])
        check(fs.triangles_of(str(node)) > 0,
                "node %s prices at zero triangles" % str(node))

    # TWO SHARING A PARENT is what makes the lookup a node lookup rather than a
    # boolean, so it is asserted rather than assumed.
    var shared := false
    for parent in parents:
        if int(parents[parent]) >= 2:
            shared = true
    check(shared, "no two specific nodes share a parent, so nothing here distinguishes "
            + "`which node` from `refined or not`")

    # A NODE THAT DOES NOT EXIST falls back and says so.
    fs.specific["unmodelled_taxon"] = {"life_form": "tree"}
    var debt := fs.resolve("unmodelled_taxon")
    check(bool(debt["ok"]), "a node with no asset resolved to nothing at all")
    check(str(debt["node_drawn"]) == "tree" and str(debt["rung"]) == FamilySet.LIFE_FORM_RUNG,
            "a node with no asset drew %s at %s" % [str(debt["node_drawn"]), str(debt["rung"])])
    check(bool(debt["art_debt"]) and str(debt["why"]).contains("ART DEBT"),
            "a missing model is not reported as art debt")
    check(fs.triangles_of("unmodelled_taxon") == fs.triangles_of("tree"),
            "a node falling back to its parent is not priced at the parent's triangles")
    fs.specific.erase("unmodelled_taxon")
    print("families: %d specific nodes over %d parents, ranges inherited, missing asset is "
            % [nodes.size(), parents.size()] + "art debt and draws the parent")


func test_the_mock_earns_a_rung_and_its_boundary_is_cell_shaped() -> void:
    """THE FINDING B6 PRODUCED, PINNED SO IT IS NOT RE-DISCOVERED.

    An earned function is a distance -- `distance_v0`'s shape, and the right
    shape for SUBJECTS, which carry their own positions. Channel 1 does not:
    it is keyed by residence cell, and a cell in this basin averages 126 km2.
    So the finest rung boundary channel 1 can express for flora is a CELL
    BOUNDARY, and a metre-scale threshold has no key to land on.

    That is a fact about the wire and not about the mock, which is why it is
    asserted here rather than left in a comment."""
    var fs := family_set()
    var fl := fixture()
    if not fs.is_loaded() or fs.nodes().is_empty():
        return
    var base := FixturePassthrough.over(fl)
    var mock := MockProducer.over(base, fs)
    check(mock.is_ready(), "the mock producer did not come up")

    # A synthetic cell layout: cells on a 10 km lattice, which is about what
    # this basin's are.
    var centres := {}
    for i in 6:
        for j in 6:
            centres["cell|%d_%d" % [i, j]] = Vector2(float(i) * 10000.0, float(j) * 10000.0)
    var observer := _dev_observer()
    observer["ground_point"] = PackedFloat64Array([0.0, 0.0, 0.0])
    var b := mock.bundle_for(fl.windows[0], 0, observer, centres)
    check(str(b.producer.get("kind", "")) == MockProducer.KIND,
            "the bundle does not stamp the mock as its producer")
    check(str((b.producer.get("provenance", {}) as Dictionary).get("_fake", "")).length() > 20,
            "the mock does not say its constants are invented")

    # PRESENT ONLY WHERE EARNED. An overlay everywhere is the same statement as
    # no overlay at all.
    check(not b.refinements.is_empty(), "the mock refined nothing at all")
    var refined_cells := {}
    for key in b.refinements:
        var parts := str(key).split("|")
        var cell := "%s|%s" % [str(parts[0]), str(parts[1])]
        refined_cells[cell] = true
        var node := str(b.refinements[key])
        check(fs.parent_of(node) == str(parts[2]),
                "%s refines %s to %s, whose parent is %s"
                % [str(key), str(parts[2]), node, fs.parent_of(node)])
    check(refined_cells.size() < centres.size(),
            "every cell was refined, so there is no boundary and this is a passthrough "
            + "wearing a mock's name")
    for cell in refined_cells:
        var c: Vector2 = centres[cell]
        check(c.length() <= MockProducer.SPECIFIC_WITHIN_M,
                "%s is %s m out and was refined inside a %s m rule"
                % [str(cell), String.num(c.length(), 0),
                        String.num(MockProducer.SPECIFIC_WITHIN_M, 0)])

    # DETERMINISTIC: same world, same observer, same moment, same bytes.
    var again := mock.bundle_for(fl.windows[0], 0, observer, centres)
    check(JSON.stringify(b.refinements) == JSON.stringify(again.refinements),
            "two bundles for one moment refined differently")

    # THE BOUNDARY IS A CELL BOUNDARY, which is the finding. Moving the
    # observer a few hundred metres changes nothing; moving it a cell does.
    observer["ground_point"] = PackedFloat64Array([300.0, 0.0, 0.0])
    var nudged := mock.bundle_for(fl.windows[0], 0, observer, centres)
    check(JSON.stringify(nudged.refinements) == JSON.stringify(b.refinements),
            "a 300 m step changed the overlay. Channel 1 is keyed by cell and a cell here is "
            + "about eleven kilometres across, so a metre-scale boundary is not expressible "
            + "-- if this passes, the key space changed and the finding is stale.")
    observer["ground_point"] = PackedFloat64Array([30000.0, 0.0, 30000.0])
    var far := mock.bundle_for(fl.windows[0], 0, observer, centres)
    check(JSON.stringify(far.refinements) != JSON.stringify(b.refinements),
            "moving three cells away changed nothing, so the earned function is not a "
            + "function of where the observer is")
    print("mock: %d of %d cells refined within %s m; a 300 m step moves nothing and three "
            % [refined_cells.size(), centres.size(),
                    String.num(MockProducer.SPECIFIC_WITHIN_M, 0)]
            + "cells moves the boundary")


func test_no_subject_is_drawn_at_two_rungs_and_the_guard_can_fire() -> void:
    """§17.8.6: BLEND WITHIN A RUNG, SWITCH BETWEEN RUNGS.

    No frame may render one subject at two rungs. Today that is a property of
    the placement rather than a hope about it -- the node is a function of
    (cell, life form), so a boundary falls between cells and never inside one,
    and each plant is written into exactly one MultiMesh.

    WHICH IS EXACTLY WHY THE CHECK HAS TO BE SHOWN A FAILURE FROM SOMEWHERE
    ELSE. A guard whose only exercise is a path that cannot produce a violation
    reports the same green as a broken one. The production path is asserted
    clean; the predicate is handed a contradiction."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    v.bind_families()
    v.show_field("deepest_winter", "band.pft_fractions", 45)
    var set_up := v.set_producer(MockProducer.KIND)
    check(bool(set_up["ok"]), "the mock producer would not select: %s" % str(set_up.get("why", "")))
    if not bool(set_up["ok"]):
        v.queue_free()
        return

    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    v.observer["ground_point"] = PackedFloat64Array([centre.x, 0.0, centre.y])
    var r := v.scatter_at(centre)
    check(bool(r.get("ok", false)), "no scatter: %s" % str(r.get("why", "")))
    if not bool(r.get("ok", false)):
        v.queue_free()
        return

    var rungs: Dictionary = r["rungs"]
    check(int(rungs["subjects_at_two_rungs"]) == 0,
            "%d subjects were drawn at two rungs in one frame: %s"
            % [int(rungs["subjects_at_two_rungs"]), str(rungs["examples"])])
    var drawn: Dictionary = rungs["drawn_by_rung"]
    check(drawn.has(FamilySet.SPECIFIC_RUNG),
            "the mock earned a specific rung and nothing was drawn at it: %s" % str(drawn))
    check(int(drawn.get(FamilySet.SPECIFIC_RUNG, 0)) > 0,
            "zero instances at the specific rung")

    # PLACEMENT DID NOT MOVE. A rung change decides which asset draws a plant;
    # it must never decide where the plant stands, or earning a rung would
    # re-place the whole cell -- §16.6's defect through the one door left open.
    var refined_digest: Dictionary = (r["placement"] as Dictionary)["digest"]
    v.set_producer(FixturePassthrough.KIND)
    var plain := v.scatter_at(centre)
    check(bool(plain.get("ok", false)), "the passthrough build failed")
    if bool(plain.get("ok", false)):
        var plain_digest: Dictionary = (plain["placement"] as Dictionary)["digest"]
        check(str(refined_digest.get("all", "")) == str(plain_digest.get("all", "")),
                "the stand moved when the rung changed. Placement is keyed on the life form "
                + "and must stay keyed on it: a refined node in the key would re-place every "
                + "plant in the cell.")
        var plain_rungs: Dictionary = plain["rungs"]
        check(not (plain_rungs["drawn_by_rung"] as Dictionary).has(FamilySet.SPECIFIC_RUNG),
                "the passthrough drew something at the specific rung, and it earns nothing")

    # THE PREDICATE, SHOWN A CONTRADICTION.
    var seen := {}
    check(not VegetationScatter.contradicts(seen, "cell|1|tree", "aspen"),
            "the first assignment for a key was reported as a contradiction")
    check(not VegetationScatter.contradicts(seen, "cell|1|tree", "aspen"),
            "repeating the same assignment was reported as a contradiction")
    check(VegetationScatter.contradicts(seen, "cell|1|tree", "needleleaf_evergreen_subalpine"),
            "one cell assigned two nodes was NOT reported, so this guard's green means "
            + "nothing at all")
    print("rungs: %s drawn, %d subjects at two rungs, and the predicate fires on a "
            % [str(drawn), int(rungs["subjects_at_two_rungs"])] + "synthetic contradiction")
    v.queue_free()


func test_walking_the_boundary_switches_the_rung_once_and_never_both() -> void:
    """THE FIRST REAL TRANSDUCER TEST: walk a rung boundary and watch the drawn
    rung change.

    Monotone approach, so a switch back is a defect rather than terrain: the
    earned function is a distance, so once a cell is inside it, walking further
    in cannot put it out. What is asserted is that the rung DOES change -- a
    boundary nobody crosses tests nothing -- that it changes once, and that no
    step draws the same ground at both rungs."""
    var fs := family_set()
    var fl := fixture()
    if not fs.is_loaded() or fs.nodes().is_empty():
        return
    var mock := MockProducer.over(FixturePassthrough.over(fl), fs)
    var centres := {"target|0": Vector2(0.0, 0.0)}
    var observer := _dev_observer()

    var seen: Array = []
    var switches := 0
    var last := ""
    var step := MockProducer.SPECIFIC_WITHIN_M / 8.0
    for i in 20:
        var away := MockProducer.SPECIFIC_WITHIN_M * 2.0 - float(i) * step
        observer["ground_point"] = PackedFloat64Array([away, 0.0, 0.0])
        var b := mock.bundle_for(fl.windows[0], 0, observer, centres)
        var here := ""
        for key in b.refinements:
            if str(key).begins_with("target|0|"):
                here = str(b.refinements[key])
        var rung := FamilySet.LIFE_FORM_RUNG if here == "" else fs.rung_of(here)
        seen.append(rung)
        if last != "" and rung != last:
            switches += 1
        last = rung
    check(switches == 1, "the rung changed %d times over a monotone approach: %s"
            % [switches, str(seen)])
    check(str(seen[0]) == FamilySet.LIFE_FORM_RUNG,
            "the walk started inside the boundary, so it never crossed one")
    check(str(seen[seen.size() - 1]) == FamilySet.SPECIFIC_RUNG,
            "the walk ended outside the boundary")

    # THE TRANSITION LINE a person reads, and the leak it exists to show.
    var clean := PerceptProbe.transition(FamilySet.SPECIFIC_RUNG, FamilySet.LIFE_FORM_RUNG, 0)
    check(bool(clean["changed"]) and not bool(clean["leak"]),
            "a rung change is being reported as a leak, and crossing a boundary is the "
            + "system working")
    check(str(clean["line"]).contains("switched"), "the line does not say a switch happened")
    var leaking := PerceptProbe.transition(FamilySet.SPECIFIC_RUNG, FamilySet.SPECIFIC_RUNG, 3)
    check(bool(leaking["leak"]) and str(leaking["line"]).contains("TWO RUNGS"),
            "a subject drawn at two rungs does not show in the transition line")
    print("boundary: %d switch over %d steps of a monotone approach, and the transition line "
            % [switches, seen.size()] + "tells a switch from a leak")


# ============================================================================
# Terrain stage 0: the detail function, and the constraint the rest rests on.
# ============================================================================

func detail_field() -> DetailField:
    return DetailField.load_from(heightfield(), DetailField.ROWS_PATH, 0.0,
            TerrainLayers.load_from())


func test_the_detail_is_exactly_zero_at_every_parent_sample() -> void:
    """THE CONSTRAINT THE WHOLE METHOD RESTS ON, and the one worth asserting
    hardest: detail refines and never contradicts.

    The function reproduces the shipped lattice values EXACTLY at the lattice,
    so every consumer that samples there -- slope, aspect, routing, zonal
    statistics, energy budgets -- is untouched by its existence. Not `within a
    tolerance`: exactly, because the mechanism is subtracting the function's
    own coarse component, and if that is right the difference is zero and if it
    is wrong no tolerance makes it safe.

    AND A ZERO FUNCTION WOULD PASS THIS, so the control is that the detail is
    NOT zero away from the lattice."""
    var hf := heightfield()
    var df := detail_field()
    check(df.is_loaded(), "the detail field did not load: %s" % df.why_absent)
    if not df.is_loaded():
        return

    var nodes := 0
    var worst := 0.0
    for ty in range(300, 1000, 37):
        for tx in range(200, 800, 41):
            var w := hf.texel_to_world(float(tx), float(ty))
            if is_nan(hf.height_at_world(w.x, w.y)):
                continue
            nodes += 1
            worst = maxf(worst, absf(df.detail_at(w)))
            var lattice := hf.height_at_world(w.x, w.y)
            check(df.height_at(w) == lattice,
                    "at a parent node the function gives %s and the lattice gives %s"
                    % [String.num(df.height_at(w), 12), String.num(lattice, 12)])
    check(nodes > 100, "only %d parent nodes were checked" % nodes)
    check(worst == 0.0, "the detail is %s m at a parent node, not zero"
            % String.num(worst, 15))

    # THE CONTROL. A function that is zero everywhere satisfies the assertion
    # above and refines nothing.
    var moved := 0.0
    var away := 0
    for ty2 in range(300, 1000, 37):
        var w2 := hf.texel_to_world(float(ty2) + 0.37, 500.41)
        if is_nan(hf.height_at_world(w2.x, w2.y)):
            continue
        away += 1
        moved = maxf(moved, absf(df.detail_at(w2)))
    check(away > 5 and moved > 0.001,
            "the detail is at most %s m anywhere between nodes, so it is a zero function and "
                    % String.num(moved, 6)
            + "the exactness above is about nothing")
    print("detail: exactly zero at %d parent nodes, up to %s m between them, finest %s m"
            % [nodes, String.num(moved, 3), String.num(df.finest_m, 3)])


func test_the_detail_tells_a_playa_from_a_talus_slope() -> void:
    """`REASONABLE FEATURES` HAS TO BE A MEASURED MATCH RATHER THAN TASTE, and
    a bounded-but-flat synthesizer must fail.

    The owner's acceptance criterion is a statement about SPREAD -- a playa is
    smooth and rocky slopes are rough -- so bounds cannot be the test. A
    function adding a constant offset inside its amplitude bound satisfies
    every range check and tells the two apart not at all. The variogram is what
    distinguishes them, and this is that measurement at gate scale."""
    var hf := heightfield()
    var df := detail_field()
    if not df.is_loaded():
        return
    var centre := Vector2.INF
    for ty in range(400, 1100, 11):
        var cand := hf.texel_to_world(500.0, float(ty))
        if not is_nan(hf.height_at_world(cand.x, cand.y)):
            centre = cand
            break
    if centre == Vector2.INF:
        check(false, "no valid ground to measure a variogram over")
        return

    var smooth := _semivariance(df, centre, "playa", 32.0)
    var rough := _semivariance(df, centre, "talus", 32.0)
    check(rough > 0.0 and smooth > 0.0, "one of the two classes has no variance at all")
    check(rough / maxf(smooth, 1e-12) > 4.0,
            "talus and playa differ by %sx at a 32 m lag. Their declared amplitudes differ by "
                    % String.num(rough / maxf(smooth, 1e-12), 2)
            + "fortyfold, so a synthesizer this close to flat discriminates nothing.")

    # A VARIOGRAM THAT RISES WITH LAG, which is what a spectral claim means.
    var near := _semivariance(df, centre, "talus", 2.0)
    check(rough > near, "the talus variogram does not rise between a 2 m and a 32 m lag, so "
            + "the field is white noise wearing a spectrum's parameters")

    # THE FLAT CONTROL, in the gate rather than only in the tool.
    check(_semivariance_of_constant(0.8) == 0.0,
            "a constant offset was measured as having variance, so this instrument cannot see "
            + "the defect it exists for")

    # And the artefact agrees with the gate.
    var f := FileAccess.open("res://measurements/detail_variogram.json", FileAccess.READ)
    if f != null:
        var parsed = JSON.parse_string(f.get_as_text())
        if typeof(parsed) == TYPE_DICTIONARY:
            var doc: Dictionary = parsed
            check(bool((doc.get("verdict", {}) as Dictionary).get("ok", false)),
                    "the recorded variogram run failed: %s"
                    % str((doc.get("verdict", {}) as Dictionary).get("why", "")))
            check(str(doc.get("parameters_are", "")).contains("PLACEHOLDER"),
                    "the artefact does not say its parameters are invented")
    print("detail: talus/playa semivariance %sx at a 32 m lag, rising with lag, and a constant "
            % String.num(rough / maxf(smooth, 1e-12), 0) + "offset measures zero")


## Half the mean squared difference between pairs a fixed distance apart, over
## the detail term alone. The lattice's own variation is metres where the
## detail's is centimetres, so scoring the sum would measure the lattice --
## which a first run of the tool did, reporting every class within 2% of every
## other.
func _semivariance(df: DetailField, centre: Vector2, landform: String, lag: float) -> float:
    var total := 0.0
    var n := 0
    for i in 200:
        var u := StableHash.unit(StableHash.of3(i, int(lag), 3))
        var v := StableHash.unit(StableHash.of3(i, int(lag), 5))
        var a := centre + Vector2((u - 0.5) * 400.0, (v - 0.5) * 400.0)
        var b := a + Vector2(lag, 0.0)
        var da := df.detail_at(a, landform)
        var db := df.detail_at(b, landform)
        total += (da - db) * (da - db)
        n += 1
    return 0.0 if n == 0 else 0.5 * total / float(n)


func _semivariance_of_constant(value: float) -> float:
    var total := 0.0
    for i in 50:
        total += (value - value) * (value - value)
    return 0.5 * total / 50.0


func test_one_ground_for_every_consumer_or_none_at_all() -> void:
    """THE WRONG-GROUND DEFECT, PREVENTED AT THE SCALE BELOW THE ONE THAT
    CAUGHT IT.

    Plants were once placed on the heightfield while the mesh drew a
    triangulation of it; the two disagree by a mean of 36 m and up to 640 m,
    which is invisible from a map camera and the whole picture at eye level. A
    metre-scale detail term reopens exactly that class one scale down.

    So there is one object both consumers ask, and it REFUSES to answer when
    the mesh in front of it was built with a different detail term. Detail is
    on for both or for neither; there is no arrangement in which one has it."""
    var hf := heightfield()
    var tm := TerrainMesh.new()
    tm.build(hf, 8, 1.0)
    var plain := GroundSurface.over(hf, tm, null)
    check(plain.agrees_with_mesh(), "a mesh built with no detail disagrees with no detail")
    # SOMEWHERE THE MESH ACTUALLY DRAWS. A point over one of the basin's holes
    # gives NAN from both paths and would let every comparison below pass by
    # comparing nothing.
    var w := Vector2.INF
    for ty in range(400, 1100, 13):
        var cand := hf.texel_to_world(500.0, float(ty))
        if not is_nan(tm.drawn_surface_y(cand, hf)):
            w = cand
            break
    check(w != Vector2.INF, "no point on the mesh could be found to compare on")
    if w == Vector2.INF:
        return
    check(not is_nan(plain.surface_at(w)), "the agreeing surface refused: %s" % plain.why_refused)
    check(plain.surface_at(w) == tm.drawn_surface_y(w, hf),
            "the surface a plant stands on is not the surface the mesh draws")

    # THE REFUSAL, which is the whole guard.
    var df := detail_field()
    var mismatched := GroundSurface.over(hf, tm, df)
    check(not mismatched.agrees_with_mesh(),
            "a surface holding a detail term agrees with a mesh built without one")
    check(is_nan(mismatched.surface_at(w)),
            "a surface the mesh does not draw answered with a height anyway")
    check(mismatched.why_refused.contains("wrong-ground"),
            "the refusal does not say what it is preventing: %s" % mismatched.why_refused)

    # AND WITH DETAIL ON BOTH SIDES it agrees again -- a gate, not a wall.
    var detailed := TerrainMesh.new()
    detailed.build(hf, 8, 1.0, -1.0, df)
    var both := GroundSurface.over(hf, detailed, df)
    check(both.agrees_with_mesh(), "detail on both sides still disagrees")
    check(not is_nan(both.surface_at(w)), "the detailed surface refused: %s" % both.why_refused)

    # THE SCATTER REFUSES LOUDLY rather than placing nothing. A silent empty
    # stand reads as no vegetation here rather than as a mismatch.
    var sc := VegetationScatter.new()
    sc.bind(hf, residence(), fixture(), family_set(), FrameCost.load_from(), tm)
    sc.ground = GroundSurface.over(hf, tm, df)
    var r := sc.build("deepest_winter", 45, w, 1000.0)
    check(not bool(r.get("ok", true)), "the scatter built on a surface the mesh does not draw")
    check(str(r.get("why", "")).contains("wrong-ground"),
            "the scatter's refusal does not name the defect: %s" % str(r.get("why", "")))
    print("ground: one surface for both consumers, refused when the mesh carries a different "
            + "detail term, and the scatter refuses loudly rather than placing nothing")


func test_the_detail_rows_say_that_they_are_invented() -> void:
    """PLACEHOLDER PARAMETERS HAVE TO ANNOUNCE THEMSELVES, everywhere a reader
    might quote one. The row schema is the deliverable; the values are not, and
    a number that does not say it is invented becomes a number somebody cites.

    The same discipline the mock producer's constants carry, one lane over."""
    var f := FileAccess.open(DetailField.ROWS_PATH, FileAccess.READ)
    check(f != null, "no detail rows at %s" % DetailField.ROWS_PATH)
    if f == null:
        return
    var text := f.get_as_text()
    var parsed = JSON.parse_string(text)
    check(typeof(parsed) == TYPE_DICTIONARY, "the rows are not a JSON object")
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var doc: Dictionary = parsed
    # THE KEYS MOVED WITH THE ARTEFACT AND THE PROPERTY DID NOT. The rows are
    # emitted now rather than hand-kept, so the warning is asked for by
    # SUBSTANCE and not by key: pinning a key turns a rename into a failure and
    # a deletion into a pass, and this file has now seen both.
    # BY SUBSTANCE, AND NOT BY A WORD EITHER. The first version of this asked
    # for the key; the second asked for the literal string "INVENTED", and the
    # headline came back saying "EVERY VALUE IN THIS FILE IS A PLACEHOLDER".
    # That is the same mistake one level down -- a check pinned to the wording
    # of the thing it is checking fails on a rewrite and passes on a deletion.
    # What is asked for is that some top-level field says these values are not
    # measured, in whichever of the two words the emitter chose.
    var headline := ""
    for k in doc:
        var v = doc[k]
        if typeof(v) != TYPE_STRING:
            continue
        var up := str(v).to_upper()
        if up.contains("INVENTED") or up.contains("PLACEHOLDER"):
            headline = str(k)
            break
    check(headline != "",
            "no top-level field in the rows says its values are placeholders. A number that "
            + "does not say it is invented becomes a number somebody cites.")
    check(str(doc.get("_replaced_by", doc.get("_values_land_when", ""))).length() > 20,
            "the rows do not say what replaces them")
    check(str((doc.get("classifier", {}) as Dictionary).get("_FAKE", "")).length() > 20,
            "the classifier's thresholds do not say they are invented")
    check(str((doc.get("hand_taper", {}) as Dictionary).get("_FAKE", "")).length() > 20,
            "the HAND taper's constants do not say they are invented")
    # AND THE STATE OF THE HEADLINE IS REPORTED EVERY RUN RATHER THAN ASSERTED
    # ONCE. The artefact carried `_values_are_placeholders` with the sentence
    # "EVERY NUMBER IN THIS FILE IS INVENTED" at `magisteria@060cddd` and
    # carries the same key set to `null` at `4af865c` -- the field survived and
    # its content did not, which is the failure mode a key-pinned check cannot
    # see and a reader meets first. Printed, so it cannot go quiet.
    if headline == "":
        print("detail rows: NO TOP-LEVEL PLACEHOLDER WARNING. `_values_are_placeholders` is "
                + "present and null in this cut; the per-section notes still carry it. "
                + "Reported rather than asserted, and raised with the producing side.")

    # THE OWNER'S ACCEPTANCE CRITERION IS TWO LITERAL ROWS.
    var landforms: Dictionary = doc.get("landforms", {})
    check(landforms.has("playa") and landforms.has("talus"),
            "the acceptance criterion names a playa and rocky slopes and they are not rows")
    check(DetailField.scalar_of(landforms["talus"] as Dictionary, "amplitude_m", 0.0)
                    > 10.0 * DetailField.scalar_of(
                            landforms["playa"] as Dictionary, "amplitude_m", 0.0),
            "the rough class is not much rougher than the smooth one, so the rows do not "
            + "express the criterion they were written for")

    # AND THE TARGET IS SUB-METRE, not the 1 m the sketch first proposed: real
    # 1 m ground passes the underfoot criterion at the stub's speed and fails
    # at the 0.7 m/s a real envelope reports.
    for name in landforms:
        var finest := DetailField.scalar_of(landforms[name] as Dictionary, "finest_wavelength_m", 99.0)
        check(finest < 1.0, "%s synthesises down to %s m, and 1 m ground fails the underfoot "
                % [str(name), String.num(finest, 3)]
                + "criterion at a load-bearing envelope's speed")
    var df := detail_field()
    check(df.orientation_note().contains("NOT implemented"),
            "the orientation source is not recorded as unimplemented")
    print("detail rows: saying they are invented in %d places (headline: %s), playa and "
            % [(3 if headline == "" else 4), (headline if headline != "" else "MISSING")]
            + "talus are literal rows, and every class synthesises below a metre")


# ============================================================================
# Streaming: the pyramid into the drawn mesh.
# ============================================================================

## A place with the pyramid under it, and everything a patch needs to be built
## there. Empty when the tiles are not fetched, which is a valid clone.
func streaming_place() -> Dictionary:
    var tp := TilePyramid.load_from()
    if not tp.is_loaded() or int(tp.inventory()["present"]) == 0:
        return {}
    var hf := heightfield()
    var tm := TerrainMesh.new()
    tm.build(hf, 4, 1.0)
    var res := TileResidency.over(tp)
    # SOMEWHERE THE COARSE MESH DRAWS AND THE PYRAMID HAS TILES. Both, because
    # a patch over a hole in either is a patch with nothing in it, and a test
    # that built one would pass by comparing nothing.
    for ty in range(300, 1200, 29):
        for tx in range(200, 900, 31):
            var w := hf.texel_to_world(float(tx), float(ty))
            if is_nan(tm.drawn_surface_y(w, hf)):
                continue
            var z := res.level_for(w)
            if z != 0:
                continue
            var c := res.snap(w, z)
            if not bool(res.pump(c, z, 16)["ready"]):
                continue
            if is_nan(tp.height_at_world(c.x, c.y, z)):
                continue
            return {"tp": tp, "hf": hf, "tm": tm, "res": res, "centre": c, "z": z}
    return {}


func test_the_finest_level_is_the_one_chosen_and_z_zero_is_it() -> void:
    """THE INVERTED POLARITY, ASSERTED RATHER THAN COMMENTED.

    `z = 0` is the FINEST level here and the coarsest in a web map. A streaming
    layer that has it backwards loads 3,200 m tiles into the near field, which
    looks exactly like a pyramid that did not help -- so it would be read as
    the pyramid failing rather than as being read upside down.

    The control is the one that matters: a search from the other end returns a
    different level, so this check is discriminating and not agreeing with
    everything."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var tp: TilePyramid = p["tp"]
    var res: TileResidency = p["res"]
    var w: Vector2 = p["centre"]
    check(tp.pixel_size_of(0) < tp.pixel_size_of(5),
            "z=0 is not finer than z=5, so the pin's polarity is not what the pyramid claims")
    var chosen := res.level_for(w)
    check(chosen == 0, "the finest fetched level here is z=%d and not z=0" % chosen)
    # THE CONTROL. Whatever a coarse-first search would have returned, it is
    # not this -- so "z=0" is a result rather than the only possible answer.
    var coarsest := -1
    for lv in tp.levels:
        coarsest = maxi(coarsest, int((lv as Dictionary)["z"]))
    check(coarsest != chosen,
            "every level is the same level, so choosing the finest cannot be checked")
    check(tp.pixel_size_of(chosen) * 30.0 < tp.pixel_size_of(coarsest) * 1.0 + 3200.0,
            "the chosen level is not finer than the coarsest one")
    print("streaming: level chosen here is z=%d at %s m, against z=%d at %s m at the other end"
            % [chosen, String.num(tp.pixel_size_of(chosen), 0), coarsest,
                    String.num(tp.pixel_size_of(coarsest), 0)])


func test_a_tile_in_flight_is_not_empty_ground() -> void:
    """FOUR STATES, AND THE FOURTH IS THE ONE STREAMING ADDS.

    EMPTY_GROUND is a fact about the basin, NOT_FETCHED a fact about this
    clone, NOT_LOADED a fact about this moment -- and only the last resolves on
    its own. A tile in flight that reads as empty ground puts the coarse
    surface across part of the near field and reports a healthy build: the
    picture flattens while every count says fine.

    So the patch is not built at all until every tile is resident, and `pump`
    is what says when."""
    var tp := TilePyramid.load_from()
    if not tp.is_loaded():
        print("streaming: %s -- skipping" % tp.why_absent)
        return
    check(tp.availability("0/0_0.png") == TilePyramid.EMPTY_GROUND,
            "a corner the emitter never wrote is not empty ground")
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    # A FRESH PYRAMID, so nothing is decoded yet and NOT_LOADED is real rather
    # than arranged.
    var cold := TilePyramid.load_from()
    var res := TileResidency.over(cold)
    var c: Vector2 = p["centre"]
    var keys := res.keys_for(c, 0)
    check(keys.size() >= 1, "a patch here touches no tiles at all")
    var present := ""
    for k in keys:
        if cold.availability(k) == TilePyramid.PRESENT:
            present = k
            break
    check(present != "", "no tile under this patch is fetched, so the state cannot be checked")
    if present == "":
        return
    check(res.state(present) == TileResidency.NOT_LOADED,
            "a fetched but undecoded tile reports %s rather than NOT_LOADED" % res.state(present))
    check(res.state(present) != TilePyramid.EMPTY_GROUND,
            "a tile in flight is being reported as ground that was never there")
    # BUDGET ZERO: nothing decodes, and the patch is refused rather than built
    # over what has not arrived.
    var starved := res.pump(c, 0, 0)
    check(not bool(starved["ready"]),
            "a pump that decoded nothing reported itself ready to build")
    check(int(starved["not_loaded"]) >= 1, "the in-flight tile was not counted")
    check(int(starved["decoded_now"]) == 0, "a zero budget decoded %d tiles"
            % int(starved["decoded_now"]))
    var fed := res.pump(c, 0, 16)
    check(bool(fed["ready"]), "a pump with a budget did not reach ready")
    check(res.state(present) == TileResidency.RESIDENT,
            "a decoded tile is not reported resident")
    check(cold.decodes >= 1, "the pyramid reports no decodes after warming one")
    print("streaming: four states -- empty ground, not fetched, %d in flight before the pump "
            % int(starved["not_loaded"]) + "and resident after it")


func test_the_patch_rim_lies_on_the_coarse_plane_exactly() -> void:
    """THE SEAM, AND IT IS AN EQUALITY RATHER THAN A TOLERANCE.

    The blend weight is exactly zero on the outermost ring, so a rim vertex is
    the coarse surface's own value at that position -- not close to it. The
    coarse surface between its samples is planar, so a rim vertex evaluated
    there lies exactly on the triangle it overlaps and there is no crack.

    Chebyshev and not radial, which is the half of this that is easy to get
    wrong: a radial weight reaches zero at the four edge midpoints and not at
    the corners, so the seam holds along four lines and gaps at four points.

    The control is that the interior is NOT the coarse surface. A patch that
    reproduced it everywhere would pass the rim check and refine nothing."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var res: TileResidency = p["res"]
    var hf: Heightfield = p["hf"]
    var tm: TerrainMesh = p["tm"]
    var np := NearFieldPatch.build(res, p["centre"], 0, hf, tm, null)
    check(np.is_built(), "the patch did not build: %s" % np.why_refused)
    if not np.is_built():
        return
    check(absf(np.weight_at(0, 0)) == 0.0, "the corner of the rim is not weighted zero")
    check(absf(np.weight_at((np.n - 1) / 2, 0)) == 0.0,
            "the middle of an edge is not weighted zero")
    check(np.weight_at((np.n - 1) / 2, (np.n - 1) / 2) == 1.0,
            "the centre of the patch is not fully refined")
    var rim_checked := 0
    var rim_off := 0
    for i in np.n:
        for j in [0, np.n - 1]:
            for pair in [[i, int(j)], [int(j), i]]:
                var a: int = pair[0]
                var b: int = pair[1]
                var y := np.height_at_node(a, b)
                var c := tm.drawn_surface_y(np.world_of(a, b), hf)
                if is_nan(y) or is_nan(c):
                    continue
                rim_checked += 1
                if y != c:
                    rim_off += 1
    check(rim_checked > 100, "only %d rim vertices could be compared" % rim_checked)
    check(rim_off == 0, "%d of %d rim vertices are not exactly on the coarse plane"
            % [rim_off, rim_checked])
    # THE CONTROL: the interior is somewhere else, or the patch refines nothing.
    var mid := (np.n - 1) / 2
    var moved := 0
    for k in range(mid - 20, mid + 20):
        var y2 := np.height_at_node(k, mid)
        var c2 := tm.drawn_surface_y(np.world_of(k, mid), hf)
        if not is_nan(y2) and not is_nan(c2) and absf(y2 - c2) > 1.0:
            moved += 1
    check(moved > 5, "the patch's interior sits on the coarse plane at %d of 40 nodes, so it "
            % (40 - moved) + "is reproducing the surface rather than refining it")
    print("streaming: %d rim vertices exactly on the coarse plane, %d of 40 interior nodes "
            % [rim_checked, moved] + "off it by more than a metre")


func test_a_rebuild_moves_no_shared_vertex() -> void:
    """WHEN TO REBUILD, ANSWERED SO THAT IT DOES NOT MATTER.

    Every patch's centre is snapped to the level's own texel grid, so two
    patches built around two observer positions sample the SAME world
    positions. What they share, they share exactly -- a rebuild adds rim and
    drops rim and moves nothing in between. Without the snap each rebuild
    resamples half a texel over and the near field shimmers on every step.

    The hysteresis distance is derived rather than tuned: what is left of the
    half extent once the blend ring and the body's own near field are taken out
    of it. Stand anywhere inside it and the whole near field is on fully
    refined ground."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var res: TileResidency = p["res"]
    var hf: Heightfield = p["hf"]
    var tm: TerrainMesh = p["tm"]
    var c0: Vector2 = p["centre"]
    var c1 := res.snap(c0 + Vector2(700.0, -400.0), 0)
    check(c1 != c0, "the second observer position snapped to the same node, so two patches "
            + "cannot be compared")
    res.pump(c1, 0, 16)
    var a := NearFieldPatch.build(res, c0, 0, hf, tm, null)
    var b := NearFieldPatch.build(res, c1, 0, hf, tm, null)
    check(a.is_built() and b.is_built(), "one of the two patches did not build")
    if not (a.is_built() and b.is_built()):
        return
    var shared := 0
    var differing := 0
    for j in a.n:
        for i in a.n:
            # ONLY WHERE BOTH ARE FULLY REFINED. A node in one patch's blend
            # ring and the other's interior is SUPPOSED to differ; that is the
            # ramp working, not a rebuild moving ground.
            if a.weight_at(i, j) < 1.0:
                continue
            var w := a.world_of(i, j)
            if not b.contains(w):
                continue
            var g := b._grid_of(w)
            var bi := int(round(g.x))
            var bj := int(round(g.y))
            if b.weight_at(bi, bj) < 1.0:
                continue
            if b.world_of(bi, bj) != w:
                continue
            var ya := a.height_at_node(i, j)
            var yb := b.height_at_node(bi, bj)
            if is_nan(ya) and is_nan(yb):
                continue
            shared += 1
            if is_nan(ya) or is_nan(yb) or ya != yb:
                differing += 1
    check(shared > 500, "only %d vertices are shared by the two patches" % shared)
    check(differing == 0, "%d of %d shared vertices moved when the patch was rebuilt"
            % [differing, shared])
    # THE REBUILD RULE ITSELF.
    res.settled(c0, 0)
    check(not res.needs_rebuild(c0), "a patch centred here wants rebuilding where it stands")
    check(not res.needs_rebuild(c0 + Vector2(TileResidency.KEEP_M - 1.0, 0.0)),
            "a rebuild is asked for while the near field is still on refined ground")
    check(res.needs_rebuild(c0 + Vector2(TileResidency.KEEP_M + 1.0, 0.0)),
            "no rebuild is asked for once the near field has left the refined interior")
    check(TileResidency.KEEP_M + TileResidency.BLEND_M + TileResidency.NEAR_FIELD_M
                    == TileResidency.PATCH_HALF_M,
            "the rebuild distance is not the half extent less the blend ring and the near "
            + "field, so it is a tuned number rather than a derived one")
    print("streaming: %d shared vertices, none moved by a rebuild; rebuilds at %s m of the "
            % [shared, String.num(TileResidency.KEEP_M, 0)] + "%s m half extent"
            % String.num(TileResidency.PATCH_HALF_M, 0))


func test_the_patch_never_takes_ground_away() -> void:
    """A REBUILD THAT REMOVES A PLANT IS A WORSE REBUILD THAN ONE THAT MOVES IT.

    The native grid's holes are not the overview's holes -- both come from one
    DEM, but `average` over a 10x10 block is valid wherever part of the block
    was. Where the patch has nothing to say it reproduces the coarse surface,
    so it never opens a hole where the coarse mesh had ground, and the plants
    standing there keep standing."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var res: TileResidency = p["res"]
    var hf: Heightfield = p["hf"]
    var tm: TerrainMesh = p["tm"]
    var np := NearFieldPatch.build(res, p["centre"], 0, hf, tm, null)
    if not np.is_built():
        print("streaming: the patch did not build -- skipping")
        return
    var had := 0
    var lost := 0
    for j in np.n:
        for i in np.n:
            var w := np.world_of(i, j)
            if is_nan(tm.drawn_surface_y(w, hf)):
                continue
            had += 1
            if is_nan(np.height_at_node(i, j)):
                lost += 1
    check(had > 1000, "only %d nodes had coarse ground under them" % had)
    check(lost == 0, "the patch opened %d holes in ground the coarse mesh was drawing" % lost)
    check(np.no_native == 0 or np.no_native < np.n * np.n / 4,
            "%d of %d nodes have no native datum, so this place is mostly not refined and is "
            % [np.no_native, np.n * np.n] + "a poor one to be measuring streaming at")
    print("streaming: %d nodes over coarse ground, %d holes opened, %d ramped in the blend "
            % [had, lost, np.from_ramp] + "ring and %d with no native datum" % np.no_native)


func test_the_ground_refuses_a_patch_it_is_not_standing_on() -> void:
    """THE WRONG-GROUND DEFECT AT LEVEL GRANULARITY.

    Metre scale was stage 0's version of this; a mesh drawn at one level while
    the scatter samples another is the same defect with a median 42.5 m gap
    rather than a centimetre one. So a patch is `stream`ed in rather than
    assigned, and holding one at all is proof it belongs to the mesh in front
    of it."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var res: TileResidency = p["res"]
    var hf: Heightfield = p["hf"]
    var tm: TerrainMesh = p["tm"]
    var np := NearFieldPatch.build(res, p["centre"], 0, hf, tm, null)
    if not np.is_built():
        return
    var mine := GroundSurface.over(hf, tm, null)
    check(mine.stream(np), "the surface refused a patch seamed to its own mesh: %s"
            % mine.why_refused)
    # A DIFFERENT MESH. Same field, same stride, same everything except
    # identity -- which is the case a value comparison would let through.
    var other := TerrainMesh.new()
    other.build(hf, 4, 1.0)
    var theirs := GroundSurface.over(hf, other, null)
    check(not theirs.stream(np), "a surface accepted a patch built against another mesh")
    check(theirs.why_refused.contains("wrong-ground"),
            "the refusal does not name the defect: %s" % theirs.why_refused)
    check(theirs.patch == null, "a refused patch was held anyway")
    # AND A DETAIL MISMATCH, the other half of the pair.
    var withdetail := GroundSurface.over(hf, tm, detail_field())
    check(not withdetail.stream(np),
            "a surface holding a detail term accepted a patch built without one")
    # THE PATCH ANSWERS INSIDE ITS FOOTPRINT AND THE COARSE MESH OUTSIDE IT.
    var c: Vector2 = p["centre"]
    check(mine.patch != null, "the accepted patch was not held")
    var inside := mine.surface_at(c)
    check(not is_nan(inside), "the streamed surface refused at its own centre")
    check(inside == np.surface_y(c), "inside the patch the ground is not the patch")
    var far := c + Vector2(TileResidency.PATCH_HALF_M * 3.0, 0.0)
    if not is_nan(tm.drawn_surface_y(far, hf)):
        check(mine.surface_at(far) == tm.drawn_surface_y(far, hf),
                "outside the patch the ground is not the coarse mesh")
    print("streaming: the surface takes its own patch, refuses another mesh's and a "
            + "mismatched detail term, and answers from the patch only where it covers")


func test_the_near_field_gains_the_data_s_own_samples() -> void:
    """THE ACCEPTANCE METRIC, IN THE GATE.

    `measurements/ground_relief.json` reports it over sixty places; this
    asserts it at one, so a regression is caught by the gate rather than by
    somebody re-reading an artefact. The disc a standing body sees held ZERO of
    the drawn mesh's ground samples -- the whole near field inside one 4 km
    triangle -- and the native grid has 69 in the same disc."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var res: TileResidency = p["res"]
    var hf: Heightfield = p["hf"]
    var tm: TerrainMesh = p["tm"]
    var c: Vector2 = p["centre"]
    var np := NearFieldPatch.build(res, c, 0, hf, tm, null)
    if not np.is_built():
        return
    var r := TileResidency.NEAR_FIELD_M
    var coarse_samples := 0
    var step := float(tm.stride) * hf.pixel_size_m
    var reach := int(r / step) + 2
    for dj in range(-reach, reach + 1):
        for di in range(-reach, reach + 1):
            var w := c + Vector2(float(di) * step, float(dj) * step)
            var t := hf.world_to_texel(w.x, w.y)
            # A COARSE MESH VERTEX, which is a texel at a multiple of the
            # stride and not any texel.
            if absf(t.x - round(t.x)) > 0.01 or absf(t.y - round(t.y)) > 0.01:
                continue
            if int(round(t.x)) % tm.stride != 0 or int(round(t.y)) % tm.stride != 0:
                continue
            if (w - c).length() <= r and not is_nan(hf.height_at_world(w.x, w.y)):
                coarse_samples += 1
    var streamed := np.nodes_within(c, r)
    check(coarse_samples <= 1, "the coarse mesh already has %d ground samples in the near "
            % coarse_samples + "field, so the blocker this is measured against is gone")
    check(streamed >= 60, "the streamed near field holds %d ground samples" % streamed)
    check(streamed > coarse_samples * 20, "streaming did not multiply the near field's ground "
            + "samples: %d against %d" % [streamed, coarse_samples])
    print("streaming: near field holds %d ground samples streamed against %d coarse -- the "
            % [streamed, coarse_samples] + "disc is %s m and the patch samples it at %s m"
            % [String.num(r, 0), String.num(np.step_m, 0)])


func test_the_detail_vanishes_on_the_patch_and_appears_below_it() -> void:
    """WHERE STAGE 0 AND STREAMING MEET, AND IT IS A ZERO.

    The detail term is exactly zero at every parent lattice node. Refining the
    pyramid's 100 m lattice makes its nodes the patch's own vertices, so at
    `refine = 1` the synthesis contributes EXACTLY NOTHING to the drawn mesh --
    the heights are the data. That is the stage-0 guard working, and it is
    worth asserting because "the synthesis is on and changed nothing" and "the
    synthesis is off" are indistinguishable from anywhere else.

    And the other half: tessellate finer than the data and it appears."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var res: TileResidency = p["res"]
    var hf: Heightfield = p["hf"]
    var tm: TerrainMesh = p["tm"]
    var tp: TilePyramid = p["tp"]
    var df := DetailField.load_from(hf, DetailField.ROWS_PATH, tp.pixel_size_of(0))
    check(df.is_loaded(), "the detail field did not load at a 100 m parent")
    if not df.is_loaded():
        return
    check(df.parent_spacing_m == 100.0, "the parent spacing is %s m and not the level's 100 m"
            % String.num(df.parent_spacing_m, 1))
    var plain := NearFieldPatch.build(res, p["centre"], 0, hf, tm, null)
    var withd := NearFieldPatch.build(res, p["centre"], 0, hf, tm, df)
    check(plain.is_built() and withd.is_built(), "a patch did not build")
    if not (plain.is_built() and withd.is_built()):
        return
    var nonzero := 0
    var compared := 0
    for j in range(0, plain.n, 3):
        for i in range(0, plain.n, 3):
            var a := plain.height_at_node(i, j)
            var b := withd.height_at_node(i, j)
            if is_nan(a) or is_nan(b):
                continue
            compared += 1
            if a != b:
                nonzero += 1
    check(compared > 300, "only %d nodes could be compared" % compared)
    check(nonzero == 0, "the detail term moved %d of %d patch vertices, so the patch's "
            % [nonzero, compared] + "vertices are not the lattice it is exact on")
    # THE OTHER HALF: below the data, it is there.
    var fine := NearFieldPatch.build(res, p["centre"], 0, hf, tm, df, 2)
    check(fine.is_built(), "the tessellated patch did not build")
    if not fine.is_built():
        return
    var moved := 0
    var swing := 0.0
    for j in range(1, fine.n - 1, 7):
        for i in range(1, fine.n - 1, 7):
            # ONLY THE NODES BETWEEN DATA SAMPLES. The ones ON them are the
            # zeros just asserted.
            if i % 2 == 0 and j % 2 == 0:
                continue
            var y := fine.height_at_node(i, j)
            var lat := tp.height_at_world(fine.world_of(i, j).x, fine.world_of(i, j).y)
            if is_nan(y) or is_nan(lat):
                continue
            if fine.weight_at(i, j) < 1.0:
                continue
            moved += 1
            swing = maxf(swing, absf(y - lat))
    check(moved > 50, "only %d sub-lattice nodes could be measured" % moved)
    check(swing > 0.0, "tessellating below the data produced no metre-scale relief at all")
    print("streaming: the detail is exactly zero at all %d patch vertices at refine 1, and "
            % compared + "moves the surface up to %s m at refine 2" % String.num(swing, 3))


func test_one_row_serves_two_parents() -> void:
    """`amplitude_m` IS NOT SCALE FREE, AND THE ROWS ALWAYS SAID SO.

    The units block has always read "standard deviation of the detail term at
    the parent spacing". What it did not say was WHICH parent, and nothing read
    it -- which is fine with one level and wrong the moment streaming
    introduces a second. Refining a 100 m lattice, the data already carries
    1,000 m down to 100 m; the function must supply only what is below, which
    is a smaller standard deviation than the same row supplies under a 1,000 m
    parent.

    So the file declares the parent its amplitudes were measured at and the
    field rescales by the row's own exponent -- for fBm the RMS increment over
    a lag goes as lag^H, and `spectral_slope` is that exponent here.

    The control is the number this is worth: taken literally at both spacings
    the same row puts the full kilometre-scale roughness into the last hundred
    metres, and it arrives exactly when a level switches."""
    var hf := heightfield()
    var coarse := DetailField.load_from(hf, DetailField.ROWS_PATH, 1000.0)
    var fine := DetailField.load_from(hf, DetailField.ROWS_PATH, 100.0)
    check(coarse.is_loaded() and fine.is_loaded(), "the rows did not load at both spacings")
    if not (coarse.is_loaded() and fine.is_loaded()):
        return
    check(coarse.calibration_note == "",
            "the rows do not declare which parent their amplitudes belong to: %s"
            % coarse.calibration_note)
    check(coarse.calibrated_at_parent_m == 1000.0,
            "the rows say they were calibrated at %s m" % String.num(coarse.calibrated_at_parent_m, 0))

    # THE DECLARED NUMBER IS UNCHANGED AT THE PARENT IT WAS CALIBRATED AT, to
    # the bit. A single-level client must not move.
    for name in coarse.landforms():
        check(coarse.amplitude_for(str(name))
                        == DetailField.scalar_of(coarse.row(str(name)), "amplitude_m", NAN),
                "%s's amplitude moved at the parent it was calibrated at" % str(name))

    # AND THE ROW STATES A WAVELENGTH, so the octave count follows the parent
    # rather than the answer following the count.
    for name in coarse.landforms():
        var want := DetailField.scalar_of(coarse.row(str(name)), "finest_wavelength_m", NAN)
        for df in [coarse, fine]:
            var got: float = df.parent_spacing_m / pow(2.0, float(df.octaves_for(str(name))))
            check(got <= want and got > want * 0.5,
                    "%s synthesises to %s m under a %s m parent, and the row asks for %s m"
                    % [str(name), String.num(got, 4), String.num(df.parent_spacing_m, 0),
                            String.num(want, 3)])

    # THE SURFACE ITSELF, over the band both parents cover.
    var w0 := hf.texel_to_world(500.0, 700.0)
    var lag := 8.0
    var g_coarse := _detail_variance(coarse, w0, lag)
    var g_fine := _detail_variance(fine, w0, lag)
    check(g_coarse > 0.0 and g_fine > 0.0, "one of the two surfaces is flat")
    var ratio: float = maxf(g_coarse, g_fine) / maxf(minf(g_coarse, g_fine), 1.0e-12)
    check(ratio < 2.0, "the same row under a 1,000 m and a 100 m parent differs by %sx in "
            % String.num(ratio, 2) + "roughness at %s m, so a level switch changes the ground"
            % String.num(lag, 0))
    # THE CONTROL: without the rescale it would have. Loose, because a discrete
    # octave ladder is not a continuum -- the two parents put their finest
    # octave at 0.24 m and 0.20 m, which is a 25% difference in the last band
    # before anything else is counted.
    var talus := fine.row("talus")
    var raw := DetailField.scalar_of(talus, "amplitude_m", NAN)
    var scaled := fine.amplitude_for("talus")
    check(raw / scaled > 2.0, "the rescale is worth %sx, which is small enough that this "
            % String.num(raw / scaled, 2) + "check would pass without it")
    print("one row, two parents: roughness at %s m agrees within %sx, and the rescale it "
            % [String.num(lag, 0), String.num(ratio, 2)]
            + "took is %sx on talus (%s m at a 1,000 m parent, %s m at 100 m)"
            % [String.num(raw / scaled, 2), String.num(raw, 3), String.num(scaled, 3)])


## Mean squared difference of the detail term over a fixed lag -- a variogram
## at one distance, which is all this comparison needs.
func _detail_variance(df: DetailField, at: Vector2, lag: float) -> float:
    var total := 0.0
    var n := 0
    for k in 200:
        var p := at + Vector2(float(k % 20) * 37.0, float(k / 20) * 41.0)
        var a := df.detail_at(p, "talus")
        var b := df.detail_at(p + Vector2(lag, 0.0), "talus")
        if is_nan(a) or is_nan(b):
            continue
        total += (a - b) * (a - b)
        n += 1
    return 0.0 if n == 0 else 0.5 * total / float(n)


func test_a_level_switch_moves_no_plant() -> void:
    """DECISION 952 THROUGH THE ONE DOOR STREAMING LEAVES OPEN.

    §16.6 keys placement on quantised ground position x family x candidate
    index, and 952 binds that to anything turning cover into objects. A
    streaming rebuild is exactly the event that could re-key it -- a tile
    arriving, a level switching, a re-centre -- and the churn defect would come
    back through it.

    It does not, because placement is a function of the ground a plant stands
    ON and never of the height it stands AT: the level decides the second and
    the digest folds the first. So the XOR digest is identical across a level
    change and the plants are at different heights, and BOTH halves are
    asserted -- a patch that changed no height would pass the first on its own
    by doing nothing.

    A plant DROPPED would also be a plant moved, and worse. The patch never
    subtracts, so the instance count is asserted too."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    v.bind_families()
    v.show_field("deepest_winter", "band.pft_fractions", 45)
    var c: Vector2 = p["centre"]
    # WELL INSIDE THE REFINED INTERIOR. A radius reaching the blend ring would
    # compare plants on ramped ground, which is a fair comparison of the wrong
    # thing.
    var radius := 1200.0
    var before := v.scatter_at(c, radius)
    if not bool(before.get("ok", false)):
        print("streaming: the coarse scatter refused (%s) -- skipping"
                % str(before.get("why", "?")))
        v.queue_free()
        return
    var d0: Dictionary = (before["placement"] as Dictionary)["digest"]
    var n0: Dictionary = (before["placement"] as Dictionary)["digest_instances"]
    var census0 := v.scatter.census.duplicate(true)

    var streamed := v.stream_to(c)
    check(bool(streamed.get("ok", false)), "the patch did not stream: %s"
            % str(streamed.get("why", "?")))
    if not bool(streamed.get("ok", false)):
        v.queue_free()
        return
    check(v.ground.patch != null, "the ground is not standing on the streamed patch")
    var after := v.scatter_at(c, radius)
    check(bool(after.get("ok", false)), "the scatter refused after the level changed: %s"
            % str(after.get("why", "?")))
    if not bool(after.get("ok", false)):
        v.queue_free()
        return
    var d1: Dictionary = (after["placement"] as Dictionary)["digest"]
    var n1: Dictionary = (after["placement"] as Dictionary)["digest_instances"]

    check(int(d0["all"]) == int(d1["all"]),
            "the placement digest changed across a level switch: %d then %d -- a rebuild moved "
            % [int(d0["all"]), int(d1["all"])] + "a plant, which is the churn defect returning "
            + "through the one door streaming leaves open")
    check(int(n0["all"]) == int(n1["all"]),
            "%d plants were placed on the coarse surface and %d on the streamed one; a rebuild "
            % [int(n0["all"]), int(n1["all"])] + "that removes a plant is a worse rebuild than "
            + "one that moves it")
    check(int(n0["all"]) > 100, "only %d plants were placed, so the digest is comparing almost "
            % int(n0["all"]) + "nothing")
    for ring in d0:
        check(int(d0[ring]) == int(d1[ring]), "ring %s of the digest changed across the level "
                % str(ring) + "switch")

    # AND THE CONTROL: the heights DID change, so the first half is not passing
    # because streaming did nothing.
    var census1: Dictionary = v.scatter.census
    var compared := 0
    var lifted := 0
    var worst := 0.0
    for k in census0:
        if not census1.has(k):
            continue
        var a: Array = census0[k]
        var b: Array = census1[k]
        compared += 1
        if float(a[2]) != float(b[2]):
            lifted += 1
            worst = maxf(worst, absf(float(a[2]) - float(b[2])))
    check(compared > 20, "only %d sub-cells could be compared" % compared)
    check(lifted > compared / 2, "only %d of %d sub-cells changed height, so the patch is not "
            % [lifted, compared] + "the ground the plants are standing on")
    print("streaming: the placement digest is identical across the level switch over %d "
            % int(n0["all"]) + "plants, and %d of %d sub-cells moved vertically, by up to %s m"
            % [lifted, compared, String.num(worst, 1)])
    v.queue_free()


func test_a_patch_refines_its_own_level_and_not_the_overview() -> void:
    """THE LATTICE A PATCH REFINES IS THE LEVEL IT IS DRAWING, and the wiring
    that decides it is the whole of this.

    `DetailField.load_from` defaults the parent to the heightfield's own pixel
    -- the shipped 1,000 m overview -- and every construction in the tree takes
    that default. A patch draws the pyramid's 100 m level. Handed the default
    straight through, the near field would carry the full kilometre-parent
    amplitude over ground that already holds the 1,000 -> 100 m band, and the
    exact-at-parent guard would go on being green about nodes nobody is
    drawing.

    Measured, which is why this test exists rather than a comment: a
    1,000 m-parented field on a 100 m patch moves 676 of 729 sampled patch
    vertices by up to 0.36 m.

    So the patch re-parents, because it is the only object that knows which
    level it is, and the control below is that the un-re-parented field really
    would have done damage."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var res: TileResidency = p["res"]
    var hf: Heightfield = p["hf"]
    var tm: TerrainMesh = p["tm"]
    var tp: TilePyramid = p["tp"]
    var overview := DetailField.load_from(hf)
    check(overview.parent_spacing_m == hf.pixel_size_m,
            "the default parent is not the overview's pixel, so this test is about nothing")
    var np := NearFieldPatch.build(res, p["centre"], 0, hf, tm, overview)
    check(np.is_built(), "the patch did not build: %s" % np.why_refused)
    if not np.is_built():
        return
    check(np.detail.parent_spacing_m == tp.pixel_size_of(0),
            "the patch's detail term is parented to %s m and it refines %s m"
            % [String.num(np.detail.parent_spacing_m, 0),
                    String.num(tp.pixel_size_of(0), 0)])
    check(np.detail_reparented_from_m == hf.pixel_size_m,
            "the re-parent was not recorded, so the fix-up is silent")
    check(np.detail.same_function_as(overview),
            "re-parenting changed the function and not only the lattice")
    check(np.detail.amplitude_for("talus") < overview.amplitude_for("talus") * 0.5,
            "re-parenting did not reduce the amplitude: %s against %s"
            % [String.num(np.detail.amplitude_for("talus"), 3),
                    String.num(overview.amplitude_for("talus"), 3)])

    # THE EXACTNESS IS ABOUT THE LATTICE BEING DRAWN. Zero at every patch
    # vertex, exactly, with the re-parent in place.
    var plain := NearFieldPatch.build(res, p["centre"], 0, hf, tm, null)
    var moved := 0
    var compared := 0
    for j in range(0, np.n, 3):
        for i in range(0, np.n, 3):
            var a := plain.height_at_node(i, j)
            var b := np.height_at_node(i, j)
            if is_nan(a) or is_nan(b):
                continue
            compared += 1
            if a != b:
                moved += 1
    check(compared > 300, "only %d nodes could be compared" % compared)
    check(moved == 0, "%d of %d patch vertices carry a detail term, so the exactness is being "
            % [moved, compared] + "asserted about a lattice the patch is not drawing")

    # THE CONTROL: without the re-parent it would have. Built by hand here
    # rather than by disabling the fix, so the number is measured and not
    # asserted.
    var wrong := 0
    var worst := 0.0
    for j in range(0, np.n, 3):
        for i in range(0, np.n, 3):
            var w := np.world_of(i, j)
            var d := overview.detail_at(w)
            if d != 0.0:
                wrong += 1
            worst = maxf(worst, absf(d))
    check(wrong > compared / 2, "only %d of %d patch vertices would have moved under the "
            % [wrong, compared] + "overview's parent, so this check does not discriminate")
    check(worst > 0.1, "the mis-parented field would have moved the surface by only %s m"
            % String.num(worst, 4))
    print("streaming: the patch re-parents %s m -> %s m; zero of %d vertices carry detail "
            % [String.num(np.detail_reparented_from_m, 0),
                    String.num(np.detail.parent_spacing_m, 0), compared]
            + "after it, and %d would have moved by up to %s m without it"
            % [wrong, String.num(worst, 3)])


func test_the_view_turns_detail_on_for_both_surfaces_or_neither() -> void:
    """THE PRODUCTION PATH, DRIVEN. The re-parent above is worth nothing if the
    only caller that reaches it is a test.

    `detail_on` is off by default and off is not a placeholder -- decision 974
    licenses a published pure function evaluated on both sides, and this switch
    is what makes that path reachable. One switch for both surfaces, because
    `GroundSurface` refuses when they disagree: there is no arrangement in
    which the coarse mesh has detail and the patch does not."""
    var p := streaming_place()
    if p.is_empty():
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var v := TerrainView.new()
    v.detail_on = true
    get_root().add_child(v)
    var r := v.build()
    check(bool(r.get("ok", false)), "the view refused to build with detail on: %s"
            % str(r.get("why", "?")))
    if not bool(r.get("ok", false)):
        v.queue_free()
        return
    check(v.terrain.detail != null, "detail is on and the mesh carries no detail term")
    check(v.terrain.detail.parent_spacing_m == v.heightfield.pixel_size_m,
            "the coarse mesh's detail term is not parented to the overview it refines")
    v.bind_fields()
    v.bind_families()
    check(v.ground.detail == v.terrain.detail,
            "the ground and the mesh hold different detail terms")
    var streamed := v.stream_to(p["centre"])
    check(bool(streamed.get("ok", false)),
            "the patch was refused with detail on: %s" % str(streamed.get("why", "?")))
    if bool(streamed.get("ok", false)):
        check(v.ground.patch != null, "a patch was drawn the ground does not hold")
        check(float(streamed["detail_parent_m"]) == 100.0,
                "the streamed patch's detail is parented to %s m, not the level's 100 m"
                % String.num(float(streamed["detail_parent_m"]), 0))
        check(float(streamed["detail_reparented_from_m"]) == 1000.0,
                "the report does not record what the field was re-parented from")
        # AND THE GUARD FIRES ON A PATCH PARENTED TO THE WRONG LATTICE.
        var bad := NearFieldPatch.build(v.residency, v.residency.centre, 0, v.heightfield,
                v.terrain, v.terrain.detail)
        bad.detail = v.terrain.detail          # undo the re-parent, by hand
        check(not v.ground.stream(bad),
                "the ground accepted a patch whose detail is parented to the overview")
        check(v.ground.why_refused.contains("nobody is drawing"),
                "the refusal does not say what is wrong: %s" % v.ground.why_refused)
        v.ground.stream(v.patch)
    print("view: detail_on builds both surfaces, the patch reports a %s m parent from a %s m "
            % [String.num(float(streamed.get("detail_parent_m", 0.0)), 0),
                    String.num(float(streamed.get("detail_reparented_from_m", 0.0)), 0)]
            + "field, and a hand-broken parent is refused")
    v.queue_free()


func test_the_patch_keeps_ground_the_native_grid_does_not_have() -> void:
    """THE NEVER-SUBTRACTS RULE'S NODATA HALF, AT A PLACE WHERE IT FIRES.

    The rule is that where the patch has nothing to say it reproduces the
    coarse surface, so it can never open a hole in ground the coarse mesh was
    drawing -- and a rebuild that REMOVES a plant is a worse rebuild than one
    that moves it (decision 952).

    Until now it was only ever exercised by the blend ring: at every place the
    gate measures, the two grids' holes coincide and `no_native` is zero. That
    made the rule structural rather than observed, which is a weaker claim than
    the comment was making.

    THE COORDINATE IS THE SIM SESSION'S, HANDED OVER. 4,354 km2 of the basin
    are nodata in the native grid, of which 57 km2 are interior holes with
    drawn ground on all sides; this is the densest of them, 93 of 100 fine
    pixels absent, with its neighbour at 90. It exists because the overview's
    validity flag is any-valid rather than all-valid, so a 1 km cell declares
    ground on as little as 1% real coverage -- which is the sim session's own
    open question and is exactly what makes this case real rather than
    contrived."""
    var tp := TilePyramid.load_from()
    if not tp.is_loaded() or int(tp.inventory()["present"]) == 0:
        print("streaming: no fetched pyramid -- skipping, and saying so")
        return
    var hf := heightfield()
    var tm := TerrainMesh.new()
    tm.build(hf, 4, 1.0)
    var res := TileResidency.over(tp)
    var hole := Vector2(-1148792.9, 1246226.3)
    var z := res.level_for(hole)
    if z < 0:
        print("streaming: the nodata place has no fetched level -- skipping")
        return
    var c := res.snap(hole, z)
    if not bool(res.pump(c, z, 16)["ready"]):
        print("streaming: the nodata place's tiles did not load -- skipping")
        return
    var np := NearFieldPatch.build(res, c, z, hf, tm, null)
    check(np.is_built(), "the patch did not build over the nodata place: %s" % np.why_refused)
    if not np.is_built():
        return
    # THE HALF THAT HAD NEVER FIRED. Nodes with coarse ground under them and no
    # native datum: the patch takes the coarse height rather than opening a
    # hole, so the plants standing there keep standing.
    check(np.no_native > 0, "the handed coordinate has no missing native data under it, so "
            + "either the place has moved or this check is still not exercising the rule")
    var had := 0
    var lost := 0
    for j in np.n:
        for i in np.n:
            if is_nan(tm.drawn_surface_y(np.world_of(i, j), hf)):
                continue
            had += 1
            if is_nan(np.height_at_node(i, j)):
                lost += 1
    check(had > 100, "only %d nodes have coarse ground here" % had)
    check(lost == 0, "the patch opened %d holes in ground the coarse mesh was drawing" % lost)

    # AND THE REASON THE POPULATION AT RISK IS SMALL, MEASURED RATHER THAN
    # ASSUMED. The sim session's census counts native nodata against the
    # RASTER. What the client DRAWS has a much wider hole: `TerrainMesh` emits
    # a quad only when all four corners are valid, and `Heightfield.height_at`
    # is NAN if any of its sixteen bicubic taps is -- so at stride 4 a hole in
    # the data grows a margin of kilometres before it becomes a hole on screen.
    # Most of a nodata region is therefore outside the drawn surface entirely,
    # and only its fringe is ground the patch could take away.
    var absent := 0
    for j3 in np.n:
        for i3 in np.n:
            if is_nan(tp.height_at_world(np.world_of(i3, j3).x, np.world_of(i3, j3).y, z)):
                absent += 1
    check(absent > np.no_native, "every node with no native datum is inside the drawn surface, "
            + "so the coarse mesh's nodata margin is not wider than the raster's and this "
            + "reading is wrong")
    # AND THE PATCH IS STILL MOSTLY DATA. A place that was nodata everywhere
    # would pass the two checks above by refining nothing.
    check(np.from_native > np.no_native,
            "%d nodes came from the native grid against %d with none, so this patch is mostly "
            % [np.from_native, np.no_native] + "coarse surface and proves little about either")
    # AND A PLANT STANDS ON EVERY ONE OF THEM. The scatter drops any instance
    # whose ground answers NAN, which is how a hole here becomes a removed
    # plant -- so the positions asked about are exactly the population at risk:
    # nodes with coarse ground and no native datum, rather than a box around
    # the centre. A first version sampled a fixed 740 m box and answered 0 of
    # 0, which passes and means nothing.
    var g := GroundSurface.over(hf, tm, null)
    check(g.stream(np), "the surface refused the patch: %s" % g.why_refused)
    var stood := 0
    var refused := 0
    for j2 in np.n:
        for i2 in np.n:
            var w := np.world_of(i2, j2)
            if is_nan(tm.drawn_surface_y(w, hf)):
                continue
            if not is_nan(tp.height_at_world(w.x, w.y, z)):
                continue
            if is_nan(g.surface_at(w)):
                refused += 1
            else:
                stood += 1
    check(stood + refused > 0,
            "no node here has coarse ground and no native datum, so nothing was tested")
    check(refused == 0, "%d of %d positions with coarse ground and no native datum got no "
            % [refused, stood + refused] + "height from the streamed surface, which is a plant "
            + "removed by a rebuild")
    print("streaming: at the handed nodata place %d of %d nodes lack a native datum but only "
            % [absent, np.n * np.n] + "%d of them are inside the %d the coarse mesh draws -- "
            % [np.no_native, had] + "0 holes opened and all %d positions at risk answered"
            % stood)


# ============================================================================
# The three derived terrain layers.
# ============================================================================

var _tlayers: TerrainLayers = null


func terrain_layers() -> TerrainLayers:
    if _tlayers == null:
        _tlayers = TerrainLayers.load_from()
    return _tlayers


## A world position with all three layers under it, or Vector2.INF.
func layered_place() -> Vector2:
    var tl := terrain_layers()
    var hf := heightfield()
    if not tl.is_loaded():
        return Vector2.INF
    for ty in range(300, 1200, 23):
        for tx in range(200, 900, 29):
            var w := hf.texel_to_world(float(tx), float(ty))
            if is_nan(hf.height_at_world(w.x, w.y)):
                continue
            var ok := true
            for name in [TerrainLayers.SLOPE, TerrainLayers.ASPECT, TerrainLayers.DISTANCE]:
                var at := tl.locate(str(name), w.x, w.y, 0)
                if not bool(at.get("ok", false)):
                    ok = false
                    break
                if tl.availability(str(at["key"])) != TilePyramid.PRESENT:
                    ok = false
                    break
            if ok and not is_nan(tl.slope_degrees_at(w.x, w.y, 0)):
                return w
    return Vector2.INF


func test_the_layers_ride_the_pyramids_own_grid() -> void:
    """ONE GRID, ONE PRODUCER. The layers are emitted by reading the height
    export's grid, not by re-deriving one: same origin, same tile_px, same
    naming, same z-polarity and the SAME KEY SETS at every level.

    A layer tile half a pixel off the height tile beneath it is a misalignment
    nothing reports, because both look like data. So this compares the two pins
    against each other rather than each against its own claim."""
    var tl := terrain_layers()
    var tp := TilePyramid.load_from()
    if not tl.is_loaded() or not tp.is_loaded():
        print("layers: %s -- skipping, and saying so"
                % (tl.why_absent if not tl.is_loaded() else tp.why_absent))
        return
    check(tl.origin_x == tp.origin_x and tl.origin_y == tp.origin_y,
            "the layers' grid corner is (%s, %s) and the pyramid's is (%s, %s)"
            % [String.num(tl.origin_x, 6), String.num(tl.origin_y, 6),
                    String.num(tp.origin_x, 6), String.num(tp.origin_y, 6)])
    check(Array(tl.names()) == [TerrainLayers.ASPECT, TerrainLayers.DISTANCE,
            TerrainLayers.HAND, TerrainLayers.SLOPE],
            "the pin names %s" % str(Array(tl.names())))
    # z = 0 IS THE FINEST HERE TOO, with the same control as the pyramid's.
    check(tl.pixel_size_of(TerrainLayers.SLOPE, 0)
                    < tl.pixel_size_of(TerrainLayers.SLOPE, 5),
            "z=0 is not the finest layer level, so the polarity is inverted from the pyramid's")
    for name in tl.names():
        for z in 6:
            check(tl.pixel_size_of(str(name), z) == tp.pixel_size_of(z),
                    "%s z=%d is %s m and the pyramid's is %s m" % [str(name), z,
                            String.num(tl.pixel_size_of(str(name), z), 1),
                            String.num(tp.pixel_size_of(z), 1)])
    # NO LAYER EVER KEYS GROUND THE HEIGHT PYRAMID DOES NOT -- the direction
    # that matters, asserted for all four. A layer claiming ground the client
    # is not drawing would have to be checked against the terrain at every
    # read; the reverse is legitimate and is per layer.
    var extra := 0
    for k in tl.keys:
        var parts := str(k).split("/", true, 1)
        if parts.size() == 2 and not tp.keys.has(parts[1]):
            extra += 1
    check(extra == 0, "%d layer tiles name ground the height pyramid does not key" % extra)

    # THE THREE THAT SHARE THE DEM'S MASK ARE EQUAL, TILE FOR TILE. `hand` is
    # NOT, and that is the layer being honest rather than a gap: it is absent
    # where a filled descent reaches no channel -- endorheic and edge-draining
    # ground -- so thirty of its z=0 tiles were never written.
    var equal_layers := [TerrainLayers.SLOPE, TerrainLayers.ASPECT, TerrainLayers.DISTANCE]
    var missing := 0
    var hand_short := 0
    for k in tp.keys:
        for name in equal_layers:
            if not tl.keys.has("%s/%s" % [str(name), str(k)]):
                missing += 1
        if not tl.keys.has("%s/%s" % [TerrainLayers.HAND, str(k)]):
            hand_short += 1
    check(missing == 0, "%d height tiles have no layer tile beside them" % missing)
    check(hand_short > 0, "hand keys every tile the pyramid does, so the drainage mask this "
            + "layer is supposed to carry is not narrowing anything")
    check(hand_short < tp.keys.size() / 4, "hand is missing %d of %d tiles, which is not a rim "
            % [hand_short, tp.keys.size()] + "of undrained ground but most of the basin")
    var inv := tl.inventory()
    check(int(inv["keyed"]) == tp.keys.size() * 3 + (tp.keys.size() - hand_short),
            "%d layer tiles against %d expected" % [int(inv["keyed"]),
                    tp.keys.size() * 3 + (tp.keys.size() - hand_short)])
    print("layers: hand keys %d of the pyramid's %d tiles -- %d are outside any drainage"
            % [tp.keys.size() - hand_short, tp.keys.size(), hand_short])
    print("layers: %d tiles over %d layers on the pyramid's own grid, %d present"
            % [int(inv["keyed"]), tl.names().size(), int(inv["present"])])


func test_aspect_is_read_through_its_validity_byte_and_never_around_it() -> void:
    """THE ONE READING THAT WOULD LOOK RIGHT AND BE MEANINGLESS.

    Where B is 0 or 128 the components are zeroed, and zeroed components go
    through `atan2((0-128)/127, (0-128)/127)` to 225 degrees -- a perfectly
    plausible south-west. So the failure this prevents is not a crash and not a
    NAN: it is a wrong answer, over half the source grid, that no reader could
    tell from a right one.

    The guard is structural rather than remembered: there is no method on
    `TerrainLayers` that returns an azimuth without having consulted B.
    `aspect_at` returns a STATE and a number, and the number is NAN in two of
    the three states.

    The control is that the naive decode really does produce 225."""
    var tl := terrain_layers()
    if not tl.is_loaded():
        print("layers: %s -- skipping, and saying so" % tl.why_absent)
        return
    # THE CONTROL FIRST. If zeroed components did not decode to a plausible
    # direction there would be nothing here to guard against.
    var naive := rad_to_deg(atan2((0.0 - 128.0) / 127.0, (0.0 - 128.0) / 127.0))
    check(absf(naive - -135.0) < 0.001 or absf(naive - 225.0) < 0.001,
            "a zeroed aspect pixel decodes to %s degrees, not the 225 the guard is about"
            % String.num(naive, 3))

    # THE PIN WITHOUT THE BYTES IS A VALID CLONE, and this skips rather than
    # failing on it. An earlier version asserted first and skipped second,
    # which turned a working clone into two red checks -- caught by CI, where
    # the host is a `file://` path CI cannot reach, which is exactly the state
    # the absence discipline exists for.
    var w := layered_place()
    if w == Vector2.INF:
        print("layers: keyed but not fetched -- skipping the decoded half, and saying so")
        return
    # A SCALAR READ OF ASPECT IS REFUSED, not quietly wrong. `value_at`'s
    # arithmetic IS the misreading the direction pair exists to prevent.
    check(is_nan(tl.value_at(TerrainLayers.ASPECT, w.x, w.y, 0)),
            "aspect decoded as a scalar rather than refusing")

    # AND THE THREE STATES ARE ALL REACHED SOMEWHERE, so the byte is carrying
    # three values and not two.
    var seen := {}
    var valid_azimuths := 0
    var out_of_range := 0
    for j in 60:
        for i in 60:
            var q := w + Vector2(float(i - 30) * 400.0, float(j - 30) * 400.0)
            var a := tl.aspect_at(q.x, q.y, 0)
            var st := str(a["state"])
            seen[st] = int(seen.get(st, 0)) + 1
            if st == TerrainLayers.VALID:
                valid_azimuths += 1
                var deg := float(a["azimuth_deg"])
                if is_nan(deg) or deg < -180.001 or deg > 180.001:
                    out_of_range += 1
            elif not is_nan(float(a["azimuth_deg"])):
                # THE WHOLE POINT. A non-valid state must not carry a number.
                out_of_range += 1
    check(valid_azimuths > 100, "only %d of 3600 samples had a valid aspect" % valid_azimuths)
    check(out_of_range == 0,
            "%d samples carried an azimuth they should not have, or one out of range"
            % out_of_range)
    check(seen.has(TerrainLayers.NO_DATA),
            "no sample was outside the basin, so the nodata state is untested here")
    print("layers: aspect over 3600 samples -- %s; every non-valid state carries NAN and the "
            % str(seen) + "naive decode of a zeroed pixel is %s degrees" % String.num(naive, 1))


func test_a_layer_decodes_into_the_range_its_pin_declares() -> void:
    """THE TWO SCALAR LAYERS HAVE RANGES THREE ORDERS OF MAGNITUDE APART -- 0 to
    78.2 degrees against 0 to 183,725.9 m -- so one layer's constants applied to
    the other's bytes is wrong by that much, with nothing to report it. Each is
    decoded from its OWN stats block; this is the check that it was."""
    var tl := terrain_layers()
    var w := layered_place()
    if not tl.is_loaded() or w == Vector2.INF:
        print("layers: none fetched -- skipping, and saying so")
        return
    for name in [TerrainLayers.SLOPE, TerrainLayers.DISTANCE]:
        var stats: Dictionary = (tl.layers[str(name)] as Dictionary)["stats"]
        var lo := float(stats["min"])
        var hi := float(stats["max"])
        var taken := 0
        var out := 0
        var seen_lo := INF
        var seen_hi := -INF
        for j in 40:
            for i in 40:
                var q := w + Vector2(float(i - 20) * 600.0, float(j - 20) * 600.0)
                var v := tl.value_at(str(name), q.x, q.y, 0)
                if is_nan(v):
                    continue
                taken += 1
                seen_lo = minf(seen_lo, v)
                seen_hi = maxf(seen_hi, v)
                if v < lo - 1.0e-6 or v > hi + 1.0e-6:
                    out += 1
        check(taken > 200, "%s decoded at only %d of 1600 samples" % [str(name), taken])
        check(out == 0, "%s decoded %d samples outside its own declared range" % [str(name), out])
        print("layers: %s over %d samples reads %s .. %s, declared %s .. %s"
                % [str(name), taken, String.num(seen_lo, 2), String.num(seen_hi, 2),
                        String.num(lo, 2), String.num(hi, 2)])
    # THE CONTROL: the two ranges really are far enough apart that a swap would
    # show. Without it "inside its own range" is a weak claim.
    var s_hi := float((tl.layers[TerrainLayers.SLOPE] as Dictionary)["stats"]["max"])
    var d_hi := float((tl.layers[TerrainLayers.DISTANCE] as Dictionary)["stats"]["max"])
    check(d_hi > s_hi * 1000.0, "the two layers' ranges are within a thousandfold, so decoding "
            + "one with the other's constants would not leave the range")


func test_the_classifier_reads_the_layers_and_can_reach_the_margin() -> void:
    """THE ROW THAT WAS UNREACHABLE.

    `riparian_margin` has been a row since stage 0 -- and the row whose
    amplitude matters most, because a shoreline converts vertical error to
    horizontal error at 1/slope -- and nothing could ever return it. The only
    field available was slope re-derived from a kilometre lattice; there was no
    channel network to measure a distance from.

    So this asserts the substantive change rather than the better slope: the
    class exists in the field now, and the classifier says which source it
    used."""
    var hf := heightfield()
    var tl := terrain_layers()
    var with_layers := DetailField.load_from(hf, DetailField.ROWS_PATH, 0.0, tl)
    var without := DetailField.load_from(hf, DetailField.ROWS_PATH, 0.0, null)
    check(with_layers.is_loaded() and without.is_loaded(), "the rows did not load")
    check(without.classifier_source().contains("parent lattice"),
            "a field with no layers does not say it is re-deriving: %s"
            % without.classifier_source())
    if not tl.is_loaded():
        print("layers: %s -- skipping the layered half, and saying so" % tl.why_absent)
        return
    check(with_layers.classifier_source().contains("assets/terrain/layers/"),
            "a field with layers does not say it is reading them: %s"
            % with_layers.classifier_source())

    # THE LEVEL IS CHOSEN BY THE PARENT SPACING, not fixed at the finest. A
    # classifier refining a kilometre lattice that sampled slope at 100 m would
    # classify a kilometre of ground by one point of it.
    check(with_layers.level_for_spacing(1000.0) == 3,
            "a 1,000 m parent reads level %d, and 800 m is the closest in ratio"
            % with_layers.level_for_spacing(1000.0))
    check(with_layers.level_for_spacing(100.0) == 0,
            "a 100 m parent does not read the finest level")

    var w := layered_place()
    if w == Vector2.INF:
        print("layers: keyed but not fetched -- skipping the classified half, and saying so")
        return
    var seen := {}
    for j in 70:
        for i in 70:
            var q := w + Vector2(float(i - 35) * 900.0, float(j - 35) * 900.0)
            if is_nan(hf.height_at_world(q.x, q.y)):
                continue
            var c := with_layers.classify(q)
            seen[c] = int(seen.get(c, 0)) + 1
    check(int(seen.get("riparian_margin", 0)) > 0,
            "the margin class is still unreachable over %d classified points: %s"
            % [seen.values().size(), str(seen)])
    check(seen.size() >= 3, "only %d classes appear, so the classifier is not discriminating"
            % seen.size())
    # AND THE MARGIN IS NOT EVERYTHING. A threshold that swallowed the basin
    # would satisfy the check above and mean the opposite of what it claims.
    var total := 0
    for k in seen:
        total += int(seen[k])
    check(float(seen.get("riparian_margin", 0)) / float(total) < 0.5,
            "%s%% of the basin classified as margin, which is a threshold swallowing the map"
            % String.num(100.0 * float(seen.get("riparian_margin", 0)) / float(total), 1))

    # A SLOPE AVERAGES AND A FIELD MEASURED TO A FEATURE DOES NOT, and this is
    # the control that found it -- after two wrong predictions, both of which
    # this measurement refused.
    #
    # An earlier version read BOTH layers at the level nearest the parent
    # spacing: "sample a quantity at the scale you are using it", which is
    # right for slope and inverts for a distance transform. The mean of a
    # distance field over 800 m is not the distance of anything.
    #
    # THE RULE OUTLIVED THE CALLER. Distance no longer conditions the margin --
    # decision 985 names HAND and slope, and the membership moved -- but HAND
    # is measured to the same network and is read at z=0 for exactly the reason
    # measured here. So this stays as the evidence for that reading rather than
    # being deleted with the caller it was written for.
    #
    # WHAT WAS PREDICTED AND WHAT WAS MEASURED. First guess: the margin would
    # be MORE reachable at a fine parent because a 150 m band cannot sit on an
    # 800 m cell. Second guess, after that failed: the coarse read INVENTS
    # margins by pulling distances down near channels. Measured, on the same
    # points at the same threshold: the coarse read finds 8 where the fine
    # read finds 49, and 2 of the 8 are places the fine field says are
    # kilometres from a channel.
    #
    # SO IT IS WRONG IN BOTH DIRECTIONS AT ONCE, which is a stronger statement
    # than either guess. A coarse read of a distance transform is not a blurred
    # version of the fine one; it is a different field, erasing six margins in
    # seven and inventing a couple that were never there. Averaging is
    # meaningful for a quantity that has a value over an area and this does
    # not have one.
    var coarse_hits := 0
    var fine_hits := 0
    var fabricated := 0
    var compared := 0
    var near_m := float((with_layers.rows.get("classifier", {}) as Dictionary)
            .get("riparian_within_m", 150.0))
    for j2 in 70:
        for i2 in 70:
            var q2 := w + Vector2(float(i2 - 35) * 900.0, float(j2 - 35) * 900.0)
            var d_fine := tl.distance_to_channel_m(q2.x, q2.y, 0)
            var d_coarse := tl.distance_to_channel_m(q2.x, q2.y, 3)
            if is_nan(d_fine) or is_nan(d_coarse):
                continue
            compared += 1
            if d_coarse <= near_m:
                coarse_hits += 1
            if d_fine <= near_m:
                fine_hits += 1
            if d_coarse <= near_m and d_fine > near_m:
                fabricated += 1
    check(compared > 500, "only %d points could be compared at both levels" % compared)
    # BOTH DIRECTIONS ASSERTED, because either alone is a weaker claim than
    # what was measured and either alone could be arranged.
    check(fabricated > 0, "reading the distance layer coarse invented no margins over %d "
            % compared + "points, so half the reason this class pins itself to z=0 is not "
            + "demonstrated here")
    check(fine_hits > coarse_hits * 2, "the coarse read found %d margins against the fine "
            % coarse_hits + "read's %d, so it is not erasing the class and this reading is "
            % fine_hits + "wrong")
    # THE SOURCE LINE HAS TO NAME BOTH LEVELS AND WHY THEY DIFFER. Which level
    # a quantity is read at is a decision this class makes twice, differently,
    # for reasons that are not symmetric -- so a report that gave one number
    # would be hiding the half a reader would question.
    var src := with_layers.classifier_source()
    check(src.contains("z=3") and src.contains("z=0"),
            "the source line does not name both levels: %s" % src)
    check(src.contains("averages") and src.contains("finest"),
            "the source line does not say why the two are read differently: %s" % src)
    print("layers: classified %d points -- %s -- from %s"
            % [total, str(seen), with_layers.classifier_source()])
    print("layers: over %d points a %s m margin test reads %d hits at z=0 and %d at z=3 -- "
            % [compared, String.num(near_m, 0), fine_hits, coarse_hits]
            + "the coarse read erases %d real margins AND invents %d that are kilometres "
            % [fine_hits - (coarse_hits - fabricated), fabricated]
            + "from a channel. A distance transform is not sampled at the parent's scale the "
            + "way a slope is.")


# ============================================================================
# §20.4.5 conformance, against a golden bundle.
# ============================================================================

const GOLDEN_BUNDLE := "res://contract/percept_bundle_v0.golden.json"


func golden_bundle() -> Dictionary:
    var f := FileAccess.open(GOLDEN_BUNDLE, FileAccess.READ)
    if f == null:
        return {}
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func test_the_golden_bundle_carries_exactly_what_the_schema_declares() -> void:
    """CONFORMANCE TO §20.4.5, MADE MECHANICAL RATHER THAN REVIEWED.

    Decision 980 lands `PerceptBundle` v0 as §20.4.5 and makes the corpus the
    authority this prototype conforms to -- so the interesting failure is no
    longer 'the code is wrong' but 'the code and the ruled shape have drifted
    apart and nobody noticed'. A test that only exercised the code could not
    see that at all.

    So the golden document is checked BOTH WAYS at every level: every name the
    schema declares appears in it, and every name in it is one the schema
    declares. A field added to `DECLARED` without reaching the golden fails
    here, and so does the reverse. That is the whole point of a golden and it
    is why the check is an equality rather than a subset in either direction.

    The values in it are invented and say so; what is asserted is structure."""
    var doc := golden_bundle()
    check(not doc.is_empty(), "no golden bundle at %s" % GOLDEN_BUNDLE)
    if doc.is_empty():
        return
    check(str(doc.get("_the_values_are_invented", "")).length() > 20,
            "the golden does not say its numbers are placeholders")
    var g: Dictionary = doc.get("bundle", {})
    check(not g.is_empty(), "the golden file carries no `bundle`")
    if g.is_empty():
        return

    # EVERY LEVEL, BOTH DIRECTIONS.
    var levels := {
        "root": g,
        "header": g.get("header", {}),
        "producer": (g.get("header", {}) as Dictionary).get("producer", {}),
        "moment": (g.get("header", {}) as Dictionary).get("moment", {}),
        "body": g.get("body", {}),
        "fields": g.get("fields", {}),
    }
    for level in levels:
        var declared: Array = PerceptBundle.DECLARED[str(level)]
        var present: Dictionary = levels[level]
        for name in declared:
            check(present.has(str(name)), "the golden's %s carries no `%s`, which the schema "
                    % [str(level), str(name)] + "declares")
        for name in present:
            check(declared.has(str(name)), "the golden's %s carries `%s`, which the schema does "
                    % [str(level), str(name)] + "not declare")
    # AND THE ROW LEVEL, which is where 978 landed.
    var rows: Dictionary = (g.get("fields", {}) as Dictionary).get("rows", {})
    check(rows.size() >= 3, "the golden carries %d rows, too few to show the shapes" % rows.size())
    for row in rows:
        var r: Dictionary = rows[row]
        for name in PerceptBundle.DECLARED["row"]:
            check(r.has(str(name)), "the golden's row %s carries no `%s`" % [str(row), str(name)])
        for name in r:
            check(PerceptBundle.DECLARED["row"].has(str(name)),
                    "the golden's row %s carries `%s`, which the schema does not declare"
                    % [str(row), str(name)])

    # BOTH LATTICES APPEAR, or the golden cannot show what 978 changed.
    var seen := {}
    for row in rows:
        seen[str((rows[row] as Dictionary)["lattice"])] = true
    for lattice in PerceptBundle.AXIS_OF_LATTICE:
        check(seen.has(str(lattice)), "no golden row rides the %s lattice, so this document "
                % str(lattice) + "cannot show one key axis per lattice")
    print("golden: %d rows over %d lattices, every level's names equal to the schema's"
            % [rows.size(), seen.size()])


func test_the_golden_bundle_loads_checks_and_round_trips() -> void:
    """THE DOCUMENT IS A DOCUMENT, not a shape someone wrote down.

    `from_dict` accepts it, `check()` passes on it, and `to_dict` reproduces it
    BYTE FOR BYTE -- decision 180's percept-as-pure-function extended to the
    document that carries it, which is what makes a recorded stream replayable
    against a pinned fixture digest.

    Byte for byte and not field by field: a comparison that walked the fields
    would pass over a key ORDER change, and two documents that differ in order
    do not have the same digest, so a replay would not match."""
    var doc := golden_bundle()
    if doc.is_empty():
        return
    var g: Dictionary = doc.get("bundle", {})
    var b := PerceptBundle.from_dict(g)
    check(not b.refused, "the golden bundle was refused: %s" % b.refusal)
    if b.refused:
        return
    var ok := b.check()
    check(bool(ok["ok"]), "the golden bundle does not check: %s" % str(ok["why"]))

    # THE FIXED-POINT FORM, AND IT HAS TO BE STATED CAREFULLY.
    #
    # What decision 180 needs is that writing a bundle, reading it, and writing
    # it again produces the same bytes -- otherwise a recorded stream's digest
    # moves under a replay that changed nothing.
    #
    # BOTH SIDES GO THROUGH THE PARSER, and that is not a dodge. A GDScript
    # `int` written to JSON comes back a float: `{"day": 12}` reads as 12.0 and
    # re-writes as `12.0`. So an in-memory document and its own reload differ
    # in type while agreeing in value, and comparing the two would report a
    # difference that no wire ever sees. What a reader and a digest see is the
    # TEXT, so the text is what is compared, from the same starting point on
    # both sides.
    var reloaded := PerceptBundle.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
    check(not reloaded.refused, "the bundle's own output was refused on reload: %s"
            % reloaded.refusal)
    var again := JSON.stringify(JSON.parse_string(JSON.stringify(b.to_dict())), "  ")
    var want := JSON.stringify(g, "  ")
    check(again == want, "loading and re-saving the golden does not reproduce it. Either the "
            + "schema moved or the file did; the form `to_dict` produces is:\n%s"
            % again.substr(0, 700))
    # AND ONCE MORE FROM THE RELOAD, which is the fixed point itself rather
    # than agreement with one particular file.
    check(JSON.stringify(reloaded.to_dict(), "  ") == JSON.stringify(b.to_dict(), "  "),
            "a bundle and its own reload write different documents, so a recorded stream's "
            + "digest moves under a replay that changed nothing")

    # THE AXES ARE SEPARATE AND THE VALUES LAND WHERE THE KEYS SAY.
    check(b.value_at("1401000101|1", "band.wetness") == 0.25,
            "the golden's band row does not index by residence key")
    check(b.node_value_at("1401000102", "node.streamflow") == 2.25,
            "the golden's node row does not index by node key")
    check(b.value_at("1401000101|0", "band.pft_fractions", 1) == 0.75,
            "the golden's group axis does not index")
    check(is_nan(b.value_at("1401000101|0", "node.streamflow")),
            "the golden's node row answered to a residence key")
    print("golden: loads, checks and round-trips at %d bytes" % again.length())


func test_the_schema_refuses_an_undeclared_name_at_every_level() -> void:
    """THE CLOSED WHITELIST, EXERCISED WHERE IT IS DECLARED RATHER THAN AT ONE
    LEVEL AND ASSUMED FOR THE REST.

    §20.4.5's two closure rules are deliberately different: the document's
    STRUCTURE is a closed whitelist and an undeclared name refuses -- a refused
    bundle is not a partially-loaded one -- while the ROWS INSIDE the fields
    region version instead, because rows are the additive half the version pair
    already governs. Collapsing them either way loses a property.

    So this asserts refusal at every structural level including the row's own
    shape, and the golden is the base each mutation is made from, which means a
    level added to the schema without a golden entry is caught by the test
    above and a level that stops refusing is caught here."""
    var doc := golden_bundle()
    if doc.is_empty():
        return
    var g: Dictionary = doc.get("bundle", {})
    check(not PerceptBundle.from_dict(g).refused, "the unmutated golden is refused")

    var at := {
        "root": [],
        "header": ["header"],
        "producer": ["header", "producer"],
        "moment": ["header", "moment"],
        "body": ["body"],
        "fields": ["fields"],
    }
    for level in at:
        var mutated: Dictionary = g.duplicate(true)
        var target: Dictionary = mutated
        for step in (at[level] as Array):
            target = target[str(step)]
        target["_smuggled"] = "a name this schema does not declare"
        var b := PerceptBundle.from_dict(mutated)
        check(b.refused, "an undeclared name in `%s` was accepted" % str(level))
        check(b.refusal.contains("_smuggled") and b.refusal.contains("closed"),
                "the refusal for `%s` does not name what arrived or say why: %s"
                % [str(level), b.refusal])
        # A REFUSED BUNDLE IS NOT A PARTIALLY-LOADED ONE.
        check(b.check()["ok"] == false, "a refused bundle passed its own check")
        check(b.cell_keys.is_empty() and b.rows.is_empty(),
                "a refused bundle carries %d keys and %d rows" % [b.cell_keys.size(),
                        b.rows.size()])

    # AND THE ROW'S OWN SHAPE, which is structure and not content.
    var row_mutated: Dictionary = g.duplicate(true)
    ((row_mutated["fields"]["rows"] as Dictionary)["band.wetness"]
            as Dictionary)["_smuggled"] = true
    var rb := PerceptBundle.from_dict(row_mutated)
    check(rb.refused, "an undeclared name inside a row was accepted")
    check(rb.refusal.contains("band.wetness"),
            "the row refusal does not name the row: %s" % rb.refusal)

    # BUT AN UNKNOWN ROW NAME IS CONTENT AND VERSIONS INSTEAD OF REFUSING.
    var added: Dictionary = g.duplicate(true)
    (added["fields"]["rows"] as Dictionary)["band.not_yet_invented"] = {
        "lattice": "band", "groups": [""], "values": [[0.0, 0.0, 0.0]]}
    var ab := PerceptBundle.from_dict(added)
    check(not ab.refused, "an unknown ROW NAME refused, which breaks the additive bet the "
            + "version pair already governs: %s" % ab.refusal)
    check(ab.rows.has("band.not_yet_invented"), "the added row was dropped rather than carried")

    # AND A ROW ON A LATTICE THE SCHEMA HAS NO AXIS FOR IS A CHECK FAILURE, not
    # a refusal: it parsed, and it is unusable.
    var wrong: Dictionary = g.duplicate(true)
    ((wrong["fields"]["rows"] as Dictionary)["band.wetness"]
            as Dictionary)["lattice"] = "parcel"
    var wb := PerceptBundle.from_dict(wrong)
    check(not wb.refused, "a row naming an unknown lattice refused at the structural level")
    check(not bool(wb.check()["ok"]), "a row on an undeclared lattice passed check()")
    check(str(wb.check()["why"]).contains("parcel"),
            "the check does not name the lattice it does not know: %s" % str(wb.check()["why"]))
    print("golden: refusal at %d structural levels plus the row shape; an unknown row NAME "
            % at.size() + "versions instead")


func test_no_consumer_paints_one_lattices_row_through_the_others_join() -> void:
    """978 KEPT THE TWO KEY SPACES APART IN THE SCHEMA. This is the check that
    a CONSUMER cannot put them back together.

    `FieldOverlay`'s join is the residence one -- pixel to cell index -- and
    channel 1 now also carries node rows. `node.streamflow` handed to
    `paint_row` is 1,154 values indexed into a 5,684-cell join: the first 1,154
    cells take a plausible number from the wrong river and the rest go nodata.
    A basin painted through the wrong join looks like a basin, which is why
    this refuses rather than producing a texture nobody would question.

    The same thing one verb over: `probe.row` reads a node row through the
    residence layer's OWN node id -- decision 891's resolution, carried -- and
    never by splitting the residence key string, which 978 rejects as doing
    A-side a resolution already done B-side."""
    var fl := fixture()
    var window := fl.windows[0]
    var p := FixturePassthrough.over(fl)
    var b := p.bundle_for(window, 12, _dev_observer())
    var ov := FieldOverlay.new()
    ov.bind(residence(), b, Color(0.6, 0.6, 0.55, 1.0))
    check(ov.is_bound(), "the overlay did not bind")

    var band := ov.paint_row(b, "band.wetness", 0, 0.0, 1.0)
    check(bool(band.get("ok", false)), "a band row would not paint: %s" % str(band.get("why", "")))
    var node := ov.paint_row(b, "node.streamflow", 0, 0.0, 100000.0)
    check(not bool(node.get("ok", true)),
            "a node row painted through the residence join, which is the projection 978 "
            + "forbids arriving through a consumer")
    check(str(node.get("why", "")).contains("node")
                    and str(node.get("why", "")).contains("residence"),
            "the refusal does not name both joins: %s" % str(node.get("why", "")))
    check(not node.has("texture"), "a refused paint produced a texture anyway")

    # AND THE FIXTURE AGREES ABOUT WHICH LATTICE EACH ROW IS ON, which is where
    # the bundle read it from. Two homes for that fact is one too many.
    for row in b.row_names():
        check(b.lattice_of(row) == fl.lattice_of(window, row),
                "the bundle files %s on %s and the fixture on %s"
                % [row, b.lattice_of(row), fl.lattice_of(window, row)])
    print("transducer: a node row is refused by the residence join and %d rows agree with the "
            % b.rows.size() + "fixture about their lattice")


func test_probe_row_reads_a_node_row_through_the_residence_layers_own_node_id() -> void:
    """THE DEV VERB, WHICH IS EXEMPT BY CONTEXT AND NOT FROM BEING RIGHT.

    `probe.row` reads the artefact directly on purpose -- it is a development
    view of data the client holds whole. That exemption is about the boundary,
    not about arithmetic: reading a 1,154-long node row at a cell index would
    report a plausible flow from the wrong river, and a probe that lies is
    worse than no probe."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    v.show_field("deepest_winter", "band.pft_fractions", 45)
    var console := DevConsole.new()
    console.producer_kind = str(v.bundle.producer.get("kind", ""))
    var verbs := ConsoleVerbs.new()
    verbs.bind(console, v)

    var verts: PackedVector3Array = v.terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var centre := v.terrain.mesh_to_world(verts[5000], v.heightfield)
    var at := "%f %f" % [centre.x, centre.y]
    var lines := console.run("probe.row node.streamflow " + at)
    var text := ""
    for l in lines:
        text += str(l) + "\n"
    check(text.contains("[node lattice]"),
            "probe.row does not say which lattice the row rides: %s" % text)
    check(text.contains("at node ") and text.contains("ordinal"),
            "probe.row does not name the node it read, so a reader cannot tell it from a cell "
            + "read: %s" % text)
    var band_lines := console.run("probe.row band.wetness " + at)
    var band_text := ""
    for l in band_lines:
        band_text += str(l) + "\n"
    check(band_text.contains("[band lattice]"), "probe.row does not label a band row: %s"
            % band_text)
    check(not band_text.contains("ordinal"), "a band row was read through the node axis")
    print("probe.row: %s" % str(lines[1] if lines.size() > 1 else "no value line"))
    console.free()
    v.queue_free()


func test_the_flow_drape_paints_from_a_bundle_and_never_from_the_fixture() -> void:
    """ITEM 3: THE EXCLUSION THAT LEFT THE LIST.

    `node.streamflow` is indexed by river node, channel 1 carried one key axis,
    and the drape read the artefact because there was nowhere on the wire to
    put the row. 978 gives node rows their own axis, so this paints from a
    bundle and the join is an identity: a reach carries a `node` from the
    flowline export and the bundle's node axis is keyed by the same HUC10 ids.

    WHAT IS ASSERTED IS THE JOIN AND NOT THE PLUMBING. Every reach that has a
    node and is keyed takes the value the bundle carries for that node, checked
    against the bundle itself rather than against the fixture -- a drape that
    painted the right number through the wrong ordinal would look identical
    from outside."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    var r := v.show_flow("deepest_winter", 45)
    check(bool(r.get("ok", false)), "the drape would not paint from a bundle: %s"
            % str(r.get("why", "?")))
    if not bool(r.get("ok", false)):
        v.queue_free()
        return
    var counts: Dictionary = r["counts"]
    check(int(r["known"]) > 20000, "only %d reaches were painted from a value" % int(r["known"]))
    # AT LEAST TWO CLASSES OCCUPIED, NAMED BY PROPERTY RATHER THAN BY WHICH TWO.
    # This required `in_scale` and `zero` together, which was true of the trace
    # it was written against and stopped being true at 31efcab: the melt gate
    # landed, flow no longer decays to exactly nothing, and `deepest_winter` now
    # holds ZERO exact zeros across all 90 days where it used to hold 9,628.
    # That is a fact about the run, and a check that reported it as "the basin
    # came out all one state" would be accusing the drape of a discrimination
    # failure it does not have -- 860 below-scale against 28,624 in-scale.
    var occupied := PackedStringArray()
    for k in ["zero", "below_scale", "in_scale"]:
        if int(counts.get(k, 0)) > 0:
            occupied.append(str(k))
    check(occupied.size() >= 2,
            "the basin came out all one state: %s" % str(counts))
    # THE ZERO CLASS STILL HAS A WITNESS SOMEWHERE, and where it does not, the
    # loss is printed rather than inferred from a check that quietly stopped
    # being about it. `largest_fire` carries 90 exact zeros; `deepest_winter`
    # carries none.
    var zeros_anywhere := 0
    for win in v.fixture.windows:
        for d in v.fixture.days(win, "node.streamflow"):
            for val in v.fixture.day_values(win, "node.streamflow", d):
                if val == 0.0:
                    zeros_anywhere += 1
    print("flow: classes occupied %s in deepest_winter day 45; %d exact zeros across the "
            % [str(Array(occupied)), zeros_anywhere] + "whole fixture")
    check(zeros_anywhere > 0,
            "no exact zero anywhere in the fixture, so `FlowDisplay`'s separation of no-flow "
            + "from below-the-scale has no subject in this artefact at all. That is worth "
            + "knowing before the distinction is read as exercised.")

    # THE JOIN, SPOT-CHECKED AGAINST THE BUNDLE. Not against the fixture: what
    # is being checked is that the drape reads the wire, so the wire is the
    # authority the comparison uses.
    var b := v.bundle_at("deepest_winter", 45)
    var flow := v.fixture.day_values("deepest_winter", "node.streamflow", 45)
    var checked := 0
    for huc in [b.node_keys[0], b.node_keys[500], b.node_keys[b.node_keys.size() - 1]]:
        var mine := b.node_value_at(str(huc), FlowlineDrape.ROW)
        var theirs := flow[v.fixture.node_index_of(str(huc))]
        if is_nan(theirs):
            check(is_nan(mine), "node %s is nodata and the bundle carries %f" % [str(huc), mine])
        else:
            check(mine == theirs, "node %s reads %s on the wire and %s in the fixture"
                    % [str(huc), String.num(mine, 9), String.num(theirs, 9)])
        checked += 1
    check(checked == 3, "only %d nodes were spot-checked" % checked)

    # THE DRAPE IS IN THE SUBTREE AND THE SUBTREE'S RULE HOLDS FOR IT.
    check(FlowlineDrape.new().get_script().resource_path.begins_with(Transducer.SUBTREE),
            "the flow drape is not inside the transducer subtree")
    print("flow: %d reaches known, %d not -- %s" % [int(r["known"]), int(r["unknown"]),
            str(counts)])
    v.queue_free()


func test_a_withheld_node_draws_as_no_information_and_not_as_no_water() -> void:
    """THE DEFECT THIS ITEM ACTUALLY FIXES, DEMONSTRATED ON A WITHHOLDING WIRE.

    Against the passthrough nothing is withheld, so the old code and the new
    one draw the same basin and no test over the fixture could tell them apart.
    The interesting bundle is one that carries FEWER nodes than the map has
    reaches -- which is what an earned horizon is -- and the old drape drew
    every one of those as NO_FLOW: a dry river, which is a statement about the
    world rather than about what an observer was given.

    So this builds that bundle by truncating the node axis, which is the
    cheapest honest stand-in for a producer that withholds, and asserts the
    colour."""
    var v := TerrainView.new()
    get_root().add_child(v)
    v.build()
    v.bind_fields()
    var full := v.bundle_at("deepest_winter", 45)
    check(full != null and not full.node_keys.is_empty(), "no bundle to truncate")
    if full == null:
        v.queue_free()
        return

    # A WIRE THAT CARRIES A TENTH OF THE BASIN'S NODES.
    var narrow := PerceptBundle.from_dict(full.to_dict())
    var kept := PackedStringArray()
    var keep := int(full.node_keys.size() / 10)
    for i in keep:
        kept.append(full.node_keys[i])
    narrow.node_keys = kept
    var row: Dictionary = narrow.rows[FlowlineDrape.ROW]
    var trimmed := PackedFloat64Array()
    for i in keep:
        trimmed.append((row["values"][0] as PackedFloat64Array)[i])
    row["values"] = [trimmed]
    narrow.rows[FlowlineDrape.ROW] = row
    check(bool(narrow.check()["ok"]), "the narrowed bundle does not check: %s"
            % str(narrow.check()["why"]))

    var disp := FlowDisplay.new()
    var mesh := v.drape.paint_flow(narrow, disp)
    check(mesh != null, "the narrowed bundle painted nothing: %s" % v.drape.why_refused())
    var d := disp.describe()
    var counts: Dictionary = d["counts"]
    check(int(counts["not_keyed"]) > 1000,
            "only %d reaches fell outside the narrowed wire, so this is not testing a "
            % int(counts["not_keyed"]) + "withholding producer")
    check(int(d["known"]) > 0, "the narrowed wire painted no values at all")
    # THE WHOLE POINT: those reaches are NOT drawn as no water -- and "not the
    # same colour" is too weak a claim to be worth making. Two greys an eighth
    # of a step apart would pass an inequality and be one colour on screen, so
    # what is asserted is a SEPARATION, and a generous one because this is a
    # legibility claim being made without a photograph.
    var sep := (absf(FlowDisplay.NO_INFO.r - FlowDisplay.NO_FLOW.r)
            + absf(FlowDisplay.NO_INFO.g - FlowDisplay.NO_FLOW.g)
            + absf(FlowDisplay.NO_INFO.b - FlowDisplay.NO_FLOW.b))
    check(sep > 0.3, "nothing-known and no-water are %s apart in total channel distance, "
            % String.num(sep, 3) + "which is not a difference a viewer would see")
    # AND ON THE OTHER SIDE OF THE RAMP TOO: NO_INFO must not read as a value.
    for probe in [0.0, 1e-9, 0.001, 1.0, 900.0]:
        var c := FlowDisplay.new().colour_for(float(probe))
        check(not c.is_equal_approx(FlowDisplay.NO_INFO),
                "a flow of %s renders as nothing-known" % String.num(float(probe), 9))
    # AND THE COUNTS SEPARATE THE MAP'S GAP FROM THE WIRE'S.
    var wide := FlowDisplay.new()
    v.drape.paint_flow(full, wide)
    check(wide.n_not_keyed == 0, "%d reaches are unkeyed even on the full wire, so the "
            % wide.n_not_keyed + "flowline export names nodes the fixture's axis does not")
    check(wide.n_no_node == disp.n_no_node,
            "the map's own gap moved when the wire narrowed: %d against %d"
            % [wide.n_no_node, disp.n_no_node])

    # AND A ROW ON THE WRONG LATTICE REFUSES RATHER THAN PAINTING AN EMPTY MAP.
    var wrong := PerceptBundle.from_dict(full.to_dict())
    (wrong.rows[FlowlineDrape.ROW] as Dictionary)["lattice"] = "band"
    check(v.drape.paint_flow(wrong, FlowDisplay.new()) == null,
            "a streamflow row filed on the band lattice painted anyway")
    check(v.drape.why_refused().contains("node lattice"),
            "the refusal does not say what was wrong: %s" % v.drape.why_refused())
    print("flow: a wire carrying %d of %d nodes leaves %d reaches NO_INFO, %d NO_NODE, and "
            % [keep, full.node_keys.size(), int(counts["not_keyed"]), int(counts["no_node"])]
            + "%d still painted from a value" % int(d["known"]))
    v.queue_free()


# ============================================================================
# Decision 985: runtime conditions continuously, calibration stratifies.
# ============================================================================

func test_the_amplitude_field_has_no_step_on_a_class_boundary() -> void:
    """985 REJECTS A HARD LANDFORM CLASSIFIER CONDITIONING AMPLITUDE AT RUNTIME,
    and this class was one: `classify` picked a class and the class picked an
    amplitude, so every threshold in the rows was a rendered seam -- a crease
    across ground that does not change, on a line no landform owns. Convention
    1 says the same generally: a hard threshold anywhere is a bug.

    The chain is swept in SLOPE rather than through world positions, because
    the property is a fact about the arithmetic and driving it through the
    basin would exercise only the slopes this basin happens to have.

    The control is the step the old form had. Without it, 'the field is
    continuous' is a claim about a number nobody has compared to anything."""
    var df := detail_field()
    check(df.is_loaded(), "the detail rows did not load")
    if not df.is_loaded():
        return
    var c: Dictionary = df.rows["classifier"]
    var centres := [float(c["playa_below_slope_deg"]), float(c["floor_below_slope_deg"]),
            float(c["slope_below_slope_deg"])]
    check(float(c.get("blend_deg", 0.0)) > 0.0,
            "the rows declare no blend width, so every centre is still a cut")

    # A PARTITION OF UNITY, SWEPT ACROSS EVERY BOUNDARY.
    var worst_sum := 0.0
    var negative := 0
    var support := {}
    var samples := 0
    for i in 9000:
        var deg := float(i) * 0.005          # 0 .. 45 degrees
        var wts := df.slope_weights(deg)
        var sum := 0.0
        var live := 0
        for name in wts:
            var v := float(wts[name])
            if v < 0.0:
                negative += 1
            sum += v
            if v != 0.0:
                live += 1
        worst_sum = maxf(worst_sum, absf(sum - 1.0))
        support[live] = int(support.get(live, 0)) + 1
        samples += 1
    check(negative == 0, "%d weights came out negative" % negative)
    check(worst_sum < 1.0e-12, "the weights sum to 1 only within %s" % String.num(worst_sum, 15))

    # CONTINUITY IS NOT "THE STEP IS SMALL", AND MEASURING IT THAT WAY IS WHAT
    # THIS TEST GOT WRONG FIRST.
    #
    # The blended amplitude runs from 0.04 m to 1.6 m across a 0.4-degree
    # blend, so its slope is about 3.9 m per degree and ANY sweep reports a
    # step: 0.0197 m at 0.005-degree spacing, which is the derivative and not a
    # discontinuity. A threshold on that number would have been a threshold on
    # the sampling rate -- the same mistake the underfoot criterion made
    # against a raster, one field over.
    #
    # What separates a continuous function from a stepped one is that HALVING
    # THE SPACING HALVES THE STEP. A class boundary's jump does not shrink at
    # all, because it is a jump.
    var fine_h := 0.0005
    var coarse_h := 0.001
    var blend_fine := _worst_amplitude_step(df, fine_h, false)
    var blend_coarse := _worst_amplitude_step(df, coarse_h, false)
    var hard_fine := _worst_amplitude_step(df, fine_h, true)
    var hard_coarse := _worst_amplitude_step(df, coarse_h, true)
    var blend_ratio: float = blend_coarse / maxf(blend_fine, 1.0e-12)
    var hard_ratio: float = hard_coarse / maxf(hard_fine, 1.0e-12)
    check(absf(blend_ratio - 2.0) < 0.15,
            "halving the sweep spacing changed the blended field's largest step by %sx, and a "
            % String.num(blend_ratio, 3) + "continuous function's would halve")
    check(hard_ratio < 1.05,
            "the hard classifier's largest step shrank by %sx when the spacing halved, so it "
            % String.num(hard_ratio, 3) + "is not the discontinuity this is contrasted against")
    check(hard_fine > 20.0 * blend_fine,
            "at %s degrees the hard form steps %s m and the blend steps %s m, which is not "
            % [String.num(fine_h, 4), String.num(hard_fine, 4), String.num(blend_fine, 6)]
            + "the removal this claims")

    # COMPACT SUPPORT: away from a boundary exactly one stratum is live, and
    # never more than two. This is what makes the blend cost one or two noise
    # fields instead of five.
    check(not support.has(0), "some slope has no stratum at all")
    check(int(support.get(1, 0)) > samples / 2,
            "only %d of %d slopes have a single stratum, so the bands overlap and the support "
            % [int(support.get(1, 0)), samples] + "is not compact")
    var most := 0
    for k in support:
        most = maxi(most, int(k))
    check(most <= 2, "%d strata are live at once; the blend widths overlap their bands" % most)

    check(centres.size() == 3, "the rows declare %d slope centres" % centres.size())
    print("985: weights sum to 1 within %s over %d slopes, at most %d strata live at once. "
            % [String.num(worst_sum, 15), samples, most]
            + "Halving the sweep spacing takes the blend's largest step %s m -> %s m (%sx) "
            % [String.num(blend_coarse, 6), String.num(blend_fine, 6),
                    String.num(blend_ratio, 2)]
            + "and leaves the hard classifier's at %s m (%sx)"
            % [String.num(hard_fine, 3), String.num(hard_ratio, 2)])


## The largest change in conditioned amplitude between adjacent samples of a
## slope sweep at spacing `h`. `hard` selects the retired class-picking form.
##
## THE TWO FORMS ARE MEASURED BY THE SAME INSTRUMENT AT THE SAME SPACINGS,
## because the claim is about how each RESPONDS to the spacing and a
## comparison at one spacing cannot see that at all.
func _worst_amplitude_step(df: DetailField, h: float, hard: bool) -> float:
    var worst := 0.0
    var prev := NAN
    var deg := 0.0
    while deg <= 45.0:
        var amp := 0.0
        if hard:
            amp = df.amplitude_for(df.classify_by_slope(deg))
        else:
            var wts := df.slope_weights(deg)
            for name in wts:
                amp += float(wts[name]) * df.amplitude_for(str(name))
        if not is_nan(prev):
            worst = maxf(worst, absf(amp - prev))
        prev = amp
        deg += h
    return worst


func test_the_blend_cannot_break_the_exactness_at_a_parent_node() -> void:
    """THE ONE GUARD THE WHOLE METHOD RESTS ON, AND IT IS INDIFFERENT TO WHAT
    CONDITIONS THE AMPLITUDE.

    Every stratum's term is identically zero at a parent node, so any weighted
    sum of them is zero there -- for ANY weights, including ones nobody has
    calibrated. That is worth asserting after the conditioning changed rather
    than reasoning about, because it is the property a bad blend would break
    silently: a field that was exact before and is 2e-5 off now would look
    identical everywhere a person could see."""
    var hf := heightfield()
    var df := detail_field()
    if not df.is_loaded():
        return
    var nodes := 0
    var off := 0
    var between := 0
    for iy in range(600, 900, 7):
        for ix in range(300, 700, 11):
            var node := df.parent_node(ix, iy)
            if is_nan(hf.height_at_world(node.x, node.y)):
                continue
            nodes += 1
            if df.detail_at(node) != 0.0:
                off += 1
            # AND NON-ZERO BETWEEN THEM, or a field that refined nothing would
            # pass the line above by doing nothing.
            var mid := df.parent_node(ix, iy) + Vector2(df.parent_spacing_m * 0.5, 0.0)
            if df.detail_at(mid) != 0.0:
                between += 1
    check(nodes > 200, "only %d parent nodes were tested" % nodes)
    check(off == 0, "%d of %d parent nodes carry a non-zero blended detail term" % [off, nodes])
    check(between > nodes / 2, "only %d of %d midpoints moved, so the blended field is refining "
            % [between, nodes] + "almost nothing")
    print("985: the blended term is exactly zero at all %d parent nodes and non-zero at %d "
            % [nodes, between] + "of %d midpoints" % nodes)


func test_hand_conditions_the_amplitude_and_absence_is_full_strength() -> void:
    """985's SECOND CONDITIONING INPUT, LIVE.

    `taper_at` returned 1.0 everywhere for as long as no HAND raster was
    vendored, and said so. The layer landed and the mechanism that was wired
    rather than waited for plugged in without being rebuilt -- which is the
    whole reason it was wired before the data existed.

    THE ABSENCE RULE IS THE PART WORTH ASSERTING. HAND is NAN outside the basin
    AND where a filled descent reaches no channel at all -- 6.3 million pixels
    of endorheic and edge-draining ground. Undrained upland is not a floodplain,
    so absent HAND is FULL strength. Defaulting the other way would have
    flattened all of it on the strength of a missing value, and it would have
    looked like a working taper."""
    var hf := heightfield()
    var tl := terrain_layers()
    var df := DetailField.load_from(hf, DetailField.ROWS_PATH, 0.0, tl)
    check(df.is_loaded(), "the detail rows did not load")
    if not df.is_loaded() or not tl.is_loaded():
        print("985: no layer pin -- skipping, and saying so")
        return
    # THE PIN IS COMMITTED AND THE BYTES ARE NOT, so `is_loaded` is true in a
    # clone with none of them. Asking it and meaning "can I read a value" is
    # how the last two rounds of layer tests failed CI while passing here.
    check(tl.has(TerrainLayers.HAND), "the layers pin carries no hand layer")
    if not tl.has(TerrainLayers.HAND) or not tl.is_fetched():
        print("985: the layer pin is here and the tiles are not -- skipping the read half, "
                + "and saying so")
        return
    check(df.taper_source().contains("HAND at z=0"),
            "the taper does not say it is reading HAND: %s" % df.taper_source())

    var h: Dictionary = df.rows["hand_taper"]
    var floor_fraction := float(h["floor_fraction"])
    var full_above := float(h["full_strength_above_m"])
    check(floor_fraction > 0.0 and floor_fraction < 1.0,
            "the floor fraction is %s, so the taper either does nothing or erases the row"
            % String.num(floor_fraction, 3))

    # SWEPT OVER REAL GROUND, and bucketed by the HAND the layer actually
    # reports -- so this measures the field and not the arithmetic.
    var at_drainage := 0
    var high_up := 0
    var absent := 0
    var worst_low := 0.0
    var worst_high := 1.0
    var out_of_range := 0
    var seen := 0
    for ty in range(300, 1200, 17):
        for tx in range(200, 900, 19):
            var w := hf.texel_to_world(float(tx), float(ty))
            if is_nan(hf.height_at_world(w.x, w.y)):
                continue
            var hand := df.hand_m(w)
            var taper := df.taper_at(w)
            seen += 1
            if taper < floor_fraction - 1.0e-9 or taper > 1.0 + 1.0e-9:
                out_of_range += 1
            if is_nan(hand):
                absent += 1
                # THE RULE: no drainage relationship is full strength.
                if taper != 1.0:
                    worst_high = minf(worst_high, taper)
            elif hand <= 1.0:
                at_drainage += 1
                worst_low = maxf(worst_low, taper)
            elif hand >= full_above:
                high_up += 1
                if taper != 1.0:
                    worst_high = minf(worst_high, taper)
    check(seen > 500, "only %d places were swept" % seen)
    check(out_of_range == 0, "%d tapers fell outside [floor, 1]" % out_of_range)
    check(at_drainage > 0, "no sample sat within a metre of its drainage, so the suppressed "
            + "end of the taper is untested")
    check(high_up > 0, "no sample sat above the full-strength height")
    check(worst_low < floor_fraction + 0.2,
            "at the drainage the taper reaches only %s, against a floor of %s"
            % [String.num(worst_low, 3), String.num(floor_fraction, 3)])
    check(worst_high == 1.0, "a sample above the full-strength height, or with no drainage at "
            + "all, was tapered to %s" % String.num(worst_high, 4))
    check(absent > 0, "no sample lacked a HAND value, so the absence rule is untested here")

    # MONOTONE AND SATURATING, driven directly so every height is exercised
    # rather than only the ones this basin has.
    var prev := -1.0
    var jumps := 0
    for i in 2000:
        var probe := float(i) * 0.05
        var t := floor_fraction + (1.0 - floor_fraction) * DetailField._ramp(
                probe, 0.5 * full_above, 0.5 * full_above)
        if t < prev - 1.0e-12:
            jumps += 1
        prev = t
    check(jumps == 0, "the taper is not monotone in HAND (%d reversals)" % jumps)
    print("985: taper live on HAND -- %d samples, %d at the drainage (worst %s), %d above %s m, "
            % [seen, at_drainage, String.num(worst_low, 2), high_up, String.num(full_above, 0)]
            + "%d with no drainage at all and all of those at full strength" % absent)


func test_the_detail_is_band_limited_below_the_parent_spacing() -> void:
    """985 REQUIRES IT AND IT WAS TRUE BY CONSTRUCTION AND UNMEASURED.

    The term is `f(x)` minus `f` sampled on the parent lattice and interpolated
    back, so the parent-representable component is removed by subtraction --
    that is the same arithmetic the exactness rests on. What that argument does
    not cover is the AMPLITUDE, which decision 985 conditions continuously on
    HAND and slope: those are fields that vary over hundreds of metres and
    more, and a product of a band-limited field with a slowly-varying one has
    energy at the slow field's scale. Whether conditioning reintroduces
    parent-scale energy is a question about the basin and not about the
    construction, so it is measured.

    THE ANSWER IS NO, and the blended field is flatter than a single stratum's
    rather than less flat -- the taper is bounded and the conditioning fields
    vary smoothly, so the modulation lands well below the sill.

    The lattice is the control. Without it, 'the variogram stops growing' is a
    statement about the instrument.

    AND THIS IS NOT THE WHOLE OF PROPERTY 3, WHICH THE REFERENCE MEASURED AND
    DOES NOT MEET. What is asked here -- does conditioning add energy at the
    parent scale -- is a different question from how much energy sits AT the
    parent, and the published audit answers the second one: `P[f]` is `f`
    sampled every parent spacing, and every octave of `f` is at or below half
    that, so those samples are an ALIAS of `f` rather than a low-pass of it.
    Subtracting an alias does not remove parent-scale energy, it adds a
    parent-scale field of comparable amplitude -- 23% to 37% of the detail
    term's variance survives a one-parent-cell average, against 4% to 16% for
    `f` alone. Properties 2 and 3 are in genuine tension there: a field exactly
    zero on a regular lattice carries lattice-aligned structure somewhere, and
    the alternatives concentrate it into a visible quilt on the parent grid,
    which is decision 974's refused seam class arriving by a third route. Which
    property gives is a corpus ruling. The recipe here is the published one and
    is not quietly diverging from it."""
    var hf := heightfield()
    var df := detail_field()
    if not df.is_loaded():
        return
    var parent := df.parent_spacing_m
    var centre := hf.texel_to_world(500.0, 700.0)
    var at_sixteenth := _variogram_of(hf, df, centre, parent / 16.0, "talus")
    var at_parent := _variogram_of(hf, df, centre, parent, "talus")
    var at_four := _variogram_of(hf, df, centre, parent * 4.0, "talus")
    var blend_parent := _variogram_of(hf, df, centre, parent, "")
    var blend_four := _variogram_of(hf, df, centre, parent * 4.0, "")
    var lat_parent := _variogram_of(hf, df, centre, parent, "lattice")
    var lat_four := _variogram_of(hf, df, centre, parent * 4.0, "lattice")
    check(at_parent > 0.0 and lat_parent > 0.0, "a variogram came out zero")
    if at_parent <= 0.0 or lat_parent <= 0.0:
        return

    # ENERGY IS BELOW THE PARENT: the variogram climbs across the band the
    # function synthesises. A field with nothing in it would satisfy the
    # saturation check below by being flat everywhere.
    check(at_parent > 3.0 * at_sixteenth,
            "the detail's variogram only grows %sx from a sixteenth of the parent spacing to "
            % String.num(at_parent / maxf(at_sixteenth, 1e-30), 2)
            + "the parent, so there is little in the band it is supposed to fill")

    # AND NOT ABOVE IT: it has saturated by the parent spacing.
    var detail_ratio: float = at_four / at_parent
    var blend_ratio: float = blend_four / maxf(blend_parent, 1e-30)
    var lattice_ratio: float = lat_four / lat_parent
    check(detail_ratio < 1.5, "the detail's variogram grows %sx between the parent spacing and "
            % String.num(detail_ratio, 2) + "four times it, so it carries energy the parent "
            + "lattice should already hold")
    check(blend_ratio < 1.5, "the conditioned field grows %sx over the same span, so blending "
            % String.num(blend_ratio, 2) + "amplitude on HAND and slope has put parent-scale "
            + "energy back into a term that is supposed to refine below it")
    check(lattice_ratio > 3.0, "the lattice itself only grows %sx over that span, so this "
            % String.num(lattice_ratio, 2) + "instrument cannot see growth and the saturation "
            + "above means nothing")
    print("985: over parent -> 4x parent the detail grows %sx, the conditioned field %sx, and "
            % [String.num(detail_ratio, 2), String.num(blend_ratio, 2)]
            + "the lattice it refines %sx" % String.num(lattice_ratio, 1))


## Half the mean squared difference over one lag. `which` picks the stratum,
## "" for the conditioned field, "lattice" for the surface being refined.
func _variogram_of(hf: Heightfield, df: DetailField, centre: Vector2, lag: float,
                   which: String) -> float:
    var total := 0.0
    var n := 0
    for k in 240:
        var p := centre + Vector2(float(k % 16) * 731.0, float(k / 16) * 617.0)
        var q := p + Vector2(lag, 0.0)
        var a: float
        var b: float
        if which == "lattice":
            a = hf.height_at_world(p.x, p.y)
            b = hf.height_at_world(q.x, q.y)
        else:
            a = df.detail_at(p, which)
            b = df.detail_at(q, which)
        if is_nan(a) or is_nan(b):
            continue
        total += (a - b) * (a - b)
        n += 1
    return 0.0 if n == 0 else 0.5 * total / float(n)


func test_the_field_is_c1_and_says_which_term_binds() -> void:
    """985 ASKS FOR AT LEAST C1. It is met exactly at the floor, and which term
    holds it there is worth knowing.

    Three things compose: the gradient noise's fade, the Catmull-Rom that puts
    the coarse component back, and the smoothstep weights that condition the
    amplitude. The fade is the quintic, C2 at the cell boundaries; the weights
    are smoothstep, also C2 at their knots. CATMULL-ROM IS C1 AND NO MORE, so
    the composed field is C1 and no more -- and that term is not free to
    change, because the exactness at the parent rests on putting the coarse
    component back through the SAME interpolant the heightfield uses. Asking
    for C2 would mean a different interpolant, which would leave a residue at
    every node.

    WHAT CANNOT BE MEASURED HERE, AND IT IS NOT SHYNESS. The field's own
    derivative is not numerically checkable in world space: a position arrives
    in a `Vector2`, which at this basin's eastings steps 0.125 m, and the
    finest synthesised wavelength is 0.244 m. A difference quotient would be
    sampling a two-texel-wide feature at one and a half texels. So the
    smoothness of the COMPONENTS is asserted where they live -- in unit space,
    where no world coordinate is involved -- and the composition is an
    argument rather than a measurement, stated as one."""
    # THE FADE: value and first two derivatives at both knots.
    check(DetailField._fade(0.0) == 0.0 and DetailField._fade(1.0) == 1.0,
            "the fade does not pin its endpoints")
    var h := 1.0e-4
    for knot in [0.0, 1.0]:
        var t := float(knot)
        var d1: float = (DetailField._fade(t + h) - DetailField._fade(t - h)) / (2.0 * h)
        var d2: float = (DetailField._fade(t + h) - 2.0 * DetailField._fade(t)
                + DetailField._fade(t - h)) / (h * h)
        check(absf(d1) < 1.0e-6, "the fade's slope at t=%s is %s, so the noise creases at every "
                % [String.num(t, 0), String.num(d1, 9)] + "cell boundary")
        check(absf(d2) < 1.0e-3, "the fade's curvature at t=%s is %s, so the noise is C1 and "
                % [String.num(t, 0), String.num(d2, 6)] + "not the C2 a quintic fade buys")

    # THE WEIGHTS: smoothstep, flat at both ends, so conditioning adds no
    # crease of its own.
    for pair in [[0.0, 0.0], [1.0, 1.0]]:
        var x := float(pair[0])
        var want := float(pair[1])
        check(DetailField._ramp(x, 0.5, 0.5) == want,
                "the weight ramp does not pin its endpoints")
        var slope: float = (DetailField._ramp(x + h, 0.5, 0.5)
                - DetailField._ramp(x - h, 0.5, 0.5)) / (2.0 * h)
        check(absf(slope) < 1.0e-3, "the weight ramp's slope at its %s end is %s, so the "
                % [("lower" if x == 0.0 else "upper"), String.num(slope, 9)]
                + "amplitude field creases where a stratum's band begins")

    # AND THE BINDING TERM IS NAMED IN THE FILE THAT OWNS IT, so the next
    # person asking "can this be C2" finds the reason it cannot before
    # changing the interpolant.
    var src := FileAccess.open("res://src/terrain/heightfield.gd", FileAccess.READ).get_as_text()
    check(src.contains("PUBLIC BECAUSE THE DETAIL FUNCTION NEEDS THIS EXACT INTERPOLANT"),
            "heightfield.gd no longer records why the detail function needs its interpolant")
    print("985: fade C2 at both knots, weights C2 at theirs, Catmull-Rom C1 -- so the field is "
            + "C1, at 985's floor, and the binding term is the one the exactness requires")


# ============================================================================
# Phase 8 lane B4/B5: the token issuer, and the skin that consumes it.
# ============================================================================

## One subject's drawn look, as a string a consumer could remember it by. The
## attack in the skin test is a dictionary lookup, so the key has to be what a
## consumer can actually see -- a colour, at the precision an eye or a frame
## buffer has, and not a float the consumer would have no way to read.
static func _look_of(seed: int) -> String:
    var c := RungSkin.tint_delta(seed, 1.0)
    return "%d,%d,%d" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)),
            int(round(c.b * 255.0))]


func test_a_token_rotates_at_all_three_boundaries_and_nowhere_else() -> void:
    """DECISION 368'S THREE BOUNDARIES, EACH ONE SHOWN.

    A consumer that treats a token as a durable identity is correct against
    every producer that never rotates one, which is every producer this repo
    has. The defect is invisible until live B, so the rotation has to be
    exercised before then or not at all -- which is the whole reason a toy
    issuer is worth building.

    The interesting case is the fourth check in the envelope group. A
    per-subject ordinal kept in the map entry is the obvious implementation and
    it is wrong: the entry is dropped at exit, so the ordinal restarts, and a
    returning subject is handed the token it left with. An exit rotation that
    rotates back is worse than none, because it looks like one."""
    var iss := TokenIssuer.for_session("session-a", 0x5eed)
    var t0 := iss.observe("subject-1", "life_form")
    check(t0.length() == TokenIssuer.TOKEN_HEX,
            "a token is %d hex digits and the class declares %d"
                    % [t0.length(), TokenIssuer.TOKEN_HEX])
    check(not t0.contains("subject-1"),
            "the subject's own id is inside its token, which is a global id in a costume")

    # STABLE WHERE NOTHING HAPPENED. Tracking a moving body across frames is
    # the thing a name is FOR; an issuer that rotated per moment would have
    # closed the leak by making channel 2 useless.
    for _i in 50:
        iss.observe("subject-1", "life_form")
    check(iss.token_for("subject-1") == t0,
            "the token moved over fifty moments with no boundary crossed, so nothing "
            + "downstream can follow a subject at all")

    # 1. THE RUNG CHANGED.
    var t1 := iss.observe("subject-1", "specific")
    check(t1 != t0, "the observer's rung changed and the name did not")

    # 2. THE SUBJECT LEFT THE ENVELOPE.
    iss.left_envelope("subject-1")
    check(iss.token_for("subject-1") == "",
            "a subject outside the envelope still has a name")
    check(not iss.is_resident("subject-1"), "the map kept a subject that left")
    var t2 := iss.observe("subject-1", "specific")
    check(t2 != t1, "a subject left the envelope and came back to the same name")
    # The control for the per-subject-ordinal defect: leave, and return AT THE
    # ORIGINAL RUNG. Every earlier name must stay spent.
    iss.left_envelope("subject-1")
    var t3 := iss.observe("subject-1", "life_form")
    check(t3 != t0 and t3 != t1 and t3 != t2,
            "a returning subject was handed a name it had already spent, so the exit "
            + "boundary rotates in a cycle rather than forward")

    # 3. RESTORATION.
    var t4 := iss.observe("subject-2", "life_form")
    var before := iss.epoch()
    iss.restore()
    check(iss.resident() == 0, "restoration left %d tokens live" % iss.resident())
    check(iss.epoch() == before + 1, "restoration did not move the epoch")
    check(iss.observe("subject-2", "life_form") != t4, "restoration did not rotate")
    check(iss.observe("subject-1", "life_form") != t3, "restoration did not rotate")

    var rot := iss.rotations()
    for b in TokenIssuer.BOUNDARIES:
        check(int(rot.get(b, 0)) > 0,
                "boundary %s never fired, so this test is not exercising it" % str(b))

    # PER OBSERVER, NEVER GLOBAL. One subject, two sessions, two names -- the
    # property 20.4.3 rules and the one a stable id would break outright.
    var sa := TokenIssuer.for_session("session-a", 0x5eed)
    var sb := TokenIssuer.for_session("session-b", 0x5eed)
    check(sa.observe("subject-1", "life_form") != sb.observe("subject-1", "life_form"),
            "two observers were handed one name for one subject, which is the global id "
            + "the per-observer rule exists to refuse")

    # OPAQUE MEANS UNREPRODUCIBLE WITHOUT THE SALT. A party holding the subject
    # list and the session name, but not the producer's salt, gets nothing.
    var guess := TokenIssuer.for_session("session-a", 0x0badbeef)
    check(guess.observe("subject-1", "life_form")
                    != TokenIssuer.for_session("session-a", 0x5eed)
                            .observe("subject-1", "life_form"),
            "the same inputs under a different salt produced the same token, so the "
            + "derivation is a pure function of identity and is invertible by anyone "
            + "who can enumerate subjects")

    # DETERMINISTIC OVER THE EPISODE, which is the narrowing of decision 180
    # the class header states. Same salt, same call sequence, same names.
    var r1 := TokenIssuer.for_session("s", 11)
    var r2 := TokenIssuer.for_session("s", 11)
    var same := true
    for i in 20:
        var who := "subj-%d" % (i % 5)
        if r1.observe(who, "life_form") != r2.observe(who, "life_form"):
            same = false
        if i % 7 == 0:
            r1.left_envelope(who)
            r2.left_envelope(who)
    check(same, "replaying an episode from its start reissued different tokens, so a "
            + "recorded channel-2 stream cannot be replayed at all")

    # AND THE NAMES DO NOT COLLIDE OVER A SESSION'S LENGTH. The map is bounded
    # by occupancy; the issuance count is not, and a birthday collision hands
    # two subjects one name.
    var many := TokenIssuer.for_session("s", 7)
    var seen := {}
    for i in 20000:
        var who := "subj-%d" % i
        seen[many.observe(who, "life_form")] = true
        many.left_envelope(who)
    check(seen.size() == many.issued(),
            "%d issuances produced %d distinct tokens" % [many.issued(), seen.size()])
    print("tokens: %d issued with no collision; rotates at %s and holds still over 50 "
            % [many.issued(), str(TokenIssuer.BOUNDARIES)] + "moments in between")


func test_a_rotation_is_not_an_erasure_and_the_map_rides_the_envelope() -> void:
    """WHAT ROTATION BUYS, AND WHAT IT DOES NOT -- BOTH MEASURED.

    An honest mechanism is one nobody over-reads later, and the way a bound
    stops being read is that only its good half was ever demonstrated. So both
    halves are here: the cross-episode case rotation closes, and the
    within-episode case it does not and was never meant to.

    The second half asserts a WEAKNESS, deliberately. If it ever starts
    failing, something has changed that this file should be told about."""
    var subjects := ["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8"]

    # THE HALF THAT IS BOUGHT. A consumer remembers every name it resolved,
    # then the episode ends. Nothing it holds appears again.
    var iss := TokenIssuer.for_session("observer", 0x1234)
    var memory := {}
    for s in subjects:
        memory[iss.observe(s, "specific")] = s
    iss.restore()
    var carried := 0
    for s in subjects:
        if memory.has(iss.observe(s, "specific")):
            carried += 1
    check(carried == 0,
            "%d of %d names survived a restoration, so a client carries a dictionary "
                    % [carried, subjects.size()]
            + "through the boundary that was supposed to spend it")

    # THE HALF THAT IS NOT, SHOWN WORKING. Within an episode a subject's
    # position is unchanged either side of a rotation, so a consumer matches
    # the two by where they are. No wire encoding prevents this and the
    # mechanism does not claim to.
    var at := {}
    for i in subjects.size():
        at[subjects[i]] = Vector2(float(i) * 100.0, 0.0)
    var ep := TokenIssuer.for_session("observer", 0x99)
    var where := {}                         # token -> position, before
    for s in subjects:
        where[ep.observe(s, "life_form")] = at[s] as Vector2
    var relinked := 0
    var still_named := 0
    for s in subjects:
        # The rung boundary rotates the name. Checked rather than assumed: if
        # the names had NOT changed, the relink below would succeed for a
        # reason that says nothing about positions.
        if where.has(ep.observe(s, "specific")):
            still_named += 1
        var here: Vector2 = at[s]
        for tok in where:
            if (where[tok] as Vector2).distance_to(here) < 1.0:
                # the old name at this position; the consumer has re-linked
                relinked += 1
                break
    check(still_named == 0, "%d of %d names survived the rung boundary, so the relink below "
            % [still_named, subjects.size()] + "proves nothing about position")
    check(relinked == subjects.size(),
            "within-episode positional linkage failed for %d of %d subjects. That is not "
                    % [subjects.size() - relinked, subjects.size()]
            + "a success: 20.4.3 states this bound openly and the client should not come "
            + "to believe rotation does more than it does.")

    # THE MAP RIDES THE ENVELOPE AND NOT THE ROSTER. The distinction is the
    # difference between a structure sized by who is nearby and one sized by
    # who exists, and both are bounded, which is why the wrong one survives
    # review.
    var roster := 5000
    var envelope := 40
    var e := TokenIssuer.for_session("observer", 5)
    for i in roster:
        e.observe("r-%d" % i, "life_form")
        if i >= envelope:
            e.left_envelope("r-%d" % (i - envelope))
    check(e.issued() == roster, "%d subjects passed through and %d names were issued"
            % [roster, e.issued()])
    check(e.resident() == envelope,
            "the map holds %d entries after %d subjects passed through an envelope of "
                    % [e.resident(), roster]
            + "%d. A map sized against the roster is correct and bounded and wrong by "
                    % envelope
            + "two orders of magnitude.")
    print("tokens: %d issued over the episode, %d resident -- the map is %dx smaller than "
            % [e.issued(), e.resident(), roster / envelope]
            + "the roster; cross-episode linkage 0 of %d, within-episode %d of %d and "
                    % [subjects.size(), relinked, subjects.size()]
            + "openly so")


func test_the_skin_keys_on_precision_and_dies_with_the_token() -> void:
    """B5, AND THE ONE PROPERTY THAT MAKES THE SEED RULE LOAD-BEARING.

    Two things the skin has to get right, and one of them is not testable here
    on purpose. Amplitude keying on carried precision rather than on
    distance-to-truth is enforced by WHERE THIS FILE LIVES: the transducer
    subtree's dependency scan is what makes truth unreachable, and an assertion
    here that the skin does not use the truth would be a guard that cannot
    fail. Structure, not a test.

    The one that is testable is the seed. A perturbation seeded on anything
    that outlives a token is a visual fingerprint, and 'the look is the same
    look' re-identifies a subject one layer below the name that rotated. So the
    attack is run twice -- once against the token seed, once against a stable
    seed as the negative control -- because a re-identification count of zero
    means nothing unless the same experiment can produce a non-zero one."""
    # THE AMPLITUDE. Zero at exact, and exactly zero.
    check(RungSkin.amplitude_for(1.0) == 0.0,
            "the skin leaves a residue of %s at the finest rung, which is a permanent lie "
                    % String.num(RungSkin.amplitude_for(1.0), 9)
            + "about the finest thing this client knows")
    check(RungSkin.amplitude_for(0.0) == 1.0, "the coarsest rung is not at full amplitude")
    var prev := 2.0
    for i in 101:
        var p := float(i) / 100.0
        var a := RungSkin.amplitude_for(p)
        check(a <= prev + 1.0e-9, "the amplitude rose as the precision improved, at p=%s"
                % String.num(p, 2))
        prev = a
    # Flat at both ends, so a subject drifting toward a boundary does not have
    # the wobble stop dead as it arrives.
    var h := 1.0e-4
    for end_p in [0.0, 1.0]:
        var x := float(end_p)
        var slope: float = (RungSkin.amplitude_for(x + h) - RungSkin.amplitude_for(x - h)) / (2.0 * h)
        check(absf(slope) < 1.0e-3, "the amplitude's slope at p=%s is %s"
                % [String.num(x, 0), String.num(slope, 6)])
    # The finest rung on the ladder, and an unknown one, both add nothing.
    check(RungSkin.amplitude_for(RungSkin.precision_of_rung("specific")) == 0.0,
            "the finest rung on the ladder is not at zero amplitude")
    check(RungSkin.amplitude_for(RungSkin.precision_of_rung("nonesuch-rung")) == 0.0,
            "a rung name this client does not know drew full wobble. An unrecognised rung "
            + "means the skin does not know how coarse this is; the honest answer is to "
            + "add nothing, not to paint the basin.")
    check(RungSkin.rung_delta("specific") == Color(0.0, 0.0, 0.0, 0.0),
            "the finest rung carries a colour step, so the client never draws what it was "
            + "given unskinned")
    for r in RungSkin.RUNGS:
        check(RungSkin.tint_delta(RungSkin.seed_for_subject("tok", "hue"),
                RungSkin.amplitude_for(RungSkin.precision_of_rung(str(r)))).a == 0.0,
                "the skin moved alpha at rung %s. A skin that can make a thing transparent "
                        % str(r) + "can make it absent.")

    # THE SEAM SURVIVES THE WOBBLE, as a measurement. A skin whose noise
    # straddles its own rung step looks like it is reporting something and is
    # reporting the hash.
    var margin := RungSkin.separation_margin()
    check(margin > 0.0,
            "two adjacent rungs overlap by %s once both are wobbled as far as they go, so "
                    % String.num(-margin, 4)
            + "the rung a thing is drawn at is not readable off the picture")

    # ROTATION CHANGES THE LOOK, AT EACH BOUNDARY. Amplitude is held at 1.0
    # throughout so that only the seed differs -- comparing the look at two
    # rungs would move the rung step and the amplitude too, and would pass
    # whether or not the seed had anything to do with it.
    var iss := TokenIssuer.for_session("observer", 0x777)
    var w := _look_of(RungSkin.seed_for_subject(iss.observe("s1", "life_form"), "hue"))
    var moves := {
        TokenIssuer.RUNG_CHANGE: func() -> void: iss.observe("s1", "specific"),
        TokenIssuer.ENVELOPE_EXIT: func() -> void: iss.left_envelope("s1"),
        TokenIssuer.RESTORATION: func() -> void: iss.restore(),
    }
    for boundary in TokenIssuer.BOUNDARIES:
        (moves[boundary] as Callable).call()
        # READ WITHOUT ROTATING AGAIN. Where the move left the subject
        # resident, its name is already the rotated one; where the move
        # emptied the entry, one observation at the rung it is already at
        # re-issues without crossing a second boundary. Observing blind would
        # have made every case a rung change and the test would pass whichever
        # boundary was broken.
        var tok := iss.token_for("s1")
        if tok == "":
            tok = iss.observe("s1", "specific")
        var after := _look_of(RungSkin.seed_for_subject(tok, "hue"))
        check(after != w,
                "the token rotated at %s and the look did not. The wobble is then a "
                        % str(boundary)
                + "fingerprint that outlives the name, which rebuilds the linkage the "
                + "rotation was for one layer down.")
        w = after

    # THE ATTACK, RUN BOTH WAYS. A consumer remembers what each subject LOOKED
    # like in one episode and tries the lookup in the next.
    var subjects := ["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8"]
    var ep := TokenIssuer.for_session("observer", 0x2468)
    var by_look := {}
    for s in subjects:
        by_look[_look_of(RungSkin.seed_for_subject(ep.observe(s, "life_form"), "hue"))] = s
    ep.restore()
    var hits := 0
    for s in subjects:
        var look := _look_of(RungSkin.seed_for_subject(ep.observe(s, "life_form"), "hue"))
        if str(by_look.get(look, "")) == s:
            hits += 1
    check(hits == 0, "%d of %d subjects were re-identified from their look alone after a "
            % [hits, subjects.size()] + "restoration")

    # THE CONTROL. The same experiment with the seed keyed on the subject
    # instead of on its name -- which is what any stable seed amounts to.
    var control := {}
    for s in subjects:
        control[_look_of(StableHash.of_name("%s/hue" % s))] = s
    var control_hits := 0
    for s in subjects:
        if str(control.get(_look_of(StableHash.of_name("%s/hue" % s)), "")) == s:
            control_hits += 1
    check(control_hits == subjects.size(),
            "the stable-seeded control re-identified %d of %d, so the zero above is a "
                    % [control_hits, subjects.size()]
            + "property of the experiment rather than of the seed rule")

    # CHANNEL-1 FLORA SEEDS ON THE GROUND, and that is not a loosening: a
    # background plant carries no name because it is not individuated on the
    # wire at all, so there is no identity for a look to outlive.
    var k1 := VegetationScatter.placement_key(
            VegetationScatter.family_key("grass"), Vector2(100.0, 200.0), 30.0)
    var k2 := VegetationScatter.placement_key(
            VegetationScatter.family_key("grass"), Vector2(160.0, 200.0), 30.0)
    check(k1 != k2, "two sub-cells share a placement key, so this check proves nothing")
    check(RungSkin.seed_for_placement(k1, "hue") != RungSkin.seed_for_placement(k2, "hue"),
            "two stands of one family got one wobble, so the skin is flat where the "
            + "placement is not")
    check(RungSkin.seed_for_placement(k1, "hue") == RungSkin.seed_for_placement(k1, "hue"),
            "one stand's wobble moved between two reads of it")
    check(RungSkin.seed_for_placement(k1, "hue") != RungSkin.seed_for_placement(k1, "height"),
            "two attributes of one stand share a seed, so they wobble together and the "
            + "skin reports one number twice")

    # AND IT COMPUTES FROM BUNDLE CONTENTS ALONE, which was one of the five
    # tests the bundle's fields were chosen against. Running it is the whole
    # point of building the skin before anything draws it.
    var fs := family_set()
    var fl := fixture()
    if fs.is_loaded() and not fs.nodes().is_empty():
        var mock := MockProducer.over(FixturePassthrough.over(fl), fs)
        var centres := {}
        for i in 6:
            for j in 6:
                centres["cell|%d_%d" % [i, j]] = Vector2(float(i) * 10000.0, float(j) * 10000.0)
        var observer := _dev_observer()
        observer["ground_point"] = PackedFloat64Array([0.0, 0.0, 0.0])
        var b := mock.bundle_for(fl.windows[0], 0, observer, centres)
        var near := "cell|0_0"
        var far := "cell|5_5"
        # THE LIFE FORM HAS TO BE ONE THE MOCK CAN REFINE, and asking for the
        # first family instead is how this was written the first time: `grass`
        # has no specific-rung asset, so it is never refined anywhere, and the
        # skin correctly read the coarse rung under the observer's own feet.
        # A test that picks its subject by ordinal rather than by property
        # fails on correct code.
        var life := fs.parent_of(str(fs.nodes()[0]))
        check(RungSkin.refined_node(b, near, life) != "",
                "the cell under the observer carries no overlay, so the skin has no "
                + "boundary to read")
        check(RungSkin.refined_node(b, far, life) == "",
                "a cell three envelopes away carries an overlay")
        check(RungSkin.earned_rung(b, near, life) == "specific"
                        and RungSkin.earned_rung(b, far, life) == "life_form",
                "the skin reads the same rung either side of the mock's boundary")
        check(RungSkin.amplitude_for(RungSkin.precision_of_rung(
                        RungSkin.earned_rung(b, near, life))) == 0.0,
                "the refined cell still draws a wobble")
        check(RungSkin.amplitude_for(RungSkin.precision_of_rung(
                        RungSkin.earned_rung(b, far, life))) > 0.5,
                "the unrefined cell draws almost no wobble, so the boundary is invisible")
        # A FAMILY WITH NOWHERE FINER TO GO READS COARSE EVERYWHERE, including
        # under the observer. That is the skin reporting the wire honestly:
        # nothing was earned there because there is nothing there to earn.
        var unrefinable := ""
        for lfn in fs.life_forms():
            if fs.parent_of(str(lfn)) == "" and RungSkin.refined_node(b, near, str(lfn)) == "":
                unrefinable = str(lfn)
                break
        check(unrefinable != "" and RungSkin.earned_rung(b, near, unrefinable) == "life_form",
                "a family with no finer node was drawn as refined, or this basin's families "
                + "all have specific assets and this check no longer bites")
    check(RungSkin.DEV_ONLY and not RungSkin.enabled(false),
            "the skin draws in a release build. Its perturbing half is a transducer adding "
            + "what the producer did not send, which is a corpus question this repo does "
            + "not answer by shipping it.")
    print("skin: amplitude 0 at the finest rung, rungs separated by %s beyond the widest "
            % String.num(margin, 3)
            + "wobble, 0 of %d re-identified across a restoration against %d of %d for a "
                    % [subjects.size(), control_hits, subjects.size()]
            + "stable seed")


# ============================================================================
# Decision 985: conformance against the published reference.
# ============================================================================

const CONFORMANCE_PATH := "res://assets/detail/detail_conformance.json"
const DETAIL_ROWS_PATH := "res://assets/detail/detail_rows.json"


## A float64 from the bit pattern the artefact carries it as.
##
## THE HEX IS THE CONTRACT AND THE DECIMAL IS FOR READERS, which is the
## artefact's own rule and is load-bearing here rather than fastidious: this
## engine's string-to-double is not correctly rounded, so reading the decimal
## would compare the reference against a number a digit of the reference away.
static func _f64(h: String) -> float:
    var t := h.trim_prefix("0x")
    while t.length() < 16:
        t = "0" + t
    var b := PackedByteArray()
    b.resize(8)
    b.encode_u32(0, t.substr(8, 8).hex_to_int())
    b.encode_u32(4, t.substr(0, 8).hex_to_int())
    return b.decode_double(0)


## The bits of a float64, for a message that has to show which ulp.
static func _bits(v: float) -> String:
    var b := PackedByteArray()
    b.resize(8)
    b.encode_double(0, v)
    return "0x%08x%08x" % [b.decode_u32(4), b.decode_u32(0)]


## One number out of a vector, or NAN where the artefact writes an absence.
static func _vec_num(v) -> float:
    if v == null:
        return NAN
    return _f64(str((v as Dictionary)["hex"]))


## The conformance artefact, parsed -- and parsed STRICTLY, which it once was
## not able to be.
##
## It carried 88 bare `NaN` tokens, which RFC 8259 has no literal for, so this
## parser refused the whole document rather than the token; the gate read it
## through a substitution of the artefact's own `null`-means-absent rule. The
## emitter applies that rule itself now and dumps with NaN refused at the
## source, so the shim is gone rather than left in place working. A workaround
## that outlives its defect is indistinguishable from a requirement.
func conformance() -> Dictionary:
    var f := FileAccess.open(CONFORMANCE_PATH, FileAccess.READ)
    if f == null:
        return {}
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func test_the_detail_function_conforms_to_its_published_vectors() -> void:
    """THE CROSS-REPO CHECK 985 ASKS FOR: two implementations of one published
    function, compared at 300 positions the other side chose.

    What makes this worth having rather than reassuring is that it is not a
    tolerance test on the answer -- it is a test of the whole chain. The mixer,
    the five-part gradient key with the octave in it, the world seed, the
    octave ladder, the anisotropic coordinate, Catmull-Rom, the residual
    normalisation, the slope chain, the margin, the taper and the two absence
    rules all have to be right together, because any one of them wrong moves
    every number."""
    var c := conformance()
    check(not c.is_empty(), "the conformance artefact did not parse")
    if c.is_empty():
        return
    var parent: Dictionary = c["parent"]
    var spacing := DetailField.scalar_of(parent, "spacing_m", 0.0)
    var hf := heightfield()
    var df := DetailField.load_from(hf, DETAIL_ROWS_PATH, spacing)
    check(df.is_loaded(), "the detail field did not load: %s" % df.why_absent)
    if not df.is_loaded():
        return

    # THE SEED IS DERIVED FROM A NAME, and this is the check that the name is
    # the derivation rather than a label beside a magic number.
    check(df.world_seed == int(c["world_seed"]),
            "the rows carry seed %d and the vectors were emitted at %d"
                    % [df.world_seed, int(c["world_seed"])])
    check(StableHash.of_name(df.world_name) == df.world_seed,
            "`%s` hashes to %d and the rows declare seed %d, so the name is decoration"
                    % [df.world_name, StableHash.of_name(df.world_name), df.world_seed])

    # THE LATTICE CORNER, READ FROM THE ARTEFACT AND CHECKED AGAINST THE
    # VECTORS STANDING ON IT.
    #
    # This engine's string-to-double reads the corner's decimal to the FARTHER
    # of its two neighbouring doubles -- 2.22e-10 m out where the correct
    # rounding is 1.10e-11 m -- in its JSON parser and its own source lexer
    # alike. That moves every parent node, so the exact node test misses and
    # property 2 fails in float64 against a reference that read the decimal
    # correctly. The artefact carries `origin_hex` now, so the corner arrives
    # as bits and the engine's parse stops mattering for this constant.
    #
    # AND THE PUBLISHED CORNER IS CHECKED, NOT TRUSTED. A node is
    # `origin + (i + 0.5) * spacing`, so every node vector implies a corner;
    # all 64 must imply the one the artefact publishes. That is the pairing the
    # vectors could not previously make: each position round-trips through its
    # own hex perfectly, so an implementation with a bad decimal parser passed
    # all 300 while standing on a shifted lattice.
    # TWO ARTEFACTS CARRY THIS BLOCK AND THEY ARE COMPARED, NOT MAINTAINED IN
    # PARALLEL. The rows and the vectors both describe the lattice, and for one
    # cut only the vectors carried the corner as bits -- which cost nothing
    # while the gate happened to read that one, and would have cost a reader
    # taking the lattice from the other exactly the ulp this whole thread is
    # about. So the whole block is compared rather than the one field that went
    # missing: a check on the field that broke last time is a check on last
    # time. A third artefact carrying it joins this comparison rather than
    # being trusted.
    var rf := FileAccess.open(DETAIL_ROWS_PATH, FileAccess.READ)
    var rows_doc: Dictionary = JSON.parse_string(rf.get_as_text()) if rf != null else {}
    var rows_parent: Dictionary = rows_doc.get("parent", {})
    check(not rows_parent.is_empty(), "the rows artefact describes no parent lattice")
    # THE MESSAGE NAMES THE FIELD THAT DIFFERS, not the first 200 characters of
    # each block. The whole point of this pair is that the divergence which
    # matters is an ulp inside a hex string: dumping the blocks shows two
    # decimals that print identically and truncates before reaching the field
    # that moved. A control that fires with an unreadable reason is a control
    # somebody turns off.
    var differing := PackedStringArray()
    for k in rows_parent:
        if not parent.has(k) or JSON.stringify(parent[k]) != JSON.stringify(rows_parent[k]):
            differing.append("%s: rows=%s vectors=%s" % [str(k),
                    JSON.stringify(rows_parent[k]), JSON.stringify(parent.get(k, null))])
    for k2 in parent:
        if not rows_parent.has(k2):
            differing.append("%s: missing from the rows" % str(k2))
    check(differing.is_empty(),
            "the rows and the vectors describe different parent lattices, and two copies of "
            + "one fact are safe only while something compares them -- %s" % str(differing))

    # READ THROUGH THE ACCESSOR, WHICH KNOWS BOTH SHAPES. Until 31efcab this
    # was `origin_hex`, a parallel array of patterns beside a list of decimals;
    # it is now nested per element, the form this client asked for. The check is
    # that the corner arrives as BITS, not that it arrives under a particular
    # key -- a test pinned to the spelling would have failed on the artefact
    # that adopted the convention it argued for.
    check(PublishedBits.is_protected(parent, "origin"),
            "the artefact's parent block publishes the lattice corner without a pattern, so it "
            + "arrives as a decimal and this engine cannot read it to the right double")
    var ox := DetailField.scalar_element_of(parent, "origin", 0)
    var oy := DetailField.scalar_element_of(parent, "origin", 1)
    if is_nan(ox) or is_nan(oy):
        check(false, "the published corner did not read back from its pattern")
        return
    var nodes: Array = ((c["classes"] as Dictionary)["parent_node"] as Dictionary)["vectors"]
    var agree := 0
    for v in nodes:
        var vv: Dictionary = v
        var nxf := _vec_num(vv["x"])
        var nyf := _vec_num(vv["y"])
        var ix := int(round((nxf - hf.origin_x) / spacing - 0.5))
        var iy := int(round((hf.origin_y - nyf) / spacing - 0.5))
        var gx := nxf - (float(ix) + 0.5) * spacing
        var gy := nyf + (float(iy) + 0.5) * spacing
        if gx == ox and gy == oy:
            agree += 1
    check(agree == nodes.size(),
            "%d of %d node vectors stand on the corner the artefact publishes and the rest "
                    % [agree, nodes.size()]
            + "do not, so the vectors and the lattice they are measured from have drifted "
            + "apart")
    # THE ENGINE DEFECT IS STILL THERE AND NO LONGER REACHES THIS CONSTANT.
    # Asserted rather than assumed, in the direction that matters: the day the
    # parse is fixed this fails, and the right response is to stop carrying the
    # hex rather than to leave a workaround nobody remembers the reason for.
    check(ox != hf.origin_x,
            "the engine now reads the lattice corner to the same double the artefact "
            + "publishes. The string-to-double defect is fixed, `origin_hex` is no longer "
            + "buying anything here, and that is worth acting on rather than leaving.")
    df.parent_origin_x = ox
    df.parent_origin_y = oy

    # THE RESIDUAL IS READ, NOT ESTIMATED, at the parent the artefact publishes.
    for lf in df.landforms():
        check(df.residual_source(str(lf)).begins_with("published"),
                "%s recomputed its residual at the artefact's own parent: %s"
                        % [str(lf), df.residual_source(str(lf))])

    var tol := float((c["tolerance"] as Dictionary)["tolerance_m"])
    var classes: Dictionary = c["classes"]
    var worst_all := 0.0
    var total := 0

    # -- the three position classes ------------------------------------------
    for cls in ["parent_node", "stratum", "blended"]:
        var entry: Dictionary = classes[cls]
        var worst := 0.0
        for v in (entry["vectors"] as Array):
            var vv: Dictionary = v
            var got := df.detail_at64(_vec_num(vv["x"]), _vec_num(vv["y"]),
                    _vec_num(vv.get("slope_deg", null)), _vec_num(vv.get("hand_m", null)),
                    str(vv.get("landform", "")))
            worst = maxf(worst, absf(got - _vec_num(vv["d_m"])))
            total += 1
        worst_all = maxf(worst_all, worst)
        if cls == "parent_node":
            # EXACT, NOT WITHIN TOLERANCE. Property 2 is the constraint the
            # rest of the method rests on, and a tolerance here would let a
            # conforming implementation lose it silently.
            check(worst == 0.0, "`d` is %s m at a parent node and the rule is exactly zero"
                    % String.num(worst, 17))
        else:
            check(worst <= tol, "class %s is out by %s m against a tolerance of %s m"
                    % [cls, String.num(worst, 17), String.num(tol, 17)])

    # -- the chain, driven directly ------------------------------------------
    var wc: Dictionary = classes["weight_chain"]
    var wworst := 0.0
    var sumworst := 0.0
    var taperworst := 0.0
    for v in (wc["vectors"] as Array):
        var vv: Dictionary = v
        var got := df.slope_weights(_vec_num(vv["slope_deg"]))
        var sum := 0.0
        for k in (vv["weights"] as Dictionary):
            wworst = maxf(wworst, absf(float(got.get(k, 0.0))
                    - _vec_num((vv["weights"] as Dictionary)[k])))
        for k2 in got:
            sum += float(got[k2])
        sumworst = maxf(sumworst, absf(sum - 1.0))
        if vv.has("taper_at_hand_10m"):
            taperworst = maxf(taperworst, absf(df.taper_for(10.0)
                    - _vec_num(vv["taper_at_hand_10m"])))
        total += 1
    check(wworst <= tol, "the slope chain is out by %s m" % String.num(wworst, 17))
    check(sumworst == 0.0, "the weights sum to 1 with error %s. They telescope, so the sum is "
            % String.num(sumworst, 17) + "1 by construction and any error at all is a "
            + "different construction.")
    check(taperworst <= tol, "the HAND taper is out by %s" % String.num(taperworst, 17))

    # -- the carrier probe, which is meant to bite ---------------------------
    #
    # Each pair is closer together than one single-precision step. In float64
    # they are two positions with two answers; through a `Vector2` they are one
    # position evaluated twice. Both halves are asserted, because the point is
    # to REPORT the carrier limit rather than round it away -- and a test that
    # only checked the float64 arm would be silent about the thing the class
    # exists to show.
    var fp: Dictionary = classes["float32_probe"]
    var pworst := 0.0
    var distinct := 0
    var collapsed := 0
    for v in (fp["vectors"] as Array):
        var vv: Dictionary = v
        var ma: Dictionary = vv["a"]
        var mb: Dictionary = vv["b"]
        var da := df.detail_at64(_vec_num(ma["x"]), _vec_num(ma["y"]),
                _vec_num(ma.get("slope_deg", null)), _vec_num(ma.get("hand_m", null)),
                str(ma.get("landform", "")))
        var db := df.detail_at64(_vec_num(mb["x"]), _vec_num(mb["y"]),
                _vec_num(mb.get("slope_deg", null)), _vec_num(mb.get("hand_m", null)),
                str(mb.get("landform", "")))
        pworst = maxf(pworst, maxf(absf(da - _vec_num(ma["d_m"])),
                absf(db - _vec_num(mb["d_m"]))))
        if da != db:
            distinct += 1
        var fa := Vector2(_vec_num(ma["x"]), _vec_num(ma["y"]))
        var fb := Vector2(_vec_num(mb["x"]), _vec_num(mb["y"]))
        if fa == fb:
            collapsed += 1
        total += 2
    var pairs := (fp["vectors"] as Array).size()
    check(pworst <= tol, "the carrier probe's own values are out by %s m"
            % String.num(pworst, 17))
    check(distinct == pairs, "%d of %d probe pairs evaluated to the same number in float64, "
            % [pairs - distinct, pairs] + "so the pairs are not separated by the arithmetic "
            + "and the class proves nothing")
    check(collapsed == pairs, "%d of %d probe pairs are separable through a Vector2. The "
            % [collapsed, pairs] + "pairs are built an eighth of a float32 step apart, so "
            + "this passing would mean the carrier changed -- which is worth knowing, not "
            + "worth ignoring.")

    print("985: %d vectors, worst %s m against a %s m tolerance; parent nodes exactly zero; "
            % [total, String.num(worst_all, 17), String.num(tol, 17)]
            + "corner read from `origin_hex` and confirmed by %d/%d node vectors (%s "
                    % [agree, nodes.size(), _bits(ox)]
            + "published, %s from this engine's parse of the same decimal)" % _bits(hf.origin_x))
    print("985: the carrier probe -- %d/%d pairs distinct in float64, %d/%d collapse through "
            % [distinct, pairs, collapsed, pairs] + "a Vector2, which is the limit reported "
            + "rather than rounded away")


func test_the_five_part_hash_is_the_general_one() -> void:
    """`of5` exists because the gradient key is five parts wide and runs a few
    million times in one calibration pass. It is a shortcut, and a shortcut
    that disagrees with the thing it is short for moves the whole world."""
    var cases := [[0, 0, 0, 0, 0], [1, 2, 3, 4, 5], [-1, -2, -3, -4, -5],
            [2714988810, 0x67726164, 8, -913, 4471], [0x7fffffff, 1, 0, -1, 0x7fffffff]]
    for cs in cases:
        var a: Array = cs
        check(StableHash.of5(a[0], a[1], a[2], a[3], a[4]) == StableHash.over(a),
                "of5%s disagrees with over(%s)" % [str(a), str(a)])
    # And the control: it is not a constant function of four of its arguments.
    check(StableHash.of5(1, 2, 3, 4, 5) != StableHash.of5(1, 2, 3, 4, 6),
            "of5 ignores its fifth part, so the octave is not in the gradient key")
    check(StableHash.of5(1, 2, 3, 4, 5) != StableHash.of5(1, 2, 4, 3, 5),
            "of5 is order-blind, so a lattice node and an octave index are interchangeable")
    print("hash: of5 agrees with over() on %d cases and separates every argument"
            % cases.size())


# ============================================================================
# Decision 986: the instrument, and the gate re-keyed onto it.
# ============================================================================

## A tilted plane through the origin, gradient `s` at azimuth `deg`.
static func _plane(s: float, deg: float) -> Callable:
    var th := deg_to_rad(deg)
    var gx := s * cos(th)
    var gy := s * sin(th)
    return func(x: float, y: float) -> float: return gx * x + gy * y


func test_the_structure_function_refuses_below_the_spacing_it_declares() -> void:
    """THE HONESTY RULE, WHICH IS WHAT LETS A RASTER AND A FUNCTION BE ASKED
    THE SAME QUESTION.

    A surface declares the spacing it is honest at and returns CANNOT ANSWER
    below it. That is the clause the retired instrument had no equivalent of:
    §23.976 measured it returning the sampling step at every resolution, so it
    was reporting the grid rather than the ground and any amplitude passed.

    The absence is `null` and the test says so, because the three plausible
    alternatives -- zero, NAN, a number -- are all things a real surface
    returns. This repo's rasters give NAN at nodata."""
    var plane := _plane(0.1, 0.0)
    var win := Vector2(0.0, 0.0)
    var span := Vector2(1000.0, 1000.0)
    var lags := [0.25, 0.5, 1.0, 2.0, 4.0, 16.0, 64.0]

    # A function answers everywhere.
    var fn := StructureFunction.of_function(plane, win, span, "a plane")
    var sf_fn := fn.s_of_lag(lags, 0.5, "plain", 4000, 1)
    for lag in lags:
        check(sf_fn[lag] != null, "a continuous function refused a %s m lag" % str(lag))

    # A raster declaring a metre cannot.
    var ras := StructureFunction.of_raster(plane, 1.0, win, span, "a plane, sampled at 1 m")
    var sf_ras := ras.s_of_lag(lags, 0.5, "plain", 4000, 1)
    var refused := 0
    for lag in lags:
        if float(lag) < 1.0:
            check(sf_ras[lag] == null,
                    "a 1 m raster answered at a %s m lag. Below its own spacing it is "
                            % str(lag)
                    + "grading its own interpolation, which is exactly what the retired "
                    + "instrument did.")
            refused += 1
        else:
            check(sf_ras[lag] != null, "a 1 m raster refused a %s m lag" % str(lag))
    check(refused == 2, "%d lags were refused and 2 are below a metre" % refused)

    # THE SAME SURFACE, TWO DECLARATIONS, TWO ANSWERS -- which is the point:
    # the refusal is a property of the CLAIM and not of the array, so a raster
    # resampled finer still answers where it always did.
    check(sf_fn[0.25] != null and sf_ras[0.25] == null,
            "the declared spacing did not change what the instrument would answer, so the "
            + "declaration is decorative")

    # And a lag the window cannot hold is also a refusal rather than a number
    # from a stencil hanging off the edge.
    var tight := StructureFunction.of_function(plane, win, Vector2(10.0, 10.0), "a small window")
    check(tight.s_of_lag([64.0], 0.5, "plain", 400, 1)[64.0] == null,
            "a 64 m lag was answered inside a 10 m window")
    print("986: the honesty rule -- a function answers at %d/%d lags, a 1 m raster at %d, "
            % [lags.size(), lags.size(), lags.size() - refused]
            + "and the difference is the declaration and not the surface")


func test_the_plain_form_reports_the_slope_and_the_detrended_form_cannot_see_it() -> void:
    """THE TWO FORMS, ON GROUND WHOSE ANSWER IS KNOWN WITHOUT MEASURING IT.

    Agreement on the basin is worth much less than agreement on a plane,
    because on the basin a shared misreading looks exactly like conformance --
    which is what the amplitude defect in 985 was, both implementations
    computing one wrong number and agreeing perfectly.

    So: a plane, where the plain form's answer is analytic; a plane plus known
    roughness, where the question is which form NOTICES; and the second
    difference, which annihilates any linear trend exactly and must therefore
    return zero on a plane rather than something small."""
    var win := Vector2(0.0, 0.0)
    var span := Vector2(4000.0, 4000.0)
    var lags := [2.0, 4.0, 8.0, 16.0, 32.0, 64.0]
    var grad := 0.1

    # THE DETRENDED FORM ON A PLANE IS EXACTLY ZERO, not nearly. A second
    # difference of a linear function is zero in exact arithmetic and the
    # arithmetic here is exact -- the three samples are a linear combination
    # that cancels -- so a tolerance would be hiding something.
    var flat := StructureFunction.of_function(_plane(grad, 31.0), win, span, "a plane")
    var det := flat.s_of_lag(lags, 0.5, "detrended", 4000, 3)
    var worst_det := 0.0
    for lag in lags:
        worst_det = maxf(worst_det, absf(float(det[lag])))
    # AT THE ROUNDING FLOOR AND NO LONGER EXACTLY ZERO, and the reason is the
    # corrected directions rather than a weaker claim. `z(x+v) - 2z(x) + z(x-v)`
    # cancels to zero for any linear `z` in exact arithmetic. While every offset
    # was axis-aligned the three products rounded alike and the cancellation was
    # exact in float64 too; a direction off the axes makes `g . (x+v)` and
    # `g . x + g . v` round differently, and this basin's coordinates are large
    # enough that the residue is the ulp of a million-metre product rather than
    # of a height. So the assertion is the floor, stated in what it is a floor
    # OF: the residue over the surface's own vertical scale across the window.
    var vertical_scale := grad * minf(span.x, span.y)
    check(worst_det < 1.0e-12 * vertical_scale,
            "the second difference of a plane is %s m against a %s m relief across the "
                    % [String.num(worst_det, 14), String.num(vertical_scale, 0)]
            + "window. It cancels exactly in exact arithmetic, so anything above the "
            + "rounding floor means it is not blind to gradient and the whole reason for "
            + "the second form is gone.")

    # THE PLAIN FORM IS AZIMUTH-FREE NOW, AND THE CONTROL SHOWS IT WAS NOT.
    #
    # Convention 6 as amended asks that a mechanism asserted to act be shown
    # acting: the effect where it claims one, beside a control showing its
    # absence when it is disabled. So the corrected direction family is
    # asserted to read the isotropic median of |cos| -- 0.7071 -- at every
    # azimuth, and the retired pooling is run at the same azimuths to show it
    # reading something else. A fix asserted only by its new number could be
    # asserting a coincidence.
    var isotropic := 0.7071067811865476
    var pooled_spread := 0.0
    for pair in [[0.0, 1.0], [15.0, 0.836516], [26.57, 0.670820], [45.0, 0.707107]]:
        var deg := float((pair as Array)[0])
        var was := float((pair as Array)[1])
        var s := StructureFunction.of_function(_plane(grad, deg), win, span, "a plane")
        var now := float(s.s_of_lag([8.0], 0.5, "plain", 4000, 5)[8.0]) / (grad * 8.0)
        check(absf(now - isotropic) < 0.02,
                "on a plane at %s degrees the corrected family reads %s of the gradient and "
                        % [String.num(deg, 2), String.num(now, 4)]
                + "the isotropic median of |cos| is %s. A continuous surface samples the "
                        % String.num(isotropic, 4)
                + "circle evenly, so the reading must not depend on where the hill points.")
        # THE CONTROL: the same plane, the same lag, the retired pooling.
        var old_read := float(s.s_of_lag([8.0], 0.5, "plain", 4000, 5, true)[8.0]) / (grad * 8.0)
        check(absf(old_read - was) < 0.01,
                "the retired pooling reads %s at %s degrees and the analytic prediction for "
                        % [String.num(old_read, 4), String.num(deg, 2)]
                + "four pooled offsets is %s" % String.num(was, 4))
        pooled_spread = maxf(pooled_spread, absf(old_read - isotropic))
    check(pooled_spread > 0.1,
            "the retired pooling and the corrected family read a plane alike, within %s. The "
                    % String.num(pooled_spread, 4)
            + "fix would then be asserting a number it was already returning.")
    # And the exponent is untouched by either, which is why this was invisible
    # to every exponent check for as long as it was there.
    var tilt := StructureFunction.of_function(_plane(grad, 26.57), win, span, "a plane")
    for legacy in [false, true]:
        var law := StructureFunction.fit_law(
                tilt.s_of_lag(lags, 0.5, "plain", 4000, 7, legacy), 100.0, "plain", 1.0, 100.0)
        check(absf(float(law["exponent"]) - 1.0) < 1.0e-6,
                "a plane does not fit exponent 1 with pooling %s: got %s"
                        % ["on" if legacy else "off", String.num(float(law["exponent"]), 8)])
    print("986: the corrected family reads %s of a gradient at every azimuth; the retired "
            % String.num(isotropic, 4)
            + "pooling ranged to %s away from it and both fit exponent 1 exactly"
                    % String.num(pooled_spread, 3))

    # WHICH FORM NOTICES ROUGHNESS. The plane is steep enough that the plain
    # form is dominated by it; the roughness is added at a known amplitude and
    # a wavelength inside the measured lags.
    var rough := 0.5
    var moved_by := {}
    for form in StructureFunction.FORMS:
        var bare := StructureFunction.of_function(_plane(grad, 26.57), win, span, "plane")
        var bumpy := StructureFunction.of_function(
                func(x: float, y: float) -> float:
                    return (grad * cos(deg_to_rad(26.57)) * x
                            + grad * sin(deg_to_rad(26.57)) * y
                            + rough * sin(x * TAU / 6.0) * sin(y * TAU / 6.0)),
                win, span, "plane plus known roughness")
        var a := float(bare.s_of_lag([5.0], 0.5, str(form), 40000, 11)[5.0])
        var b := float(bumpy.s_of_lag([5.0], 0.5, str(form), 40000, 11)[5.0])
        # ABSOLUTE, BECAUSE ONE OF THE BASELINES IS EXACTLY ZERO. The
        # reference's table is relative and its base surface was real ground,
        # which has curvature; a pure plane's second difference is 0, so the
        # relative move is infinite and says nothing. What both forms can be
        # asked is how many metres they moved for a known metre of roughness.
        moved_by[str(form)] = b - a
        if str(form) == "detrended":
            # At the rounding floor rather than exactly zero: see the note on
            # the same assertion above -- an offset off the axes makes the
            # three-term cancellation inexact in float64 at these coordinates.
            check(a < 1.0e-12 * grad * minf(span.x, span.y),
                    "the detrended form reads %s m on a bare plane, which is above the "
                            % String.num(a, 14)
                    + "rounding floor for a window with %s m of relief across it"
                            % String.num(grad * minf(span.x, span.y), 0))
        print("986: %s m of roughness on a %s gradient takes the %s form from %s m to %s m"
                % [String.num(rough, 2), String.num(grad, 2), str(form),
                        String.num(a, 6), String.num(b, 4)])
    # THE TWO FORMS AGAINST EACH OTHER, which is the actual claim and needs no
    # threshold anybody chose. The reference's table is relative and its base
    # was real ground; a pure plane's second difference is exactly zero, so a
    # relative move here is infinite and says nothing. What is comparable is
    # how many metres each form moved for one known metre of roughness.
    # MAGNITUDE AND NOT DIRECTION, which is a correction to how this was first
    # written. Added roughness can LOWER the plain median: the statistic is a
    # quantile of `|g . v + roughness|`, and on a slope the roughness moves
    # individual pairs both ways, so the median can fall. That was once filed
    # on the producing side as documented behaviour of the pooled sampling and
    # it survives the correction, so the honest claim is about how far the two
    # forms move and not which way.
    var d_plain := absf(float(moved_by["plain"]))
    var d_det := absf(float(moved_by["detrended"]))
    check(d_det > 3.0 * d_plain,
            "one metre of roughness moves the plain form by %s m and the detrended form by "
                    % String.num(d_plain, 4)
            + "%s m. The second form exists because the first barely sees roughness on a "
                    % String.num(d_det, 4)
            + "slope; if they respond alike, the criterion cannot discriminate whichever "
            + "form it is declared on.")
    check(d_plain < 0.2 * rough,
            "the plain form moved %s m for %s m of roughness, which is more than nearly "
                    % [String.num(d_plain, 4), String.num(rough, 2)]
            + "blind -- the base plane may be too shallow for this comparison to bite")
    print("986: %s m of roughness moves the plain form %s m and the detrended form %s m, "
            % [String.num(rough, 2), String.num(d_plain, 4), String.num(d_det, 4)]
            + "which is %sx -- magnitudes, because the plain form's direction of response "
                    % String.num(d_det / maxf(d_plain, 1.0e-12), 1)
            + "is not guaranteed")


func test_the_instrument_repeats_and_recovers_a_known_exponent() -> void:
    """TWO PROPERTIES A GRADER NEEDS BEFORE ANYONE GRADES ANYTHING WITH IT.

    It has to repeat -- a statistic that moves between runs cannot be compared
    across repos at all -- and it has to recover an exponent it was given, or
    the fitted law is decorative."""
    var win := Vector2(0.0, 0.0)
    var span := Vector2(4000.0, 4000.0)
    var lags := [2.0, 4.0, 8.0, 16.0, 32.0, 64.0]
    # NOT ON A PLANE, WHICH IS THE FIRST THING THIS WAS WRITTEN ON. A plane's
    # height difference depends only on the OFFSET and not on where the pair
    # sits, so every sample in a direction returns the identical number and the
    # quantile is the same whatever the seed. The check passed for a reason
    # that had nothing to do with seeding -- a control that cannot discriminate
    # on the surface it is given.
    var bumpy := func(x: float, y: float) -> float:
        return 0.05 * x + sin(x * 0.37) * cos(y * 0.41)
    var s := StructureFunction.of_function(bumpy, win, span, "a rough surface")
    check(JSON.stringify(s.s_of_lag(lags, 0.5, "plain", 4000, 2))
                    == JSON.stringify(s.s_of_lag(lags, 0.5, "plain", 4000, 2)),
            "two runs at one seed disagree, so nothing measured here can be compared to "
            + "anything measured anywhere else")
    check(JSON.stringify(s.s_of_lag(lags, 0.5, "plain", 4000, 2))
                    != JSON.stringify(s.s_of_lag(lags, 0.5, "plain", 4000, 3)),
            "the seed changes nothing, so the sampling is not seeded and the agreement "
            + "above means only that the code is deterministic")
    # And the plane, shown to be the wrong subject for that question -- as a
    # COMPARISON rather than as an equality, because once the offsets came off
    # the axes the rounding of `g . (x+v)` depends on `x` and the last bits move
    # with the seed. The claim was never bit-equality; it is that a plane cannot
    # DISCRIMINATE a seed, and the way to say that is beside a surface that can.
    var flat := StructureFunction.of_function(_plane(0.05, 10.0), win, span, "a plane")
    var flat_a := flat.s_of_lag(lags, 0.5, "plain", 4000, 2)
    var flat_b := flat.s_of_lag(lags, 0.5, "plain", 4000, 99)
    var rough_a := s.s_of_lag(lags, 0.5, "plain", 4000, 2)
    var rough_b := s.s_of_lag(lags, 0.5, "plain", 4000, 99)
    var flat_move := 0.0
    var rough_move := 0.0
    for lag in lags:
        flat_move = maxf(flat_move, absf(float(flat_a[lag]) - float(flat_b[lag]))
                / absf(float(flat_a[lag])))
        rough_move = maxf(rough_move, absf(float(rough_a[lag]) - float(rough_b[lag]))
                / absf(float(rough_a[lag])))
    check(flat_move < 1.0e-12 and rough_move > 1.0e-4,
            "changing the seed moves a plane by %s and a rough surface by %s. A plane's "
                    % [String.num(flat_move, 14), String.num(rough_move, 6)]
            + "height difference is a function of the offset alone, so it cannot "
            + "discriminate a seed at all -- which is exactly why it was the wrong subject "
            + "for the check above.")

    # THE DETAIL FUNCTION IS THE SUBJECT, and it is the one surface here that
    # can answer at every lag. Its exponent is the row's own `spectral_slope`
    # by construction, so the fit has something to be checked against.
    var df := detail_field()
    if not df.is_loaded():
        return
    var hf := heightfield()
    var centre := hf.texel_to_world(500.0, 700.0)
    var strata := df.landforms()
    check(strata.size() > 0, "the rows declare no strata")
    # NOT A NUMBER OF STRATA. The set is read from the rows at run time: one of
    # them may yet be merged or ruled away, and a test that had memorised five
    # would go quiet about the one that left rather than failing.
    # EVERY STRATUM THE ROWS DECLARE, AND THE TARGET IS THE ROW'S OWN NUMBER.
    # For fBm the structure function goes as `l^H` and `spectral_slope` IS that
    # exponent here, so each stratum has an analytic answer and they span
    # 0.55 to 1.20 -- which is what makes this a recovery rather than one
    # number landing near one other number.
    # FITTED WELL BELOW THE PARENT, AND THAT IS NOT A CONVENIENCE.
    #
    # Measured first at a 100 m parent over lags of 1 to 32 m, where every
    # stratum came out LOW -- playa 1.112 against a declared 1.2, floor 0.905
    # against 0.95 -- and the size of the miss tracked the declared exponent.
    # That is the subtraction showing up in the fit: `d` is `f` minus what the
    # parent can carry, so the energy is removed from exactly the lags nearest
    # the parent spacing, and a smooth field keeps more of its variance there
    # to lose. A fit whose top lag is a third of the parent is measuring the
    # subtraction as much as the spectrum.
    #
    # So the same strata are fitted under the 1 km parent this client actually
    # draws the far field at, over 1 to 64 m -- under a tenth of the parent at
    # the top -- where the recovery is inside 0.01.
    var lags_d := [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0]
    var worst_err := 0.0
    var lines := PackedStringArray()
    for raw_name in strata:
        var name := str(raw_name)
        var want := DetailField.scalar_of(df.row(name), "spectral_slope", NAN)
        var surf := StructureFunction.of_function(
                func(x: float, y: float) -> float:
                    return df.detail_at64(x, y, NAN, NAN, name),
                centre - Vector2(2000.0, 2000.0), Vector2(4000.0, 4000.0),
                "the detail function, stratum %s" % name)
        var sf := surf.s_of_lag(lags_d, 0.5, "detrended", 1600, 13)
        var fitted := StructureFunction.fit_law(sf, df.parent_spacing_m, "detrended")
        check(not fitted.is_empty() and not fitted.has("refused"),
                "no law could be fitted to stratum %s over the measurable range" % name)
        if fitted.is_empty() or fitted.has("refused"):
            continue
        var got := float(fitted["exponent"])
        worst_err = maxf(worst_err, absf(got - want))
        check(absf(got - want) < 0.03,
                "stratum %s declares exponent %s and measures %s. The structure function of "
                        % [name, String.num(want, 3), String.num(got, 3)]
                + "an fBm goes as l^H and the row's `spectral_slope` is that H, so these are "
                + "the same number and a gap means one of the two is not what it says.")
        check(float(fitted["parent_spacing_m"]) == df.parent_spacing_m,
                "the fitted law for %s does not carry the parent it was measured against"
                        % name)
        lines.append("%s %s/%s" % [name, String.num(got, 3), String.num(want, 2)])
    # A ROW WITHOUT A PARENT IS REFUSED RATHER THAN WARNED ABOUT.
    var any := StructureFunction.of_function(
            func(x: float, y: float) -> float:
                return df.detail_at64(x, y, NAN, NAN, str(strata[0])),
            centre - Vector2(2000.0, 2000.0), Vector2(4000.0, 4000.0), "one stratum")
    var no_parent := StructureFunction.fit_law(
            any.s_of_lag(lags_d, 0.5, "detrended", 400, 13), 0.0, "detrended")
    check(no_parent.has("refused"),
            "a law fitted without a parent spacing was emitted anyway. An amplitude at a lag "
            + "is a claim about which octaves are synthesised, so one number under two "
            + "parents describes two different spectral spans.")
    print("986: measured/declared exponent over %d strata read from the rows -- %s; worst "
            % [strata.size(), " ".join(lines)] + "gap %s" % String.num(worst_err, 3))


func test_walk_mode_is_shut_for_986s_reasons_and_itemises_which() -> void:
    """THE GATE WAS RIGHT AND ITS MECHANISM WAS NOT.

    `walk_available` returned the retired instrument's `ok` verbatim. Walk mode
    was therefore shut BECAUSE THE DRAWN GROUND IS SAMPLED COARSELY, not
    because 986's conditions are unmet -- so refining the sample would have
    opened it on a criterion the corpus has retired. An outcome that is right
    for a retired reason is the shape that survives review and fails later.

    Re-keyed on the three conditions, itemised, with a third outcome beside
    pass and fail. The payoff is that when the grading form is ruled exactly
    one row flips and a reader can see which -- instead of a boolean that has
    been hiding the fact that condition 1 has been met since yesterday."""
    var fl := fixture()
    var b := FixturePassthrough.over(fl).bundle_for(fl.windows[0], 0, _dev_observer())
    var w := DebugPlayer.walk_available(b, 1000.0, 4000.0)
    check(not bool(w["ok"]), "walk mode opened")
    check((w["conditions"] as Array).size() == DebugPlayer.CONDITIONS.size(),
            "%d conditions reported against %d named"
                    % [(w["conditions"] as Array).size(), DebugPlayer.CONDITIONS.size()])
    check(int(w["not_gradeable"]) == 3 and int(w["met"]) == 0,
            "with no evidence at all, %d conditions read MET and %d not gradeable. Nothing "
                    % [int(w["met"]), int(w["not_gradeable"])]
            + "has been measured, and that is three NOT_GRADEABLE rather than three failures.")

    # THE CONDITION THIS CLIENT CAN ALREADY MEET, supplied as evidence rather
    # than fetched: this file is inside the transducer subtree and consumes
    # what it is given. Whether the vectors are green is something the gate
    # knows and a body does not.
    var green := {"conformance": {"vectors": 310, "worst_abs_m": 0.0,
            "tolerance_m": 1.0e-15, "parent_nodes_exact": true}}
    var w2 := DebugPlayer.walk_available(b, 1000.0, 4000.0, green)
    check(int(w2["met"]) == 1 and int(w2["not_gradeable"]) == 2,
            "with the conformance result supplied, %d met and %d not gradeable"
                    % [int(w2["met"]), int(w2["not_gradeable"])])
    check(not bool(w2["ok"]),
            "one condition met out of three opened walk mode. A NOT_GRADEABLE is not a pass; "
            + "that is the entire reason for the third outcome.")

    # AND A FAILING CONFORMANCE IS `UNMET`, NOT `NOT_GRADEABLE`. The two mean
    # different things and collapsing them would hide a real defect behind a
    # word that reads like patience.
    var red := {"conformance": {"vectors": 310, "worst_abs_m": 1.0e-9,
            "tolerance_m": 1.0e-15, "parent_nodes_exact": false}}
    var w3 := DebugPlayer.walk_available(b, 1000.0, 4000.0, red)
    check(int(w3["unmet"]) == 1, "a failing conformance result did not read UNMET")

    # ALL THREE MET IS THE ONLY THING THAT OPENS IT -- checked, so that "walk
    # mode stays shut" is a fact about the conditions and not about a gate that
    # cannot open at all. A guard that cannot fire is the defect this repo
    # keeps finding.
    var all_met := green.duplicate(true)
    all_met["bands"] = {"ok": true, "why": "synthetic", "strata": ["a", "b"]}
    all_met["spread"] = {"ok": true, "why": "synthetic"}
    check(bool(DebugPlayer.walk_available(b, 1000.0, 4000.0, all_met)["ok"]),
            "three MET conditions still did not open walk mode, so the gate cannot open and "
            + "its shutness says nothing")

    # THE RETIRED INSTRUMENT IS STILL HERE AND IS NO LONGER A GATE.
    var f := DebugPlayer.ground_findings(b, 1000.0, 4000.0)
    check(f.has("native_spacing_probe"), "the probe is gone rather than demoted")
    check(not f.has("changes_underfoot"),
            "`changes_underfoot` is still a finding under its old name, so the demotion is a "
            + "comment rather than a change")
    var probe: Dictionary = f["native_spacing_probe"]
    check(not probe.has("ok"),
            "the probe still answers yes or no, which is how it will be read as a gate again")
    check(float(probe["lower_lag_bound_m"]) == 1000.0,
            "the probe does not report the lower lag bound it exists to supply")
    for line in DebugPlayer.walk_lines(w2):
        print("  " + line)
    print("986: walk mode SHUT -- %d met, %d unmet, %d not gradeable; the retired instrument "
            % [int(w2["met"]), int(w2["unmet"]), int(w2["not_gradeable"])]
            + "is a native-spacing probe reporting a %s m lower lag bound"
                    % String.num(float(probe["lower_lag_bound_m"]), 0))


## How many strata a measurement covers at any lag at all.
static func _strata_covered(m: Dictionary, lags: Array) -> int:
    var n := 0
    for name in (m.get("strata", {}) as Dictionary):
        for lag in lags:
            if (m["strata"][name] as Dictionary).get(float(lag), null) != null:
                n += 1
                break
    return n


func test_the_strata_are_the_membership_functions_on_real_ground() -> void:
    """DECISION 1019'S GRADING FORM, BUILT SO THE VALUES ARE THE ONLY THING
    STILL MISSING.

    The second difference carries both of convention 6's clauses; the strata are
    the membership functions themselves evaluated on real HAND and slope, never
    a table; the support is the window; and a stratum without coverage gets a
    REFUSED band rather than a tolerance of zero.

    Every check here is two-sided per convention 6 as amended -- the effect
    where the mechanism claims one, beside a control showing its absence when
    the mechanism is off. A grader asserted only by the numbers it returns is
    asserting that it ran."""
    var df := detail_field()
    var hf := heightfield()
    if not df.is_loaded():
        return
    var layers := TerrainLayers.load_from()
    if not layers.is_fetched():
        print("986/1019: the terrain layers are not fetched, so membership cannot be "
                + "evaluated on real ground and this test is not running. "
                + "`python3 tools/fetch_artefacts.py`")
        return
    df.bind_layers(layers)
    check(not df.classifier_source().begins_with("the parent lattice"),
            "the classifier is still re-deriving slope from the lattice with the layers bound")

    # WINDOWS ACROSS THE BASIN, WHICH IS WHAT CROSS-WINDOW MEANS.
    #
    # Measured first over ONE 3 km window and four of the five strata fell
    # below the sampling floor at every lag: a window of a few kilometres is
    # almost always one landform. That is the support rule working -- a stratum
    # is refused where it is not, rather than handed the window's own median
    # under its name -- and it is exactly why 1019 bands cross-window and asks
    # that window sourcing cover the joint HAND-by-slope membership space.
    var centres: Array = []
    for pair in [[500.0, 700.0], [260.0, 300.0], [700.0, 1100.0],
            [420.0, 980.0], [640.0, 520.0], [340.0, 760.0]]:
        var t: Array = pair
        var c := hf.texel_to_world(float(t[0]), float(t[1]))
        if is_finite(hf.height_at_world(c.x, c.y)):
            centres.append(c)
    check(centres.size() >= 4, "only %d of the sampled window centres are on ground"
            % centres.size())
    var centre: Vector2 = centres[0]
    var lags := [4.0, 8.0, 16.0]
    var m := StratumGrade.over_windows(df, hf, centres, 3000.0, lags, 0.5, 300, 21)
    check(bool(m["ok"]), "the grader refused a window with the layers bound: %s" % str(m["why"]))
    if not bool(m["ok"]):
        return

    # THE ONE-WINDOW CONTROL, which is what makes the sentence above a
    # measurement rather than an anecdote: the same grader over a single window
    # must cover fewer strata than over six.
    var one := StratumGrade.over_window(df, hf, centre, 3000.0, lags, 0.5, 300, 21)
    var covered_one := _strata_covered(one, lags)
    var covered_many := _strata_covered(m, lags)
    check(covered_many > covered_one,
            "six windows cover %d strata and one covers %d. If they are equal the support "
                    % [covered_many, covered_one]
            + "rule is not biting and the cross-window clause is decorative here.")
    print("986/1019: one window covers %d strata, %d windows cover %d"
            % [covered_one, centres.size(), covered_many])

    # THE STRATA ARE WHATEVER THE ROWS DECLARE. `upland_flat` is neither ruled
    # unwalkable nor merged, and under membership strata the elevation classes
    # stopped being calibration units at all -- so a grader that had memorised
    # a set would be wrong in both directions.
    var strata: Dictionary = m["strata"]
    check(strata.size() == df.landforms().size(),
            "the grader reports %d strata and the rows declare %d"
                    % [strata.size(), df.landforms().size()])

    # REFUSED WHERE THE STRATUM IS NOT IN THE WINDOW, AND NOT ZERO. The two are
    # opposite readings: a refusal says nobody measured this, a zero says
    # everything fails. At least one of the two must occur here or the check is
    # not exercised at all -- which is itself reported rather than passed over.
    var refused := 0
    var measured := 0
    for name in strata:
        var entry: Dictionary = strata[name]
        var n_eff := float(entry.get("n_effective", 0.0))
        for lag in lags:
            if entry[float(lag)] == null:
                refused += 1
                check(n_eff < StratumGrade.MIN_EFFECTIVE_SAMPLES,
                        "%s was refused at %s m with %s effective samples, which is above "
                                % [str(name), str(lag), String.num(n_eff, 1)]
                        + "the floor -- so the refusal is not the coverage rule firing")
            else:
                measured += 1
                check(float(entry[float(lag)]) > 0.0,
                        "%s measured exactly zero at %s m, which a second difference on real "
                                % [str(name), str(lag)] + "ground does not do")
    check(measured > 0, "no stratum was measured at any lag in this window")
    print("986/1019: %d stratum-lags measured and %d refused for coverage over %d strata"
            % [measured, refused, strata.size()])

    # THE MEMBERSHIP WEIGHTING ACTS, and the control is the same window graded
    # with the weights flattened. If the two agree, the stratification is
    # decorative and every stratum is being handed the window's own median.
    var flat_w := PackedFloat64Array()
    var vals := PackedFloat64Array()
    for i in 64:
        vals.append(float(i))
        flat_w.append(1.0)
    var skew := PackedFloat64Array()
    for i in 64:
        skew.append(1.0 if i < 8 else 0.0)
    check(StratumGrade.weighted_quantile(vals, flat_w, 0.5)
                    != StratumGrade.weighted_quantile(vals, skew, 0.5),
            "a flat weighting and a weighting concentrated on the smallest eighth give the "
            + "same quantile, so the weights are not reaching the statistic")
    check(StratumGrade.effective_n(skew) == 8.0,
            "the effective count of eight ones and fifty-six zeros is %s and not 8"
                    % String.num(StratumGrade.effective_n(skew), 2))
    check(StratumGrade.effective_n(flat_w) == 64.0,
            "the effective count of sixty-four equal weights is not 64")

    # AND THE STRATA SPREAD, which is convention 6's second clause and a
    # separate question: a synthesiser whose playa and talus agree passes every
    # per-stratum band and fails the criterion.
    var sp := StratumGrade.spread(m, lags)
    var seen_spread := false
    for lag in lags:
        var e = sp[float(lag)]
        if e == null:
            continue
        seen_spread = true
        check(str((e as Dictionary)["loudest"]) != str((e as Dictionary)["quietest"]),
                "the spread at %s m names one stratum as both ends" % str(lag))
        print("986/1019: at %s m the strata spread %sx, %s over %s"
                % [str(lag), String.num(float((e as Dictionary)["ratio"]), 2),
                        str((e as Dictionary)["loudest"]), str((e as Dictionary)["quietest"])])
    check(seen_spread, "no lag produced a spread between two distinct strata")

    # THE PARENT'S OWN SHARE, MEASURED RATHER THAN ASSUMED. The bands come from
    # real ground, which carries its terrain, so the grade is taken on the drawn
    # ground and not on the detail term alone. If the parent ever carried most
    # of the second difference the grade would be reading the lattice -- which
    # is the premise §23.999 used to refuse fork (c) -- so it is reported.
    var share := StratumGrade.parent_share(df, hf, centre, 3000.0, lags, 200, 23)
    for lag in lags:
        var v = share[float(lag)]
        if v == null:
            continue
        print("986/1019: at %s m the parent lattice carries %s%% of the second difference"
                % [str(lag), String.num(float(v) * 100.0, 1)])

    # WITHOUT THE LAYERS IT REFUSES BY NAME. The control for every number
    # above: strip the real inputs and the grader must stop rather than
    # stratify on a re-derived lattice gradient wearing the same stratum names.
    var bare := DetailField.load_from(hf, DetailField.ROWS_PATH)
    var m2 := StratumGrade.over_window(bare, hf, centre, 3000.0, lags, 0.5, 64, 21)
    check(not bool(m2["ok"]) and str(m2["why"]) == StratumGrade.NO_LAYERS,
            "a field with no layers graded anyway, reporting %s. 1019 rules the strata are "
                    % str(m2["why"])
            + "the membership functions on REAL HAND and slope; a lattice re-derivation is "
            + "a different stratification with the same names on it.")

    # AND THE GATE STILL READS NOT_GRADEABLE, because nothing is published to
    # measure against. Measuring is not grading.
    var ev := StratumGrade.evidence(m, sp, {})
    check(ev.is_empty(),
            "the grader offered evidence with no bands published. A measurement with nothing "
            + "to measure against is a number and not a verdict.")
    var fl := fixture()
    var b := FixturePassthrough.over(fl).bundle_for(fl.windows[0], 0, _dev_observer())
    var w := DebugPlayer.walk_available(b, 1000.0, 4000.0, ev)
    check(int(w["not_gradeable"]) == 3 and not bool(w["ok"]),
            "measuring without bands moved the gate: %d not gradeable" % int(w["not_gradeable"]))

    # AND THE REFUSAL SAYS WHICH THING IS MISSING. Two different absences reach
    # the gate as the same NOT_GRADEABLE, and only one of them is actionable
    # here: bands nobody has published are the producing side's, while a
    # stratum this window set does not cover is window sourcing and is mine.
    var why_not := StratumGrade.gradeable(m, {})
    check(not bool(why_not["ok"]), "the grader says it can grade with no bands published")
    check(str(why_not["why"]).begins_with(StratumGrade.NO_COVERAGE)
                    or str(why_not["why"]).begins_with(StratumGrade.NO_BANDS),
            "the refusal does not name what is missing: %s" % str(why_not["why"]))
    print("986/1019: not gradeable because %s" % str(why_not["why"]))

    # THE CONTROL FOR THE GRADING ITSELF, on a measurement where every stratum
    # IS covered. The real windows above do not cover two of the five, which is
    # the finding rather than a shortfall in this test -- but a band check that
    # has never returned a verdict cannot be said to refuse for the right
    # reason, so it is shown returning all three.
    var synth := {"ok": true, "why": "", "strata": {}}
    var i := 0
    for name in strata:
        i += 1
        synth["strata"][str(name)] = {4.0: 0.01 * float(i), 8.0: 0.02 * float(i),
                16.0: 0.04 * float(i), "n_effective": 1000.0}
    var synth_sp := StratumGrade.spread(synth, lags)
    var bands := {"_min_spread": 1.0}
    for name in strata:
        var per := {}
        for lag in lags:
            var sv := float((synth["strata"][str(name)] as Dictionary)[float(lag)])
            per[float(lag)] = [sv * 0.5, sv * 2.0]
        bands[str(name)] = per
    check(bool(StratumGrade.gradeable(synth, bands)["ok"]),
            "a fully covered and fully banded measurement is still not gradeable: %s"
                    % str(StratumGrade.gradeable(synth, bands)["why"]))
    var ev2 := StratumGrade.evidence(synth, synth_sp, bands)
    check(not ev2.is_empty() and bool((ev2["bands"] as Dictionary)["ok"]),
            "bands containing the measurement did not read as met: %s"
                    % str((ev2.get("bands", {}) as Dictionary).get("why", "")))
    var w2 := DebugPlayer.walk_available(b, 1000.0, 4000.0, ev2)
    check(int(w2["not_gradeable"]) == 1 and int(w2["met"]) == 2,
            "with bands supplied, %d met and %d not gradeable -- the conformance result was "
                    % [int(w2["met"]), int(w2["not_gradeable"])] + "not passed in, so one "
            + "should be ungraded and two should be met")
    # And bands that exclude it read UNMET rather than NOT_GRADEABLE.
    var tight := {"_min_spread": 1.0}
    for name in strata:
        var per2 := {}
        for lag in lags:
            var sv2 := float((synth["strata"][str(name)] as Dictionary)[float(lag)])
            per2[float(lag)] = [sv2 * 10.0, sv2 * 20.0]
        tight[str(name)] = per2
    var w3 := DebugPlayer.walk_available(b, 1000.0, 4000.0,
            StratumGrade.evidence(synth, synth_sp, tight))
    check(int(w3["unmet"]) >= 1,
            "bands the measurement sits outside did not read UNMET, so the band check cannot "
            + "fail and its pass above means nothing")
    # And a spread requirement nothing meets reads UNMET too, separately.
    var nospread := bands.duplicate(true)
    nospread["_min_spread"] = 1000.0
    var w4 := DebugPlayer.walk_available(b, 1000.0, 4000.0,
            StratumGrade.evidence(synth, synth_sp, nospread))
    check(int(w4["unmet"]) >= 1,
            "a spread requirement of a thousandfold was met, so the second clause cannot "
            + "fail independently of the first")
    print("986/1019: bands absent -> 3 not gradeable; bands containing the measurement -> "
            + "met; bands excluding it -> unmet. The grading form is built and the values "
            + "are the only thing missing.")
