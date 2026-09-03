extends Node3D

## M1 plus M2a: the terrain viewer, with the contract inspector over it.
##
## The two halves consume different artefacts and neither reaches for the
## other's -- the inspector reads only `contract/schema.json`, the terrain only
## `assets/terrain/`. Keeping them independent is what makes each milestone's
## claim checkable: if the terrain fails, the inspector still renders, and the
## report says which one did what.

@onready var _terrain: TerrainView = $TerrainView
@onready var _inspector: InspectorPanel = $UI/Scroll/Inspector
@onready var _controls: VBoxContainer = $UI/Controls

var terrain_report: Dictionary = {}
var field_report: Dictionary = {}
var scrubber: FieldScrubber = null


func _ready() -> void:
    terrain_report = _terrain.build()
    if terrain_report.get("ok", false):
        print("terrain: %d verts, %d quads, %d reaches over %d orders"
                % [terrain_report["vertices"], terrain_report["quads"],
                   terrain_report["reaches_drawn"], terrain_report["flowline_orders"]])
        if terrain_report.get("reaches_offmap", 0) > 0:
            push_warning("terrain: %d reaches fall outside the valid heightfield"
                    % terrain_report["reaches_offmap"])
    else:
        push_error("terrain: %s" % terrain_report.get("why", "unknown"))

    # M2 rides on M1 and is reported separately: a fixture failure must not
    # read as a terrain failure, and the viewer stays usable without one.
    field_report = _terrain.bind_fields()
    if field_report.get("ok", false):
        scrubber = FieldScrubber.new()
        scrubber.setup(_terrain.fixture)
        scrubber.changed.connect(_on_field_changed)
        _controls.add_child(scrubber)

        # M4. The legend is built before the first paint because the paint
        # writes to it: the share of the boundary that is real is part of what
        # the layer draws, not a note about it.
        contour_report = _terrain.bind_contours()
        legend = ContourLegend.new()
        legend.setup()
        _controls.add_child(legend)
        for d in contour_report.get("sets", []):
            print("contours: %s %s @ %s %s, %d days"
                    % [d["window"], d["row"], String.num(d["threshold"], 4), d["unit"],
                       d["days"]])
        if not contour_report.get("ok", false):
            push_warning("contours: %s" % contour_report.get("why", "unknown"))

        family_report = _terrain.bind_families()
        if family_report.get("ok", false):
            print("families: %s for wire groups %s%s"
                    % [str(family_report["families"]), str(family_report["wire_groups"]),
                       "" if family_report["missing"].is_empty()
                            else ", MISSING " + str(family_report["missing"])])
            for m in family_report["missing"]:
                push_warning("families: the wire names life form %s and no family answers it" % m)
        else:
            push_warning("families: %s" % family_report.get("why", "unknown"))

        probe_panel = ProbePanel.new()
        probe_panel.setup(_terrain.fixture)
        _controls.add_child(probe_panel)
        _terrain.probed.connect(_on_probed)

        var c := scrubber.current()
        if not c.is_empty():
            _on_field_changed(c["window"], c["row"], c["day"], c["group"])
        var burn := _terrain.burn_edge(str(field_report["windows"][0]), 0)
        if not burn.get("has_edge", false):
            # Decision 892 draws a burn perimeter as a real edge. This trace has
            # none, and saying so is the honest output -- contouring anyway
            # would draw a curve wherever the threshold cut the noise.
            push_warning("burn: %s" % burn.get("verdict", "no verdict"))
        print("fields: %d px resolved, %d rows, windows %s"
                % [field_report["resolved_px"], field_report["rows"].size(),
                   str(field_report["windows"])])
        for w in field_report["refused"]:
            for r in field_report["refused"][w]:
                push_warning("fixture %s: %s not carried" % [w, r])
    else:
        push_warning("fields: %s" % field_report.get("why", "unknown"))

    var doc := _inspector.document
    if doc == null:
        doc = SchemaLoader.load_from_file(InspectorPanel.ARTEFACT_PATH)
        _inspector.document = doc
        _inspector.rebuild()
    for r in doc.reports:
        push_warning("contract: %s" % r)
    if doc.refused:
        push_error("contract REFUSED: %s" % doc.refusal_reason)


var flow_report: Dictionary = {}
var burn_report: Dictionary = {}
var contour_report: Dictionary = {}
var contour_day_report: Dictionary = {}
var legend: ContourLegend = null
var probe_panel: ProbePanel = null
var probe_report: Dictionary = {}
var family_report: Dictionary = {}
var scatter_report: Dictionary = {}


func _on_field_changed(window: String, row: String, day: int, group: int) -> void:
    if not _terrain.show_field(window, row, day, group):
        push_warning("fields: could not paint %s/%s day %d" % [window, row, day])
    # M3: the day is one value. Flow and the field are painted from it together
    # so the rivers and the ground can never show different days.
    flow_report = _terrain.show_flow(window, day)
    if not flow_report.get("ok", false):
        push_warning("flow: %s" % flow_report.get("why", "unknown"))
    burn_report = _terrain.burn_edge(window, day)
    # M4: the same day again. The contour layer never asks the clock itself.
    contour_day_report = _terrain.show_contours(window, day)
    if legend != null:
        var cs: ContourSet = _terrain.contour_sets.get(window, null)
        if cs == null:
            legend.show_absent(window)
        else:
            legend.show_set(cs, day, contour_day_report)


## M4. The probe is assembled by the view that holds the cameras and the
## painted row; main only routes the answer to the panel.
func _on_probed(result: Dictionary) -> void:
    probe_report = result
    if probe_panel != null:
        probe_panel.show_probe(result)
    # M5 rides on the probe: the scatter needs a place to stand, and the point
    # the viewer just asked about is the one they are looking at.
    if str(result.get("state", "")) == CellProbe.RESOLVED and result.has("world"):
        scatter_report = _terrain.scatter_at(result["world"])
        if probe_panel != null:
            probe_panel.show_scatter(scatter_report)
