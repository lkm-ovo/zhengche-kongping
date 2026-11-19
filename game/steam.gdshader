shader_type spatial;
render_mode unshaded, depth_draw_never;

void fragment() {
	float soft_edge = pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.0),2.1);
	float billow = .68 + .22*sin(UV.x*36.0+UV.y*28.0) + .10*cos(UV.x*19.0-UV.y*47.0);
	ALBEDO = vec3(.86,.91,.88);
	ALPHA = soft_edge*billow*.26;
}
