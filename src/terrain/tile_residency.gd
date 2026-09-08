class_name TileResidency
extends RefCounted

## WHICH TILES TO HOLD, AND WHEN TO REBUILD. The streaming decisions, kept in
## one object so that "what is the client holding" has an answer that is not
## spread across a mesh builder and a view.
##
## THE FOOTPRINT IS DERIVED, NOT TUNED. Three distances decide everything here
## and only one of them is chosen:
##
##   NEAR_FIELD_M  480 -- the disc `tools/free_flight.gd` scatters within and
##                        `measure_relief` measures in. It is what a standing
##                        body has in front of it, and it is the distance the
##                        acceptance metric is stated over.
##   BLEND_M      1000 -- the overview's own pixel. The patch ramps to the
##                        coarse surface across it, so the two agree at the
##                        scale the coarse surface is actually resolved at
##                        rather than over some fraction of a radius.
##   PATCH_HALF_M 4000 -- the one choice. It is the overview mesh's own draw
##                        step (1,000 m texels at stride 4), so the patch
##                        covers whole coarse quads and its rim runs along
##                        their edges.
##
## and the rebuild distance falls out: KEEP_M is what is left of the half
## extent once the blend ring and the body's own near field are taken out of
## it. Stand anywhere within KEEP_M of the patch's centre and the whole near
## field is inside fully refined ground. That is the property; the number is
## its consequence, and moving PATCH_HALF_M moves it without anything else
## needing to be re-tuned.
##
## THE CENTRE IS SNAPPED TO THE LEVEL'S OWN TEXEL GRID, and that is what makes
## a rebuild safe. Every patch anywhere samples the same world positions, so
## two patches built around two observer positions carry IDENTICAL heights at
## every vertex they share in their interiors -- a rebuild adds and drops rim,
## and moves nothing. Without the snap each rebuild resamples the ground half
## a texel over and the near field shimmers on every step.
##
## A FOURTH STATE, KEPT APART FROM THE THREE ABSENCES.
##
##   EMPTY_GROUND -- no tile was ever written here. A fact about the basin.
##   NOT_FETCHED  -- keyed, not on this disk. A fact about this clone.
##   NOT_LOADED   -- on the disk, not decoded yet. A fact about this MOMENT,
##                   and the only one of the four that resolves on its own.
##   RESIDENT     -- decoded and in hand.
##
## The distinction is not bookkeeping. A tile in flight that reads as empty
## ground puts a hole -- or, here, a fall back to the coarse surface -- into
## the near field and reports it as terrain that was never there, so the
## picture quietly flattens while every count says healthy. It is separated
## here rather than added to `TilePyramid.availability` because that method
## answers from the pin and the disk, both of which are the same next frame,
## and this one is not.

const RESIDENT := "RESIDENT"
const NOT_LOADED := "NOT_LOADED"

const NEAR_FIELD_M := 480.0
const BLEND_M := 1000.0
const PATCH_HALF_M := 4000.0
const KEEP_M := PATCH_HALF_M - BLEND_M - NEAR_FIELD_M

## Tiles decoded per pump. Two, because one 512x512 decode is 262,144
## per-pixel reads and a frame has room for about that much; the point of a
## budget is that `NOT_LOADED` is a state the rest of the code actually has to
## survive rather than one it can assume away.
const DECODE_BUDGET := 2

var _tp: TilePyramid = null
## Where the patch currently standing was centred, and at which level.
var centre := Vector2.ZERO
var z: int = 0
var has_centre := false


static func over(tp: TilePyramid) -> TileResidency:
    var r := TileResidency.new()
    r._tp = tp
    if tp != null:
        # A 8,000 m patch at 100 m is 80 texels and a tile is 512, so the
        # footprint is at most 2x2 -- but it is asked for rather than assumed,
        # because a coarser level covers the same metres in fewer texels and a
        # finer product would cover it in more.
        tp.set_capacity(maxi(tp.capacity(), 9))
    return r


func pyramid() -> TilePyramid:
    return _tp


## THE NEAREST LEVEL TEXEL CENTRE. Everything else about a patch follows from
## its centre being on the grid, so the snap is a method rather than a line
## inside the builder: the measurement, the view and the test all have to use
## the same one or they are not measuring the same patch.
func snap(w: Vector2, z_: int) -> Vector2:
    if _tp == null:
        return w
    var px := _tp.pixel_size_of(z_)
    if is_nan(px) or px <= 0.0:
        return w
    # Through the grid's double-precision corner, not the Vector2 one: a
    # snapped centre that is an eighth of a metre off the grid puts every
    # vertex of every patch an eighth of a metre off it too.
    var ix := int(round((w.x - _tp.origin_x) / px - 0.5))
    var iy := int(round((_tp.origin_y - w.y) / px - 0.5))
    return Vector2(_tp.origin_x + (float(ix) + 0.5) * px,
                   _tp.origin_y - (float(iy) + 0.5) * px)


## How many texels of level `z_` reach PATCH_HALF_M, and therefore what the
## patch's half extent actually is. An exact multiple of the texel size, so
## the outermost ring of vertices sits exactly at the half extent and the
## blend weight there is exactly zero rather than nearly.
func reach_texels(z_: int) -> int:
    var px := _tp.pixel_size_of(z_) if _tp != null else NAN
    if is_nan(px) or px <= 0.0:
        return 0
    return int(PATCH_HALF_M / px)


func half_extent_m(z_: int) -> float:
    var px := _tp.pixel_size_of(z_) if _tp != null else NAN
    if is_nan(px) or px <= 0.0:
        return 0.0
    return float(reach_texels(z_)) * px


## The tile keys a patch at this centre and level touches. Corners of the
## square, expanded to whole tiles: a patch is at most 2x2 tiles at z=0 and
## one tile above that, and the four corners name every tile a rectangle
## crosses because tiles are a rectangular grid.
func keys_for(centre_: Vector2, z_: int) -> PackedStringArray:
    var out := PackedStringArray()
    if _tp == null:
        return out
    var half := half_extent_m(z_)
    var seen := {}
    for sy in [-1.0, 1.0]:
        for sx in [-1.0, 1.0]:
            var at := _tp.locate(centre_.x + sx * half, centre_.y + sy * half, z_)
            if not bool(at.get("ok", false)):
                continue
            var k := str(at["key"])
            if not seen.has(k):
                seen[k] = true
                out.append(k)
    return out


## Which of the four states one key is in.
func state(key: String) -> String:
    if _tp == null:
        return TilePyramid.NOT_FETCHED
    var a := _tp.availability(key)
    if a != TilePyramid.PRESENT:
        return a
    return RESIDENT if _tp.is_warm(key) else NOT_LOADED


## THE FINEST LEVEL WHOSE TILES THIS CLONE ACTUALLY HAS, and the reason this
## is a search rather than a constant.
##
## `z = 0` IS THE FINEST. Read off the pin's `levels[]` and sorted, never
## assumed, because the inverted polarity is the one mistake here that hides:
## a streaming layer that starts at the coarse end loads 3,200 m tiles into
## the near field and looks exactly like a pyramid that did not help.
##
## EMPTY_GROUND does not disqualify a level -- there is no tile because there
## is no ground, and the patch reproduces the coarse surface there. NOT_FETCHED
## does, because this clone cannot draw what it does not have, and NOT_LOADED
## does not either: it resolves on its own, and the caller finds out from
## `pump` whether the patch can be built yet.
func level_for(centre_: Vector2) -> int:
    if _tp == null:
        return -1
    var zs: Array = []
    for lv in _tp.levels:
        zs.append(int((lv as Dictionary)["z"]))
    zs.sort()
    var best := -1
    for zi in zs:
        var px := _tp.pixel_size_of(int(zi))
        if is_nan(px) or px <= 0.0:
            continue
        var keys := keys_for(centre_, int(zi))
        if keys.is_empty():
            continue
        var ok := true
        for k in keys:
            if _tp.availability(k) == TilePyramid.NOT_FETCHED:
                ok = false
                break
        if ok:
            best = int(zi)
            break
    return best


## Spend up to `budget` decodes on the tiles a patch here would need, and
## report where that leaves it. `ready` is the whole answer a caller needs:
## every tile that could be resident is.
func pump(centre_: Vector2, z_: int, budget: int = DECODE_BUDGET) -> Dictionary:
    var keys := keys_for(centre_, z_)
    var spent := 0
    var tally := {RESIDENT: 0, NOT_LOADED: 0,
                  TilePyramid.EMPTY_GROUND: 0, TilePyramid.NOT_FETCHED: 0}
    for k in keys:
        var st := state(k)
        if st == NOT_LOADED and spent < budget:
            if _tp.warm(k):
                st = RESIDENT
            spent += 1
        tally[st] = int(tally[st]) + 1
    return {
        "z": z_,
        "keys": keys,
        "decoded_now": spent,
        "resident": int(tally[RESIDENT]),
        "not_loaded": int(tally[NOT_LOADED]),
        "empty_ground": int(tally[TilePyramid.EMPTY_GROUND]),
        "not_fetched": int(tally[TilePyramid.NOT_FETCHED]),
        # NOT "no tile is missing". A tile still in flight is not empty ground
        # and the patch must not be built as though it were, which is the
        # whole reason the fourth state exists.
        "ready": int(tally[NOT_LOADED]) == 0,
    }


## Whether the patch standing now still covers this observer's near field.
##
## HYSTERESIS, AND THE NUMBER IS DERIVED. Rebuilding on any movement rebuilds
## every frame; rebuilding only when the observer leaves the patch rebuilds
## after the near field has already run off the refined ground. KEEP_M is the
## distance at which the near field is about to touch the blend ring, so the
## rebuild happens while the picture is still correct.
func needs_rebuild(observer: Vector2) -> bool:
    if not has_centre:
        return true
    return (observer - centre).length() > KEEP_M


## Record what was actually built, so `needs_rebuild` is answering about the
## patch that is drawn rather than about one that was planned.
func settled(centre_: Vector2, z_: int) -> void:
    centre = centre_
    z = z_
    has_centre = true


func forget() -> void:
    has_centre = false
