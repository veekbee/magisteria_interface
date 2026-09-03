# `assets/contours/` — pre-extracted contour geometry

Extracted **server-side** (§16.12.1, decision 296) by the simulation repo's
`tools/extract_contours.py`, brought here by `tools/vendor_contours.py`, and pinned like every
other vendored artefact. `python3 tools/check_contract.py` verifies the files against `PIN`.

## Why the extraction is not here

A contour of a band-quantised field is the level set of the **elevation at which the field crosses
a threshold**, and that elevation is computable only from the sixteen HUC4 band ladders — whose
base elevations differ, so band 4 is a different 300 m under each parent. That ladder is the
*generator* in §16.12's sense: anything holding it can evaluate the field anywhere in the region,
including where the avatar has never been, which is the leak §23.55 caught and §23.93 generalised.
So the ladder stays on the server and geometry crosses.

The disclosure that geometry *does* carry is the licensed one. An arc is a level set, so reading
the height under a drawn arc recovers that node's crossing elevation — but only for a node whose
arc you can see, which is exactly §16.12's coarse rung working as ruled. What never ships is a
crossing elevation for a node with no arc.

## What is here, and what is deliberately missing from it

`contours_<window>_<row>.json` is the manifest; `contours_<window>_<row>.bin` is int32 `x, y`
pairs in EPSG:5070 metres, a day at a time, in the order of that day's `arc_vertex_counts`.

**The line is broken, and that is the artefact being honest rather than incomplete.** A node whose
bands all sit above the threshold is entirely inside it; all below, entirely outside. Neither holds
a crossing, so neither says where the line runs — and between an all-snow node and an all-bare one
the only available curve is the HUC10 divide between them. Drawing that would be decision 890's
forbidden lattice geometry wearing a snowline's name, and it would look *better* than the real
thing because it is continuous. So a cell is contoured only when its four corners carry one node
index, and every day's record carries `share_drawn`: on the peak day of `deepest_winter`, 60.4% of
the boundary comes from the field and the remaining 39.6% is declined.

**The corridor is one band, 300 m** (§16.7). The crossing elevation is interpolated linearly
between the two adjacent band *midpoints*, so it lies between them by construction; `corridor_m`
carries the measured distance to the nearer one, which never exceeds 150 m.

## Reading it

Nothing about a node reaches this artefact — no id, no elevation, no ladder. Draping an arc on the
terrain needs only the terrain export's transform, which the arcs were extracted on and
`tools/vendor_contours.py` refuses to vendor against a different one.
