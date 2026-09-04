shader_type spatial;
render_mode unshaded, cull_disabled;

// WHICH PIXELS ARE AT WHICH RANGE, as a one-bit mask rather than as a depth
// image.
//
// The obvious instrument is a render that writes linearized camera distance
// into RGB and is read back as a number. It does not survive this pipeline:
// an unshaded ALBEDO still goes out through tonemapping and sRGB encoding, so
// the bytes that come back are not the bytes that were written, and a range
// decoded from them is wrong by an amount nothing in the frame declares. A
// mask is immune to every one of those transforms -- white stays the brightest
// thing the buffer can hold and black stays the darkest -- so membership of a
// range band survives exactly.
//
// The cost is one render per band instead of one for all of them. That is
// eight frames of settle per band against a scatter that takes seconds to
// build, so it is not the expensive part of anything here.
//
// `length(VERTEX)` in `fragment()` is distance from the camera in metres of
// MESH space. Horizontal distance is unexaggerated in this project and height
// is 12x, so a band is a cylinder-ish shell rather than a sphere -- which is
// what the question is about, because the ranges being scored are horizontal.

uniform float lo_m = 0.0;
uniform float hi_m = 100.0;

void fragment() {
	float d = length(VERTEX);
	float inside = step(lo_m, d) * step(d, hi_m);
	ALBEDO = vec3(inside);
	ALPHA = 1.0;
}
