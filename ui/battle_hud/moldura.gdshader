shader_type canvas_item;
// Moldura da luta (D047, visual do Look Outside): a cena aparece numa janela de cantos arredondados, com um filete
// e escurecida nas bordas; fora da janela, fundo escuro (onde ficam o menu, a caixa de texto e o retrato).

uniform vec4 frame_color : source_color = vec4(0.055, 0.04, 0.07, 1.0);
uniform vec4 line_color : source_color = vec4(0.55, 0.24, 0.3, 1.0);
// janela da cena: x0, y0, x1, y1 (fração da tela)
uniform vec4 window = vec4(0.03, 0.03, 0.97, 0.705);
uniform float radius = 0.014;
uniform float line_px = 3.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = UV * res;
	vec2 a = window.xy * res;
	vec2 b = window.zw * res;
	vec2 c = (a + b) * 0.5;
	vec2 h = (b - a) * 0.5;
	float r = radius * res.y;
	vec2 q = abs(px - c) - h + r;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	vec4 col;
	if (d > line_px) {
		col = frame_color;
	} else if (d > 0.0) {
		col = line_color;
	} else {
		// dentro: só escurece perto da borda (o olho vai para o meio, onde está o inimigo)
		vec2 n = (px - c) / h;
		float v = smoothstep(0.45, 1.15, length(n * vec2(0.85, 1.0)));
		col = vec4(0.0, 0.0, 0.0, v * vignette);
	}
	COLOR = col;
}
