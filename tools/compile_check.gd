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
## `load` IS NOT THE CHECK, AND THINKING IT WAS MADE THIS STEP PASS ON A TREE
## IT SHOULD HAVE FAILED. Measured: two scripts with a parse error and an
## unresolved identifier, both reported by the engine on stderr, and this tool
## printed "all 63 scripts load" underneath them. `load` returns a GDScript
## object either way -- an EMPTY one for a script that did not compile, which
## is exactly the failure mode described above arriving one level earlier. So
## the object is interrogated rather than counted: `reload` gives the compiler's
## own error code and `can_instantiate` is false for a script with nothing on
## it.
##
## AND IT HAS A NEGATIVE CONTROL, for the same reason the fetch tool's selftest
## does. A checker that cannot fail is not a checker, and this one silently
## could not; a deliberately broken script is compiled on every run so that
## "all N load" is a claim someone verified rather than one nobody could.
##
## It is a compile check and not a lint: what it asserts is that every script
## in the tree can be loaded at all, which is the weakest useful claim and the
## one whose absence is most expensive.

const DIRS := ["res://src", "res://tools", "res://tests"]
const CONTROL := "user://_compile_check_control.gd"


func _init() -> void:
    if not _control_is_caught():
        print("compile: CONTROL FAILED -- a script that does not compile was reported as "
                + "compiling. This step cannot detect anything and its result means nothing.")
        quit(1)
        return
    var failed: Array = []
    var seen := 0
    for d in DIRS:
        seen += _walk(str(d), failed)
    if failed.is_empty():
        print("compile: all %d scripts load (control: a broken script is caught)" % seen)
        quit(0)
        return
    for f in failed:
        print("compile: FAILED %s" % str(f))
    print("compile: %d of %d scripts do not load" % [failed.size(), seen])
    quit(1)


## Whether one script compiles. The engine prints the file and the line itself;
## this only decides whether anything usable came back.
##
## THE RUNNING SCRIPT IS EXEMPT FROM `reload`, AND ONLY FROM THAT. A script
## cannot recompile itself while it is the one executing -- measured: this file
## reloads to OK from any other script and to a failure from inside its own
## `_init`, and taking that at face value made the checker's first run report
## itself as broken. Its compiling is not in doubt anyway: nothing here would
## be running otherwise. `can_instantiate` still applies to it.
func _compiles(path: String) -> bool:
    var res: Variant = load(path)
    if res == null:
        return false
    var gs := res as GDScript
    if gs == null:
        return false
    # 43 is ERR_PARSE_ERROR, which is what a script with a type error comes
    # back as. Checked as "anything but OK" rather than against that number,
    # because the interesting case is the next error code, not this one.
    if path != _own_path() and gs.reload() != OK:
        return false
    return gs.can_instantiate()


func _own_path() -> String:
    var s: Variant = get_script()
    return "" if s == null else str((s as Script).resource_path)


## Compile something that must not compile. Written outside `res://` so it is
## never part of the tree this tool walks and can never be shipped.
func _control_is_caught() -> bool:
    var f := FileAccess.open(CONTROL, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string("extends RefCounted\n"
            + "func broken() -> int:\n"
            + "    var q: int = \"a string is not an int\"\n"
            + "    return q + no_such_function()\n")
    f.close()
    var caught := not _compiles(CONTROL)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(CONTROL))
    return caught


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
        if not _compiles(path + "/" + f):
            failed.append(path + "/" + f)
    return n
