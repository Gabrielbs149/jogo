shader_type spatial;
// Grade do editor de mapas (D042): linhas no mundo a cada `celula` metros, linha forte a cada 4 células,
// some devagar longe do mouse. Desenhada por cima de tudo (chão com dunas não esconde a grade).
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix, shadows_disabled;

uniform float celula = 1.0;
uniform vec4 cor : source_color = vec4(1.0, 0.95, 0.8, 0.16);
uniform vec4 cor_forte : source_color = vec4(1.0, 0.82, 0.45, 0.42);
uniform vec2 centro = vec2(0.0);
uniform float raio = 22.0;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float linha(vec2 p) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	float fina = linha(mundo.xz / celula);
	float forte = linha(mundo.xz / (celula * 4.0));
	float sumir = 1.0 - smoothstep(raio * 0.35, raio, length(mundo.xz - centro));
	ALBEDO = mix(cor.rgb, cor_forte.rgb, forte);
	ALPHA = max(fina * cor.a, forte * cor_forte.a) * sumir;
}
