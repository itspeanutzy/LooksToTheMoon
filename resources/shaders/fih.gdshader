shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 0.2) = 0.03;
uniform float frequency = 10.0;
uniform float speed = 3.0;

// Top portion of the sprite that stays perfectly flat (the "--")
uniform float flat_length : hint_range(0.0, 1.0) = 0.2;
// How far down the wave takes to grow from flat to full amplitude
uniform float ramp_length : hint_range(0.01, 1.0) = 0.5;

void fragment() {
	// 0 in the flat zone, then grows to 1 going down
	float env = smoothstep(flat_length, flat_length + ramp_length, UV.y);

	vec2 uv = UV;
	uv.x += sin(UV.y * frequency - TIME * speed) * amplitude * env;
	COLOR = texture(TEXTURE, uv);
}