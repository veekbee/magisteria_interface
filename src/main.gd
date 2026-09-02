extends Control

## The whole application, for now: load the contract and show it.
##
## There is deliberately nothing else here. M1 (terrain) needs the sim
## repo's Phase 3 export and M2 (field overlays) needs its Phase 4 fixture;
## neither exists yet, and a stub that pretended to draw terrain would be
## the thing everyone later builds around.

@onready var _scroll: ScrollContainer = $Scroll
@onready var _inspector: InspectorPanel = $Scroll/Inspector


func _ready() -> void:
    var doc := _inspector.document
    if doc == null:
        doc = SchemaLoader.load_from_file(InspectorPanel.ARTEFACT_PATH)
        _inspector.document = doc
        _inspector.rebuild()
    for report in doc.reports:
        push_warning("contract: %s" % report)
    if doc.refused:
        push_error("contract REFUSED: %s" % doc.refusal_reason)
