class_name DressingDraw
extends RefCounted

## WHAT TO PUT ON SCREEN — G-9 W3's drawing layer, kept separate from the scene
## that draws it so that every decision here is testable headless.
##
## The scene owns input, the camera and the slider. This owns NOTHING but
## arithmetic: given a folded state, the committed palette and the committed
## centres, it says which tile gets which colour and where. A `_draw()` that
## also decided colours could only be checked by looking at it, and the owner's
## look is meant to be a ruling on the dressing, not a debugging session on the
## viewer (owner ruling 2059 asks for their ruling, not their debugging).
##
## THE PALETTE IS DATA AND IS NEVER RETYPED (decision 2129 (b), (f)). Class
## names, route-class names, the feature outline, the background and the
## density reference all come from the committed `palette.json`. A class the
## palette does not name draws as its `UNKNOWN` -- which is the renderer's own
## answer for that case, a magenta that announces itself -- and is reported, so
## a class this build has never seen is visible rather than quietly absent.
##
## ⚠ ONE DISPLAY CONSTANT IS COPIED FROM THE RENDERER AND CAN DRIFT. The
## shading darkens toward black as density rises, by `1 - 0.55 * f` where `f` is
## the tile's density over the palette's `density_ref`. `density_ref` IS carried
## in `palette.json`, deliberately, so the reference is data. **The 0.55 is
## not.** It lives in the simulation's renderer as a display constant, and this
## is a second copy of it: if that one changes, this view's shading silently
## stops matching the committed render that the owner may also have seen, and
## nothing anywhere would say so. It is copied rather than invented because
## inventing a different curve would guarantee the mismatch instead of merely
## risking it. **If the two are meant to stay in step, `palette.json` should
## carry the factor as it already carries the reference** -- raised with the
## manager at W3 rather than left in a comment.

## The shading's own factor. See the warning above: this is the renderer's
## display constant, not a value the palette carries.
const DENSITY_DARKEN := 0.55


## A palette colour, darkened toward black as density rises. `f` is clamped.
static func shade(rgb: Array, f: float) -> Color:
    var k := clampf(f, 0.0, 1.0)
    var m := 1.0 - DENSITY_DARKEN * k
    return Color(float(rgb[0]) / 255.0 * m, float(rgb[1]) / 255.0 * m,
            float(rgb[2]) / 255.0 * m)


static func _rgb(palette: Dictionary, group: String, name: String) -> Array:
    var g = palette.get(group, {})
    if typeof(g) == TYPE_DICTIONARY and (g as Dictionary).has(name):
        return (g as Dictionary)[name]
    return palette.get("UNKNOWN", [255, 0, 255])


## One row per drawable tile: {key, color}. A tile whose class is null is NOT
## drawn -- it is ground the dressing has touched but not built on, which the
## renderer also leaves as background -- and that is a measured absence rather
## than missing data, so it is not reported as a problem.
##
## `unknown_classes` collects the classes the palette does not name, so the
## caller can say which rather than only that some existed.
static func tile_rows(fold: Dictionary, palette: Dictionary, density_ref: float,
        unknown_classes: Dictionary = {}) -> Array:
    var out: Array = []
    var pal = palette.get("PALETTE", {})
    var ref := density_ref if density_ref > 0.0 else 1.0
    for key in fold:
        var s: Dictionary = fold[key]
        if s["class"] == null:
            continue
        var cls := str(s["class"])
        if typeof(pal) == TYPE_DICTIONARY and not (pal as Dictionary).has(cls):
            unknown_classes[cls] = true
        var d := float(s["density_per_km2"]) if s["density_per_km2"] != null else 0.0
        out.append({"key": key, "color": shade(_rgb(palette, "PALETTE", cls), d / ref)})
    return out


## A route's colour by its class, from the palette's ROUTE group.
static func route_color(palette: Dictionary, route_class: String) -> Color:
    return shade(_rgb(palette, "ROUTE", route_class), 0.0)


## The palette's feature outline, which is also what a pin is outlined in.
##
## NOT `UNKNOWN`, and that was a correction. `UNKNOWN` is the renderer's magenta
## for a class missing from the palette, so outlining every pin in it would fill
## the owner's screen with the colour that means *something is wrong here*, at
## the one moment the screen has to be trustworthy. `FEATURE_EDGE` is the
## renderer's own outline for a feature's footprint, and the committed
## placeholder pin is a FEATURE pin, so a pin is outlined the way the thing it
## stands for is outlined.
static func edge_color(palette: Dictionary) -> Color:
    var e = palette.get("FEATURE_EDGE", [30, 30, 30])
    return Color(float(e[0]) / 255.0, float(e[1]) / 255.0, float(e[2]) / 255.0)


static func background_color(palette: Dictionary) -> Color:
    var b = palette.get("BACKGROUND", [246, 244, 238])
    return Color(float(b[0]) / 255.0, float(b[1]) / 255.0, float(b[2]) / 255.0)


## The tiles of a footprint that lie on its boundary: those missing a
## four-neighbour. Keys are `DressingFold.tile_key`'s form.
##
## IN TILE-INDEX SPACE AND NOT IN METRES, deliberately. Two tiles are
## neighbours when their `i`/`j` differ by one within the same patch -- but a
## footprint can cross a patch edge, where the indices jump and the metres do
## not. So adjacency is decided on the CENTRES: neighbours are the tiles one
## `tile_m` away. That is the only test that stays true across a patch boundary,
## and a footprint outlined by index arithmetic would show a seam exactly where
## a patch ends, which looks like real geometry and is not.
static func outline_keys(tile_keys: Array, centres: DressingCentres) -> PackedStringArray:
    var t := centres.tile_m
    if not (t > 0.0):
        return PackedStringArray()
    # An exact neighbour index rather than a pairwise scan: every centre is a
    # whole number of tiles from every other, so rounding to the nearest metre
    # is lossless here and two tiles are neighbours when their rounded centres
    # differ by exactly one `tile_m`. A pairwise comparison with a tolerance
    # would be O(n^2) AND would need a fuzz factor to express something that is
    # in fact exact -- and a tolerance invented to paper over a float is how a
    # seam becomes invisible.
    var at := {}
    var mine: Array = []
    for k in tile_keys:
        var c := centres.centre_of(str(k))
        if c.is_empty():
            continue
        var gx := int(round(c[0]))
        var gy := int(round(c[1]))
        at["%d,%d" % [gx, gy]] = true
        mine.append({"key": str(k), "gx": gx, "gy": gy})
    var step := int(round(t))
    var out := PackedStringArray()
    for row: Dictionary in mine:
        var gx: int = row["gx"]
        var gy: int = row["gy"]
        var n := 0
        for d: Array in [[step, 0], [-step, 0], [0, step], [0, -step]]:
            if at.has("%d,%d" % [gx + int(d[0]), gy + int(d[1])]):
                n += 1
        if n < 4:
            out.append(str(row["key"]))
    out.sort()
    return out
