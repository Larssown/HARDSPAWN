// Cuts the black background out of the HUD weapon art (glowing lines on black)
// and puts a soft dark halo behind the lines, so they read on white and dark scenes.
shader_type canvas_item;

uniform bool monochrome = false;      // true = draw the lines in `tint` (inactive slots)
uniform vec3 tint : source_color = vec3(1.0);
uniform float gain = 1.7;             // how quickly dim pixels become opaque
uniform float halo_px = 10.0;         // halo radius in source-texture pixels
uniform float halo_alpha = 0.55;

float key(vec4 c) {
	return clamp(max(c.r, max(c.g, c.b)) * gain, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = key(c) * c.a;
	float peak = max(max(c.r, max(c.g, c.b)), 0.001);
	vec3 line = monochrome ? tint : mix(c.rgb / peak, vec3(1.0), smoothstep(0.85, 1.0, peak) * 0.6);

	float h = 0.0;
	vec2 step_px = TEXTURE_PIXEL_SIZE * halo_px;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		vec2 dir = vec2(cos(ang), sin(ang));
		h = max(h, key(texture(TEXTURE, UV + dir * step_px)));
		h = max(h, key(texture(TEXTURE, UV + dir * step_px * 0.5)));
	}
	float halo = h * halo_alpha;
	float out_a = a + halo * (1.0 - a);
	vec3 out_rgb = (line * a + vec3(0.0) * halo * (1.0 - a)) / max(out_a, 0.001);
	COLOR = vec4(out_rgb, out_a * COLOR.a);
}
