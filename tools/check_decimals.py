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

AND EVERY DISAGREEMENT IS EITHER PROTECTED OR NAKED, which is the distinction
that decides whether any of it matters. A value published with its bit pattern
beside it -- nested `{"dec": ..., "hex": ...}` or flat `<name>_bits` -- has a
correct route into this client, and the decimal that disagrees is decoration
this repo does not read. A value published as a bare decimal has no such route.

The first cut of this file could not tell those apart, and reported the detail
lattice's corner (protected by `origin_hex` since decision 985's amendment,
read from the pattern, exact) in the same breath as three
`amplitude_m_at_parent` values that are PARAMETERS OF THE PUBLISHED FUNCTION
with nothing behind them. Four disagreements in one file, one of them
meaningless and three of them the client and the emitter evaluating `d(x, y)`
with different numbers -- inside the conformance tolerance, so nothing failed.
A count that mixes those is a count nobody can act on.

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

#: Artefacts whose scalars ARE the published function's parameters, so that a
#: naked one is named however small the disagreement. Not a list of files that
#: matter more -- a list of files where every number is load-bearing by
#: construction, and where "small" is therefore no evidence of anything.
PARAMETER_ARTEFACTS = ("assets/detail/detail_rows.json",)

#: How many of the remaining naked disagreements to name rather than count. A
#: report that prints fifty-five lines every green run is one people stop
#: reading, and then it does not matter what the fifty-sixth said.
NAMED_AT_MOST = 6

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


def _protection_of(container, key) -> str:
    """Is the leaf at `key` inside `container` published with its bits?

    Returns "nested", "flat", or "" for naked. A list element inherits its
    list's protection, because `origin` and `origin_hex` are published as
    parallel arrays and an element of one is answered by the element of the
    other."""
    if isinstance(container, dict):
        if isinstance(container.get(key), dict) and "hex" in container[key]:
            return "nested"
        if isinstance(key, str):
            if ("%s_bits" % key) in container:
                return "flat"
            if ("%s_hex" % key) in container:
                return "flat_hex"
            # The leaf may BE the `dec` of a nested block, in which case the
            # block itself carries the hex and this element is protected.
            if key == "dec" and "hex" in container:
                return "nested"
    return ""


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

    def walk(v, path, protection=""):
        nonlocal leaves
        if isinstance(v, dict):
            for k in v:
                walk(v[k], "%s/%s" % (path, k), _protection_of(v, k))
        elif isinstance(v, list):
            # An element inherits the list's protection: `origin` and
            # `origin_hex` are parallel arrays, so element i of one is answered
            # by element i of the other.
            for i, x in enumerate(v):
                walk(x, "%s/%d" % (path, i), protection)
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
                lost.append((path, want, got, 1.0, protection))
                return
            rel = abs(got - want) / abs(want) if want != 0.0 else float("inf")
            (gross if rel > GROSS else minor).append((path, want, got, rel, protection))

    files = sorted(str(q.relative_to(ROOT))
                   for d in DIRS for q in (ROOT / d).glob("*.json"))
    for rel_path in files:
        walk(json.loads((ROOT / rel_path).read_text()), rel_path)
    everything = lost + gross + minor
    naked = [r for r in everything if not r[4]]

    print("decimals: %d numeric leaves across %d documents" % (leaves, len(files)))
    if leaves == 0 or not godot:
        print("decimals: nothing was compared, so this check proved nothing")
        return 1

    print("decimals: %d minor (<= %g relative), %d gross, %d lost"
          % (len(minor), GROSS, len(gross), len(lost)))
    print("decimals: %d of those %d are protected by a published pattern, %d are naked"
          % (len(everything) - len(naked), len(everything), len(naked)))
    by_file = Counter(p.split(".json")[0] + ".json" for p, _, _, _, _ in everything)
    naked_by_file = Counter(p.split(".json")[0] + ".json" for p, _, _, _, _ in naked)
    for f, c in by_file.most_common():
        print("decimals:   %6d  %-58s naked %d" % (c, f, naked_by_file.get(f, 0)))
    # NAMED IN A VENDORED ARTEFACT, COUNTED IN MY OWN MEASUREMENTS, and the
    # split is the whole point. A naked disagreement under `assets/` or
    # `contract/` is a value the emitter and this client hold DIFFERENTLY with
    # no route to the right one -- two sides evaluating the same function from
    # different numbers. The same thing under `measurements/` is this repo
    # disagreeing with its own output, which is worth knowing and is nobody
    # else's problem.
    #
    # Sorting by relative error alone hid exactly the ones that matter: the
    # three `amplitude_m_at_parent` values in `detail_rows.json` are parameters
    # of the published `d(x, y)` and disagree at the ulp, so they sorted below
    # six quaternion components of my own flight noise and never printed.
    vendored = [r for r in naked if not r[0].startswith("measurements/")]
    mine = [r for r in naked if r[0].startswith("measurements/")]
    params = [r for r in vendored if any(a in r[0] for a in PARAMETER_ARTEFACTS)]
    rest = sorted((r for r in vendored if r not in params), key=lambda r: -r[3])

    def say(rows, head):
        if not rows:
            return
        print("decimals: %s" % head)
        for path, want, got, rel, _ in rows:
            print("decimals:   %s\n              wants %r, reads %r (relative %.3g)"
                  % (path, want, got, rel))

    # EVERY ONE OF THESE, HOWEVER SMALL. `detail_rows.json` IS the published
    # function's parameter block, so a naked scalar in it is not a diagnostic
    # that disagrees -- it is a number the emitter evaluates `d(x, y)` from and
    # this client evaluates it from differently. Ranking by relative error hid
    # all three behind six quaternion components of my own flight noise.
    say(params, "naked in a published parameter block -- these are inputs to d(x, y):")
    say(rest[:NAMED_AT_MOST],
        "%d other naked disagreement(s) in vendored artefacts, worst %d named:"
        % (len(rest), min(len(rest), NAMED_AT_MOST)))
    print("decimals: %d naked in this repo's own measurements (worst %.3g relative)"
          % (len(mine), max((r[3] for r in mine), default=0.0)))

    failed = 0
    for label, rows in (("LOST", lost), ("GROSS", gross)):
        for path, want, got, rel, _prot in rows:
            key, why = _allowed_for(path)
            if key is None:
                print("decimals: %s %s\n  wants %r, Godot reads %r (relative %.3g)"
                      % (label, path, want, got, rel))
                failed += 1
    for key, why in ALLOWED.items():
        hit = sum(1 for rows in (lost, gross)
                  for p, _, _, _, _ in rows if key in p)
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
