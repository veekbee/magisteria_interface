extends SceneTree

## Dumps every numeric leaf of every inbound JSON artefact as `path<TAB>bits`,
## for `check_decimals.py` to compare against a correctly-rounded parse.
##
## WHY THE BITS AND NOT THE NUMBER. The whole subject is decimals that do not
## survive a parse, so a decimal is the one form this file must not emit. The
## bit pattern is the value; anything else is the value's opinion of itself.
##
## WHY GODOT DOES THE READING. The question is not "is this JSON accurate", it
## is "what does THIS ENGINE do with it" -- and the answer is a property of
## Godot's `built_in_strtod`, not of the document. A checker that parsed these
## files in Python alone would be grading the sim's arithmetic and would have
## found nothing, because the sim's decimals are correct. It is the reader that
## is not.

const DIRS := ["assets/contours", "assets/detail", "assets/families", "assets/fixture",
        "assets/terrain", "contract", "measurements", "measurements/flights"]

var _out: FileAccess


static func bits_of(v: float) -> String:
    var b := PackedByteArray()
    b.resize(8)
    b.encode_double(0, v)
    return "%08x%08x" % [b.decode_u32(4), b.decode_u32(0)]


func _walk(v: Variant, path: String) -> void:
    match typeof(v):
        TYPE_DICTIONARY:
            for k in v:
                _walk(v[k], "%s/%s" % [path, str(k)])
        TYPE_ARRAY:
            for i in (v as Array).size():
                _walk(v[i], "%s/%d" % [path, i])
        TYPE_FLOAT:
            _out.store_line("%s\t%s" % [path, bits_of(v)])
        TYPE_INT:
            # Integers go through a different code path in the parser and are
            # exact; they are dumped anyway so the leaf count is the document's
            # and not a subset somebody has to reason about.
            _out.store_line("%s\t%s" % [path, bits_of(float(v))])


func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var dest := "res://../decimal_leaves.tsv" if args.is_empty() else args[0]
    _out = FileAccess.open(dest, FileAccess.WRITE)
    if _out == null:
        push_error("decimal_leaves: cannot write %s" % dest)
        quit(1)
        return
    var files := PackedStringArray()
    for d in DIRS:
        var da := DirAccess.open("res://" + d)
        if da == null:
            continue
        for f in da.get_files():
            if f.ends_with(".json"):
                files.append("%s/%s" % [d, f])
    files.sort()
    var n := 0
    for rel in files:
        var fa := FileAccess.open("res://" + rel, FileAccess.READ)
        if fa == null:
            continue
        var parsed: Variant = JSON.parse_string(fa.get_as_text())
        if parsed == null:
            push_error("decimal_leaves: %s does not parse" % rel)
            continue
        _walk(parsed, rel)
        n += 1
    _out.close()
    print("decimal_leaves: %d documents -> %s" % [n, dest])
    quit()
