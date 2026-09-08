extends SceneTree

## Load every GDScript in the tree and report the ones that do not compile.
##
## WHY THIS IS ITS OWN STEP. `--import` does not compile GDScript, and a
## `class_name` script that fails to compile does not vanish -- it resolves to
## a bare GDScript with none of its statics on it. The symptom is a runtime
## "Nonexistent function 'x' in base 'GDScript'" at the CALLER, a thousand
## lines into a test log, with the file that actually has the error in it
## unmentioned. Loading each script names the file and the line, which is where
## a person can act on it.
##
## It is a compile check and not a lint: what it asserts is that every script
## in the tree can be loaded at all, which is the weakest useful claim and the
## one whose absence is most expensive.

const DIRS := ["res://src", "res://tools", "res://tests"]


func _init() -> void:
    var failed: Array = []
    var seen := 0
    for d in DIRS:
        seen += _walk(str(d), failed)
    if failed.is_empty():
        print("compile: all %d scripts load" % seen)
        quit(0)
        return
    for f in failed:
        print("compile: FAILED %s" % str(f))
    print("compile: %d of %d scripts do not load" % [failed.size(), seen])
    quit(1)


func _walk(path: String, failed: Array) -> int:
    var d := DirAccess.open(path)
    if d == null:
        return 0
    var n := 0
    for sub in d.get_directories():
        n += _walk(path + "/" + sub, failed)
    for f in d.get_files():
        if not f.ends_with(".gd"):
            continue
        n += 1
        # Errors print themselves, with the file and the line. What is checked
        # here is only whether anything came back.
        if load(path + "/" + f) == null:
            failed.append(path + "/" + f)
    return n
