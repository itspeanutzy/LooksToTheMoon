shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 30.0) = 0.0;

void fragment() {
    vec2 uv = UV;
    float alpha = 1.0;

    // Blur the horizontal edge of the lid.
    float edge = blur_amount * TEXTURE_PIXEL_SIZE.y;

    alpha *= smoothstep(0.0, edge, uv.y);
    alpha *= 1.0 - smoothstep(1.0 - edge, 1.0, uv.y);

    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}