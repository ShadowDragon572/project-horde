shader_type canvas_item;

uniform int num_colors : hint_range(2, 26) = 8;
uniform sampler2D PALETTE_TEXTURE : hint_default_black, filter_nearest;

uniform bool dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;

const float BAYER[16] = float[](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

// Returns a 0..1 threshold from the 4x4 Bayer pattern for this low-res pixel.
float bayer_threshold(vec2 uv, vec2 tex_size) {
	ivec2 p = ivec2(uv * tex_size);
	return (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
}

// Finds the closest and second-closest palette colors to albedo.
void find_two_closest(vec3 albedo, out vec3 c1, out vec3 c2, out float d1, out float d2) {
	c1 = vec3(0.0);
	c2 = vec3(0.0);
	d1 = 10.0;
	d2 = 10.0;
	float n = float(num_colors);

	for (int i = 0; i < num_colors; i++) {
		float index = 1.0 / (2.0 * n) + float(i) / n;
		vec3 col = texture(PALETTE_TEXTURE, vec2(index, 0.5)).rgb;
		float d = length(col - albedo);

		if (d < d1) {
			d2 = d1;
			c2 = c1;
			d1 = d;
			c1 = col;
		} else if (d < d2) {
			d2 = d;
			c2 = col;
		}
	}
}

void fragment() {
	vec3 albedo = texture(TEXTURE, UV).rgb;

	vec3 c1;
	vec3 c2;
	float d1;
	float d2;
	find_two_closest(albedo, c1, c2, d1, d2);

	vec3 result = c1;

	if (dithering && d1 > 0.001) {
		// 0.0 = exactly on c1, 0.5 = halfway between c1 and c2
		float ratio = d1 / (d1 + d2);
		float threshold = bayer_threshold(UV, vec2(textureSize(TEXTURE, 0)));
		if (threshold < ratio * dither_strength) {
			result = c2;
		}
	}

	COLOR.rgb = result;
}