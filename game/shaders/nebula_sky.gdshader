shader_type sky;
// Shows the baked sky cubemap (see SkyBaker and nebula_bake.gdshader).

uniform samplerCube cubemap : source_color, filter_linear_mipmap, repeat_disable;
uniform float energy = 1.0;

void sky() {
	COLOR = texture(cubemap, EYEDIR).rgb * energy;
}
