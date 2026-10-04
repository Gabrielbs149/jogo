// Grade de protótipo em coordenadas do mundo: 1 quadrado = 1 metro em qualquer bloco,
// sem precisar de textura nem UV. Serve para sentir velocidade e distância no greybox.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.55, 0.58, 0.62);
uniform vec3 line_color : source_color = vec3(0.38, 0.41, 0.45);
uniform float cell_size = 1.0;
uniform float line_width : hint_range(0.0, 0.2) = 0.025;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 cell = world_pos / cell_size;
	vec3 to_line = abs(fract(cell - 0.5) - 0.5);
	vec3 n = abs(world_normal);
	// Usa só os dois eixos que correm ao longo da face.
	float d;
	if (n.y >= n.x && n.y >= n.z) {
		d = min(to_line.x, to_line.z);
	} else if (n.x >= n.z) {
		d = min(to_line.y, to_line.z);
	} else {
		d = min(to_line.x, to_line.y);
	}
	float aa = fwidth(d) * 1.5;
	float line = 1.0 - smoothstep(line_width, line_width + aa, d);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.85;
}
