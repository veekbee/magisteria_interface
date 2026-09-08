class_name DevConsole
extends Control

## The `~` console. Three prefixes, partitioned from birth.
##
## THE PARTITION IS THE POINT AND THE COMMANDS ARE NOT. What a console does is
## easy to add later; which of its verbs may exist in which build is not, and a
## flat namespace makes that question unanswerable without reading every verb.
##
##   view.*   -- camera, overlays, capture, what mode the viewer is in. Purely
##               A-side. Legitimate in every build, forever.
##   probe.*  -- reads the loaded artefact. ABSENT BY CONSTRUCTION against a
##               live producer: the truth never arrives, so there is nothing to
##               read and the verbs are not registered at all. That absence is
##               the enforcement; the verbs are only its shape.
##   world.*  -- dev rebuild and reload against the fixture. Never a transducer
##               function. Registered only in a dev build; in production they
##               do not exist client-side.
##
## SO REGISTRATION REFUSES, RATHER THAN EXECUTION CHECKING. A verb that exists
## and declines is a verb someone will find a way to call; a verb that was
## never registered cannot be reached, and the console says which prefix is
## absent here and why rather than pretending the name was a typo.
##
## `run` IS A FUNCTION FROM A LINE TO LINES, with no window in it, so the gate
## drives the console headlessly and a console-launched measurement is the same
## measurement the shell tool emits.

const PREFIXES := ["view.", "probe.", "world."]

## Producer kinds whose client holds the artefact whole. `probe.*` exists for
## exactly these; against anything else it is not registered.
const PROBE_ADMITS := ["fixture_passthrough", "mock"]

signal ran(line: String, output: PackedStringArray)

var producer_kind: String = "fixture_passthrough"
var dev_build: bool = true
var history: Array = []

var _verbs: Dictionary = {}          ## name -> {"help": String, "call": Callable}
var _absent: Dictionary = {}         ## prefix -> why it is not here
var _input: LineEdit = null
var _out: RichTextLabel = null


## Whether a prefix exists in this build at all, with the sentence that says
## why when it does not.
static func admits(prefix: String, producer: String, dev: bool) -> Dictionary:
    match prefix:
        "view.":
            return {"ok": true, "why": ""}
        "probe.":
            if PROBE_ADMITS.has(producer):
                return {"ok": true, "why": ""}
            return {"ok": false, "why": ("probe.* reads the loaded artefact, and against a %s "
                    % producer + "producer there is no artefact to read: the truth never "
                    + "arrives. These verbs are absent by construction, not disabled.")}
        "world.":
            if dev:
                return {"ok": true, "why": ""}
            return {"ok": false, "why": ("world.* rebuilds and reloads the fixture, which is a "
                    + "development verb and never a transducer function. It does not exist "
                    + "client-side in a production build.")}
    return {"ok": false, "why": "%s is not one of this console's three prefixes" % prefix}


func _init() -> void:
    # Registered here rather than in `setup` so a console driven headlessly --
    # which is how the gate drives it -- can still ask what it has.
    register("view.help", "what this build's console has", help)


## Register a verb. Refuses an unprefixed name, and silently declines one whose
## prefix this build does not admit -- which is how `probe.*` comes to be
## missing rather than disabled.
func register(name: String, help: String, call: Callable) -> bool:
    var prefix := ""
    for p in PREFIXES:
        if name.begins_with(p):
            prefix = p
    if prefix == "":
        push_error("console: %s belongs to no prefix. Every verb is view.*, probe.* or world.*, "
                % name + "because a flat namespace cannot say which build it may exist in.")
        return false
    var admit := admits(prefix, producer_kind, dev_build)
    if not bool(admit["ok"]):
        _absent[prefix] = str(admit["why"])
        return false
    _verbs[name] = {"help": help, "call": call}
    return true


func names() -> PackedStringArray:
    var out := PackedStringArray()
    for k in _verbs:
        out.append(str(k))
    out.sort()
    return out


func absent_prefixes() -> Dictionary:
    return _absent.duplicate()


## One line in, lines out. No window, no side channel: a console session is
## reproducible and a gate can drive it.
func run(line: String) -> PackedStringArray:
    var text := line.strip_edges()
    if text == "":
        return PackedStringArray()
    history.append(text)
    var parts := text.split(" ", false)
    var verb := str(parts[0])
    var args := PackedStringArray()
    for i in range(1, parts.size()):
        args.append(str(parts[i]))

    if verb == "help":
        verb = "view.help"
    var out := PackedStringArray()
    if not _verbs.has(verb):
        out.append("no verb `%s`" % verb)
        for p in PREFIXES:
            if verb.begins_with(p) and _absent.has(p):
                out.append(str(_absent[p]))
        if out.size() == 1:
            var near := _nearest(verb)
            if near != "":
                out.append("did you mean `%s`?" % near)
        ran.emit(text, out)
        return out
    var call: Callable = (_verbs[verb] as Dictionary)["call"]
    var answer = call.call(args)
    if answer is PackedStringArray:
        out = answer
    elif answer is Array:
        for a in answer:
            out.append(str(a))
    else:
        out.append(str(answer))
    ran.emit(text, out)
    return out


func _nearest(verb: String) -> String:
    var best := ""
    var best_score := 0
    for k in _verbs:
        var score := 0
        var s := str(k)
        for i in mini(s.length(), verb.length()):
            if s[i] == verb[i]:
                score += 1
            else:
                break
        if score > best_score:
            best_score = score
            best = s
    return best if best_score >= 4 else ""


## `view.help`, which is a verb like any other so that it cannot list something
## the console does not have.
func help(_args: PackedStringArray) -> PackedStringArray:
    var out := PackedStringArray()
    for n in names():
        out.append("%-18s %s" % [n, str((_verbs[n] as Dictionary)["help"])])
    for p in PREFIXES:
        if _absent.has(p):
            out.append("%-18s ABSENT: %s" % [p + "*", str(_absent[p])])
    return out


# -- the window half ---------------------------------------------------------

func setup() -> void:
    set_anchors_preset(Control.PRESET_TOP_WIDE)
    custom_minimum_size = Vector2(0, 260)
    visible = false
    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.03, 0.05, 0.88)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_FULL_RECT)
    box.add_theme_constant_override("separation", 2)
    add_child(box)
    _out = RichTextLabel.new()
    _out.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _out.scroll_following = true
    box.add_child(_out)
    _input = LineEdit.new()
    _input.placeholder_text = "view.* / probe.* / world.*   --  `help` lists what this build has"
    _input.text_submitted.connect(_on_submit)
    # The toggle key reaches the LineEdit as GUI input when the field has
    # focus, so it never becomes "unhandled" and the console could be opened
    # and not closed the same way. Caught here as well.
    _input.gui_input.connect(_on_input_key)
    box.add_child(_input)
    # Asked for explicitly rather than relied on: this node spends most of its
    # life hidden, and a toggle that only works while the panel is open is not
    # a toggle.
    set_process_unhandled_key_input(true)


func _on_input_key(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k != null and k.pressed and not k.echo and k.keycode == KEY_QUOTELEFT:
        visible = false
        accept_event()


func _on_submit(text: String) -> void:
    _input.text = ""
    _out.append_text("[b]> %s[/b]\n" % text)
    for line in run(text):
        _out.append_text(line + "\n")


## Toggle on the key left of `1`. Handled here rather than in the viewer so the
## console owns its own visibility and a build without one has no key bound.
func _unhandled_key_input(event: InputEvent) -> void:
    var k := event as InputEventKey
    if k == null or not k.pressed or k.echo:
        return
    if k.keycode == KEY_QUOTELEFT:
        visible = not visible
        if visible and _input != null:
            _input.grab_focus()
        get_viewport().set_input_as_handled()
