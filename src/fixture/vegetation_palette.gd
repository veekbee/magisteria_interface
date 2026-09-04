class_name VegetationPalette
extends RefCounted

## The three colours a plant is made of, in one place.
##
## THEY WERE THE SHADER'S UNIFORM DEFAULTS AND THAT IS NOT A SOURCE OF TRUTH.
## The far-field tint has to produce the colour the near-field instances
## produce, or the seam between them is a colour step by construction rather
## than by any failure of either. Two copies of a palette agree until one is
## edited, and the whole point of the seam work is that the two ends are the
## same stand.
##
## So the constants live here, `TerrainView` writes them into the instance
## shader's uniforms rather than letting the shader's own defaults stand, and
## the tint reads them directly. A test holds the shader's defaults to these
## values, so an edit in either place fails rather than drifts.
##
## The palette is the CLIENT'S (decision 894 keeps it off the wire), and
## `assets/families/README.md` says so: the families carry geometry and a
## vertex-colour mask, and the colour decision is made here.

const SENESCENT := Color(0.46, 0.36, 0.17)
const GROWING := Color(0.20, 0.42, 0.16)
const STRUCTURE := Color(0.29, 0.24, 0.19)


## One plant's mean colour, as `vegetation.gdshader` would render it averaged
## over its own silhouette.
##
## The shader mixes per fragment: structure where the authored mask is 0,
## seasonal foliage where it is 1. `foliage` here is that mask averaged over
## the mesh by area (`FamilySet.foliage_fraction`), so this is the same mix one
## step up -- which is exactly the step the far field is taking.
static func colour_for(foliage: float, phenology: float) -> Color:
    var f: Color = SENESCENT.lerp(GROWING, clampf(phenology, 0.0, 1.0))
    return STRUCTURE.lerp(f, clampf(foliage, 0.0, 1.0))
