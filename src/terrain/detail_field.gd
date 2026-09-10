class_name DetailField
extends RefCounted

## METRE-SCALE RELIEF AS A PURE FUNCTION OF POSITION.
##
## The shipped lattice stops at a resolution a body can feel through: the
## ground changes every hundred metres of walking, which is twenty seconds at
## the speed one sustains. Below the finest data any world has, ground is
## authored -- sub-metre reality does not exist for 640,000 km2 -- and the
## question is only whether it is authored ONCE, published, and evaluated
## identically by everything that touches it, or improvised separately by each
## consumer. This is the first.
##
## EXACT AT THE PARENT SAMPLES, WHICH IS THE CONSTRAINT THE REST RESTS ON.
## Detail refines and never contradicts: the function reproduces the shipped
## lattice values exactly, so every consumer that samples at lattice resolution
## -- slope, aspect, routing, zonal statistics, energy budgets -- is untouched
## by its existence. The conserved primitive is the shipped grid.
##
## HOW EXACTNESS IS ACHIEVED, AND IT IS THE WHOLE OF THE METHOD: the function
## subtracts its own coarse component. `detail(x) = f(x) - P[f](x)`, where `f`
## is the noise field and `P[f]` is `f` sampled at the parent lattice and put
## back through an INTERPOLATING scheme. At a parent node the two terms are the
## same number, so the detail is exactly zero -- not small, zero -- and the sum
## is the lattice value bit for bit. It costs sixteen extra evaluations of `f`
## per query, and that cost is the price of the constraint rather than an
## inefficiency to optimise away.
##
## DETERMINISTIC AND POSITION-SEEDED, through `StableHash` -- the same mixer
## placement uses, for the same reason: an engine-internal generator moves the
## world when the engine updates. Every client and the simulation compute the
## same ground from the same position.
##
## THE PARAMETERS ARE DATA ROWS AND TODAY THEY ARE FAKE. Amplitude, spectral
## slope, octave count and anisotropy per landform class, in
## `assets/detail/detail_rows.json`, which says in three places that every
## number in it is invented. What is real is the row schema.

const ROWS_PATH := "res://assets/detail/detail_rows.json"

## Landform classes this field knows. Two of them are the owner's acceptance
## criterion stated as rows: a playa is smooth and rocky slopes are rough.
const CLASSES := ["playa", "floor", "slope", "talus", "riparian_margin"]

## The most halvings any row can ask for. Cost is linear in this, and a row
## asking for a millimetre under a kilometre parent would ask for twenty.
const MAX_OCTAVES := 12

var rows: Dictionary = {}
## Where the rows came from. Part of what makes two fields the SAME FUNCTION --
## see `same_function_as`, and the guard that needed it.
var rows_path: String = ""
var why_absent: String = ""

## Metres between parent lattice samples. The detail is exactly zero on this
## grid and everything below it is synthesised.
var parent_spacing_m: float = 0.0

## Finest wavelength the function synthesises, metres. Read from the octave
## count of the coarsest row rather than declared, so it cannot drift from what
## is actually evaluated.
var finest_m: float = 0.0

## THE PARENT SPACING THE ROWS' AMPLITUDES WERE MEASURED AT.
##
## `amplitude_m` IS NOT SCALE FREE, and the units block in the rows file has
## always said so -- "standard deviation of the detail term AT THE PARENT
## SPACING". What it did not say was which parent, and nothing read it.
##
## That is fine while there is one parent and fails the moment there are two,
## which is what streaming introduces. Refining a 100 m lattice, the data
## already carries everything between 1,000 m and 100 m, so the function must
## supply only what is below 100 m -- and that is a SMALLER standard deviation
## than the same row supplies under a 1,000 m parent. Taking the number
## literally at both spacings puts the full 1,000 m roughness into the last
## 100 m: measured, 3.5x too much, and it arrives exactly when a level
## switches, which is the one moment a viewer is looking at the ground change.
##
## So the amplitude is rescaled by the row's own exponent. For fBm the RMS
## increment over a lag scales as lag^H, and `spectral_slope` IS that exponent
## here -- the per-octave amplitude ratio is 0.5^slope -- so the same row under
## a different parent is the same surface, sampled over a different band.
##
## Per-row, with a file-level default, the same shape decision 972 made for
## `host_base`: one number where one is enough, an override where a class was
## measured on a different window.
var calibrated_at_parent_m: float = 0.0
## Empty when the rows declared it, and a sentence when they did not. Separate
## from `why_absent`, which means the field does not work at all.
var calibration_note: String = ""

var _hf: Heightfield = null
## THE DERIVED LAYERS, when this clone has them. Null is a working clone and
## the classifier says which source it used rather than answering the same way
## either way.
var _layers: TerrainLayers = null
## Which level of the layers to read. DERIVED FROM THE PARENT SPACING, not
## fixed at the finest: a classifier refining a 1 km lattice that sampled slope
## at 100 m would classify a kilometre of ground by one point of it. The same
## discipline `calibrated_at_parent_m` applies to amplitude -- a quantity is
## read at the scale it is being used at -- and it falls out of the same
## principle rather than being a second rule.
var _layer_z: int = 0
## The 16 parent-node noise values of the cell last asked about, per landform:
## `landform -> [x0, y0, stencil]`.
##
## EXACTNESS COSTS SEVENTEEN NOISE EVALUATIONS A SAMPLE -- one for the point
## and sixteen for the stencil it is measured against -- and that is the price
## of the constraint rather than an inefficiency. What IS an inefficiency is
## paying it again for the next sample in the same parent cell, and consecutive
## samples are nearly always in one: a row of mesh vertices, a variogram pair,
## a plant and its neighbour. So the last cell is remembered per landform.
##
## A memo and not an approximation: the same sixteen numbers, computed once.
## One cell deep and keyed on integers rather than a formatted string, because
## a cache that allocates on every hit is not a cache.
var _stencil: Dictionary = {}


static func load_from(hf: Heightfield, path: String = ROWS_PATH,
                      spacing_m: float = 0.0,
                      layers: TerrainLayers = null) -> DetailField:
    var df := DetailField.new()
    df._hf = hf
    df.parent_spacing_m = spacing_m if spacing_m > 0.0 else hf.pixel_size_m
    df.bind_layers(layers)
    if not FileAccess.file_exists(path):
        df.why_absent = "no parameter rows at %s" % path
        return df
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        df.why_absent = "%s is not a JSON object" % path
        return df
    df.rows = parsed
    df.rows_path = path
    df.calibrated_at_parent_m = float(df.rows.get("calibrated_at_parent_m", 0.0))
    if df.calibrated_at_parent_m <= 0.0:
        # NOT A SILENT 1:1. A rows file that does not say which parent its
        # amplitudes were measured at cannot be rescaled to another one, so
        # the honest reading is that they belong to the parent in front of
        # them and no level switch is safe until the file says otherwise.
        df.calibrated_at_parent_m = df.parent_spacing_m
        df.calibration_note = ("the rows do not declare `calibrated_at_parent_m`, so their "
                + "amplitudes are read as belonging to whatever parent they are used "
                + "with. That is right for one level and wrong for two.")
    df.finest_m = INF
    for name in df.landforms():
        df.finest_m = minf(df.finest_m,
                df.parent_spacing_m / pow(2.0, float(df.octaves_for(str(name)))))
    return df


## HOW MANY HALVINGS THIS CLASS NEEDS UNDER THE PARENT IT IS REFINING.
##
## DERIVED FROM A RESOLUTION, NOT DECLARED AS A COUNT. A row saying "seven
## octaves" means 7.8 m under the shipped overview and 0.78 m under the
## pyramid's 100 m level -- the same row, two different products. So the row
## states the finest wavelength it wants and this works out the count, and a
## parent that changes moves the count rather than the answer.
##
## Capped, because the cost is linear in octaves and a row asking for a
## millimetre under a kilometre parent would ask for twenty of them.
func octaves_for(landform: String) -> int:
    var finest := float(row(landform).get("finest_wavelength_m", 1.0))
    if finest <= 0.0 or parent_spacing_m <= 0.0:
        return 1
    return clampi(int(ceil(log(parent_spacing_m / finest) / log(2.0))), 1, MAX_OCTAVES)


## THE SAME FUNCTION OVER A DIFFERENT PARENT LATTICE.
##
## THIS IS WHAT MAKES "ONE GROUND, EVERY CONSUMER" SURVIVE A SECOND LEVEL. A
## `DetailField` is two things: a function, which is the rows and their
## calibration, and a LATTICE, which is whatever grid it is refining. Those
## were one object while there was one grid, and streaming made that a defect
## rather than a simplification -- the near field refines the pyramid's 100 m
## level and was being handed a field that thought it was refining a kilometre.
##
## MEASURED, BEFORE THE GUARD BELOW EXISTED: a 1,000 m-parented field on a
## 100 m patch moved 676 of 729 sampled patch vertices, by up to 0.36 m, and
## applied 1.6 m of amplitude where 0.451 m is the same surface. Both halves
## wrong at once -- the exactness is asserted about a lattice nobody is drawing,
## and the roughness is the full kilometre band laid over ground that already
## carries it.
##
## Shares the rows rather than re-reading them: a re-parent is a change of
## lattice and must not be an opportunity for the function to differ.
func for_parent(spacing_m: float) -> DetailField:
    if spacing_m <= 0.0 or is_equal_approx(spacing_m, parent_spacing_m):
        return self
    var df := DetailField.new()
    df._hf = _hf
    df.rows = rows
    df.rows_path = rows_path
    df._layers = _layers
    df.calibrated_at_parent_m = calibrated_at_parent_m
    df.calibration_note = calibration_note
    df.why_absent = why_absent
    df.parent_spacing_m = spacing_m
    df._layer_z = df.level_for_spacing(spacing_m)
    df.finest_m = INF
    for name in df.landforms():
        df.finest_m = minf(df.finest_m,
                df.parent_spacing_m / pow(2.0, float(df.octaves_for(str(name)))))
    return df


## WHETHER TWO FIELDS ARE THE SAME FUNCTION, DELIBERATELY IGNORING THE LATTICE.
##
## The guard that keeps a scatter and a mesh on one ground used to be object
## identity, which was right while one lattice was the only lattice and became
## wrong the moment a patch needed its own. Identity would REFUSE the correctly
## re-parented field and accept only the mis-parented one, which is a guard
## enforcing the defect it was written to prevent.
##
## So sameness is the rows and the calibration they were measured against.
## Parent spacing is excluded on purpose: `calibrated_at_parent_m` exists
## precisely so that one row is one surface at every parent.
func same_function_as(other: DetailField) -> bool:
    if other == null:
        return false
    return (rows_path == other.rows_path
            and is_equal_approx(calibrated_at_parent_m, other.calibrated_at_parent_m))


## THIS CLASS ROW'S AMPLITUDE UNDER THE PARENT ACTUALLY BEING REFINED.
##
## Exactly the declared number when the parent is the one it was calibrated
## at, so a single-level client is unchanged to the bit; a power law in the
## row's own exponent otherwise. See `calibrated_at_parent_m`.
func amplitude_for(landform: String) -> float:
    var p := row(landform)
    var a := float(p.get("amplitude_m", 0.0))
    var ref := float(p.get("calibrated_at_parent_m", calibrated_at_parent_m))
    if ref <= 0.0 or parent_spacing_m <= 0.0 or is_equal_approx(ref, parent_spacing_m):
        return a
    return a * pow(parent_spacing_m / ref, float(p.get("spectral_slope", 1.0)))


## Take the derived layers, and pick the level to read them at.
func bind_layers(layers: TerrainLayers) -> void:
    _layers = layers if layers != null and layers.is_loaded() else null
    _layer_z = level_for_spacing(parent_spacing_m)


## THE LEVEL WHOSE PIXEL IS CLOSEST TO THIS PARENT SPACING, in ratio rather
## than in metres: 800 m and 1,600 m are 200 m and 600 m from a 1,000 m parent
## but 0.8x and 1.6x of it, and a pyramid halves, so the ratio is the distance
## that matches how the levels are spaced.
func level_for_spacing(spacing_m: float) -> int:
    if _layers == null or spacing_m <= 0.0:
        return 0
    var best := 0
    var best_d := INF
    for lv in (_layers.layers.get(TerrainLayers.SLOPE, {}) as Dictionary).get("levels", []):
        var d: Dictionary = lv
        var px := float(d["pixel_size_m"])
        if px <= 0.0:
            continue
        var dist: float = absf(log(px / spacing_m))
        if dist < best_d:
            best_d = dist
            best = int(d["z"])
    return best


## Where the classifier's slope came from, for a report that has to say whether
## a number is data or a re-derivation.
func classifier_source() -> String:
    if _layers == null:
        return ("the parent lattice's own gradient. The derived layers are not fetched: "
                + "`python3 tools/fetch_artefacts.py`.")
    return ("slope at z=%d (%s m), the level nearest this parent spacing; distance-to-channel "
            % [_layer_z, String.num(_layers.pixel_size_of(TerrainLayers.SLOPE, _layer_z), 0)]
            + "at z=0 (%s m) always, because a distance transform does not average. Both from "
            % String.num(_layers.pixel_size_of(TerrainLayers.DISTANCE, 0), 0)
            + "assets/terrain/layers/")


func is_loaded() -> bool:
    return not rows.is_empty() and _hf != null and parent_spacing_m > 0.0


func landforms() -> PackedStringArray:
    var out := PackedStringArray()
    for k in (rows.get("landforms", {}) as Dictionary):
        out.append(str(k))
    out.sort()
    return out


func row(landform: String) -> Dictionary:
    var r: Dictionary = (rows.get("landforms", {}) as Dictionary).get(landform, {})
    if not r.is_empty() and not r.has("_name"):
        r["_name"] = landform
    return r


## THE GROUND: the lattice, plus the detail that vanishes on it.
func height_at(w: Vector2) -> float:
    var base := _hf.height_at_world(w.x, w.y)
    if is_nan(base) or not is_loaded():
        return base
    return base + detail_at(w)


## HOW MUCH OF EACH LANDFORM STRATUM APPLIES HERE. Sums to exactly 1.
##
## DECISION 985 REJECTS A HARD LANDFORM CLASSIFIER CONDITIONING AMPLITUDE AT
## RUNTIME, and this class was one: `classify` picked a class and the class
## picked an amplitude. An amplitude step on a class boundary is a RENDERED
## SEAM on a line no landform owns -- a visible crease where two invented
## thresholds meet, running across ground that does not change. Convention 1
## says the same thing generally: a hard threshold anywhere is a bug, and the
## fix is a clamped ramp.
##
## SO CALIBRATION STRATIFIES AND RUNTIME BLENDS. The rows stay per-landform,
## because that is how a calibration is measured and how 986's bands are
## graded; what changes is that a POSITION is no longer in one stratum. It is
## in a mixture, and the mixture varies smoothly.
##
## COMPACT SUPPORT, WHICH MAKES THIS CHEAPER THAN IT LOOKS. The weights are
## built as a telescoping chain of smoothsteps over the slope boundaries --
## `1-S1, S1-S2, S2-S3, S3` -- so they sum to 1 by construction rather than by
## normalising, and each is EXACTLY zero outside its own band. Away from a
## boundary exactly one stratum is non-zero, and inside one exactly two are, so
## a typical evaluation costs one or two noise fields rather than five. A
## Gaussian-style kernel would have been non-zero everywhere and cost all five
## at every sample, for a contribution below the float32 position quantum.
##
## THE MARGIN RIDES ITS OWN CONDITION, not the slope chain: a margin on a
## 3-degree slope is a margin. It is blended over the whole chain rather than
## added to it -- `(1-r) * chain + r * riparian` -- so the sum stays 1.
##
## WHAT CONDITIONS IT IS SLOPE AND, WHEN IT EXISTS, HAND. 985 names both. No
## HAND raster is vendored, so the margin's condition is distance-to-channel --
## HAND's horizontal sibling, already in use for this class, and stated here as
## the stand-in it is rather than passed off as the thing 985 asked for.
func weights_at(w: Vector2) -> Dictionary:
    var c: Dictionary = rows.get("classifier", {})
    var deg := slope_degrees_at(w)
    if is_nan(deg):
        # No slope anywhere -- the layer has a hole and the lattice could not
        # answer either. One stratum at full weight, the same answer the hard
        # classifier gave, because there is nothing here to blend BETWEEN.
        return {"floor": 1.0}
    var chain := slope_weights(deg)

    var r := 0.0
    var d_channel := distance_to_channel_m(w)
    if not is_nan(d_channel):
        var near := float(c.get("riparian_within_m", 150.0))
        var mhalf := 0.5 * maxf(0.0, float(c.get("riparian_blend_m", 0.0)))
        r = 1.0 - _ramp(d_channel, near, mhalf)

    var out := {}
    if r > 0.0:
        out["riparian_margin"] = r
    for name in chain:
        var v: float = float(chain[name]) * (1.0 - r)
        # EXACTLY ZERO IS DROPPED AND NOTHING ELSE IS. This is not a tolerance:
        # the chain's terms are identically zero outside their bands, so the
        # entries left out contribute nothing at all rather than something
        # small. A threshold here would be the hard cut this method exists to
        # remove, reintroduced as an optimisation.
        if v != 0.0:
            out[str(name)] = v
    return out


## WHAT THE HARD CLASSIFIER WOULD HAVE ANSWERED AT ONE SLOPE.
##
## KEPT ONLY AS THE CONTROL FOR WHAT THE BLEND REMOVED. Nothing at runtime
## calls it: an amplitude picked this way steps at every centre, which is the
## rendered seam 985 rejects. It is here so the gate can measure the step
## rather than assert that one used to exist, and so that a reader comparing
## the two forms can see them side by side.
func classify_by_slope(deg: float) -> String:
    var c: Dictionary = rows.get("classifier", {})
    if deg < float(c.get("playa_below_slope_deg", 0.6)):
        return "playa"
    if deg < float(c.get("floor_below_slope_deg", 4.0)):
        return "floor"
    if deg < float(c.get("slope_below_slope_deg", 22.0)):
        return "slope"
    return "talus"


## THE SLOPE CHAIN ALONE, as a function of degrees.
##
## SEPARATED FROM `weights_at` SO IT CAN BE DRIVEN DIRECTLY. The property that
## matters -- that these sum to exactly 1 and that each is exactly 0 outside
## its band -- is a fact about the arithmetic, and asserting it through a world
## position would test it only at whatever slopes the basin happens to have.
## Every boundary is exercised by sweeping this instead.
##
## TELESCOPING, SO THE SUM IS 1 BY CONSTRUCTION AND NOT BY NORMALISING.
## `(1-S1) + (S1-S2) + (S2-S3) + S3` cancels to 1 for any S at all, so the
## partition survives a change to the ramp shape, a change to the centres, and
## a calibration that moves both.
func slope_weights(deg: float) -> Dictionary:
    var c: Dictionary = rows.get("classifier", {})
    var half := 0.5 * maxf(0.0, float(c.get("blend_deg", 0.0)))
    var s1 := _ramp(deg, float(c.get("playa_below_slope_deg", 0.6)), half)
    var s2 := _ramp(deg, float(c.get("floor_below_slope_deg", 4.0)), half)
    var s3 := _ramp(deg, float(c.get("slope_below_slope_deg", 22.0)), half)
    return {"playa": 1.0 - s1, "floor": s1 - s2, "slope": s2 - s3, "talus": s3}


## A smoothstep from 0 to 1 across `centre +/- half`. C1 at both ends, which is
## what makes the blended field C1 where 985 requires it: the product rule
## needs the weight's derivative to exist, and a linear ramp's does not at its
## corners.
static func _ramp(x: float, centre: float, half: float) -> float:
    if half <= 0.0:
        return 0.0 if x < centre else 1.0
    var t: float = clampf((x - (centre - half)) / (2.0 * half), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


## The detail term. Exactly zero at every parent lattice node.
##
## NAMING A LANDFORM ASKS FOR THAT STRATUM ALONE, which is the CALIBRATION
## path: `tools/measure_variogram.gd` scores each stratum against its own row,
## and 986 grades `S_q(l)` per stratum. Asking without one gets the blended
## field, which is what a body stands on.
##
## THE BLEND CANNOT BREAK THE EXACTNESS, and that is not luck. Every stratum's
## term is identically zero at a parent node, so any weighted sum of them is
## zero there too -- for any weights at all, including ones nobody has
## calibrated yet. The one guard the whole method rests on is indifferent to
## what conditions the amplitude.
func detail_at(w: Vector2, landform: String = "") -> float:
    if not is_loaded():
        return 0.0
    if landform != "":
        return _stratum_detail(w, landform)
    var total := 0.0
    var weights := weights_at(w)
    for name in weights:
        total += float(weights[name]) * _stratum_detail(w, str(name))
    return total


## One stratum's own detail term, at its own amplitude.
func _stratum_detail(w: Vector2, landform: String) -> float:
    var p := row(landform)
    if p.is_empty():
        return 0.0
    var amp := amplitude_for(landform) * taper_at(w)
    if amp <= 0.0:
        return 0.0
    # f(x) minus its own coarse component. See the header: this is what makes
    # the sum exact at every parent sample.
    return amp * (_noise(w, p) - _coarse_component(w, p))


## `f` sampled on the parent lattice and interpolated back with the same
## Catmull-Rom the heightfield uses. Interpolating, so it equals `f` at nodes.
func _coarse_component(w: Vector2, p: Dictionary) -> float:
    var t := parent_coord(w)
    # THE NODE CASE IS TAKEN DIRECTLY, AND THE TEST FOR IT IS AN EXACT
    # COMPARISON OF POSITIONS, not a tolerance on the cell coordinate.
    #
    # The method is exact in exact arithmetic: at a node the interpolant
    # returns the sample it interpolates. What is not exact is the coordinate.
    # A world position here arrives in a `Vector2`, which is SINGLE precision,
    # and this basin's eastings pass 1.3 million metres -- where a float32 step
    # is 0.125 m. So a "point" is a box an eighth of a metre across, and the
    # cell coordinate of a node comes out 6.1e-5 cells away from an integer
    # rather than 1e-13. A first attempt used an epsilon of a billionth of a
    # cell and never fired; the detail measured 2e-5 m on the lattice, which
    # is nothing to look at and is not zero, and "exactly" is the whole of the
    # constraint.
    #
    # An epsilon large enough to cover the quantisation would be a 0.06 m flat
    # spot around every node. Comparing the POSITIONS instead has neither
    # problem: a consumer computes node positions the same way this does and
    # gets the identical float32, and there is no representable point strictly
    # between a node and half an ulp of it to flatten.
    var nx: int = int(round(t.x))
    var ny: int = int(round(t.y))
    if parent_node(nx, ny) == w:
        return _noise(w, p)
    var x0 := int(floor(t.x))
    var y0 := int(floor(t.y))
    var tx := t.x - float(x0)
    var ty := t.y - float(y0)
    var name := str(p.get("_name", ""))
    var entry: Array = _stencil.get(name, [])
    var stencil := PackedFloat64Array()
    if entry.size() == 3 and int(entry[0]) == x0 and int(entry[1]) == y0:
        stencil = entry[2]
    else:
        stencil.resize(16)
        for j in 4:
            for i in 4:
                stencil[j * 4 + i] = _noise(parent_node(x0 - 1 + i, y0 - 1 + j), p)
        _stencil[name] = [x0, y0, stencil]
    var rows_v := PackedFloat64Array()
    rows_v.resize(4)
    for j in 4:
        rows_v[j] = Heightfield.catmull(stencil[j * 4], stencil[j * 4 + 1],
                stencil[j * 4 + 2], stencil[j * 4 + 3], tx)
    return Heightfield.catmull(rows_v[0], rows_v[1], rows_v[2], rows_v[3], ty)


## THE PARENT LATTICE, NAMED SEPARATELY FROM THE HEIGHTFIELD'S TEXEL GRID.
##
## They coincide today -- the parent is the shipped overview -- and they will
## not once the pyramid's 100 m level is what gets refined. Exactness is
## defined against the grid being refined, so it has to be the grid this
## arithmetic uses, and reading it off `world_to_texel` would have tied it to
## whichever raster happened to be loaded.
func parent_coord(w: Vector2) -> Vector2:
    return Vector2((w.x - _hf.origin_x) / parent_spacing_m - 0.5,
                   (_hf.origin_y - w.y) / parent_spacing_m - 0.5)


func parent_node(ix: int, iy: int) -> Vector2:
    return Vector2(_hf.origin_x + (float(ix) + 0.5) * parent_spacing_m,
                   _hf.origin_y - (float(iy) + 0.5) * parent_spacing_m)


## Fractional Brownian motion over gradient noise, band-limited between the
## parent spacing and the finest octave this landform declares.
##
## ANISOTROPY IS A COORDINATE SCALE, applied before sampling: a hillside's
## roughness is lineated downslope and an isotropic field is visibly not a
## hillside. The ratio is a fake row; the mechanism is not.
func _noise(w: Vector2, p: Dictionary) -> float:
    var octaves := octaves_for(str(p.get("_name", "")))
    if octaves <= 1 and p.has("finest_wavelength_m"):
        octaves = clampi(int(ceil(log(parent_spacing_m
                / float(p["finest_wavelength_m"])) / log(2.0))), 1, MAX_OCTAVES)
    var slope := float(p.get("spectral_slope", 1.0))
    var ratio := maxf(0.05, float(p.get("anisotropy", 1.0)))
    var theta := deg_to_rad(float(p.get("orientation_deg", 0.0)))
    var c := cos(theta)
    var s := sin(theta)
    var along := (w.x * c + w.y * s) / ratio
    var across := -w.x * s + w.y * c
    var q := Vector2(along, across)

    var total := 0.0
    var norm := 0.0
    var wavelength := parent_spacing_m
    var amp := 1.0
    for _o in octaves:
        wavelength *= 0.5
        amp *= pow(0.5, slope)
        total += amp * _gradient_noise(q / wavelength)
        norm += amp * amp
    return 0.0 if norm <= 0.0 else total / sqrt(norm)


## WHICH WAY THE ANISOTROPY POINTS, AND WHY IT IS NOT LOCAL YET.
##
## The sketch asks for the orientation to follow local aspect or drainage, and
## the obvious implementation -- rotate the world coordinate by the local
## aspect angle before sampling the noise -- IS WRONG, MEASURABLY. The rotation
## is about the coordinate origin and this basin sits about two million metres
## from it, so a change of one microradian in the local aspect moves the sample
## point by two metres. Aspect changes far more than that between neighbouring
## points, so the field decorrelates completely at every lag: measured, the
## variogram came out FLAT from one metre to sixty-four, which is a
## white-noise field wearing a spectrum's parameters.
##
## Anchoring the rotation at the nearest parent node bounds the offset but
## moves the problem to the anchor, which jumps at half-cell boundaries and
## seams the pattern by up to several hundred metres of noise offset.
##
## So stage 0 orients each class by a CONSTANT angle from its row. The
## anisotropy mechanism is real and calibratable; the orientation SOURCE is
## not implemented, and is recorded here rather than implied by a field name
## that suggests it. A correct local version warps the offset inside a noise
## cell rather than the world coordinate, which is a change to the gradient
## evaluation and wants the calibration data before it is designed.
func orientation_note() -> String:
    return ("anisotropy is oriented by a constant angle per landform row. Orientation by local "
            + "aspect or drainage is NOT implemented: rotating a world coordinate about an "
            + "origin two million metres away turns a microradian of aspect change into two "
            + "metres of sample offset, which measured as a flat variogram at every lag.")


## Gradient noise on the unit lattice: hashed gradients at the corners, dotted
## with the offset, blended with a quintic fade. Zero mean, band-limited to one
## lattice spacing, and a pure function of position.
func _gradient_noise(q: Vector2) -> float:
    var x0 := int(floor(q.x))
    var y0 := int(floor(q.y))
    var fx := q.x - float(x0)
    var fy := q.y - float(y0)
    var ux := _fade(fx)
    var uy := _fade(fy)
    var n00 := _dot_grad(x0, y0, fx, fy)
    var n10 := _dot_grad(x0 + 1, y0, fx - 1.0, fy)
    var n01 := _dot_grad(x0, y0 + 1, fx, fy - 1.0)
    var n11 := _dot_grad(x0 + 1, y0 + 1, fx - 1.0, fy - 1.0)
    return lerpf(lerpf(n00, n10, ux), lerpf(n01, n11, ux), uy)


static func _fade(t: float) -> float:
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _dot_grad(ix: int, iy: int, dx: float, dy: float) -> float:
    var a := TAU * StableHash.unit(StableHash.of3(ix, iy, 0x9e37))
    return cos(a) * dx + sin(a) * dy


## WHICH LANDFORM STRATUM A POINT IS MOST OF -- FOR CALIBRATION AND REPORTING,
## AND NOT FOR CONDITIONING THE AMPLITUDE.
##
## DECISION 985 RETIRED THIS METHOD'S OLD JOB. It used to pick the class whose
## row the detail term was evaluated at, which put an amplitude step on every
## class boundary -- a rendered seam on a line no landform owns. `weights_at`
## does that now, continuously. What a hard answer is still the right tool for
## is stratifying a MEASUREMENT: 986 grades `S_q(l)` per landform stratum, and
## a measurement has to know which stratum a sample belongs to.
##
## SO IT RETURNS THE HEAVIEST WEIGHT rather than re-deriving a decision from
## the thresholds. Two implementations of "which class is this" would be two
## things to keep in step, and the one that decided nothing at runtime would be
## the one nobody noticed drifting.
##
## FROM THE DERIVED LAYERS WHERE THIS CLONE HAS THEM, and from the parent
## lattice's own gradient where it does not. The rows' `_FAKE` note used to
## read "when those arrive this classifier reads them"; they have arrived, and
## this is that.
##
## THE MARGIN CLASS WAS UNREACHABLE UNTIL NOW, which is the substantive change
## rather than the better slope. `riparian_margin` has been a row since stage 0
## -- with the note that it is the row whose amplitude matters most and is
## least free, because a shoreline converts vertical error to horizontal at
## 1/slope -- and nothing could ever return it, since the only field available
## was slope re-derived from a kilometre lattice. Distance-to-channel is what
## it was waiting for.
##
## IT IS TESTED FIRST, and that is a decision rather than an ordering
## accident: a margin on a 3-degree slope is a margin, and asking about slope
## first would file it as `floor` and never reach the question. The thresholds
## are still fake rows and still say so.
func classify(w: Vector2) -> String:
    var best := ""
    var best_w := -1.0
    var weights := weights_at(w)
    for name in weights:
        var v := float(weights[name])
        if v > best_w:
            best_w = v
            best = str(name)
    return best if best != "" else "floor"


## SLOPE IN DEGREES, from the layer where there is one.
##
## THE FALLBACK IS NOT THE SAME QUANTITY AND IT IS NOT PRETENDING TO BE. A
## central difference over the parent lattice is the slope of a kilometre of
## averaged ground; the layer is slope computed on the source DEM and
## reprojected. They agree in character and not in value, which is why
## `classifier_source` exists and why a measurement that quotes a class
## distribution has to say which one produced it.
func slope_degrees_at(w: Vector2) -> float:
    if _layers != null:
        var v := _layers.slope_degrees_at(w.x, w.y, _layer_z)
        # SLOPE'S MASK IS NARROWER THAN THE DEM'S BY A ONE-PIXEL RIM -- a
        # gradient needs neighbours -- so a NAN here over drawn ground is
        # expected on 0.19% of it and falls through to the lattice rather than
        # classifying it `floor` by default.
        if not is_nan(v):
            return v
    return lattice_slope_degrees_at(w)


func lattice_slope_degrees_at(w: Vector2) -> float:
    var d := _hf.pixel_size_m
    var hx := _hf.height_at_world(w.x + d, w.y) - _hf.height_at_world(w.x - d, w.y)
    var hy := _hf.height_at_world(w.x, w.y + d) - _hf.height_at_world(w.x, w.y - d)
    if is_nan(hx) or is_nan(hy):
        return NAN
    return rad_to_deg(atan(Vector2(hx, hy).length() / (2.0 * d)))


## HORIZONTAL DISTANCE TO THE NEAREST ORDER-4 FLOWLINE, metres. NAN without
## the layers -- there is nothing to re-derive it from, and a client that
## guessed would be inventing a channel network.
##
## READ AT THE FINEST LEVEL ALWAYS, AND NOT AT THE PARENT'S. This is the one
## place the "sample a quantity at the scale you are using it" rule inverts,
## and it took a failing test to see it.
##
## A SLOPE AVERAGES AND A DISTANCE DOES NOT. The slope of a kilometre of ground
## is a real quantity and it is the one a kilometre parent is refining. The
## mean of a distance transform over a kilometre is not the distance of
## anything, because a distance transform has no value over an area -- only at
## a point.
##
## MEASURED, on 3,330 points of real basin at the rows' own 150 m threshold:
## the fine level finds 49 margins and the 800 m level finds 8, and 2 of those
## 8 are places the fine field says are kilometres from a channel. So a coarse
## read is wrong in BOTH directions at once -- it erases six margins in seven
## and invents a couple that were never there -- and it is not a blurred
## version of the fine field but a different one. The margin is the row whose
## amplitude matters most, because a shoreline converts vertical error to
## horizontal at 1/slope.
func distance_to_channel_m(w: Vector2) -> float:
    return NAN if _layers == null else _layers.distance_to_channel_m(w.x, w.y, 0)


## HOW FAR THE AMPLITUDE IS TAPERED HERE, 0 to 1.
##
## The mechanism is §2b's and it is the lead one for the water margin:
## roughness is suppressed near channels and on floodplains -- depositional and
## genuinely smooth -- and full strength upslope, because at a shoreline a
## vertical error becomes a horizontal one at gain 1/slope and half a metre on
## a 2% slope moves the waterline twenty-five metres.
##
## NO HAND RASTER IS VENDORED, so this returns 1.0 everywhere and `taper_source`
## says why. Wired rather than waited for: a mechanism with nowhere to plug in
## is one that gets rebuilt when the data lands.
func taper_at(_w: Vector2) -> float:
    return 1.0


func taper_source() -> String:
    if _layers == null:
        return ("no HAND raster and no derived layers, so the taper is 1.0 everywhere.")
    return ("distance-to-channel is vendored and HAND is not, so the taper is still 1.0. They "
            + "are not substitutes: one is horizontal distance to a channel and the other is "
            + "height above it, and it is the height that says whether ground is depositional. "
            + "Decision 985 conditions amplitude continuously on HAND and slope, which "
            + "supersedes the per-class selection this taper was drafted beside, so the "
            + "mechanism is 985's to build and not this method's to guess at. The distance "
            + "layer is in use -- it is what makes `riparian_margin` reachable in `classify`.")
