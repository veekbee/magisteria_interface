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

var terrain_report: Dictionary = {}


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

    var doc := _inspector.document
    if doc == null:
        doc = SchemaLoader.load_from_file(InspectorPanel.ARTEFACT_PATH)
        _inspector.document = doc
        _inspector.rebuild()
    for r in doc.reports:
        push_warning("contract: %s" % r)
    if doc.refused:
        push_error("contract REFUSED: %s" % doc.refusal_reason)
