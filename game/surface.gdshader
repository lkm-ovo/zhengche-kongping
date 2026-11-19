shader_type spatial;

uniform vec4 tint : source_color = vec4(0.32, 0.34, 0.30, 1.0);
uniform float coarse = 0.10;
uniform float grain = 0.07;
uniform float scale_world = 1.0;
uniform int finish = 0;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 object_position;

float hash21(vec2 uv) {
	vec3 p = fract(vec3(uv.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise21(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	object_position = VERTEX;
}

void fragment() {
	vec3 axis = abs(normalize(world_normal));
	vec2 uv = world_position.xz;
	if (axis.x > max(axis.y, axis.z)) {
		uv = world_position.zy;
	} else if (axis.z > axis.y) {
		uv = world_position.xy;
	}
	uv *= scale_world;
	float broad = noise21(uv * 1.67) - 0.5;
	float mid = noise21(uv * 8.34) - 0.5;
	float fine = noise21(uv * 231.0) - 0.5;
	float value = 1.0 + coarse * (broad + mid * 0.32) + grain * fine;
	float roughness = 0.88 + 0.05 * mid;
	float metalness = 0.0;
	float height = 0.04 * mid + 0.10 * fine;
	if (finish == 1) {
		vec2 g = uv * vec2(2.8, 36.0);
		float warp = noise21(g * vec2(0.63, 0.12));
		float pore = noise21(vec2(g.x * 1.8, g.y * 5.0 + warp * 3.4));
		float growth = noise21(vec2(g.x * 0.55, g.y * 1.49 + warp * 3.87));
		float board = hash21(vec2(floor((world_position.z + 0.53) / 0.166), 2.0));
		float seam = 1.0 - smoothstep(0.003, 0.016, abs(fract((world_position.z + 0.53) / 0.166) - 0.5));
		float stains = smoothstep(0.56, 0.84, noise21(uv * 4.2 + vec2(14.2, 2.8)));
		value *= (0.78 + 0.38 * growth + 0.15 * pore + board * 0.18) * (1.0 - stains * 0.25);
		value *= 1.0 - 0.44 * seam * step(0.6, axis.y);
		roughness = 0.61 + growth * 0.12 + stains * 0.14;
		height = 0.13 * pore + 0.12 * growth;
	} else if (finish == 2) {
		float brushing = noise21(uv * vec2(3.1, 272.0));
		float wear = smoothstep(0.52, 0.93, noise21(uv * 14.2));
		value = 0.90 + brushing * 0.18 - wear * 0.18;
		roughness = 0.27 + brushing * 0.075 + wear * 0.17;
		metalness = 0.83;
		height = 0.017 * brushing;
	} else if (finish == 3) {
		float soot = smoothstep(0.56, 0.87, noise21(uv * 6.2));
		float pebbles = noise21(uv * 428.0);
		value *= 0.94 + pebbles * 0.11 - soot * 0.22;
		roughness = 0.81 + 0.12 * soot;
		height = 0.09 * pebbles;
	} else if (finish == 4) {
		float film = smoothstep(0.52, 0.88, noise21(uv * 9.2));
		float tile_variation = hash21(floor(uv / vec2(0.35, 0.278) + vec2(0.5, 0.40)));
		value *= 0.91 + tile_variation * 0.21 - film * 0.12;
		roughness = 0.27 + 0.28 * film + fine * 0.025;
		height = 0.012 * fine;
	} else if (finish == 5) {
		float patina = smoothstep(0.53, 0.86, noise21(uv * 15.5));
		float scratch = smoothstep(0.79, 0.94, noise21(uv * vec2(265.0, 7.0))) * patina;
		value = 0.92 + broad * 0.22 + fine * 0.05 - patina * 0.14 + scratch * 0.30;
		roughness = 0.55 + 0.24 * patina;
		metalness = 0.12 + scratch * 0.42;
		height = 0.03 * fine - 0.03 * scratch;
	} else if (finish == 6) {
		vec2 weave_space = vec2(object_position.x + object_position.z * 0.8, object_position.y);
		vec2 thread = weave_space * vec2(815.0, 1100.0);
		float weave = sin(thread.x) * sin(thread.y);
		float fibers = noise21(thread * 0.36);
		value = 0.93 + 0.14 * fibers + 0.035 * weave;
		roughness = 0.94;
		height = 0.041 * weave;
	} else {
		float damp = smoothstep(0.50, 0.84, noise21(uv * vec2(7.6, 3.7)));
		float base = 1.0 - smoothstep(0.07, 0.58, world_position.y);
		value *= 1.0 - damp * (0.06 + base * 0.16);
	}
	vec3 normal = normalize(NORMAL);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 cross_x = cross(dy, normal);
	vec3 cross_y = cross(normal, dx);
	float det = dot(dx, cross_x);
	vec3 grad = sign(det) * (dFdx(height) * cross_x + dFdy(height) * cross_y);
	NORMAL = normalize(normal * max(abs(det), 0.00000001) - 0.00061 * grad);
	ALBEDO = tint.rgb * max(value, 0.25);
	ROUGHNESS = roughness;
	METALLIC = metalness;
}
