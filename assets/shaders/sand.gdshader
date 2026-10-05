// Areia do Plano do Fogo: ocre avermelhado, ondulações do vento e alguns grãos que brilham com a luz.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 sand_light : source_color = vec3(0.76, 0.55, 0.38);
uniform vec3 sand_dark : source_color = vec3(0.4, 0.24, 0.16);
uniform vec3 crest_tint : source_color = vec3(1.0, 0.86, 0.66);
// Ondulações do vento (marcas na areia)
uniform float ripple_frequency = 2.2;
uniform float ripple_strength = 0.28;
uniform vec2 wind_direction = vec2(0.85, 0.5);
// Brilho dos grãos
uniform float glitter_density : hint_range(0.9, 1.0) = 0.997;
uniform float glitter_strength = 1.5;
uniform float glitter_scale = 38.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash31(vec3(i, 1.0));
	float b = hash31(vec3(i + vec2(1.0, 0.0), 1.0));
	float c = hash31(vec3(i + vec2(0.0, 1.0), 1.0));
	float d = hash31(vec3(i + vec2(1.0, 1.0), 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 wind = normalize(wind_direction);

	// Ondulações: senoide ao longo do vento, entortada por ruído
	float warp = noise2(p * 0.18) * 5.0 + noise2(p * 0.05) * 9.0;
	float phase = dot(p, wind) * ripple_frequency + warp;
	float slope = cos(phase);
	vec3 n = normalize(world_normal + vec3(wind.x, 0.0, wind.y) * slope * ripple_strength * world_normal.y);

	// Cor: encostas viradas para cima mais claras, sombra quente nas partes íngremes
	float up = clamp(n.y, 0.0, 1.0);
	vec3 albedo = mix(sand_dark, sand_light, smoothstep(0.55, 0.98, up));
	albedo = mix(albedo, crest_tint, smoothstep(0.6, 1.0, sin(phase) * 0.5 + 0.5) * 0.12);
	albedo *= 0.94 + noise2(p * 3.0) * 0.08;

	// Brilho: cada grão tem uma chance de refletir; muda conforme o ângulo da câmera
	vec3 view_world = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 grain = floor(world_pos * glitter_scale);
	float seed = hash31(grain + floor(view_world * 9.0) * 17.0);
	float sparkle = step(glitter_density, seed) * smoothstep(0.2, 0.9, dot(n, view_world));

	ALBEDO = albedo;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 0.82;
	SPECULAR = 0.35;
	RIM = 0.25;
	RIM_TINT = 0.6;
	EMISSION = vec3(1.0, 0.93, 0.8) * sparkle * glitter_strength;
}
