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

ABSENT IS VALID. A clone with none of these files is a working clone; the checks
that need them skip and say so. Running this tool is therefore optional, and it
is a no-op when everything is present and matching.
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
        "assets/terrain/tiles/PIN", "assets/contours/PIN")


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

    for p in problems:
        print(f"  SELFTEST: {p}", file=sys.stderr)
    print("  fetch selftest: %s" % ("FAILED" if problems else "host_base, row override and "
                                    "no-host all behave; no URL decides a path"))
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
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()

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
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
