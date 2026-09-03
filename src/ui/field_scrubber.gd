class_name FieldScrubber
extends VBoxContainer

## M2's controls: which window, which row, which day.
##
## The row list comes from the FIXTURE, not from a hardcoded list -- a row the
## fixture refused must not be offerable, and a row added later must appear
## without an edit here. Refused rows are shown, disabled, with their reason,
## because a control that simply omitted one would make an unresolved design
## question look like a design.
##
## At contract v1.0 the one refused row was `node.aft.population` (15 palette
## members against a 14-wide engine axis). v2.0 removed it from the carried set
## entirely -- its only writer is unimplemented -- so nothing is refused today.
## Deriving the list from the fixture is what made that a no-op here.

signal changed(window: String, row: String, day: int, group: int)

## M3: daily playback. The scrubber owns the clock because the day is one
## value shared by the field overlay and the flow lines -- two clocks would
## drift and show a field and a river from different days, which is the kind
## of wrongness a viewer reads as physics.
const FRAMES_PER_DAY := 3

var playing := false
var _tick := 0

var window_pick: OptionButton
var row_pick: OptionButton
var day_slider: HSlider
var day_label: Label
var refused_label: Label

var _fl: FixtureLoader
var _rows: PackedStringArray = PackedStringArray()


func setup(fl: FixtureLoader) -> void:
    _fl = fl
    custom_minimum_size = Vector2(420, 0)

    window_pick = OptionButton.new()
    for w in fl.windows:
        window_pick.add_item(w)
    window_pick.item_selected.connect(func(_i): _reload_rows(); _emit())
    add_child(_labelled("window", window_pick))

    row_pick = OptionButton.new()
    row_pick.item_selected.connect(func(_i): _emit())
    add_child(_labelled("field", row_pick))

    day_slider = HSlider.new()
    day_slider.min_value = 0
    day_slider.step = 1
    day_slider.custom_minimum_size = Vector2(300, 0)
    day_slider.value_changed.connect(func(_v): _update_day_label(); _emit())
    day_label = Label.new()
    add_child(_labelled("day", day_slider))
    add_child(day_label)

    var play := Button.new()
    play.text = "play / pause"
    play.pressed.connect(func():
        playing = not playing
        play.text = "pause" if playing else "play")
    add_child(play)

    refused_label = Label.new()
    refused_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    refused_label.custom_minimum_size = Vector2(400, 0)
    add_child(refused_label)

    _reload_rows()


func current() -> Dictionary:
    if row_pick == null or row_pick.selected < 0:
        return {}
    return {
        "window": window_pick.get_item_text(max(window_pick.selected, 0)),
        "row": row_pick.get_item_text(row_pick.selected),
        "day": int(day_slider.value),
        "group": 0,
    }


func _reload_rows() -> void:
    var w := window_pick.get_item_text(max(window_pick.selected, 0))
    _rows = _fl.row_names(w)
    row_pick.clear()
    for r in _rows:
        row_pick.add_item(r)
    if _rows.size() > 0:
        row_pick.select(0)
        day_slider.max_value = max(_fl.days(w, _rows[0]) - 1, 0)
    _update_day_label()

    var refused: Dictionary = _fl.refused_rows.get(w, {})
    if refused.is_empty():
        refused_label.text = ""
    else:
        var parts := PackedStringArray()
        for k in refused:
            parts.append("%s — not carried: %s" % [k, str(refused[k])])
        refused_label.text = "\n".join(parts)


func _update_day_label() -> void:
    if day_label:
        day_label.text = "day %d of %d" % [int(day_slider.value) + 1,
                                           int(day_slider.max_value) + 1]


func _emit() -> void:
    var c := current()
    if not c.is_empty():
        changed.emit(c["window"], c["row"], c["day"], c["group"])


func _labelled(text: String, control: Control) -> HBoxContainer:
    var box := HBoxContainer.new()
    var l := Label.new()
    l.text = text
    l.custom_minimum_size = Vector2(60, 0)
    box.add_child(l)
    box.add_child(control)
    return box


func _process(_delta: float) -> void:
    if not playing or day_slider == null:
        return
    _tick += 1
    if _tick % FRAMES_PER_DAY != 0:
        return
    var next := int(day_slider.value) + 1
    if next > int(day_slider.max_value):
        next = 0
    day_slider.value = next      # emits value_changed -> _emit()
