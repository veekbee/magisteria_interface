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

## Salts, so that three uses of one mixer cannot collide. Published like
## everything else `d` reads, and named rather than spelled at the call site.
const SALT_GRADIENT := 0x67726164        ## "grad"
const SALT_RESIDUAL := 0x72657364        ## "resd"

## The sample set `residual_rms` is measured over -- a PURE FUNCTION OF THE
## SEED AND THE LATTICE, so it is reproducible in any language rather than a
## number someone measured once. The offsets come from the mixer and not from a
## regular sub-grid, because a regular sampling coarser than the finest octave
## reports its own step rather than the field's, which is the sampling mistake
## this repo has now made in three different places.
## How many parent cells' stencils are remembered per landform. Sized so that
## a window of a few thousand metres at either parent this client refines fits
## whole, which is what turns a random-sampling instrument's miss rate from
## nearly one into nearly zero.
const STENCIL_CELLS := 512

const RESIDUAL_SAMPLES := 4096
const RESIDUAL_BLOCK_CELLS := 16

## The order the strata are summed in. FIXED, and not a dictionary's iteration
## order: floating-point addition is not associative, and the conformance
## tolerance is 1e-15 m, which is inside the range a reordering moves.
const STRATA_ORDER := ["playa", "floor", "slope", "talus", "riparian_margin"]

## WHICH PRECISION THE POSITION ARRIVED IN. The arithmetic below is float64
## either way; what this decides is the ONE comparison that has to be done in
## the caller's own precision -- whether a position is exactly a parent node.
## A `Vector2` carries float32, and the float32 rounding of a node is not the
## node, so a float64 comparison against a float32 carrier's position never
## fires and the exactness silently stops holding for the renderer.
enum { CARRIER_F32, CARRIER_F64 }

var rows: Dictionary = {}
## Where the rows came from. Part of what makes two fields the SAME FUNCTION --
## see `same_function_as`, and the guard that needed it.
var rows_path: String = ""
var why_absent: String = ""

## Metres between parent lattice samples. The detail is exactly zero on this
## grid and everything below it is synthesised.
var parent_spacing_m: float = 0.0

## THE PARENT LATTICE'S CORNER, AS A FIELD AND NOT A READ THROUGH THE RASTER.
##
## This file has always said the parent lattice is named separately from the
## heightfield's texel grid, because exactness is defined against the grid
## BEING REFINED and reading it off whichever raster happened to be loaded
## would tie it to the wrong thing. The prose said it; the arithmetic still
## reached through `_hf`. It is a field now, defaulted from the heightfield,
## and that completes a separation the file already claimed.
##
## AND IT IS THE ONE NUMBER THE CLIENT CANNOT GET RIGHT FROM A DECIMAL. The
## export carries the corner as `-1809292.9365744274`; Godot's string-to-double
## returns the double 2.22e-10 m from that value where the correctly rounded
## one is 1.10e-11 m away -- the FARTHER of the two neighbours, a full ulp out.
## At a float32 render that is nine orders below the position quantum and
## cannot matter. In float64 it moves every parent node by an ulp, so the exact
## node test misses and property 2 -- the one property stated as exact rather
## than within tolerance -- fails against a reference that read the same
## decimal correctly. Hence the setter: a caller holding the corner's BITS can
## put them here, which is the same rule the conformance vectors already apply
## to every other position they carry.
var parent_origin_x: float = 0.0
var parent_origin_y: float = 0.0

## THE PUBLISHED WORLD SEED, and the name it is derived from. 985 names a world
## seed among `d`'s three inputs; a hex literal in a source file is not one,
## because a seed exists so that a world can be RE-SEEDED and naming a second
## world should be a legible act with a reproducible consequence. The rows
## carry the name and the seed, and `StableHash.of_name` is the derivation.
var world_name: String = ""
var world_seed: int = 0

## `rms(f - P[f])` per landform at THIS field's parent spacing. Read from the
## rows where they publish it for this lattice, computed where they do not --
## see `residual_rms_for`, which is also where the one gap in the artefact is
## recorded.
var _residual: Dictionary = {}

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
    df.parent_origin_x = hf.origin_x
    df.parent_origin_y = hf.origin_y
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
    # THE SEED IS REQUIRED AND ITS ABSENCE IS A REFUSAL, not a default. A rows
    # file with no `world_seed` describes a world that cannot be re-seeded,
    # which is not the function 985 rules; and defaulting to a constant here
    # would make every clone agree with itself and with nothing else.
    df.world_name = str(df.rows.get("world_name", ""))
    if not df.rows.has("world_seed"):
        df.why_absent = (("%s declares no `world_seed`. " % path)
                + "985 names a published world seed among `d`'s three inputs, and these rows "
                + "name none, so there is no function to evaluate rather than a slightly "
                + "different one.")
        return df
    df.world_seed = int(df.rows["world_seed"])
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
    df.world_name = world_name
    df.world_seed = world_seed
    df.parent_origin_x = parent_origin_x
    df.parent_origin_y = parent_origin_y
    # THE RESIDUAL IS NOT CARRIED ACROSS. `rms(f - P[f])` is a property of the
    # row, the seed AND THE LATTICE -- a different parent is a different octave
    # ladder and a different subtraction -- so copying it here would apply one
    # lattice's normalisation to another's surface, which is the shape of the
    # defect this constant was published to remove.
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
            and world_seed == other.world_seed
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
    return ("slope at z=%d (%s m), the level nearest this parent spacing, and HAND at z=0 -- "
            % [_layer_z, String.num(_layers.pixel_size_of(TerrainLayers.SLOPE, _layer_z), 0)]
            + "the two inputs decision 985 names. Both from assets/terrain/layers/. A slope "
            + "averages and is read at the scale it is used at; HAND is a height above a "
            + "specific feature and is read at the finest level, for the same reason a "
            + "distance transform is.")


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
    return weights_for(slope_degrees_at(w), hand_m(w))


## THE SAME MIXTURE, WITH ITS TWO CONDITIONS GIVEN RATHER THAN SAMPLED.
##
## Separated from the position for the reason `slope_weights` was: the property
## that matters is a fact about the arithmetic, and driving it through a world
## position tests it only at whatever slopes and heights the basin happens to
## have. It is also the shape the published function takes -- slope and HAND
## are arguments to `d`, and which raster they were read from, at which level,
## is the caller's question and has its own answer.
func weights_for(slope_deg: float, hand: float) -> Dictionary:
    var c: Dictionary = rows.get("classifier", {})
    if is_nan(slope_deg):
        # No slope anywhere -- the layer has a hole and the lattice could not
        # answer either. One stratum at full weight, the same answer the hard
        # classifier gave, because there is nothing here to blend BETWEEN.
        return {"floor": 1.0}
    var chain := slope_weights(slope_deg)

    # THE MARGIN RIDES HAND, NOT DISTANCE. 985 conditions on HAND and slope,
    # and those are the two inputs here. It is also the better field for this
    # class on its own merits: a wide flat floodplain stays low above its
    # drainage for kilometres, and that depositional ground is exactly what the
    # margin row describes, while a horizontal distance would have cut it off
    # at a fixed radius that no floodplain has.
    #
    # NAN IS NO MARGIN AND NOT THE MAXIMUM. Absent HAND means the cell is
    # outside the basin or a filled descent reaches no channel -- endorheic and
    # edge-draining ground, 6.3 million pixels. Undrained upland is not a
    # floodplain.
    var r := 0.0
    if not is_nan(hand):
        var below := float(c.get("riparian_below_hand_m", 10.0))
        var mhalf := 0.5 * maxf(0.0, float(c.get("riparian_blend_hand_m", 0.0)))
        r = 1.0 - _ramp(hand, below, mhalf)

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
    # THE CARRIER IS CONCEDED HERE AND NOWHERE ELSE. A `Vector2` is single
    # precision and this basin's eastings pass 1.3 million metres, where a
    # float32 step is 0.125 m on one axis and 0.25 m on the other -- coarser
    # than the finest wavelength the function synthesises. That costs almost
    # nothing on this ladder (the finest octaves carry under a thousandth of
    # the variance) and the rendering is not re-plumbed for it. What it does
    # cost is the GRADING, which happens below a metre, so the conformance path
    # takes float64 and this one says out loud that it does not.
    return detail_at64(float(w.x), float(w.y), slope_degrees_at(w), hand_m(w),
            landform, CARRIER_F32)


## `d(x, y)` AT FULL PRECISION, WITH ITS CONDITIONING GIVEN RATHER THAN SAMPLED.
##
## This is the published function's own signature: position, slope, HAND. The
## conditioning fields are arguments and not raster reads, which is what keeps
## `d` pure, keeps the conformance vectors self-contained, and keeps "do two
## implementations sample the same layers the same way" a separate question
## from "do two implementations of `d` agree".
func detail_at64(x: float, y: float, slope_deg: float, hand: float,
                 landform: String = "", carrier: int = CARRIER_F64) -> float:
    if not is_loaded():
        return 0.0
    if landform != "":
        return _stratum_detail64(x, y, landform, hand, carrier)
    var weights := weights_for(slope_deg, hand)
    var total := 0.0
    # IN A FIXED ORDER. A zero-weight stratum is skipped rather than added as
    # `0.0 * d`, which is the same float64 either way and one noise field
    # cheaper -- the strata have compact support, so most positions are one
    # stratum and no position is more than two.
    for name in STRATA_ORDER:
        if not weights.has(name):
            continue
        var wgt := float(weights[name])
        if wgt == 0.0:
            continue
        total += wgt * _stratum_detail64(x, y, str(name), hand, carrier)
    return total


## One stratum's own detail term, at its own amplitude.
##
## THE AMPLITUDE IS DIVIDED BY THE RESIDUAL, and that division is the fix for a
## defect that would have been invisible in both implementations at once. The
## rows' units block has always read "standard deviation of the detail term" --
## the sd of what the function ADDS. `f` is normalised to unit variance and
## then `P[f]` is subtracted from it, so what lands is `A * rms(f - P[f])`,
## which is 3.5x to 4.4x short of `A` on these rows. Decision 986's bands are
## measured from the residual on real ground, so grading the under-delivered
## surface against them would have failed for a reason nobody could see: two
## conforming implementations computing the same wrong number and agreeing
## perfectly.
func _stratum_detail64(x: float, y: float, landform: String, hand: float,
                       carrier: int) -> float:
    var p := row(landform)
    if p.is_empty():
        return 0.0
    var rms := residual_rms_for(landform)
    if rms <= 0.0:
        return 0.0
    var amp := amplitude_for(landform) / rms
    return amp * taper_for(hand) * (_noise64(x, y, p) - _coarse_component64(x, y, p, carrier))


## `rms(f - P[f])` for one row on THIS field's parent lattice.
##
## A PURE FUNCTION OF THE ROW, THE LATTICE AND THE SEED, published beside the
## rows so that no consumer estimates it. It is read where the artefact carries
## it for the parent being refined, and computed by the artefact's own recipe
## where it does not -- which is reproduction rather than estimation, because
## the sample set is itself a published function of the seed.
##
## AND THE LATTICE IS PART OF IT, WHICH IS EASY TO MISS. The first cut of this
## artefact published one number per row, for the 100 m parent the near-field
## patches refine. The far field refines the 1 km overview, where the ladder is
## twelve rungs instead of nine and the subtraction removes a different band.
## Measured here at -6.2% to +3.8% across the rows, and independently at
## -5.1% to +6.6% on the producing side: small, silent, and the same class of
## error the constant was published to remove. The rows now carry the number
## at every spacing anyone refines, and the computed path below stays as the
## fallback it was written to be.
func residual_rms_for(landform: String) -> float:
    if _residual.has(landform):
        return float(_residual[landform])
    var p := row(landform)
    var v := NAN
    # BY SPACING AND NOT BY PYRAMID LEVEL. Which parents get refined is a fact
    # about consumers, not about the pyramid, and a level nobody refines needs
    # no normalisation published. The keys are compared as numbers rather than
    # as strings so that "100" and "100.0" are the same lattice.
    for key in (p.get("residual_rms_by_parent_m", {}) as Dictionary):
        if is_equal_approx(float(str(key)), parent_spacing_m):
            v = float((p["residual_rms_by_parent_m"] as Dictionary)[key])
            break
    if is_nan(v):
        # The scalar is the SHIPPED parent's value, so it is only read when it
        # is that parent -- never as a default for an unlisted one.
        var at := float((rows.get("parent", {}) as Dictionary).get("spacing_m", 0.0))
        var scalar := float(p.get("residual_rms", 0.0))
        if scalar > 0.0 and at > 0.0 and is_equal_approx(at, parent_spacing_m):
            v = scalar
    if is_nan(v) or v <= 0.0:
        v = compute_residual_rms(landform)
    _residual[landform] = v
    return v


## Which of the two the number came from, for a report that has to say whether
## a constant was read or reproduced.
func residual_source(landform: String) -> String:
    var p := row(landform)
    for key in (p.get("residual_rms_by_parent_m", {}) as Dictionary):
        if is_equal_approx(float(str(key)), parent_spacing_m):
            return "published at %s m" % String.num(parent_spacing_m, 0)
    var at := float((rows.get("parent", {}) as Dictionary).get("spacing_m", 0.0))
    if float(p.get("residual_rms", 0.0)) > 0.0 and is_equal_approx(at, parent_spacing_m):
        return "published, the artefact's own parent"
    return ("recomputed by the published recipe: the rows carry no residual for a %s m parent"
            % String.num(parent_spacing_m, 0))


## The published recipe, evaluated. Four thousand positions drawn from the
## mixer over a sixteen-cell block at the lattice origin, and the RMS of the
## residual over them.
func compute_residual_rms(landform: String) -> float:
    var p := row(landform)
    if p.is_empty() or parent_spacing_m <= 0.0:
        return 0.0
    var span := float(RESIDUAL_BLOCK_CELLS) * parent_spacing_m
    var acc := 0.0
    for k in RESIDUAL_SAMPLES:
        var u := StableHash.unit(StableHash.over([world_seed, SALT_RESIDUAL, 0, k]))
        var v := StableHash.unit(StableHash.over([world_seed, SALT_RESIDUAL, 1, k]))
        var px := parent_origin_x + u * span
        var py := parent_origin_y - v * span
        var r := _noise64(px, py, p) - _coarse_component64(px, py, p, CARRIER_F64)
        acc += r * r
    return sqrt(acc / float(RESIDUAL_SAMPLES))


## `f` sampled on the parent lattice and interpolated back with the same
## Catmull-Rom the heightfield uses. Interpolating, so it equals `f` at nodes.
func _coarse_component64(x: float, y: float, p: Dictionary, carrier: int) -> float:
    var tx_c := (x - parent_origin_x) / parent_spacing_m - 0.5
    var ty_c := (parent_origin_y - y) / parent_spacing_m - 0.5
    # THE NODE CASE IS TAKEN DIRECTLY, AND THE TEST FOR IT IS AN EXACT
    # COMPARISON OF POSITIONS, not a tolerance on the cell coordinate.
    #
    # The method is exact in exact arithmetic; the coordinate is not. A
    # division and a subtraction put a node's cell coordinate a few ulp off an
    # integer, and an epsilon large enough to cover that would be a flat spot
    # around every node -- measured at 0.06 m across, on a surface whose whole
    # claim is that it is ZERO there and not merely small.
    #
    # AND THE COMPARISON IS DONE IN THE CALLER'S PRECISION. A consumer that
    # built this position through a `Vector2` holds the float32 rounding of a
    # node, which is not the node; comparing that against the float64 node
    # never fires, and the exactness would hold for the conformance vectors and
    # quietly stop holding for everything that draws.
    var nx := int(round(tx_c))
    var ny := int(round(ty_c))
    var wx := parent_origin_x + (float(nx) + 0.5) * parent_spacing_m
    var wy := parent_origin_y - (float(ny) + 0.5) * parent_spacing_m
    var on_node := (wx == x and wy == y) if carrier == CARRIER_F64 \
            else Vector2(wx, wy) == Vector2(x, y)
    if on_node:
        return _noise64(x, y, p)

    var x0 := int(floor(tx_c))
    var y0 := int(floor(ty_c))
    var tx := tx_c - float(x0)
    var ty := ty_c - float(y0)
    var name := str(p.get("_name", ""))
    # MANY CELLS AND NOT ONE. This was one cell deep per landform, which is the
    # right shape when consecutive samples walk the ground -- a row of mesh
    # vertices, a plant and its neighbour -- and the wrong one the moment
    # anything samples at random. Decision 986's structure function does
    # exactly that: it draws pairs from all over a window to estimate a
    # quantile, so a one-deep cache missed on nearly every call and paid all
    # sixteen noise evaluations each time. Measured on the gate's own sweep
    # over five strata and seven lags: 37 s at one cell, 2 s at this size --
    # about eighteenfold, and it moves no value, which the placement digest
    # and the conformance vectors both confirm.
    #
    # CLEARED WHOLE WHEN IT FILLS, rather than evicted least-recently-used.
    # The bookkeeping an LRU needs costs more per hit than the misses it saves
    # at this size, and the cache is a memo rather than a budget: dropping all
    # of it is correct, just occasionally wasteful.
    var cells: Dictionary = _stencil.get(name, {})
    var key := Vector2i(x0, y0)
    var stencil: PackedFloat64Array = cells.get(key, PackedFloat64Array())
    if stencil.size() != 16:
        stencil = PackedFloat64Array()
        stencil.resize(16)
        for j in 4:
            for i in 4:
                # THE STENCIL NODES ARE BUILT IN float64. They used to come
                # through `parent_node`, which returns a `Vector2`, so the
                # sixteen samples `P[f]` is built from were taken up to an
                # eighth of a metre away from the nodes they were supposed to
                # be at. The node case short-circuits, so exactness survived
                # and nothing failed; what moved was every off-node value.
                stencil[j * 4 + i] = _noise64(
                        parent_origin_x + (float(x0 - 1 + i) + 0.5) * parent_spacing_m,
                        parent_origin_y - (float(y0 - 1 + j) + 0.5) * parent_spacing_m, p)
        if cells.size() >= STENCIL_CELLS:
            cells.clear()
        cells[key] = stencil
        _stencil[name] = cells
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
    return Vector2((w.x - parent_origin_x) / parent_spacing_m - 0.5,
                   (parent_origin_y - w.y) / parent_spacing_m - 0.5)


func parent_node(ix: int, iy: int) -> Vector2:
    return Vector2(parent_origin_x + (float(ix) + 0.5) * parent_spacing_m,
                   parent_origin_y - (float(iy) + 0.5) * parent_spacing_m)


## The same node, at the precision the lattice is actually defined in. The
## `Vector2` form above is what a renderer compares against; this is what the
## arithmetic uses and what a conformance vector is written in.
func parent_node_x(ix: int) -> float:
    return parent_origin_x + (float(ix) + 0.5) * parent_spacing_m


func parent_node_y(iy: int) -> float:
    return parent_origin_y - (float(iy) + 0.5) * parent_spacing_m


## Fractional Brownian motion over gradient noise, band-limited between the
## parent spacing and the finest octave this landform declares.
##
## ANISOTROPY IS A COORDINATE SCALE, applied before sampling: a hillside's
## roughness is lineated downslope and an isotropic field is visibly not a
## hillside. The ratio is a fake row; the mechanism is not.
func _noise64(x: float, y: float, p: Dictionary) -> float:
    var octaves := octaves_for(str(p.get("_name", "")))
    var slope := float(p.get("spectral_slope", 1.0))
    var ratio := maxf(0.05, float(p.get("anisotropy", 1.0)))
    var theta := deg_to_rad(float(p.get("orientation_deg", 0.0)))
    var c := cos(theta)
    var s := sin(theta)
    var along := (x * c + y * s) / ratio
    var across := -x * s + y * c

    var total := 0.0
    var norm := 0.0
    var wavelength := parent_spacing_m
    var amp := 1.0
    # THE LADDER STARTS AT HALF THE PARENT SPACING, which is property 3 before
    # the subtraction has done anything: `d` may only carry what the parent
    # cannot, and the parent carries everything at and above its own spacing.
    for o in octaves:
        wavelength *= 0.5
        amp *= pow(0.5, slope)
        total += amp * _gradient_noise(along / wavelength, across / wavelength, o)
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
func _gradient_noise(qx: float, qy: float, octave: int) -> float:
    var x0 := int(floor(qx))
    var y0 := int(floor(qy))
    var fx := qx - float(x0)
    var fy := qy - float(y0)
    var ux := _fade(fx)
    var uy := _fade(fy)
    var n00 := _dot_grad(x0, y0, octave, fx, fy)
    var n10 := _dot_grad(x0 + 1, y0, octave, fx - 1.0, fy)
    var n01 := _dot_grad(x0, y0 + 1, octave, fx, fy - 1.0)
    var n11 := _dot_grad(x0 + 1, y0 + 1, octave, fx - 1.0, fy - 1.0)
    return lerpf(lerpf(n00, n10, ux), lerpf(n01, n11, ux), uy)


static func _fade(t: float) -> float:
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## A hashed unit gradient at a lattice node, dotted with the offset.
##
## THE OCTAVE INDEX IS IN THE KEY, AND IT WAS NOT. §16.5.1 names "quantised
## position plus octave index" and this keyed on position alone, with one salt
## at every octave. Each octave halves the lattice, so every second node of the
## finer octave landed on a coarser one carrying the IDENTICAL gradient vector:
## the octaves were aligned copies of one field rather than independent draws
## of it, which is not the fBm the exponent rows describe. Nothing looked
## wrong, because a sum of aligned copies is still a plausible-looking surface.
##
## AND THE WORLD SEED IS IN IT. `0x9e37` was the whole of the world's identity
## and it was a constant in this file.
func _dot_grad(ix: int, iy: int, octave: int, dx: float, dy: float) -> float:
    var a := TAU * StableHash.unit(
            StableHash.of5(world_seed, SALT_GRADIENT, octave, ix, iy))
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
## NO LONGER CONDITIONS ANYTHING. Decision 985 names HAND and slope, and the
## margin's membership moved to HAND when that layer landed. This is kept
## because it is the horizontal sibling that VALIDATES the vertical one -- HAND
## rises monotonically across eight distance bands, which is the check that the
## two were derived against the same network -- and because a reader asking
## "how far is the water" should not have to compute it from a height.
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
## LIVE NOW: this returned 1.0 everywhere for as long as no HAND raster was
## vendored, and said so. The layer landed, so the mechanism that was wired
## rather than waited for is plugged in without being rebuilt -- which is the
## whole reason it was wired.
##
## SATURATING, NOT A CUT. `floor_fraction` at the drainage, full strength above
## `full_strength_above_m`, smoothstep between: convention 1, and the same
## reason the strata blend rather than switch.
##
## NAN IS FULL STRENGTH. Absent HAND is outside the basin, or ground whose
## filled descent reaches no channel at all. Undrained upland is not a
## floodplain, so the honest default is no suppression -- and defaulting the
## other way would have flattened 6.3 million pixels of real relief on the
## strength of a missing value.
func taper_at(w: Vector2) -> float:
    return taper_for(hand_m(w))


## The same taper, with HAND given rather than sampled -- `d`'s own signature.
func taper_for(hand: float) -> float:
    var h: Dictionary = rows.get("hand_taper", {})
    if is_nan(hand):
        return 1.0
    var floor_fraction := clampf(float(h.get("floor_fraction", 0.15)), 0.0, 1.0)
    var full_above := maxf(1.0e-6, float(h.get("full_strength_above_m", 25.0)))
    # Centred so the ramp spans [0, full_above] exactly: `_ramp` measures from
    # `centre - half`, so a centre of half the span with half its width puts
    # the foot at zero and the shoulder at `full_above`.
    var t := _ramp(hand, 0.5 * full_above, 0.5 * full_above)
    return floor_fraction + (1.0 - floor_fraction) * t


## Height above the nearest drainage, metres, or NAN. NAN without the layers --
## there is nothing to re-derive it from without a channel network and a fill.
func hand_m(w: Vector2) -> float:
    return NAN if _layers == null else _layers.hand_m(w.x, w.y, 0)


func taper_source() -> String:
    if _layers == null or not _layers.has(TerrainLayers.HAND):
        return ("no HAND layer, so the taper is 1.0 everywhere and the amplitude is "
                + "conditioned on slope alone. Decision 985 names both.")
    var h: Dictionary = rows.get("hand_taper", {})
    return ("HAND at z=0, from assets/terrain/layers/: %s of full amplitude at the drainage, "
            % String.num(float(h.get("floor_fraction", 0.15)), 2)
            + "full above %s m, smoothstep between. Absent HAND is full strength -- undrained "
            % String.num(float(h.get("full_strength_above_m", 25.0)), 0)
            + "upland is not a floodplain. Distance-to-channel no longer conditions anything: "
            + "985 names HAND and slope, and the horizontal sibling's job is now to VALIDATE "
            + "the vertical one, which it does monotonically across eight distance bands.")
