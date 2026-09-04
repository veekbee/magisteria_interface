class_name FieldOverlay
extends RefCounted

## M2: a carried row, one day, as colour on the terrain.
##
## THE CHAIN, and every link is somebody else's ruling. A rendered pixel has a
## residence key (decision 891, server-authoritative, received not computed);
## the key joins to a cell through the fixture's `cell_keys`; the cell indexes
## the day's values; the value maps through a ramp over the row's CONTRACT
## bounds. Nothing here decides what a position resolves to and nothing here
## invents a range.
##
## RAMPS USE CONTRACT BOUNDS, NOT THE DAY'S RANGE. Auto-ranging per day makes
## the scrubber a lie: the colour would mean a different thing in every frame,
## and a field that barely moves would look as dramatic as one that swings. The
## schema declares bounds for exactly this.
##
## NO DATA IS NOT A COLOUR. The 4,973 overview pixels that carry terrain and no
## residence key, and any cell whose value is NAN, are written as fully
## transparent black rather than at the ramp's low end, which would invent a
## measurement.
##
## THAT ALPHA IS CURRENTLY INERT, AND SAYING SO IS BETTER THAN IMPLYING
## OTHERWISE. The terrain material leaves `transparency` at DISABLED, so the
## engine ignores the alpha channel and those texels reach the screen as BLACK
## rather than letting the bare hillshade through. Measured on the running app:
## 105 pixels of a 157,000-pixel frame, because almost every texel with ground
## also has a key and a cell -- so the intent above is unrealised and the cost
## of it is currently negligible.
##
## It stops being negligible the moment a carried row is NAN over an area
## rather than a scatter, because black sits next to this ramp's low end
## (0.267, 0.005, 0.329) and would read as a low value rather than as no value.
## Enabling alpha on the terrain is not a free fix: a transparent material is
## depth-sorted and stops writing depth by default, which changes how the
## vegetation and the flowlines resolve against the ground. That is a decision
## with a picture attached, and it is not made here.

const NODATA := Color(0, 0, 0, 0)

var width: int = 0
var height: int = 0
var resolved_px: int = 0
var nodata_px: int = 0

var _cell_of_px: PackedInt32Array = PackedInt32Array()   ## -1 where unkeyed


## Precompute the pixel -> cell join once. It depends only on the two layers,
## not on which row or day is shown, so doing it per frame would repay nothing.
func bind(rl: ResidenceLayer, fl: FixtureLoader) -> void:
    width = rl.width
    height = rl.height
    _cell_of_px.resize(width * height)
    _cell_of_px.fill(-1)
    resolved_px = 0
    for y in height:
        for x in width:
            var k := rl.key_at(x, y)
            if k.is_empty():
                continue
            var huc: String = rl.node_of_index.get(k[0], "")
            if huc == "":
                continue
            var ci: Variant = fl.cell_of_key.get("%s|%d" % [huc, k[1]], null)
            if ci == null:
                continue
            _cell_of_px[y * width + x] = int(ci)
            resolved_px += 1
    nodata_px = width * height - resolved_px


func is_bound() -> bool:
    return _cell_of_px.size() == width * height and width > 0


## Colour texture for one row-day. `lo`/`hi` are the CONTRACT's bounds.
func texture_for(values: PackedFloat64Array, lo: float, hi: float) -> ImageTexture:
    var span: float = (hi - lo) if hi > lo else 1.0
    var buf := PackedByteArray()
    buf.resize(width * height * 4)
    var painted := 0
    for i in _cell_of_px.size():
        var o := i * 4
        var c := _cell_of_px[i]
        if c < 0 or c >= values.size():
            buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0; buf[o + 3] = 0
            continue
        var v := values[c]
        if is_nan(v):
            buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0; buf[o + 3] = 0
            continue
        var col := ramp(clampf((v - lo) / span, 0.0, 1.0))
        buf[o] = int(col.r * 255.0)
        buf[o + 1] = int(col.g * 255.0)
        buf[o + 2] = int(col.b * 255.0)
        buf[o + 3] = 200
        painted += 1
    var img := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buf)
    return ImageTexture.create_from_image(img)


#: Viridis, sampled at five stops. Chosen for ONE property: its lightness
#: rises monotonically from end to end, so equal steps in the value look like
#: equal steps in the colour.
#:
#: The first version of this ramp went blue -> green -> yellow -> RED, and the
#: test below rejected it. That is the rainbow family, and its lightness
#: reverses at the top: yellow is far lighter than the red after it, so a
#: field would show a bright band partway up its range that corresponds to
#: nothing in the data. That is terracing invented in the colour instead of
#: the geometry -- the same defect §16.5 names for the heightfield, one layer
#: further out -- and it is the reason scientific ramps abandoned rainbow.
const RAMP_STOPS: Array[Color] = [
    Color(0.267, 0.005, 0.329),
    Color(0.229, 0.322, 0.545),
    Color(0.128, 0.567, 0.551),
    Color(0.369, 0.789, 0.383),
    Color(0.993, 0.906, 0.144),
]


static func ramp(t: float) -> Color:
    var u: float = clampf(t, 0.0, 1.0) * float(RAMP_STOPS.size() - 1)
    var i: int = int(floor(u))
    if i >= RAMP_STOPS.size() - 1:
        return RAMP_STOPS[RAMP_STOPS.size() - 1]
    return RAMP_STOPS[i].lerp(RAMP_STOPS[i + 1], u - float(i))
