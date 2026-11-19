shader_type spatial;
render_mode cull_back, depth_draw_never;

uniform sampler2D background : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 glass : source_color = vec4(0.24, 0.37, 0.15, 1.0);
uniform float scuff = 0.28;
uniform float wetness = 0.0;
varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec3 view = normalize(VIEW);
	vec3 n = normalize(NORMAL);
	float facing = max(dot(n, view), 0.0);
	float base_thickness = 1.0 - smoothstep(0.006, 0.039, local.y);
	float angle = atan(local.x, local.z);
	float waves = sin(angle * 17.0 + local.y * 120.0) * cos(local.y * 91.0);
	float fine = sin(angle * 185.0 + local.y * 397.0);
	float scratches = pow(max(fine, 0.0), 39.0) * max(waves, 0.0) * scuff;
	float abraded = exp(-abs(local.y - 0.022) * 195.0) + exp(-abs(local.y - 0.155) * 300.0);
	float haze = scratches * 0.42 + abraded * scuff * 0.19;
	vec3 bent = refract(-view, n, 0.79);
	vec2 warp = (bent.xy + view.xy) * (0.049 + 0.035 * base_thickness);
	warp.y += 0.009 * base_thickness + waves * 0.00065;
	vec2 uv = clamp(SCREEN_UV + warp, vec2(0.002), vec2(0.998));
	vec3 through = textureLod(background, uv, 0.50 + 1.35 * haze).rgb;
	vec3 transmission = mix(vec3(0.08), vec3(0.97), pow(max(glass.rgb, vec3(0.006)), vec3(0.38)));
	through *= pow(transmission, vec3(0.79 + 0.48 * base_thickness + (1.0 - facing) * 0.54));
	float reflection = 0.04 + 0.96 * pow(1.0 - facing, 5.0);
	float window_highlight = pow(max(cos(angle + 0.91), 0.0), 120.0) * (0.14 + facing * 0.62);
	float room_highlight = pow(max(cos(angle - 0.68), 0.0), 55.0) * 0.30;
	vec3 glint = vec3(0.77, 0.85, 0.86) * (window_highlight + room_highlight + reflection * 0.21 + haze * 0.45);
	vec2 film_cell = fract(vec2(angle*13.0,local.y*218.0)+sin(floor(local.y*192.0)*3.2)*.14)-.5;
	float beads = (1.0-smoothstep(.08,.21,length(film_cell*vec2(1.0,.67)))) * wetness;
	glint += vec3(.75,.88,.94)*beads*.16;
	ALBEDO = glass.rgb * 0.035;
	EMISSION = through * (1.0 - reflection * 0.74) + glint;
	ROUGHNESS = 0.13 + haze * 0.24 - wetness*.043;
	SPECULAR = 0.84;
	ALPHA = 1.0;
}
