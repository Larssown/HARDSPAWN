shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Texture-free, low-cost flowing lava. The HDR emission is picked up by
// WorldEnvironment glow; no texture import or noise resource is required.
uniform vec4 crust_color : source_color = vec4(0.10, 0.008, 0.003, 1.0);
uniform vec4 hot_color : source_color = vec4(0.95, 0.13, 0.008, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.52, 0.04, 1.0);
uniform float flow_speed : hint_range(0.01, 1.0) = 0.18;
uniform float emission_strength : hint_range(0.0, 12.0) = 4.0;
// Unshaded output is multiplied by this so the lava glows (HDR) through bright haze.
uniform float hdr_boost : hint_range(0.5, 8.0) = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 p = UV * 6.0;
	float t = TIME * flow_speed;
	vec2 warp = vec2(
		noise2(p * 0.58 + vec2(t, -t * 0.55)),
		noise2(p * 0.58 + vec2(8.1 - t * 0.42, t * 0.72))
	);
	vec2 flow = p + (warp - 0.5) * 1.6 + vec2(t * 0.32, t * 0.85);
	float field = noise2(flow) * 0.82 + noise2(flow * 2.7) * 0.18;
	float heat = 1.0 - smoothstep(0.20, 0.60, field);
	vec3 lava = mix(crust_color.rgb, hot_color.rgb, smoothstep(0.08, 0.82, heat));
	lava = mix(lava, core_color.rgb, smoothstep(0.82, 0.99, heat) * 0.58);

	// Small expanding rings make the surface read as bubbling, not static noise.
	vec2 bubble_uv = UV * 8.0;
	vec2 cell = floor(bubble_uv);
	vec2 center = vec2(hash21(cell + 11.3), hash21(cell + 37.7));
	float phase = fract(TIME * 0.38 + hash21(cell + 71.9));
	float distance_to_bubble = length(fract(bubble_uv) - center);
	float ring = (1.0 - smoothstep(0.025, 0.075,
		abs(distance_to_bubble - phase * 0.32))) * (1.0 - phase) * heat;
	lava = mix(lava, hot_color.rgb, ring * 0.55);

	ALBEDO = lava * hdr_boost;
	EMISSION = lava * emission_strength * (0.16 + heat * 0.92 + ring * 0.65);
}
