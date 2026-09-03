# `tools/blender/` — M5's form-archetype sources

`build_families.py` authors the four families and exports them; `family_*.blend` are the sources it
saves. Run through `bash tools/build_families.sh`, which supplies the Blender path.

Build machinery, not an addon: nothing here is loaded by the Godot project, and the no-addons rule
in `README.md` is unaffected.

## The sources are generated, and that is deliberate

`build_families.py` builds each mesh procedurally and saves the `.blend` beside its export. A hand-
authored `.blend` is an opaque binary in a repo whose every other artefact states what it claims;
this way the geometry is reviewable as a diff, a change to a canopy is a change to three lines, and
the archetypes can be rebuilt from nothing on a machine that has never opened Blender's UI.

The `.blend` files still commit. They are the thing the roadmap asks for, they are the input a
future hand-edit would start from, and at ~87 KB each they cost nothing.

## `.gdignore`, and why this directory needs one

Godot 4 imports `.blend` files natively by shelling out to Blender. Headless, with no Blender path
configured, that fails with *"Blender path is invalid or not set"* — which would turn `verify.sh`
red over files the project never loads. `.gdignore` keeps the engine out of the directory entirely.

`tools/build_families.sh` asserts the file is still there, because the failure it prevents appears
in the gate rather than here, and looks like a broken engine rather than a missing marker.

## Blender

**5.2.1 LTS**, and not on `PATH` on the machine this was built on. `build_families.sh` uses the full
macOS bundle path and takes `BLENDER=<path>` to override. A script that says `blender` works for
whoever installed it that way and fails everywhere else with a message about a missing command
rather than about what it was trying to do.

The exporter runs with `export_materials="NONE"`: the families carry geometry and a vertex-colour
mask, and the material is the client's. A material baked here would be a colour decision made in a
file that cannot see the field it is colouring.
