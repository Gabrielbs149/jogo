// Chão pintado (D027): grama, terra e calçada misturadas por um mapa (máscara) do tamanho da área.
// Na máscara: vermelho = terra, verde = calçada; o resto é grama. A terra e a grama têm grão, pedrinhas,
// rachaduras e relevo feitos aqui (várias escalas do mesmo ruído); as bordas são irregulares e definidas.
shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform sampler2D mask : source_color, filter_linear, repeat_disable;
uniform vec2 area_center = vec2(0.0);
uniform vec2 area_size = vec2(220.0);

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cobble_meters = 2.2;

uniform vec3 grass_light : source_color = vec3(0.46, 0.6, 0.25);
uniform vec3 grass_dark : source_color = vec3(0.27, 0.42, 0.16);
uniform vec3 grass_dry : source_color = vec3(0.6, 0.58, 0.3);
uniform vec3 dirt_light : source_color = vec3(0.62, 0.48, 0.32);
uniform vec3 dirt_dark : source_color = vec3(0.42, 0.31, 0.2);
uniform vec3 pebble_color : source_color = vec3(0.7, 0.66, 0.58);
uniform vec3 cobble_tint : source_color = vec3(1.0, 0.96, 0.9);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float n(vec2 p, float meters, vec2 offset) {
	return texture(noise, p / meters + offset).r;
}

// relevo: grande, médio, pequeno e grão
float height(vec2 p) {
	return n(p, 9.0, vec2(0.0)) * 0.42 + n(p, 2.6, vec2(0.31, 0.17)) * 0.3 + n(p, 0.75, vec2(0.7, 0.4)) * 0.18
		+ n(p, 0.23, vec2(0.11, 0.83)) * 0.1;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = (p - area_center) / area_size + 0.5;
	vec4 m = texture(mask, uv);
	float h = height(p);
	float big = n(p, 31.0, vec2(0.37, 0.71));
	float huge = n(p, 70.0, vec2(0.13, 0.52));

	// grama: manchas grandes, tufos médios e um "pente" fino que lembra folha
	float blades = n(p * vec2(1.0, 0.35), 0.18, vec2(0.5, 0.2));
	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.25, 0.8, h * 0.7 + big * 0.3));
	grass = mix(grass, grass_dry, smoothstep(0.58, 0.85, huge) * 0.55);
	grass *= 0.86 + blades * 0.28;

	// terra: grão, pedrinhas claras com sombra embaixo e rachaduras escuras
	vec3 dirt = mix(dirt_dark, dirt_light, smoothstep(0.2, 0.85, h));
	float pebble_n = n(p, 0.31, vec2(0.21, 0.66));
	float pebble = smoothstep(0.74, 0.79, pebble_n);
	float pebble_shadow = smoothstep(0.68, 0.74, pebble_n) * (1.0 - pebble);
	dirt = mix(dirt, dirt_dark * 0.75, pebble_shadow * 0.6);
	dirt = mix(dirt, pebble_color * (0.85 + h * 0.3), pebble);
	float crack = smoothstep(0.2, 0.14, n(p, 1.3, vec2(0.45, 0.05)));
	dirt *= 1.0 - crack * 0.25;
	dirt *= 0.9 + n(p, 0.09, vec2(0.9, 0.3)) * 0.2;

	// bordas: irregulares (ruído de várias escalas) mas definidas
	float edge_noise = (h - 0.5) * 0.55 + (n(p, 0.6, vec2(0.33, 0.9)) - 0.5) * 0.25;
	float d = smoothstep(0.46, 0.54, m.r + edge_noise);
	vec3 col = mix(grass, dirt, d);

	vec2 cuv = p / cobble_meters;
	vec3 cobble = texture(cobble_albedo, cuv).rgb * cobble_tint;
	float c = smoothstep(0.47, 0.53, m.g + (n(p, 1.1, vec2(0.6, 0.6)) - 0.5) * 0.3);
	// faixa de terra mais escura encostada na calçada (onde a pedra encontra o chão)
	float seam = smoothstep(0.3, 0.47, m.g + (n(p, 1.1, vec2(0.6, 0.6)) - 0.5) * 0.3) * (1.0 - c);
	col *= 1.0 - seam * 0.22;
	col = mix(col, cobble, c);

	// relevo da grama e da terra a partir da altura (diferença entre vizinhos)
	float e = 0.06;
	float hx = height(p + vec2(e, 0.0)) - h;
	float hz = height(p + vec2(0.0, e)) - h;
	float strength = mix(1.6, 3.2, d);
	vec3 ground_normal = normalize(vec3(-hx * strength, -hz * strength, 1.0)) * 0.5 + 0.5;

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.9, d), 0.82, c);
	NORMAL_MAP = mix(ground_normal, texture(cobble_normal, cuv).rgb, c);
	NORMAL_MAP_DEPTH = 1.0;
}
