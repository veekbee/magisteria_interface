#!/usr/bin/env python3
"""
vendor_contours.py -- bring pre-extracted contours across the repo boundary. M4.

Contours are extracted SERVER-SIDE (§16.12.1). What crosses is geometry: arcs
in EPSG:5070 metres plus per-day counts. What does not cross is the band
ladder they were built from -- 16 HUC4 ladders whose base elevations differ --
because that is the generator, and §16.12's whole argument is that a client
holding the generator can read the field anywhere in the region.

THE TWO REFUSALS, AND WHY THEY ARE THE POINT
---------------------------------------------
A contour is a line drawn on terrain, and it is wrong in a way nothing else
catches if either half of that sentence comes from somewhere else.

  1. **Same run as the fixture.** The arcs are the level set of one day of one
     field. Against a fixture from a different run they are a snowline from a
     different winter, drawn over this one's colours, and both look right.

  2. **Same grid as the terrain export.** The arcs were extracted on the
     overview raster's transform. On any other transform they land off their
     own terrain -- §23.828's failure one artefact over, and the reason the
     residence layer asserts alignment rather than assuming it.

Neither is checkable after the fact by looking at the picture, which is what
makes them worth a refusal instead of a note.

Usage (from the client repo root):
    python3 tools/vendor_contours.py --from ../iota_magisteria/data/contour_output \
        --sim ../iota_magisteria
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "assets" / "contours"

#: Keys the client does not get. `generated_from` names paths inside the sim
#: repo, which are not facts about the client's copy; the PIN carries the
#: source commit instead, which is.
NOT_VENDORED = ("generated_from",)


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _json(path: Path) -> dict:
    return json.loads(path.read_text())


def refusals(doc: dict) -> list[str]:
    """What must agree before a line may be drawn on this terrain."""
    out: list[str] = []

    fixture_pin = ROOT / "assets" / "fixture" / "PIN"
    if fixture_pin.exists():
        run = _json(fixture_pin).get("run", {})
        if run and run.get("base_commit") != doc["run"]["base_commit"]:
            out.append(
                "the contours and the vendored fixture come from different runs\n"
                f"    fixture  {run.get('base_commit')}\n"
                f"    contours {doc['run']['base_commit']}\n"
                "  The arcs would be one winter's snowline over another's colours.")

    terrain = ROOT / "assets" / "terrain" / "terrain_export.json"
    if terrain.exists():
        hf = _json(terrain)["heightfield"]
        g = doc["grid"]
        if hf["transform"] != g["transform"]:
            out.append("the contours were extracted on a different transform from the "
                       "vendored terrain export -- every arc would sit off its own ground")
        if [hf["width"], hf["height"]] != [g["width"], g["height"]]:
            out.append(f"grid size {g['width']}x{g['height']} against terrain "
                       f"{hf['width']}x{hf['height']}")

    fixture = ROOT / "assets" / "fixture" / "fixture_client.json"
    if fixture.exists():
        windows = _json(fixture).get("windows", {})
        if doc["window"] not in windows:
            out.append(f"window {doc['window']!r} is not in the vendored fixture "
                       f"({sorted(windows)}) -- nothing would scrub with these arcs")
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--from", dest="src", type=Path, required=True,
                    help="the sim repo's contour outdir")
    ap.add_argument("--sim", type=Path, help="a sim checkout, to record the source commit")
    a = ap.parse_args(argv)

    manifests = sorted(a.src.glob("contours_*.json"))
    if not manifests:
        print(f"no contours_*.json in {a.src} -- run tools/extract_contours.py",
              file=sys.stderr)
        return 2

    DEST.mkdir(parents=True, exist_ok=True)
    files: dict[str, str] = {}
    rows: list[str] = []
    for mpath in manifests:
        doc = _json(mpath)
        problems = refusals(doc)
        if problems:
            print(f"REFUSED ({mpath.name}):", file=sys.stderr)
            for p in problems:
                print(f"  {p}", file=sys.stderr)
            return 1
        payload = a.src / doc["payload"]["file"]
        if not payload.exists():
            print(f"{mpath.name} names {payload.name}, which is not in {a.src}",
                  file=sys.stderr)
            return 2
        client = {k: v for k, v in doc.items() if k not in NOT_VENDORED}
        client["_what"] = ("pre-extracted contour geometry. The band ladder it was "
                           "extracted from is not here and is not derivable from it "
                           "for any node whose arc is absent -- §16.12.")
        (DEST / mpath.name).write_text(json.dumps(client, indent=1) + "\n")
        shutil.copy2(payload, DEST / payload.name)
        files[mpath.name] = sha256(DEST / mpath.name)
        files[payload.name] = sha256(DEST / payload.name)
        days = doc["days"]
        rows.append(f"{doc['row']} @ {doc['threshold']} {doc['unit']} in {doc['window']}: "
                    f"{len(days)} day(s), {doc['payload']['vertices']} vertices")

    pin = {
        "_form": "The claim about the vendored contours. Same shape as assets/terrain/PIN.",
        "artefact": "pre-extracted contours of band-quantised fields",
        "ruled_by": ["§16.12", "§16.12.1", "§16.7", "decision 296", "decision 890"],
        "source": {"repo": "git@github.com:veekbee/magisteria.git",
                   "path": "data/contour_output"},
        "generated_by": "tools/extract_contours.py",
        "vendored_by": "tools/vendor_contours.py",
        "sets": rows,
        "files": files,
        "_not_here": ("the per-node crossing elevations and the HUC4 band ladders they "
                      "come from. Geometry ships; the generator does not (§16.12)."),
    }
    if a.sim:
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=a.sim,
                              text=True, capture_output=True)
        if head.returncode == 0:
            pin["source_commit"] = head.stdout.strip()
    (DEST / "PIN").write_text(json.dumps(pin, indent=2) + "\n")

    total = sum((DEST / f).stat().st_size for f in files)
    print(f"vendored {len(manifests)} contour set(s), {total / 1e6:.1f} MB")
    for r in rows:
        print(f"  {r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
