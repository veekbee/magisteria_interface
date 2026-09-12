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
python3 tools/check_contract.py || fail=1

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
# THE BYTES MUST NOT BE COMMITTABLE BY ACCIDENT. 141 MB of tile pyramid and
# 437 MB of derived layers sit under assets/terrain/ once fetched, against a
# ~10 MB threshold. The .gitignore keeps them out; this is the check that the
# .gitignore still does, because a rule nobody verifies is a rule that survives
# exactly until someone adds a negation to it -- and the layers arrived by
# adding three negations to it.
tracked=$(git ls-files assets/terrain/tiles assets/terrain/layers \
  | grep -vE '^assets/terrain/(tiles|layers)/(PIN|README\.md|\.gdignore)$' || true)
if [ -n "$tracked" ]; then
  echo "fetched tile bytes are tracked by git:"; echo "$tracked" | head -5; fail=1
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
