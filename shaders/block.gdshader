// HARDSPAWN concept look: matte grey blocks with thin, softly glowing edge lines,
// faint panel seams, and (optionally) a black floor grid on upward faces.
// Works on BoxMesh / CSGBox3D: set the per-instance `box_size` to the box size.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.33, 0.335, 0.345);
uniform float base_variation = 0.08;
uniform vec3 edge_color : source_color = vec3(0.93, 0.95, 0.97);
uniform float edge_width = 0.022;
uniform float edge_emission = 1.6;
uniform float seam_size = 2.0;
uniform float seam_strength = 0.04;
uniform float bottom_shade = 0.3;
uniform bool grid_top = false;
uniform vec3 top_color : source_color = vec3(0.03, 0.032, 0.036);
uniform vec3 grid_color : source_color = vec3(0.22, 0.23, 0.25);
uniform float grid_size = 1.0;
uniform float grid_emission = 0.12;
uniform float roughness_value = 0.82;

instance uniform vec3 box_size = vec3(1.0);
// 1.0 = that side is joined to a neighbouring block, so no outline is drawn there.
instance uniform vec3 join_pos = vec3(0.0);
instance uniform vec3 join_neg = vec3(0.0);

varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float line_mask_fw(float d, float w, float fw) {
	fw = max(fw, 0.0001);
	// Never thinner than ~1 pixel, so outlines stay readable far away.
	float width = max(w, fw * 1.0);
	// Lines thinner than a pixel fade out instead of shimmering.
	float strength = clamp(w / (fw * 0.7), 0.35, 1.0);
	return (1.0 - smoothstep(width - fw, width + fw, d)) * strength;
}

float line_mask(float d, float w) {
	return line_mask_fw(d, w, fwidth(d));
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 half_size = box_size * 0.5;
	vec3 d = half_size - abs(local_pos);
	vec3 d_real = d;
	vec3 joined = mix(join_neg, join_pos, step(vec3(0.0), local_pos));
	d = mix(d, vec3(1000.0), joined);
	// A face that is itself buried against a neighbour can peek through the seam
	// for a pixel; render it plain dark so it never shows up as a white dash.
	vec3 face_side = mix(join_neg, join_pos, step(vec3(0.0), local_normal));
	bool buried = dot(face_side, abs(local_normal)) > 0.5;
	vec3 an = abs(local_normal);
	float edge_dist;
	float edge_real;
	vec2 face_uv;
	if (an.x > 0.5) {
		edge_dist = min(d.y, d.z);
		edge_real = min(d_real.y, d_real.z);
	} else if (an.y > 0.5) {
		edge_dist = min(d.x, d.z);
		edge_real = min(d_real.x, d_real.z);
	} else {
		edge_dist = min(d.x, d.y);
		edge_real = min(d_real.x, d_real.y);
	}
	// Screen-space width comes from the real distance: the joined substitute jumps
	// at the box midline and would otherwise draw a broken line across the block.
	float edge = line_mask_fw(edge_dist, edge_width, fwidth(edge_real));

	vec3 wn = abs(world_normal);
	face_uv = wn.y > 0.5 ? world_pos.xz : (wn.x > 0.5 ? world_pos.zy : world_pos.xy);
	vec3 albedo = base_color;
	float emit_grid = 0.0;

	if (grid_top && world_normal.y > 0.5) {
		albedo = top_color;
		vec2 g = abs(fract(face_uv / grid_size - 0.5) - 0.5) * grid_size;
		float minor = line_mask(min(g.x, g.y), 0.012);
		vec2 g4 = abs(fract(face_uv / (grid_size * 4.0) - 0.5) - 0.5) * grid_size * 4.0;
		float major = line_mask(min(g4.x, g4.y), 0.022);
		float grid = max(minor * 0.4, major * 0.85);
		albedo = mix(albedo, grid_color, grid);
		emit_grid = grid * grid_emission;
	} else {
		vec2 cell = floor(face_uv / seam_size);
		float h = hash21(cell);
		albedo *= 1.0 - base_variation + base_variation * 2.0 * h;
		if (seam_size > 0.0) {
			vec2 s = abs(fract(face_uv / seam_size - 0.5) - 0.5) * seam_size;
			float seam = line_mask(min(s.x, s.y), 0.01);
			albedo = mix(albedo, albedo * 1.6 + 0.05, seam * seam_strength * 6.0);
		}
		// Vertical faces get slightly darker towards their base (cheap fake AO).
		if (an.y < 0.5) {
			float t = clamp((local_pos.y + half_size.y) / max(box_size.y, 0.01), 0.0, 1.0);
			albedo *= mix(1.0 - bottom_shade, 1.0, smoothstep(0.0, 0.6, t));
		}
	}

	ALBEDO = mix(albedo, edge_color, edge * 0.85);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	EMISSION = edge_color * edge * edge_emission + grid_color * emit_grid;
	if (buried) {
		ALBEDO = top_color;
		ROUGHNESS = 1.0;
		EMISSION = vec3(0.0);
	}
}
