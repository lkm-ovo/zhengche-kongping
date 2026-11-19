shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_atlas : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 local;

float hash21(vec2 uv) {
	vec3 p = fract(vec3(uv.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec3 pigmentation = texture(skin_atlas, UV).rgb;
	vec2 grain_uv = (local.xy + vec2(local.z*.39,local.z*.86)) * 3900.0;
	float pores = hash21(floor(grain_uv));
	float grain = mix(.018,-.018,pores);
	float variation = dot(pigmentation,vec3(.26,.65,.09));
	ALBEDO = pigmentation * (0.95 + grain);
	ROUGHNESS = .52 + pores*.065 + (1.0-variation)*.07;
	SPECULAR = .32;
}
