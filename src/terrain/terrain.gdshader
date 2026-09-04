shader_type spatial;

// The terrain's surface, in two views of one basin.
//
// IT WAS A StandardMaterial3D AND THE DATA VIEW MUST NOT MOVE. Everything the
// visual audit ruled about that material is reproduced here exactly and for
// the same reasons: ROUGHNESS 1 and SPECULAR 0, because a specular term adds
// white in proportion to nothing in the data and washed 56% of the overlay's
// pixels off the viridis ramp; the field texture straight into ALBEDO with no
// colour multiplied over it; and transparency left off, because nodata is
// PAINTED with the terrain's own bare albedo rather than written transparent.
// The swap was photographed before and after and the data view is unchanged.
//
// DATA VIEW IS THE RAMP. NATURALISTIC VIEW IS THE STAND. They are different
// questions -- one asks what a carried row's value is here, the other asks
// what this place looks like -- and neither is a decoration of the other, so
// the shader carries both and mixes neither.
//
// COVERAGE IS A MASK, NOT AN ALPHA. The far field is not a wash of green over
// the ground; it is some pixels plant and some pixels ground, which is what
// the near field measurably is (32-58% coverage with ground showing through,
// `measurements/scatter_bands.json`). Blending vegetation colour over the
// hillshade at 40% opacity produces a colour that is neither, and shifts with
// the hillshade underneath it. A hashed threshold reproduces the fraction
// instead: below `coverage` a pixel is plant, above it the ground shows.
//
// THE HASH IS IN WORLD-ISH SPACE, not screen space. Screen-space dither
// crawls when the camera moves -- the pattern stays put while the ground slides
// under it, which reads as static rather than as vegetation. Hashing UV, which
// is the heightfield's own texel grid, pins the pattern to the ground.

uniform sampler2D field : source_color, hint_default_white;
uniform sampler2D vegetation : source_color, hint_default_white;
uniform vec4 bare : source_color = vec4(0.62, 0.60, 0.55, 1.0);
uniform bool has_field = false;
uniform bool naturalistic = false;
/// How fine the coverage mask is, in cycles across the heightfield. High
/// enough that a mask cell is well under a screen pixel at range -- where it
/// averages to the coverage fraction, which is the point -- and low enough
/// that it does not alias into moire at close range.
uniform float mask_frequency = 900.0;

// RANGE DARKENING. Apparent stand colour falls with range -- measured, not
// assumed: the vegetation in a 100 m cut means (0.171, 0.340, 0.128) and in a
// 300 m one (0.096, 0.230, 0.070), because more of what is drawn at range is
// small, far and in shadow. A tint painting the near colour everywhere is
// visibly brighter than the stand it stands in for.
//
// It belongs at the fragment and not in the texture: the texture is per cell
// and view-independent, and range is a property of where the camera is. `k0`
// is the multiplier the curve settles to and `r0` its e-folding distance; both
// are fitted from `measure_seam`'s binned oracle rather than chosen.
//
// Only the VEGETATION is attenuated. The ground's own colour at range is the
// hillshade's business and is already right.
uniform bool range_matched = false;
uniform float range_k0 = 0.5;
uniform float range_r0 = 200.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 ground = has_field ? texture(field, UV).rgb : bare.rgb;
	if (naturalistic) {
		vec4 veg = texture(vegetation, UV);
		// A carries coverage: the share of this ground the stand covers.
		float coverage = clamp(veg.a, 0.0, 1.0);
		float pick = hash12(floor(UV * mask_frequency));
		float k = 1.0;
		if (range_matched) {
			k = range_k0 + (1.0 - range_k0) * exp(-length(VERTEX) / range_r0);
		}
		ground = pick < coverage ? veg.rgb * k : bare.rgb;
	}
	ALBEDO = ground;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
