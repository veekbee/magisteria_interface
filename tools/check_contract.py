#!/usr/bin/env python3
r"""
check_contract.py -- does `contract/schema.json` still match `contract/PIN`?

TWO HALVES, AND ONLY ONE OF THEM CAN RUN IN THIS REPO'S CI
-----------------------------------------------------------
**The local half** (default) asks whether the vendored bytes match the claim
the PIN makes about them. It needs nothing but this repo, so CI runs it on
every push. It compares a sha256 of the file's *bytes* -- deliberately, so
the check needs no JSON parser and cannot be fooled by a re-serialisation
that changes bytes while preserving structure, or vice versa.

**The cross-repo half** (`--against <sim-checkout>`) asks the question that
actually matters: do these bytes match what the simulation repo committed at
the pinned SHA? That needs a checkout or a bundle of the simulation repo,
which this repo's CI does not have and should not be given. Run it when one
is at hand.

**Do not fake the cross-repo half with a stale copy.** A vendored second copy
would be checked against itself, which is worse than not checking: it reads
as a green cross-repo check while comparing a file to its own duplicate. The
simulation side is independently guarded by `emit_schema.py --check` in that
repo's own CI, which fails there if the artefact ever disagrees with the
registry -- so the uncovered gap is narrow and named rather than papered over.

WHAT IS NOT CHECKED, AND WHY
-----------------------------
`declared_content_digest_sha256` is the artefact's own claim about its
canonical content (which excludes `since`). This tool records it and does not
verify it: recomputing it means reimplementing the emitter's canonicalisation
rule, and a second implementation of a rule is a second thing that can be
wrong. The emitter verifies it where the rule lives.

Usage:
    python3 tools/check_contract.py
    python3 tools/check_contract.py --against ../iota_magisteria
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIN_PATH = ROOT / "contract" / "PIN"
ARTEFACT_PATH = ROOT / "contract" / "schema.json"

#: A second pinned import, on the same terms. The terrain export is four files
#: rather than one, so its PIN carries a `files` map instead of a single
#: `file_sha256` -- the shape differs, the discipline does not.
TERRAIN_PIN = ROOT / "assets" / "terrain" / "PIN"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_pin() -> dict:
    if not PIN_PATH.exists():
        raise SystemExit(f"no PIN at {PIN_PATH} -- the vendored artefact has no claim about it")
    try:
        return json.loads(PIN_PATH.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"PIN is not valid JSON: {exc}")


def check_local(pin: dict) -> list[str]:
    problems = []
    if not ARTEFACT_PATH.exists():
        return [f"no artefact at {ARTEFACT_PATH}"]
    raw = ARTEFACT_PATH.read_bytes()
    actual = sha256(raw)
    claimed = pin.get("file_sha256", "")
    if actual != claimed:
        problems.append(
            f"vendored artefact does not match its PIN\n"
            f"    PIN claims  {claimed}\n"
            f"    file is     {actual}\n"
            f"  One of the two was edited without the other. An artefact bump is a TWO-file\n"
            f"  diff; a one-file diff here is either an unpinned edit or a stale pin.")

    # The PIN also restates the version pair. It is a claim about the file, so
    # it is checked against the file -- not trusted because it sits beside it.
    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        problems.append(f"vendored artefact is not valid JSON: {exc}")
        return problems
    want = pin.get("version", {})
    got = doc.get("version", {})
    if (want.get("major"), want.get("minor")) != (got.get("major"), got.get("minor")):
        problems.append(
            f"PIN claims version {want.get('major')}.{want.get('minor')} but the artefact "
            f"declares {got.get('major')}.{got.get('minor')}")
    if pin.get("declared_content_digest_sha256") != doc.get("content_digest_sha256"):
        problems.append("PIN's recorded content digest differs from the artefact's own")
    return problems


def check_against(pin: dict, sim: Path) -> list[str]:
    commit = pin.get("artefact_committed_at", "")
    path = pin.get("source", {}).get("path", "")
    if not commit or not path:
        return ["PIN does not name both a source commit and a source path"]
    if not (sim / ".git").exists():
        return [f"{sim} is not a git checkout of the simulation repo"]
    try:
        blob = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=sim,
                              check=True, capture_output=True).stdout
    except subprocess.CalledProcessError as exc:
        return [f"`git show {commit}:{path}` failed in {sim}: "
                f"{exc.stderr.decode(errors='replace').strip()}\n"
                f"  The pinned commit is not in that checkout. Fetch it rather than "
                f"re-pinning to whatever is there."]
    upstream = sha256(blob)
    if upstream != pin.get("file_sha256"):
        return [f"the pinned commit's artefact does not match the vendored copy\n"
                f"    {commit}:{path}\n"
                f"      is  {upstream}\n"
                f"    PIN/vendored\n"
                f"      is  {pin.get('file_sha256')}"]
    return []


def check_terrain() -> list[str]:
    """The terrain export against its own PIN.

    Absent is not a failure: the export is a separate artefact and a checkout
    predating it is a legitimate state. A PIN naming a file that is missing IS
    a failure -- that is a claim about something that is not there.
    """
    if not TERRAIN_PIN.exists():
        return []
    try:
        pin = json.loads(TERRAIN_PIN.read_text())
    except json.JSONDecodeError as exc:
        return [f"terrain PIN is not valid JSON: {exc}"]
    problems = []
    for name, claimed in pin.get("files", {}).items():
        path = TERRAIN_PIN.parent / name
        if not path.exists():
            problems.append(f"terrain PIN names {name}, which is not present")
            continue
        actual = sha256(path.read_bytes())
        if actual != claimed:
            problems.append(
                f"terrain artefact {name} does not match its PIN\n"
                f"    PIN claims  {claimed}\n"
                f"    file is     {actual}")
    return problems


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--against", type=Path, default=None, metavar="SIM_CHECKOUT",
                    help="also run the cross-repo half against a simulation-repo checkout")
    a = ap.parse_args(argv)

    pin = load_pin()
    problems = check_local(pin) + check_terrain()
    scope = "local"
    if a.against is not None:
        problems += check_against(pin, a.against.resolve())
        scope = "local + cross-repo"

    if problems:
        print("CONTRACT CHECK FAILED:", file=sys.stderr)
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        return 1

    v = pin.get("version", {})
    print(f"contract OK ({scope}): v{v.get('major')}.{v.get('minor')}, "
          f"sha256 {pin.get('file_sha256', '')[:16]}…, "
          f"pinned at {pin.get('artefact_committed_at', '')[:12]}")
    if TERRAIN_PIN.exists():
        tp = json.loads(TERRAIN_PIN.read_text())
        print(f"terrain OK: {len(tp.get('files', {}))} file(s), "
              f"pinned at {tp.get('source_commit', '')[:12]}")
    if a.against is None:
        print("  (cross-repo half not run -- pass --against <sim-checkout> when one is at hand)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
