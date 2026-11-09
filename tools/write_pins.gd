extends SceneTree

## WRITE ONE `pins.json` FOR MAGISTERIA'S EMISSION TOOL TO PLACE.
##
## G-8's authoring surface at the command line. It takes the two digests the
## AUTHOR supplies and a pin file to read rows from, builds the document through
## `PinFile`, and writes it. It validates FORM only.
##
##   godot --headless --script res://tools/write_pins.gd -- \
##       --base-dressing sha256:<64 hex> --schedule-plan-digest sha256:<64 hex> \
##       --rows <path to a json array of pin rows> --out <path>
##
## WHAT IT CANNOT TELL YOU, AND IT SAYS SO ON EVERY SUCCESSFUL WRITE. Whether
## the base dressing exists, whether a pin is inside the footprint, whether a
## pin is inside its bound, whether the schedule stamp will be accepted: all
## four are magisteria's committed data, and a reader of it here would be a
## second copy of a bound. **The emission tool's `--check` is where an author
## learns those**, and that runs on the shared machine through the manager.
##
## A `sink` PIN'S `from` IS NOT READ BY THE ENGINE YET (§25 backlog 722,
## design's). The kind is implemented because §22.8.4 lists it, and the tool
## does emit its row -- but the writer's sink acts from the build, not from
## `from`, so a sink pin's date is authored and not yet honoured. Printed on any
## write that carries one, because a capability that reads as usable and is not
## is worse than one that is missing.

func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var opt := {}
    var i := 0
    while i < args.size() - 1:
        if str(args[i]).begins_with("--"):
            opt[str(args[i]).substr(2)] = str(args[i + 1])
            i += 2
        else:
            i += 1
    # THE OLD FLAG REFUSES AND NAMES THE NEW ONE. Checked BEFORE the required
    # list, so an author who passes the old spelling is told what to pass
    # instead rather than told that the new flag is missing -- which is true
    # but says nothing about the rename. The stamp's meaning changed with its
    # name (decision 2128 (ii)), so an alias would be wrong even where the
    # value happened to be right.
    if opt.has("schedule-digest"):
        printerr("write_pins: use --schedule-plan-digest: the stamp is the schedule's "
                + "plan_digest (decision 2128)")
        quit(2)
        return
    for need in ["base-dressing", "schedule-plan-digest", "rows", "out"]:
        if not opt.has(need):
            printerr("write_pins: --%s is required; nothing is defaulted" % need)
            quit(2)
            return

    var f := FileAccess.open(str(opt["rows"]), FileAccess.READ)
    if f == null:
        printerr("write_pins: no rows file at %s" % str(opt["rows"]))
        quit(2)
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_ARRAY:
        printerr("write_pins: %s is not a JSON array of pin rows" % str(opt["rows"]))
        quit(2)
        return

    var pf := PinFile.over(str(opt["base-dressing"]), str(opt["schedule-plan-digest"]))
    if pf.why_refused != "":
        printerr("write_pins: %s" % pf.why_refused)
        quit(1)
        return
    var sinks := 0
    for row in (parsed as Array):
        if typeof(row) != TYPE_DICTIONARY:
            printerr("write_pins: a row is not an object: %s" % JSON.stringify(row))
            quit(1)
            return
        if not pf.add_pin(row as Dictionary):
            printerr("write_pins: %s" % pf.why_refused)
            quit(1)
            return
        if str((row as Dictionary).get("kind", "")) == "sink":
            sinks += 1

    var w := FileAccess.open(str(opt["out"]), FileAccess.WRITE)
    if w == null:
        printerr("write_pins: cannot write %s" % str(opt["out"]))
        quit(1)
        return
    w.store_string(pf.to_json())
    w.close()
    print("write_pins: %d pin(s) -> %s" % [pf.pins.size(), str(opt["out"])])
    print("write_pins: FORM ONLY. The base dressing, the footprint, the bounds and the "
            + "schedule stamp are refusals only magisteria's emission tool can make.")
    if sinks > 0:
        print("write_pins: %d sink pin(s). THE ENGINE HAS NO DATE SEAT FOR A SINK'S "
                % sinks + "`from` (§25 backlog 722): the writer's sink acts from the build.")
    quit(0)
