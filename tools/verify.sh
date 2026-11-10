#!/usr/bin/env bash
# THE gate. CI runs this file rather than a copy of its steps.
#
# WHY THIS EXISTS. A local check that greps a test runner's output for "OK"
# passes while the engine reports SCRIPT ERROR and exits non-zero -- which is
# how a runtime error reached CI green-locally. CI greps the log AND reads the
# exit code; anything less than both is a weaker gate than the one that
# matters, so this file is the only local invocation worth trusting.
#
# IT USED TO SAY "run exactly what CI runs" AND THAT STOPPED BEING TRUE. CI
# had four steps and this had six: the transport selftest, the tracked-tile
# guard and the compile check existed only here, so three of the gate's own
# checks never ran on a push. A sentence claiming two things are the same is
# not a mechanism for keeping them the same, so `.github/workflows/checks.yml`
# now invokes this script and there is one definition of the gate.
#
# AND IT COULD NOT FAIL. The last line was `[ "$fail" -eq 0 ] && echo ALL
# GREEN || echo FAILED`, whose exit status is the status of whichever `echo`
# ran -- always zero. So this printed FAILED and returned success, and anything
# wiring it into CI or a hook would have got a gate that always passes. It
# ends on `exit "$fail"` now, and the negative control is that CI's own red
# build is what found it.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
fail=0

echo "== contract pin =="
# THE SELFTEST FIRST, because the comparison it guards agrees on every artefact
# in the tree: a green content-digest check and one that cannot fire print the
# same line.
python3 tools/check_contract.py --selftest || fail=1
python3 tools/check_contract.py || fail=1

echo "== the explorer's file path (G-8) =="
# THE PYTHON HALF IS GATED, NOT MERELY PRESENT. `rewrite_pins.py` exists because
# no value may reach a Godot float parse: at EPSG:5070 magnitudes a coordinate
# parses one ulp low in all three of this engine's text-to-double paths. Its
# selftest witnesses the coordinate the engine gets WRONG, with the one it gets
# right as the control -- a selftest on the control alone would pass while the
# case was displaced.
python3 tools/rewrite_pins.py --selftest || fail=1

echo "== transport (decision 948/972) =="
python3 tools/fetch_artefacts.py --selftest || fail=1
# AND THEN ACTUALLY FETCH, which is the step whose absence made CI red for
# thirty commits. `fce9bd8` moved the 28 MB fixture binary out of the tree and
# onto a release asset; nothing taught either gate to bring it back, so every
# run since has been decoding an artefact that was not there. 38 failing
# checks, all of them one missing file.
#
# A no-op when the bytes are present, and it is `--require`d for the fixture
# alone. The tile pyramid is genuinely optional -- 141 MB of near-field
# detail, hosted locally, and the checks that need it skip and say so. The
# fixture binary is not optional in the same way: it is the artefact this
# client exists to display, and 1,526 of the suite's checks read it. A gate
# that let those skip would go green having run half of itself.
python3 tools/fetch_artefacts.py --quiet --require assets/fixture/PIN || fail=1
# THE DRESSING IS REQUIRED TOO, and for the fixture's reason rather than the
# pyramid's. G-9's identity check is the whole of window 1: if the bytes are
# absent it SKIPS AND SAYS SO, which is correct behaviour for a clone and
# useless in a gate -- the gate would go green having never recomputed a
# digest. 7.6 MB off a local host, so requiring it costs a fraction of a second.
python3 tools/fetch_artefacts.py --quiet --require assets/dressing/da6-compact/PIN || fail=1
# AND 730's REFERENCE, for the same reason: W2's comparison is the whole of that
# window, and if the reference is absent it SKIPS AND SAYS SO -- right for a
# clone, useless in a gate, which would then go green having compared nothing.
python3 tools/fetch_artefacts.py --quiet --require assets/dressing_renders/da6-compact/PIN \
  || fail=1
# THE BYTES MUST NOT BE COMMITTABLE BY ACCIDENT. 141 MB of tile pyramid and
# 437 MB of derived layers sit under assets/terrain/ once fetched, against a
# ~10 MB threshold. The .gitignore keeps them out; this is the check that the
# .gitignore still does, because a rule nobody verifies is a rule that survives
# exactly until someone adds a negation to it -- and the layers arrived by
# adding three negations to it.
#
# AND DA-6's DRESSING JOINS THEM UNDER A DIFFERENT RULE. Its four files are
# 7.6 MB in total and UNDER the threshold, so the size argument above does not
# reach them: they are fetched because decision 2129 answered decision 973's
# question that way (owner ruling 2130). Same guard, because the reason bytes
# must not be committable by accident does not depend on why they are fetched.
allow='^assets/(terrain/(tiles|layers)|dressing/da6-compact|dressing_renders/da6-compact)/(PIN|README\.md|\.gdignore)$'
tracked=$(git ls-files assets/terrain/tiles assets/terrain/layers assets/dressing \
  assets/dressing_renders | grep -vE "$allow" || true)
# A FILTER THAT CANNOT FIRE IS NOT A FILTER -- the lesson the engine-error awk
# below already learned. If the allow-list ever widens to swallow a data file,
# this guard goes silent and reports the swallowing as a pass, so the pattern is
# asserted against a path it MUST report and one it must NOT.
ctl_bad=$(printf 'assets/dressing/da6-compact/tiles.jsonl\nassets/dressing_renders/da6-compact/fold_1890.json\n' \
  | grep -vE "$allow" | tr '\n' ' ')
ctl_ok=$(printf 'assets/dressing/da6-compact/PIN\nassets/dressing_renders/da6-compact/PIN\n' \
  | grep -vE "$allow" || true)
want_bad='assets/dressing/da6-compact/tiles.jsonl assets/dressing_renders/da6-compact/fold_1890.json '
if [ "$ctl_bad" != "$want_bad" ] || [ -n "$ctl_ok" ]; then
  echo "-- the tracked-bytes allow-list does not discriminate: a fetched data file"
  echo "   was reported as [$ctl_bad] and the pin as [$ctl_ok]"; fail=1
fi
if [ -n "$tracked" ]; then
  echo "fetched bytes are tracked by git:"; echo "$tracked" | head -5; fail=1
else echo "ok -- only the pins, READMEs and .gdignores are tracked"; fi

echo "== no addons =="
[ -d addons ] && { echo "addons/ exists"; fail=1; } || echo "ok"

echo "== project imports =="
"$GODOT" --headless --import 2>&1 | tee /tmp/import.log >/dev/null
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load" /tmp/import.log; then
  echo "import produced script or parse errors"; grep -E "SCRIPT ERROR|Parse Error" /tmp/import.log | head -5; fail=1
else echo "ok"; fi

echo "== every script compiles =="
# A SCRIPT THAT FAILS TO COMPILE DOES NOT SAY SO WHERE YOU LOOK. `--import` does
# not compile GDScript, and a broken `class_name` script resolves at runtime to
# a bare GDScript with none of its statics -- so the symptom is "Nonexistent
# function 'load_from' in base 'GDScript'" a thousand lines into a test log,
# pointing at the caller rather than at the file with the error in it. Measured:
# a single inferred-Variant warning in `detail_field.gd` took four runs to
# locate that way. Loading every script names the file and the line.
"$GODOT" --headless --script res://tools/compile_check.gd 2>&1 | tee /tmp/compile.log
grep -q "^compile: all " /tmp/compile.log || { echo "-- not every script compiles"; fail=1; }

echo "== the pin run's verdict (W2) =="
# THE RE-PIN USED TO BE GREEN BY CONSTRUCTION. `run_headless.gd:_finish()` wrote
# the pin and quit 0 under `--pin-counts` before reaching its failure block, so a
# re-pin over a red suite exited 0, printed no `FAIL:` line, and had already
# written the broken counts as the new baseline -- the declaration-by-diff
# mechanism recording the damage as its own expectation.
#
# BOTH DIRECTIONS ARE ASSERTED, because one of them is not a control: a fix that
# refused to write unconditionally would pass a failure-only check while breaking
# re-pinning entirely. So a planted failure must refuse and exit non-zero, AND a
# clean run must still write.
#
# The two runs skip the suite (that is what the control flags do), so this costs
# about a second rather than two eight-minute runs. The clean run necessarily
# overwrites tests/check_counts.json with a near-empty pin, so it is backed up
# and restored, and the restore is itself asserted. If this script is killed
# between the two, `git checkout tests/check_counts.json` puts it back.
cp tests/check_counts.json /tmp/check_counts.backup.json
before=$(shasum -a 256 tests/check_counts.json | awk '{print $1}')
"$GODOT" --headless --script res://tests/run_headless.gd -- --pin-counts --control-plant-failure \
  > /tmp/pin_verdict_fail.log 2>&1
rc_fail=$?
after_fail=$(shasum -a 256 tests/check_counts.json | awk '{print $1}')
"$GODOT" --headless --script res://tests/run_headless.gd -- --pin-counts --control-no-failure \
  > /tmp/pin_verdict_pass.log 2>&1
rc_pass=$?
after_pass=$(shasum -a 256 tests/check_counts.json | awk '{print $1}')
cp /tmp/check_counts.backup.json tests/check_counts.json
restored=$(shasum -a 256 tests/check_counts.json | awk '{print $1}')
# A PARSE FAILURE IS NOT A VERDICT FAILURE, AND MUST NOT BE REPORTED AS ONE.
# This step first ran BEFORE `== project imports ==`, where a newly added
# `class_name` is not yet a registered global -- so both runs failed to parse
# the test script, executed nothing, and GODOT STILL EXITED 0. The control duly
# reported all three of its assertions failing and blamed the verdict, sending
# a reader to the wrong file. Godot's exit code does not see a parse error,
# which is why this script greps logs rather than trusting exits; this control
# has to do the same, and name the real cause.
probs=""
for lg in /tmp/pin_verdict_fail.log /tmp/pin_verdict_pass.log; do
  if grep -qE "SCRIPT ERROR|Parse Error" "$lg"; then
    echo "-- a control run did not execute: $lg carries a script or parse error, so the"
    echo "   assertions below would measure nothing. First error:"
    grep -m1 -E "SCRIPT ERROR|Parse Error" "$lg" | sed 's/^/     /'
    probs="$probs CONTROL-RUN-DID-NOT-EXECUTE"
  fi
done
[ "$rc_fail" -eq 0 ] && probs="$probs exited-0-over-a-failure"
grep -q "^FAIL: the planted control failure" /tmp/pin_verdict_fail.log \
  || probs="$probs did-not-name-the-failing-check"
[ "$before" != "$after_fail" ] && probs="$probs WROTE-THE-PIN-OVER-A-FAILURE"
[ "$rc_pass" -ne 0 ] && probs="$probs refused-a-clean-repin"
[ "$before" = "$after_pass" ] && probs="$probs did-not-write-when-clean"
[ "$before" != "$restored" ] && probs="$probs DID-NOT-RESTORE-THE-PIN"
if [ -n "$probs" ]; then
  echo "-- the pin run's verdict does not hold:$probs"; fail=1
else
  echo "ok -- a failure refuses the write and exits non-zero, naming the check; a clean run writes"
fi

echo "== decimals survive the reader =="
# Godot's decimal-to-double conversion is not correctly rounded, and its own
# JSON writer emits the plain-decimal form its reader is worst at. Decision 985
# turned on a single ulp in a lattice corner, so "the artefact is correct" and
# "the client reads the artefact correctly" are different claims and only one of
# them was ever checked. This checks the other one.
"$GODOT" --headless --script res://tools/decimal_leaves.gd -- /tmp/decimal_leaves.tsv \
  2>&1 | grep -v "Exponent too high" | tee /tmp/decimals_dump.log >/dev/null
grep -q "^decimal_leaves: " /tmp/decimals_dump.log \
  || { echo "-- the leaf dump did not run"; fail=1; }
python3 tools/check_decimals.py /tmp/decimal_leaves.tsv || fail=1

echo "== headless tests =="
"$GODOT" --headless --script res://tests/run_headless.gd 2>&1 | tee /tmp/test.log
rc=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|^FAIL:" /tmp/test.log; then
  echo "-- script errors or failures in the test log"; fail=1
fi
# AN ERROR THE ENGINE RAISED, AS OPPOSED TO ONE THIS CODE CHOSE TO PRINT.
#
# The greps above look for `SCRIPT ERROR`, and a whole class of fault does not
# say that. Measured: `print("a %s" + "b" % [x])` binds `%` tighter than `+`,
# so the format lands on the tail fragment alone; the engine reports `ERROR:
# String formatting error` and the line prints its own format string. That
# survived every green run since it was written, and CI found it only because
# a different failure made someone read the log.
#
# Failing on `ERROR:` outright does not work here, and that is not an accident:
# this repo uses `push_error` for DESIGNED refusals that tests then assert --
# aspect refusing a scalar read, the console refusing an unprefixed verb. A
# green run emits exactly two, and both are the point.
#
# So the discriminator is the `at:` line, which names the C++ frame that raised
# it. `push_error` and `push_warning` are this code speaking; anything else is
# the engine. A green run leaves zero.
engine_err=$(awk '
  /^ERROR: /            { err = 1; msg = $0; next }
  /^ *at: /             { if (err && $0 !~ /push_error/) print msg; err = 0; next }
                        { err = 0 }' /tmp/test.log)
# AND THE RULE HAS A NEGATIVE CONTROL, because a filter that cannot fire is not
# a filter -- the lesson `compile_check.gd` and `fetch_artefacts.py --selftest`
# both learned the hard way.
control=$(printf 'ERROR: chosen\n   at: push_error (core/variant/variant_utility.cpp:1023)\nERROR: raised\n   at: validated_evaluate (core/variant/variant_op.h:770)\n' | awk '
  /^ERROR: /            { err = 1; msg = $0; next }
  /^ *at: /             { if (err && $0 !~ /push_error/) print msg; err = 0; next }
                        { err = 0 }')
if [ "$control" != "ERROR: raised" ]; then
  echo "-- the engine-error filter does not discriminate: it reported [$control]"; fail=1
fi
if [ -n "$engine_err" ]; then
  echo "-- errors the ENGINE raised, which no grep above looks for:"
  echo "$engine_err" | head -5; fail=1
fi
grep -q "^OK -- " /tmp/test.log || { echo "-- no OK line: the runner did not finish"; fail=1; }
[ "$rc" -ne 0 ] && { echo "-- runner exited $rc"; fail=1; }

echo
[ "$fail" -eq 0 ] && echo "ALL GREEN" || echo "FAILED"
# THE EXIT CODE IS THE POINT AND THE WORD IS NOT. See the header: this line
# was missing and the script returned success while printing FAILED.
exit "$fail"
exit $fail
