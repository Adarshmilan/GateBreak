shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation = 1.4;
uniform float brightness = 1.25;
uniform float smooth_lod = 1.6;
uniform float clip_y = 0.0;          // everything below this height is cut (guns). Zombies use -100.

varying float h;

void vertex() {
	h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (h < clip_y) discard;
	vec3 c = textureLod(albedo_tex, UV, smooth_lod).rgb * tint.rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation) * brightness;
	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	float b = 0.55 + 0.22 * smoothstep(-0.05, 0.1, nl) + 0.28 * smoothstep(0.4, 0.6, nl);
	DIFFUSE_LIGHT += LIGHT_COLOR * b * ATTENUATION;
}