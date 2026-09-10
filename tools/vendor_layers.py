#!/usr/bin/env python3
"""
vendor_layers.py -- write the terrain layer tiles' PIN from a host.

The sibling `vendor_tiles.py` names: §5.1a and §23.912 record a producing-side
manifest emitter retired before it landed, so the digests in a pin are computed
CLIENT-SIDE at vendor time. A pin is the claim the client makes about bytes it
holds, so the client is the side that can make it. The producing manifest tells
us the grid, the encodings and the per-layer statistics; it deliberately does
not tell us the digests.

ONE PIN FOR THREE LAYERS, AND THE JUDGEMENT IS ABOUT WHAT THE ARTEFACT IS.
`vendor_tiles.py` split the pyramid out of the terrain export because the two
decode with different constants and version separately. Neither is true here:
the three layers are one emitting run, one host slot (`terrain-layers-v1`), one
grid read from the height export so a layer tile cannot sit half a pixel off
the height tile beneath it, and they move together. Splitting them into three
pins would make "which run produced this" a question with three answers that
are supposed to agree.

TWO ENCODINGS UNDER ONE PIN IS FINE AND ONE PAIR OF CONSTANTS UNDER TWO
ARTEFACTS IS NOT. That was the tiles' argument and it does not transfer: there
the risk was a SHARED encoding block quietly applying to bytes it did not
describe, and here each layer names its own `encoding_kind` and carries its own
`stats`. A decoder that reads the layer's own block cannot pick up its
neighbour's.

WHAT DOES NOT COME ACROSS. The manifest's `levels[].keys` are the run's own
record of what it wrote, and they become this pin's `files` keys prefixed by
the layer name -- `slope/0/12_0.png`. That prefix is not cosmetic: the key does
double duty as the destination path relative to this pin AND as the suffix
appended to `host_base`, so where the pin sits decides the split point. A pin
at `assets/terrain/layers/PIN` takes `<layer>/{z}/{x}_{y}.png` and a base
ending `.../terrain-layers-v1/`.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Optional, Sequence

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / "assets/terrain/layers/PIN"
MANIFEST = "terrain_layer_tiles.json"


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def keys_from(manifest: dict) -> list[str]:
    """Every layer tile the producing run says it wrote.

    From the run's own report and never from a directory walk, for the reason
    `vendor_tiles.py` gives: a walk answers "what is on this disk", and telling
    *nothing was emitted here* from *this file did not arrive* is the whole of
    §5.1a's absence semantics.
    """
    out = []
    for layer, block in manifest.get("layers", {}).items():
        for level in block.get("levels", []):
            for key in level.get("keys", []):
                out.append(f"{layer}/{key}")
    return out


def build(src: Path, host_base: Optional[str], source_commit: Optional[str],
          source_path: str) -> dict:
    manifest = json.loads((src / MANIFEST).read_text())
    keys = keys_from(manifest)
    if not keys:
        raise SystemExit(f"{src}/{MANIFEST} reports no tiles at all")

    files: dict[str, str] = {}
    fetched: dict[str, dict] = {}
    missing: list[str] = []
    total = 0
    for key in keys:
        p = src / key
        if not p.exists():
            missing.append(key)
            continue
        files[key] = sha256_file(p)
        size = p.stat().st_size
        total += size
        fetched[key] = {"bytes": size}
    if missing:
        raise SystemExit(
            f"{len(missing)} layer tiles the run reports writing are not at the host, first: "
            f"{missing[:3]}.\nA pin claiming a digest for bytes nobody holds is a pin that "
            f"cannot be satisfied; fix the host or re-run the emitter.")

    layers = {}
    for name, block in manifest.get("layers", {}).items():
        levels = [{k: v for k, v in level.items() if k != "keys"}
                  | {"written": len(level.get("keys", []))}
                  for level in block.get("levels", [])]
        layers[name] = {
            "source": block.get("source"),
            "unit": block.get("unit"),
            "note": block.get("note"),
            "encoding_kind": block.get("encoding_kind"),
            "stats": block.get("stats"),
            "levels": levels,
            "bytes": block.get("bytes"),
            # THE MASK GAP, CARRIED RATHER THAN DISCOVERED. A layer is never
            # WIDER than the DEM's mask, so keying on a layer needs no check
            # that terrain exists under it. Narrower is real and per layer:
            # slope loses a one-pixel rim at every nodata boundary because a
            # gradient needs neighbours. A client meeting that as an
            # unexplained hole would have to invent a reason for it.
            "px_dem_has_ground_layer_does_not": block.get("px_dem_has_ground_layer_does_not"),
            "share_dem_has_ground_layer_does_not": block.get(
                "share_dem_has_ground_layer_does_not"),
        }

    pin = {
        "_form": ("The claim about the terrain layer tiles. Same shape as the other pins: the "
                  "files are DATA, this is the claim about them. Every file here is FETCHED "
                  "and none is committed (decision 948) -- 437 MB against a ~10 MB threshold "
                  "-- so `files` is what verifies the bytes and `fetched` is where they can "
                  "currently be found."),
        "artefact": manifest.get("artefact"),
        "ruled_by": manifest.get("ruled_by"),
        "source": {
            "repo": "git@github.com:veekbee/magisteria.git",
            # PASSED IN, NEVER HARDCODED, AND THAT COST A WRONG PIN ONCE.
            # This read `data/terrain_layer_tiles_output` as a literal. When
            # the producer emitted a four-layer pyramid into a NEW directory
            # -- its own, not a rewrite -- everything else in the pin followed
            # the bytes and this one field went on naming the old one. Nothing
            # catches it: `cross_repo` declares this artefact not checkable
            # against a checkout, so the path is pure provenance and no check
            # reads it. What made it matter was that the producing side had
            # said it would delete the old directory once this field named the
            # new one.
            #
            # It is REQUIRED rather than defaulted, because only the operator
            # knows which upstream directory the bytes came from: by vendor
            # time they have been copied to a host slot whose name is the
            # host's, not the producer's, so there is nothing here to infer it
            # from.
            "path": source_path,
            "_not": ("data/terrain_layers_output -- the GeoTIFFs these are derived from. Those "
                     "are named `_100m` and are NOT 100 m: their pixel is 92.6185 x 82.7865 m, "
                     "non-square. These tiles are reprojected onto the height pyramid's grid, "
                     "not relabelled."),
        },
        "produced_by": manifest.get("generated_by"),
        "source_commit": source_commit,
        "emitted_at_utc": manifest.get("generated_at_utc"),
        "vendored_by": "tools/vendor_layers.py",
        "grid": manifest.get("grid"),
        "_grid_note": ("READ FROM THE HEIGHT EXPORT BY THE PRODUCER, which is why the origin, "
                       "tile_px, naming, z-polarity and per-level tile counts are identical to "
                       "`assets/terrain/tiles/PIN`'s. A layer tile half a pixel off the height "
                       "tile beneath it is a misalignment nothing reports, because both look "
                       "like data."),
        "encodings": manifest.get("encodings"),
        "_encoding_note": ("CARRIED HERE BECAUSE THE CLIENT NEEDS IT AND NOTHING COMMITTED HAS "
                           "IT. Two kinds, and `aspect` is the one to read: it ships as "
                           "sin/cos with a THREE-state validity byte and never as an angle. "
                           "Check B before the components -- where B is 0 or 128 the "
                           "components are zeroed, and zeroed components decode to 225 "
                           "degrees, a perfectly plausible south-west. That is the one reading "
                           "that would look right and be meaningless."),
        "cross_repo": {
            "_what": ("how each file above could be checked against `source_commit` in a "
                      "simulation checkout. For this artefact the answer is that it cannot be, "
                      "and that is DECLARED rather than left as an empty block a checker would "
                      "read as a missing vendor run."),
            "files": {},
            "not_checkable_because": ("the layer tiles are 437 MB and are not committed in the "
                                      "producing repo either -- they are fetched from a host "
                                      "on both sides of the boundary. `git show "
                                      "<commit>:<path>` has nothing to show, so there is no "
                                      "upstream blob to compare against. What verifies these "
                                      "bytes is the digest in `files`, which is the whole of "
                                      "the check decision 948 rules and needs no checkout at "
                                      "all."),
        },
        "layers": layers,
        "files": files,
        "fetched": {
            "_what": ("every row above. None of these bytes is committed; "
                      "tools/fetch_artefacts.py is the only sanctioned way they arrive, and a "
                      "clone with none of them is a working clone."),
            "host_base": host_base,
            "_host_base_is": ("decision 972: a prefix each row's key appends to. NOT "
                              "authoritative -- the digest is the whole of the check -- and a "
                              "row's own `host` overrides it. It exists so that a move of "
                              "hosting stays the one-field edit decision 948 rules, which "
                              "1,038 absolute URLs would have quietly stopped being."),
            "total_bytes": total,
            "files": fetched,
        },
    }
    return pin


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--from", dest="src", required=True,
                    help="the host directory holding <layer>/ and " + MANIFEST)
    ap.add_argument("--source-commit", default=None,
                    help="the producing repo commit these bytes came to rest at")
    ap.add_argument("--source-path", required=True,
                    help="the producing repo's path these bytes were emitted to, "
                         "repo-relative. Required: it cannot be inferred from --from, which "
                         "names a host slot, and nothing downstream checks it.")
    ap.add_argument("--host-base", default=None,
                    help="URL prefix a row's key appends to. Omitting it writes a pin with no "
                         "host, which is a valid clone: the checks that need layers skip.")
    a = ap.parse_args(argv)

    src = Path(a.src).expanduser().resolve()
    base = a.host_base
    if base and not base.endswith("/"):
        base += "/"
    pin = build(src, base, a.source_commit, a.source_path)
    PIN.parent.mkdir(parents=True, exist_ok=True)
    PIN.write_text(json.dumps(pin, indent=2) + "\n")
    print(f"wrote {PIN.relative_to(ROOT)}: {len(pin['files'])} tiles over "
          f"{len(pin['layers'])} layers, {pin['fetched']['total_bytes']} bytes, host_base "
          f"{'set' if base else 'NOT SET (a valid clone)'}")
    print(f"  source: {pin['source']['path']} at {pin['source_commit']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
