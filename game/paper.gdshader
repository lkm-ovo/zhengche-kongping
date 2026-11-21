shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec4 paper : source_color = vec4(0.75, 0.69, 0.50, 1.0);
uniform vec4 ink : source_color = vec4(0.24, 0.29, 0.17, 1.0);
uniform float printed = 1.0;
uniform bool sleeve = false;
uniform float scraped = 0.0;
uniform int scrape_passes = 1;
uniform vec2 label_band = vec2(0.067, 0.148);
uniform float adhesion_threshold = 0.62;
varying float label_height;

void vertex() {
	label_height = clamp((VERTEX.y - label_band.x) / (label_band.y - label_band.x), 0.0, 1.0);
}

float grain(vec2 uv) {
	vec3 p = fract(vec3(uv.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec2 uv = UV;
	float fiber = grain(floor(uv * vec2(626.0, 355.0)));
	vec2 islands = uv + vec2(sin(uv.y*33.0), cos(uv.x*27.0)) * 0.018;
	float adhesion = grain(floor(islands*vec2(18.0, 12.0)) + vec2(3.0, 19.0));
	float pass_needed = 0.0;
	if (scrape_passes > 1 && adhesion >= adhesion_threshold) {
		float stubbornness = (adhesion - adhesion_threshold) / (1.0 - adhesion_threshold);
		pass_needed = min(float(scrape_passes - 1), 1.0 + floor(stubbornness * float(scrape_passes - 1)));
	}
	float cut = clamp(scraped*float(scrape_passes) - pass_needed, 0.0, 1.0);
	float scrape_edge = 1.0 - cut;
	scrape_edge += (grain(vec2(floor(uv.x*68.0), 1.0)) - 0.44) * 0.095;
	scrape_edge += 0.052 * cos(uv.x * 10.0);
	if (cut >= 0.998 || (cut > 0.0 && label_height > scrape_edge)) {
		discard;
	}
	float fleck = max(0.0, grain(floor(uv * vec2(77.0, 57.0))) - 0.83) * 0.35;
	float stripe = smoothstep(0.045, 0.070, uv.y) * (1.0 - smoothstep(0.130, 0.143, uv.y));
	stripe += smoothstep(0.835, 0.848, uv.y) * (1.0 - smoothstep(0.89, 0.905, uv.y));
	float rules = 1.0-smoothstep(0.004,0.013,abs(uv.y-0.22));
	vec3 base = mix(paper.rgb, ink.rgb, min(stripe * .82 + rules * .45, 1.0) * printed);
	float dirt = 0.14 * smoothstep(0.17, 0.22, length((uv-vec2(.82,.18))*vec2(.7,1.0)));
	ALBEDO = base * (0.99 + (sleeve ? 0.038 : 0.14)*(fiber-0.5) - fleck - dirt*0.32);
	if (cut > 0.0) {
		ALBEDO = mix(ALBEDO, paper.rgb * 1.12, smoothstep(scrape_edge - 0.066, scrape_edge, label_height) * 0.39);
	}
	ROUGHNESS = sleeve ? 0.29 + fiber*0.13 : 0.84 + fiber*0.11;
}
