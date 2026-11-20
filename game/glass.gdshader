shader_type spatial;
render_mode cull_back, depth_draw_never;

uniform sampler2D background : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 glass : source_color = vec4(0.24, 0.37, 0.15, 1.0);
uniform float scuff = 0.28;
uniform float wetness = 0.0;
uniform vec4 adhesive_area = vec4(-1.13, 2.48, 0.052, 0.166);
uniform float stain_seed = 0.0;
uniform float adhesive_strength = 0.0;
uniform float grime_strength = 0.0;
uniform float wipe_coverage = 0.0;
varying vec3 local;

void vertex() {
	local = VERTEX;
}

float stain_hash(vec2 point) {
	vec3 p = fract(vec3(point.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float stain_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(point));
	return mix(mix(stain_hash(cell), stain_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(stain_hash(cell + vec2(0.0, 1.0)), stain_hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

float adhesive_mask(float angle, float height) {
	// The opaque paper wrap hides this film until its paper fragments are removed.
	vec2 wrap = vec2((angle - adhesive_area.x) / adhesive_area.y,
		(height - adhesive_area.z) / (adhesive_area.w - adhesive_area.z));
	vec2 margin = min(wrap, 1.0 - wrap);
	float inside = smoothstep(0.012, 0.085, margin.x) * smoothstep(0.025, 0.13, margin.y);
	vec2 patch = wrap * vec2(7.5, 6.4) + vec2(stain_seed, stain_seed * 0.4);
	float warp = stain_noise(patch * 1.7);
	float cloudy = stain_noise(patch + vec2(warp * 0.76, -warp * 0.51));
	float grain = stain_noise(patch * vec2(4.3, 6.1));
	float film = smoothstep(0.39, 0.72, cloudy * 0.76 + grain * 0.24);
	return inside * film * (0.48 + 0.52 * grain);
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
	float adhesive = 0.0;
	float grime = 0.0;
	if (wipe_coverage < 1.0 && (adhesive_strength > 0.0 || grime_strength > 0.0)) {
		vec2 stain_point = vec2(sin(angle + 0.82) * 7.2 + stain_seed, local.y * 86.0);
		float rough_patch = stain_noise(stain_point);
		float wipe_rank = mix(0.15, 0.85, clamp(0.45 + sin(angle) * 0.36 + (rough_patch - 0.5) * 0.24, 0.0, 1.0));
		float remaining = 1.0 - smoothstep(wipe_rank - 0.13, wipe_rank + 0.13, wipe_coverage);
		adhesive = adhesive_strength * adhesive_mask(angle, local.y) * remaining;
		float dirt_band = smoothstep(0.034, 0.058, local.y) * (1.0 - smoothstep(0.150, 0.204, local.y));
		float dirt = smoothstep(0.54, 0.81, rough_patch * 0.78 + stain_noise(stain_point * 3.8) * 0.22);
		grime = grime_strength * dirt_band * dirt * remaining;
	}
	vec3 clear_glass = through * (1.0 - reflection * 0.74) + glint;
	vec3 old_glue = mix(clear_glass * 0.70, vec3(0.65, 0.49, 0.26), 0.66);
	vec3 dirty_glass = mix(clear_glass * 0.47, vec3(0.33, 0.24, 0.12), 0.49);
	ALBEDO = glass.rgb * 0.035;
	EMISSION = mix(mix(clear_glass, old_glue, adhesive), dirty_glass, grime);
	ROUGHNESS = 0.13 + haze * 0.24 - wetness*.043 + adhesive * 0.43 + grime * 0.36;
	SPECULAR = 0.84;
	ALPHA = 1.0;
}
