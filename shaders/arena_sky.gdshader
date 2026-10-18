shader_type sky;

// Broad, soft backlight with no sun disk or other circular object.
uniform vec3 void_color : source_color = vec3(0.008, 0.006, 0.005);
uniform vec3 warm_haze : source_color = vec3(0.24, 0.13, 0.07);
uniform vec3 pale_light : source_color = vec3(2.3, 1.95, 1.55);

void sky() {
	vec3 view_dir = normalize(EYEDIR);
	vec3 light_dir = normalize(vec3(0.42, 0.58, -0.70));
	float facing = max(dot(view_dir, light_dir), 0.0);
	float broad = pow(facing, 2.5);
	float glow = pow(facing, 8.0);
	float elevation = smoothstep(-0.18, 0.62, view_dir.y);
	COLOR = void_color + warm_haze * broad * elevation + pale_light * glow * elevation;
}
