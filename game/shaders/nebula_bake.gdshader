shader_type canvas_item;
// Paints one face of the sky cubemap: a layered-noise nebula, a star field and the sun. It runs
// once, in a SubViewport, when a zone loads (SkyBaker); the result is stored as a cubemap that
// `nebula_sky.gdshader` shows. Colours and sizes come from the ArenaDef.

uniform int face = 0;
uniform float seed = 3.0;
uniform vec3 space_color : source_color = vec3(0.012, 0.01, 0.02);
uniform vec3 nebula_deep : source_color = vec3(0.25, 0.07, 0.02);
uniform vec3 nebula_main : source_color = vec3(1.0, 0.45, 0.08);
uniform vec3 nebula_hot : source_color = vec3(1.0, 0.82, 0.45);
uniform vec3 dust_lane : source_color = vec3(0.02, 0.012, 0.01);
uniform float nebula_scale = 1.6;
uniform float nebula_strength = 1.0;
uniform float star_density = 0.5;
uniform float star_brightness = 1.0;
uniform vec3 sun_direction = vec3(0.55, 0.28, -0.78);
uniform vec3 sun_color : source_color = vec3(0.85, 0.92, 1.0);
uniform float sun_radius = 0.0244; // radians

// Direction of pixel `uv` (0..1, origin top left) on a cubemap face, in Godot's face order:
// +X, -X, +Y, -Y, +Z, -Z (Vulkan cube map convention).
vec3 face_direction(int f, vec2 uv) {
	float sc = uv.x * 2.0 - 1.0;
	float tc = uv.y * 2.0 - 1.0;
	if (f == 0) return vec3(1.0, -tc, -sc);
	if (f == 1) return vec3(-1.0, -tc, sc);
	if (f == 2) return vec3(sc, 1.0, tc);
	if (f == 3) return vec3(sc, -1.0, -tc);
	if (f == 4) return vec3(sc, -tc, 1.0);
	return vec3(-sc, -tc, -1.0);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	vec3 q = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(q) * 43758.5453);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float g = hash13(i + vec3(1.0, 0.0, 1.0));
	float h = hash13(i + vec3(0.0, 1.0, 1.0));
	float k = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 6; i++) {
		sum += amp * value_noise(p);
		p = p * 2.03 + vec3(17.1, 9.2, 5.3);
		amp *= 0.5;
	}
	return sum;
}

// One layer of stars: a random point in each cell of a 3D grid, drawn as a small soft dot.
float star_layer(vec3 d, float cells, float chance, float size) {
	vec3 p = d * cells;
	vec3 cell = floor(p);
	float exists = step(1.0 - chance, hash13(cell + 7.7));
	vec3 centre = cell + 0.15 + 0.7 * hash33(cell + 3.1);
	float dist = length(p - centre);
	float shine = 0.35 + 0.65 * hash13(cell + 11.3);
	return exists * shine * smoothstep(size, 0.0, dist);
}

void fragment() {
	vec3 d = normalize(face_direction(face, UV));
	vec3 sun = normalize(sun_direction);

	// Nebula: a warped fbm gives the gas, a second one the bright cores and a third the lanes.
	vec3 p = d * nebula_scale + vec3(seed * 1.7, seed * 0.9, seed * 2.3);
	float warp = fbm(p * 0.8 + 11.0);
	float gas = fbm(p + warp * 1.6);
	float body = smoothstep(0.42, 0.85, gas);
	float cores = smoothstep(0.55, 0.9, fbm(p * 2.1 + warp * 2.0 + 5.0));
	float lanes = smoothstep(0.5, 0.78, fbm(p * 1.3 + vec3(40.0, 3.0, 9.0)));
	// More gas towards one band of the sky, so the sky has a direction and an empty side.
	float band = 0.35 + 0.65 * smoothstep(-0.6, 0.5, dot(d, normalize(vec3(-0.3, 0.2, 0.9))));

	vec3 col = space_color;
	col += nebula_deep * smoothstep(0.3, 0.75, gas) * 0.7 * nebula_strength;
	col = mix(col, nebula_main * 0.55, body * band * nebula_strength);
	col += nebula_hot * cores * body * band * 0.55 * nebula_strength;
	col = mix(col, dust_lane, lanes * body * 0.7);
	// The sun lights the gas near it.
	float toward_sun = max(dot(d, sun), 0.0);
	col += nebula_main * pow(toward_sun, 4.0) * body * 0.5 * nebula_strength;

	// Stars: dim and dense, plus rarer bright ones. Fewer where the nebula is thick.
	float cover = 1.0 - 0.7 * body * band;
	float stars = star_layer(d, 70.0, 0.22 * star_density, 0.07) * 0.7;
	stars += star_layer(d, 150.0, 0.2 * star_density, 0.09) * 0.6;
	stars += star_layer(d, 38.0, 0.1 * star_density, 0.06) * 1.2;
	col += vec3(0.85, 0.9, 1.0) * stars * star_brightness * cover;

	// The sun: a hard disc with a soft halo.
	float angle = acos(clamp(dot(d, sun), -1.0, 1.0));
	float disc = smoothstep(sun_radius * 1.15, sun_radius * 0.85, angle);
	float halo = exp(-angle / (sun_radius * 3.0)) * 0.45 + exp(-angle / (sun_radius * 14.0)) * 0.12;
	col += sun_color * (disc * 1.6 + halo);

	COLOR = vec4(col, 1.0);
}
