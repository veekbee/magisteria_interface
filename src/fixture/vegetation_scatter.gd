class_name VegetationScatter
extends RefCounted

## M5's first visible result: the carried vegetation rows, scattered as form
## archetypes over the terrain at life form.
##
## THE CHAIN, AND EVERY LINK IS SOMEBODY ELSE'S. A texel has a residence key
## (decision 891, received not computed); the key joins to a cell; the cell
## indexes one day of `band.pft_fractions` and `band.pft.biomass`; the group
## axis is named by the fixture's `taxon_groups` and keys a family. Nothing
## here decides what grows where.
##
## TWO AXES FROM TWO ROWS, WHICH IS WHY THERE ARE TWO ROWS. §17.8.2 wants
## height and crown as separate axes for woody forms, deriving from different
## field quantities, and the wire carries exactly two per group:
##
##   * `crown_m`  <- the COVER FRACTION. Cover is crown area times count, so
##                   the fraction is the quantity that speaks about width.
##   * `height_m` <- the BIOMASS PER COVERED AREA (biomass / fraction). Mass
##                   packed into a given crown footprint is the quantity that
##                   speaks about height.
##
## Both are normalised into the family's declared legal range, so a value can
## never leave it by construction -- and `FamilySet` still checks, because a
## parameter that escapes is a bug upstream and clamping it would hide the bug
## behind a plausible plant.
##
## COUNT IS NOT A FREE PARAMETER. Instances per texel are
## `fraction * texel_area / crown_area`, which is cover divided by the area one
## individual covers. That number is what the wire implies and it is very often
## far more than a frame can draw -- grass alone runs to millions per square
## kilometre. The scatter does NOT quietly thin it. It draws one stated share
## across every family, so the mix between families is preserved, and reports
## the share, the implied count and the predicted cost. A picture with a share
## of 1e-4 is a sample of a stand and says so; a picture that silently drew the
## thousand instances that happened to fit would be a different stand.
##
## NOTHING WRITTEN INTO A MultiMesh CAN BE READ BACK HEADLESS. Under the dummy
## renderer the per-instance store does not exist: `get_instance_transform`
## returns the identity, `get_instance_custom_data` returns zeros, and `buffer`
## is empty, whatever was written. `instance_count` and the format flags are
## properties of the resource and do survive.
##
## So THIS REPORT is the checkable statement about what the scatter placed --
## every figure in it is computed in GDScript from the same values that go into
## the instances. A test that read the instances back would be testing the stub,
## and would pass by comparing zero against zero.
##
## THE VERTICAL EXAGGERATION APPLIES TO THE PLANTS TOO. M1 draws this basin at
## 12x relief. Vegetation at true scale on 12x terrain reads as twelve times
## too short, so the same factor scales plant height and the report carries it.
## No height should be read off the picture either way.

## PLACEMENT IS A FUNCTION OF WHERE, NOT OF WHEN IT WAS DRAWN. This is the
## world key that function is hashed against; it is not a sequence seed, and
## nothing here consumes a random stream. It travels in the report.
##
## WHY, MEASURED. A sequential stream makes a position depend on visit order,
## and the scatter is rebuilt around a camera that moves, so re-centring the
## disc renumbers every position inside it. One 21.8 m dolly step, same day,
## same place, overlapping discs: 36,081 instances became 28,358, of which
## EIGHT were the same plants (`measurements/scatter_motion.json`). A stand
## that reshuffles under motion is not a stand, and no crossfade can hide an
## unbounded one.
##
## So a candidate's position comes from a hash of its own quantised world
## coordinates, its family, and its index within its sub-cell. Two builds over
## the same ground agree instance for instance, whatever else differs.
const SCATTER_SEED := 20260903

## Sub-cell origins are quantised to a centimetre before hashing, so the key is
## the ground rather than a float that arithmetic happened to reassociate.
const PLACEMENT_QUANTUM := 100.0

## Mixing is done in 32 bits with every product masked, because GDScript ints
## are 64-bit and a multiplier over 2^31 would overflow the signed range rather
## than wrap into it. Both multipliers below are under 2^31 for that reason.
const HASH_MASK := 0xFFFFFFFF
const HASH_SPAN := 4294967296.0

## Rounds in the candidate ordering. Any number of rounds is a bijection, which
## is the property that matters; four is where the order stops resembling the
## index.
const PERMUTATION_ROUNDS := 4

## Cycle-walking terminates with probability 1 and is bounded anyway. Reaching
## this would be a bug, and `placement_walk_overruns` in the report is how it
## would be found rather than absorbed.
const PERMUTATION_WALK_LIMIT := 64

## Discs the placement digest is folded over, in metres from the build centre.
## Absolute rather than fractions of the radius, so two builds at two radii are
## comparing the same ground; see the digest's own note for what makes a ring
## comparable.
const DIGEST_RINGS_M: Array = [500, 1000, 2000]

## A ceiling on instances BUILT, which is not the frame budget and must not be
## confused with it. `measurements/render_cost.json` prices a frame; this
## bounds the seconds GDScript spends filling a MultiMesh before that frame
## exists. Whichever binds is named in the report, so a share of 0.02 is never
## ambiguous between "the GPU cannot draw this" and "the scatter declined to
## spend a minute building it".
const MAX_BUILT_INSTANCES := 120000

## A DENSITY SCHEDULE, which is the thing a band system is made of.
##
## `[{"to_m": 100.0, "keep": 1.0}, {"to_m": 300.0, "keep": 0.25}]` places every
## implied individual within 100 m of the centre, a quarter of them out to
## 300 m, and none beyond. An empty schedule is today's behaviour exactly: one
## keep of 1.0 everywhere, thinned only by whatever ceiling binds.
##
## THINNING IS SAMPLING, NOT SHRINKING, and the distinction is the same one
## `share_drawn` already makes. A band at 0.25 draws a quarter of the stand at
## full size; it does not draw the whole stand at quarter density, and it does
## not make the plants smaller. What the wire says is on the ground is
## unchanged and the report still carries it -- `implied` is the unthinned
## implication and stays that way, because the schedule is a drawing decision
## and the implication is a measurement.
const NO_SCHEDULE: Array = []

## THE HORIZON RULE: an object stops being drawn individually beyond `k` times
## its own drawn height, one shared `k` for every family. Zero disables it and
## is the shipped default until the sweep has ruled a value.
##
## WHY ONE CONSTANT AND NOT FOUR TUNED DISTANCES. Individuation range is
## proportional to apparent size, so a per-family distance is a per-family
## restatement of one fact. Derived, the horizon cannot drift between families
## the way four tuned numbers can, and there is one knob to sweep instead of a
## product of four.
##
## AND THE CONSTANT IS BOUNDED ABOVE BY THE CAMERA, which is worth knowing
## before sweeping it. `resolution_k` is the `k` at which the horizon lands
## exactly where the object falls below one pixel, and it is a pinhole
## identity -- 521 at 1280x800 and a 75 degree fov, THE SAME 521 for every
## family, measured off `scatter_bands.json`'s own pixel table for shrub,
## succulent and tree. So k is not free: individuation stops at or before
## resolution, and the sweep is looking for how far before.
const NO_HORIZON_RULE := 0.0

## How far `render_cost.json`'s coefficient sits below a real frame.
##
## The budget below is `budget_ms / mean_ns_per_instance`, and that coefficient
## is measured on an EMPTY STAGE -- no terrain, no culling, no LOD. It is a
## floor, and `measurements/scatter_cost.json` measures the distance from it:
## the same instances in the viewer that draws them cost about a third more,
## reproducibly and never less, across a 5.6x change in the pixels they cover.
##
## So a scatter thinned "to fit 33.3 ms" by this coefficient lands near 44 ms.
## That is not a hypothetical: at the basin's densest cells the thinning is
## already engaged and the frame still measures 36-49 ms
## (`measurements/scatter_horizon.json`). The number is NOT applied here --
## §19.8.9 owns the coefficient and correcting a budget is its call, not this
## client's -- but the budget block says it, so nobody reads the prediction as
## the frame. `test_the_budget_says_it_is_made_from_a_floor` keeps it current
## against the artefact it is quoted from.
const EMPTY_STAGE_UNDER_PREDICTS := 1.33


## How far one object of this drawn height is individuated, under constant `k`.
static func individuation_horizon_m(height_m: float, k: float) -> float:
    if k <= 0.0 or height_m <= 0.0:
        return 0.0
    return k * height_m


## The `k` whose horizon IS the one-pixel range: a property of the camera and
## the viewport, not of vegetation, and the same number for every family.
## `k / resolution_k(...)` is the fraction of the resolvable range that is
## being individuated, which is the portable way to quote a swept `k`.
static func resolution_k(viewport_height_px: float, fov_degrees: float) -> float:
    var t := tan(deg_to_rad(0.5 * fov_degrees))
    if t <= 0.0 or viewport_height_px <= 0.0:
        return 0.0
    return viewport_height_px / (2.0 * t)


## A 32-bit avalanche. Deterministic, portable, and not `String.hash()` or
## `RandomNumberGenerator`: both are engine internals free to change between
## versions, and a placement that moves when Godot updates is the defect this
## whole scheme exists to remove.
static func mix32(value: int) -> int:
    var x: int = value & HASH_MASK
    x = ((x ^ (x >> 16)) * 0x21f0aaad) & HASH_MASK
    x = ((x ^ (x >> 15)) * 0x735a2d97) & HASH_MASK
    return (x ^ (x >> 15)) & HASH_MASK


## One hash over an ordered list of integers. Order matters and is the point:
## `[x, y]` and `[y, x]` are different ground.
static func stable_hash(parts: Array) -> int:
    var h: int = 0x9e3779b9
    for p in parts:
        h = mix32(h ^ mix32(int(p)))
    return h


## THE SAME HASH OVER EXACTLY THREE PARTS, WITHOUT THE ARRAY.
##
## Identical output to `stable_hash([a, b, c])` -- the gate checks that rather
## than trusting it -- and it exists because the array is not free. This runs
## three times per placed instance, so at a hundred thousand instances a build
## it was three hundred thousand allocations to carry three integers into a
## loop that adds them up. Measured: the whole digest and jitter path cost
## 270 ms of a 1,670 ms build before this.
static func stable_hash3(a: int, b: int, c: int) -> int:
    var h: int = 0x9e3779b9
    h = mix32(h ^ mix32(a))
    h = mix32(h ^ mix32(b))
    return mix32(h ^ mix32(c))


## The hash read as a fraction of 1, which is the form a rank and a jitter both
## want.
static func hash01(h: int) -> float:
    return float(h & HASH_MASK) / HASH_SPAN


## The family axis of the key, from the name rather than from an index, so
## adding a family to the fixture cannot move an existing family's plants.
## FNV-1a over the UTF-8 bytes -- small, specified elsewhere, and ours.
static func family_key(life_form: String) -> int:
    var h: int = 0x811c9dc5
    for b in life_form.to_utf8_buffer():
        h = ((h ^ int(b)) * 16777619) & HASH_MASK
    return h


## A Feistel round pair over `2 * bits` bits. Invertible for any round function,
## which is the only property asked of it here.
static func _feistel(value: int, bits: int, key: int) -> int:
    var half: int = (1 << bits) - 1
    var l: int = value & half
    var r: int = (value >> bits) & half
    for i in PERMUTATION_ROUNDS:
        var f: int = mix32(key ^ mix32(r ^ ((i + 1) * 0x9e3779b1))) & half
        var carry: int = r
        r = l ^ f
        l = carry
    return (r << bits) | l


## THE `index`-th CANDIDATE OF `n`, UNDER THE ORDERING `key` NAMES.
##
## Thinning has to be a stable ordering rather than a fresh draw (§16.6), and
## the obvious way to write one is to give each candidate a hashed rank and
## keep the ranks under the drawn fraction. That form is O(n), and `n` for
## grass is the millions of blades a texel implies -- visited to find the
## hundreds that pass. A permutation gives the same set in O(m): the first `m`
## of a fixed order.
##
## Nesting is what makes it a fix rather than a different shuffle. The set for
## `m - 1` is the set for `m` minus one plant, so a falling share thins the
## stand and a rising one puts back the same plants it took.
##
## A Feistel network over the smallest power-of-four domain covering `n`,
## cycle-walked back into range. The domain is under `4n`, so the walk expects
## fewer than four turns whatever `n` is.
static func candidate_at(index: int, n: int, key: int) -> int:
    if n <= 1:
        return 0
    var bits := 1
    while (1 << (2 * bits)) < n and bits < 31:
        bits += 1
    var x: int = index % (1 << (2 * bits))
    for _walk in PERMUTATION_WALK_LIMIT:
        x = _feistel(x, bits, key)
        if x < n:
            return x
    # Not reachable in any run; counted rather than silently modulo'd, because
    # a fallback that looks like an answer is how a broken permutation ships.
    return -1

## A TEXEL IS A KILOMETRE, AND A BAND BOUNDARY IS A HUNDRED METRES. The
## residence and height rasters this scatter places against are the 1,000 m
## overview -- the export declares a tile pyramid and does not emit it -- so a
## 1,500 m horizon is NINE texels, and applying a schedule per texel gives a
## fade with three steps in it, all of them a kilometre wide. Measured before
## this existed: schedules cutting at 100 m, 200 m and 300 m produced byte-
## identical instance counts, because each kept exactly the centre texel and
## nothing else.
##
## So a schedule subdivides the texel it is thinning. Each texel is split into
## this many sub-cells per side and the keep is evaluated at each sub-cell's
## own centre, which puts the fade on a 31 m grid instead of a 1,000 m one.
## The DATA is still per cell -- every plant in a texel has the same height,
## crown and phenology, because those come from the cell -- and only the
## density varies within it. That asymmetry is honest and worth stating: the
## fade is a drawing decision applied at a resolution the wire does not have.
##
## It costs nothing when no schedule is given, which is the shipped path: with
## an empty schedule the texel is not subdivided at all.
const BAND_SUBDIVISION := 32

## Days sampled to find a cell's own yearly trough and peak for phenology.
##
## Ten of the window's ninety, because the alternative is reading every day of
## every group for a number that moves slowly. The sampling is stated in the
## report: a trough between two samples is missed, which widens no cell's range
## and narrows some, so a sampled phenology is conservative rather than wrong
## in an unknown direction.
const PHENOLOGY_SAMPLE_STRIDE := 9

var meshes: Dictionary = {}          ## life_form -> MultiMesh

## THE STAND AS A CENSUS: sub-cell -> [count, mesh x, mesh y, mesh z].
##
## `meshes` is the only record of what was placed, and under the dummy renderer
## nothing can be read back out of it. That is tolerable for a photograph and
## fatal for a replay: a trace scored headlessly has to know what population
## each frame held, and it cannot ask the MultiMesh.
##
## So the build keeps the census beside the meshes. It is exact rather than a
## summary, and it is enough to compute what changed between two builds without
## either of them being drawn -- BECAUSE placement is a stable prefix of a fixed
## per-sub-cell order. Two builds that admit the same sub-cell hold the first
## `n_a` and the first `n_b` of one sequence, so the plants they share are the
## first `min(n_a, n_b)` of it. Set arithmetic collapses to `min`, per sub-cell,
## and a churn is three sums over two dictionaries.
##
## That identity is worth naming as the thing it is: a consequence of the
## placement rule, not a property of scatters in general. Against the sequential
## draw this replaced, two builds shared nothing and no census could have said
## otherwise.
##
## NOT SERIALISED. It is thousands of entries and it is an intermediate, not a
## measurement; what reaches an artefact is what was computed FROM it.
var census: Dictionary = {}
var report: Dictionary = {}

var _hf: Heightfield = null
var _rl: ResidenceLayer = null
var _fl: FixtureLoader = null
var _fs: FamilySet = null
var _fc: FrameCost = null
var _tm: TerrainMesh = null
var _season: Dictionary = {}         ## "window|group" -> {"lo": .., "hi": ..} per cell


func bind(hf: Heightfield, rl: ResidenceLayer, fl: FixtureLoader,
          fs: FamilySet, fc: FrameCost, tm: TerrainMesh) -> void:
    _hf = hf
    _rl = rl
    _fl = fl
    _fs = fs
    _fc = fc
    _tm = tm


func is_bound() -> bool:
    return _hf != null and _rl != null and _fl != null and _fs != null and _tm != null


## Scatter one day of one window within `radius_m` of a world position.
##
## A radius rather than the basin: a cell here is about 126 km2 and the whole
## basin is 5,684 of them, so "scatter the fixture" is not a thing any frame
## can contain. The horizon is the caller's and the cost of it is reported.
## `only`, when set, builds ONE life form and skips the rest entirely.
##
## Not a convenience: the build ceiling and the frame budget are applied as ONE
## SHARE ACROSS EVERY FAMILY, so a deep build for a sparse family would thin the
## dense ones and then thin the sparse one with them. A reference for trees at
## three kilometres has to not be paying for grass at three kilometres.
func build(window: String, day: int, centre: Vector2, radius_m: float,
           bands: Array = NO_SCHEDULE, ceiling: int = MAX_BUILT_INSTANCES,
           k: float = NO_HORIZON_RULE, only: String = "",
           frame_budget: bool = true) -> Dictionary:
    var t_build := Time.get_ticks_usec()
    meshes = {}
    census = {}
    if not is_bound():
        report = {"ok": false, "why": "the scatter is not bound to its artefacts"}
        return report

    var groups := _fl.taxon_groups(window, "band.pft_fractions")
    if groups.is_empty():
        report = {"ok": false, "why": "the fixture names no taxon_groups for band.pft_fractions"}
        return report
    var biomass_groups := _fl.taxon_groups(window, "band.pft.biomass")
    if Array(groups) != Array(biomass_groups):
        # Two rows on one group axis. If they ever disagreed, every plant would
        # take its width from one life form and its height from another.
        report = {"ok": false, "why": ("the two vegetation rows name different group axes: "
                + "%s against %s") % [str(groups), str(biomass_groups)]}
        return report
    var missing := _fs.missing_for(groups)

    var bare := _fl.day_values(window, "band.bare_fraction", day)
    if bare.is_empty():
        report = {"ok": false, "why": ("no band.bare_fraction for %s day %d, and without it "
                + "pft_fractions is a composition with nothing to scale it") % [window, day]}
        return report
    var fractions: Array = []
    var biomass: Array = []
    for g in groups.size():
        fractions.append(_fl.day_values(window, "band.pft_fractions", day, g))
        biomass.append(_fl.day_values(window, "band.pft.biomass", day, g))
    var biomass_hi := _row_hi(window, "band.pft.biomass")
    var seasons: Array = []
    for g in groups.size():
        seasons.append(_season_range(window, "band.pft.biomass", g))

    # PASS ONE: what the wire implies, before any question of what fits.
    var texel_area := _hf.pixel_size_m * _hf.pixel_size_m
    var wanted: Array = []             ## {texel, group, count, height_m, crown_m}
    var implied: Dictionary = {}
    for g in groups:
        implied[g] = 0.0
    var texels := 0
    var flat_cells := 0
    var phen_lo := 1.0
    var phen_hi := 0.0
    ## [life_form, horizon_m] per cell the rule was evaluated at, so the report
    ## can say what one `k` actually meant in metres per family.
    var horizons_seen: Array = []
    var centre_texel := _hf.world_to_texel(centre.x, centre.y)
    # A TEXEL IS A KILOMETRE AND THE DISC IS OFTEN SMALLER THAN ONE.
    #
    # This used to keep a texel when its CENTRE was inside the radius, which is
    # the wrong test by half a texel in every direction: a texel centred 600 m
    # away reaches to within 100 m of the camera and was being skipped whole.
    # At the 480 m radius every far-field harness here uses, at most one texel
    # centre can be within the radius of any point -- so the scatter drew ONE
    # texel and the ground beyond it was bare.
    #
    # Found by flying it. A straight walk at 5 m/s crossed a texel boundary and
    # the vegetation stopped dead: a well-defined edge, then a flat empty
    # plane, then the next rebuild put a whole stand back. Nothing in the
    # numbers said so -- `texels: 1` was sitting in every report and read as a
    # small disc rather than as a wall.
    var texel_half := 0.5 * _hf.pixel_size_m
    var reach := int(ceil(radius_m / _hf.pixel_size_m)) + 1
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            var tx := int(round(centre_texel.x)) + dx
            var ty := int(round(centre_texel.y)) + dy
            var w := _hf.texel_to_world(float(tx), float(ty))
            # The disc against the texel's SQUARE: distance to the nearest
            # point of it, which is zero when the centre is inside.
            var gx := maxf(0.0, absf(w.x - centre.x) - texel_half)
            var gy := maxf(0.0, absf(w.y - centre.y) - texel_half)
            if Vector2(gx, gy).length() > radius_m:
                continue
            # WHETHER THE WHOLE TEXEL IS INSIDE, which decides whether the fast
            # path is honest. A texel the disc only clips has to be subdivided
            # and cut, or the disc is not a disc: plants would be placed
            # anywhere in a kilometre square whose far corner is outside the
            # radius the caller asked for.
            var fx := absf(w.x - centre.x) + texel_half
            var fy := absf(w.y - centre.y) + texel_half
            var whole := Vector2(fx, fy).length() <= radius_m
            if is_nan(_hf.height_at_texel(tx, ty)):
                continue
            var key := _rl.key_at(tx, ty)
            if key.is_empty():
                continue
            var huc: String = _rl.node_of_index.get(int(key[0]), "")
            if huc == "":
                continue
            var ci: Variant = _fl.cell_of_key.get("%s|%d" % [huc, int(key[1])], null)
            if ci == null:
                continue
            texels += 1
            var cell := int(ci)
            for gi in groups.size():
                var life_form := groups[gi]
                if not _fs.has(life_form):
                    continue
                if only != "" and life_form != only:
                    continue
                var vals_f: PackedFloat64Array = fractions[gi]
                var vals_b: PackedFloat64Array = biomass[gi]
                if cell >= vals_f.size() or cell >= vals_b.size():
                    continue
                # The COMPOSITION share scaled by how much ground is vegetated
                # at all. Reading the share as a cover is what put every cell
                # at full canopy; see `ground_cover`.
                var frac := ground_cover(vals_f[cell],
                        NAN if cell >= bare.size() else bare[cell])
                var bio := vals_b[cell]
                if is_nan(frac) or is_nan(bio) or frac <= 0.0:
                    continue
                var params := parameters_for(life_form, frac, bio, biomass_hi)
                if not bool(params["ok"]):
                    continue
                var crown := float(params["crown_m"])
                var crown_area: float = PI * (0.5 * crown) * (0.5 * crown)
                if crown_area <= 0.0:
                    continue
                var count := frac * texel_area / crown_area
                var phen := phenology_for(seasons[gi], cell, bio)
                var why_phen := _fs.check(life_form, "phenology", phen)
                if why_phen != "":
                    # The tint is a declared parameter with a declared range,
                    # so it is refused on the same terms as height and crown.
                    continue
                if float(seasons[gi]["hi"][cell]) - float(seasons[gi]["lo"][cell]) <= 0.0:
                    flat_cells += 1
                var half := 0.5 * _hf.pixel_size_m
                # THE HORIZON IS PER FAMILY AND SMALLER THAN A TEXEL, so it
                # has to be evaluated on the subdivided grid for the same
                # reason the density schedule does: a texel is a kilometre, and
                # cutting at 15 m or at 300 m inside one keeps the same whole
                # texel either way. Measured before the schedule existed:
                # cuts at 100, 200 and 300 m gave byte-identical counts. So a
                # horizon rule forces subdivision even with no schedule.
                var horizon_m := individuation_horizon_m(float(params["height_m"]), k)
                if k > 0.0:
                    horizons_seen.append([life_form, horizon_m])
                # NO FAST PATH FOR A WHOLE TEXEL ANY MORE, and the reason is
                # placement rather than tidiness. A sub-cell's placement key
                # carries the granularity it was emitted at, so a texel emitted
                # whole and the same texel emitted as sub-cells are different
                # ground to the hash. The disc clips texels differently as the
                # camera moves, so the fast path made a texel's plants re-draw
                # the moment the rim reached it -- the churn defect back again,
                # at the one place a crossfade would have to hide it. The gate
                # caught this within minutes of the clip being added.
                # Subdivided, because the schedule works at a finer scale than
                # the raster this is placed on. Sub-cells the schedule keeps
                # nothing in are not emitted at all, so a tight band over a
                # wide horizon costs a loop and not a scatter.
                var sub_half := half / float(BAND_SUBDIVISION)
                var per_sub := count / float(BAND_SUBDIVISION * BAND_SUBDIVISION)
                for sy in BAND_SUBDIVISION:
                    for sx in BAND_SUBDIVISION:
                        var o := Vector2(
                                w.x - half + sub_half * (2.0 * float(sx) + 1.0),
                                w.y - half + sub_half * (2.0 * float(sy) + 1.0))
                        var d_m := Vector2(o.x - centre.x, o.y - centre.y).length()
                        # THE RADIUS IS A CUT LIKE THE OTHERS. Without it a
                        # clipped texel would place plants past the disc the
                        # caller asked for, which is how "within radius_m"
                        # stops being true of the thing that comes back.
                        if d_m > radius_m:
                            continue
                        # WHAT THE WIRE IMPLIES OVER THE GROUND THIS BUILD
                        # ASKED ABOUT. Accumulated per surviving sub-cell
                        # rather than per texel: a texel the disc only clips
                        # would otherwise contribute its whole kilometre to a
                        # number the caller reads as "inside the radius", and
                        # `share x implied = placed` would stop holding. The
                        # horizon and the schedule are NOT applied here -- they
                        # are drawing decisions and the implication is a
                        # measurement.
                        implied[life_form] = float(implied[life_form]) + per_sub
                        # The horizon is a hard cut and the schedule is a fade;
                        # they compose, and neither substitutes for the other.
                        if k > 0.0 and d_m > horizon_m:
                            continue
                        var keep := keep_at(d_m, bands)
                        if keep <= 0.0:
                            continue
                        wanted.append({"origin": o, "half_m": sub_half,
                                       "life_form": life_form, "count": per_sub,
                                       "banded": per_sub * keep,
                                       "distance_m": d_m, "keep": keep,
                                       "height_m": float(params["height_m"]),
                                       "crown_m": crown, "phenology": phen})

    # What one frame can hold, from the measurement rather than from a guess.
    var total_implied := 0.0
    for g in implied:
        total_implied += float(implied[g])
    # After the schedule, which is what actually has to be built and drawn. The
    # unthinned total stays reported beside it: one is what the wire says is
    # there and the other is what this frame chose to draw, and collapsing them
    # into one number is how a drawing decision comes to look like data.
    var total_banded := 0.0
    for item in wanted:
        total_banded += float(item["banded"])
    var afford := _affordable(groups, implied)
    var head: float = float(afford.get("instances", 0.0)) if bool(afford.get("ok", false)) else 0.0
    var bound_by := "the frame budget"
    if not frame_budget:
        # AN ORACLE IS NOT A FRAME ANYONE HAS TO PLAY. It is photographed once,
        # and thinning it to 33.3 ms makes it a SAMPLE of the stand rather than
        # the stand -- which is the one thing a reference must not be, because
        # every candidate is then flattered by exactly the sampling. The build
        # ceiling still applies: that is about what fits in memory and in a
        # build, which is a real limit on any build.
        head = float(ceiling)
        bound_by = ("the build ceiling; the frame budget is deliberately not applied to this "
                + "build, which is a reference and not a frame")
    elif not bool(afford.get("ok", false)):
        head = float(ceiling)
        bound_by = "the build ceiling, with no frame-cost measurement to price against"
    elif head > float(ceiling):
        head = float(ceiling)
        bound_by = "the build ceiling, which is lower here than the frame budget"
    var share: float = 1.0
    if total_banded > head and total_banded > 0.0:
        share = head / total_banded
    else:
        bound_by = ("the density schedule alone" if not bands.is_empty()
                else "nothing: the whole implied scatter is drawn")

    # PASS TWO: place the share, preserving the mix between families.
    #
    # Every position below is a pure function of the ground it stands on. The
    # camera decides HOW MANY of a sub-cell's candidates are drawn and never
    # WHICH, so re-centring the disc moves the rim and leaves the interior
    # alone. See SCATTER_SEED for what this replaced and what it cost.
    var placed: Dictionary = {}
    var refused := 0
    var walk_overruns := 0
    # WHAT THE STAND ACTUALLY IS, IN A FORM A HEADLESS TEST CAN COMPARE.
    #
    # Instance transforms cannot be read back under the dummy renderer, so the
    # claim "two builds over the same ground placed the same plants" would be
    # uncheckable in the gate -- exactly the claim this scheme exists to make.
    # An XOR fold over the quantised world position of every placed instance is
    # order-independent, so two builds that scanned the disc differently still
    # agree, and it is nested by radius so a small build can be compared with
    # the inner part of a large one.
    #
    # THE RINGS ARE ABSOLUTE METRES, NOT FRACTIONS OF THE RADIUS, and that is
    # the difference between a comparable digest and a plausible one. A texel
    # is a kilometre, so a build's radius decides which TEXELS are scanned
    # while an instance sits anywhere inside its own texel -- up to 707 m from
    # that texel's centre. Two builds at two radii therefore agree on the
    # plants within D metres only if both scanned every texel that could put
    # one there, which is a statement about D and not about either radius.
    var digest: Dictionary = {}
    var digest_n: Dictionary = {}
    for ring in DIGEST_RINGS_M:
        digest[str(ring)] = 0
        digest_n[str(ring)] = 0
    digest["all"] = 0
    digest_n["all"] = 0
    # AND PER TEXEL, WHICH IS THE ONLY FORM THAT SURVIVES RE-CENTRING. The
    # rings above are measured from the build's own centre, so two builds
    # around two cameras have no ring in common and the defect this scheme
    # fixes is exactly a change of centre. A texel is fixed ground: whichever
    # build reaches it, it holds the same plants, and two builds can be
    # compared on the texels they both covered whole.
    var digest_texel: Dictionary = {}
    var by_family: Dictionary = {}
    var phen_of: Dictionary = {}
    for g in groups:
        placed[g] = 0
        by_family[g] = []
        phen_of[g] = PackedFloat32Array()
    for item in wanted:
        var life_form: String = item["life_form"]
        var origin: Vector2 = item["origin"]
        var half: float = item["half_m"]
        # HOISTED, ALL OF IT. Every line here is constant for the sub-cell:
        # the family key is an FNV walk over a string, and the texel a sub-cell
        # sits in is one texel by construction. Both were being recomputed per
        # INSTANCE, which is a hundred thousand string walks a build to learn
        # the same answer.
        var lf_key := family_key(life_form)
        var cell_key := stable_hash([SCATTER_SEED, lf_key,
                int(round(origin.x * PLACEMENT_QUANTUM)),
                int(round(origin.y * PLACEMENT_QUANTUM)),
                int(round(half * PLACEMENT_QUANTUM))])
        # ROUNDING THAT KEEPS THE STAND, AND KEEPS IT IN THE SAME ORDER.
        #
        # A sub-cell is a thirty-metre square and a family's implication in one
        # is often a fraction. Rounding each independently deletes any family
        # whose density is under half a plant per sub-cell -- and since the
        # texel is now always subdivided, that is most sparse families over
        # most of the basin. The old whole-texel path hid this by rounding once
        # per kilometre.
        #
        # So the fraction is resolved against the sub-cell's OWN hash: floor,
        # plus one more when the draw falls inside the remainder. Over a texel
        # the count comes out right, the choice is a function of the ground
        # like everything else here, and ONE draw serves both the pool and the
        # thinned count -- which is what keeps `n <= pool` true and the prefix
        # nested as the share falls.
        var u := hash01(stable_hash3(cell_key, 0, 7))
        var pool := _resolve(float(item["count"]), u)
        var n := _resolve(float(item["banded"]) * share, u)
        if n <= 0:
            continue
        if pool < n:
            pool = n
        var it := _hf.world_to_texel(origin.x, origin.y)
        var tkey := "%d|%d" % [int(round(it.x)), int(round(it.y))]
        # The folds for this sub-cell, kept in locals and written to the
        # dictionaries once at the end of it rather than per instance.
        var fold_all := 0
        var fold_ring := [0, 0, 0]
        var fold_ring_n := [0, 0, 0]
        var here := 0
        var here_at := Vector3.ZERO
        for i in n:
            var candidate := candidate_at(i, pool, cell_key)
            if candidate < 0:
                walk_overruns += 1
                continue
            # Uniform in the sub-cell square, which is the distribution the
            # sequential draw had. §16.6 asks for blue noise and this is not
            # it: a hash-seeded uniform jitter fixes the STABILITY defect and
            # leaves the spacing one open. Recorded in the report, not implied.
            var wx := origin.x + (2.0 * hash01(stable_hash3(cell_key, candidate, 1)) - 1.0) * half
            var wy := origin.y + (2.0 * hash01(stable_hash3(cell_key, candidate, 2)) - 1.0) * half
            # ON THE SURFACE THAT IS DRAWN, not on the field it was sampled
            # from. The mesh triangulates the heightfield every `stride` texels
            # -- 4 km apart on the overview -- and the two disagree by a MEAN OF
            # 36 m and up to 640 m. Plants placed on the field therefore float
            # above the ground or are buried under it by tens of metres. From
            # the overview camera, where the basin is 1.5 million metres across,
            # that is invisible; at eye level it is the whole picture, and it is
            # why the first seam run photographed 1.65 million instances as a
            # patch on the horizon.
            var h := _hf.height_at_world(wx, wy)
            var y := _tm.drawn_surface_y(Vector2(wx, wy), _hf)
            if is_nan(h) or is_nan(y):
                continue            # the one-texel nodata border; dropped, not clamped
            var m := _tm.world_to_mesh(Vector2(wx, wy), _hf)
            var pos := Vector3(m.x, y, m.y)
            var xf := _fs.instance_transform(life_form, pos, float(item["height_m"]),
                    float(item["crown_m"]), _tm.exaggeration)
            if not bool(xf["ok"]):
                refused += 1
                continue
            (by_family[life_form] as Array).append(xf["transform"])
            var pf: PackedFloat32Array = phen_of[life_form]
            pf.append(float(item["phenology"]))
            phen_of[life_form] = pf
            phen_lo = minf(phen_lo, float(item["phenology"]))
            phen_hi = maxf(phen_hi, float(item["phenology"]))
            placed[life_form] = int(placed[life_form]) + 1
            here += 1
            if here == 1:
                here_at = pos
            var seen := stable_hash3(int(round(wx * PLACEMENT_QUANTUM)),
                    int(round(wy * PLACEMENT_QUANTUM)), lf_key)
            fold_all ^= seen
            var d_centre := Vector2(wx - centre.x, wy - centre.y).length()
            for j in DIGEST_RINGS_M.size():
                if d_centre <= float(DIGEST_RINGS_M[j]):
                    fold_ring[j] = int(fold_ring[j]) ^ seen
                    fold_ring_n[j] = int(fold_ring_n[j]) + 1
        # ONCE PER SUB-CELL, not once per plant. XOR is associative, so folding
        # into a local and then into the dictionary is the same number.
        if here > 0:
            digest["all"] = int(digest["all"]) ^ fold_all
            digest_n["all"] = int(digest_n["all"]) + here
            for j2 in DIGEST_RINGS_M.size():
                var rk := str(DIGEST_RINGS_M[j2])
                digest[rk] = int(digest[rk]) ^ int(fold_ring[j2])
                digest_n[rk] = int(digest_n[rk]) + int(fold_ring_n[j2])
            if not digest_texel.has(tkey):
                digest_texel[tkey] = [0, 0]
            var acc: Array = digest_texel[tkey]
            acc[0] = int(acc[0]) ^ fold_all
            acc[1] = int(acc[1]) + here
            digest_texel[tkey] = acc
            # ONE ENTRY PER SUB-CELL, NOT PER PLANT. The key is the family and
            # the sub-cell's own quantised origin, so two builds name the same
            # ground with the same string and nothing about either camera is in
            # it. The position carried is the first instance's, which is where
            # the sub-cell's plants are to within half a sub-cell -- enough to
            # ask what a heading has in front of it, and not a claim about any
            # individual plant.
            census["%s|%d|%d" % [life_form, int(round(origin.x * PLACEMENT_QUANTUM)),
                    int(round(origin.y * PLACEMENT_QUANTUM))]] = [
                    here, here_at.x, here_at.y, here_at.z]

    # The size the wire implied, per family, over the cells this horizon
    # touched. A band scheme needs it to know when an individual stops being
    # worth drawing individually, and it is not recoverable from `placed`.
    var form: Dictionary = {}
    for item in wanted:
        var lf: String = item["life_form"]
        var h := float(item["height_m"])
        var c := float(item["crown_m"])
        if not form.has(lf):
            form[lf] = {"height_min_m": h, "height_max_m": h,
                        "crown_min_m": c, "crown_max_m": c}
        else:
            var f: Dictionary = form[lf]
            f["height_min_m"] = minf(float(f["height_min_m"]), h)
            f["height_max_m"] = maxf(float(f["height_max_m"]), h)
            f["crown_min_m"] = minf(float(f["crown_min_m"]), c)
            f["crown_max_m"] = maxf(float(f["crown_max_m"]), c)

    # WHAT ONE `k` MEANT, PER FAMILY, IN METRES. The rule is one constant and
    # the consequence is four distances, so the artefact carries the
    # consequence: a reader should not have to multiply to find out that a
    # shared k put grass at tens of metres and trees at a couple of kilometres.
    var horizon: Dictionary = {}
    if k > 0.0:
        var sub_m := _hf.pixel_size_m / float(BAND_SUBDIVISION)
        for pair in horizons_seen:
            var lf: String = pair[0]
            var hz: float = pair[1]
            if not horizon.has(lf):
                horizon[lf] = {"min_m": hz, "max_m": hz}
            else:
                var e: Dictionary = horizon[lf]
                e["min_m"] = minf(float(e["min_m"]), hz)
                e["max_m"] = maxf(float(e["max_m"]), hz)
        for lf in horizon:
            var e: Dictionary = horizon[lf]
            # THE CUT IS QUANTISED TO THE SUB-CELL, which is the resolution
            # wall one level down. A horizon of a few sub-cells is a circle
            # drawn with a handful of squares, and a horizon under one is not
            # drawn at all -- the family vanishes rather than thinning, and it
            # would look exactly like a family the wire never carried.
            e["sub_cell_m"] = sub_m
            e["cut_in_sub_cells"] = float(e["min_m"]) / sub_m
            if float(e["min_m"]) < sub_m:
                e["below_the_grid"] = ("%s's smallest horizon is %s m against a %s m sub-cell, "
                        % [lf, String.num(float(e["min_m"]), 1), String.num(sub_m, 1)]
                        + "so the rule cuts it below the resolution the cut is evaluated at "
                        + "and this family is dropped rather than thinned. Raise k, raise "
                        + "BAND_SUBDIVISION, or read this family's count as absent-by-grid.")

    var triangles := 0
    for life_form in by_family:
        var transforms: Array = by_family[life_form]
        if transforms.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        # CUSTOM DATA, NOT INSTANCE COLOUR. The engine multiplies an instance
        # colour into the mesh's vertex colour, and the mesh's vertex colour is
        # the authored phenology MASK -- the product is zero both for a trunk in
        # summer and for foliage in midwinter, which must not look alike.
        mm.use_custom_data = true
        # WHITE INSTANCE COLOURS, AND THEY ARE NOT DECORATION. With `use_colors`
        # off, the compatibility renderer hands the shader COLOR = 0 instead of
        # the mesh's vertex colour, so the authored phenology mask arrives as
        # zero and every plant renders as bare structure in every season. White
        # is the identity for that multiply; the mask survives it.
        mm.use_colors = true
        mm.mesh = _fs.mesh_for(life_form)
        mm.instance_count = transforms.size()
        var pf: PackedFloat32Array = phen_of[life_form]
        for i in transforms.size():
            mm.set_instance_transform(i, transforms[i])
            mm.set_instance_color(i, Color.WHITE)
            mm.set_instance_custom_data(i, Color(pf[i], 0.0, 0.0, 1.0))
        meshes[life_form] = mm
        triangles += _fs.triangles_of(life_form) * transforms.size()

    report = {
        "ok": true,
        "window": window,
        "day": day,
        "centre_m": [centre.x, centre.y],
        "radius_m": radius_m,
        "texels": texels,
        "seed": SCATTER_SEED,
        "vertical_exaggeration": _tm.exaggeration,
        "groups": Array(groups),
        "families_missing": Array(missing),
        "implied": implied,
        "implied_total": total_implied,
        "bands": bands,
        "implied_after_bands": total_banded,
        "build_ceiling_used": ceiling,
        "placed": placed,
        "form": form,
        "individuation_k": k,
        "horizon": horizon,
        "only_life_form": only,
        "frame_budget_applied": frame_budget,
        "share_drawn": share,
        "share_bound_by": bound_by,
        "build_ceiling": MAX_BUILT_INSTANCES,
        "refused_parameters": refused,
        "placement": {
            "rule": ("a hash of the sub-cell's own quantised world position, its family and "
                    + "the candidate's index in that sub-cell -- no random stream, so nothing "
                    + "here depends on the order the disc was scanned in"),
            "thinning": ("a stable prefix of a fixed per-sub-cell order, so a lower share "
                    + "REMOVES candidates and a higher one restores the same ones"),
            "quantum_m": 1.0 / PLACEMENT_QUANTUM,
            "jitter": ("uniform in the sub-cell square, the same distribution the sequential "
                    + "draw had. Blue-noise spacing is NOT implemented: this fixes what moves "
                    + "under the camera, not how evenly plants sit"),
            "walk_overruns": walk_overruns,
            "digest": digest,
            "digest_instances": digest_n,
            "digest_rings_m": DIGEST_RINGS_M,
            "digest_by_texel": digest_texel,
            "digest_by_texel_is": ("[fold, count] per heightfield texel, which is ground and "
                    + "not a distance from any camera. Two builds around two different centres "
                    + "have to agree on every texel they both covered WHOLE -- a texel the "
                    + "horizon or the disc clipped in one build and not the other holds fewer "
                    + "plants, correctly, and is not comparable"),
            "digest_is": ("an XOR fold of every placed instance's quantised world position and "
                    + "family, over concentric discs in absolute metres. Order-independent, so "
                    + "it compares builds that scanned the same ground in different orders. A "
                    + "ring is comparable across two builds only if BOTH scanned every texel "
                    + "that could place an instance inside it -- radius >= ring + %d m."
                    % int(ceil(0.70711 * _hf.pixel_size_m))),
        },
        "phenology": {
            "from": ("this cell's biomass today against its own trough and peak across the "
                    + "window, not against the row's range: the row's range says where a "
                    + "cell sits in the basin, not where it sits in its year"),
            "days_sampled": int(seasons[0]["days_sampled"]) if seasons.size() > 0 else 0,
            "range_drawn": [phen_lo, phen_hi] if phen_hi >= phen_lo else [],
            "cells_with_no_seasonal_signal": flat_cells,
        },
        "triangles_in_frame": triangles,
        "build_ms": float(Time.get_ticks_usec() - t_build) / 1000.0,
        "budget": afford,
        "what_share_means": ("one share across every family, so the mix between them is what "
                + "the wire says. A share below 1 is a sample of the stand, not a thinner "
                + "stand."),
    }
    return report


## A fractional count made whole, against a draw that belongs to the ground.
##
## `floor(x)`, plus one when `u` lands inside the remainder. Monotone in `x`
## for a fixed `u`, which is what makes a falling share remove plants rather
## than reshuffle them, and unbiased over many sub-cells, which is what stops a
## sparse family from rounding itself out of existence.
static func _resolve(x: float, u: float) -> int:
    if x <= 0.0:
        return 0
    var whole: float = floor(x)
    return int(whole) + (1 if u < x - whole else 0)


## How much of a cell's ground one life form actually covers.
##
## `band.pft_fractions` IS A COMPOSITION, NOT A COVER, and this client read it
## as a cover from M5 until the far-field tint made the error visible: every
## cell came back fully vegetated. The evidence is in the data and is not
## ambiguous -- the four groups sum to 1.0000 in 99.7% of the fixture's covered
## cells, while `band.bare_fraction` runs from 0.05 to 0.95 across the basin and
## averages 0.475. Both cannot be absolute: a cell cannot be 95% bare and 100%
## covered. The one that sums to one is the composition.
##
## NOT *EVERY* CELL, AND THAT IS AN UPSTREAM DEFECT RATHER THAN A LIMIT ON THE
## READING. The simulation divides by `tot + EPS_V` inside a branch already
## gated on `tot > EPS_V`, so the epsilon is redundant where it is applied and
## acts as a mass sink: the sum is exactly `tot / (tot + EPS_V)`, and a cell
## whose biomass sits near the gate loses part of its composition. 16 of
## `deepest_winter`'s 5,612 covered cells sum below 0.99 at day 22 and the worst
## sums 0.696. It is a known defect with a known fix that has to wait -- it
## moves 19 of 33 state arrays, so it breaks M0 bit-comparability and lands with
## M1. The population grows with run length, so the guard below WILL eventually
## fail for a real reason, and the threshold is not what to change when it does.
##
## The contract declares both as `fraction` in [0, 1] and says what neither is
## a fraction OF, so the reading rests on the property rather than on the
## declaration -- and `test_pft_fractions_are_a_composition_of_the_cover`
## asserts that property over the shipped fixture. If a later fixture stops
## summing to one, that test fails and this reading is what has to be revisited.
##
## What it cost while it was wrong: every implied-instance count in
## `measurements/scatter_cost.json` and `scatter_bands.json` was inflated by
## 1/(1 - bare), which is 1.9x on the basin mean and about 20x in the sparsest
## cells. Height too -- biomass per covered area was divided by a share instead
## of by an area.
static func ground_cover(share: float, bare: float) -> float:
    if is_nan(share) or is_nan(bare):
        return NAN
    return clampf(share, 0.0, 1.0) * clampf(1.0 - bare, 0.0, 1.0)


## The share of a texel's implied stand a schedule keeps at this distance.
##
## Bands are read in order and the FIRST whose `to_m` the distance is inside
## wins, so a schedule is written near-to-far and a distance past the last band
## keeps nothing. An empty schedule keeps everything, which is what makes the
## default identical to having no schedule at all rather than merely similar.
static func keep_at(distance_m: float, bands: Array) -> float:
    if bands.is_empty():
        return 1.0
    for b in bands:
        if distance_m <= float((b as Dictionary).get("to_m", 0.0)):
            return clampf(float((b as Dictionary).get("keep", 0.0)), 0.0, 1.0)
    return 0.0


## Height and crown for one cell's worth of one life form, both inside the
## family's declared range by construction.
##
## `t` for each axis is a normalised position in a wire quantity, and the two
## quantities are different: cover fraction for width, biomass per covered area
## for height. Deriving both from one quantity would make the two axes one axis
## wearing two names.
func parameters_for(life_form: String, fraction: float, biomass: float,
                    biomass_hi: float) -> Dictionary:
    var h_range := _fs.range_of(life_form, "height_m")
    var c_range := _fs.range_of(life_form, "crown_m")
    if h_range.is_empty() or c_range.is_empty():
        return {"ok": false, "why": "%s declares no height or crown range" % life_form}
    if fraction <= 0.0:
        return {"ok": false, "why": "no cover"}
    var per_covered := biomass / fraction
    var t_h: float = 0.0 if biomass_hi <= 0.0 else clampf(per_covered / biomass_hi, 0.0, 1.0)
    var t_c: float = clampf(fraction, 0.0, 1.0)
    return {
        "ok": true,
        "height_m": lerpf(float(h_range["min"]), float(h_range["max"]), t_h),
        "crown_m": lerpf(float(c_range["min"]), float(c_range["max"]), t_c),
        "t_height": t_h,
        "t_crown": t_c,
    }


## How many instances a frame can hold, at the mix these families imply.
##
## Priced through `measurements/render_cost.json` rather than assumed. Without
## the measurement there is no budget and the scatter says so instead of
## inventing one -- which is §19.8.9's whole point, one milestone along.
func _affordable(groups: PackedStringArray, implied: Dictionary) -> Dictionary:
    if _fc == null or not _fc.is_loaded():
        return {"ok": false, "instances": 0.0,
                "why": ("no frame-cost measurement, so no budget. "
                        + ("" if _fc == null else _fc.why_absent))}
    var total := 0.0
    var weighted_ns := 0.0
    for g in groups:
        var n := float(implied.get(g, 0.0))
        if n <= 0.0 or not _fs.has(g):
            continue
        var per := _fc.per_instance_ns(_fs.triangles_of(g))
        if not bool(per["ok"]):
            return {"ok": false, "instances": 0.0, "why": str(per["why"])}
        total += n
        weighted_ns += n * float(per["ns"])
    if total <= 0.0:
        return {"ok": true, "instances": 0.0, "why": "nothing implied"}
    var mean_ns := weighted_ns / total
    var affordable := _fc.budget_ms * 1.0e6 / mean_ns
    return {
        "ok": true,
        "instances": affordable,
        "budget_ms": _fc.budget_ms,
        "mean_ns_per_instance": mean_ns,
        "implied_total": total,
        "implied_ms": weighted_ns / 1.0e6,
        "measured_on": str(_fc.host.get("gpu", "?")) + " / "
                + str(_fc.host.get("rendering_method", "?")),
        "predicted_from": ("render_cost.json's empty-stage coefficient, which is a FLOOR and "
                + "not a forecast: measured against a real frame it under-predicts by about "
                + "%sx, so a scatter thinned to fit %s ms lands nearer %s ms. The correction "
                        % [String.num(EMPTY_STAGE_UNDER_PREDICTS, 2),
                                String.num(_fc.budget_ms, 1),
                                String.num(_fc.budget_ms * EMPTY_STAGE_UNDER_PREDICTS, 1)]
                + "is not applied here; the coefficient is §19.8.9's."),
        "budget_ms_if_corrected": _fc.budget_ms / EMPTY_STAGE_UNDER_PREDICTS,
    }


## A cell's own yearly trough and peak for one life form's biomass.
##
## PHENOLOGY IS RELATIVE TO THE CELL, NOT TO THE ROW. Normalised over the row's
## realised range instead, a cell that never carries much biomass would read as
## permanently wintering, and a productive one as permanently at peak -- which
## is a statement about where a cell sits in the basin, not about where it sits
## in its year. The seasonal signal is the cell against itself.
## Public, because the far-field tint needs THIS rule and not a copy of it.
## Candidate #1 replaces instances with a per-cell colour, and the phenology
## that colour is mixed by has to be the phenology the instances beside it are
## mixed by, or the seam is a colour step whatever else is right.
func season_range(window: String, row: String, group: int) -> Dictionary:
    return _season_range(window, row, group)


func _season_range(window: String, row: String, group: int) -> Dictionary:
    var key := "%s|%s|%d" % [window, row, group]
    if _season.has(key):
        return _season[key]
    var n_days := _fl.days(window, row)
    var lo := PackedFloat64Array()
    var hi := PackedFloat64Array()
    var day := 0
    while day < n_days:
        var vals := _fl.day_values(window, row, day, group)
        if lo.is_empty():
            lo = vals.duplicate()
            hi = vals.duplicate()
        else:
            for c in vals.size():
                var v := vals[c]
                if is_nan(v):
                    continue
                if is_nan(lo[c]) or v < lo[c]:
                    lo[c] = v
                if is_nan(hi[c]) or v > hi[c]:
                    hi[c] = v
        day += PHENOLOGY_SAMPLE_STRIDE
    var out := {"lo": lo, "hi": hi, "days_sampled": int(ceil(float(n_days) / float(PHENOLOGY_SAMPLE_STRIDE)))}
    _season[key] = out
    return out


## Where today sits between this cell's own trough and peak, in [0, 1].
##
## A cell whose biomass does not move across the window has trough == peak ==
## today, and the ratio's limit there is 1: the day's value IS the cell's
## maximum. That is the honest degenerate answer rather than a chosen midpoint,
## and the count of such cells travels in the report.
func phenology_for(season: Dictionary, cell: int, today: float) -> float:
    var lo: PackedFloat64Array = season["lo"]
    var hi: PackedFloat64Array = season["hi"]
    if cell >= lo.size() or cell >= hi.size() or is_nan(today):
        return 1.0
    var span := hi[cell] - lo[cell]
    if is_nan(span) or span <= 0.0:
        return 1.0
    return clampf((today - lo[cell]) / span, 0.0, 1.0)


func _row_hi(window: String, row: String) -> float:
    var rows: Dictionary = _fl.manifest.get("client_form", {}).get("rows", {})
    var d: Variant = rows.get("%s/%s" % [window, row], null)
    return 0.0 if d == null else float(d["hi"])
