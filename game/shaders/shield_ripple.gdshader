shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// The shield bubble: invisible until a hit, then a bright flash where it landed and a ring that
// spreads over the bubble. Each ripple is a vec4: xyz = direction of the hit on the unit sphere
// (in the bubble's own space), w = seconds since the hit, or a negative number when unused.
uniform vec4 ripple_0 = vec4(0.0, 0.0, 1.0, -1.0);
uniform vec4 ripple_1 = vec4(0.0, 0.0, 1.0, -1.0);
uniform vec4 ripple_2 = vec4(0.0, 0.0, 1.0, -1.0);
uniform vec4 ripple_3 = vec4(0.0, 0.0, 1.0, -1.0);
uniform vec4 shield_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform float duration = 0.7;
uniform float strength = 0.75;

varying vec3 bubble_dir;

float ripple(vec4 r) {
	if (r.w < 0.0 || r.w > duration) {
		return 0.0;
	}
	float t = r.w / duration;
	float angle = acos(clamp(dot(bubble_dir, r.xyz), -1.0, 1.0));
	float ring = exp(-pow((angle - t * 1.7) * 5.5, 2.0));
	float core = exp(-angle * angle * 7.0);
	float fade = 1.0 - t;
	return (ring * 0.9 + core * 1.3) * fade * fade;
}

void vertex() {
	bubble_dir = normalize(VERTEX);
}

void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float hit = ripple(ripple_0) + ripple(ripple_1) + ripple(ripple_2) + ripple(ripple_3);
	float amount = hit * (0.35 + 0.65 * edge) * strength;
	ALBEDO = shield_color.rgb * amount;
	ALPHA = clamp(amount, 0.0, 1.0);
}
