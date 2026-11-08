#!/usr/bin/env python3
"""
rewrite_pins.py -- re-author an existing `pins.json` without losing a bit.

WHY THIS IS PYTHON AND THE EXPLORER IS NOT. Godot's decimal-to-double
conversion is not correctly rounded, and `tools/check_decimals.py` carries the
measurement: at EPSG:5070 magnitudes a coordinate with ten digits after the
point already parses ONE ULP LOW, and all three of Godot's text-to-double paths
fail identically on it -- `JSON.parse_string`, a GDScript float literal, and
`String.to_float`. So **no value may reach a Godot float parse on the
explorer's path.** Re-authoring a file is a text-to-text job and Python's parse
and repr are correctly rounded both ways, so the bits survive by construction.

THIS TOOL VALIDATES NOTHING, AND THAT IS A RULE RATHER THAN AN OMISSION. Every
form rule lives in `src/dressing/pin_file.gd`; every bound rule lives in
magisteria's emission tool. If this file ever starts checking a field, it has
become a second copy of a rule that is enforced elsewhere, and it should be
refused at review. It moves text. That is all it does.

WHAT IT GUARANTEES. A pin the author did not move keeps its SOURCE BYTES.
Numbers are read with `parse_float=str` so they are never converted to a float
at all; they are carried through as the exact characters the author wrote and
re-emitted verbatim. A pin created or edited in the explorer arrives as a
computed double and is written by Python's `repr`, which is the shortest
round-tripping form.

Usage:
    python3 tools/rewrite_pins.py --rows <pins.json> --out <out.json> \
        --base-dressing sha256:<hex> --schedule-digest sha256:<hex>
    python3 tools/rewrite_pins.py --selftest
"""
from __future__ import annotations

import argparse
import json
import struct
import sys

#: Exactly the top-level set the emission tool admits, less `generated_by`,
#: which the tool strips and rewrites -- so emitting one here would be a
#: provenance claim that cannot survive.
TOP_KEYS = ("what", "form", "ruled_by", "base_dressing",
            "schedule_content_digest", "pins")

#: The only int-typed fields at load, confirmed against the loader rather than
#: inferred. Every other number loads through a check accepting an int or a
#: finite float, so converting one would rewrite `share: 1.0` into `1`.
INT_FIELDS = ("from", "to")


class _Raw(str):
    """A number carried as its own source text, never as a float.

    `json.dump` would quote a `str`, so these are spliced back in after
    serialisation through a placeholder. The point is that the characters the
    author wrote are the characters emitted -- no parse, no repr, no rounding.
    """


def _rawify(v):
    """Read numbers as `_Raw`, so nothing is ever converted to a float."""
    if isinstance(v, dict):
        return {k: _rawify(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_rawify(x) for x in v]
    return v


def _dump(doc) -> str:
    """Serialise with `_Raw` numbers emitted unquoted and unrounded."""
    marks: dict[str, str] = {}

    def mark(v):
        if isinstance(v, _Raw):
            # THE SENTINEL MUST SURVIVE `json.dumps` UNCHANGED. A NUL does not:
            # `dumps` escapes it to `\u0000`, so a literal-NUL search finds
            # nothing and every number is emitted as a QUOTED placeholder. That
            # is what the first cut of this did, and the selftest caught it.
            key = "@@RAW%d@@" % len(marks)
            marks[key] = str(v)
            return key
        if isinstance(v, dict):
            return {k: mark(x) for k, x in v.items()}
        if isinstance(v, list):
            return [mark(x) for x in v]
        return v

    marked = mark(doc)
    text = json.dumps(marked, indent=1, ensure_ascii=False)
    for key, raw in marks.items():
        text = text.replace('"%s"' % key, raw)
    # AND NOTHING MAY SURVIVE AS A PLACEHOLDER. If the sentinel ever appears in
    # authored text, or an escape defeats the substitution again, a number would
    # be emitted as a quoted string and the file would load as nonsense. This
    # refuses instead.
    if "@@RAW" in text:
        raise ValueError("a number was not spliced back: a placeholder survived "
                         "serialisation, so the emitted file would quote a number")
    return text + "\n"


def rewrite(rows_path: str, base_dressing: str, schedule_digest: str) -> str:
    with open(rows_path, encoding="utf-8") as f:
        # `parse_float=_Raw` is the whole mechanism: a coordinate is never a
        # float in this process, so it cannot be rounded by one.
        src = json.load(f, parse_float=_Raw)
    pins = src["pins"] if isinstance(src, dict) and "pins" in src else src
    out = []
    for pin in pins:
        row = dict(_rawify(pin))
        # The years are the one place a value must change TYPE. `_Raw` carries
        # "1877" and the loader wants an int, so it is converted here -- and
        # only here, and only for these two fields.
        for k in INT_FIELDS:
            if k in row and row[k] is not None:
                row[k] = int(str(row[k]))
        out.append(row)
    return _dump({
        "what": ("pin rows re-authored over a committed dressing, in §22.8.4's form"
                 " -- placed by magisteria's emission tool (§25 backlog 690)"),
        "form": "§22.8.4 pins; the explorer's emission format is §22.8.9 (decision 2075)",
        "ruled_by": "decision 2075",
        "base_dressing": base_dressing,
        "schedule_content_digest": schedule_digest,
        "pins": out,
    })


def selftest() -> int:
    """THE CASE IS THE COORDINATE THIS ENGINE GETS WRONG; THE CONTROL IS THE ONE
    IT GETS RIGHT. A selftest witnessed only on the second would pass while the
    first was displaced -- which is exactly how the defect survived four probe
    rounds tonight.
    """
    import os
    import tempfile
    a, b = -1689313.6678021685, 1328912.2044408391
    want_a, want_b = "3a15f5aae1c639c1", "1e3c563410473441"
    rows = ('{"pins":[{"pin_id":"s1","kind":"feature","type":"rail_yard",'
            '"from":1877,"to":1900,"authored_by":"owner","share":1.0,'
            '"polygon":[[-1689313.6678021685,1328912.2044408391]]}]}')
    fd, path = tempfile.mkstemp(suffix=".json")
    os.write(fd, rows.encode())
    os.close(fd)
    try:
        text = rewrite(path, "sha256:" + "a" * 64, "sha256:" + "b" * 64)
    finally:
        os.unlink(path)
    doc = json.loads(text)
    bad = []
    if sorted(doc) != sorted(TOP_KEYS):
        bad.append("top-level keys are %s, not %s" % (sorted(doc), sorted(TOP_KEYS)))
    pin = doc["pins"][0]
    got_a, got_b = pin["polygon"][0]
    for label, got, want, ref in (("A", got_a, want_a, a), ("B", got_b, want_b, b)):
        bits = struct.pack("<d", got).hex()
        if bits != want:
            bad.append("coordinate %s round-tripped to %s, not %s (%r against %r)"
                       % (label, bits, want, got, ref))
    for k in INT_FIELDS:
        if not isinstance(pin[k], int):
            bad.append("`%s` is %r, not an int" % (k, pin[k]))
    # `share` must NOT have been turned into an int: it is not an INT_FIELD.
    if "1.0" not in text:
        bad.append("`share: 1.0` did not survive as a float; only %s convert" % str(INT_FIELDS))
    # A NEGATIVE CONTROL ON THE MECHANISM ITSELF: the source text must be
    # emitted verbatim, so the long literal appears in the output unchanged.
    if "-1689313.6678021685" not in text:
        bad.append("the source text of coordinate A was not emitted verbatim")
    for line in bad:
        print("rewrite_pins selftest: %s" % line, file=sys.stderr)
    print("rewrite_pins selftest: %s" % ("ok" if not bad else "%d problem(s)" % len(bad)))
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows")
    ap.add_argument("--out")
    ap.add_argument("--base-dressing")
    ap.add_argument("--schedule-digest")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    for need in ("rows", "out", "base_dressing", "schedule_digest"):
        if getattr(a, need) is None:
            print("rewrite_pins: --%s is required; nothing is defaulted"
                  % need.replace("_", "-"), file=sys.stderr)
            return 2
    text = rewrite(a.rows, a.base_dressing, a.schedule_digest)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(text)
    print("rewrite_pins: %d pin(s) -> %s" % (len(json.loads(text)["pins"]), a.out))
    print("rewrite_pins: VALIDATES NOTHING. Form is src/dressing/pin_file.gd's; "
          "the bounds, the footprint and the stamp are the emission tool's.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
