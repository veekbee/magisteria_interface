class_name FixtureLoader
extends RefCounted

## Fixture v1 as the client reads it: quantised band rows plus the cell-key join.
##
## WHAT THIS IS NOT. `fixture_client.bin` is a DISPLAY encoding, not the
## fixture. Three rows in the real fixture are float64 because their smallest
## non-zero magnitudes fall below float32's floor; quantising to 65,534 levels
## discards that. It is acceptable here because a colour ramp cannot show 1e-64
## either -- the loss is in the encoding's stated purpose rather than hidden in
## it -- and anything needing the precision reads the simulation repo's
## `fixture_v1.bin`.
##
## THE JOIN. Band arrays are indexed by CELL; residence answers in
## `(node, band)`. `cell_keys` is the bijection between them, and without it
## the two artefacts cannot be used together at all. It is built once here.

var manifest: Dictionary = {}
var cell_of_key: Dictionary = {}        ## "huc10|band" -> cell index
var n_cells: int = 0
var windows: PackedStringArray = PackedStringArray()
var refused_rows: Dictionary = {}

var _bin_path: String = ""
var _rows: Dictionary = {}              ## "window/row" -> descriptor
var _node_ordinal: Dictionary = {}      ## huc10 -> node axis position


static func load_from(dir_path: String) -> FixtureLoader:
    var fl := FixtureLoader.new()
    var mpath := dir_path + "fixture_client.json"
    if not FileAccess.file_exists(mpath):
        push_error("fixture: no manifest at %s" % mpath)
        return fl
    var f := FileAccess.open(mpath, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("fixture: manifest is not a JSON object")
        return fl
    fl.manifest = parsed
    fl._bin_path = dir_path + str(parsed.get("client_form", {}).get("file", ""))
    fl._rows = parsed.get("client_form", {}).get("rows", {})
    fl.refused_rows = parsed.get("_refused_rows", {})

    var ck: Dictionary = parsed.get("cell_keys", {})
    var pairs: Array = ck.get("pairs", [])
    fl.n_cells = pairs.size()
    for i in pairs.size():
        fl.cell_of_key["%s|%d" % [str(pairs[i][0]), int(pairs[i][1])]] = i
    for w in parsed.get("windows", {}):
        fl.windows.append(w)
    return fl


func is_loaded() -> bool:
    return n_cells > 0 and FileAccess.file_exists(_bin_path)


func row_names(window: String, lattice: String = "") -> PackedStringArray:
    var out := PackedStringArray()
    for k in _rows:
        if str(_rows[k]["window"]) != window:
            continue
        if lattice != "" and str(_rows[k].get("lattice", "band")) != lattice:
            continue
        out.append(str(_rows[k]["row"]))
    out.sort()
    return out


## The engine's node-axis position for a HUC10 id. Node-lattice rows are
## indexed by it.
##
## Read from the manifest's `node_order`, which the simulation emits for this
## purpose. It is NOT inferred from the order ids first appear in `cell_keys`
## -- that inference agrees today and rests on cells being grouped by node
## ordinal, which nothing promises, and a wrong node index draws the wrong
## river's flow while looking entirely plausible.
func node_index_of(huc10: String) -> int:
    if _node_ordinal.is_empty():
        var ids: Array = manifest.get("node_order", {}).get("ids", [])
        for i in ids.size():
            _node_ordinal[str(ids[i])] = i
    return int(_node_ordinal.get(huc10, -1))


func days(window: String, row: String) -> int:
    var d: Variant = _rows.get("%s/%s" % [window, row], null)
    return 0 if d == null else int(d["shape"][0])


## One day of one row, decoded to physical units, indexed by cell.
##
## Taxon-dimensioned rows have a trailing group axis; `group` selects one.
## Values are NAN where the fixture stored nodata, never 0.0 -- zero is a real
## value for every one of these rows.
## Returns float64, NOT float32, and that is load-bearing rather than tidy.
## Node rows are shipped at full float64 precisely because streamflow reaches
## 4.9e-324; storing them in a PackedFloat32Array flushes every value below
## 1.18e-38 to zero, which would undo the exactness at the last container --
## the same failure as rounding the fixture's JSON, one layer further along.
## Measured: it moved thousands of samples from "below the display scale" into
## "no flow", which are different statements about the river.
func day_values(window: String, row: String, day: int, group: int = 0) -> PackedFloat64Array:
    var out := PackedFloat64Array()
    var key := "%s/%s" % [window, row]
    var d: Variant = _rows.get(key, null)
    if d == null:
        push_warning("fixture: no row %s" % key)
        return out
    var shape: Array = d["shape"]
    var n_days := int(shape[0])
    var cells := int(shape[1])
    var groups := 1 if shape.size() < 3 else int(shape[2])
    if day < 0 or day >= n_days or group < 0 or group >= groups:
        return out

    var f := FileAccess.open(_bin_path, FileAccess.READ)
    if f == null:
        push_error("fixture: cannot open %s" % _bin_path)
        return out

    # Node rows are stored as raw float64 rather than quantised -- see the
    # manifest's `not_quantised_because`. Quantising streamflow over the
    # contract's [0, 100000] would put everything below 1.5 m3/s at zero, and
    # 40.9% of this window's non-zero values are below 1e-6.
    if str(d.get("dtype", "")).begins_with("float64"):
        var base64 := int(d["byte_offset"]) + day * cells * groups * 8
        f.seek(base64)
        var raw64 := f.get_buffer(cells * groups * 8)
        out.resize(cells)
        for c in cells:
            out[c] = raw64.decode_double((c * groups + group) * 8)
        return out

    var lo := float(d["lo"])
    var span := float(d["hi"]) - lo
    var stride_cell := groups
    var base := int(d["byte_offset"]) + day * cells * groups * 2
    f.seek(base)
    var raw := f.get_buffer(cells * groups * 2)
    out.resize(cells)
    for c in cells:
        var at := (c * stride_cell + group) * 2
        var v := raw.decode_u16(at)
        out[c] = NAN if v == 65535 else lo + float(v) / 65534.0 * span
    return out
