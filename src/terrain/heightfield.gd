class_name Heightfield
extends RefCounted

## The terrain export's heightfield, decoded and sampled.
##
## THE ENCODING IS NOT A DETAIL. Height arrives in two 8-bit channels because
## a single 16-bit PNG channel does not survive `Image.load()` -- the engine
## returns FORMAT_L8 and discards the low byte, which over this basin is a
## 17 m step and visible terracing. `R * 256 + G` reconstructs the code; `B`
## is validity, 255 where there is ground. The manifest states the formula and
## this file follows it rather than restating a constant.
##
## WHY BICUBIC. §16.5 records nearest-neighbour terracing as the first visible
## defect of a heightfield, and a mesh built at any resolution other than the
## texture's own resamples. Bilinear removes the steps and leaves creases along
## every texel boundary; Catmull-Rom is C1 across them, which is what a
## hillshade needs -- shading reads the *derivative*, so a discontinuity
## invisible in the surface is a hard line in the light.
##
## Sampling outside the valid region returns NAN rather than 0.0. A zero here
## is sea level, which is a real height in this basin (its minimum is -6.39 m),
## so a sentinel that is also a value would put a plateau at the coast.

const NODATA_R := 0

var width: int = 0
var height: int = 0
var offset_m: float = 0.0
var scale_m: float = 0.0
var pixel_size_m: float = 0.0
## World-space position of the raster's top-left corner (EPSG:5070 metres).
var origin_x: float = 0.0
var origin_y: float = 0.0

var _codes: PackedFloat32Array = PackedFloat32Array()   ## raw 16-bit codes
var _valid: PackedByteArray = PackedByteArray()


## Build from the vendored export. `manifest` is the parsed terrain_export.json.
static func load_from(manifest: Dictionary, image_path: String) -> Heightfield:
    var hf := Heightfield.new()
    var m: Dictionary = manifest.get("heightfield", {})
    var enc: Dictionary = m.get("encoding", {})
    hf.width = int(m.get("width", 0))
    hf.height = int(m.get("height", 0))
    hf.offset_m = float(enc.get("offset_m", 0.0))
    hf.scale_m = float(enc.get("scale_m_per_step", 0.0))
    hf.pixel_size_m = float(m.get("pixel_size_m", 0.0))
    var tr: Array = m.get("transform", [])
    if tr.size() >= 6:
        hf.origin_x = float(tr[2])
        hf.origin_y = float(tr[5])

    # Loaded as a RESOURCE, not with `Image.load()`. The engine warns that
    # loading a res:// path as an image file "will not work on export" -- the
    # source PNG is not shipped, only the imported texture -- so the direct
    # call works headlessly and in the editor and fails in a build, which is
    # the worst place to find out.
    var img: Image = null
    var res: Resource = load(image_path)
    if res != null and res.has_method("get_image"):
        img = res.get_image()
    if img == null:
        push_error("heightfield: cannot load %s as a texture resource" % image_path)
        return hf

    # THE FORMAT IS ASSERTED, because height lives in the bytes. A
    # VRAM-compressed import (S3TC, BPTC, ETC) is lossy per channel, which
    # would corrupt heights while every file checksum still passed -- the
    # failure is invisible to the pin and visible only as wrong terrain.
    var fmt := img.get_format()
    if fmt != Image.FORMAT_RGB8 and fmt != Image.FORMAT_RGBA8:
        push_error(("heightfield: %s imported as format %d; height is encoded in "
                + "the R and G BYTES and only an uncompressed 8-bit format "
                + "preserves them. Set the import to Lossless.") % [image_path, fmt])
        return hf
    if img.get_width() != hf.width or img.get_height() != hf.height:
        push_error("heightfield: image is %dx%d, manifest says %dx%d"
                % [img.get_width(), img.get_height(), hf.width, hf.height])
        return hf

    hf._codes.resize(hf.width * hf.height)
    hf._valid.resize(hf.width * hf.height)
    for y in hf.height:
        for x in hf.width:
            var c := img.get_pixel(x, y)
            var i := y * hf.width + x
            hf._codes[i] = float(int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0)))
            hf._valid[i] = 1 if c.b > 0.5 else 0
    return hf


func is_loaded() -> bool:
    return width > 0 and _codes.size() == width * height


## Height in metres at integer texel (x, y), or NAN outside the valid region.
func height_at_texel(x: int, y: int) -> float:
    if x < 0 or y < 0 or x >= width or y >= height:
        return NAN
    var i := y * width + x
    if _valid[i] == 0:
        return NAN
    return offset_m + _codes[i] * scale_m


## One-dimensional Catmull-Rom through four samples, t in [0, 1] between p1, p2.
static func _catmull(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
    var t2 := t * t
    var t3 := t2 * t
    return 0.5 * ((2.0 * p1)
            + (-p0 + p2) * t
            + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
            + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Height in metres at a continuous texel coordinate, bicubic.
##
## Returns NAN if any of the sixteen taps is outside the valid region. That is
## deliberate and it costs a one-texel border of terrain: interpolating across
## a nodata edge invents a slope out of a sentinel, and a fabricated cliff at
## the basin boundary is worse than an absent one.
func height_at(fx: float, fy: float) -> float:
    var x0 := int(floor(fx))
    var y0 := int(floor(fy))
    var tx := fx - float(x0)
    var ty := fy - float(y0)
    var rows := PackedFloat64Array()
    rows.resize(4)
    for j in 4:
        var cols := PackedFloat64Array()
        cols.resize(4)
        for i in 4:
            var h := height_at_texel(x0 - 1 + i, y0 - 1 + j)
            if is_nan(h):
                return NAN
            cols[i] = h
        rows[j] = _catmull(cols[0], cols[1], cols[2], cols[3], tx)
    return _catmull(rows[0], rows[1], rows[2], rows[3], ty)


## World (EPSG:5070 metres) -> continuous texel coordinate.
##
## The half is the difference between a texel's corner and its CENTRE, and a
## texel coordinate names the centre -- `height_at(0, 0)` is the value of
## texel (0, 0), not a corner between four of them.
func world_to_texel(wx: float, wy: float) -> Vector2:
    return Vector2((wx - origin_x) / pixel_size_m - 0.5,
                   (origin_y - wy) / pixel_size_m - 0.5)


## Its exact inverse: a texel coordinate -> the world position of that texel's
## centre. Here rather than at the call site so the half above has one home.
func texel_to_world(tx: float, ty: float) -> Vector2:
    return Vector2(origin_x + (tx + 0.5) * pixel_size_m,
                   origin_y - (ty + 0.5) * pixel_size_m)


## Height in metres at a world position, bicubic. NAN outside the basin.
func height_at_world(wx: float, wy: float) -> float:
    var t := world_to_texel(wx, wy)
    return height_at(t.x, t.y)
