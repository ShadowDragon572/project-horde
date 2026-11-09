shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 20.0) = 1.0; // in viewport pixels

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (MODELVIEW_NORMAL_MATRIX * NORMAL);

	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * outline_width * 2.0 * clip.w;
	clip.xy += offset;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}