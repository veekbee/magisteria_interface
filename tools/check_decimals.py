#!/usr/bin/env python3
"""
check_decimals.py -- which numbers change when Godot reads them.

THE DEFECT THIS EXISTS FOR. Godot's decimal-to-double conversion is not
correctly rounded, and the error is not a uniform ulp. Measured in this engine
(4.7.2), a plain-decimal literal is exact through seventeen digits after the
point and degrades from the eighteenth, monotonically, reaching **35%** by
1e-17. Subnormals do not survive at all: every subnormal decimal -- `1e-310` as
readily as `5e-324` -- parses to exactly zero, in the source lexer and the JSON
parser alike.

AND GODOT'S OWN WRITER EMITS THE FORM ITS READER CANNOT READ. `JSON.stringify`
renders 1.55252999774486e-17 as `0.0000000000000000155252999774486`. So a
Godot-written artefact does not round-trip through Godot, and the same value in
scientific notation would have parsed exactly. This is not a fault in any
document here; it is a property of the reader, which is why the comparison runs
against what the engine actually returned rather than against the text.

HOW IT IS CHECKED. `decimal_leaves.gd` parses every inbound JSON in Godot and
dumps each numeric leaf's bit pattern. This compares those against Python's
correctly-rounded parse of the same leaf and sorts the disagreements by how
much they actually move the number:

  * LOST    -- a non-zero decimal that Godot reads as 0.0. Always a defect:
               the value is not approximated, it is gone.
  * GROSS   -- relative error above 1e-6. Big enough that some consumer could
               care, so it has to be looked at rather than tallied.
  * MINOR   -- at or below 1e-6. Reported per file and not failed.

MINOR IS REPORTED RATHER THAN TOLERATED, AND THE DIFFERENCE MATTERS. Decision
985 turned on a ONE-ULP error in a lattice corner: the smallest disagreement
this file can measure was, in that instance, the whole problem. So a small
relative error is not evidence that a value is unimportant -- it is evidence
that this check cannot tell, and the answer for any value whose exact double
matters is to publish it as bits, the way `origin_hex` and `min_nonzero_bits`
do. The counts print every run so that a new one is visible rather than
absorbed into a total nobody reads.

THE EXCEPTIONS ARE NAMED, WITH REASONS, AND THEY ARE NOT A TOLERANCE. Each
covers a specific path prefix that is known to disagree and understood; a new
disagreement anywhere else fails.
"""
from __future__ import annotations

import json
import pathlib
import struct
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIRS = ["assets/contours", "assets/detail", "assets/families", "assets/fixture",
        "assets/terrain", "contract", "measurements", "measurements/flights"]

#: Relative error above which a disagreement must be understood rather than counted.
GROSS = 1e-6

#: Known disagreements, by path substring, each with the reason it is not acted on.
#: A reason is required: an exception with no reason is a value nobody checked.
ALLOWED = {
    "/min_nonzero_magnitude": (
        "a field whose NAME is a minimum non-zero magnitude, published as a subnormal decimal, "
        "arriving as 0.0. Fixed upstream at magisteria@b9287f1, which now publishes "
        "`min_nonzero_bits` beside it and refuses to emit a bare subnormal anywhere in a "
        "manifest; it reaches this repo with the next fixture re-vendor. Nothing here reads the "
        "field, and when something does it must read the bits."),
    "flights/scripted.trace.json/frames/": (
        "quaternion components at 1e-16 and below -- numerical zero in a unit rotation, and "
        "already below the trace writer's own 1e-6 orientation quantum. This trace was recorded "
        "at af3d023, before `FlightTrace.add` snapped orientation, so the components that should "
        "have been zeroed at write time survived to be misread at read time. `pose_of` "
        "normalises, so the worst of them moves the basis by about 1e-17 radians."),
}


def _bits(x: float) -> int:
    return struct.unpack("<Q", struct.pack("<d", x))[0]


def _double(b: int) -> float:
    return struct.unpack("<d", struct.pack("<Q", b))[0]


def _allowed_for(path: str):
    for key, why in ALLOWED.items():
        if key in path:
            return key, why
    return None, None


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: check_decimals.py <leaves.tsv>")
        return 2
    tsv = pathlib.Path(sys.argv[1])
    if not tsv.exists():
        print("decimals: no leaf dump at %s -- decimal_leaves.gd did not run" % tsv)
        return 1
    godot = {}
    for line in tsv.read_text().splitlines():
        path, bits = line.split("\t")
        godot[path] = int(bits, 16)

    lost, gross, minor = [], [], []
    leaves = 0

    def walk(v, path):
        nonlocal leaves
        if isinstance(v, dict):
            for k in v:
                walk(v[k], "%s/%s" % (path, k))
        elif isinstance(v, list):
            for i, x in enumerate(v):
                walk(x, "%s/%d" % (path, i))
        elif isinstance(v, bool):
            return
        elif isinstance(v, (int, float)):
            leaves += 1
            g = godot.get(path)
            if g is None or g == _bits(float(v)):
                return
            got = _double(g)
            want = float(v)
            if got == 0.0 and want != 0.0:
                lost.append((path, want, got, 1.0))
                return
            rel = abs(got - want) / abs(want) if want != 0.0 else float("inf")
            (gross if rel > GROSS else minor).append((path, want, got, rel))

    files = sorted(str(q.relative_to(ROOT))
                   for d in DIRS for q in (ROOT / d).glob("*.json"))
    for rel_path in files:
        walk(json.loads((ROOT / rel_path).read_text()), rel_path)

    print("decimals: %d numeric leaves across %d documents" % (leaves, len(files)))
    if leaves == 0 or not godot:
        print("decimals: nothing was compared, so this check proved nothing")
        return 1

    by_file = Counter(p.split(".json")[0] + ".json" for p, _, _, _ in minor)
    print("decimals: %d minor (<= %g relative), %d gross, %d lost"
          % (len(minor), GROSS, len(gross), len(lost)))
    for f, c in by_file.most_common():
        print("decimals:   %6d  %s" % (c, f))

    failed = 0
    for label, rows in (("LOST", lost), ("GROSS", gross)):
        for path, want, got, rel in rows:
            key, why = _allowed_for(path)
            if key is None:
                print("decimals: %s %s\n  wants %r, Godot reads %r (relative %.3g)"
                      % (label, path, want, got, rel))
                failed += 1
    for key, why in ALLOWED.items():
        hit = sum(1 for rows in (lost, gross)
                  for p, _, _, _ in rows if key in p)
        # AN EXCEPTION THAT COVERS NOTHING IS DELETED, NOT KEPT IN CASE. It
        # would otherwise sit here reading as a known problem long after the
        # re-vendor that fixed it, and the next person would work around a
        # defect that is not there any more.
        state = "%d" % hit if hit else "NONE LEFT -- delete this exception"
        print("decimals: allowed %-42s %s" % (key, state))

    if failed:
        print("decimals: %d disagreement(s) that are neither small nor accounted for" % failed)
        return 1
    print("decimals: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
