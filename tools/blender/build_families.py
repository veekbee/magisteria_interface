#!/usr/bin/env python3
"""
build_families.py -- author M5's form archetypes and export them. Run in Blender, headless.

    /Applications/Blender.app/Contents/MacOS/Blender --background --python \
        tools/blender/build_families.py

FOUR FAMILIES, NOT NINE, AND THE COUNT IS MEASURED RATHER THAN CHOSEN
----------------------------------------------------------------------
The wire carries `band.pft.biomass` and `band.pft_fractions` with a group axis
of four, and `fixture_client.json` names those groups. That list is the family
list and the whole of it. The five animal families of the roadmap's M5 have no
row on the wire at all -- no AFT row is carried at v2.0 (decision 901) -- so
there is nothing to place them with and no legal range that could be derived
rather than invented. `assets/families/families.json` records their absence and
why, so the next reader does not rediscover it.

THE FAMILY IS AUTHORED; THE INDIVIDUAL IS PARAMETERS (§17.8.2)
---------------------------------------------------------------
Nothing here is a species, a PFT member or a size. Each family is one mesh
normalised to UNIT HEIGHT and UNIT CROWN WIDTH standing on the origin plane, so
an instance transform scales the two axes INDEPENDENTLY -- they derive from
different field quantities and a single uniform scale would tie them together.
No mesh is per-PFT: palettes are off the wire (decision 894) and the fixture
aggregates to life form (decisions 872, 889), so a per-member mesh set has no
key it could legally be indexed by.

THE SECOND AXIS IS CROWN WIDTH, NOT TRUNK GIRTH, AND THAT IS FORCED BY THE
WIRE. §17.8.2 asks for height and girth as separate axes for woody forms; of
the two readings of "girth", only one is derivable here. `band.pft_fractions`
carries the share of ground a life form covers, and cover is crown area times
count -- so crown width is constrained by a carried row. Trunk diameter is
constrained by nothing on the wire at all: no carried row mentions stems, and
an authored trunk-to-height ratio would be a number invented to look precise.
The trunk is therefore drawn as a fixed proportion of the crown and is not a
parameter.

PHENOLOGY IS A MASK, NOT A MESH. Vertex colour R carries the weight of a vertex
in the seasonal tint -- 1.0 on foliage, 0.0 on permanent structure -- so one
family covers the year under a shader parameter instead of one mesh per season.
G carries height fraction along the form, which a shader needs to tint a canopy
without tinting a trunk.

TRIANGLES ARE THE BUDGET. `measurements/render_cost.json` measures MultiMesh
instancing on this project's renderer at about 10 ns per instance plus 0.16 ns
per triangle, so above a few hundred triangles the mesh IS the cost. These are
authored an order of magnitude below the benchmark's heavy rung deliberately.
"""
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND_DIR = os.path.join(ROOT, "tools", "blender")
OUT_DIR = os.path.join(ROOT, "assets", "families")

#: Vertex colour R for structure that does not change with the season.
STRUCTURE = 0.0


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def normalise(bm):
    """Unit height, unit crown width, standing on z = 0.

    Done to the geometry rather than left to the authoring numbers, so the
    convention an instance transform relies on is a property of the file
    instead of a promise about how carefully each builder was written.
    """
    zs = [v.co.z for v in bm.verts]
    z0 = min(zs)
    height = max(zs) - z0
    radius = max(math.hypot(v.co.x, v.co.y) for v in bm.verts) or 0.5
    for v in bm.verts:
        v.co.x *= 0.5 / radius
        v.co.y *= 0.5 / radius
        v.co.z = (v.co.z - z0) / (height or 1.0)
    return bm


def finish(bm, name, phenology_of):
    """Turn a bmesh into an object carrying the phenology and height masks.

    `phenology_of(vertex_co)` returns the seasonal weight for a vertex. It is a
    function of position rather than a constant per mesh, because a tree's
    trunk and its canopy are one mesh and only one of them changes colour in
    autumn.
    """
    mesh = bpy.data.meshes.new(name)
    normalise(bm).to_mesh(mesh)
    bm.free()
    mesh.validate()

    hi = max((v.co.z for v in mesh.vertices), default=1.0) or 1.0
    attr = mesh.color_attributes.new(name="mask", type="FLOAT_COLOR", domain="POINT")
    for i, v in enumerate(mesh.vertices):
        attr.data[i].color = (phenology_of(v.co), min(max(v.co.z / hi, 0.0), 1.0), 0.0, 1.0)
    mesh.color_attributes.active_color_index = 0
    mesh.color_attributes.render_color_index = 0

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def cylinder(bm, r0, r1, z0, z1, sides):
    """A tapered ring-to-ring band. Used for trunks and stems."""
    lower, upper = [], []
    for i in range(sides):
        a = 2.0 * math.pi * i / sides
        lower.append(bm.verts.new((r0 * math.cos(a), r0 * math.sin(a), z0)))
        upper.append(bm.verts.new((r1 * math.cos(a), r1 * math.sin(a), z1)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    return lower, upper


def cone(bm, radius, z0, z1, sides):
    """A closed cone: the cheapest thing that reads as a canopy from a distance."""
    tip = bm.verts.new((0.0, 0.0, z1))
    ring = []
    for i in range(sides):
        a = 2.0 * math.pi * i / sides
        ring.append(bm.verts.new((radius * math.cos(a), radius * math.sin(a), z0)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring[i], ring[j], tip))
    centre = bm.verts.new((0.0, 0.0, z0))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring[j], ring[i], centre))
    return ring


def blob(bm, centre, radius, subdiv=1):
    """A low icosphere. Foliage clumps, and nothing that needs to be round."""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=radius)
    bmesh.ops.translate(tmp, verts=tmp.verts, vec=Vector(centre))
    tmp.to_mesh(bpy.data.meshes.new("_tmp"))
    mapping = {}
    for v in tmp.verts:
        mapping[v] = bm.verts.new(v.co)
    for f in tmp.faces:
        try:
            bm.faces.new([mapping[v] for v in f.verts])
        except ValueError:
            pass          # a duplicate face where clumps overlap; harmless
    tmp.free()


# --------------------------------------------------------------------------
# the four families
# --------------------------------------------------------------------------

def build_tree():
    """Trunk plus a two-stage canopy. The crown sets the width axis and the
    trunk is a fixed proportion of it -- see the module note on why trunk
    diameter is not a parameter."""
    bm = bmesh.new()
    cylinder(bm, 0.055, 0.038, 0.0, 0.46, 6)
    cone(bm, 0.5, 0.34, 0.86, 8)
    cone(bm, 0.33, 0.6, 1.0, 8)
    return finish(bm, "family_tree", lambda co: 0.0 if co.z < 0.34 else 1.0)


def build_shrub():
    """Three overlapping clumps over a stub of stem. Woody, so it keeps both
    axes, but the crown is the whole of what a viewer resolves."""
    bm = bmesh.new()
    cylinder(bm, 0.06, 0.045, 0.0, 0.3, 5)
    blob(bm, (0.0, 0.0, 0.62), 0.34)
    blob(bm, (0.22, 0.08, 0.44), 0.26)
    blob(bm, (-0.19, -0.13, 0.5), 0.24)
    return finish(bm, "family_shrub", lambda co: 0.0 if co.z < 0.3 else 1.0)


def build_grass():
    """Six crossed blades, twelve triangles. A tussock is never the thing a
    viewer resolves and at horizon distance it is a few pixels -- but twelve is
    a floor rather than a taste: `measurements/render_cost.json` measured mesh
    complexities from twelve triangles up, and a family below that span could
    only be priced by extrapolating the cost model past its own evidence."""
    bm = bmesh.new()
    for k in range(6):
        a = math.pi * k / 6.0
        dx, dy = 0.5 * math.cos(a), 0.5 * math.sin(a)   # normalise() fixes the width
        v0 = bm.verts.new((-dx, -dy, 0.0))
        v1 = bm.verts.new((dx, dy, 0.0))
        v2 = bm.verts.new((dx * 0.35, dy * 0.35, 1.0))
        v3 = bm.verts.new((-dx * 0.35, -dy * 0.35, 1.0))
        bm.faces.new((v0, v1, v2, v3))
    return finish(bm, "family_grass", lambda co: 1.0)


def build_succulent():
    """A fluted column with a domed cap. Its seasonal weight is low rather than
    zero: a succulent's colour moves with water, not with leaf fall, and the
    mask is what a shader multiplies -- not a claim that nothing changes."""
    bm = bmesh.new()
    lower, upper = cylinder(bm, 0.5, 0.46, 0.0, 0.82, 8)
    ring = [bm.verts.new((0.3 * math.cos(2 * math.pi * i / 8),
                          0.3 * math.sin(2 * math.pi * i / 8), 0.94)) for i in range(8)]
    tip = bm.verts.new((0.0, 0.0, 1.0))
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((upper[i], upper[j], ring[j], ring[i]))
        bm.faces.new((ring[i], ring[j], tip))
    centre = bm.verts.new((0.0, 0.0, 0.0))
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((lower[j], lower[i], centre))
    return finish(bm, "family_succulent", lambda co: 0.15)


FAMILIES = {
    "tree": build_tree,
    "shrub": build_shrub,
    "grass": build_grass,
    "succulent": build_succulent,
}

#: Legal ranges, and where each end comes from.
#:
#: WIRE-VISIBLE INFORMATION ONLY. What the carried rows give is a life form,
#: a share of ground covered, and a biomass density -- not a species, not a
#: height, not a stem count. So the ranges below are the SPAN a life form can
#: physically occupy, wide enough to contain whatever the field implies, and
#: the individual's value inside that span is computed from the wire at the
#: instance. They are coarse on purpose: a narrow range would be a claim about
#: which plants live here, and that claim is in the palette, which is off the
#: wire (decision 894).
#:
#: If coarse ranges prove insufficient, that is a one-line design ask upstream
#: and not a file this repo writes.
RANGES = {
    "tree": {
        "height_m": (1.5, 40.0, "woody life form spanning sapling to closed-canopy conifer; "
                                "the upper end is generous for this basin rather than fitted "
                                "to it, because no carried row says which trees these are"),
        "crown_m": (0.8, 15.0, "cover fraction is crown area times count, so crown width is "
                               "the axis the wire constrains; the span covers a sapling to a "
                               "mature open-grown crown"),
    },
    "shrub": {
        "height_m": (0.15, 5.0, "prostrate dwarf-shrub to tall chaparral"),
        "crown_m": (0.2, 4.0, "crowns are wider than tall in this life form more often than "
                              "not, so the span is not a scaled copy of the height range"),
    },
    "grass": {
        "height_m": (0.03, 2.5, "cropped sward to tall bunchgrass in seed"),
        "crown_m": (0.05, 0.6, "a tussock, not a canopy: the width span is narrow because "
                               "the form does not build one"),
    },
    "succulent": {
        "height_m": (0.05, 12.0, "cushion cactus to columnar; the widest height span of the "
                                 "four, which is why one authored size would be wrong here "
                                 "rather than imprecise"),
        "crown_m": (0.05, 1.2, "columnar forms stay narrow as they grow tall, so width and "
                               "height are least correlated in this family"),
    },
}

#: The five families the roadmap asks for and the wire cannot key.
ABSENT = {
    "families": ["quadruped", "bird", "fish", "herptile", "invertebrate"],
    "why": ("no AFT row is carried. contract/schema.json at v2.0 has 8 rows, none with an "
            "`aft` dim, and the envelope declares only the `pft` taxonomy; decision 901 "
            "re-declared node.aft.population internal because its only writer is "
            "unimplemented. There is no density, no presence and no count to place an "
            "animal with, so a legal range for one could only be invented -- which is the "
            "single thing M5's parameter rule forbids."),
    "when": ("author them when an AFT row reaches the wire. The count of families here is "
             "read from the fixture's taxon_groups, so a new group appears as a missing "
             "family rather than as silence."),
}


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export(life_form, builder):
    clear_scene()
    obj = builder()
    obj.location = (0.0, 0.0, 0.0)

    blend = os.path.join(BLEND_DIR, "family_%s.blend" % life_form)
    bpy.ops.wm.save_as_mainfile(filepath=blend)

    glb = os.path.join(OUT_DIR, "family_%s.glb" % life_form)
    bpy.ops.export_scene.gltf(
        filepath=glb,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_texcoords=False,
        export_materials="NONE",
        export_cameras=False,
        export_lights=False,
    )
    return {
        "file": "family_%s.glb" % life_form,
        "blend_source": "tools/blender/family_%s.blend" % life_form,
        "triangles": triangles(obj),
        "vertices": len(obj.data.vertices),
    }


def manifest(built):
    families = {}
    for life_form, facts in sorted(built.items()):
        params = {}
        for name, (lo, hi, why) in sorted(RANGES[life_form].items()):
            params[name] = {"min": lo, "max": hi, "unit": "m", "from": why}
        params["phenology"] = {
            "min": 0.0, "max": 1.0, "unit": "fraction",
            "from": ("a shader parameter multiplied by vertex colour R, which is the "
                     "authored mask of what changes with the season. The mask is in the "
                     "mesh; the value is computed at the instance."),
        }
        families[life_form] = dict(facts, parameters=params)
    return {
        "artefact": "M5 form archetypes, keyed by life form",
        "ruled_by": ["\u00a717.8.2", "\u00a723.302", "decision 180", "decision 872",
                     "decision 889", "decision 894"],
        "generated_by": "tools/blender/build_families.py",
        "blender": bpy.app.version_string,
        "keyed_by": {
            "axis": "life_form",
            "read_from": ("fixture_client.json's windows.<window>.series.<row>.taxon_groups. "
                          "The client reads that list rather than assuming this file's order: "
                          "the wire's order is alphabetical and any other order here would "
                          "scatter each family over another family's ground while looking "
                          "entirely plausible."),
            "never": ("per PFT member and per AFT. Palettes are off the wire (894), the "
                      "fixture aggregates to life form (872, 889), and a size-baked form "
                      "token is wrong rather than imprecise (\u00a723.302, decision 180)."),
        },
        "convention": {
            "units": ("each mesh is normalised to 1 m tall and 1 m across, standing on the "
                      "origin plane, so an instance transform is scale(crown_m, height_m, "
                      "crown_m) and the two axes move independently"),
            "up": "+Y after glTF export",
            "vertex_colour_r": "phenology mask: 1 on foliage, 0 on permanent structure",
            "vertex_colour_g": "height fraction along the form, 0 at the base",
        },
        "families": families,
        "not_here": {"animal_families": ABSENT},
    }


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    built = {}
    for life_form, builder in FAMILIES.items():
        built[life_form] = export(life_form, builder)
        print("family %-10s %4d triangles, %3d vertices"
              % (life_form, built[life_form]["triangles"], built[life_form]["vertices"]))
    path = os.path.join(OUT_DIR, "families.json")
    with open(path, "w") as f:
        json.dump(manifest(built), f, indent=1, sort_keys=True)
        f.write("\n")
    print("wrote %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
