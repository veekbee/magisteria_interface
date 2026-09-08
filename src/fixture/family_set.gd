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
## KEYED BY LIFE FORM OFF THE WIRE, AND BY TAXON NODE WHERE A PRODUCER SENDS
## ONE. Palettes are off the wire (decision 894), the fixture aggregates to
## life form (decisions 872, 889), and a size-baked form token is wrong rather
## than imprecise on most of a palette (§23.302, decision 180). None of that
## has changed, and none of it is a statement about a node an OBSERVER earned:
## a refinement overlay carries a taxon node, and the node is the key. So
## `families` is indexed off the fixture and `specific` never is.
##
## THE LOOKUP IS THE IDENTITY, AND THAT IS A REQUIREMENT RATHER THAN A
## CONVENIENCE (§17.8.6). Every internal node of the taxonomy has a
## representative form, so `resolve` always answers with SOME asset -- a node
## with none falls back to its parent's archetype and says it did. That is what
## makes a missing model ART DEBT rather than a smaller percept: if the lookup
## could fail, a modelling gap would start reading as a claim about what the
## observer earned.
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

const LIFE_FORM_RUNG := "life_form"
const SPECIFIC_RUNG := "specific"

var manifest: Dictionary = {}
var families: Dictionary = {}        ## life_form -> manifest entry
var specific: Dictionary = {}        ## taxon node -> manifest entry (carries `life_form`)
var why_absent: String = ""

var _meshes: Dictionary = {}         ## life_form -> Mesh
var _specific_meshes: Dictionary = {} ## taxon node -> Mesh
var _foliage: Dictionary = {}        ## life_form -> area-weighted mask mean


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
    fs.specific = parsed.get("specific", {})
    for life_form in fs.families:
        var entry: Dictionary = fs.families[life_form]
        var path := dir_path + str(entry.get("file", ""))
        var mesh := _mesh_in(path)
        if mesh == null:
            push_error("families: %s names %s, which holds no mesh" % [life_form, path])
            continue
        fs._meshes[life_form] = mesh
    for node in fs.specific:
        var entry: Dictionary = fs.specific[node]
        var path := dir_path + str(entry.get("file", ""))
        var mesh := _mesh_in(path)
        if mesh == null:
            # NOT AN ERROR AND NOT SILENCE. A declared node with no mesh is art
            # debt, and `resolve` will draw the parent and say so; pushing an
            # error here would make a modelling gap look like a load failure.
            push_warning("families: node %s names %s, which holds no mesh -- ART DEBT"
                    % [node, path])
            continue
        fs._specific_meshes[str(node)] = mesh
    return fs


## Every taxon node this client can draw at the specific rung.
func nodes() -> PackedStringArray:
    var out := PackedStringArray()
    for n in specific:
        out.append(str(n))
    out.sort()
    return out


## The life form a specific node refines, or "" if the node is not one.
func parent_of(node: String) -> String:
    return str((specific.get(node, {}) as Dictionary).get("life_form", ""))


## Which rung a node sits at. Two here: the four life forms the wire names, and
## the taxa a refinement can name below them.
func rung_of(node: String) -> String:
    if families.has(node):
        return LIFE_FORM_RUNG
    if specific.has(node):
        return SPECIFIC_RUNG
    return ""


## WHICH ASSET ACTUALLY DRAWS A NODE, and at which rung.
##
## Always answers, because the lookup is required to be the identity. A node
## with no asset of its own draws its parent's archetype, reports the rung it
## was actually drawn at -- which is the parent's, not the one asked for -- and
## flags `art_debt`. Nothing here reduces what the observer earned; it reports
## what this client could show of it.
func resolve(node: String) -> Dictionary:
    if _specific_meshes.has(node):
        return {"ok": true, "node_drawn": node, "rung": SPECIFIC_RUNG,
                "art_debt": false, "why": ""}
    var parent := parent_of(node)
    if parent != "" and _meshes.has(parent):
        return {"ok": true, "node_drawn": parent, "rung": LIFE_FORM_RUNG, "art_debt": true,
                "why": ("ART DEBT: no asset for %s, so its parent %s is drawn. The lookup is "
                        % [node, parent]
                        + "required to be the identity, so this is a missing model and not a "
                        + "claim about what the observer earned.")}
    if _meshes.has(node):
        return {"ok": true, "node_drawn": node, "rung": LIFE_FORM_RUNG,
                "art_debt": false, "why": ""}
    return {"ok": false, "node_drawn": "", "rung": "", "art_debt": true,
            "why": "no asset and no parent for node %s" % node}


## The mesh `resolve` chose.
func mesh_for_node(node: String) -> Mesh:
    var r := resolve(node)
    return null if not bool(r["ok"]) else _mesh_for(str(r["node_drawn"]))


func _mesh_for(node: String) -> Mesh:
    if _specific_meshes.has(node):
        return _specific_meshes[node]
    return _meshes.get(node, null)


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


## Whether SOME asset would answer this node -- its own, or its parent's.
## Always true for a life form this set holds, which is what the identity
## lookup guarantees.
func can_draw(node: String) -> bool:
    return bool(resolve(node)["ok"])


func mesh_for(life_form: String) -> Mesh:
    return _meshes.get(life_form, null)


## What share of a family's silhouette is foliage rather than permanent
## structure, area-weighted over its own triangles.
##
## THE FAR FIELD NEEDS THE SAME NUMBER THE SHADER USES, ONE STEP UP. Per
## instance, `vegetation.gdshader` mixes structure toward foliage by the
## AUTHORED vertex-colour mask; per cell, a tint standing in for a stand needs
## that mix averaged over the whole plant, or the far field is a different
## colour from the near field by construction. Read off the mesh rather than
## declared in the manifest, because the mesh is what renders and a declared
## number is a second copy free to disagree with it.
##
## Area-weighted, not vertex-averaged: a trunk built from four long quads and a
## canopy from forty small triangles have very different vertex counts and very
## similar screen areas, and it is screen area the tint is reproducing.
func foliage_fraction(life_form: String) -> float:
    if _foliage.has(life_form):
        return float(_foliage[life_form])
    var mesh: Mesh = mesh_for(life_form)
    if mesh == null or mesh.get_surface_count() == 0:
        return NAN
    var arrays := mesh.surface_get_arrays(0)
    var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    if colours.is_empty():
        return NAN
    var area := 0.0
    var weighted := 0.0
    var n: int = (indices.size() if not indices.is_empty() else verts.size()) / 3
    for t in n:
        var i0 := indices[t * 3] if not indices.is_empty() else t * 3
        var i1 := indices[t * 3 + 1] if not indices.is_empty() else t * 3 + 1
        var i2 := indices[t * 3 + 2] if not indices.is_empty() else t * 3 + 2
        var a := 0.5 * (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).length()
        area += a
        weighted += a * (colours[i0].r + colours[i1].r + colours[i2].r) / 3.0
    var f: float = 0.0 if area <= 0.0 else weighted / area
    _foliage[life_form] = f
    return f


## Triangles of the asset that would actually DRAW this node, which is the
## number a frame budget has to price. A node falling back to its parent costs
## the parent's triangles, not the ones its own model would have had.
func triangles_of(node: String) -> int:
    if families.has(node):
        return int((families[node] as Dictionary).get("triangles", 0))
    var r := resolve(node)
    if not bool(r["ok"]):
        return 0
    var drawn := str(r["node_drawn"])
    if specific.has(drawn):
        return int((specific[drawn] as Dictionary).get("triangles", 0))
    return int((families.get(drawn, {}) as Dictionary).get("triangles", 0))


## `[min, max]` for one parameter, or an empty Vector2 span when the family or
## the parameter is not declared -- which is itself a refusal, not a default.
## INHERITED EXACTLY BY A SPECIFIC NODE, never narrowed. A tighter span for a
## named taxon would be calibration this client authored and no producer sent --
## a claim about how tall this plant grows here, invented to look precise.
func range_of(life_form: String, parameter: String) -> Dictionary:
    var key := life_form
    if specific.has(key):
        key = parent_of(key)
    var entry: Dictionary = families.get(key, {})
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
