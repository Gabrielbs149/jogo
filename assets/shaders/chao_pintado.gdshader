// Chão pintado (D027): grama, terra e calçada misturadas por um mapa (máscara) do tamanho da área.
// Na máscara: vermelho = terra, verde = calçada; o resto é grama. As bordas se desfazem com ruído,
// então ruas e praças não têm recorte reto. A máscara é gerada junto com a fase (tools/art/montar_arandu.gd).
shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform sampler2D mask : source_color, filter_linear, repeat_disable;
uniform vec2 area_center = vec2(0.0);
uniform vec2 area_size = vec2(220.0);

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cobble_meters = 2.2;

uniform vec3 grass_light : source_color = vec3(0.47, 0.6, 0.26);
uniform vec3 grass_dark : source_color = vec3(0.31, 0.45, 0.18);
uniform vec3 grass_dry : source_color = vec3(0.62, 0.6, 0.32);
uniform vec3 dirt_light : source_color = vec3(0.66, 0.53, 0.36);
uniform vec3 dirt_dark : source_color = vec3(0.5, 0.39, 0.26);
uniform vec3 cobble_tint : source_color = vec3(1.0, 0.96, 0.9);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = (p - area_center) / area_size + 0.5;
	vec4 m = texture(mask, uv);
	float n1 = texture(noise, p / 7.0).r;
	float n2 = texture(noise, p / 23.0 + vec2(0.37, 0.71)).r;
	float n3 = texture(noise, p / 61.0 + vec2(0.13, 0.52)).r;

	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.25, 0.85, n1 * 0.55 + n2 * 0.45));
	grass = mix(grass, grass_dry, smoothstep(0.55, 0.9, n3) * 0.6);
	vec3 dirt = mix(dirt_dark, dirt_light, smoothstep(0.2, 0.8, n1 * 0.6 + n2 * 0.4));

	float d = smoothstep(0.38, 0.62, m.r + (n1 - 0.5) * 0.45 + (n2 - 0.5) * 0.2);
	vec3 col = mix(grass, dirt, d);

	vec2 cuv = p / cobble_meters;
	vec3 cobble = texture(cobble_albedo, cuv).rgb * cobble_tint;
	float c = smoothstep(0.42, 0.58, m.g + (n1 - 0.5) * 0.25);
	col = mix(col, cobble, c);

	ALBEDO = col;
	ROUGHNESS = mix(0.97, 0.85, c);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(cobble_normal, cuv).rgb, c);
	NORMAL_MAP_DEPTH = 1.0;
}
