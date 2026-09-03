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
FIXTURE_PIN = ROOT / "assets" / "fixture" / "PIN"
CONTOUR_PIN = ROOT / "assets" / "contours" / "PIN"


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


def check_multi(pin_path: Path, label: str) -> list[str]:
    """The terrain export against its own PIN.

    Absent is not a failure: the export is a separate artefact and a checkout
    predating it is a legitimate state. A PIN naming a file that is missing IS
    a failure -- that is a claim about something that is not there.
    """
    if not pin_path.exists():
        return []
    try:
        pin = json.loads(pin_path.read_text())
    except json.JSONDecodeError as exc:
        return [f"{label} PIN is not valid JSON: {exc}"]
    problems = []
    for name, claimed in pin.get("files", {}).items():
        path = pin_path.parent / name
        if not path.exists():
            problems.append(f"{label} PIN names {name}, which is not present")
            continue
        actual = sha256(path.read_bytes())
        if actual != claimed:
            problems.append(
                f"{label} artefact {name} does not match its PIN\n"
                f"    PIN claims  {claimed}\n"
                f"    file is     {actual}")
    return problems


def _upstream_blob(sim: Path, commit: str, path: str):
    """The bytes of `path` at `commit` in a simulation checkout, or an error string."""
    r = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=sim, capture_output=True)
    if r.returncode != 0:
        return None, (f"`git show {commit}:{path}` failed in {sim}: "
                      f"{r.stderr.decode(errors='replace').strip()}")
    return r.stdout, None


def _derived_by(spec: str):
    """Import the vendor tool's own transform, named `module.py:function`.

    IMPORTED, not reimplemented. Two copies of a transform agree until one is
    edited, and an edit is exactly what this check exists to catch -- a second
    derivation here would go green on the day the vendor tool changed and the
    vendored copy did not.
    """
    mod_path, _, func = spec.partition(":")
    name = Path(mod_path).stem
    sys.path.insert(0, str(ROOT / "tools"))
    return getattr(__import__(name), func)


def check_against_multi(sim: Path, pin_path: Path, label: str) -> tuple[list[str], dict]:
    """A vendored multi-file artefact against the source commit it names.

    **The green line used to cover one artefact of four.** `--against` checked
    `contract/schema.json` and nothing else, while terrain, fixture and contours
    each carried a `source_commit` that nothing ever read. Three of those four
    are not byte copies -- two are transforms of an upstream manifest and one is
    a key projection of it -- so a single byte-equality rule would have reported
    a defect on every correct file, which is presumably why none was written.
    The rule is therefore declared per file, by the tool that vendored it.
    """
    tally = {"bytes": 0, "derived": 0, "key_subset": 0, "not_checkable": 0}
    if not pin_path.exists():
        return [], tally
    pin = json.loads(pin_path.read_text())
    commit = pin.get("source_commit", "")
    rules = pin.get("cross_repo", {}).get("files", {})
    if not commit:
        return [f"{label} PIN names no source_commit -- nothing to check it against"], tally
    if not rules:
        return [f"{label} PIN declares no cross_repo rules, so its {len(pin.get('files', {}))} "
                f"file(s) cannot be checked against {commit[:12]} -- re-run its vendor tool"], tally

    problems = []
    for name, sha_claimed in pin.get("files", {}).items():
        rule = rules.get(name)
        if rule is None:
            problems.append(f"{label}/{name} has no cross_repo rule; it is pinned locally and "
                            f"unchecked against {commit[:12]}")
            continue
        how = rule.get("how")
        if how == "not_tracked_upstream":
            tally["not_checkable"] += 1
            continue
        blob, err = _upstream_blob(sim, commit, rule["upstream"])
        if err:
            problems.append(f"{label}/{name}: {err}")
            continue
        local = pin_path.parent / name
        if how == "bytes":
            if sha256(blob) != sha_claimed:
                problems.append(f"{label}/{name} differs from {commit[:12]}:{rule['upstream']}")
            else:
                tally["bytes"] += 1
        elif how in ("derived", "key_subset"):
            try:
                up = json.loads(blob)
                got = json.loads(local.read_text())
            except json.JSONDecodeError as exc:
                problems.append(f"{label}/{name} or its upstream is not JSON: {exc}")
                continue
            if how == "derived":
                want = _derived_by(rule["by"])(up)
                if want != got:
                    extra = sorted(set(got) - set(want))
                    missing = sorted(set(want) - set(got))
                    changed = sorted(k for k in set(want) & set(got) if want[k] != got[k])
                    problems.append(
                        f"{label}/{name} is not what {rule['by']} makes of "
                        f"{commit[:12]}:{rule['upstream']}\n"
                        f"    keys only here: {extra or 'none'}\n"
                        f"    keys only there: {missing or 'none'}\n"
                        f"    keys that differ: {changed or 'none'}")
                else:
                    tally["derived"] += 1
            else:
                bad = [k for k in got if k in up and up[k] != got[k]]
                if bad:
                    problems.append(f"{label}/{name} projects {bad} from "
                                    f"{commit[:12]}:{rule['upstream']} with different values")
                else:
                    tally["key_subset"] += 1
        else:
            problems.append(f"{label}/{name} declares an unknown cross_repo rule {how!r}")
    return problems, tally


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--against", type=Path, default=None, metavar="SIM_CHECKOUT",
                    help="also run the cross-repo half against a simulation-repo checkout")
    a = ap.parse_args(argv)

    pin = load_pin()
    problems = (check_local(pin) + check_multi(TERRAIN_PIN, "terrain")
                + check_multi(FIXTURE_PIN, "fixture")
                + check_multi(CONTOUR_PIN, "contours"))
    scope = "local"
    tallies = {}
    if a.against is not None:
        sim = a.against.resolve()
        problems += check_against(pin, sim)
        for pp, label in ((TERRAIN_PIN, "terrain"), (FIXTURE_PIN, "fixture"),
                          (CONTOUR_PIN, "contours")):
            probs, tally = check_against_multi(sim, pp, label)
            problems += probs
            if pp.exists():
                tallies[label] = tally
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
    for pp, label in ((TERRAIN_PIN, "terrain"), (FIXTURE_PIN, "fixture"),
                      (CONTOUR_PIN, "contours")):
        if pp.exists():
            d = json.loads(pp.read_text())
            print(f"{label} OK: {len(d.get('files', {}))} file(s)")
    if a.against is None:
        print("  (cross-repo half not run -- pass --against <sim-checkout> when one is at hand)")
    else:
        for label, t in tallies.items():
            checked = t["bytes"] + t["derived"] + t["key_subset"]
            print(f"{label} cross-repo: {checked} file(s) checked against the source commit "
                  f"({t['bytes']} by bytes, {t['derived']} re-derived, {t['key_subset']} by key "
                  f"projection), {t['not_checkable']} not tracked upstream and so uncheckable")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
