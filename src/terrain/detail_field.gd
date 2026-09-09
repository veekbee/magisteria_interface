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
                      spacing_m: float = 0.0) -> DetailField:
    var df := DetailField.new()
    df._hf = hf
    df.parent_spacing_m = spacing_m if spacing_m > 0.0 else hf.pixel_size_m
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
    df.calibrated_at_parent_m = calibrated_at_parent_m
    df.calibration_note = calibration_note
    df.why_absent = why_absent
    df.parent_spacing_m = spacing_m
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


## The detail term alone. Exactly zero at every parent lattice node.
func detail_at(w: Vector2, landform: String = "") -> float:
    if not is_loaded():
        return 0.0
    var name := landform if landform != "" else classify(w)
    var p := row(name)
    if p.is_empty():
        return 0.0
    var amp := amplitude_for(name) * taper_at(w)
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


## WHICH LANDFORM CLASS A POINT IS IN.
##
## From the parent lattice's own slope today, because the pipeline's derived
## layers -- slope, aspect and distance-to-channel at 100 m, which exist
## sim-side -- are not vendored here. When they are, this reads them instead of
## re-deriving one of them and guessing at the other two. The thresholds are
## fake rows and say so.
func classify(w: Vector2) -> String:
    var c: Dictionary = rows.get("classifier", {})
    var deg := slope_degrees_at(w)
    if is_nan(deg):
        return "floor"
    if deg < float(c.get("playa_below_slope_deg", 0.6)):
        return "playa"
    if deg < float(c.get("floor_below_slope_deg", 4.0)):
        return "floor"
    if deg < float(c.get("slope_below_slope_deg", 22.0)):
        return "slope"
    return "talus"


func slope_degrees_at(w: Vector2) -> float:
    var d := _hf.pixel_size_m
    var hx := _hf.height_at_world(w.x + d, w.y) - _hf.height_at_world(w.x - d, w.y)
    var hy := _hf.height_at_world(w.x, w.y + d) - _hf.height_at_world(w.x, w.y - d)
    if is_nan(hx) or is_nan(hy):
        return NAN
    return rad_to_deg(atan(Vector2(hx, hy).length() / (2.0 * d)))


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
    return ("no HAND raster is vendored, so the taper is 1.0 everywhere. The pipeline derives "
            + "distance-to-channel at 100 m sim-side, which is the horizontal sibling of what "
            + "this wants.")
