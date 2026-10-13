extends Node
## Opções do jogador (autoload "Settings", D038; completas na D074): vídeo, gráficos, áudio, controles (teclas que dá
## para trocar e controle de videogame), jogo e acessibilidade. Ficam em user://opcoes.cfg e valem na hora em que mudam.
## A tela de Opções é ui/options/options_menu.tscn.
## O que depende da cena (luzes, ambiente, câmera) é aplicado em cada nó que entra na árvore (node_added).

signal changed

const SECTION := "opcoes"
const KEYS_SECTION := "teclas"
const DEFAULTS := {
	# vídeo
	"modo_tela": 0,  # 0 janela, 1 tela cheia (sem borda), 2 tela cheia exclusiva
	"resolucao": "1600x900",  # tamanho da janela (no modo janela)
	"vsync": true,
	"limite_fps": 0,  # 0 = sem limite
	"escala_render": 1.0,  # 0,5..1: menos que 1 desenha menor e amplia (FSR), mais leve
	"brilho": 1.0,
	"campo_visao": 68.0,
	# gráficos
	"qualidade": 2,  # 0 baixa, 1 média, 2 alta, 3 ultra, 4 personalizada
	"sombras": 2,  # 0 desligadas, 1 baixas, 2 médias, 3 altas
	"antisserrilhado": 3,  # 0 desligado, 1 FXAA, 2 MSAA 2x, 3 MSAA 4x, 4 TAA
	"oclusao": true,  # oclusão de ambiente (SSAO), onde a fase usa
	"brilho_luzes": true,  # "glow" das luzes, onde a fase usa
	"nevoa": true,  # névoa volumétrica, onde a fase usa
	"detalhe": 2,  # 0 baixo, 1 médio, 2 alto, 3 ultra (simplificação dos modelos de longe)
	# áudio
	"volume_geral": 1.0,
	"volume_musica": 0.8,
	"volume_efeitos": 1.0,
	"volume_ambiente": 0.8,
	"som_sem_foco": true,  # falso = fica mudo quando a janela perde o foco
	# controles
	"sensibilidade": 1.0,
	"inverter_y": false,
	"inverter_x": false,
	"sensibilidade_controle": 1.0,
	"zona_morta": 0.2,
	# jogo
	"dicas": true,
	"distancia_camera": 4.6,
	"tremor": 1.0,
	"velocidade_texto": 1.0,
	"mostrar_fps": false,
	# acessibilidade
	"tamanho_interface": 1.0,
	"tempo_qte": 1.0,
}
## Canal de áudio de cada volume.
const BUSES := {"volume_geral": &"Master", "volume_musica": &"Musica", "volume_efeitos": &"Efeitos", "volume_ambiente": &"Ambiente"}
## Predefinições de qualidade (D074): "alta" é o visual do jogo como foi feito.
const PRESETS := [
	{"sombras": 1, "antisserrilhado": 1, "oclusao": false, "brilho_luzes": false, "nevoa": false, "detalhe": 0, "escala_render": 0.75},
	{"sombras": 1, "antisserrilhado": 1, "oclusao": false, "brilho_luzes": true, "nevoa": true, "detalhe": 1, "escala_render": 1.0},
	{"sombras": 2, "antisserrilhado": 3, "oclusao": true, "brilho_luzes": true, "nevoa": true, "detalhe": 2, "escala_render": 1.0},
	{"sombras": 3, "antisserrilhado": 4, "oclusao": true, "brilho_luzes": true, "nevoa": true, "detalhe": 3, "escala_render": 1.0},
]
const GRAPHICS := ["sombras", "antisserrilhado", "oclusao", "brilho_luzes", "nevoa", "detalhe", "escala_render"]
const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const FPS_LIMITS := [30, 60, 120, 144, 165, 240, 0]
## Ações que dá para trocar a tecla: [ação, nome na tela, grupo].
const REBINDABLE := [
	[&"move_forward", "Andar para a frente", "Movimento"], [&"move_back", "Andar para trás", "Movimento"],
	[&"move_left", "Andar para a esquerda", "Movimento"], [&"move_right", "Andar para a direita", "Movimento"],
	[&"sprint", "Correr (segurar)", "Movimento"], [&"sneak", "Agachar (andar sem ser visto)", "Movimento"],
	[&"dodge", "Esquivar", "Movimento"],
	[&"attack", "Golpe", "Ações"], [&"interact", "Conversar, ler, usar", "Ações"], [&"pause", "Pausa", "Ações"],
	[&"battle_attack", "Atacar (na luta)", "Luta"], [&"skill_q", "Habilidade 1", "Luta"], [&"skill_e", "Habilidade 2", "Luta"],
	[&"skill_r", "Habilidade 3", "Luta"], [&"parry", "Aparar (no anel de defesa)", "Luta"],
]
## Controle de videogame (layout Xbox; D074): [ação, botão] ou [ação, eixo, direção]. Entra junto com o teclado.
const JOYPAD := [
	[&"move_left", JOY_AXIS_LEFT_X, -1.0], [&"move_right", JOY_AXIS_LEFT_X, 1.0],
	[&"move_forward", JOY_AXIS_LEFT_Y, -1.0], [&"move_back", JOY_AXIS_LEFT_Y, 1.0],
	[&"look_left", JOY_AXIS_RIGHT_X, -1.0], [&"look_right", JOY_AXIS_RIGHT_X, 1.0],
	[&"look_up", JOY_AXIS_RIGHT_Y, -1.0], [&"look_down", JOY_AXIS_RIGHT_Y, 1.0],
	[&"sprint", JOY_BUTTON_LEFT_STICK], [&"sprint", JOY_AXIS_TRIGGER_LEFT, 1.0],
	[&"attack", JOY_BUTTON_X], [&"attack", JOY_AXIS_TRIGGER_RIGHT, 1.0],
	[&"interact", JOY_BUTTON_A], [&"dodge", JOY_BUTTON_B], [&"sneak", JOY_BUTTON_RIGHT_STICK],
	[&"pause", JOY_BUTTON_START], [&"battle_attack", JOY_BUTTON_X],
	[&"skill_q", JOY_BUTTON_LEFT_SHOULDER], [&"skill_e", JOY_BUTTON_RIGHT_SHOULDER], [&"skill_r", JOY_BUTTON_Y],
	[&"parry", JOY_BUTTON_RIGHT_SHOULDER],
]

## Arquivo das opções (os testes trocam por outro).
var path: String = "user://opcoes.cfg"
var _values: Dictionary = DEFAULTS.duplicate()
## Tecla trocada pelo jogador: ação -> "k:<código físico>" ou "m:<botão do mouse>".
var _keys: Dictionary = {}
## Volume de cada canal no default_bus_layout (o 100% de cada barra).
var _base_db: Dictionary = {}
## A tecla de fábrica de cada ação que dá para trocar (o primeiro evento de teclado/mouse dela).
var _default_events: Dictionary = {}
var _gamma: CanvasLayer
var _gamma_rect: ColorRect
var _fps: CanvasLayer
var _fps_label: Label
var _fps_wait: float = 0.0
var _focused: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_args():
		if arg.contains("gut_cmdln"):
			path = "user://opcoes_testes.cfg"
	for key: String in BUSES:
		var bus := AudioServer.get_bus_index(BUSES[key])
		_base_db[key] = AudioServer.get_bus_volume_db(bus) if bus >= 0 else 0.0
	_setup_input()
	_build_overlays()
	load_file()
	get_tree().node_added.connect(_on_node_added)


func value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


## Muda uma opção, aplica e grava. Mexer num item de gráfico vira a qualidade "personalizada"; escolher uma qualidade
## põe os itens dela.
func set_value(key: String, v: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: opção desconhecida %s" % key)
		return
	_values[key] = v
	if key == "qualidade" and int(v) < PRESETS.size():
		var preset: Dictionary = PRESETS[int(v)]
		for item: String in preset:
			_values[item] = preset[item]
			_apply(item)
	elif GRAPHICS.has(key):
		_values["qualidade"] = _matching_preset()
	_apply(key)
	save_file()
	changed.emit()


func reset_defaults() -> void:
	_values = DEFAULTS.duplicate()
	_keys.clear()
	_apply_keys()
	for key: String in _values:
		_apply(key)
	save_file()
	changed.emit()


## Quanto o mouse gira a câmera (multiplica a sensibilidade da câmera).
func mouse_factor() -> float:
	return float(value("sensibilidade"))


# --- teclas -------------------------------------------------------------------------------------------------------

## Troca a tecla (teclado ou botão do mouse) de uma ação. Devolve a outra ação que já usava essa tecla (no mesmo
## grupo), ou "" — quem chama avisa; as duas ficam com a tecla até o jogador trocar a outra.
func rebind(action: StringName, event: InputEvent) -> String:
	var code := _encode(event)
	if code == "":
		return ""
	_keys[String(action)] = code
	_apply_keys()
	save_file()
	changed.emit()
	var group := _group_of(action)
	for entry: Array in REBINDABLE:
		if entry[0] != action and String(entry[2]) == group and _key_event(entry[0]) != null \
				and _encode(_key_event(entry[0])) == code:
			return String(entry[1])
	return ""


## O nome da tecla de teclado/mouse da ação agora ("Shift", "Botão esq.", "F"...).
func key_name(action: StringName) -> String:
	var event := _key_event(action)
	if event == null:
		return "—"
	return event_name(event)


static func event_name(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Botão esq.", MOUSE_BUTTON_RIGHT: "Botão dir.", MOUSE_BUTTON_MIDDLE: "Botão do meio",
			MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}.get((event as InputEventMouseButton).button_index, "Mouse")
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var names := {KEY_SPACE: "Espaço", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_ESCAPE: "Esc",
			KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter", KEY_TAB: "Tab", KEY_BACKSPACE: "Apagar", KEY_UP: "↑", KEY_DOWN: "↓",
			KEY_LEFT: "←", KEY_RIGHT: "→", KEY_CAPSLOCK: "Caps"}
		if names.has(code):
			return names[code]
		# a tecla física vira a letra do teclado do jogador (ABNT, AZERTY...); sem janela (testes) fica a física
		if key.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	return "?"


## O primeiro evento de teclado ou mouse da ação (o que aparece e o que se troca).
func _key_event(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event
	return null


func _group_of(action: StringName) -> String:
	for entry: Array in REBINDABLE:
		if entry[0] == action:
			return String(entry[2])
	return ""


static func _encode(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return "m:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventKey:
		var key := event as InputEventKey
		return "k:%d" % (key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	return ""


static func _decode(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "m":
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(parts[1]) as MouseButton
		mouse.pressed = true
		return mouse
	var key := InputEventKey.new()
	key.physical_keycode = int(parts[1]) as Key
	return key


## Guarda as teclas de fábrica, cria as ações da câmera pelo controle e põe o controle de videogame nas ações.
func _setup_input() -> void:
	for entry: Array in REBINDABLE:
		_default_events[entry[0]] = _key_event(entry[0])
	for action: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
	for entry: Array in JOYPAD:
		var action: StringName = entry[0]
		if not InputMap.has_action(action):
			continue
		var event: InputEvent
		if entry.size() == 3:
			var motion := InputEventJoypadMotion.new()
			motion.axis = entry[1] as JoyAxis
			motion.axis_value = float(entry[2])
			event = motion
		else:
			var button := InputEventJoypadButton.new()
			button.button_index = entry[1] as JoyButton
			event = button
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


## Põe as teclas trocadas pelo jogador (e volta as de fábrica nas outras).
func _apply_keys() -> void:
	for entry: Array in REBINDABLE:
		var action: StringName = entry[0]
		if not InputMap.has_action(action):
			continue
		var now := _key_event(action)
		var want: InputEvent = _decode(String(_keys[String(action)])) if _keys.has(String(action)) else _default_events.get(action)
		if now != null:
			InputMap.action_erase_event(action, now)
		if want != null:
			# a tecla nova fica em primeiro (é a que aparece nas dicas)
			var rest := InputMap.action_get_events(action)
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, want)
			for event: InputEvent in rest:
				InputMap.action_add_event(action, event)


# --- arquivo ------------------------------------------------------------------------------------------------------

func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for key: String in DEFAULTS:
			var v: Variant = cfg.get_value(SECTION, key, DEFAULTS[key])
			if typeof(v) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and v is int):
				_values[key] = v
		# opções de antes da D074
		if cfg.has_section_key(SECTION, "tela_cheia") and not cfg.has_section_key(SECTION, "modo_tela"):
			_values["modo_tela"] = 1 if bool(cfg.get_value(SECTION, "tela_cheia")) else 0
		if cfg.has_section(KEYS_SECTION):
			for action: String in cfg.get_section_keys(KEYS_SECTION):
				_keys[action] = String(cfg.get_value(KEYS_SECTION, action))
	_apply_keys()
	for key: String in _values:
		_apply(key)


func save_file() -> void:
	var cfg := ConfigFile.new()
	for key: String in _values:
		cfg.set_value(SECTION, key, _values[key])
	for action: String in _keys:
		cfg.set_value(KEYS_SECTION, action, _keys[action])
	cfg.save(path)


func _matching_preset() -> int:
	for i: int in PRESETS.size():
		var same := true
		for item: String in PRESETS[i]:
			if not is_equal_approx(float(_values[item]), float(PRESETS[i][item])):
				same = false
				break
		if same:
			return i
	return 4


# --- aplicar ------------------------------------------------------------------------------------------------------

func _apply(key: String) -> void:
	if BUSES.has(key):
		_apply_volume(key)
		return
	match key:
		"zona_morta":
			for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"look_left", &"look_right",
					&"look_up", &"look_down"]:
				if InputMap.has_action(action):
					InputMap.action_set_deadzone(action, clampf(float(_values[key]), 0.05, 0.9))
		"limite_fps":
			Engine.max_fps = int(_values[key])
		"mostrar_fps":
			if _fps:
				_fps.visible = bool(_values[key])
		"brilho":
			if _gamma_rect:
				var gamma := float(_values[key])
				(_gamma_rect.material as ShaderMaterial).set_shader_parameter("brilho", gamma)
				_gamma.visible = not is_equal_approx(gamma, 1.0)
	if DisplayServer.get_name() == "headless":
		return
	var root := get_tree().root
	match key:
		"modo_tela", "resolucao":
			_apply_window()
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _values[key] else DisplayServer.VSYNC_DISABLED)
		"escala_render":
			var scale := clampf(float(_values[key]), 0.5, 1.0)
			root.scaling_3d_scale = scale
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if scale >= 0.999 else Viewport.SCALING_3D_MODE_FSR
		"antisserrilhado":
			var aa := int(_values[key])
			root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED][aa]
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_taa = aa == 4
		"detalhe":
			root.mesh_lod_threshold = [6.0, 3.0, 1.0, 0.5][clampi(int(_values[key]), 0, 3)]
		"sombras":
			var level := clampi(int(_values[key]), 0, 3)
			var size: int = [1024, 2048, 4096, 8192][level]
			RenderingServer.directional_shadow_atlas_set_size(size, true)
			RenderingServer.directional_soft_shadow_filter_set_quality([0, 1, 2, 3][level] as RenderingServer.ShadowQuality)
			RenderingServer.positional_soft_shadow_filter_set_quality([0, 1, 2, 3][level] as RenderingServer.ShadowQuality)
			root.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][level]
			for light: Node in root.find_children("*", "Light3D", true, false):
				_light(light as Light3D)
		"oclusao", "brilho_luzes", "nevoa":
			for env: Node in root.find_children("*", "WorldEnvironment", true, false):
				_environment(env as WorldEnvironment)
		"campo_visao", "distancia_camera":
			for cam: Node in root.find_children("*", "", true, false):
				if _is_game_camera(cam):
					_camera(cam)
		"tamanho_interface":
			root.content_scale_factor = clampf(float(_values[key]), 0.7, 1.5)


func _apply_volume(key: String) -> void:
	var bus := AudioServer.get_bus_index(BUSES[key])
	if bus < 0:
		return
	var v := clampf(float(_values[key]), 0.0, 1.0)
	var muted := v <= 0.001 or (key == "volume_geral" and not _focused and not bool(_values["som_sem_foco"]))
	AudioServer.set_bus_mute(bus, muted)
	AudioServer.set_bus_volume_db(bus, float(_base_db.get(key, 0.0)) + linear_to_db(maxf(v, 0.001)))


func _apply_window() -> void:
	var mode := int(_values["modo_tela"])
	if mode == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var parts := String(_values["resolucao"]).split("x")
		if parts.size() == 2:
			var size := Vector2i(int(parts[0]), int(parts[1]))
			var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode == 1 else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


## O que depende da cena: cada luz, ambiente e câmera que entra na árvore já recebe as opções.
func _on_node_added(node: Node) -> void:
	if node is Light3D:
		_light.call_deferred(node)
	elif node is WorldEnvironment:
		_environment.call_deferred(node)
	elif _is_game_camera(node):
		_camera.call_deferred(node)


## No editor de mapas (F2) nada da cena muda: o editor grava a fase como ela está.
static func _editing() -> bool:
	return bool((load("res://world/level.gd") as Script).get("editing"))


static func _is_game_camera(node: Node) -> bool:
	var script := node.get_script() as Script
	return script != null and script.resource_path.ends_with("third_person_camera.gd")


func _light(light: Light3D) -> void:
	if not is_instance_valid(light) or _editing():
		return
	if not light.has_meta("sombra_da_fase"):
		light.set_meta("sombra_da_fase", light.shadow_enabled)
	light.shadow_enabled = bool(light.get_meta("sombra_da_fase")) and int(_values["sombras"]) > 0


## Oclusão, brilho das luzes e névoa: só desligam o que a fase liga (nunca ligam o que a fase não usa).
func _environment(node: WorldEnvironment) -> void:
	if not is_instance_valid(node) or node.environment == null or _editing():
		return
	var env := node.environment
	if not node.has_meta("da_fase"):
		node.set_meta("da_fase", {"ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "glow": env.glow_enabled,
			"vfog": env.volumetric_fog_enabled})
	var base: Dictionary = node.get_meta("da_fase")
	env.ssao_enabled = bool(base["ssao"]) and bool(_values["oclusao"])
	env.ssil_enabled = bool(base["ssil"]) and bool(_values["oclusao"])
	env.glow_enabled = bool(base["glow"]) and bool(_values["brilho_luzes"])
	env.volumetric_fog_enabled = bool(base["vfog"]) and bool(_values["nevoa"])


func _camera(cam: Node) -> void:
	if not is_instance_valid(cam) or _editing():
		return
	cam.set("distance", clampf(float(_values["distancia_camera"]), float(cam.get("min_distance")), float(cam.get("max_distance"))))
	var lens := cam.get_node_or_null("Arm/Camera3D") as Camera3D
	if lens:
		lens.fov = clampf(float(_values["campo_visao"]), 50.0, 100.0)


# --- brilho e contador de quadros (por cima de tudo) ----------------------------------------------------------------

func _build_overlays() -> void:
	_gamma = CanvasLayer.new()
	_gamma.layer = 120
	_gamma.visible = false
	add_child(_gamma)
	_gamma_rect = ColorRect.new()
	_gamma_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gamma_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear;
uniform float brilho = 1.0;
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	COLOR = vec4(pow(c, vec3(1.0 / brilho)), 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_gamma_rect.material = material
	_gamma.add_child(_gamma_rect)
	_fps = CanvasLayer.new()
	_fps.layer = 121
	_fps.visible = false
	add_child(_fps)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 8)
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps.add_child(_fps_label)


func _process(delta: float) -> void:
	if _fps and _fps.visible:
		_fps_wait -= delta
		if _fps_wait <= 0.0:
			_fps_wait = 0.5
			_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		if _values.has("volume_geral"):
			_apply_volume("volume_geral")
