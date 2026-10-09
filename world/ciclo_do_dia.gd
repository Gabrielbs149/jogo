class_name CicloDoDia
extends Node
## O tempo passa (D060): o relógio do jogo (Game.hora, Game.dia) anda sozinho e a fase acompanha. O sol nasce no
## leste, sobe e se põe no oeste com sombras compridas; no poente o céu esquenta; de noite vem o céu estrelado e o
## "sol" vira lua; a neblina, a luz ambiente e o brilho mudam aos poucos; os postes acendem ao entardecer e as janelas
## das casas (de quem ainda está acordado) de noite. Fica parado nas cenas (Level.em_cena).
## Ponha como filho da fase (nó "CicloDoDia"); sem ele a fase usa o dia/noite fixo de antes (Level.noite).

signal hour_changed(hora: float)

## Minutos do jogo por segundo de verdade (1 = uma hora do jogo por minuto: um dia inteiro em 24 minutos).
@export var minutos_por_segundo: float = 1.0
## Desligado: o relógio não anda (a luz ainda segue Game.hora).
@export var rodando: bool = true

## Quanto é noite agora (0 = dia claro, 1 = noite fechada).
var noite: float = 0.0

const SUNRISE := 6.0
const SUNSET := 18.0
## Valores de noite (os mesmos da D045).
const NIGHT := {
	"ambient": Color(0.32, 0.38, 0.6), "ambient_energy": 0.32, "exposure": 1.15, "fog": Color(0.1, 0.13, 0.22),
	"fog_density": 0.0035, "fog_sky": 0.35, "vfog": 0.008, "vfog_albedo": Color(0.55, 0.6, 0.75), "glow": 0.6,
	"saturation": 0.95,
}
const MOON_COLOR := Color(0.6, 0.7, 1.0)
const MOON_ENERGY := 0.32
const SUN_DAY_COLOR := Color(1.0, 0.86, 0.68)
const SUN_LOW_COLOR := Color(1.0, 0.5, 0.25)

var _level: Level
var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _day: Dictionary = {}
var _sun_energy: float = 2.3
var _lamps: Array = []  # [OmniLight3D, energia de noite, alcance]
var _windows_on: bool = false
var _apply_left: float = 0.0
var _last_hour: float = -1.0


func _ready() -> void:
	if Level.editing:
		set_process(false)
		return
	_level = get_parent() as Level
	var env_node := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment if _level else null
	_sun = _level.get_node_or_null("Sun") as DirectionalLight3D if _level else null
	if env_node == null or _sun == null:
		set_process(false)
		return
	_env = env_node.environment.duplicate() as Environment
	env_node.environment = _env
	_day = {
		"ambient_source": _env.ambient_light_source, "ambient": _env.ambient_light_color,
		"ambient_energy": _env.ambient_light_energy, "exposure": _env.tonemap_exposure, "fog": _env.fog_light_color,
		"fog_density": _env.fog_density, "fog_sky": _env.fog_sky_affect, "vfog": _env.volumetric_fog_density,
		"vfog_albedo": _env.volumetric_fog_albedo, "glow": _env.glow_intensity, "saturation": _env.adjustment_saturation,
	}
	_sun_energy = _sun.light_energy
	# o céu: a foto de dia continua, agora num shader que também faz o poente e a noite
	var panorama: Texture2D = null
	if _env.sky and _env.sky.sky_material is PanoramaSkyMaterial:
		panorama = (_env.sky.sky_material as PanoramaSkyMaterial).panorama
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://assets/shaders/ceu_ciclo.gdshader")
	_sky_mat.set_shader_parameter("panorama", panorama)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_env.sky = sky
	_env.adjustment_enabled = true
	# postes e lanternas da rua: apagados de dia, acesos (e mais fortes) de noite
	var street := _level.get_node_or_null("Lights")
	if street:
		for found: Node in street.find_children("*", "OmniLight3D", true, false):
			var lamp := found as OmniLight3D
			_lamps.append([lamp, lamp.light_energy * 1.5, lamp.omni_range * 1.25])
	apply(true)


func _process(delta: float) -> void:
	if rodando and _level.ready_to_play and not _level.em_cena:
		Game.advance_time(delta * minutos_por_segundo / 60.0)
	_apply_left -= delta
	if _apply_left <= 0.0 or absf(Game.hora - _last_hour) > 0.25:
		_apply_left = 0.2
		apply()


## Põe a luz da hora atual (Game.hora). force: muda tudo na hora (pulo de horário numa cena).
func apply(force: bool = false) -> void:
	if _env == null:
		return
	var h := Game.hora
	if absf(h - _last_hour) < 0.001 and not force:
		return
	_last_hour = h
	# altura do sol: 0 no nascer (6h) e no pôr (18h), 1 ao meio-dia, negativo de noite
	var sun_sin := sin(PI * (h - SUNRISE) / (SUNSET - SUNRISE)) if h >= SUNRISE and h <= SUNSET else -sin(PI * fposmod(h - SUNSET, 24.0) / (24.0 - (SUNSET - SUNRISE)))
	noite = 1.0 - smoothstep(-0.26, 0.08, sun_sin)
	var poente := exp(-pow((sun_sin - 0.02) / 0.13, 2.0))
	# sol: do leste (+X) ao oeste (-X), passando pelo sul (+Z), mais alto ao meio-dia
	var t := clampf((h - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)
	var azimuth := lerpf(0.0, PI, t)  # 0 = leste, PI = oeste
	var elevation := maxf(sun_sin, 0.0) * deg_to_rad(62.0) + deg_to_rad(2.0)
	var to_sun := Vector3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation) * 0.55).normalized()
	if sun_sin > 0.0:
		_point_light(to_sun)
		_sun.light_energy = _sun_energy * smoothstep(0.0, 0.3, sun_sin)
		_sun.light_color = SUN_LOW_COLOR.lerp(SUN_DAY_COLOR, smoothstep(0.05, 0.45, sun_sin))
		_sun.shadow_opacity = 1.0
	else:
		# de noite a mesma luz é a lua: fria, fraca e alta no céu do leste
		_point_light(Vector3(0.5, 0.74, -0.45).normalized())
		_sun.light_energy = MOON_ENERGY * smoothstep(0.0, 0.18, -sun_sin)
		_sun.light_color = MOON_COLOR
	_sky_mat.set_shader_parameter("noite", noite)
	_sky_mat.set_shader_parameter("poente", poente)
	_sky_mat.set_shader_parameter("sol", to_sun if sun_sin > -0.2 else Vector3.DOWN)
	_sky_mat.set_shader_parameter("brilho_dia", lerpf(0.55, 1.0, smoothstep(0.0, 0.35, sun_sin)))
	_env.ambient_light_energy = lerpf(float(_day["ambient_energy"]), float(NIGHT["ambient_energy"]) * 1.4, noite)
	_env.tonemap_exposure = lerpf(float(_day["exposure"]), float(NIGHT["exposure"]), noite)
	_env.fog_light_color = (_day["fog"] as Color).lerp(NIGHT["fog"] as Color, noite).lerp(Color(1.0, 0.62, 0.42), poente * 0.5 * (1.0 - noite))
	_env.fog_density = lerpf(float(_day["fog_density"]), float(NIGHT["fog_density"]), noite)
	_env.fog_sky_affect = lerpf(float(_day["fog_sky"]), float(NIGHT["fog_sky"]), noite)
	_env.volumetric_fog_density = lerpf(float(_day["vfog"]), float(NIGHT["vfog"]), noite)
	_env.volumetric_fog_albedo = (_day["vfog_albedo"] as Color).lerp(NIGHT["vfog_albedo"] as Color, noite)
	_env.glow_intensity = lerpf(float(_day["glow"]), float(NIGHT["glow"]), noite)
	_env.adjustment_saturation = lerpf(float(_day["saturation"]), float(NIGHT["saturation"]), noite) + poente * 0.12
	_sun.light_volumetric_fog_energy = lerpf(1.5, 0.4, noite)
	# postes: acendem ao entardecer
	var lamp_on := smoothstep(0.15, 0.55, noite)
	for item: Array in _lamps:
		var lamp := item[0] as OmniLight3D
		if is_instance_valid(lamp):
			lamp.light_energy = float(item[1]) * lamp_on
			lamp.omni_range = float(item[2])
			lamp.visible = lamp_on > 0.01
	# janelas: acendem com a noite já caindo e apagam de manhã (com folga, para não piscar)
	if noite > 0.55 and not _windows_on:
		_windows_on = true
		_level.night_windows(true)
	elif noite < 0.35 and _windows_on:
		_windows_on = false
		_level.night_windows(false)
	hour_changed.emit(h)


func _point_light(to_light: Vector3) -> void:
	var up := Vector3.UP if absf(to_light.y) < 0.99 else Vector3.FORWARD
	_sun.global_basis = Basis.looking_at(-to_light, up)


## Pula o relógio para a hora dada (cena, "esperar o anoitecer") e põe a luz dela na hora.
func jump_to(hora: float, next_day: bool = false) -> void:
	if next_day:
		Game.dia += 1
	Game.hora = fposmod(hora, 24.0)
	apply(true)
