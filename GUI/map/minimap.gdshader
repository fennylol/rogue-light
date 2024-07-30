shader_type canvas_item;

uniform vec2 scale = vec2(1.0, 1.0);
uniform vec2 offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = (UV - 0.5) / scale + 0.5 + offset / (TEXTURE_PIXEL_SIZE * scale);
	COLOR = texture(TEXTURE, uv);
}