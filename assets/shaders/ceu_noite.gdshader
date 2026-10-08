shader_type sky;
// Céu de noite (D045): degradê azul-escuro, estrelas e a lua no lugar da primeira luz direcional (o "sol" vira lua).

uniform vec3 top_color : source_color = vec3(0.012, 0.02, 0.055);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.1, 0.19);
uniform vec3 ground_color : source_color = vec3(0.02, 0.025, 0.035);
uniform float star_density : hint_range(0.0, 0.05) = 0.012;
uniform float star_scale = 180.0;
uniform vec3 moon_color : source_color = vec3(0.92, 0.95, 1.0);

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, h));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.15, -h));
	}
	if (h > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 p = d * star_scale;
		vec3 cell = floor(p);
		float r = hash(cell);
		if (r > 1.0 - star_density) {
			float dist = length(fract(p) - 0.5);
			float shine = hash(cell + 7.0) * 0.8 + 0.4;
			col += vec3(0.85, 0.9, 1.0) * smoothstep(0.14, 0.0, dist) * shine * 2.5 * smoothstep(0.03, 0.3, h);
		}
	}
	if (LIGHT0_ENABLED) {
		float m = dot(d, LIGHT0_DIRECTION);
		col += moon_color * smoothstep(0.99955, 0.99975, m) * 4.0;
		col += vec3(0.22, 0.28, 0.45) * pow(max(m, 0.0), 40.0) * 0.5;
	}
	COLOR = col;
}
