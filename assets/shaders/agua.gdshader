shader_type spatial;
// Água parada (bacias, chafariz, poços): azul-esverdeada, com ondinhas que andam e reflexo do céu (D041).
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 raso : source_color = vec3(0.32, 0.62, 0.66);
uniform vec3 fundo : source_color = vec3(0.08, 0.26, 0.32);
uniform float transparencia : hint_range(0.0, 1.0) = 0.82;
uniform sampler2D ondas : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float escala = 0.6;
uniform float velocidade = 0.04;
uniform float forca_ondas : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * escala;
	vec3 n1 = texture(ondas, p + vec2(TIME * velocidade, TIME * velocidade * 0.6)).rgb;
	vec3 n2 = texture(ondas, p * 1.7 - vec2(TIME * velocidade * 0.8, TIME * velocidade * 0.3)).rgb;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), normalize(n1 + n2 - 1.0) * 0.5 + 0.5, forca_ondas);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(fundo, raso, 0.5 + 0.5 * fresnel);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = mix(transparencia, 1.0, fresnel);
}
