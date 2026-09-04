#!/usr/bin/env bash
# The visual audit: one named shot per milestone claim, in a fixed state.
#
# WHY A NAMED SET AND NOT AN AD-HOC RUN. The terrain was wound inside-out from
# M1 and never rendered, so M1's hillshade, M2's overlay, M3's flow colours and
# M4's contours were asserted against data for four milestones and never
# against a picture. They all "appeared correct" -- which is the claim the
# inside-out terrain also satisfied. A set with names is what lets the next
# person re-take the same picture and compare, rather than take a different one
# and conclude.
#
# WHY IT IS NOT IN verify.sh. The gate runs headless in CI, and this refuses
# headless for the reason the benchmark does: --headless draws nothing and
# reports success. A check that cannot run where the gate runs is a checklist
# wearing a gate's name. What IS gated is every finding this audit produced:
# each one is pinned by an assert in tests/run_headless.gd that can be made
# blind, and the messages there carry the measurement that found it.
#
#   bash tools/audit.sh              # the whole set, into shots/audit/
#
# The record of what these pictures established is measurements/visual_audit.md.
# The pictures themselves are not committed: they are large, they go stale
# silently, and a stale PNG is more authoritative-looking than a stale sentence.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${OUT:-shots/audit}"
W="${WINDOW:-deepest_winter}"
mkdir -p "$OUT"
LOG="$OUT/audit.log"
: > "$LOG"

shot() {
  local what="$1"; shift
  echo "" | tee -a "$LOG"
  echo "== $what" | tee -a "$LOG"
  echo "   tools/screenshot.sh $*" | tee -a "$LOG"
  bash tools/screenshot.sh "$@" --out "$OUT" 2>&1 \
    | grep -E "^(shot|relief|ramp|compare|against|state|verdict|contours|families|fields|terrain) " \
    | tee -a "$LOG"
}

# M1 -- relief. No field, so the only thing that varies is the light; two sun
# azimuths, because a lit surface changes when the light moves and a baked
# shade map does not.
shot "M1 hillshade -- is the surface lit, and from where" \
  --only terrain --no-field --camera ortho --backdrop black --days 0 --sun 225,45

# M2 -- the overlay. Two days of one row, and the ramp measured against the
# stops the code declares rather than against an impression of them.
shot "M2 field overlay -- the ramp, and whether the day moves it" \
  --only terrain --window "$W" --row band.wetness --days 0,45 --camera ortho --backdrop black

# M3 -- flow colour on the reaches, isolated from the ground under them.
shot "M3 streamflow on the flowlines" \
  --only flowlines --window "$W" --row node.streamflow --days 0,45 --camera ortho --backdrop black

# M4 -- the vendored contours, draped, one day at a time.
shot "M4 contours -- drawn, draped, and moving with the day" \
  --only contours --window "$W" --row band.snowpack_swe --days 0,45 --camera ortho --backdrop black

# M5 -- the scatter, at the place a probe resolved, on two days of one year.
# The ground is hidden: flown to the scatter the terrain fills the frame with
# one cell's colour, and a census over that is 99% a statement about the
# overlay. The plants are the subject, so the plants are what is left in.
shot "M5 vegetation scatter -- placement and seasonal tint" \
  --only vegetation --window "$W" --row band.pft.biomass --days 22,89 --scatter

# Everything at once, which is the only shot that can show one layer eating
# another: sorting, z-fighting, a legend over the basin.
shot "composite -- every layer together, as the application runs it" \
  --window "$W" --row band.wetness --days 45 --camera ortho

echo "" | tee -a "$LOG"
echo "record: measurements/visual_audit.md   shots: $OUT (not committed)" | tee -a "$LOG"
