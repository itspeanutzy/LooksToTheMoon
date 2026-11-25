shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius : hint_range(0.0, 40.0) = 12.0; // blur size in pixels

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 o = vec2(float(x), float(y)) / 3.0; // -1..1
			float w = exp(-dot(o, o) * 2.0);          // gaussian-ish weight
			sum += texture(screen_tex, SCREEN_UV + o * px) * w;
			total += w;
		}
	}
	COLOR = sum / total;
}