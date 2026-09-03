shader_type spatial;
render_mode cull_disabled;

// M5's phenology tint. §17.8.2 asks for phenology as a vertex-colour mask plus
// a shader parameter, and this is the shader half.
//
// TWO NUMBERS MEET HERE AND THEY MUST NOT BE MULTIPLIED TOGETHER BEFORE THEY
// ARRIVE. The mesh's vertex colour R is the AUTHORED mask: which parts of this
// form change with the season, 1.0 on foliage and 0.0 on a trunk.
// INSTANCE_CUSTOM.r is the COMPUTED value: where this individual sits between
// its own cell's yearly trough and peak.
//
// They come down separate channels deliberately. Carried as a MultiMesh
// INSTANCE COLOUR, the per-instance value would be multiplied into COLOR by the
// engine, and the product is zero both for a trunk in summer and for foliage in
// deep winter -- two states that must not look alike. Custom data does not
// multiply, so the mask stays the mask.
//
// CULLING IS OFF because grass is single-sided quads: a blade seen from behind
// is still a blade, and back-face culling would delete half of every tussock.

uniform vec3 senescent : source_color = vec3(0.46, 0.36, 0.17);
uniform vec3 growing : source_color = vec3(0.20, 0.42, 0.16);
uniform vec3 structure : source_color = vec3(0.29, 0.24, 0.19);

varying float phenology;
varying float mask;

void vertex() {
	mask = COLOR.r;                  // authored: is this fragment foliage?
	phenology = INSTANCE_CUSTOM.r;   // computed: how far through its year is it?
}

void fragment() {
	// Structure does not move with the season at all; foliage does, and the
	// authored mask is the only thing that decides which a fragment is.
	vec3 foliage = mix(senescent, growing, clamp(phenology, 0.0, 1.0));
	ALBEDO = mix(structure, foliage, clamp(mask, 0.0, 1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
