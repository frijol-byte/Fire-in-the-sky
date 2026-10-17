shader_type spatial;
// Placeholder faction paint (art bible 3.2). The hull colour comes from per-ship instance
// parameters, so a paint job never needs a new material. `paint_role` picks which of the two
// colours this material uses (0 = primary, 1 = secondary). Panel lines come from the shader
// (object-space grid), not from textures.

instance uniform vec4 primary_color : source_color = vec4(0.30, 0.38, 0.52, 1.0);
instance uniform vec4 secondary_color : source_color = vec4(0.86, 0.46, 0.12, 1.0);
uniform int paint_role = 0;
uniform float panel_size = 1.4;
uniform float panel_line_width = 0.03;
uniform float panel_line_darkness = 0.45;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.15;

varying vec3 object_position;

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	vec3 base = paint_role == 0 ? primary_color.rgb : secondary_color.rgb;
	// Distance to the nearest panel seam on each axis; the seam is where any axis is near 0.
	vec3 cell = abs(fract(object_position / panel_size + 0.5) - 0.5) * panel_size;
	float seam = 1.0 - smoothstep(panel_line_width, panel_line_width * 2.0, min(cell.x, min(cell.y, cell.z)));
	// A faint per-panel brightness shift so large flat areas do not look like one flat colour.
	vec3 panel_id = floor(object_position / panel_size + 0.5);
	float shift = fract(sin(dot(panel_id, vec3(12.9898, 78.233, 37.719))) * 43758.5453) - 0.5;
	vec3 colour = base * (1.0 + shift * 0.12);
	ALBEDO = mix(colour, colour * (1.0 - panel_line_darkness), seam);
	ROUGHNESS = mix(roughness_value, roughness_value + 0.25, seam);
	METALLIC = metallic_value;
}
