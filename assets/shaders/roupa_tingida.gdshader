shader_type spatial;
// Roupa de outra cor (D060): os moradores do KayKit são só 5 modelos; para a cidade não parecer de clones, cada
// pessoa troca o tom da roupa. A pele (laranja claro, pouco saturada), o cabelo escuro e os cinzas (metal) ficam
// como estão: só as cores fortes giram de matiz.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
// D063: onde é pano (branco) e onde não é (pele, cabelo, couro, metal). Gerada por tools/art/mascaras_kaykit.py.
uniform sampler2D mask_tex : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform bool use_mask = false;
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform float sat_mul = 1.0;
uniform float val_mul = 1.0;
uniform float roughness_value = 0.85;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 base = texture(albedo_tex, UV);
	vec3 hsv = rgb2hsv(base.rgb);
	// pele: matiz laranja (0,02..0,11), saturação média, clara
	float skin = (1.0 - smoothstep(0.02, 0.05, abs(hsv.x - 0.065))) * smoothstep(0.15, 0.25, hsv.y) * (1.0 - smoothstep(0.62, 0.75, hsv.y)) * smoothstep(0.45, 0.6, hsv.z);
	float colorful = smoothstep(0.18, 0.32, hsv.y) * smoothstep(0.12, 0.25, hsv.z);
	float amount = use_mask ? texture(mask_tex, UV).r : colorful * (1.0 - skin);
	vec3 shifted = hsv2rgb(vec3(fract(hsv.x + hue_shift), clamp(hsv.y * sat_mul, 0.0, 1.0), clamp(hsv.z * val_mul, 0.0, 1.0)));
	ALBEDO = mix(base.rgb, shifted, amount);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
}
