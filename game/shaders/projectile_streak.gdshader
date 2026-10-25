shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// A shot's streak: a flat strip along its flight path that always turns its face to the camera,
// so it reads from behind (the usual view) as well as from the side. The instance transform gives
// the strip's centre, its direction (the basis' -Z) and its size (the basis' X scale is the width,
// the Z scale the length); the colour is the instance colour.

// Never thinner than this many metres per metre of distance, so far shots stay visible.
uniform float min_width_per_metre = 0.0032;
uniform float glow = 1.6;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 along = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	float length_m = length(MODEL_MATRIX[2].xyz);
	float width_m = max(length(MODEL_MATRIX[0].xyz), -centre.z * min_width_per_metre);
	vec3 side = normalize(cross(along, normalize(centre)));
	// The quad's Y runs -0.5 (tail) .. 0.5 (head), X across.
	VERTEX = centre + along * VERTEX.y * length_m + side * VERTEX.x * width_m;
	NORMAL = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// UV.y is 0 at the head and 1 at the tail; UV.x spans the width.
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float tail = pow(1.0 - UV.y, 1.4);
	float core = pow(across, 2.5) * (0.4 + 0.6 * tail);
	vec3 colour = mix(COLOR.rgb, vec3(1.0), core * 0.6);
	ALBEDO = colour * glow * (across * 0.55 + core) * (0.25 + 0.75 * tail);
	ALPHA = 1.0;
}
