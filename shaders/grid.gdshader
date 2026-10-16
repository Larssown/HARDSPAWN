// World-space sci-fi panel grid. Needs no UVs, so it works on any box.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.07, 0.075, 0.09);
uniform vec3 line_color : source_color = vec3(0.1, 0.6, 1.0);
uniform float grid_size = 2.0;
uniform float line_width = 0.025;
uniform float line_emission = 1.6;
uniform float metal = 0.15;
uniform float rough = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > 0.5 ? world_pos.xz : (n.x > 0.5 ? world_pos.zy : world_pos.xy);
	vec2 g = abs(fract(uv / grid_size - 0.5) - 0.5) * grid_size;
	float d = min(g.x, g.y);
	float fw = max(fwidth(d), 0.0001);
	float line = 1.0 - smoothstep(line_width - fw, line_width + fw, d);
	line *= clamp(line_width / (fw * 1.5), 0.0, 1.0);

	vec2 cell = floor(uv / grid_size);
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = base_color * (0.8 + 0.4 * h);
	METALLIC = metal;
	ROUGHNESS = rough + h * 0.15;
	EMISSION = line_color * line * line_emission;
}
