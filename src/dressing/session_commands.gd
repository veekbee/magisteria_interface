class_name SessionCommands
extends RefCounted

## WRITING A COMMAND TO A PLAY SESSION — §25 backlog 753, decision 2149 (2).
##
## This is the only half of the loop in which this client writes anything at
## all. It writes one file into a session's `commands/`, and the session (the
## humans lane's generator, on the owner's machine) consumes it, acts, and
## answers in `commands/done/`. Nothing here reads or writes anything under
## `data/`, and nothing here is a dressing.
##
## ⚠ THE FILENAME CARRIES THE ORDER, so it is not a label. The session acts on
## the waiting commands in NAME ORDER, so a name that did not sort in issue
## order would silently reorder the owner's commands -- an advance before the
## placement it was meant to follow. Hence `<seq>-<verb>.json` with `seq` a
## six-digit zero-padded integer.
##
## ⚠ AND A FIXED NAME PER VERB CANNOT BE USED, which is what the brief asked
## for. A command is consumed by being RENAMED into `commands/done/`, so the
## second `advance.json` finds `done/advance.json` already there and is refused
## as *consumed already* -- filed as `.again-1`. The brief's four fixed names
## each work exactly once per session. Measured against the real session rather
## than reasoned about: `done/` there holds 000001 through 000004, so the next
## seq is 000005.
##
## ⚠ THE SEQ IS ONE ABOVE THE LARGEST IN BOTH DIRECTORIES. `commands/` alone is
## not enough: a consumed command has left it, so an allocator reading only the
## pending side would reissue a seq that `done/` already holds and collide on
## the rename. `.again-N` and `.answer` files count by their LEADING seq, which
## is theirs.
##
## ⚠ WRITTEN tmp-THEN-RENAMED. The session globs `*.json` and reads the file
## after its own rename, so a file still being written would be read short and
## refused as not JSON. Writing `<name>.json.tmp` and renaming makes the
## appearance of the name atomic.
##
## ⚠ THE VERB IS IN THE BODY. The session reads `cmd.get("verb")` and refuses an
## unknown one; the filename's verb is for the human reading the directory. A
## body without it is refused as `unknown verb None`, which is what the brief's
## shape would have produced.
##
## NOTHING HERE THROWS. Every call returns a dictionary carrying `problem`.

const SEQ_DIGITS := 6


## The next free sequence number for `dir`'s commands. 1 when both are empty.
static func next_seq(dir: String) -> int:
    var base := dir if dir.ends_with("/") else dir + "/"
    var high := 0
    for sub in ["commands/", "commands/done/"]:
        for fn in DirAccess.get_files_at(base + sub):
            var seq := SessionCommands.seq_of(str(fn))
            if seq > high:
                high = seq
    return high + 1


## The leading sequence number of a command's filename, or 0 if it has none.
##
## By the LEADING digits before the first `-`, so that `000002-place.again-1.json`
## and `000002-place.answer.json` both read as 2 -- they are that command's, and
## an allocator that read the trailing `-1` would hand out 1 again.
static func seq_of(filename: String) -> int:
    var cut := filename.find("-")
    if cut <= 0:
        return 0
    var head := filename.substr(0, cut)
    if head.length() != SEQ_DIGITS or not head.is_valid_int():
        return 0
    return int(head)


## The name a command with this seq and verb takes.
static func name_for(seq: int, verb: String) -> String:
    return "%s-%s.json" % [str(seq).pad_zeros(SEQ_DIGITS), verb]


## Write one command. Returns {ok, stem, path, seq, problem}.
##
## `payload` carries the verb's own fields; `verb` is written into the body here
## so that no caller can forget it.
static func write(dir: String, verb: String, payload: Dictionary) -> Dictionary:
    var out := {"ok": false, "stem": "", "path": "", "seq": 0, "problem": ""}
    var base := dir if dir.ends_with("/") else dir + "/"
    var cmds := base + "commands/"
    if not DirAccess.dir_exists_absolute(cmds):
        out["problem"] = "No commands/ under %s: this is not a session directory." % base
        return out
    var seq := SessionCommands.next_seq(dir)
    var fname := SessionCommands.name_for(seq, verb)
    var doc := {"verb": verb}
    for k in payload:
        doc[k] = payload[k]
    var tmp := cmds + fname + ".tmp"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        out["problem"] = ("Could not write %s (error %d). The session's directory may be "
                % [tmp, FileAccess.get_open_error()]) + "read-only."
        return out
    # ⚠ `full_precision` IS THE FOURTH ARGUMENT AND IT WAS FALSE UNTIL §25 backlog
    # 754. `PinFile.to_json`'s header records the cost, measured: without it a
    # float64 is written at about fifteen significant digits and does NOT parse
    # back to the same double, so a placed pin moves by ~1e-8 m -- which no check
    # in this client can see and which a bitwise round trip cannot survive.
    #
    # IT WAS LATENT RATHER THAN WRONG IN 753: that row's only payloads are
    # `years` and `to_year`, both integers, so nothing was ever written badly.
    # A `place` carries polygons, points and endpoints, and would have been the
    # first float through this line.
    f.store_string(JSON.stringify(doc, " ", true, true) + "\n")
    f.close()
    var err := DirAccess.rename_absolute(tmp, cmds + fname)
    if err != OK:
        DirAccess.remove_absolute(tmp)
        out["problem"] = "Could not rename %s into place (error %d)." % [tmp, err]
        return out
    out["ok"] = true
    out["stem"] = fname.get_basename()
    out["path"] = cmds + fname
    out["seq"] = seq
    return out


## The answer to the command with this stem, or {} while none has been written.
static func answer_of(dir: String, stem: String) -> Dictionary:
    var base := dir if dir.ends_with("/") else dir + "/"
    return SessionRead.read_json(base + "commands/done/" + stem + ".answer.json")


## Whether an answer is a PRICED one -- nothing was done and a confirm is owed.
##
## Read from the result rather than from the refusal: a priced answer is `ok`,
## because nothing failed. `cost_s` sits INSIDE `result`, which is where the
## session puts it (and where this client's schema said it was in prose while
## declaring it at the top level -- found at §25 backlog 753 and fixed there).
static func priced_cost(answer: Dictionary) -> float:
    if not bool(answer.get("ok", false)):
        return -1.0
    var result: Dictionary = answer.get("result", {})
    if not bool(result.get("priced", false)):
        return -1.0
    return float(result.get("cost_s", -1.0))
