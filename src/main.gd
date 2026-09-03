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
        var c := scrubber.current()
        if not c.is_empty():
            _on_field_changed(c["window"], c["row"], c["day"], c["group"])
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


func _on_field_changed(window: String, row: String, day: int, group: int) -> void:
    if not _terrain.show_field(window, row, day, group):
        push_warning("fields: could not paint %s/%s day %d" % [window, row, day])
