shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D eclipse_texture : source_color;
uniform float emission_energy : hint_range(0.0, 4.0) = 1.25;

void fragment() {
	vec3 image = texture(eclipse_texture, UV).rgb;
	float radius = length(UV - vec2(0.5));
	// The source is a JPEG: its outer black must disappear, while the central
	// black disk stays opaque so towers cannot show through the eclipse.
	float disk = 1.0 - smoothstep(0.202, 0.214, radius);
	float brightness = max(image.r, max(image.g, image.b));
	float corona = smoothstep(0.018, 0.14, brightness);
	float opacity = max(disk, corona);
	if (opacity < 0.003) {
		discard;
	}
	ALBEDO = image * (1.0 - disk);
	EMISSION = image * emission_energy * (1.0 - disk);
	ALPHA = opacity;
}
