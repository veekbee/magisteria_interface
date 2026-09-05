shader_type spatial;
render_mode unshaded, cull_disabled;

// WHICH PIXELS ARE AT WHICH RANGE, as a one-bit mask rather than as a depth
// image.
//
// The obvious instrument is a render that writes linearized camera distance
// into RGB and is read back as a number. It does not survive this pipeline: an
// unshaded ALBEDO still goes out through tonemapping and sRGB encoding, so the
// bytes that come back are not the bytes that were written. A mask is immune to
// all of that -- white stays the brightest thing the buffer can hold -- so
// membership of a range band survives exactly. The cost is one render per band,
// which is eight frames against a scatter that takes seconds to build.
//
// THE DISTANCE IS COMPUTED FROM WORLD POSITIONS, NOT FROM `VERTEX`. Reading
// `length(VERTEX)` in `fragment()` as a camera distance produced an all-black
// mask at every band on this renderer -- every pixel outside every band, which
// looks exactly like a camera pointing at nothing. `MODEL_MATRIX` and
// `CAMERA_POSITION_WORLD` are unambiguous in both renderers and cost a varying.
//
// AND IT IS HORIZONTAL. The basin is drawn at 12x vertical relief and the
// camera sits above the ground, so a 3D distance would put a band's far edge
// tens of metres up a hillside that is really a few metres up. The ranges these
// bands are about are ground ranges, so Y is dropped -- which is also the only
// reading under which "a 200 m seam" means the same thing at 1x and at 12x.

uniform float lo_m = 0.0;
uniform float hi_m = 100.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 here = vec2(world_pos.x, world_pos.z);
	vec2 eye = vec2(CAMERA_POSITION_WORLD.x, CAMERA_POSITION_WORLD.z);
	float d = distance(here, eye);
	float inside = step(lo_m, d) * step(d, hi_m);
	ALBEDO = vec3(inside);
	ALPHA = 1.0;
}
