// Additive glowing material for beams, flashes, explosions and particles.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 3.0;
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = color.rgb * COLOR.rgb * energy;
	ALPHA = clamp(alpha * COLOR.a, 0.0, 1.0);
}
