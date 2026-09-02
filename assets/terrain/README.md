# `assets/terrain/` — reserved, empty

The terrain export (simulation-repo **Phase 3**) lands here: a downsampled whole-basin heightfield
overview, full-resolution tiles on a declared grid, and flowlines with reach ids.

**Producer:** `tools/build_terrain_layers.py` in the simulation repo, extended per decision 890.
Not yet built.

**Two things this directory is here to make visible before any bytes arrive:**

**The import boundary.** Terrain is one of exactly three artefacts this repo may take from the
simulation repo, and it arrives as a *file*, pinned — never as a Python import and never by reading
`sim/` or `/runs/`.

**No lattice is ever geometry** (decision 890). Cell and patch polygons must never appear here,
including "for debugging": the residence raster is a *key* layer, and the moment cell outlines exist
as geometry someone will draw them.

**Undecided, and it must be decided before the first large artefact lands:** git-LFS versus
fetch-by-manifest. Full-resolution tiles and the fixture together will run to hundreds of megabytes.
The likely shape is committing the small overview plus manifests and fetching the rest. That is this
repo's build-machinery call, not a corpus question — but making it *after* the bytes arrive means
making it inside a rewrite.
