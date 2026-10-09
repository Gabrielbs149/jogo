shader_type sky;
// Céu do ciclo do dia (D060): o céu de dia (a mesma foto HDR de antes), o pôr do sol (laranja no horizonte, do lado
// do sol) e a noite (degradê azul-escuro, estrelas e a lua) se misturam aos poucos. Quem mexe é world/ciclo_do_dia.gd.

uniform sampler2D panorama : source_color, filter_linear, hint_default_black;
// 0 = dia, 1 = noite
uniform float noite : hint_range(0.0, 1.0) = 0.0;
// 0..1: quanto de pôr/nascer do sol (cor quente perto do horizonte)
uniform float poente : hint_range(0.0, 1.0) = 0.0;
// onde está o sol (vetor do chão para o sol), para o brilho quente ficar do lado certo
uniform vec3 sol = vec3(0.0, 1.0, 0.0);
uniform float brilho_dia = 1.0;

uniform vec3 top_color : source_color = vec3(0.012, 0.02, 0.055);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.1, 0.19);
uniform vec3 ground_color : source_color = vec3(0.02, 0.025, 0.035);
uniform float star_density : hint_range(0.0, 0.05) = 0.012;
uniform float star_scale = 180.0;
uniform vec3 moon_color : source_color = vec3(0.92, 0.95, 1.0);

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

vec3 night_sky(vec3 d) {
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
			float twinkle = 0.75 + 0.25 * sin(TIME * (1.5 + r * 3.0) + r * 40.0);
			col += vec3(0.85, 0.9, 1.0) * smoothstep(0.14, 0.0, dist) * shine * twinkle * 2.5 * smoothstep(0.03, 0.3, h);
		}
	}
	if (LIGHT0_ENABLED) {
		float m = dot(d, LIGHT0_DIRECTION);
		col += moon_color * smoothstep(0.99955, 0.99975, m) * 4.0;
		col += vec3(0.22, 0.28, 0.45) * pow(max(m, 0.0), 40.0) * 0.5;
	}
	return col;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 day = texture(panorama, SKY_COORDS).rgb * brilho_dia;
	// pôr do sol: o céu perto do horizonte esquenta, mais do lado do sol; o resto do céu escurece um pouco
	float horizon = 1.0 - smoothstep(0.0, 0.45, abs(d.y));
	vec2 sh = sol.xz;
	vec2 sn = length(sh) > 0.001 ? normalize(sh) : vec2(1.0, 0.0);
	vec2 dh = d.xz;
	vec2 dn = length(dh) > 0.001 ? normalize(dh) : vec2(0.0);
	float toward = max(dot(dn, sn), 0.0);
	vec3 warm = mix(vec3(1.0, 0.45, 0.2), vec3(1.0, 0.72, 0.42), smoothstep(0.0, 0.3, d.y));
	vec3 dusk = mix(day * vec3(0.55, 0.5, 0.62), warm * (0.6 + 1.6 * pow(toward, 3.0)), horizon * (0.45 + 0.55 * toward));
	day = mix(day, dusk, poente);
	// o disco do sol, baixo e laranja no poente
	float s = dot(d, normalize(sol));
	day += vec3(1.0, 0.6, 0.3) * smoothstep(0.9993, 0.9997, s) * 6.0 * poente * step(0.0, sol.y + 0.05);
	COLOR = mix(day, night_sky(d), noite);
}
