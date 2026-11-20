class_name SessionRead
extends RefCounted

## A PLAY SESSION'S DIRECTORY, READ — §25 backlog 752, decision 2149 (1) and (4).
##
## The session is the humans lane's generator paused between years
## (`tools/play_dressing.py`, on the owner's machine, in the private repo). It
## writes a directory; this class reads it. **The two never share a process and
## never share code** — the only thing between them is the file shapes declared
## in `contract/session_schema.json`, which is the whole of what decision 2149
## (1) lets cross into this tree.
##
## ⚠ THE SHAPE IS DECLARED HERE; NO SESSION'S VALUES ARE. A session directory is
## git-ignored on the owner's machine. What this repository commits is the
## schema, this reader, and a synthetic session authored from the schema
## (`tests/session_fixture/recorded/`) — whose every figure is invented. **So the
## suite proves this reader against the schema and never against the generator.**
## The first real session the owner opens is the first integration. That is
## stated in the fixture's README too, and it is not a caveat to be read past:
## it is the exact boundary of what a green gate here means.
##
## ⚠ THREE FIELDS ARE DESTROYED AT LOAD, not merely left unread. `generated_by`
## is the generator's own tool path, `code_state` is a map of its `*.py` files to
## their digests — a listing of the private tree's layout — and
## `generator_commit` is a private-repo commit sha. Decision 973 makes none of
## them this public tree's to republish, so `_strip` erases all three from every
## parsed document, recursively, BEFORE any other code sees it. Not reading a
## field is a convention; deleting it is a mechanism, and the difference shows
## up in a crash dump or a log line written by someone who did not know.
##
## ⚠ UNKNOWN KEYS ARE IGNORED, NEVER RENDERED (752's construal Q6b). A reader
## that drew every key it found would draw whatever a later generator adds to
## these files — with no ruling, no vocabulary entry, and nothing the leak guard
## could catch, because the name would never appear in this client's source. So
## every field read here is named, and a field this client does not name is read
## past. The live case is not hypothetical: an at-the-cap row carries a key
## naming its schedule-side source, which §25 backlog 741 forbids explicitly and
## permanently. The panel reads those rows by `kind`, `type` and `tiles`, and
## that key is read past rather than refused — a session is not malformed for
## carrying it.
##
## NOTHING HERE THROWS. `problem` carries the refusal and is checked by the
## caller, as `DressingLoad` does: a view that is being used to judge a city
## must be able to say why it is not drawing one.

## Erased from every document at load. See the header.
const DROPPED := ["generated_by", "code_state", "generator_commit"]

var problem: String = ""
var dir: String = ""

var session_name: String = ""
var bound: String = ""
var dressing_id: String = ""
var base_dressing_id: String = ""
var master_seed: int = 0
var year: int = 0
var first_year: int = 0
var last_year: int = 0
## True when the session has never been advanced, which is a STATE and not a fault.
##
## The generator's own encoding: `Session.year` returns the schedule's start less
## one while nothing has been stepped, and `session.json`'s `year` means "years
## less than or equal to this are built" -- which for an unstepped session has to
## name no years at all. A reader that demanded `year` inside `years` refused the
## owner's own session on the first launch of the play, and that was this
## client's defect, not the generator's.
var unstepped: bool = false
var finished: bool = false
## Negative means the schema's `null` — no advance has been priced yet.
var last_step_s: float = -1.0
var pins_sha256: String = ""
var start_pins_sha256: String = ""

## THE SET OF PIN-FILE DIGESTS THIS SESSION HAS EVER HAD, as a set.
##
## Not a convenience: it is the fold binding's whole domain. See `fold_problem`.
var shas_had: Dictionary = {}


func is_present() -> bool:
    return problem == "" and session_name != ""


## Read a session directory. A refusal lands in `problem` and nothing throws.
static func open_dir(dir_path: String) -> SessionRead:
    var s := SessionRead.new()
    s.dir = dir_path if dir_path.ends_with("/") else dir_path + "/"
    var doc := SessionRead.read_json(s.dir + "session.json")
    if doc.is_empty():
        s.problem = "No session.json under %s, or it did not parse." % s.dir
        return s
    s.session_name = str(doc.get("name", ""))
    if s.session_name == "":
        s.problem = "session.json names no session, so no fold can be checked against it."
        return s
    s.bound = str(doc.get("bound", ""))
    s.dressing_id = str(doc.get("dressing_id", ""))
    s.base_dressing_id = str(doc.get("base_dressing_id", ""))
    s.master_seed = int(doc.get("master_seed", 0))
    s.year = int(doc.get("year", 0))
    s.finished = bool(doc.get("finished", false))
    s.pins_sha256 = str(doc.get("pins_sha256", ""))
    var years: Array = doc.get("years", [])
    if years.size() != 2:
        s.problem = ("session.json's `years` is not the schema's [first, last]: %d entries. "
                + "The slider's range is not this client's to invent.") % years.size()
        return s
    s.first_year = int(years[0])
    s.last_year = int(years[1])
    # ⚠ THE ARC'S FIRST YEAR LESS ONE IS LEGAL AND MEANS "NOTHING BUILT YET".
    # Refusing it was this client's defect: it turned a session the generator had
    # just written correctly into "outside its own arc", and the owner met that
    # on their first launch. `recorded/README.md` had already named the reason no
    # test caught it -- the fixture was authored from the schema and held only a
    # STEPPED session, so the suite proved the reader against the schema and
    # never against the generator's initial state. `unstepped/` is that state.
    s.unstepped = s.year == s.first_year - 1
    if s.year < s.first_year - 1 or s.year > s.last_year:
        var msg := "session.json's year %d is outside its own arc " % s.year
        msg += "[%d, %d], which starts at one less than %d " % [s.first_year, s.last_year, s.first_year]
        msg += "for a session that has not been advanced."
        s.problem = msg
        return s
    var step = doc.get("last_step_s", null)
    s.last_step_s = -1.0 if step == null else float(step)
    var start: Dictionary = doc.get("start_pins", {})
    s.start_pins_sha256 = str(start.get("sha256", ""))
    s._collect_shas()
    if s.pins_sha256 == "":
        s.problem = "session.json carries no pins_sha256, so a fold cannot be bound to it."
    return s


## Every digest the session's own record says its pin file has had.
##
## THREE SOURCES, AND THE MIDDLE ONE IS WHY THIS IS NOT JUST A FIELD READ: the
## start file's sha, the sha in every answered `place` or `remove` under
## `commands/done/`, and the current one. A placement moves the pin file and
## re-stamps NO fold already written (`_write_year` runs per year; the session's
## re-pin rewrites no earlier year), so the folds of years stepped before a
## placement keep the sha they were stepped under, for good.
func _collect_shas() -> void:
    shas_had.clear()
    if start_pins_sha256 != "":
        shas_had[start_pins_sha256] = true
    if pins_sha256 != "":
        shas_had[pins_sha256] = true
    var done := dir + "commands/done/"
    # A session that has answered nothing may not have the directory at all, and
    # listing a path that is not there is an engine error the gate reads as a
    # failure. The absence is a state: no answer has moved the pin file.
    if not DirAccess.dir_exists_absolute(done):
        return
    for fn in DirAccess.get_files_at(done):
        if not fn.ends_with(".answer.json"):
            continue
        var ans := SessionRead.read_json(done + fn)
        var result: Dictionary = ans.get("result", {}) if ans.has("result") else {}
        var sha := str(result.get("pins_sha256", ""))
        if sha != "":
            shas_had[sha] = true


## Why this fold is not this session's, or "" if it is.
##
## ⚠ THE BINDING IS NOT A RECOMPUTED IDENTITY, BECAUSE THERE IS NOTHING TO
## RECOMPUTE. A fetched dressing is bound by hashing its own bytes and comparing
## against a committed PIN (`DressingLoad`); a session directory has no PIN, no
## committed digests and, deliberately, no `dressing_sha256` — §25 backlog 749
## recorded that choice as "no invented dressing_sha256". So the binding is the
## strongest claim the files actually support: this session's name, a year the
## session has reached, and a pin-file digest the session has had.
##
## ⚠ AND IT IS NOT "THE CURRENT SHA", WHICH IS THE OBVIOUS ANSWER AND IS WRONG.
## Demanding `session.json`'s current `pins_sha256` would refuse every year
## stepped before the owner's last placement — that is, almost the whole city,
## immediately after the first thing the owner does. The fixture holds exactly
## that state so the test can fail if this is ever "simplified".
func fold_problem(fold: Dictionary) -> String:
    if fold.is_empty():
        return "The fold did not parse."
    var stamp: Dictionary = fold.get("session", {})
    if stamp.is_empty():
        return ("This fold carries no `session` block, so it is not a session's fold. A "
                + "committed dressing's fold carries `dressing_sha256` instead and is read "
                + "by the dressing path, never bound to a session.")
    var got_name := str(stamp.get("name", ""))
    if got_name != session_name:
        var m := "This fold is session %s's, " % JSON.stringify(got_name)
        m += "and this session is %s." % JSON.stringify(session_name)
        return m
    var y := int(fold.get("year", -1))
    if y > year:
        var m2 := "This fold is year %d, " % y
        m2 += "and the session has only reached %d." % year
        return m2
    var sha := str(stamp.get("pins_sha256", ""))
    if not shas_had.has(sha):
        var m3 := "This fold was stepped under pin file %s, " % sha
        m3 += "which this session has never had (its current one is %s)." % pins_sha256
        return m3
    return ""


## The years a slider may offer over this session, or an EMPTY range.
##
## ⚠ THE RULE LIVES HERE RATHER THAN IN THE VIEW BECAUSE THE VIEW CANNOT BE
## BUILT BY THE GATE. `ExplorerView` is a scene node that needs a tree and the
## fetched dressing, so a span computed inside it is a span nothing asserts --
## and the naive computation is wrong in a way no reader would notice by eye:
## `(first_year, year)` INVERTS for an unstepped session, whose year is one
## BELOW its first, giving a slider whose high end sits under its low end.
##
## An empty range means "this session offers no years"; the caller then uses its
## own committed span, because the committed city is what is on screen.
func slider_span() -> Vector2i:
    if not has_span():
        return Vector2i.ZERO
    return Vector2i(first_year, year)


## True when this session has years a slider can offer at all.
##
## ⚠ THE PREDICATE IS THE SIGNAL, NOT THE VALUE. `slider_span` has to say
## "none" somehow, and the first cut of this row said it with `Vector2i.ZERO`
## alone -- a sentinel that reads as data, so a caller skipping the check would
## draw a slider from 0 to 0 and believe it. Emptiness is a question about the
## session, so it is asked of the session; the zero stays only as the harmless
## answer to a question nobody should be asking of the range itself.
func has_span() -> bool:
    return is_present() and not unstepped


## The years this session has folds for, ascending.
func years_present() -> Array:
    var out: Array = []
    for y in range(first_year, year + 1):
        if FileAccess.file_exists(dir + "year_%d/fold.json" % y):
            out.append(y)
    return out


## One year's `stats.json`, stripped; empty if absent or unparsable.
func stats_of(y: int) -> Dictionary:
    return SessionRead.read_json(dir + "year_%d/stats.json" % y)


## One year's `fold.json`, stripped; empty if absent or unparsable.
func fold_of(y: int) -> Dictionary:
    return SessionRead.read_json(dir + "year_%d/fold.json" % y)


## The pin ids a session's fold already draws, so the pin can stand down.
##
## ⚠ TWO DIFFERENT MATCHES, BECAUSE THE GENERATOR WRITES TWO DIFFERENT ROWS.
## A feature row carries `pin_id` outright. A route row laid from a pin carries
## its pin's id as the row's **`route`** -- `lay_route`'s first argument is the
## `route_id`, and `_apply_pin` passes `p["pin_id"]` into it -- with `by` set to
## `"pin"`.
##
## ⚠ AND `by == "pin"` IS NOT BELT AND BRACES. The generator lays routes of its
## own in the same years, with `by` set to `"rule"`; matching on the id alone
## would draw a rule-laid route as the owner's the moment an id collided, and
## matching on the DATE -- which is what this client did until §25 backlog 755 --
## drew every rule-laid route of that year as the owner's. Measured on a real
## session: its 1880 fold carries two routes and **both** are `"rule"`.
##
## ⚠ A CORRECTION OF MY OWN MEASUREMENT BELONGS HERE. I reported that a
## session's route rows carry no `pin_id`. That was true of the two rule-laid
## rows I had, and false in general: `lay_route` writes `row["pin_id"]` whenever
## it is laying from a pin. The sample contained no pin-laid route, and I
## generalised from it. The match below reads `route` and `by`, as ruled, and
## would also have worked on `pin_id`.
static func ids_drawn_by_fold(features: Array, routes: Array) -> Dictionary:
    var out := {}
    for row_v in features:
        if typeof(row_v) != TYPE_DICTIONARY:
            continue
        var pid := str((row_v as Dictionary).get("pin_id", ""))
        if pid != "":
            out[pid] = true
    for row_v in routes:
        if typeof(row_v) != TYPE_DICTIONARY:
            continue
        var row: Dictionary = row_v
        if str(row.get("by", "")) != "pin":
            continue
        var rid := str(row.get("route", ""))
        if rid != "":
            out[rid] = true
    return out


## A session fold's tile rows, keyed as `DressingFold` keys its own state.
##
## ⚠ NOTHING IS COMPUTED HERE. A session's fold is ALREADY folded -- its rows
## carry the per-tile state that `DressingFold.fold` derives from the committed
## `tiles.jsonl` -- so this is a re-keying and not a second fold. The key is
## `DressingFold.tile_key`'s, which is also the form `centres.json` uses, so a
## tile drawn from a session lands at the same centre as the same tile drawn
## from the committed dressing.
##
## A row without a `tile` is skipped rather than guessed at: a fold row with no
## tile names no place, and inventing one would place a tile somewhere.
static func state_of_fold(doc: Dictionary) -> Dictionary:
    var out := {}
    for row_v in doc.get("tiles", []):
        if typeof(row_v) != TYPE_DICTIONARY:
            continue
        var row: Dictionary = row_v
        if not row.has("tile"):
            continue
        out[DressingFold.tile_key(row["tile"])] = row
    return out


## Parse, then STRIP. Never throws; an absent or malformed file is `{}`.
static func read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    var doc: Dictionary = parsed
    SessionRead.strip(doc)
    return doc


## Erase every dropped field, at every depth, in place.
##
## RECURSIVE BECAUSE THE FIELDS ARE NESTED: a fold's `generator_commit` sits
## inside its `session` block, not at the top level, so a top-level erase would
## have left the one copy that is hardest to notice.
static func strip(v) -> void:
    if typeof(v) == TYPE_DICTIONARY:
        var d: Dictionary = v
        for k in DROPPED:
            d.erase(k)
        for k in d.keys():
            SessionRead.strip(d[k])
    elif typeof(v) == TYPE_ARRAY:
        for item in (v as Array):
            SessionRead.strip(item)
