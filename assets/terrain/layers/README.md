# `assets/terrain/layers/` — the three derived terrain layers

**Slope, aspect and distance-to-channel**, on the height pyramid's own grid, fetched by manifest and
never committed (decision 948 — 437 MB against a ~10 MB threshold). `PIN` is the claim about the
bytes; `tools/vendor_layers.py` writes it and `tools/fetch_artefacts.py` brings them in. **A clone
with none of them is a working clone**: `DetailField` falls back to the parent lattice's own gradient
and `classifier_source()` says which it used.

Same origin, same `tile_px`, same `{z}/{x}_{y}.png` naming under a layer name, same z-polarity, and
the same 346 / 102 / 32 / 11 / 4 / 1 tiles per level as `../tiles/`. The producer reads the height
export to get that grid, because a layer tile half a pixel off the height tile beneath it is a
misalignment nothing reports — both look like data.

## `z = 0` is the FINEST level

Inverted from the web-map convention, exactly as the height pyramid is. Read `levels[]`.

## Aspect is a direction pair and never an angle

`R = sin`, `G = cos`, `B = validity`, and **B is read before the components**:

| B | meaning |
|---:|---|
| 0 | no data — outside the basin |
| **128** | in the basin, **aspect undefined — the cell is flat** |
| 255 | aspect valid |

`azimuth = atan2((R − 128) / 127, (G − 128) / 127)`, clockwise from north, **only where `B == 255`**.

Two independent reasons either of which is sufficient. An angle is **circular** — 359.9° and 0.1° are
neighbours on the ground and opposite ends of a linear code, so anything that interpolates reads due
*south* across north. And an angle channel cannot say *no aspect here* without spending a real
direction on it.

**Where B is 0 or 128 the components are zeroed, and zeroed components decode to 225° — a plausible
south-west.** That is the one reading that would look right and be meaningless, so `TerrainLayers`
has no method that returns an azimuth without having consulted B: `aspect_at` returns a *state* and a
number, and the number is NAN in two of the three states.

Flat ground is 704,980 px, **0.98% of valid ground**. Folding it into `no data` would say the basin
has a hole where it has a plateau.

Coarse levels average the **components**, never the angle, so `z ≥ 1` is safe to sample.

## Slope and distance-to-channel are `min + (R·256 + G)·(max−min)/65535`, where `B > 0`

Per layer, from that layer's own `stats` block. The two ranges are three orders of magnitude apart —
0…78.2° against 0…183,725.9 m — so one pair of constants applied to the other's bytes is wrong by
that much with nothing to report it.

## The mask is never wider than the DEM's, and slope's is narrower

A layer never claims ground the client is not drawing, so a consumer can key on a layer without first
asking whether terrain exists under it.

Narrower is real and per layer: **slope has no value on 136,865 of the pyramid's 71,826,193 ground
pixels — 0.19%, about 1,369 km²** — because a gradient needs neighbours and loses a one-pixel rim at
every nodata boundary. Aspect and distance lose none. That rim is a **second, independent** population
where a patch has a layer hole while the ground is drawn, and it does not coincide with the height
nodata.

## These are not the GeoTIFFs they came from

Three things about those files would each have been a silent defect, and the reprojection is what
removes them:

- they are named `_100m` and are **not** 100 m — their pixel is 92.6185 × 82.7865 m, non-square;
- `aspect_100m.tif` **declares no nodata and fills with 0.0**, a legal aspect, over 52.19% of its grid;
- `distance_to_channel_100m.tif` is **finite everywhere**, because a distance transform fills its
  raster — median 115.3 km outside the basin against 6.8 km inside.
