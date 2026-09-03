class_name FamilySet
extends RefCounted

## M5's form archetypes: one family per life form, and the legal ranges an
## instance's parameters must fall inside.
##
## THE FAMILY IS AUTHORED; THE INDIVIDUAL IS PARAMETERS (§17.8.2). Nothing here
## carries a size. Each mesh is normalised to one metre tall and one metre
## across, so an instance transform is `scale(crown_m, height_m, crown_m)` and
## the two axes move independently -- they come from different carried rows and
## a uniform scale would tie them together.
##
## KEYED BY LIFE FORM AND BY NOTHING ELSE. Palettes are off the wire (decision
## 894), the fixture aggregates to life form (decisions 872, 889), and a
## size-baked form token is wrong rather than imprecise on most of a palette
## (§23.302, decision 180). There is no per-PFT mesh here and no key one could
## be indexed by if there were.
##
## THE ORDER COMES FROM THE WIRE, NOT FROM THIS FILE. `families.json` is a map
## from name to file; the group axis's order is read from the fixture's
## `taxon_groups`. The wire's order is alphabetical -- grass, shrub, succulent,
## tree -- and this manifest's is whatever JSON key order happens to be, so
## keying on position would scatter each family over another family's ground
## and look entirely plausible while doing it.
##
## PARAMETERS ARE REFUSED, NEVER CLAMPED. A height outside a family's legal
## range is a computation that went wrong somewhere upstream; silently pulling
## it to the nearest legal value produces a plausible tree and destroys the
## evidence. `instance_transform` returns the reason instead.

const DIR := "res://assets/families/"

var manifest: Dictionary = {}
var families: Dictionary = {}        ## life_form -> manifest entry
var why_absent: String = ""

var _meshes: Dictionary = {}         ## life_form -> Mesh


static func load_from(dir_path: String = DIR) -> FamilySet:
    var fs := FamilySet.new()
    var mpath := dir_path + "families.json"
    if not FileAccess.file_exists(mpath):
        fs.why_absent = "no manifest at %s -- run tools/build_families.sh" % mpath
        return fs
    var f := FileAccess.open(mpath, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        fs.why_absent = "%s is not a JSON object" % mpath
        return fs
    fs.manifest = parsed
    fs.families = parsed.get("families", {})
    for life_form in fs.families:
        var entry: Dictionary = fs.families[life_form]
        var path := dir_path + str(entry.get("file", ""))
        var mesh := _mesh_in(path)
        if mesh == null:
            push_error("families: %s names %s, which holds no mesh" % [life_form, path])
            continue
        fs._meshes[life_form] = mesh
    return fs


## The first mesh in an imported glTF scene.
##
## The exporter writes one mesh per family by construction, so this takes the
## first rather than merging: a second mesh would mean the family stopped being
## one form, which is a thing to notice rather than to silently combine.
static func _mesh_in(path: String) -> Mesh:
    if not ResourceLoader.exists(path):
        return null
    var packed := load(path) as PackedScene
    if packed == null:
        return null
    var root := packed.instantiate()
    var found: Mesh = null
    var stack: Array = [root]
    while not stack.is_empty():
        var node = stack.pop_back()
        if node is MeshInstance3D and found == null:
            found = (node as MeshInstance3D).mesh
        for child in node.get_children():
            stack.append(child)
    root.free()
    return found


func is_loaded() -> bool:
    return not _meshes.is_empty()


func life_forms() -> PackedStringArray:
    var out := PackedStringArray()
    for k in families:
        out.append(str(k))
    out.sort()
    return out


func has(life_form: String) -> bool:
    return _meshes.has(life_form)


func mesh_for(life_form: String) -> Mesh:
    return _meshes.get(life_form, null)


func triangles_of(life_form: String) -> int:
    return int(families.get(life_form, {}).get("triangles", 0))


## `[min, max]` for one parameter, or an empty Vector2 span when the family or
## the parameter is not declared -- which is itself a refusal, not a default.
func range_of(life_form: String, parameter: String) -> Dictionary:
    var entry: Dictionary = families.get(life_form, {})
    var params: Dictionary = entry.get("parameters", {})
    if not params.has(parameter):
        return {}
    var p: Dictionary = params[parameter]
    return {"min": float(p["min"]), "max": float(p["max"]), "from": str(p.get("from", ""))}


## "" if the value is legal, otherwise why it is not. NEVER a clamped value.
func check(life_form: String, parameter: String, value: float) -> String:
    if not has(life_form):
        return "no family for life form %s" % life_form
    var r := range_of(life_form, parameter)
    if r.is_empty():
        return "%s declares no legal range for %s" % [life_form, parameter]
    if is_nan(value):
        return "%s.%s is NAN, which is outside every range" % [life_form, parameter]
    if value < float(r["min"]) or value > float(r["max"]):
        return ("%s.%s = %s is outside its legal range [%s, %s]"
                % [life_form, parameter, String.num(value, 4),
                   String.num(float(r["min"]), 4), String.num(float(r["max"]), 4)])
    return ""


## An instance's transform, or the reason there is not one.
##
## `height_m` and `crown_m` are checked against the family's declared ranges
## before either is used. A refusal returns the identity transform, which is
## visibly wrong if a caller ignores the refusal -- a clamped one would not be.
##
## `vertical_scale` IS APPLIED AFTER THE CHECK AND IS NOT A PARAMETER. M1 draws
## this basin at 12x relief, so a plant drawn at true height reads as twelve
## times too short against the ground it stands on. That is a property of the
## view, not of the plant: checking the exaggerated height against a range
## expressed in metres of real plant refuses every legal tree in the basin,
## which is exactly what the first version of this did.
func instance_transform(life_form: String, position: Vector3,
                        height_m: float, crown_m: float,
                        vertical_scale: float = 1.0) -> Dictionary:
    for pair in [["height_m", height_m], ["crown_m", crown_m]]:
        var why := check(life_form, str(pair[0]), float(pair[1]))
        if why != "":
            return {"ok": false, "why": why, "transform": Transform3D.IDENTITY}
    var basis := Basis.IDENTITY.scaled(
            Vector3(crown_m, height_m * vertical_scale, crown_m))
    return {"ok": true, "why": "", "transform": Transform3D(basis, position)}


## Which of the wire's groups this set has no family for.
##
## The wire is the authority on how many families are owed. A group with no
## family is reported by name rather than skipped, so a fifth life form
## appearing upstream shows up as a gap instead of as silence.
func missing_for(groups: PackedStringArray) -> PackedStringArray:
    var out := PackedStringArray()
    for g in groups:
        if not has(g):
            out.append(g)
    return out


## The families the manifest records as deliberately absent, and why.
func not_here() -> Dictionary:
    return manifest.get("not_here", {})
