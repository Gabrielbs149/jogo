// Pós-processo da tela inteira. É ele que garante o estilo (docs/ESTILO.md):
// - tudo vira um dos 6 tons da paleta, com pontilhado (dither Bayer 4x4) entre eles;
// - escuro: só contornos fortes aparecem, mais uma luz fraca em volta do personagem;
// - negativo (a foto): os tons invertem;
// - flash, grão de filme e fade para preto.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float negative : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.0;
uniform float grain_seed = 0.0;
// Luz fraca em volta do personagem quando está escuro (em pixels da tela 320x180)
uniform vec2 light_pos = vec2(160.0, 130.0);
uniform float light_radius = 30.0;

// Paleta: Breu, Carvão, Sombra, Cinza, Névoa, Osso
const float TONES[6] = float[6](0.039, 0.137, 0.278, 0.463, 0.671, 0.91);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

// Luminância -> posição contínua na paleta (0..5). Cor exata da paleta dá número inteiro.
float tone_of(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	if (l <= TONES[0]) return 0.0;
	for (int i = 0; i < 5; i++) {
		if (l <= TONES[i + 1]) {
			return float(i) + (l - TONES[i]) / (TONES[i + 1] - TONES[i]);
		}
	}
	return 5.0;
}

int quantize(float t, vec2 p) {
	float f = floor(t);
	return int(clamp(f + ((t - f) > bayer(p) ? 1.0 : 0.0), 0.0, 5.0));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + grain_seed * 7.13) * 43758.5453);
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy);
	vec2 step_uv = SCREEN_PIXEL_SIZE;
	float t = tone_of(texture(screen_tex, SCREEN_UV).rgb);
	int lvl = quantize(t, px);
	int lit_lvl = lvl;

	// Escuro: contorno onde o tom muda muito; perto do personagem, a cena aparece apagada
	if (darkness > 0.0) {
		float tr = tone_of(texture(screen_tex, SCREEN_UV + vec2(step_uv.x, 0.0)).rgb);
		float td = tone_of(texture(screen_tex, SCREEN_UV + vec2(0.0, step_uv.y)).rgb);
		float tl = tone_of(texture(screen_tex, SCREEN_UV - vec2(step_uv.x, 0.0)).rgb);
		float tu = tone_of(texture(screen_tex, SCREEN_UV - vec2(0.0, step_uv.y)).rgb);
		float edge = max(max(abs(t - tr), abs(t - td)), max(abs(t - tl), abs(t - tu)));
		float near = clamp(1.0 - distance(px, light_pos) / light_radius, 0.0, 1.0);
		int dark_lvl = 0;
		if (near > bayer(px) * 0.9) {
			dark_lvl = max(lvl - 2, edge >= 1.5 ? 3 : 0);
		} else if (edge >= 2.0) {
			dark_lvl = 2;
		}
		if (darkness > bayer(px)) {
			lvl = dark_lvl;
		}
	}

	// A foto: o flash ilumina tudo, então o negativo é da cena acesa, não do escuro
	if (negative > bayer(px)) {
		lvl = 5 - lit_lvl;
	}

	if (grain > 0.0 && hash(px) < grain * 0.012) {
		lvl = lvl >= 3 ? lvl - 1 : lvl + 1;
	}

	if (flash > bayer(px)) {
		lvl = 5;
	}
	if (fade > bayer(px)) {
		lvl = 0;
	}

	float g = TONES[lvl];
	COLOR = vec4(g, g, g, 1.0);
}
