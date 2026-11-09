// Stencil outline for flat-shaded (low poly) meshes.
// The built-in outline pushes vertices along their normals, which tears flat-shaded faces apart.
// This one pushes along the smoothed direction OutlineNormals bakes into the vertex color, so
// corners that sit in the same spot always move the same way and the shell stays closed.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
// Only draw where the main material didn't write 1, so the outline never covers the model.
stencil_mode read, compare_not_equal, 1;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float thickness = 0.04;
// The point to grow from, in the mesh's own space. Leave at 0 if the mesh's origin is its center.
uniform vec3 center = vec3(0.0);

void vertex() {
	if (COLOR.a < 0.5) {
		// OutlineNormals baked a smooth direction into the vertex color (alpha 0 marks it).
		VERTEX += normalize(COLOR.rgb * 2.0 - 1.0) * thickness;
	} else {
		// Not baked (like in the editor preview): fall back to growing from the center.
		vec3 from_center = VERTEX - center;
		if (length(from_center) > 0.0001) {
			VERTEX += normalize(from_center) * thickness;
		}
	}
}

void fragment() {
	ALBEDO = outline_color.rgb;
	// Writing ALPHA makes this a transparent material. Transparent materials draw after every
	// opaque one, so the model has already marked the stencil by the time the outline checks it.
	ALPHA = outline_color.a;
}
