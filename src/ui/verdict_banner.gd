class_name VerdictBanner
extends VBoxContainer

## The fixture's acceptance verdict, on screen, so a screenshot disclaims
## itself. Roadmap's post-M0 note.
##
## IT IS NOT PART OF THE INSPECTOR, deliberately. `InspectorPanel` is generated
## from `contract/schema.json` and reads no fixture, no terrain and no data of
## any kind -- that independence is what makes it a living consumer of the
## contract, and what lets an envelope defect surface without a fixture to hand.
## A verdict is a property of a RUN, not of the contract, so putting it there
## would make the one panel in this project that depends on nothing depend on
## the largest artefact in the repo.
##
## THE ABSENT CASE IS THE LOUD ONE, and today it is the only case. Nothing on
## the wire carries a verdict yet, and a banner that renders as an empty strip
## when it has nothing to say would be indistinguishable from a fixture that
## passed everything.

var _headline: Label
var _fails: Label


func setup() -> void:
    custom_minimum_size = Vector2(420, 0)
    _headline = _line(16)
    _fails = _line()


func show_verdict(v: AncestorVerdict) -> void:
    _headline.text = v.headline()
    match v.state:
        AncestorVerdict.SCORED:
            _headline.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
        AncestorVerdict.STALE:
            _headline.add_theme_color_override("font_color", Color(0.97, 0.45, 0.35))
        _:
            _headline.add_theme_color_override("font_color", Color(0.70, 0.70, 0.74))
    var lines := v.named_fails()
    _fails.text = "" if lines.is_empty() else "fails: " + ", ".join(lines)
    _fails.visible = not lines.is_empty()


func _line(size: int = 13) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(l)
    return l
