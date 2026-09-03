#!/usr/bin/env python3
"""
vendor_fixture.py -- bring a built fixture across the repo boundary.

M2 vendored the fixture by hand: copy two files, hand-edit a PIN. That worked
once and left no record of WHICH subset of the sim repo's manifest the client
actually gets, so the next person doing it had to reconstruct the answer by
diffing. §23.828's lesson, one boundary over -- a manual step does not stick.

What the client gets is the full manifest MINUS three keys:

  * `artefact`       -- the sim repo's own name for the run, not the client's
  * `payload`        -- describes fixture_v1.bin, which is not vendored (75 MB
                        of float64 the client has no use for)
  * `flow_precision` -- an internal note about the replay, not about the wire

plus `_what` and `_refused_rows`, which the client reads and the full manifest
carries per-window instead.

**The refusal this tool exists for.** The fixture and the contract are vendored
separately and nothing compared them. Contract v2.0 removed two carried rows,
and a fixture built before it would still have shipped nine rows against an
eight-row contract -- the client's field picker derives from the FIXTURE, so it
would have gone on offering a row the contract no longer declares. That is the
shape §23.851 measured: `node.wetland_extent` reached the public client as
207,720 zeros and was offered beside eight real fields. So this refuses unless
the fixture's carried set and the vendored contract's row set are equal.
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
DEST = ROOT / "assets" / "fixture"

#: Keys the client does not get, each for its own reason -- see the header.
NOT_VENDORED = ("artefact", "payload", "flow_precision")


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def contract_rows() -> set:
    doc = json.loads((ROOT / "contract" / "schema.json").read_text())
    return {r["name"] for r in doc["rows"]}, doc["version"]


def client_manifest(full: dict) -> dict:
    out = {k: v for k, v in full.items() if k not in NOT_VENDORED}
    out["_what"] = "the client's view of fixture v1"
    out["_refused_rows"] = {
        w: dict(spec.get("refused_rows", {}))
        for w, spec in full.get("windows", {}).items()
    }
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--from", dest="src", type=Path, required=True,
                    help="the sim repo's fixture outdir")
    ap.add_argument("--sim", type=Path,
                    help="a sim checkout, to record the source commit")
    a = ap.parse_args(argv)

    full = json.loads((a.src / "fixture_v1.json").read_text())
    src_bin = a.src / "fixture_client.bin"
    if not src_bin.exists():
        print(f"no fixture_client.bin in {a.src} -- build with --client",
              file=sys.stderr)
        return 2

    rows, version = contract_rows()
    carried = set(full["carried_set"]["names"])
    if carried != rows:
        print("REFUSED: the fixture and the vendored contract disagree.\n"
              f"  contract v{version['major']}.{version['minor']} carries "
              f"{len(rows)} row(s)\n"
              f"  fixture carries {len(carried)}\n"
              f"  in the fixture and not the contract: {sorted(carried - rows)}\n"
              f"  in the contract and not the fixture: {sorted(rows - carried)}\n"
              "Vendor the contract first, then rebuild the fixture against it.",
              file=sys.stderr)
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "fixture_client.json").write_text(
        json.dumps(client_manifest(full), indent=1) + "\n")
    shutil.copy2(src_bin, DEST / "fixture_client.bin")

    pin = json.loads((DEST / "PIN").read_text())
    pin["run"] = full["run"]
    pin["is_a_display_encoding"] = full["client_form"]["is_a_display_encoding"]
    pin["files"] = {
        "fixture_client.bin": sha256(DEST / "fixture_client.bin"),
        "fixture_client.json": sha256(DEST / "fixture_client.json"),
    }
    # HOW EACH FILE IS CHECKABLE against `source_commit`, declared by the tool
    # that made it rather than hand-added to the PIN, which does not survive the
    # next vendor run.
    pin["cross_repo"] = {
        "_what": "how each file above is checkable against `source_commit` in a simulation "
                 "checkout. Per file, because the answer differs per file.",
        "files": {
            "fixture_client.json": {
                "upstream": "data/fixture_output/fixture_v1.json",
                "how": "derived", "by": "tools/vendor_fixture.py:client_manifest"},
            "fixture_client.bin": {
                "upstream": "data/fixture_output/fixture_client.bin",
                "how": "not_tracked_upstream",
                "note": "rides `data/**/*.bin` in the simulation repo. The PIN's own sha256 "
                        "covers the vendored copy; nothing can compare it to a source "
                        "commit, and saying so is the point."},
        },
    }
    pin["carried_rows"] = sorted(carried)
    pin["contract_version"] = f"{version['major']}.{version['minor']}"
    if a.sim:
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=a.sim,
                              text=True, capture_output=True)
        if head.returncode == 0:
            pin["source_commit"] = head.stdout.strip()
    (DEST / "PIN").write_text(json.dumps(pin, indent=2) + "\n")

    print(f"vendored: {len(carried)} row(s) against contract "
          f"v{version['major']}.{version['minor']}, "
          f"{(DEST / 'fixture_client.bin').stat().st_size / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
