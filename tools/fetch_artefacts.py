#!/usr/bin/env python3
"""
fetch_artefacts.py -- bring in the artefacts too large to commit (decision 948).

**This is the only sanctioned way those bytes arrive.** Not a browser download,
not a second helper, not a hand-placed file. One path, so there is no second one
to drift from it -- and so that "where did this file come from" has exactly one
answer in a repo whose whole discipline is that a vendored artefact carries a
claim about itself.

WHAT IS AUTHORITATIVE, AND IT IS NOT THE HOST.
Each PIN already carries `files: {name: sha256}`. A PIN's `fetched` block marks
which of those are not committed and records a `host` for each. **The digest is
the whole of the check.** A move of hosting is a one-field edit in the PIN that
changes no digest and therefore no contract, so this tool:

  * never derives a destination path from a URL -- the path is the PIN's key;
  * never reports "fetched from the expected host" as any part of a pass;
  * writes nothing until the bytes it holds hash to the claimed digest.

That last one is why the download goes to a temporary file first. A partial or
wrong download that lands on the destination has replaced a known-absent file
with an unknown-present one, which is strictly worse than not running: absent is
a state the checker understands and reports, and wrong is the only state that
fails.

ABSENT IS VALID, AND `--require` IS WHERE IT STOPS BEING VALID. A clone with
none of these files is a working clone; the checks that need them skip and say
so. Running this tool is therefore optional, and it is a no-op when everything
is present and matching.

But a GATE is not a clone. `--require <pin>` says that after this run every
fetched row of that pin must be on disk, and exits non-zero otherwise --
because the alternative is a green build that ran half of itself. The two
artefacts here are not alike in this: the tile pyramid is 141 MB of near-field
detail whose checks skip and say so, and the fixture binary is the artefact the
client exists to display, read by 1,526 of the suite's checks. Absence of the
first is a clone; absence of the second is a gate that did not run.

WHAT MADE THIS NECESSARY. Decision 948 moved the fixture binary out of the tree
and onto a release asset, and neither gate learned to bring it back. CI was red
for thirty commits over four days on 38 failing checks that were one missing
file, and the failure did not name the file where anyone was looking -- it
named `band.bare_fraction gave 0 values` thirty-eight times.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional, Sequence

ROOT = Path(__file__).resolve().parents[1]
PINS = ("contract/PIN", "assets/fixture/PIN", "assets/terrain/PIN",
        "assets/terrain/tiles/PIN", "assets/terrain/layers/PIN",
        "assets/contours/PIN", "assets/detail/PIN",
        "assets/dressing/da6-compact/PIN",
        "assets/dressing_renders/da6-compact/PIN", "assets/dressing_pins/PIN")
#: `assets/detail/PIN` WAS MISSING FROM THE TUPLE UNTIL `unlisted_pins` BELOW
#: WENT LOOKING. It declares no `fetched` block -- its three files are
#: committed -- so it yields no rows and its absence changed nothing that ran.
#: It is listed anyway, because the tuple is meant to be the inventory of this
#: repo's pins and not of the fetched ones: the day a `fetched` block is added
#: to a pin nobody listed is the day an artefact goes missing in silence, and
#: that day would have arrived with no check to meet it.


def unlisted_pins(root: Path) -> list:
    """Every file named `PIN` in the tree that `PINS` above does not name.

    WHY THIS EXISTS. `PINS` IS HAND-WRITTEN, AND A PIN THAT IS NOT IN IT IS
    NOT MERELY UNFETCHED -- IT IS SILENTLY UNFETCHED. `main` walks `PINS` and
    nothing else, so an artefact whose pin was added to the tree without being
    added to this tuple produces no row, no fetch and no error; and when the
    tuple's rows are all present, the run prints a tally and exits 0. The
    failure mode is a clone that is missing an entire artefact while the
    transport reports success, which is the same shape of defect as the
    `no fetched artefacts declared` line below: AN ABSENCE READ AS A PASS.

    Measured: adding `assets/dressing/da6-compact/PIN` for decision 2129 was
    one tuple entry away from exactly that, and nothing in the gate would have
    said so -- which is why this function is called unconditionally rather
    than behind a flag.
    """
    found = sorted(str(q.relative_to(root)) for q in root.rglob("PIN")
                   if q.is_file() and ".git" not in q.parts)
    return [q for q in found if q not in PINS]


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def wanted(pin_path: Path) -> list[dict]:
    """The fetched rows of one PIN, with everything needed to act on them.

    DECISION 972 -- `host_base`. A `fetched` block may carry a prefix that each
    row's key appends to; a row's own `host` wins where present; neither is
    still `no-host`, which is a valid clone rather than a failure.

    It exists because the one-field edit does not survive a multi-file
    artefact. Decision 948 rules that a move of hosting is a one-field edit
    changing no digest and therefore no contract -- and that was written
    against a one-file case. This function reads `host` per ROW, so an artefact
    of 496 files carries 496 absolute URLs and a host move costs 496 edits, at
    which point 948's ruled property does not weaken, it silently stops
    holding.

    THIS DOES NOT REOPEN WHERE `path` COMES FROM. The destination is still the
    pin's key and never the URL, and joining a prefix to the same key to build
    a URL is the opposite direction: one string produces the address, the key
    produces the file, and neither is derived from the other.
    """
    if not pin_path.exists():
        return []
    pin = json.loads(pin_path.read_text())
    digests = pin.get("files", {})
    fetched = pin.get("fetched") or {}
    block = fetched.get("files", {})
    base = fetched.get("host_base")
    out = []
    for name, meta in block.items():
        if name not in digests:
            # A fetched row with no digest is unactionable: there would be
            # nothing to verify the bytes against, and fetching unverifiable
            # bytes is the one thing this tool must not do.
            raise SystemExit(
                f"{pin_path}: `fetched` names {name} but `files` carries no sha256 "
                f"for it. The digest is the whole of the check, so a row without one "
                f"cannot be fetched at all.")
        host = meta.get("host")
        if not host and base:
            host = base + name
        out.append({"pin": pin_path, "name": name,
                    "path": pin_path.parent / name,
                    "sha256": digests[name],
                    "bytes": meta.get("bytes"),
                    "host": host,
                    "host_from": ("row" if meta.get("host")
                                  else ("host_base" if base else None))})
    return out


def fetch_one(row: dict, timeout: float) -> str:
    """Returns a one-word outcome; raises SystemExit on a verifiable failure."""
    dest, want = row["path"], row["sha256"]
    if dest.exists():
        return "matches" if sha256_file(dest) == want else "MISMATCH"
    if not row["host"]:
        return "no-host"
    # A destination three directories deep does not exist in a fresh clone.
    # Created here rather than by the caller: the path is the pin's key, so
    # the key is the only thing that decides which directories are made.
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = None
    try:
        with urllib.request.urlopen(row["host"], timeout=timeout) as resp:
            fd, tmpname = tempfile.mkstemp(dir=str(dest.parent), prefix=".fetch-")
            tmp = Path(tmpname)
            with os.fdopen(fd, "wb") as out:
                while True:
                    chunk = resp.read(1 << 20)
                    if not chunk:
                        break
                    out.write(chunk)
    except (urllib.error.URLError, OSError) as exc:
        if tmp and tmp.exists():
            tmp.unlink()
        return f"unreachable ({exc.__class__.__name__})"
    got = sha256_file(tmp)
    if got != want:
        tmp.unlink()
        raise SystemExit(
            f"{row['name']}: the bytes at the host do not match the PIN.\n"
            f"    PIN claims  {want}\n"
            f"    downloaded  {got}\n"
            f"Nothing was written. The digest is authoritative and the host is not, "
            f"so this is the host being wrong rather than the PIN.")
    tmp.replace(dest)
    return "fetched"


def missing_required(rows: list[dict], required: set) -> list[dict]:
    """Required rows whose bytes are not on disk.

    ITS OWN FUNCTION SO THAT IT CAN HAVE A CONTROL. Three cases and two of
    them are silent when wrong: a required row that is absent and not
    reported is the gate this whole flag exists to prevent, and a row that is
    reported when nobody required it turns every valid clone red.
    """
    return [r for r in rows
            if r["pin"].resolve() in required and not r["path"].exists()]


def selftest() -> int:
    """Exercise `host_base` against a pin that exists only for this check.

    IT IS A CHECK WITH A NEGATIVE CONTROL, not a demonstration. Decision 972's
    rule has three branches -- a row's own host wins, otherwise the base and
    the key, otherwise `no-host` -- and two of those are silent when wrong: a
    base that quietly loses to nothing fetches nothing, and a base that quietly
    beats a row's host fetches the wrong file and is caught only by the digest.
    So all three are asserted, and so is the property that no URL anywhere
    decides a destination path.
    """
    import tempfile as _tf
    problems = []
    with _tf.TemporaryDirectory() as d:
        pin = Path(d) / "PIN"
        pin.write_text(json.dumps({
            "files": {"a/one.png": "aa" * 32, "b/two.png": "bb" * 32,
                      "c/three.png": "cc" * 32},
            "fetched": {
                "host_base": "https://example.invalid/rel-1/",
                "files": {"a/one.png": {}, "b/two.png": {"host": "https://elsewhere/x.png"},
                          "c/three.png": {}},
            },
        }))
        rows = {r["name"]: r for r in wanted(pin)}
        if rows["a/one.png"]["host"] != "https://example.invalid/rel-1/a/one.png":
            problems.append("host_base did not join the key: %s" % rows["a/one.png"]["host"])
        if rows["b/two.png"]["host"] != "https://elsewhere/x.png":
            problems.append("a row's own host did not win over host_base")
        if rows["b/two.png"]["host_from"] != "row":
            problems.append("the row's host is not reported as the row's")
        # THE PATH IS THE KEY AND NEVER THE URL. `b/two.png` is hosted at
        # `x.png` under another origin; if a URL ever decided a destination
        # this is the row that would land in the wrong place.
        if rows["b/two.png"]["path"] != pin.parent / "b/two.png":
            problems.append("a destination was derived from a URL: %s"
                            % rows["b/two.png"]["path"])

        pin.write_text(json.dumps({"files": {"a/one.png": "aa" * 32},
                                   "fetched": {"files": {"a/one.png": {}}}}))
        rows = {r["name"]: r for r in wanted(pin)}
        if rows["a/one.png"]["host"]:
            problems.append("a pin with no host_base and no row host produced a URL anyway")
        if fetch_one(rows["a/one.png"], 1.0) != "no-host":
            problems.append("no host is not reported as no-host")

        # `--require`'S THREE CASES, against a pin whose files do not exist.
        here = pin.parent.resolve()
        rows_list = wanted(pin)
        if missing_required(rows_list, {here / "PIN"}):
            pass
        else:
            problems.append("a required row that is absent was not reported missing")
        if missing_required(rows_list, set()):
            problems.append("a row nobody required was reported missing, so every valid "
                            "clone would fail")
        (pin.parent / "a").mkdir(parents=True, exist_ok=True)
        (pin.parent / "a" / "one.png").write_bytes(b"")
        if missing_required(rows_list, {here / "PIN"}):
            problems.append("a required row that is PRESENT was reported missing")

        # `unlisted_pins` AGAINST A PLANTED PIN, AND ITS CONTROL. A walker that
        # found nothing would pass this check by doing nothing at all, so the
        # positive case is a pin deliberately planted at a path PINS does not
        # name, and the control is a pin at a path it DOES name: the first must
        # be reported and the second must not. One without the other is a
        # check that cannot fail.
        root = Path(d) / "tree"
        (root / "assets" / "planted").mkdir(parents=True, exist_ok=True)
        (root / "assets" / "planted" / "PIN").write_text("{}")
        if "assets/planted/PIN" not in unlisted_pins(root):
            problems.append("a pin at a path PINS does not name was NOT reported, so an "
                            "artefact could be added to the tree and fetched by nothing")
        (root / "contract").mkdir(parents=True, exist_ok=True)
        (root / "contract" / "PIN").write_text("{}")
        listed = unlisted_pins(root)
        if "contract/PIN" in listed:
            problems.append("a pin PINS DOES name was reported unlisted, so every clone "
                            "would fail the check")
        if sorted(listed) != ["assets/planted/PIN"]:
            problems.append("the unlisted walk reported %r, not the planted pin alone"
                            % sorted(listed))

    for p in problems:
        print(f"  SELFTEST: {p}", file=sys.stderr)
    print("  fetch selftest: %s" % ("FAILED" if problems else "host_base, row override and "
                                    "no-host all behave; no URL decides a path; --require "
                                    "reports an absent required row and only that; an "
                                    "unlisted pin is reported and a listed one is not"))
    return 1 if problems else 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--timeout", type=float, default=60.0)
    ap.add_argument("--list", action="store_true",
                    help="report what would be fetched and exit without network")
    ap.add_argument("--selftest", action="store_true",
                    help="check decision 972's three branches against a synthetic pin")
    ap.add_argument("--quiet", action="store_true",
                    help="tally only; a multi-file artefact makes a per-row log unreadable")
    ap.add_argument("--require", action="append", default=[], metavar="PIN",
                    help="fail unless every fetched row of this pin is present afterwards. "
                         "For a gate, where an absent artefact is a run that did not happen "
                         "rather than a valid clone.")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()

    # BEFORE ANY FETCH, because an artefact missing from the tuple cannot be
    # reported by a step that only walks the tuple.
    stray = unlisted_pins(ROOT)
    if stray:
        print("these pins exist in the tree and PINS does not name them, so nothing "
              "fetches them and no other step would have said so:", file=sys.stderr)
        for q in stray:
            print(f"    {q}", file=sys.stderr)
        print("Add each to PINS in this file, or delete the pin.", file=sys.stderr)
        return 1

    required = set()
    for r in a.require:
        # Named by PIN PATH, not by file name, for the same reason a
        # destination is the pin's key: one place decides what belongs to
        # which artefact, and it is the pin.
        pin_path = (ROOT / r).resolve()
        if not pin_path.exists():
            print(f"--require names {r}, which is not a pin in this tree.", file=sys.stderr)
            return 1
        required.add(pin_path)

    rows = [r for p in PINS for r in wanted(ROOT / p)]
    if not rows:
        print("no fetched artefacts declared -- every vendored file is committed. "
              "This is a valid and expected state.")
        return 0

    failed = False
    tally: dict[str, int] = {}
    for r in rows:
        if a.list:
            state = "present" if r["path"].exists() else "absent"
            if not a.quiet:
                print(f"  {r['name']}  {r['bytes'] or '?'} bytes  {state}  "
                      f"host={r['host_from'] or 'NOT SET'}")
            tally[state] = tally.get(state, 0) + 1
            continue
        outcome = fetch_one(r, a.timeout)
        tally[outcome.split(" ")[0]] = tally.get(outcome.split(" ")[0], 0) + 1
        if not a.quiet or outcome not in ("matches", "fetched"):
            print(f"  {r['name']}: {outcome}")
        if outcome == "MISMATCH":
            failed = True
            print(f"      present but does not match its PIN. Delete it and re-run; "
                  f"this tool will not overwrite a file it did not fetch.")
        elif outcome == "no-host":
            print(f"      absent and no host configured in {r['pin'].relative_to(ROOT)}. "
                  f"That is a valid clone -- checks needing it will skip and say so.")
    # A 496-row artefact makes a per-row log unreadable, so the tally is
    # printed whether or not the rows were. It reports OUTCOMES and never
    # hosts: "fetched from the expected host" is not part of any pass.
    print("  %d rows: %s" % (len(rows),
                             ", ".join(f"{n} {k}" for k, n in sorted(tally.items()))))

    # THE REQUIRED HALF, CHECKED AGAINST THE DISK AND NOT AGAINST THE OUTCOME.
    # A row can report `matches` and a row can report `unreachable`; what a
    # gate needs to know is whether the bytes are there now, which is one
    # question with one answer.
    missing = missing_required(rows, required)
    for r in missing:
        print(f"  REQUIRED AND ABSENT: {r['name']} ({r['pin'].relative_to(ROOT)})",
              file=sys.stderr)
    if missing:
        print(f"  {len(missing)} required file(s) could not be brought in. This is a gate "
              f"refusing to certify a tree it could not assemble, not a broken clone: "
              f"without them the checks that read them fail one by one and name the "
              f"symptom rather than the cause.", file=sys.stderr)
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
