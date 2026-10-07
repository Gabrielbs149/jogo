class_name OptionsMenu
extends Control
## Tela de Opções (D038), aberta pela tela inicial e pela pausa: volumes, tela, câmera e a lista de teclas.
## Cada mudança vale na hora e fica gravada (autoload Settings). Esc ou "Voltar" fecha.

signal closed

## Teclas do jogo: [teclas, o que fazem]. Uma lista por grupo.
const KEYS_MAP: Array = [
	[["W", "A", "S", "D"], "andar"],
	[["Shift"], "correr"],
	[["Mouse"], "olhar em volta (a roda aproxima e afasta)"],
	[["Botão esq."], "golpe: acertar um inimigo antes começa a luta com vantagem"],
	[["Espaço"], "esquivar"],
	[["F"], "conversar, ler, descansar na fogueira, viajar"],
	[["Esc"], "pausa"],
	[["F2"], "editor de mapas"],
]
const KEYS_FIGHT: Array = [
	[["1"], "atacar"],
	[["Q", "E", "R"], "habilidades"],
	[["A", "D"], "trocar o alvo"],
	[["Espaço"], "no anel do golpe: golpe perfeito · no anel de defesa: esquiva"],
	[["F"], "no anel de defesa: aparar"],
]

@onready var _sound: VBoxContainer = %Som
@onready var _view: VBoxContainer = %Imagem
@onready var _keys: VBoxContainer = %Teclas


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_slider(_sound, "Volume geral", "volume_geral")
	_slider(_sound, "Música", "volume_musica")
	_slider(_sound, "Efeitos", "volume_efeitos")
	_slider(_sound, "Ambiente (vento, fogo)", "volume_ambiente")
	_toggle(_view, "Tela cheia", "tela_cheia")
	_toggle(_view, "Sincronia vertical (V-Sync)", "vsync")
	_slider(_view, "Sensibilidade do mouse", "sensibilidade", 0.3, 2.0)
	_toggle(_view, "Inverter o mouse para cima e para baixo", "inverter_y")
	_toggle(_view, "Mostrar dicas de controle na tela", "dicas")
	_key_group("No mapa", KEYS_MAP)
	_key_group("Na luta", KEYS_FIGHT)
	%Back.pressed.connect(close)
	%Defaults.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_refresh())
	visibility_changed.connect(func() -> void:
		if visible:
			(%Back as Button).grab_focus())


func open() -> void:
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _row(parent: Container, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(320, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	parent.add_child(row)
	return row


func _slider(parent: Container, text: String, key: String, low: float = 0.0, high: float = 1.0) -> void:
	var row := _row(parent, text)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(260, 28)
	slider.set_meta("chave", key)
	var number := Label.new()
	number.custom_minimum_size = Vector2(56, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		number.text = ("%d%%" % roundi(v * 100.0)) if high <= 1.0 else ("%.1f×" % v)
		if not is_equal_approx(float(Settings.value(key)), v):
			Settings.set_value(key, v))
	row.add_child(slider)
	row.add_child(number)


func _toggle(parent: Container, text: String, key: String) -> void:
	var row := _row(parent, text)
	var check := CheckButton.new()
	check.set_meta("chave", key)
	check.toggled.connect(func(on: bool) -> void:
		if bool(Settings.value(key)) != on:
			Settings.set_value(key, on))
	row.add_child(check)


func _key_group(title: String, keys: Array) -> void:
	var header := Label.new()
	header.text = title
	header.theme_type_variation = &"TitleLabel"
	header.add_theme_font_size_override("font_size", 20)
	_keys.add_child(header)
	for entry: Array in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var caps := HBoxContainer.new()
		caps.add_theme_constant_override("separation", 4)
		caps.custom_minimum_size = Vector2(170, 0)
		for key: String in entry[0]:
			caps.add_child(keycap(key))
		row.add_child(caps)
		var what := Label.new()
		what.text = entry[1]
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		_keys.add_child(row)


## Uma tecla desenhada (para usar em qualquer tela).
static func keycap(key: String) -> Label:
	var cap := Label.new()
	cap.text = key
	cap.theme_type_variation = &"Keycap"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.custom_minimum_size = Vector2(26, 0)
	return cap


func _refresh() -> void:
	for node: Node in find_children("*", "Range", true, false) + find_children("*", "CheckButton", true, false):
		if not node.has_meta("chave"):
			continue
		var key: String = node.get_meta("chave")
		if node is Range:
			(node as Range).value = float(Settings.value(key))
			(node as Range).value_changed.emit((node as Range).value)
		elif node is CheckButton:
			(node as CheckButton).set_pressed_no_signal(bool(Settings.value(key)))
