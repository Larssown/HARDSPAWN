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
// Procedural cracked concrete (0 = off). Scale is cells per metre.
uniform float crack_amount = 0.0;
uniform float crack_scale = 1.2;
uniform vec3 crack_color : source_color = vec3(0.33, 0.32, 0.31);
uniform float crack_bump = 0.45;
uniform float hairline_amount = 0.6;
uniform float stain_amount = 0.12;
// Glow that increases towards the bottom (used for the lava pit walls).
uniform vec3 heat_color : source_color = vec3(0.0);
uniform float heat_strength = 0.0;
uniform float heat_top = 0.0;
uniform float heat_bottom = -4.0;

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

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

// Distance to the nearest Voronoi cell border (Inigo Quilez). Cell borders = cracks.
float crack_distance(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return md;
}

// Anti-aliased crack line from a border distance; fades out instead of shimmering far away.
float crack_line(float d, float w, float fw) {
	fw = max(fw, 0.0001);
	float fade = clamp(w / (fw * 0.8), 0.0, 1.0);
	return (1.0 - smoothstep(w - fw, w + fw, d)) * fade;
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

	// Cracked concrete: a network of big cracks, finer hairlines in some areas,
	// soft stains, and a little depth so the cracks catch the light.
	float height = 0.0;
	float cracks_out = 0.0;
	if (crack_amount > 0.0 && !buried) {
		vec2 cuv = face_uv + vec2(world_pos.y * 0.37, world_pos.y * 0.21) * (1.0 - wn.y);
		// Pixel footprint of one metre. Detail smaller than a few pixels is skipped
		// entirely: distant surfaces stay clean and cost far less to draw.
		float fw_m = max(length(fwidth(cuv)) * 0.7, 0.00001);
		float px_per_m = 1.0 / fw_m;
		float big_vis = smoothstep(4.0, 14.0, px_per_m / crack_scale);
		float fine_vis = smoothstep(18.0, 45.0, px_per_m / (crack_scale * 2.7)) * hairline_amount;
		float grain_vis = smoothstep(80.0, 200.0, px_per_m);
		float big = 0.0;
		float big_d = 1.0;
		float split = 0.0;
		float fine = 0.0;
		if (big_vis > 0.0) {
			vec2 warp = vec2(fbm(cuv * 0.9), fbm(cuv * 0.9 + 7.7)) - 0.5;
			big_d = crack_distance(cuv * crack_scale + warp * 1.1) / crack_scale;
			float width = 0.005 + 0.011 * vnoise(cuv * 3.1);
			// Only some cells are actually split, so the pattern feels natural.
			split = smoothstep(0.25, 0.5, vnoise(cuv * 0.35 + 3.0));
			big = crack_line(big_d, width, fw_m) * mix(0.25, 1.0, split) * big_vis;
			if (fine_vis > 0.0) {
				float mask = smoothstep(0.45, 0.7, vnoise(cuv * 0.6 + 11.0));
				if (mask > 0.0) {
					float fine_d = crack_distance(cuv * crack_scale * 2.7 + warp * 2.0) / (crack_scale * 2.7);
					fine = crack_line(fine_d, 0.006, fw_m) * mask * fine_vis;
				}
			}
		}
		float cracks = clamp(big + fine * 0.7, 0.0, 1.0) * crack_amount;
		float chip = (1.0 - smoothstep(0.0, 0.035, big_d)) * split * 0.25 * crack_amount * big_vis;
		float stain = vnoise(cuv * 0.22 + 31.0) * 0.7 + vnoise(cuv * 0.61) * 0.3;
		float grain = 0.5;
		if (grain_vis > 0.0) {
			grain = vnoise(cuv * 9.0) * 0.5 + vnoise(cuv * 23.0) * 0.5;
		}
		albedo *= 1.0 - stain_amount * smoothstep(0.45, 0.85, stain) + (grain - 0.5) * 0.05 * grain_vis;
		albedo = mix(albedo, albedo * 0.82, chip);
		albedo = mix(albedo, crack_color, cracks);
		cracks_out = cracks;
		height = -cracks - chip * 0.3 + grain * 0.04 * grain_vis;
	}

	ALBEDO = mix(albedo, edge_color, edge * 0.85);
	if (crack_bump > 0.0 && crack_amount > 0.0 && !buried) {
		// Derivative bump mapping: no tangents or textures needed.
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhdx = dFdx(height);
		float dhdy = dFdy(height);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
		float near = clamp(1.0 - length(VERTEX) / 40.0, 0.0, 1.0);
		NORMAL = normalize(abs(det) * NORMAL - grad * crack_bump * 0.006 * near);
	}
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	EMISSION = edge_color * edge * edge_emission + grid_color * emit_grid;
	if (heat_strength > 0.0) {
		float heat = smoothstep(heat_top, heat_bottom, world_pos.y);
		EMISSION += heat_color * heat * heat * heat_strength * (1.0 - cracks_out * 0.6);
	}
	if (buried) {
		ALBEDO = top_color;
		ROUGHNESS = 1.0;
		EMISSION = vec3(0.0);
	}
}
