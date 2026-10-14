shader_type spatial;
render_mode cull_front, unshaded;

uniform float width = 0.03;
uniform vec4 outline_color : source_color = vec4(0.05, 0.03, 0.08, 1.0);
uniform float clip_y = 0.0;

varying float h;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = wp.y;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	wp += wn * width;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	if (h < clip_y) discard;
	ALBEDO = outline_color.rgb;
}