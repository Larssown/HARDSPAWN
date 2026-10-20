shader_type sky;

// Bright, hazy "heavenly" overcast sky: milky white at the horizon, soft blue-grey
// above, and a broad warm glow where the hidden sun sits behind the haze.
uniform vec3 horizon_color : source_color = vec3(0.93, 0.93, 0.92);
uniform vec3 zenith_color : source_color = vec3(0.74, 0.77, 0.81);
uniform vec3 below_color : source_color = vec3(0.90, 0.90, 0.89);
uniform vec3 glow_color : source_color = vec3(1.0, 0.96, 0.88);
uniform float brightness = 1.05;

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, -1.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(smoothstep(0.0, 1.0, up), 0.7));
	col = mix(col, below_color, smoothstep(0.0, -0.25, up));
	vec3 sun_dir = normalize(LIGHT0_DIRECTION);
	float facing = max(dot(dir, sun_dir), 0.0);
	col += glow_color * (pow(facing, 3.0) * 0.35 + pow(facing, 24.0) * 0.45);
	COLOR = col * brightness;
}
