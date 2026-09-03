class_name CellProbe
extends RefCounted

## A world position -> the `(node, band)` that renormalised it, and the value
## of the displayed row at that cell. M4's development probe.
##
## WHAT THIS IS, IN §16.12'S TERMS, WRITTEN HERE RATHER THAN REMEMBERED. The
## scalar at (x, y) is the fine rung and it is earned by presence; a percept
## that answered it anywhere would be handing the fine rung out for free. This
## is not a percept and is not a transducer. It is a development view of the
## server's own data, over artefacts this client already holds whole, and what
## exempts it is that context alone -- nothing about the answer. It is not a
## template for a player-facing readout: when one is wanted, the question goes
## back to §16.12 and not to this file.
##
## THREE ABSENCES, AND ONLY THE LAST IS AN ERROR:
##
##   * NO_GROUND -- nothing under the point. Outside the basin, or in one of
##                  the holes the mesh leaves at nodata rather than walling.
##   * NO_KEY    -- ground carrying no residence key. 4,973 overview pixels
##                  are like this and `ResidenceLayer.key_at` returns [] for
##                  them BY DESIGN (decision 891). A measured absence.
##   * NO_CELL   -- a key the fixture has no cell for. This one is two
##                  artefacts disagreeing; the join measures zero of them.
##
## Reporting the three as one "no data" is the failure ResidenceLayer's header
## is written against: it makes a ruled absence, a measured absence and a
## broken join look like the same thing, which is the one thing they are not.

const NO_GROUND := "no_ground"
const NO_KEY := "no_key"
const NO_CELL := "no_cell"
const RESOLVED := "resolved"

var _hf: Heightfield = null
var _rl: ResidenceLayer = null
var _fl: FixtureLoader = null


func bind(hf: Heightfield, rl: ResidenceLayer, fl: FixtureLoader) -> void:
    _hf = hf
    _rl = rl
    _fl = fl


func is_bound() -> bool:
    return _hf != null and _rl != null and _fl != null


## Probe a world (EPSG:5070) position. `values` is one day of the displayed
## row, indexed by cell; pass an empty array to ask only for the key.
##
## GROUND IS THE RASTER'S OWN VALIDITY, not the bicubic sampler's. `height_at`
## returns NAN for a whole one-texel border where the neighbourhood touches
## nodata, which is the right answer for a surface and the wrong one for a
## question about a texel: the residence layer keys those texels, and calling
## them groundless would report a ruled key as missing terrain.
func at_world(wx: float, wy: float, values: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
    var out := {"world": Vector2(wx, wy), "texel": Vector2i(-1, -1)}
    if not is_bound():
        out["state"] = NO_GROUND
        out["why"] = "the probe is not bound to a terrain and a fixture"
        return out
    var t := _hf.world_to_texel(wx, wy)
    var tx := int(round(t.x))
    var ty := int(round(t.y))
    out["texel"] = Vector2i(tx, ty)
    if is_nan(_hf.height_at_texel(tx, ty)):
        out["state"] = NO_GROUND
        out["why"] = ("no ground here: the point is outside the basin, or in one of the "
                + "holes the mesh leaves at nodata rather than walling them")
        return out
    out["elevation_m"] = _hf.height_at_texel(tx, ty)

    var k := _rl.key_at(tx, ty)
    if k.is_empty():
        out["state"] = NO_KEY
        out["why"] = ("ground with no residence key. 4,973 overview pixels carry terrain "
                + "and no key; residence is server-authoritative (decision 891) and an "
                + "empty answer is the ruled one, not a lookup that missed")
        return out
    out["node_index"] = int(k[0])
    out["band"] = int(k[1])
    var huc: String = _rl.node_of_index.get(int(k[0]), "")
    if huc == "":
        out["state"] = NO_CELL
        out["why"] = ("the residence raster names node index %d and the layer's own index "
                + "has no id for it") % int(k[0])
        return out
    var r := for_key(huc, int(k[1]), values)
    r.merge(out)
    return r


## The half of the probe that is pure lookup: a key in, a cell and a value out.
##
## Separated so the NO_CELL branch can be exercised. It is the one state that
## should never occur against these artefacts, which is exactly why it must
## not be the branch nothing has ever run.
func for_key(huc10: String, band: int,
             values: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
    var out := {"huc10": huc10, "band": band, "node_axis": -1, "cell": -1,
                "value": NAN, "has_value": false}
    if not is_bound():
        out["state"] = NO_CELL
        out["why"] = "the probe is not bound to a fixture"
        return out
    out["node_axis"] = _fl.node_index_of(huc10)
    var ci: Variant = _fl.cell_of_key.get("%s|%d" % [huc10, band], null)
    if ci == null:
        out["state"] = NO_CELL
        out["why"] = ("the residence layer keys this point to %s band %d and the fixture "
                + "has no cell for it -- two artefacts disagreeing, which the join "
                + "measures zero of today") % [huc10, band]
        return out
    out["cell"] = int(ci)
    out["state"] = RESOLVED
    if values.is_empty():
        out["why"] = "no row is displayed, so there is no value to read"
        return out
    if int(ci) >= values.size():
        out["state"] = NO_CELL
        out["why"] = ("cell %d is outside the %d values the displayed row holds"
                % [int(ci), values.size()])
        return out
    var v := values[int(ci)]
    if is_nan(v):
        # NAN is what the fixture stores for nodata, and never 0.0: zero is a
        # real value for every one of these rows.
        out["why"] = "the fixture stores nodata for this cell on this day"
        return out
    out["value"] = v
    out["has_value"] = true
    out["why"] = ""
    return out
