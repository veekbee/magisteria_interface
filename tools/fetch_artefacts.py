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
        "assets/contours/PIN")


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def wanted(pin_path: Path) -> list[dict]:
    """The fetched rows of one PIN, with everything needed to act on them."""
    if not pin_path.exists():
        return []
    pin = json.loads(pin_path.read_text())
    digests = pin.get("files", {})
    block = (pin.get("fetched") or {}).get("files", {})
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
        out.append({"pin": pin_path, "name": name,
                    "path": pin_path.parent / name,
                    "sha256": digests[name],
                    "bytes": meta.get("bytes"),
                    "host": meta.get("host")})
    return out


def fetch_one(row: dict, timeout: float) -> str:
    """Returns a one-word outcome; raises SystemExit on a verifiable failure."""
    dest, want = row["path"], row["sha256"]
    if dest.exists():
        return "matches" if sha256_file(dest) == want else "MISMATCH"
    if not row["host"]:
        return "no-host"
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


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--timeout", type=float, default=60.0)
    ap.add_argument("--list", action="store_true",
                    help="report what would be fetched and exit without network")
    a = ap.parse_args(argv)

    rows = [r for p in PINS for r in wanted(ROOT / p)]
    if not rows:
        print("no fetched artefacts declared -- every vendored file is committed. "
              "This is a valid and expected state.")
        return 0

    failed = False
    for r in rows:
        if a.list:
            state = "present" if r["path"].exists() else "absent"
            print(f"  {r['name']}  {r['bytes'] or '?'} bytes  {state}  "
                  f"host={'set' if r['host'] else 'NOT SET'}")
            continue
        outcome = fetch_one(r, a.timeout)
        print(f"  {r['name']}: {outcome}")
        if outcome == "MISMATCH":
            failed = True
            print(f"      present but does not match its PIN. Delete it and re-run; "
                  f"this tool will not overwrite a file it did not fetch.")
        elif outcome == "no-host":
            print(f"      absent and no host configured in {r['pin'].relative_to(ROOT)}. "
                  f"That is a valid clone -- checks needing it will skip and say so.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
