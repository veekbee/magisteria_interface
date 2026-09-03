class_name ResidenceLayer
extends RefCounted

## The residence key layer: every overview pixel's `(node, band)`. M2's join.
##
## Decision 891 makes residence server-authoritative -- the client RECEIVES it
## and never computes it. This class decodes; it does not resolve.
##
## Aligned pixel-for-pixel with `heightfield_overview.png` by construction, not
## by coincidence: the simulation evaluates residence on the terrain manifest's
## own transform rather than deriving a matching grid. Two independently
## derived grids agree until one changes a rounding rule, and the failure --
## every field shifted one pixel against its own terrain -- is invisible.
##
## Encoding mirrors the heightfield's, for the same reason: `R * 256 + G` is
## the node index (0 = outside the basin), `B` is `band + 1` (0 = no band).

var width: int = 0
var height: int = 0
var node_of_index: Dictionary = {}      ## int -> huc10 id string

var _node: PackedInt32Array = PackedInt32Array()
var _band: PackedByteArray = PackedByteArray()


static func load_from(manifest: Dictionary, image_path: String) -> ResidenceLayer:
    var rl := ResidenceLayer.new()
    var cl: Dictionary = manifest.get("client_layer", {})
    rl.width = int(cl.get("width", 0))
    rl.height = int(cl.get("height", 0))
    for k in manifest.get("node_index", {}):
        rl.node_of_index[int(k)] = str(manifest["node_index"][k])

    var res: Resource = load(image_path)
    if res == null or not res.has_method("get_image"):
        push_error("residence: cannot load %s" % image_path)
        return rl
    var img: Image = res.get_image()
    var fmt := img.get_format()
    if fmt != Image.FORMAT_RGB8 and fmt != Image.FORMAT_RGBA8:
        push_error(("residence: %s imported as format %d. The node index is carried in "
                + "the R and G BYTES; a compressed import would silently rename every "
                + "pixel's node.") % [image_path, fmt])
        return rl
    if img.get_width() != rl.width or img.get_height() != rl.height:
        push_error("residence: image %dx%d, manifest says %dx%d"
                % [img.get_width(), img.get_height(), rl.width, rl.height])
        return rl

    rl._node.resize(rl.width * rl.height)
    rl._band.resize(rl.width * rl.height)
    for y in rl.height:
        for x in rl.width:
            var c := img.get_pixel(x, y)
            var i := y * rl.width + x
            rl._node[i] = int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0))
            rl._band[i] = int(round(c.b * 255.0))
    return rl


func is_loaded() -> bool:
    return width > 0 and _node.size() == width * height


## `[node_index, band]`, or `[]` where the pixel has no residence. An empty
## return is the honest answer for the 4,973 overview pixels that carry terrain
## and no key -- a default of node 0 band 0 would colour them as if they were a
## real place.
func key_at(x: int, y: int) -> Array:
    if x < 0 or y < 0 or x >= width or y >= height:
        return []
    var i := y * width + x
    if _node[i] == 0 or _band[i] == 0:
        return []
    return [_node[i], int(_band[i]) - 1]


func huc10_at(x: int, y: int) -> String:
    var k := key_at(x, y)
    if k.is_empty():
        return ""
    return node_of_index.get(k[0], "")
