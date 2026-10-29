class_name OptionsMenu
extends Control
## Tela de Opções (D038; completa na D074), aberta pela tela inicial e pela pausa. Abas: Vídeo, Gráficos, Áudio,
## Controles (trocar teclas, controle de videogame), Jogo e Acessibilidade. Cada mudança vale na hora e fica gravada
## (autoload Settings). Esc ou "Voltar" fecha.

signal closed

const QUALITY := ["Baixa", "Média", "Alta", "Ultra", "Personalizada"]
const SHADOWS := ["Desligadas", "Baixas", "Médias", "Altas"]
const AA := ["Desligado", "FXAA (leve)", "MSAA 2x", "MSAA 4x", "TAA (suave)"]
const DETAIL := ["Baixo", "Médio", "Alto", "Ultra"]
const SCREEN := ["Janela", "Tela cheia", "Tela cheia exclusiva"]
const DIFFICULTY := ["Fácil", "Normal", "Difícil"]
## Controle de videogame (layout Xbox; Settings.JOYPAD): [botões, o que fazem].
const PAD: Array = [
	[["Analógico esq."], "andar (aperte para correr)"],
	[["Analógico dir."], "câmera (aperte para agachar)"],
	[["A"], "conversar, ler, usar"],
	[["B"], "esquivar"],
	[["X", "RT"], "golpe · na luta: atacar"],
	[["LB", "RB", "Y"], "habilidades na luta (RB também apara)"],
	[["LT"], "correr"],
	[["Start"], "pausa"],
]

var _tabs: TabContainer
var _waiting: StringName = &""
var _waiting_button: Button
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tabs = %Tabs as TabContainer
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	_build_video()
	_build_graphics()
	_build_audio()
	_build_controls()
	_build_game()
	_build_access()
	%Back.pressed.connect(close)
	%Defaults.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_refresh())
	Settings.changed.connect(_refresh)
	visibility_changed.connect(func() -> void:
		if visible:
			(%Back as Button).grab_focus())


func open() -> void:
	_refresh()
	show()


func close() -> void:
	_cancel_wait()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _waiting == &"" and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Esperando a tecla nova de uma ação: a próxima tecla ou botão do mouse vira a tecla dela (Esc cancela).
func _input(event: InputEvent) -> void:
	if _waiting == &"" or not visible:
		return
	var pressed := (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN])
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_cancel_wait()
		return
	var action := _waiting
	_waiting = &""
	var clash := Settings.rebind(action, event)
	_status.text = ("Atenção: essa tecla também é de \"%s\"." % clash) if clash != "" else ""
	_refresh()


func _cancel_wait() -> void:
	_waiting = &""
	if _status:
		_status.text = ""
	_refresh()


# --- abas ---------------------------------------------------------------------------------------------------------

func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	return box


func _build_video() -> void:
	var box := _tab("Vídeo")
	_choice(box, "Modo da tela", "modo_tela", SCREEN, [0, 1, 2])
	_choice(box, "Tamanho da janela", "resolucao", Settings.RESOLUTIONS, Settings.RESOLUTIONS)
	_toggle(box, "Sincronia vertical (V-Sync)", "vsync")
	var fps: Array[String] = []
	for limit: int in Settings.FPS_LIMITS:
		fps.append("%d quadros/s" % limit if limit > 0 else "Sem limite")
	_choice(box, "Limite de quadros por segundo", "limite_fps", fps, Settings.FPS_LIMITS)
	_slider(box, "Brilho", "brilho", 0.6, 1.5, 0.05, "x")
	_slider(box, "Campo de visão", "campo_visao", 55.0, 95.0, 1.0, "graus")


func _build_graphics() -> void:
	var box := _tab("Gráficos")
	_choice(box, "Qualidade", "qualidade", QUALITY, [0, 1, 2, 3, 4])
	_note(box, "Escolher uma qualidade ajusta tudo abaixo; mexer em um item vira \"Personalizada\".")
	_choice(box, "Sombras", "sombras", SHADOWS, [0, 1, 2, 3])
	_choice(box, "Antisserrilhado", "antisserrilhado", AA, [0, 1, 2, 3, 4])
	_slider(box, "Resolução 3D (menos = mais leve)", "escala_render", 0.5, 1.0, 0.05, "pct")
	_choice(box, "Detalhe dos modelos de longe", "detalhe", DETAIL, [0, 1, 2, 3])
	_toggle(box, "Sombra de contato (oclusão de ambiente)", "oclusao")
	_toggle(box, "Brilho das luzes", "brilho_luzes")
	_toggle(box, "Névoa volumétrica", "nevoa")


func _build_audio() -> void:
	var box := _tab("Áudio")
	_slider(box, "Volume geral", "volume_geral")
	_slider(box, "Música", "volume_musica")
	_slider(box, "Efeitos", "volume_efeitos")
	_slider(box, "Ambiente (vento, fogo)", "volume_ambiente")
	_slider(box, "Vozes (as falas)", "volume_vozes")
	_toggle(box, "Som com a janela fora de foco", "som_sem_foco")


func _build_controls() -> void:
	var box := _tab("Controles")
	_slider(box, "Sensibilidade do mouse", "sensibilidade", 0.3, 2.0, 0.05, "x")
	_toggle(box, "Inverter o mouse para cima e para baixo", "inverter_y")
	_toggle(box, "Inverter o mouse para os lados", "inverter_x")
	_slider(box, "Sensibilidade do controle (analógico)", "sensibilidade_controle", 0.3, 2.5, 0.05, "x")
	_slider(box, "Zona morta do analógico", "zona_morta", 0.05, 0.5, 0.01, "pct")
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	box.add_child(_status)
	var group := ""
	for entry: Array in Settings.REBINDABLE:
		if String(entry[2]) != group:
			group = String(entry[2])
			_header(box, group)
		_rebind_row(box, entry[0], String(entry[1]))
	_header(box, "Controle de videogame")
	_toggle(box, "Usar controle de videogame", "usar_controle")
	var pad := Label.new()
	pad.set_meta("controle", true)
	pad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad.modulate = Color(1, 1, 1, 0.75)
	box.add_child(pad)
	for entry: Array in PAD:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var caps := HBoxContainer.new()
		caps.add_theme_constant_override("separation", 4)
		caps.custom_minimum_size = Vector2(230, 0)
		for key: String in entry[0]:
			caps.add_child(keycap(key))
		row.add_child(caps)
		var what := Label.new()
		what.text = entry[1]
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		box.add_child(row)


func _build_game() -> void:
	var box := _tab("Jogo")
	_choice(box, "Dificuldade da luta", "dificuldade", DIFFICULTY, [0, 1, 2])
	_note(box, "Fácil: a defesa fica bem mais folgada (aparar 0,35 s, esquivar 0,5 s) e os inimigos batem 4 vezes mais "
		+ "fraco. Difícil: a defesa é a do normal, mas eles batem 2 vezes mais forte e têm 25% a mais de vida.")
	_toggle(box, "Mostrar dicas de controle na tela", "dicas")
	_slider(box, "Distância da câmera", "distancia_camera", 2.2, 8.0, 0.1, "m")
	_slider(box, "Tremor da câmera na luta", "tremor", 0.0, 1.0, 0.05, "pct")
	_slider(box, "Velocidade do texto", "velocidade_texto", 0.5, 3.0, 0.1, "x")
	_toggle(box, "Mostrar quadros por segundo (FPS)", "mostrar_fps")


func _build_access() -> void:
	var box := _tab("Acessibilidade")
	_slider(box, "Tamanho da interface e do texto", "tamanho_interface", 0.8, 1.4, 0.05, "pct")
	_slider(box, "Tempo dos reflexos na luta (golpes mais lentos)", "tempo_qte", 1.0, 2.0, 0.05, "x")
	_toggle(box, "Mostrar o anel na hora de se defender", "anel_defesa")
	_note(box, "O tempo dos reflexos deixa o seu golpe e o golpe do inimigo mais lentos, para quem precisa de mais tempo. "
		+ "Sem o anel, a defesa é como no Clair Obscur: olhe o golpe do inimigo e escute o assobio que vem antes dele.")


# --- peças da tela ------------------------------------------------------------------------------------------------

func _row(parent: Container, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(340, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	parent.add_child(row)
	return row


func _header(parent: Container, title: String) -> void:
	var header := Label.new()
	header.text = title
	header.theme_type_variation = &"TitleLabel"
	header.add_theme_font_size_override("font_size", 20)
	parent.add_child(header)


func _note(parent: Container, text: String) -> void:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color(1, 1, 1, 0.65)
	note.add_theme_font_size_override("font_size", 14)
	parent.add_child(note)


func _slider(parent: Container, text: String, key: String, low: float = 0.0, high: float = 1.0, step: float = 0.05,
		unit: String = "pct") -> void:
	var row := _row(parent, text)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(260, 28)
	slider.set_meta("chave", key)
	var number := Label.new()
	number.custom_minimum_size = Vector2(72, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		match unit:
			"pct":
				number.text = "%d%%" % roundi(v * 100.0)
			"graus":
				number.text = "%d°" % roundi(v)
			"m":
				number.text = ("%.1f m" % v).replace(".", ",")
			_:
				number.text = ("%.2f×" % v).replace(".", ",")
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


func _choice(parent: Container, text: String, key: String, labels: Array, values: Array) -> void:
	var row := _row(parent, text)
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(260, 32)
	for label: Variant in labels:
		pick.add_item(String(label))
	pick.set_meta("chave", key)
	pick.set_meta("valores", values)
	pick.item_selected.connect(func(index: int) -> void:
		var v: Variant = values[index]
		if Settings.value(key) != v:
			Settings.set_value(key, v))
	row.add_child(pick)


func _rebind_row(parent: Container, action: StringName, text: String) -> void:
	var row := _row(parent, text)
	var cap := keycap(Settings.key_name(action))
	cap.set_meta("acao", action)
	cap.custom_minimum_size = Vector2(120, 0)
	row.add_child(cap)
	var button := Button.new()
	button.text = "Trocar"
	button.custom_minimum_size = Vector2(150, 34)
	button.set_meta("trocar", action)
	button.pressed.connect(func() -> void:
		_waiting = action
		_waiting_button = button
		button.text = "Aperte a tecla…"
		_status.text = "Aperte a tecla ou o botão do mouse para \"%s\" (Esc cancela)." % text)
	row.add_child(button)


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
	for node: Node in find_children("*", "", true, false):
		if node.has_meta("chave"):
			var key: String = node.get_meta("chave")
			if node is Range:
				(node as Range).value = float(Settings.value(key))
				(node as Range).value_changed.emit((node as Range).value)
			elif node is CheckButton:
				(node as CheckButton).set_pressed_no_signal(bool(Settings.value(key)))
			elif node is OptionButton:
				var values: Array = node.get_meta("valores")
				var index := values.find(Settings.value(key))
				if index < 0 and Settings.value(key) is float:
					index = values.find(int(Settings.value(key)))
				(node as OptionButton).select(index)
		elif node.has_meta("controle"):
			var others: Array[String] = []
			for id: int in Input.get_connected_joypads():
				if id != Settings.pad_device:
					others.append(Input.get_joy_name(id))
			(node as Label).text = ("Usando: %s." % Settings.pad_name if Settings.pad_device >= 0 else "Nenhum controle em uso.") + 				(("  Ignorado (não é controle de videogame): %s." % ", ".join(others)) if not others.is_empty() else "")
		elif node.has_meta("acao"):
			(node as Label).text = Settings.key_name(node.get_meta("acao"))
		elif node.has_meta("trocar") and node.get_meta("trocar") != _waiting:
			(node as Button).text = "Trocar"
