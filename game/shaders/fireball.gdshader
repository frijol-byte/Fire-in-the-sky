shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// An exploding fireball on a camera-facing card, animated by `progress` (0 at the blast, 1 when it
// is over): a white-hot core that swells into churning orange cloud and cools to dark red while it
// thins out. It stands in for a hand-painted flipbook until the art pass (M8). With `ring` on, the
// card draws the expanding shockwave ring instead.
uniform float progress = 0.0;
uniform float noise_seed = 0.0;
uniform vec4 fire_color : source_color = vec4(1.0, 0.62, 0.2, 1.0);
uniform bool ring = false;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	// Face the camera and keep the card's scale: the model matrix scale is the fireball's size.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 billboard = mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (ring) {
		float edge = progress;
		float band = exp(-pow((r - edge) * 9.0, 2.0));
		float fade = (1.0 - progress) * (1.0 - progress);
		ALBEDO = mix(fire_color.rgb, vec3(1.0), 0.5) * band * fade * 0.8;
		ALPHA = clamp(band * fade, 0.0, 1.0);
	} else {
		float grow = 1.0 - (1.0 - progress) * (1.0 - progress);
		float edge = mix(0.18, 0.95, grow);
		vec2 q = p * 2.4 + vec2(noise_seed * 7.3, noise_seed * 3.1) + vec2(0.0, -progress * 1.4);
		float cloud = fbm(q);
		float density = smoothstep(edge, edge - 0.55, r + (cloud - 0.5) * 0.7);
		float heat = clamp(1.0 - r / max(edge, 0.001) - progress * 0.9 + cloud * 0.25, 0.0, 1.0);
		vec3 cold = fire_color.rgb * vec3(0.45, 0.2, 0.1);
		vec3 warm = fire_color.rgb;
		vec3 hot = vec3(1.0, 0.92, 0.7);
		vec3 colour = mix(cold, warm, smoothstep(0.0, 0.5, heat));
		colour = mix(colour, hot, smoothstep(0.5, 1.0, heat));
		float fade = (1.0 - progress) * (1.0 - progress * 0.5);
		float intensity = density * fade;
		ALBEDO = colour * intensity * 2.4;
		ALPHA = clamp(intensity, 0.0, 1.0);
	}
}
