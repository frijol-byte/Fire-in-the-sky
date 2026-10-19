shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Space dust and boost streaks: a MultiMesh of quads scattered in a box that follows the camera.
// Each quad is a speck of dust, stretched along the ship's velocity into a short line. A speck
// that leaves the box wraps round to the other side, so the density around the camera never
// changes, however fast it flies. Nothing is simulated on the CPU.

uniform float box_size = 160.0;
// Velocity of the camera relative to the dust (the ship's velocity), world space.
uniform vec3 velocity = vec3(0.0);
// Seconds of motion a streak shows, so a faster ship gets longer lines.
uniform float streak_time = 0.03;
uniform float min_length = 0.35;
uniform float width = 0.12;
uniform float intensity = 1.0;
// Extra brightness gained with speed (0 = specks are the same at rest and at full speed).
uniform float speed_gain = 0.0;
uniform float full_speed = 320.0;
uniform vec4 tint : source_color = vec4(0.85, 0.9, 1.0, 1.0);

varying float v_alpha;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	vec3 camera = INV_VIEW_MATRIX[3].xyz;
	vec3 home = MODEL_MATRIX[3].xyz;
	float half_box = 0.5 * box_size;
	vec3 rel = mod(home - camera + vec3(half_box), box_size) - vec3(half_box);
	vec3 centre = camera + rel;

	float speed = length(velocity);
	vec3 to_speck = normalize(rel + vec3(0.0001));
	vec3 dir = speed > 0.5 ? velocity / speed : vec3(0.0, 1.0, 0.0);
	vec3 side = cross(dir, to_speck);
	float side_length = length(side);
	// Flying straight at a speck foreshortens it to a dot: any side vector will do then.
	side = side_length > 0.001 ? side / side_length : normalize(cross(to_speck, vec3(0.0, 1.0, 0.001)));
	float length_m = max(min_length, speed * streak_time);
	vec3 world = centre + side * VERTEX.x * width + dir * VERTEX.y * length_m;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);

	float edge = max(abs(rel.x), max(abs(rel.y), abs(rel.z))) / half_box;
	float fade = 1.0 - smoothstep(0.7, 1.0, edge);
	float near = smoothstep(1.5, 8.0, length(rel));
	float brightness = 0.35 + 0.65 * hash13(home);
	float fast = 1.0 + speed_gain * clamp(speed / full_speed, 0.0, 1.0);
	v_alpha = fade * near * brightness * fast * intensity;
}

void fragment() {
	// UV.y runs from the tail (0) to the head (1) of the streak; fade the tail and the sides.
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = pow(clamp(UV.y, 0.0, 1.0), 1.5);
	ALBEDO = tint.rgb;
	ALPHA = clamp(v_alpha * across * across * (0.15 + 0.85 * along), 0.0, 1.0);
}
