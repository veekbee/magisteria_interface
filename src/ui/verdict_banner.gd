class_name VerdictBanner
extends PanelContainer

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
## THE ABSENT CASE IS THE LOUD ONE. A banner that renders as an empty strip
## when it has nothing to say would be indistinguishable from a fixture that
## passed everything.
##
## IT DRAWS ITS OWN PLATE, and that is not decoration. Photographed over
## `band.bare_fraction` in a window narrow enough to put the basin under the
## controls, the amber headline was ALL BUT INVISIBLE: amber (0.95, 0.78, 0.30)
## against the bright end of viridis (0.993, 0.906, 0.144) is a contrast ratio
## of 1.28:1, and the disclaimer disappeared into exactly the picture it
## exists to disclaim. Twenty-six headless asserts on this text saw none of it,
## because they read the string and the string was perfect. A plate makes the
## contrast a property of the banner rather than of whatever the camera is
## pointed at.

## Dark enough that every state's colour clears 4.5:1 against it, and opaque
## enough that the brightest ramp value underneath cannot lift it.
const PLATE := Color(0.07, 0.07, 0.09, 0.92)

var _headline: Label
var _fails: Label
var _box: VBoxContainer


func setup() -> void:
    custom_minimum_size = Vector2(420, 0)
    var plate := StyleBoxFlat.new()
    plate.bg_color = PLATE
    plate.content_margin_left = 6
    plate.content_margin_right = 6
    plate.content_margin_top = 4
    plate.content_margin_bottom = 4
    add_theme_stylebox_override("panel", plate)
    _box = VBoxContainer.new()
    add_child(_box)
    _headline = _line(16)
    _fails = _line()


func show_verdict(v: AncestorVerdict) -> void:
    _headline.text = v.headline()
    _headline.add_theme_color_override("font_color", colour_for(v.state))
    var lines := v.named_fails()
    var excluded := v.excluded_fields()
    if not excluded.is_empty():
        lines.append("equivalence excluded " + "; ".join(excluded))
    _fails.text = "" if lines.is_empty() else "fails: " + ", ".join(lines)
    _fails.visible = not lines.is_empty()


## The headline colour per state, exposed so the contrast against `PLATE` can
## be asserted rather than eyeballed.
##
## A proven-equivalent verdict is a VALID verdict of this basin, so it gets the
## colour of one. What separates it from SCORED is the sentence, which names
## the other run and the size of the proof -- a second amber would say "unlike
## the one beside it" and stop there.
static func colour_for(state: String) -> Color:
    match state:
        AncestorVerdict.SCORED, AncestorVerdict.EQUIVALENT:
            return Color(0.95, 0.78, 0.30)
        AncestorVerdict.STALE:
            return Color(0.97, 0.45, 0.35)
        _:
            return Color(0.70, 0.70, 0.74)


## WCAG relative luminance, for the contrast assert. The plate is composited
## over the worst case the ramp can put behind it before this is measured,
## because the plate is translucent and a contrast taken against the plate
## alone would be a contrast against a colour nobody sees.
static func luminance(c: Color) -> float:
    var ch := [c.r, c.g, c.b]
    var lin := []
    for v in ch:
        lin.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
    return 0.2126 * float(lin[0]) + 0.7152 * float(lin[1]) + 0.0722 * float(lin[2])


## Contrast ratio between two opaque colours, 1.0 (none) to 21.0 (black/white).
static func contrast(a: Color, b: Color) -> float:
    var la := luminance(a)
    var lb := luminance(b)
    return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## The plate as it is actually seen: PLATE alpha-composited over whatever is
## behind it.
static func plate_over(behind: Color) -> Color:
    var a := PLATE.a
    return Color(PLATE.r * a + behind.r * (1.0 - a),
                 PLATE.g * a + behind.g * (1.0 - a),
                 PLATE.b * a + behind.b * (1.0 - a))


func _line(size: int = 13) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _box.add_child(l)
    return l
