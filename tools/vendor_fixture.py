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

**Every refusal happens before the first write.** This tool once validated the
carried set, wrote both files, and only then reached for a manifest key that
was not there -- leaving the working tree half-vendored, with a client manifest
derived from an upstream the client cannot use and a PIN still describing the
old one. A tool that refuses after writing has not refused.

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

#: Keys the client cannot run without. `client_form` carries the display
#: encoding: the bin's filename and every row's realised lo/hi. Without it
#: `FixtureLoader` has no bin path and no rows, so the fixture does not load at
#: all and the viewer falls back to bare terrain -- which looks like a client
#: bug and is a build that was emitted without `--client`.
REQUIRED = {
    "client_form": ("the display encoding: the bin's filename and every row's realised lo/hi. "
                    "The fixture was almost certainly built without `--client`; rebuild it with "
                    "that flag rather than vendoring a manifest the client cannot load."),
}


#: Decision 948's threshold, exact so a file's side of it is computable rather
#: than arguable. Recorded into the PIN by this tool so `check_contract.py` reads
#: it from the artefact instead of carrying a second copy that can drift.
FETCH_THRESHOLD_BYTES = 10 * 1024 * 1024


def _tag_of(host: str) -> str:
    """The release tag a GitHub download URL names, for the reminder below.

    Best-effort and deliberately so: it is building a line for a person to
    read, not deriving a path. `fetch_artefacts.py` never derives a destination
    from a URL and this does not either -- if the host is not a GitHub release
    the tag comes out as a placeholder and the human fills it in.
    """
    parts = host.rstrip("/").split("/")
    if "download" in parts:
        i = parts.index("download")
        if i + 1 < len(parts):
            return parts[i + 1]
    return "<release-tag>"


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

    missing = [(k, why) for k, why in REQUIRED.items() if k not in full]
    if missing:
        print("REFUSED: the upstream manifest is missing what the client needs.", file=sys.stderr)
        for k, why in missing:
            print(f"  {k} -- {why}", file=sys.stderr)
        print(f"  in {a.src / 'fixture_v1.json'}, which carries: "
              f"{', '.join(sorted(full))}", file=sys.stderr)
        print("  Nothing was written.", file=sys.stderr)
        return 1

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
    # WHAT THE PIN CLAIMED BEFORE THIS RUN, so the end of this tool can say
    # which hosted files it has just invalidated. See the note by `stale_hosts`.
    was = dict(pin.get("files") or {})
    pin["run"] = full["run"]
    pin["is_a_display_encoding"] = full["client_form"]["is_a_display_encoding"]
    vendored = ["fixture_client.bin", "fixture_client.json"]
    pin["files"] = {n: sha256(DEST / n) for n in vendored}
    # DECISION 948: anything at or above the threshold is FETCHED, not committed.
    # Derived by size rather than by naming the file, so the day a vendored
    # artefact crosses the line it moves on its own instead of waiting for
    # someone to remember. The digest above stays authoritative; `host` is a
    # field and never a source of truth, so a move of hosting changes nothing
    # a checker reads.
    fetched = {n: (DEST / n).stat().st_size for n in vendored
               if (DEST / n).stat().st_size >= FETCH_THRESHOLD_BYTES}
    if fetched:
        # Hosts SURVIVE a re-vendor. They are the one field here the producing
        # side does not know and the vendoring does not derive, so re-deriving
        # the block must carry them forward or every re-vendor would silently
        # un-publish the artefact.
        hosts = (pin.get("fetched") or {}).get("files", {})
        pin["fetched"] = {
            "_what": "files over decision 948's threshold. NOT committed: they arrive "
                     "through tools/fetch_artefacts.py and nothing else. Absent is a "
                     "valid state for a clone; wrong bytes is not.",
            "_host_is_not_authoritative": "the sha256 in `files` is the whole of the "
                                          "check. A move of hosting is a one-field edit "
                                          "here and changes no contract (decision 948).",
            "threshold_bytes": FETCH_THRESHOLD_BYTES,
            "files": {n: {"bytes": b,
                          "host": (hosts.get(n) or {}).get("host")}
                      for n, b in sorted(fetched.items())},
        }
    else:
        pin.pop("fetched", None)
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
        # TWO COMMITS, NOT ONE, and recording only HEAD was a claim the bytes do
        # not support. `source_commit` must be where the ARTEFACT came to rest --
        # the last commit to touch the source directory -- because that is what
        # `cross_repo` compares against. HEAD at vendor time is a different fact:
        # it moves every time anyone re-vendors, whether or not the artefact
        # changed, so a PIN carrying it as `source_commit` claims a provenance
        # that is true only by luck. Both are recorded and named for what they
        # are (COLLABORATION.md §5.1a).
        rest = subprocess.run(
            ["git", "log", "-1", "--format=%H", "--", "data/fixture_output"],
            cwd=a.sim, text=True, capture_output=True)
        if rest.returncode == 0 and rest.stdout.strip():
            pin["source_commit"] = rest.stdout.strip()
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=a.sim,
                              text=True, capture_output=True)
        if head.returncode == 0:
            pin["vendored_against_commit"] = head.stdout.strip()
            pin["_two_commits_note"] = (
                "`source_commit` is where the artefact's bytes came to rest -- the "
                "last commit touching the source directory, and what `cross_repo` "
                "checks against. `vendored_against_commit` is the sim tree this "
                "vendoring read. They differ whenever the sim moved without the "
                "artefact moving, which is most of the time.")
    (DEST / "PIN").write_text(json.dumps(pin, indent=2) + "\n")

    print(f"vendored: {len(carried)} row(s) against contract "
          f"v{version['major']}.{version['minor']}, "
          f"{(DEST / 'fixture_client.bin').stat().st_size / 1e6:.1f} MB")

    # THE HOST NOW SERVES SUPERSEDED BYTES, AND THIS IS WHERE THAT IS SAID.
    #
    # `host` survives a re-vendor on purpose -- re-deriving the block without it
    # would silently un-publish the artefact -- but a host carried forward beside
    # a digest that just moved is a host that is now WRONG. Nothing failed here
    # and nothing should: the digest is authoritative, so `fetch_artefacts.py`
    # refuses the stale bytes loudly and names both sides. What it cannot do is
    # tell you BEFORE you push, and the first thing to notice was CI going red
    # on a re-vendor that was otherwise correct in every part.
    #
    # So the tool that moved the digest is the thing that says so. It cannot
    # upload -- that is outward-facing and needs a person -- but it can make the
    # step impossible to forget, which is the difference between a procedure
    # with five steps and one with six.
    stale_hosts = []
    for name, meta in ((pin.get("fetched") or {}).get("files") or {}).items():
        if meta.get("host") and was.get(name) and was[name] != pin["files"].get(name):
            stale_hosts.append((name, was[name], pin["files"][name], meta["host"]))
    for name, before, after, host in stale_hosts:
        print(f"\nHOST NOW STALE: {name}", file=sys.stderr)
        print(f"  the PIN claimed  {before}", file=sys.stderr)
        print(f"  it now claims    {after}", file=sys.stderr)
        print(f"  the host serves the first, at {host}", file=sys.stderr)
        print("  Until it is replaced, no fresh clone can fetch this artefact and CI "
              "fails the\n  digest check -- correctly, and for a reason that has nothing "
              "to do with the code.", file=sys.stderr)
        print(f"  gh release upload {_tag_of(host)} {DEST / name} --clobber",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
