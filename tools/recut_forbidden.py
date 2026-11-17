#!/usr/bin/env python3
"""Re-cut §25 backlog 741's forbidden-name digests. THE ONLY THING THAT WRITES THEM.

WHAT THIS REPLACES, AND WHY A TOOL RATHER THAN A LIST. The guard it serves used
to carry eight names typed into `tests/run_headless.gd`, checked against ONE of
the seventy `.gd` files under `src/`. It passed for two reasons, neither of them
the one it was written for: the client reads none of the simulation's newer
fields, and the eight names were themselves committed in this public tree in
order to be forbidden. Measured at this landing, SIX OF THE EIGHT are no longer
derivable from the regenerated manifest at all -- they came from the superseded
one, and the artefact store's README declares itself deletable -- so a rework
that only derived its set would have silently stopped forbidding them. That is
why `explicit` exists below.

THE FORM THE OWNER CHOSE IS ONE SHA256 PER NAME, and it is what makes this
possible: the guard never needs a name's plaintext. It hashes each candidate
string out of this tree's own sources and asks whether that digest is in the
committed set. So a name can be forbidden while appearing nowhere -- not in the
guard, not in this tool, not in the data file -- which is exactly what the six
retired names and the two the backlog row cites by hand require.

SORTED BY HEX DIGEST AND NEVER BY NAME. Sorting the list by plaintext would
order it alphabetically by the names it exists not to publish, which hands a
reader the first letter of every one of them and the alphabetical neighbourhood
of each. The digests sort by their own bytes and carry no such order.

THE RULE. A derived name is forbidden when it is compound snake_case: six
characters or more, carrying an underscore, with two or more non-empty segments.
Measured against the manifest at `ceb4a0af`: 52 of its 293 derived names pass,
and the rule cuts collisions with this client's own seventy source files from 45
to 7. What it drops is ordinary words that appear in comment prose -- `height`
on 105 lines, `lattice` on 121, `nodata`, `derived`, `centres`, `bounds`,
`footprint` -- and what it keeps is compound field names, which is the shape a
leaked simulation name actually has. `explicit` entries are OUTSIDE the rule:
they are forbidden whatever their shape.

GROWTH RE-CUTS AND DEPARTURE REFUSES, and the two are different events on
purpose. A new name in a re-staged artefact is ordinary and `--recut` accepts
it. A name that STOPS being derivable is not ordinary: either the artefact
genuinely dropped it, or the derivation broke, and the two look identical from
here. So `--check` refuses, and the only way past is `--retire`, which moves
those digests into `explicit` where they keep refusing forever. Nothing silently
narrows the set.

AND A MISMATCH IS NEVER MADE GREEN BY PASTING THIS TOOL'S OUTPUT. The gate --
`tests/run_headless.gd`, which re-derives independently -- prints COUNTS and
never a digest, so there is nothing to paste. This tool prints plaintext names
for the delta, because whoever runs it holds the artefact already and the
terminal is not a committed file; and it writes only when told to, by a person,
with the flag that names what kind of change they believe they are making.
"""

import argparse
import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MANIFEST = "assets/dressing/da6-compact/manifest.json"
SESSION_FIXTURE = "tests/session_fixture"
VOCABULARY = "contract/dressing_vocabulary.json"
SCHEMA = "contract/schema.json"
OUT = "tests/forbidden_names.json"

MIN_LEN = 6
MIN_SEGMENTS = 2

# A dotted row name in `contract/schema.json`'s leaf strings -- `band.snowpack_swe`
# and its kind. Those ARE the public contract's vocabulary, where the file's other
# leaf strings are prose; allowing prose wholesale would allow whatever a sentence
# happened to quote, so the allow side takes the keys and these.
ROW_NAME = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$")


def forbidden_shape(name):
    """The rule. `explicit` entries do not pass through here."""
    return (len(name) >= MIN_LEN
            and "_" in name
            and len([s for s in name.split("_") if s]) >= MIN_SEGMENTS)


def digest(name):
    """sha256 of the name's UTF-8 bytes, lowercase hex.

    NO SALT, DELIBERATELY. A committed salt would not slow a guess down, and an
    uncommitted one could not be recomputed by the gate. The owner was asked and
    accepted that a guessed short name can be confirmed, in exchange for a
    mismatch that can name what moved; this is that trade, not an oversight.
    """
    return hashlib.sha256(name.encode("utf-8")).hexdigest()


def walk_strings(obj, keys, vals):
    """Every key and every leaf string, which is both halves of the derivation.

    BOTH HALVES, BECAUSE ONE WOULD MISS THE OTHER'S. Of the eight names the old
    typed list carried, one was a manifest key and seven were values only, so a
    keys-only derivation would have caught one of eight. The proportions run the
    other way in the artefact as a whole -- 261 keys against 36 leaf strings --
    which is exactly why neither half can stand for the set.
    """
    if isinstance(obj, dict):
        for k, v in obj.items():
            keys.add(k)
            walk_strings(v, keys, vals)
    elif isinstance(obj, list):
        for v in obj:
            walk_strings(v, keys, vals)
    elif isinstance(obj, str):
        vals.add(obj)


def names_of_json(path):
    with open(path, encoding="utf-8") as fh:
        doc = json.load(fh)
    keys, vals = set(), set()
    walk_strings(doc, keys, vals)
    return keys | vals


def session_files(root):
    """`session.json`, `year_<Y>/stats.json` and `commands/*.json`, as 2149 (1) names them.

    The committed fixture under `tests/session_fixture` is always one of these
    and is why this source is never empty -- see that directory's README. A real
    session directory, when one exists on the owner's machine, is passed with
    `--session` and adds to it.
    """
    out = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for fn in sorted(filenames):
            if fn.endswith(".json"):
                out.append(os.path.join(dirpath, fn))
    return sorted(out)


REASONED_GROUP = "client_own_names_colliding_by_coincidence"

# RULED AT ONE. The group holds names this client independently chose for its own
# data that happen to be spelled like a manifest key -- a coincidence no contract
# file can ever record and no derivation can fix. One is a reasoned exception;
# several would be the typed allow list this arrangement exists to avoid, so the
# count is asserted here and reported by the gate, and raising it is a decision.
REASONED_ALLOWED_AT_LANDING = 1


def planted_name():
    """The fixture's planted key, BY PREFIX. The full name is not written here.

    The scan covers every committed text file, so a literal in this tool would be
    a finding in this tool, and a guard that exempted its own writer would have
    started down the road of exempting what is inconvenient.
    """
    path = os.path.join(ROOT, SESSION_FIXTURE, "session.json")
    if not os.path.exists(path):
        return ""
    with open(path, encoding="utf-8") as fh:
        doc = json.load(fh)
    for k in doc:
        if k.startswith("zz_planted"):
            return k
    return ""


def reasoned_allowances():
    """The names allowed because they collide by coincidence, with their reasons."""
    with open(os.path.join(ROOT, VOCABULARY), encoding="utf-8") as fh:
        voc = json.load(fh)
    group = voc.get(REASONED_GROUP, {})
    return {k: v for k, v in group.items() if not k.startswith("_")}


def allow_set():
    """The allow side, DERIVED and not typed.

    Derived from `contract/dressing_vocabulary.json` -- the vocabulary of the
    formats this client implements, whose names it must therefore be able to
    write -- and from `contract/schema.json`'s own keys and row names. Both files
    are public and committed, which is the whole point: 741 removes a typed
    forbidden list, and replacing it with a typed ALLOW list would move the same
    defect one column to the left.
    """
    allow = set()
    with open(os.path.join(ROOT, VOCABULARY), encoding="utf-8") as fh:
        voc = json.load(fh)
    for group, entries in voc.items():
        if group.startswith("_") or not isinstance(entries, dict):
            continue
        for name in entries:
            if not name.startswith("_"):
                allow.add(name)
    with open(os.path.join(ROOT, SCHEMA), encoding="utf-8") as fh:
        schema = json.load(fh)
    keys, vals = set(), set()
    walk_strings(schema, keys, vals)
    allow |= keys
    allow |= {v for v in vals if ROW_NAME.match(v)}
    return allow


def derive(session_dirs, quiet=False):
    """Per source, because a non-empty control over the UNION cannot fail.

    The manifest alone makes the union non-empty, so a control taken over the
    whole set would pass while the session half contributed nothing and went
    unexercised. Each source is counted and asserted on its own.
    """
    allow = allow_set()
    per_source = {}

    man = os.path.join(ROOT, MANIFEST)
    if os.path.exists(man):
        per_source["manifest"] = names_of_json(man)
    else:
        per_source["manifest"] = None  # not fetched; see --check's named skip

    fixture = set()
    for path in session_files(os.path.join(ROOT, SESSION_FIXTURE)):
        fixture |= names_of_json(path)
    per_source["session_fixture"] = fixture

    live = set()
    for d in session_dirs:
        for path in session_files(d):
            live |= names_of_json(path)
    per_source["session_live"] = live if session_dirs else None

    kept = {}
    for source, names in per_source.items():
        if names is None:
            kept[source] = None
            continue
        kept[source] = {n for n in names if forbidden_shape(n) and n not in allow}
    if not quiet:
        for source in ("manifest", "session_fixture", "session_live"):
            names = per_source[source]
            if names is None:
                print("  %-16s not present" % source)
            else:
                print("  %-16s %4d names read, %3d forbidden by the rule"
                      % (source, len(names), len(kept[source])))
    return kept, allow


def load_committed():
    path = os.path.join(ROOT, OUT)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def write_committed(doc):
    doc["derived"] = sorted(set(doc["derived"]))
    doc["explicit"] = sorted(set(doc["explicit"]))
    with open(os.path.join(ROOT, OUT), "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=2, sort_keys=False)
        fh.write("\n")


def explained_by_allow(allow):
    """Digests of names the allow side now covers but the rule would otherwise forbid.

    THE THIRD CAUSE OF A DEPARTURE, FOUND BY RUNNING THIS. A committed digest can
    stop deriving for three reasons, not two: the artefact dropped the name, the
    derivation broke, or THE NAME MOVED TO THE ALLOW SIDE -- which is a deliberate
    narrowing recorded in a committed contract file, not a loss. The first run of
    this tool after `speed_m_s` was allowed refused with a departure and offered
    `--retire`, which would have forbidden a name this tree had just ruled
    legitimate, forever and with no live source to correct it from.

    So a departure is matched against the allow side first. That half is public
    and committed, so the name CAN be printed, and the report says which file
    explains it. Only an unexplained departure refuses.
    """
    return {digest(n): n for n in allow if forbidden_shape(n)}


def cmd_check(args):
    print("== deriving ==")
    kept, allow = derive(args.session)
    if kept["manifest"] is None:
        # THE NAMED SKIP, AND THE FLAG THAT STOPS THE GATE TAKING IT. A clone
        # without the bytes cannot re-derive and must not be told it is broken;
        # a gate that fetched them and then skipped would go green having
        # compared nothing, which is the shape §25 backlog 741 exists to remove.
        # So the gate passes --require-bytes and absence becomes a failure there
        # while staying a skip here. Ordering alone would not do it: this step
        # once sat ABOVE the transport step in tools/verify.sh, where the bytes
        # were not yet present, and the skip was taken silently.
        if args.require_bytes:
            print("-- REFUSED: --require-bytes was passed and the manifest is not fetched.")
            print("   The gate fetches it first (tools/fetch_artefacts.py --require")
            print("   assets/dressing/da6-compact/PIN); a run that skipped here would")
            print("   compare nothing and say so in the voice of a pass.")
            return 1
        print("-- SKIPPED THE MANIFEST HALF: the artefact is not fetched. This is the named")
        print("   skip a clone takes and the gate must not, which --require-bytes enforces.")
        print("   The enforcement half in tests/run_headless.gd needs no artefact and ran.")
        return 0
    live_names = set()
    for source, names in kept.items():
        if names:
            live_names |= names
    committed = load_committed()
    if committed is None:
        print("-- no %s yet; run with --recut to cut the first one" % OUT)
        return 1
    want = set(committed["derived"])
    have = {digest(n) for n in live_names}
    by_digest = {digest(n): n for n in live_names}
    added = have - want
    gone = want - have
    print()
    print("committed: %d derived, %d explicit" % (len(want), len(committed["explicit"])))
    if not added and not gone:
        print("ok -- the derived digests are exactly the committed ones")
        return 0
    if added:
        print("-- GROWTH: %d name(s) derive now and are not committed. Accept with --recut."
              % len(added))
        # THE NAMES ARE BEHIND A FLAG, AND THE REASON IS WHERE THIS RUNS. This
        # tool is gated in tools/verify.sh, and CI's logs for a PUBLIC repository
        # are public: a run that printed the delta's plaintext would publish, in
        # a build log, the names the committed digests exist to keep out of the
        # tree. So the default prints counts, and --names is for a person who
        # already holds the artefact and is reading their own terminal.
        if args.names:
            for d in sorted(added):
                print("     + %s" % by_digest[d])
        else:
            print("   Run with --names locally to see which; the default prints counts because")
            print("   this tool is gated and a public repository's build logs are public.")
    if gone:
        allowed_now = explained_by_allow(allow)
        explained = {d: allowed_now[d] for d in gone if d in allowed_now}
        unexplained = gone - set(explained)
        if explained:
            print("-- NARROWED BY THE ALLOW SIDE: %d name(s) now allowed by a committed"
                  % len(explained))
            print("   contract file, so they no longer derive. This is deliberate and")
            print("   --recut accepts it; the names are public, which is why they print:")
            for d in sorted(explained):
                print("     ~ %s  (%s)" % (explained[d], VOCABULARY))
        if unexplained:
            print("-- DEPARTURE: %d committed digest(s) no longer derive and the allow side"
                  % len(unexplained))
            print("   does not explain them. THIS REFUSES. Either the artefact dropped the")
            print("   name or the derivation broke, and the two look identical from here. If")
            print("   the drop is real, --retire moves them to `explicit`, where they keep")
            print("   refusing with no live source. Their plaintext cannot be printed: it is")
            print("   not in this tree, which is the point.")
    return 1


def cmd_recut(args):
    print("== deriving ==")
    kept, allow = derive(args.session)
    if kept["manifest"] is None:
        print("-- REFUSED: the manifest is not fetched, so a re-cut would drop every name")
        print("   derived from it. Fetch it first.")
        return 1
    live_names = set()
    for names in kept.values():
        if names:
            live_names |= names
    committed = load_committed() or {
        "derived": [], "explicit": [], "allowed_with_reason": {},
    }
    want = set(committed["derived"])
    have = {digest(n) for n in live_names}
    gone = want - have
    allowed_now = explained_by_allow(allow)
    explained = {d for d in gone if d in allowed_now}
    unexplained = gone - explained
    for d in sorted(explained):
        print("  ~ %s is now on the allow side; it leaves the derived set" % allowed_now[d])
    if unexplained and not args.retire:
        print("-- REFUSED: %d committed digest(s) no longer derive and the allow side does"
              % len(unexplained))
        print("   not explain them. A re-cut that wrote this set would narrow the guard")
        print("   silently. Use --retire to move them to `explicit`.")
        return 1
    doc = _document(committed, kept, sorted(have), sorted(
        set(committed["explicit"]) | (unexplained if args.retire else set())))
    gone = unexplained
    write_committed(doc)
    print()
    print("wrote %s: %d derived, %d explicit%s"
          % (OUT, len(doc["derived"]), len(doc["explicit"]),
             " (%d retired into it)" % len(gone) if gone and args.retire else ""))
    return 0


def cmd_add_explicit(args):
    """A name with no live source, hashed here and never written down.

    THE PLAINTEXT IS TYPED ON A COMMAND LINE AND GOES NO FURTHER. This is how
    the retired six and the two names §25 backlog 741's row cites by hand reach
    the set: a person who can read the row runs this once, and what lands in the
    tree is a digest.
    """
    name = args.add_explicit
    if "_" not in name and "." not in name:
        print("-- REFUSED: %r carries neither an underscore nor a dot." % name)
        print("   The scan only hashes substrings that carry one, because testing every")
        print("   substring of every token costs far more and buys nothing the rule wants.")
        print("   An explicit name outside that shape would be committed and never matched,")
        print("   which is worse than not committing it: it would look covered.")
        return 1
    committed = load_committed()
    if committed is None:
        print("-- cut the first list with --recut before adding an explicit name")
        return 1
    d = digest(name)
    if d in set(committed["explicit"]) or d in set(committed["derived"]):
        print("ok -- already forbidden; nothing written")
        return 0
    committed["explicit"] = sorted(set(committed["explicit"]) | {d})
    counts = committed.setdefault("counts_at_last_recut", {})
    counts["explicit"] = len(committed["explicit"])
    write_committed(committed)
    print("added one explicit digest; %d now" % len(committed["explicit"]))
    return 0


def _document(committed, kept, derived_digests, explicit_digests):
    counts = {}
    for source, names in kept.items():
        counts[source] = None if names is None else len(names)
    return {
        "_what": ("§25 backlog 741's forbidden names, as one sha256 per name. THE NAMES ARE "
                  "NOT HERE AND ARE NOT ANYWHERE IN THIS TREE. The guard hashes each "
                  "candidate string out of this repo's own sources and asks whether the "
                  "digest is below; a name can therefore be refused while appearing "
                  "nowhere. Written only by tools/recut_forbidden.py."),
        "_sorted_by": ("hex digest, NEVER by name. An alphabetical list would order these by "
                       "the names it exists not to publish, handing a reader the first "
                       "letter of every one and the neighbourhood of each."),
        "_rule": ("a derived name is forbidden when it is compound snake_case -- %d characters "
                  "or more, carrying an underscore, with %d or more non-empty segments. "
                  "Measured at the landing: 52 of the manifest's 293 derived names pass, and "
                  "the rule cuts collisions with this client's 70 source files from 45 to 7. "
                  "`explicit` entries are OUTSIDE the rule and are forbidden whatever their "
                  "shape." % (MIN_LEN, MIN_SEGMENTS)),
        "_derived_vs_explicit": ("`derived` is reproducible from the staged artefacts and the "
                                 "allow side, and the gate re-derives it independently every "
                                 "run. `explicit` has NO live source -- the six names the "
                                 "regenerated manifest no longer carries, and the two the "
                                 "backlog row cites by hand -- so it is never re-derived, "
                                 "never removed, and is the half that stops the rework being "
                                 "a silent narrowing."),
        "_growth_and_departure": ("growth re-cuts, departure refuses. A new name in a "
                                  "re-staged artefact is ordinary. A name that stops deriving "
                                  "is either a real drop or a broken derivation, and the two "
                                  "are indistinguishable from here, so --retire has to be "
                                  "asked for by a person."),
        "sources": {
            "manifest": MANIFEST,
            "session_fixture": SESSION_FIXTURE,
            "session_live": "passed with --session; absent in this tree by decision 2149 (1)",
            "allow_side": [VOCABULARY, SCHEMA],
        },
        "allowed_with_reason": committed.get("allowed_with_reason", {}),
        "counts_at_last_recut": dict(counts, explicit=len(explicit_digests),
                                     derived=len(derived_digests)),
        "derived": derived_digests,
        "explicit": explicit_digests,
    }


EXEMPT_FROM_SCAN = {
    # EXEMPT BY NAME, WITH THE REASON, AND NOTHING ELSE IS. Both of these would
    # trip the scan by doing their job, and neither can carry a leak a reader
    # could use.
    #
    # `tests/forbidden_names.json` holds digests and no plaintext, so the only
    # way it could match is if a digest were also a forbidden name -- and it
    # would still publish nothing.
    #
    # `contract/dressing_vocabulary.json` IS the allow side: every name in it is
    # one a committed ruling already makes public, and the scan reading it would
    # refuse the file that declares what is permitted.
    "tests/forbidden_names.json",
    "contract/dressing_vocabulary.json",
}

# A DERIVATION SOURCE NECESSARILY NAMES WHAT IT DERIVES, and the committed one
# is visible where the fetched one is not. `tests/session_fixture/` exists to be
# the second source (decision 2149 (1)), so every forbidden name it contributes
# is a name it holds -- it would be reported for doing its only job. The fetched
# manifest has the same property and is simply git-ignored.
#
# THE EXEMPTION IS CONDITIONAL, NOT BLANKET, which is the whole difference
# between this and a convenience. It holds only while every candidate under the
# directory is `zz_`-prefixed -- synthetic by construction, as its README
# requires. The moment a name that is not `zz_`-prefixed appears there, the
# exemption LAPSES for that file and it is scanned like anything else. So the
# exemption cannot be used to park a real name in the fixture.
FIXTURE_PREFIX = "zz_"
FIXTURE_DIR_PREFIX = "tests/session_fixture/"


def fixture_exemption_holds(text):
    """True when nothing in this fixture file is a non-synthetic compound name."""
    for c in candidates_of(text):
        if forbidden_shape(c) and not c.startswith(FIXTURE_PREFIX):
            return False
    return True


def tracked_files():
    """What `git ls-files` says is committed.

    THE ENUMERATION IS GIT'S BECAUSE NOTHING ELSE CAN ANSWER THE QUESTION.
    Decision 973's surface is every committed file, and "committed" is not a
    property of a path, an extension or a directory: the fetched artefacts sit
    under `assets/` beside PINs that ARE committed, carry the same `.json`
    extension, and hold every forbidden name by construction. A walk of the tree
    would have to guess, and a guess that swallowed one data file would report
    the swallowing as a pass.
    """
    import subprocess
    tracked = subprocess.run(["git", "ls-files"], cwd=ROOT,
                             capture_output=True, text=True, check=True)
    # AND THE FILES THAT ARE ABOUT TO BE COMMITTED. A scan of `ls-files` alone
    # checks the past: it cannot see the change being made, which is the only
    # moment at which a leak can still be stopped. This was not hypothetical --
    # the first wide scan of this very change reported 299 files and none of the
    # six new ones, because none was committed yet. `--exclude-standard` honours
    # .gitignore, so the fetched artefacts stay out.
    #
    # CONSEQUENCE, STATED RATHER THAN DISCOVERED: a scratch file left in the
    # working tree IS scanned, and will be reported if it carries a forbidden
    # name. That is the behaviour worth having -- it is the file most likely to
    # be committed by accident -- and in a gate the tree is clean anyway.
    untracked = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"],
                               cwd=ROOT, capture_output=True, text=True, check=True)
    out = tracked.stdout.split("\n") + untracked.stdout.split("\n")
    return sorted({f for f in out if f})


def candidates_of(text):
    """Every `\w+` run and every dot-joined run, COMMENTS AND PROSE INCLUDED.

    Prose is the point: the data is fetched and git-ignored, so the place a
    simulation name reaches this public tree is a comment, a test name, an error
    message or a PIN's own explanation. Four of the six files the first wide scan
    reported were prose.
    """
    out = set()
    for m in re.finditer(r"[A-Za-z_][A-Za-z0-9_]*", text):
        out.add(m.group(0))
    for m in re.finditer(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+", text):
        out.add(m.group(0))
    return out


SUBSTRING_FLOOR = 6


def segment_run_hit(s, forbidden):
    """Any run of this candidate's segments that is forbidden.

    Segment boundaries rather than every substring: every name the rule can
    forbid is compound snake_case and so is every identifier one could hide
    inside, so an embedded name sits AT a boundary. Stated as a limit rather
    than left implied -- a name buried off-boundary is not matched.
    """
    starts, ends = [0], [len(s)]
    for i, ch in enumerate(s):
        if ch in "_.":
            ends.append(i)
            starts.append(i + 1)
    for a in starts:
        for b in ends:
            if b - a < SUBSTRING_FLOOR:
                continue
            sub = s[a:b]
            if "_" not in sub and "." not in sub:
                continue
            if digest(sub) in forbidden:
                return sub
    return None


def cmd_scan(args):
    """The enforcement half over EVERY COMMITTED TEXT FILE, which needs no artefact.

    This half hashes this tree's own candidates against the committed digests,
    so it runs in a clone, in a gate and in CI, and it never skips. The
    re-derivation half -- does the committed set still match the artefacts --
    is the one that needs the bytes.
    """
    committed = load_committed()
    if committed is None:
        print("-- no %s; cut it with --recut first" % OUT)
        return 1
    forbidden = set(committed["derived"]) | set(committed["explicit"])
    files = tracked_files()
    scanned = 0
    binary = 0
    fixture_exempt = 0
    findings = {}
    for rel in files:
        if rel in EXEMPT_FROM_SCAN:
            continue
        path = os.path.join(ROOT, rel)
        if not os.path.isfile(path):
            continue
        with open(path, "rb") as fh:
            raw = fh.read()
        if b"\0" in raw[:8192]:
            binary += 1
            continue
        text = raw.decode("utf-8", errors="replace")
        if rel.startswith(FIXTURE_DIR_PREFIX):
            if fixture_exemption_holds(text):
                fixture_exempt += 1
                continue
            print("-- THE FIXTURE EXEMPTION HAS LAPSED for %s: it carries a compound name "
                  "that is not %s-prefixed, so it is scanned like any other file."
                  % (rel, FIXTURE_PREFIX))
        scanned += 1
        hits = set()
        for c in candidates_of(text):
            if digest(c) in forbidden:
                hits.add(c)
                continue
            if "_" in c or "." in c:
                h = segment_run_hit(c, forbidden)
                if h:
                    hits.add(h)
        if hits:
            findings[rel] = sorted(hits)
    print("scanned %d text files -- committed and about to be (%d binary skipped, %d exempt "
          "by name, %d fixture file(s) exempt while wholly %s-prefixed) -- against %d "
          "forbidden digests" % (scanned, binary, len(EXEMPT_FROM_SCAN), fixture_exempt,
                                 FIXTURE_PREFIX, len(forbidden)))
    if not findings:
        print("ok -- no committed file names a forbidden string")
        return 0
    print("-- %d file(s) name a forbidden string (decision 973, §25 backlog 741):"
          % len(findings))
    for rel in sorted(findings):
        if args.names:
            print("     %s: %s" % (rel, ", ".join(findings[rel])))
        else:
            print("     %s: %d name(s)" % (rel, len(findings[rel])))
    if not args.names:
        print("   Run with --names locally to see which. The default prints counts because")
        print("   this tool is gated and a public repository's build logs are public.")
    return 1


def cmd_selftest(_args):
    """Controls on the two things a quiet failure here would look like.

    THE RULE MUST DISCRIMINATE, and the digest must depend on the name. A rule
    that accepted everything and a digest that returned a constant would both
    produce a full, plausible, useless list.
    """
    bad = []
    # SYNTHETIC SHAPES, NOT REAL NAMES. The rule is purely structural -- a length,
    # an underscore, a segment count -- so a made-up compound exercises it exactly
    # as well as a real one, and writing real ones here would republish in this
    # tool the names the whole arrangement exists to keep out of the tree. The
    # first draft of this selftest used six of them, and nothing would have caught
    # it: the scan reads `src/`, and this file is not under `src/`.
    for name in ("zz_shape_two", "zz_shape_two_three", "ZZ_FORM_000", "zz1_annual",
                 "zz_clip_bilinear", "zz_long_compound_name"):
        if not forbidden_shape(name):
            bad.append("the rule rejects %r, which it must forbid" % name)
    for name in ("height", "lattice", "nodata", "bounds", "centres", "from", "by",
                 "tiles", "record", "plan"):
        if forbidden_shape(name):
            bad.append("the rule forbids %r, an ordinary word in this tree's prose" % name)
    if digest("a") == digest("b"):
        bad.append("the digest does not depend on the name")
    if digest("zz_shape_two") != hashlib.sha256(b"zz_shape_two").hexdigest():
        bad.append("the digest is not sha256 over the name's UTF-8 bytes")
    allow = allow_set()
    if "era_starts" not in allow:
        bad.append("the allow side does not carry `era_starts`, which the loader must name")
    if "schedule_plan_digest" not in allow:
        bad.append("the allow side does not carry `schedule_plan_digest`, a pin-format key")
    # THE CONDITIONAL EXEMPTION MUST BE ABLE TO LAPSE, or it is a blanket one
    # wearing a condition's clothes.
    if fixture_exemption_holds('{"zz_ok_name": 1}') is not True:
        bad.append("the fixture exemption does not hold for a wholly zz_-prefixed file")
    if fixture_exemption_holds('{"a_real_compound_name": 1}') is not False:
        bad.append("THE FIXTURE EXEMPTION CANNOT LAPSE: a non-synthetic compound name in the "
                   "fixture would be exempted, so the fixture could park a real name")
    planted = planted_name()
    if not planted:
        bad.append("the session fixture carries no `zz_planted`-prefixed key, so the second "
                   "source's control has nothing to look for")
    if planted and planted in allow:
        bad.append("the allow side carries a name the guard exists to forbid")
    reasoned = reasoned_allowances()
    if len(reasoned) != REASONED_ALLOWED_AT_LANDING:
        bad.append("%d reasoned allowance(s) where %d was ruled: a group that grows quietly "
                   "is the typed allow list this arrangement exists to avoid"
                   % (len(reasoned), REASONED_ALLOWED_AT_LANDING))
    for name, why in reasoned.items():
        if name not in allow:
            bad.append("the reasoned allowance %r is not in the allow side" % name)
        if len(str(why)) < 40:
            bad.append("the reasoned allowance %r carries no stated reason" % name)
    # THE ALLOW SIDE MUST BE DERIVED, NOT EMPTY AND NOT EVERYTHING.
    if not (10 <= len(allow) <= 400):
        bad.append("the allow side has %d entries, which is not a derived vocabulary"
                   % len(allow))
    fixture = set()
    for path in session_files(os.path.join(ROOT, SESSION_FIXTURE)):
        fixture |= names_of_json(path)
    if planted and planted not in fixture:
        bad.append("the session fixture no longer carries its planted name, so the second "
                   "source's control proves nothing")
    if bad:
        print("recut_forbidden selftest: FAILED")
        for b in bad:
            print("  -- %s" % b)
        return 1
    print("recut_forbidden selftest: ok -- the rule discriminates, the digest is sha256 over "
          "the name, the allow side is derived and does not swallow a forbidden name, and the "
          "fixture's planted name is present")
    return 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--recut", action="store_true",
                    help="write the derived digests (growth accepted)")
    ap.add_argument("--retire", action="store_true",
                    help="with --recut: move digests that no longer derive into `explicit`")
    ap.add_argument("--add-explicit", metavar="NAME",
                    help="hash one name with no live source into `explicit`")
    ap.add_argument("--session", action="append", default=[], metavar="DIR",
                    help="a real session directory to read beside the committed fixture")
    ap.add_argument("--require-bytes", action="store_true",
                    help="the artefact's absence is a failure, not a skip (the gate passes this)")
    ap.add_argument("--scan", action="store_true",
                    help="enforcement: every committed text file against the committed digests")
    ap.add_argument("--names", action="store_true",
                    help="print the plaintext of what matched; for a local terminal, never CI")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args(argv)
    if args.selftest:
        return cmd_selftest(args)
    if args.scan:
        return cmd_scan(args)
    if args.add_explicit:
        return cmd_add_explicit(args)
    if args.recut:
        return cmd_recut(args)
    return cmd_check(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
