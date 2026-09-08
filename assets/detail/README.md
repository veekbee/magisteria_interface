# `assets/detail/` — placeholder parameter rows for the detail function

**Nothing here is vendored and nothing here is measured.** The other `assets/` directories hold
artefacts the simulation produced, pinned and digest-checked. This one holds numbers this repo
invented so that the shape work could be built before the calibration data exists.

`detail_rows.json` carries per-landform amplitude, spectral slope, octave count and anisotropy for
the metre-scale detail function, plus the classifier thresholds and the HAND taper's constants.
**Every value in it is fake and the file says so at the top and in each block.** They are replaced
wholesale when calibration lands — measured per-landform variograms, roughness spectra and drainage
anisotropy from a real 1 m window — and not adjusted toward it.

**What is real here is the row schema**: which quantities a landform class carries, and how the
function consumes them. That is the deliverable; the values land into these slots.

There is no PIN because there is no upstream. A pin claims a file came from a producing commit, and
this one came from a decision to stop waiting.
