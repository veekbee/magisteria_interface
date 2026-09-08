#!/usr/bin/env python3
"""
vendor_tiles.py -- write the terrain tile pyramid's PIN from a host.

WHY THIS IS A CLIENT-SIDE TOOL. `COLLABORATION.md` §5.1a's `[FIX, §23.912]`
records a producing-side manifest emitter written against that section and
retired before it landed: the pins already carry `files: {name: sha256}`, and
those digests are computed CLIENT-SIDE at vendor time by `vendor_fixture.py`
and its siblings. A pin is the claim the client makes about bytes it holds, so
the client is the side that can make it. This is that sibling for the pyramid.

WHAT IT WRITES, AND WHY IT IS ITS OWN PIN RATHER THAN A BLOCK IN THE TERRAIN
EXPORT'S. §5.1a rules the manifest is the pin that already describes the
artefact, and the judgement call here is whether the pyramid is that artefact
or part of the terrain export. It is written as its own for three reasons, each
of which is a way the other choice goes wrong:

  * THE TILES DO NOT DECODE WITH THE OVERVIEW'S CONSTANTS. Both grids resample
    with `average`, which pulls extremes in by an amount that depends on pixel
    footprint, and the native grid measures about 53 m higher at the top.
    Filing two encodings under one pin invites the one mistake that is silent:
    a clipped code is a valid code, so decoding a tile with the overview's pair
    flattens the real peaks and nothing reports it.
  * `assets/terrain/PIN` is HAND-MAINTAINED and says so -- its `cross_repo`
    block has no emitter and its own note records that a hand-added block did
    not survive the first re-vendor of the contours. Writing 496 machine rows
    into it is how the hand-maintained half gets lost on the next run.
  * The pyramid versions separately. It is `terrain-tiles-v1` at the host and
    can be re-emitted without the overview moving.

It is the same vocabulary and the same fields, which is what §5.1a actually
requires; it is not a second provenance language.

THE KEY DOES DOUBLE DUTY, and that decides where `host_base` is cut. A row's
key is the destination path relative to the pin AND the suffix appended to
`host_base`. So a pin at `assets/terrain/tiles/PIN` takes keys like
`0/12_0.png` and a base ending `.../tiles/`; the URLs are identical either way,
but the split point is a consequence of where the pin sits rather than a free
choice.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Optional, Sequence

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / "assets/terrain/tiles/PIN"


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def keys_from(report: dict) -> list[str]:
    """The tile keys the producing run says it wrote, in level order.

    Read from the run's own report rather than from a directory walk. A walk
    reports what is on this disk, which is the same answer only while nothing
    has gone missing -- and telling *nothing was emitted here* from *this file
    did not arrive* is the whole of §5.1a's absence semantics."""
    out = []
    for level in report.get("levels", []):
        z = int(level["z"])
        for key in level.get("keys", []):
            out.append(f"{z}/{key}.png")
    return out


def build(src: Path, host_base: Optional[str], source_commit: Optional[str]) -> dict:
    report = json.loads((src / "emitted.json").read_text())
    if not report.get("emitted", False):
        raise SystemExit(f"{src}/emitted.json says the run emitted nothing")
    keys = keys_from(report)

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
            f"{len(missing)} tiles the run reports writing are not at the host, first: "
            f"{missing[:3]}.\nA pin claiming a digest for bytes nobody holds is a pin that "
            f"cannot be satisfied; fix the host or re-run the emitter.")

    levels = [{k: v for k, v in level.items() if k != "keys"}
              | {"written": len(level.get("keys", []))}
              for level in report.get("levels", [])]

    pin = {
        "_form": ("The claim about the terrain tile pyramid. Same shape as the other pins: "
                  "the files are DATA, this is the claim about them. Every file here is "
                  "FETCHED and none is committed (decision 948) -- 141 MB against a ~10 MB "
                  "threshold -- so `files` is what verifies the bytes and `fetched` is where "
                  "they can currently be found."),
        "artefact": "terrain tile pyramid: the drawn substrate at native resolution",
        "ruled_by": ["decision 890", "decision 948", "decision 972", "§16.5"],
        "source": {
            "repo": "git@github.com:veekbee/magisteria.git",
            "path": "data/terrain_export_output/tiles",
            "_not": ("data/terrain_export_output/heightfield_overview.png -- the 1 km overview, "
                     "which is COMMITTED and decodes with different constants. See `encoding`."),
        },
        "produced_by": "tools/build_terrain_export.py --tiles",
        "source_commit": source_commit,
        "emitted_at_utc": report.get("emitted_at_utc"),
        "vendored_by": "tools/vendor_tiles.py",
        "grid": {
            "naming": report.get("naming"),
            "z_polarity": report.get("z_polarity"),
            "origin": report.get("origin"),
            "crs": report.get("crs"),
            "native_pixel_size_m": report.get("native_pixel_size_m"),
            "levels": levels,
            "_keys_are": ("the pin's own `files` keys are `{z}/{x}_{y}.png`, relative to this "
                          "pin. A level's tile that is entirely nodata was never written and "
                          "is not keyed here, so absent-and-unkeyed is empty ground while "
                          "absent-and-keyed is a fetch that has not happened."),
        },
        "encoding": report.get("encoding"),
        "_encoding_note": ("CARRIED HERE BECAUSE THE CLIENT NEEDS IT AND THE COMMITTED EXPORT "
                           "DOES NOT HAVE IT. `terrain_export.json`'s tiles block is the same "
                           "in every clone whether or not a run emitted, so it states the grid "
                           "and not the constants. Decoding a tile with the overview's "
                           "`offset_m`/`scale_m_per_step` clips the basin's real peaks "
                           "SILENTLY, because a clipped code is a valid code."),
        "cross_repo": {
            "_what": ("how each file above could be checked against `source_commit` in a "
                      "simulation checkout. For this artefact the answer is that it cannot "
                      "be, and that is DECLARED rather than left as an empty block a checker "
                      "would read as a missing vendor run."),
            "files": {},
            "not_checkable_because": ("the pyramid is 141 MB and is not committed in the "
                                      "producing repo either -- it is fetched from a host on "
                                      "both sides of the boundary. `git show <commit>:<path>` "
                                      "has nothing to show, so there is no upstream blob to "
                                      "compare against. What verifies these bytes is the "
                                      "digest in `files`, which is the whole of the check "
                                      "decision 948 rules and needs no checkout at all."),
        },
        "files": files,
        "fetched": {
            "_what": ("every row above. None of these bytes is committed; "
                      "tools/fetch_artefacts.py is the only sanctioned way they arrive, and a "
                      "clone with none of them is a working clone."),
            "host_base": host_base,
            "_host_base_is": ("decision 972: a prefix each row's key appends to. NOT "
                              "authoritative -- the digest is the whole of the check -- and a "
                              "row's own `host` overrides it. It exists so that a move of "
                              "hosting stays the one-field edit decision 948 rules, which 496 "
                              "absolute URLs would have quietly stopped being."),
            "total_bytes": total,
            "files": fetched,
        },
    }
    return pin


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--from", dest="src", required=True,
                    help="the host directory holding tiles/ and emitted.json")
    ap.add_argument("--source-commit", default=None,
                    help="the producing repo commit these bytes came to rest at")
    ap.add_argument("--host-base", default=None,
                    help="URL prefix a row's key appends to. Omitting it writes a pin with no "
                         "host, which is a valid clone: the checks that need tiles skip.")
    a = ap.parse_args(argv)

    src = Path(a.src).expanduser().resolve()
    base = a.host_base
    if base and not base.endswith("/"):
        base += "/"
    pin = build(src, base, a.source_commit)
    PIN.parent.mkdir(parents=True, exist_ok=True)
    PIN.write_text(json.dumps(pin, indent=2) + "\n")
    print(f"wrote {PIN.relative_to(ROOT)}: {len(pin['files'])} tiles, "
          f"{pin['fetched']['total_bytes']} bytes, host_base "
          f"{'set' if base else 'NOT SET (a valid clone)'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
