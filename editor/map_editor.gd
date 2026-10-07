class_name MapEditor
extends Node3D
## Editor de mapas dentro do jogo (D023, refeito na D042). F2 numa fase, ou "Editor de mapas" na tela inicial.
## Esquerda: a Biblioteca (todas as peças, com foto, por categoria e com busca) e a lista do que está na fase.
## Meio: o mapa, com a GRADE ligada: prédios e muros encaixam pela pegada (a borda cai na linha da grade e o
## centro fica no meio das células), a pegada aparece no chão (verde = livre, vermelho = batendo em outra coisa).
## Direita: tudo o que dá para mudar na peça escolhida. Embaixo: as teclas do que dá para fazer agora.
## Salvar grava a própria .tscn da fase. Testar joga a fase como está (sem salvar); F2 lá volta para cá.

signal selection_changed

const LEVELS_DIR := "res://levels/"
## Fase usada de molde para "Nova fase" (fica só o chão, o sol e o que toda fase precisa).
const TEMPLATE := "res://levels/arandu/arandu.tscn"
## Nós que toda fase tem e que não se clicam no mapa (aparecem em "Na fase").
const SYSTEM: Array[String] = ["WorldEnvironment", "Sun", "Navigation", "CameraRig", "HUD", "FX", "Terrain", "Ground", "Embers", "Grama", "Smoke",
	"Missoes"]
## Grupos que entram no mapa de navegação (os aliados e inimigos desviam deles).
const NAV_GROUPS: Array[String] = ["Buildings", "Walls", "Market", "Ruins", "Trees", "Rocks", "Props", "Places", "Plaza", "Dungeon"]
const ACTION_NAMES: Array[String] = ["Mostrar texto", "Descansar", "Chamar herói", "Viajar", "Missão"]
## Tamanhos de grade (G liga/desliga; [ e ] trocam).
const GRIDS: Array[float] = [0.5, 1.0, 2.0, 4.0]
## Peças pequenas dos kits (menos que isso, em metros) não ganham colisão.
const KIT_MIN_COLLISION := 0.6
## Nomes dos campos no painel (o que não estiver aqui aparece com o nome do código).
const FIELD_NAMES: Dictionary[String, String] = {
	"chapter_title": "Nome da fase", "intro_lines": "Abertura", "start_story": "Texto do começo",
	"victory_text": "Texto de vitória", "defeat_text": "Texto de derrota", "skip_intro": "Pular abertura",
	"stabilize_after": "Levanta após (s)", "action": "F faz", "prompt_text": "Aviso na tela", "text": "Texto",
	"target_scene": "Leva para", "hero_id": "Herói", "encounter_id": "Nome da luta", "arena_scene": "Arena",
	"trigger_radius": "Começa a (m)", "after_text": "Texto ao vencer", "light_color": "Cor", "light_energy": "Força",
	"omni_range": "Alcance", "spot_range": "Alcance", "spot_angle": "Abertura", "shadow_enabled": "Sombras",
	"background_color": "Cor do fundo", "ambient_light_color": "Luz ambiente", "ambient_light_energy": "Força ambiente",
	"tonemap_exposure": "Exposição", "fog_enabled": "Neblina", "fog_light_color": "Cor da neblina",
	"fog_density": "Densidade", "glow_enabled": "Brilho", "display_name": "Nome", "max_hp": "Vida máx.",
	"hp": "Vida", "armor_class": "CA", "speed": "Velocidade", "personagem": "Personagem", "animacao": "Animação",
	"na_mao": "Na mão", "deslocamento": "Começa em (s)", "musica": "Música", "ambiente": "Som de fundo", "piso": "Chão (passos)",
}

## A fase aberta (raiz da cena) e o arquivo dela.
var level: Node3D
var level_path: String = ""
var selection: Array[Node3D] = []
var dirty: bool = false
## Grade: ligada por padrão; prédios encaixam pela pegada.
var snap: bool = true
var grid: float = 1.0
var library: EditorLibrary

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _placing: String = ""
var _entry: Dictionary = {}
var _ghost: Node3D
var _ghost_yaw: float = 0.0
var _ghost_scale: float = 1.0
var _ghost_ok: bool = true
var _press_pos: Vector2
var _pressing: bool = false
var _dragging: bool = false
var _boxing: bool = false
var _drag_hit: Vector3
var _drag_from: Array[Transform3D] = []
var _drag_center: Vector3
var _labels: Array[Dictionary] = []
var _syncing_tree: bool = false
var _hud_was_visible: bool = true
var _levels: PackedStringArray = []
var _after_confirm: Callable
var _section_box: VBoxContainer
var _recent: Array[String] = []
var _category: String = ""
var _mouse: Vector2
var _size_label: Label3D
## Câmeras da fase que estavam "atuais" no arquivo (a do jogo): o editor usa a dele e devolve isso ao salvar.
var _level_cameras: Array[Camera3D] = []
## A pegada pintada no chão (verde = livre, vermelho = batendo, amarelo = escolhida).
var _footprint_fill: MeshInstance3D

# interface (montada em _build_ui)
var _ui: Control
var _level_pick: OptionButton
var _status: Label
var _search: LineEdit
var _chips: HFlowContainer
var _items: ItemList
var _tree: Tree
var _inspector: VBoxContainer
var _box: Panel
var _toast: Label
var _hints: HBoxContainer
var _snap_button: CheckButton
var _grid_pick: OptionButton
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _confirm: ConfirmationDialog

@onready var _world: Node3D = $World
@onready var _camera: EditorCamera = $Camera
@onready var _overlay: Node3D = $Overlay
@onready var _lines: MeshInstance3D = $Overlay/Lines
@onready var _grid_mesh: MeshInstance3D = $Overlay/Grade


func _ready() -> void:
	Level.editing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	library = EditorLibrary.new()
	_lines.mesh = ImmediateMesh.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	line_mat.vertex_color_use_as_albedo = true
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lines.material_override = line_mat
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	_grid_mesh.mesh = plane
	var grid_mat := ShaderMaterial.new()
	grid_mat.shader = load("res://editor/grade.gdshader")
	_grid_mesh.material_override = grid_mat
	_size_label = Label3D.new()
	_size_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_size_label.no_depth_test = true
	_size_label.fixed_size = true
	_size_label.pixel_size = 0.001
	_size_label.font_size = 26
	_size_label.outline_size = 8
	_size_label.modulate = Color(1, 0.92, 0.6)
	_overlay.add_child(_size_label)
	_footprint_fill = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	_footprint_fill.mesh = quad
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.no_depth_test = true
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_footprint_fill.material_override = fill_mat
	_footprint_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.add_child(_footprint_fill)
	_build_ui()
	var path := Game.edit_level if Game.edit_level != "" else Game.ARANDU
	if Game.edit_draft != "" and FileAccess.file_exists(Game.edit_draft):
		open_level(path, Game.edit_draft)
		dirty = true
		_toast_text("Voltou do teste: o que não foi salvo continua aqui")
	else:
		open_level(path)
	Game.edit_draft = ""
	_build_inspector()
	_update_status()
	_update_hints()


func _exit_tree() -> void:
	Level.editing = false
	_free_orphans()


# --- interface ------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := $UI as CanvasLayer
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = load("res://ui/theme/journey_theme.tres")
	layer.add_child(_ui)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.07, 0.06, 0.94)
	panel_style.border_color = Color(0.55, 0.36, 0.2, 0.8)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(8)

	# barra de cima
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", panel_style)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_top = 8
	top.offset_right = -8
	top.offset_bottom = 56
	_ui.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	top.add_child(row)
	_level_pick = OptionButton.new()
	_level_pick.custom_minimum_size.x = 160
	_level_pick.tooltip_text = "Fase aberta"
	_level_pick.item_selected.connect(_on_level_picked)
	row.add_child(_level_pick)
	_tool_button(row, "Nova fase", "Começa uma fase nova, só com chão e sol", _ask_new_level)
	row.add_child(VSeparator.new())
	_tool_button(row, "Salvar", "Grava a fase (Ctrl+S)", func() -> void: save())
	_tool_button(row, "↶ Desfazer", "Ctrl+Z", undo)
	_tool_button(row, "↷ Refazer", "Ctrl+Y", redo)
	row.add_child(VSeparator.new())
	_snap_button = CheckButton.new()
	_snap_button.text = "Grade"
	_snap_button.button_pressed = snap
	_snap_button.tooltip_text = "Encaixar na grade (G). Prédios encaixam pela pegada: a borda na linha, o centro no meio das células."
	_snap_button.toggled.connect(func(on: bool) -> void:
		snap = on
		_update_hints())
	row.add_child(_snap_button)
	_grid_pick = OptionButton.new()
	for g: float in GRIDS:
		_grid_pick.add_item(("%s m" % str(g)).replace(".", ","))
	_grid_pick.select(GRIDS.find(grid))
	_grid_pick.tooltip_text = "Tamanho da célula ([ e ] trocam). As peças de casa dos kits encaixam em 2 m."
	_grid_pick.item_selected.connect(func(i: int) -> void: set_grid(GRIDS[i]))
	row.add_child(_grid_pick)
	_tool_button(row, "Vista de cima", "T", func() -> void: _camera.toggle_top_view())
	_tool_button(row, "Propriedades da fase", "Nome, música, sol e céu da fase", func() -> void: select_nodes([level]))
	row.add_child(VSeparator.new())
	_tool_button(row, "▶ Testar", "Joga a fase como está agora, sem salvar (F2 lá volta para cá)", test_level)
	_tool_button(row, "Sair", "Volta para a tela inicial", func() -> void: _leave(Game.go_to_title))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(1, 0.9, 0.75, 0.8))
	row.add_child(_status)

	# esquerda: biblioteca e lista da fase
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", panel_style)
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 8
	left.offset_top = 64
	left.offset_right = 392
	left.offset_bottom = -58
	_ui.add_child(left)
	var tabs := TabContainer.new()
	left.add_child(tabs)
	var lib_box := VBoxContainer.new()
	lib_box.name = "Biblioteca"
	lib_box.add_theme_constant_override("separation", 6)
	tabs.add_child(lib_box)
	_search = LineEdit.new()
	_search.placeholder_text = "Buscar (ex.: porta, barril, árvore, telhado)"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _fill_items())
	lib_box.add_child(_search)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 4)
	_chips.add_theme_constant_override("v_separation", 4)
	lib_box.add_child(_chips)
	var chip_group := ButtonGroup.new()
	for c: String in ["Recentes"] + library.categories:
		var chip := Button.new()
		chip.text = c
		chip.toggle_mode = true
		chip.button_group = chip_group
		chip.focus_mode = Control.FOCUS_NONE
		chip.add_theme_font_size_override("font_size", 13)
		chip.pressed.connect(func() -> void:
			_category = c
			_search.text = ""
			_fill_items())
		_chips.add_child(chip)
		if c == "Prédios":
			chip.button_pressed = true
			_category = c
	_items = ItemList.new()
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items.icon_mode = ItemList.ICON_MODE_TOP
	_items.fixed_icon_size = Vector2i(96, 96)
	_items.max_columns = 0
	_items.fixed_column_width = 108
	_items.same_column_width = true
	_items.max_text_lines = 2
	_items.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_items.add_theme_font_size_override("font_size", 13)
	_items.focus_mode = Control.FOCUS_NONE
	_items.item_selected.connect(func(i: int) -> void:
		var key := String(_items.get_item_metadata(i))
		start_placing(key if key != _placing else ""))
	lib_box.add_child(_items)
	_tree = Tree.new()
	_tree.name = "Na fase"
	_tree.item_selected.connect(_on_tree_selected)
	tabs.add_child(_tree)

	# direita: propriedades
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", panel_style)
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -392
	right.offset_top = 64
	right.offset_right = -8
	right.offset_bottom = -58
	_ui.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 4)
	scroll.add_child(_inspector)

	# embaixo: teclas do que dá para fazer agora
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", panel_style)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 8
	bottom.offset_top = -50
	bottom.offset_right = -8
	bottom.offset_bottom = -8
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bottom)
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 18)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_hints)

	_box = Panel.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(1, 0.82, 0.3, 0.12)
	box_style.border_color = Color(1, 0.82, 0.3, 0.9)
	box_style.set_border_width_all(1)
	_box.add_theme_stylebox_override("panel", box_style)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	_ui.add_child(_box)
	_toast = Label.new()
	_toast.theme_type_variation = &"ToastLabel"
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 72
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_toast)

	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Nova fase"
	var form := VBoxContainer.new()
	var hint := Label.new()
	hint.text = "Nome da fase (vira a pasta levels/<nome>/):"
	form.add_child(hint)
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "Floresta de Novazul"
	form.add_child(_new_name)
	_new_dialog.add_child(form)
	_new_dialog.confirmed.connect(_create_level)
	layer.add_child(_new_dialog)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Sair sem salvar?"
	_confirm.confirmed.connect(func() -> void: _after_confirm.call())
	layer.add_child(_confirm)
	_fill_items()


func _tool_button(parent: Control, text: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## Mostra as peças da categoria escolhida (ou o resultado da busca, em todas as categorias).
func _fill_items() -> void:
	if _items == null:
		return
	_items.clear()
	var list: Array = []
	if _search.text.strip_edges() != "":
		list = library.search(_search.text)
	elif _category == "Recentes":
		for key: String in _recent:
			if library.by_key.has(key):
				list.append(library.by_key[key])
	else:
		list = library.entries.get(_category, [])
	for entry: Dictionary in list:
		var icon_path := EditorLibrary.icon_path(entry["key"])
		var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
		var i := _items.add_item(String(entry["nome"]), icon)
		_items.set_item_metadata(i, entry["key"])
		_items.set_item_tooltip(i, "%s\n%s" % [entry["nome"], entry["dica"]] if String(entry["dica"]) != "" else String(entry["nome"]))
		if entry["key"] == _placing:
			_items.select(i)


## Teclas do que dá para fazer agora (barra de baixo).
func _update_hints() -> void:
	if _hints == null:
		return
	for child: Node in _hints.get_children():
		child.queue_free()
	var list: Array = []
	if _placing != "":
		list = [[["Clique"], "coloca"], [["Q", "E"], "gira 90°"], [["Shift"], "+ roda: gira 15°"], [["Ctrl"], "+ roda: tamanho"],
			[["Alt"], "solta da grade"], [["Esc"], "para de colocar"]]
	elif not selection.is_empty() and not (selection.size() == 1 and selection[0] == level):
		list = [[["Arrastar"], "move"], [["Q", "E"], "gira 90°"], [["←", "→", "↑", "↓"], "anda 1 célula"], [["C"], "centraliza na grade"],
			[["Del"], "apaga"], [["Ctrl", "D"], "duplica"], [["F"], "foca"], [["Esc"], "solta"]]
	else:
		list = [[["Clique"], "escolhe uma peça"], [["Arrastar"], "escolhe várias"], [["W", "A", "S", "D"], "anda"], [["Botão dir."], "gira a câmera"],
			[["Roda"], "aproxima"], [["G"], "grade %s" % ("ligada" if snap else "desligada")], [["T"], "de cima"], [["Ctrl", "Z"], "desfaz"]]
	for entry: Array in list:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for key: String in entry[0]:
			item.add_child(OptionsMenu.keycap(key))
		var text := Label.new()
		text.text = " " + String(entry[1])
		text.add_theme_font_size_override("font_size", 14)
		item.add_child(text)
		_hints.add_child(item)


func set_grid(size: float) -> void:
	grid = size
	if _grid_pick:
		_grid_pick.select(GRIDS.find(size))
	_toast_text(("Grade de %s m" % str(size)).replace(".", ","))


# --- abrir, salvar, testar ------------------------------------------------------------------

## Abre uma fase no editor. source = de onde ler (o rascunho do Testar); por padrão o próprio arquivo.
func open_level(path: String, source: String = "") -> void:
	if level:
		_world.remove_child(level)
		level.queue_free()
		level = null
	_free_orphans()
	_undo.clear()
	_redo.clear()
	selection.clear()
	_cancel_placing()
	var scene := ResourceLoader.load(source if source != "" else path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if scene == null:
		_toast_text("Não consegui abrir %s" % path)
		return
	level = scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	_level_cameras.clear()
	for found: Node in level.find_children("*", "Camera3D", true, false):
		if (found as Camera3D).current:
			_level_cameras.append(found as Camera3D)
	_world.add_child(level)
	_camera.camera.make_current()  # a câmera do jogo (CameraRig) vem marcada como atual e roubava a vista
	level_path = path
	Game.edit_level = path
	dirty = false
	var hud := level.get_node_or_null("HUD") as CanvasLayer
	if hud:
		_hud_was_visible = hud.visible
		hud.visible = false
	var spawn := level.get_node_or_null("PlayerSpawn") as Node3D
	_camera.focus(spawn.global_position if spawn else Vector3.ZERO, 40.0)
	_fill_level_pick()
	_refresh_all()


## Grava a fase no arquivo dela (ou em outro caminho, nos testes).
func save(path: String = "") -> Error:
	if path == "":
		path = level_path
	var err := _write(path)
	if err != OK:
		_toast_text("Não deu para salvar (%s). Salvar só funciona rodando o jogo pelo Godot." % error_string(err))
		return err
	if path == level_path:
		dirty = false
		_toast_text("Salvo em %s" % path)
	_update_status()
	return OK


## Joga a fase como está agora (sem mexer no arquivo). F2 no jogo volta para cá.
func test_level() -> void:
	if _write(Game.EDITOR_DRAFT) != OK:
		_toast_text("Não consegui preparar o teste")
		return
	Game.edit_level = level_path
	Level.editing = false
	Game.test_level(Game.EDITOR_DRAFT)


func _write(path: String) -> Error:
	var hud := level.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = _hud_was_visible
	for cam: Camera3D in _level_cameras:
		if is_instance_valid(cam):
			cam.current = true
	var packed := PackedScene.new()
	var err := packed.pack(level)
	_camera.camera.make_current()
	_camera.camera.make_current.call_deferred()  # a troca de câmera da fase também chega um quadro depois
	if hud:
		hud.visible = false
	if err != OK:
		return err
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	err = ResourceSaver.save(packed, path)
	if err == OK:
		packed.take_over_path(path)  # quem carregar a fase depois (Testar, F2) pega a versão nova
	return err


func _leave(then: Callable) -> void:
	if not dirty:
		then.call()
		return
	_after_confirm = then
	_confirm.dialog_text = "Tem coisa não salva em %s. Sair mesmo assim?" % level_path.get_file()
	_confirm.popup_centered()


func _fill_level_pick() -> void:
	_levels.clear()
	for dir: String in DirAccess.get_directories_at(LEVELS_DIR):
		if dir == "arenas":
			continue  # a arena é outra coisa (luta por turnos)
		for file: String in DirAccess.get_files_at(LEVELS_DIR + dir):
			if file.ends_with(".tscn"):
				_levels.append(LEVELS_DIR + dir + "/" + file)
	if not _levels.has(level_path):
		_levels.append(level_path)
	_level_pick.clear()
	for i: int in _levels.size():
		_level_pick.add_item(_levels[i].get_file().get_basename().capitalize())
		if _levels[i] == level_path:
			_level_pick.select(i)


func _on_level_picked(index: int) -> void:
	var path := _levels[index]
	if path == level_path:
		return
	_leave(func() -> void: open_level(path))
	_fill_level_pick()  # se cancelar, o seletor volta para a fase aberta


func _ask_new_level() -> void:
	_new_name.text = ""
	_new_dialog.popup_centered(Vector2i(420, 140))
	_new_name.grab_focus()


## "Nova fase": copia o molde deixando só o chão, o sol e o que toda fase precisa.
func _create_level() -> void:
	var title := _new_name.text.strip_edges()
	var slug := title.to_lower().validate_filename().replace(" ", "_")
	if slug == "":
		_toast_text("Dê um nome para a fase")
		return
	var path := LEVELS_DIR + slug + "/" + slug + ".tscn"
	if FileAccess.file_exists(path):
		_toast_text("Já existe uma fase chamada %s" % slug)
		return
	_leave(func() -> void:
		var fresh := (ResourceLoader.load(TEMPLATE, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		for child: Node in fresh.get_children():
			if not (SYSTEM.has(String(child.name)) or child.name == &"PlayerSpawn") or child.name in [&"Grama", &"Smoke", &"Missoes"]:
				fresh.remove_child(child)
				child.free()
		var ground := fresh.get_node_or_null("Ground")
		if ground:
			for part: Node in ground.get_children():
				if not (part.name == &"Dirt" or part.name == &"Body"):
					ground.remove_child(part)
					part.free()
		fresh.name = title.to_pascal_case()
		fresh.set("chapter_title", title)
		fresh.set("intro_lines", PackedStringArray([title + "."]))
		fresh.set("start_story", "")
		fresh.set("cena_de_abertura", null)
		var packed := PackedScene.new()
		packed.pack(fresh)
		fresh.free()
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if ResourceSaver.save(packed, path) != OK:
			_toast_text("Não deu para criar a fase (só rodando pelo Godot)")
			return
		open_level(path)
		_toast_text("Fase nova: %s. Pegue peças na Biblioteca e salve." % path))


# --- colocar peças --------------------------------------------------------------------------

func _entry_of(key: String) -> Dictionary:
	var path := key if key.begins_with("res://") else EditorLibrary.PROPS + key + ".tscn"
	if library.by_key.has(path):
		return library.by_key[path]
	return {"key": path, "nome": path.get_file().get_basename(), "dica": "", "grupo": "Props", "varia": false, "escala": 1.0, "estrutura": false}


## Começa a colocar uma peça: ela segue o mouse; clique coloca (pode colocar várias), Esc para.
func start_placing(key: String) -> void:
	_cancel_placing()
	if key == "":
		return
	select_nodes([])
	_entry = _entry_of(key)
	_placing = String(_entry["key"])
	_ghost_yaw = 0.0
	_ghost_scale = 1.0
	_ghost = (load(_placing) as PackedScene).instantiate() as Node3D
	_overlay.add_child(_ghost)
	for body: Node in _ghost.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = 0
	_ghost.visible = false
	_vary_ghost()
	_recent.erase(_placing)
	_recent.push_front(_placing)
	_recent = _recent.slice(0, 24)
	_update_hints()


## Coloca uma peça neste ponto (é o que o clique faz; os testes chamam direto). Devolve a peça colocada.
func place(key: String, at: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	var entry := _entry_of(key)
	var scene := load(String(entry["key"])) as PackedScene
	var piece := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	var parent := _container_for(entry)
	parent.add_child(piece, true)
	piece.owner = level
	piece.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size * float(entry["escala"])), at)
	if not String(entry["key"]).begins_with(EditorLibrary.PROPS) and _kit_collides(entry, piece):
		piece.add_to_group("colisao_auto", true)  # a fase dá colisão do formato da peça
	_push({"kind": "add", "nodes": [piece], "parents": [parent], "indexes": [piece.get_index()], "owned": [_owned_paths(piece)]})
	dirty = true
	_refresh_all()
	return piece


func _cancel_placing() -> void:
	_placing = ""
	_entry = {}
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if _items:
		_items.deselect_all()
	_update_hints()


func _vary_ghost() -> void:
	if _entry.get("varia", false):
		_ghost_yaw = randf() * TAU
		_ghost_scale = randf_range(0.85, 1.2)
	if _ghost:
		_ghost.basis = Basis(Vector3.UP, _ghost_yaw).scaled(Vector3.ONE * _ghost_scale * float(_entry.get("escala", 1.0)))


## Peça solta de kit: estruturas grandes ganham colisão; plantas e coisas pequenas, não.
func _kit_collides(entry: Dictionary, piece: Node3D) -> bool:
	var file := String(entry["key"]).get_file()
	if String(entry["key"]).contains("/natureza/"):
		return file.begins_with("Rock_") or file.begins_with("DeadTree") or file.begins_with("TwistedTree")
	var box := _bounds(piece)
	return maxf(box.size.x, maxf(box.size.y, box.size.z)) >= KIT_MIN_COLLISION


## O grupo da fase onde a peça entra (cria o grupo se a fase ainda não tem).
func _container_for(entry: Dictionary) -> Node3D:
	var group_name := String(entry.get("grupo", "Props"))
	var found := level.get_node_or_null(group_name) as Node3D
	if found:
		return found
	var created := Node3D.new()
	created.name = group_name
	level.add_child(created)
	created.owner = level
	if NAV_GROUPS.has(group_name):
		created.add_to_group("nav_source", true)
	return created


# --- grade: encaixe pela pegada ---------------------------------------------------------------

## Centro de uma pegada de tamanho `size` perto de `x` na grade: se cabe um número ímpar de células, o
## centro fica no meio de uma célula; se par, numa linha. Assim as bordas sempre caem nas linhas.
func _snap_axis(x: float, size: float) -> float:
	var cells := maxi(1, roundi(size / grid))
	if cells % 2 == 1:
		return (floorf(x / grid) + 0.5) * grid
	return roundf(x / grid) * grid


## Onde a peça deve ficar para a pegada dela encaixar na grade com o centro perto de `point`.
## Devolve a origem nova (o y continua o de `point`).
func snap_piece(piece: Node3D, point: Vector3) -> Vector3:
	var box := _bounds(piece)
	var offset := box.get_center() - piece.global_position
	offset.y = 0.0
	var center := point + offset
	if snap:
		center = Vector3(_snap_axis(center.x, box.size.x), center.y, _snap_axis(center.z, box.size.z))
	return center - offset


## Centraliza as peças escolhidas na grade (pela pegada de cada uma).
func center_selection() -> void:
	var was := snap
	snap = true
	_transform_selection(func(n: Node3D) -> Transform3D:
		var xf := n.transform
		var target := snap_piece(n, n.global_position)
		var parent := n.get_parent_node_3d()
		xf.origin = parent.global_transform.affine_inverse() * target if parent else target
		return xf)
	snap = was


## A pegada (retângulo no chão) de uma peça.
func _footprint(piece: Node3D) -> Rect2:
	var box := _bounds(piece)
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


## A pegada bate em outra estrutura da fase? (coisa pequena, chão e plantas não contam)
func _blocked(rect: Rect2, ignore: Array) -> bool:
	var inner := rect.grow(-0.15)
	for item: Node3D in items():
		if ignore.has(item) or not item.is_visible_in_tree():
			continue
		var other := _footprint(item)
		if other.size.x * other.size.y < 1.5 or other.size.x > 60.0 or other.size.y > 60.0:
			continue
		if inner.intersects(other.grow(-0.15)):
			return true
	return false


# --- entrada (mouse e teclado) --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if level == null:
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey and event.is_pressed():
		_on_key(event as InputEventKey)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	var wheel := event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if wheel and event.pressed and (event.ctrl_pressed or event.shift_pressed):
		var up := event.button_index == MOUSE_BUTTON_WHEEL_UP
		if event.shift_pressed:
			var step := deg_to_rad(15.0) * (1.0 if up else -1.0)
			if _ghost:
				_ghost_yaw += step
				_vary_ghost_keep()
			else:
				rotate_selection(step)
		else:
			var factor := 1.08 if up else 1.0 / 1.08
			if _ghost:
				_ghost_scale *= factor
				_vary_ghost_keep()
			else:
				scale_selection(factor)
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if _placing != "":
			if _ghost and _ghost.visible:
				var piece := place(_placing, _ghost.global_position, _ghost_yaw, _ghost_scale)
				_flash(piece)
				_vary_ghost()
				_toast_text("%s colocado%s" % [_entry.get("nome", ""), "" if _ghost_ok else " (está batendo em outra coisa)"])
			return
		_press_pos = event.position
		_pressing = true
		var picked := _pick(event.position, event.alt_pressed)
		if picked == null:
			_boxing = true
			if not event.shift_pressed:
				select_nodes([])
			return
		if event.shift_pressed or event.ctrl_pressed:
			var now := selection.duplicate()
			if now.has(picked):
				now.erase(picked)
			else:
				now.append(picked)
			select_nodes(now)
			_pressing = false
			return
		if not selection.has(picked):
			select_nodes([picked])
		var hit: Variant = _ground_hit(event.position, selection)
		_drag_hit = hit if hit != null else picked.global_position
		_drag_from.clear()
		for node: Node3D in selection:
			_drag_from.append(node.global_transform)
		_drag_center = _bounds(selection[0]).get_center()
	else:
		if _dragging:
			var to: Array = []
			for node: Node3D in selection:
				to.append(node.transform)
			var from: Array = []
			for i: int in selection.size():
				from.append(selection[i].get_parent_node_3d().global_transform.affine_inverse() * _drag_from[i])
			_push({"kind": "xf", "nodes": selection.duplicate(), "from": from, "to": to})
			dirty = true
			_update_status()
			_build_inspector()
		elif _boxing and _press_pos.distance_to(event.position) > 6.0:
			var rect := Rect2(_press_pos, event.position - _press_pos).abs()
			var inside: Array[Node3D] = []
			if event.shift_pressed:
				inside.assign(selection)
			for item: Node3D in items():
				var screen := _camera.camera.unproject_position(item.global_position)
				if rect.has_point(screen) and not _camera.camera.is_position_behind(item.global_position) and not inside.has(item):
					inside.append(item)
			select_nodes(inside)
		_pressing = false
		_dragging = false
		_boxing = false
		_box.visible = false


func _vary_ghost_keep() -> void:
	if _ghost:
		_ghost.basis = Basis(Vector3.UP, _ghost_yaw).scaled(Vector3.ONE * _ghost_scale * float(_entry.get("escala", 1.0)))
		_move_ghost()


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	_mouse = event.position
	if _ghost:
		_move_ghost()
	if not _pressing or not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return
	if _boxing:
		var rect := Rect2(_press_pos, event.position - _press_pos).abs()
		_box.visible = true
		_box.position = rect.position
		_box.size = rect.size
		return
	if not _dragging and _press_pos.distance_to(event.position) < 5.0:
		return
	if selection.is_empty() or _drag_from.size() != selection.size() or selection.has(level):
		return
	_dragging = true
	var hit: Variant = _ground_hit(event.position, selection)
	if hit == null:
		return
	var delta: Vector3 = (hit as Vector3) - _drag_hit
	delta.y = 0.0
	# a primeira peça "manda" na grade (pela pegada); as outras andam junto, do mesmo tanto
	if snap and not Input.is_key_pressed(KEY_ALT):
		var box := _bounds(selection[0])
		var center := _drag_center + delta
		var snapped_center := Vector3(_snap_axis(center.x, box.size.x), center.y, _snap_axis(center.z, box.size.z))
		delta += snapped_center - center
	for i: int in selection.size():
		var xf := _drag_from[i]
		xf.origin += delta
		selection[i].global_transform = xf


## A peça que segue o mouse: encaixa a pegada na grade e pousa no que estiver embaixo
## (estruturas ficam no chão; objetos podem ir em cima de mesa, balcão...).
func _move_ghost() -> void:
	var structure: bool = _entry.get("estrutura", false)
	var hit: Variant = _ground_hit(_mouse, [], not structure)
	_ghost.visible = hit != null
	if hit == null:
		return
	var point: Vector3 = hit
	_ghost.global_position = point
	var was := snap
	if Input.is_key_pressed(KEY_ALT):
		snap = false
	var target := snap_piece(_ghost, point)
	snap = was
	var ground: Variant = _surface_y(target, not structure)
	target.y = float(ground) if ground != null else point.y
	_ghost.global_position = target
	_ghost_ok = not structure or not _blocked(_footprint(_ghost), [])


func _on_key(event: InputEventKey) -> void:
	var key := event.keycode
	var fine := event.shift_pressed
	if event.ctrl_pressed:
		match key:
			KEY_S:
				save()
			KEY_Z:
				if event.shift_pressed:
					redo()
				else:
					undo()
			KEY_Y:
				redo()
			KEY_D:
				duplicate_selection()
			KEY_A:
				select_nodes(items())
			KEY_F:
				_search.grab_focus()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	var repeats := [KEY_Q, KEY_E, KEY_PAGEUP, KEY_PAGEDOWN, KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	if event.echo and key not in repeats:
		return
	match key:
		KEY_Q, KEY_E:
			var step := deg_to_rad(15.0 if fine else 90.0) * (1.0 if key == KEY_Q else -1.0)
			if _ghost:
				_ghost_yaw += step
				_vary_ghost_keep()
			else:
				rotate_selection(step)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if selection.is_empty():
				return
			var axes := _camera.ground_axes()
			var dir: Vector3 = {KEY_LEFT: -axes[1], KEY_RIGHT: axes[1], KEY_UP: axes[0], KEY_DOWN: -axes[0]}[key]
			# anda na direção da tela, mas sempre por um eixo do mundo (x ou z)
			dir = Vector3(signf(dir.x), 0, 0) if absf(dir.x) > absf(dir.z) else Vector3(0, 0, signf(dir.z))
			move_selection(dir * (grid if not fine else grid * 0.25))
		KEY_PAGEUP, KEY_PAGEDOWN:
			move_selection(Vector3.UP * (1.0 if fine else 0.25) * (1.0 if key == KEY_PAGEUP else -1.0))
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			scale_selection(1.1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			scale_selection(1.0 / 1.1)
		KEY_R:
			_transform_selection(func(n: Node3D) -> Transform3D: return Transform3D(Basis(), n.transform.origin))
		KEY_C:
			center_selection()
			_toast_text("Centralizado na grade")
		KEY_DELETE, KEY_BACKSPACE:
			delete_selection()
		KEY_G:
			_snap_button.button_pressed = not _snap_button.button_pressed
			_toast_text("Grade %s" % ("ligada" if snap else "desligada"))
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var i := clampi(GRIDS.find(grid) + (1 if key == KEY_BRACKETRIGHT else -1), 0, GRIDS.size() - 1)
			set_grid(GRIDS[i])
		KEY_T:
			_camera.toggle_top_view()
		KEY_F:
			if not selection.is_empty():
				var box := _bounds(selection[0])
				_camera.focus(box.get_center(), maxf(box.get_longest_axis_size() * 2.5, 8.0))
		KEY_ESCAPE:
			if _placing != "":
				_cancel_placing()
			else:
				select_nodes([])
		KEY_F2:
			_leave(func() -> void: test_level())
		_:
			return
	get_viewport().set_input_as_handled()


# --- o que dá para fazer com o que está escolhido -------------------------------------------

func select_nodes(nodes: Array) -> void:
	selection.clear()
	for node: Variant in nodes:
		if node is Node3D and is_instance_valid(node) and (node as Node3D).is_inside_tree():
			selection.append(node as Node3D)
	_sync_tree_selection()
	_build_inspector()
	_update_hints()
	_update_status()
	selection_changed.emit()


func rotate_selection(angle: float) -> void:
	# gira em volta do centro da pegada (a peça não "anda" ao girar)
	_transform_selection(func(n: Node3D) -> Transform3D:
		var center := _bounds(n).get_center()
		var parent := n.get_parent_node_3d()
		var local_center := parent.global_transform.affine_inverse() * center if parent else center
		var xf := n.transform
		var turn := Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
		var rel := xf.origin - local_center
		xf.origin = local_center + turn.basis * rel
		xf.basis = turn.basis * xf.basis
		return xf)


func scale_selection(factor: float) -> void:
	_transform_selection(func(n: Node3D) -> Transform3D: return n.transform.scaled_local(Vector3.ONE * factor))


func move_selection(offset: Vector3) -> void:
	_transform_selection(func(n: Node3D) -> Transform3D: return n.transform.translated(offset))


func delete_selection() -> void:
	var nodes: Array = []
	var parents: Array = []
	var indexes: Array = []
	var owned: Array = []
	for node: Node3D in selection:
		if node == level:
			continue
		if node.owner != level:
			_toast_text("%s é parte de dentro de outra peça: apague a peça inteira" % node.name)
			continue
		nodes.append(node)
		parents.append(node.get_parent())
		indexes.append(node.get_index())
		owned.append(_owned_paths(node))
	if nodes.is_empty():
		return
	for node: Node in nodes:
		node.get_parent().remove_child(node)
	_push({"kind": "del", "nodes": nodes, "parents": parents, "indexes": indexes, "owned": owned})
	dirty = true
	select_nodes([])
	_refresh_all()


func duplicate_selection() -> void:
	var copies: Array = []
	var parents: Array = []
	var indexes: Array = []
	var owned: Array = []
	for node: Node3D in selection:
		if node == level:
			continue
		var paths := _owned_paths(node)
		var editable: Array[NodePath] = []
		for inner: Node in node.find_children("*", "", true, false):
			if level.is_editable_instance(inner):
				editable.append(node.get_path_to(inner))
		var copy := node.duplicate() as Node3D
		if copy.get("encounter_id") is String:
			copy.set("encounter_id", "")  # grupo novo: vencer um não some com o outro
		node.get_parent().add_child(copy, true)
		_restore_owned(copy, paths)
		for rel: NodePath in editable:
			level.set_editable_instance(copy.get_node(rel), true)
		# a cópia vai para o lado, encostada na original (largura da pegada), já na grade
		var box := _bounds(node)
		var right := _camera.ground_axes()[1]
		var side := Vector3(signf(right.x), 0, 0) if absf(right.x) > absf(right.z) else Vector3(0, 0, signf(right.z))
		copy.global_position += side * maxf(absf(box.size.dot(side)), grid)
		copies.append(copy)
		parents.append(copy.get_parent())
		indexes.append(copy.get_index())
		owned.append(paths)
	if copies.is_empty():
		return
	_push({"kind": "add", "nodes": copies, "parents": parents, "indexes": indexes, "owned": owned})
	dirty = true
	_refresh_all()
	select_nodes(copies)


func _transform_selection(change: Callable) -> void:
	var nodes: Array = []
	var from: Array = []
	var to: Array = []
	for node: Node3D in selection:
		if node == level:
			continue
		from.append(node.transform)
		node.transform = change.call(node)
		to.append(node.transform)
		nodes.append(node)
		_mark_edited(node)
	if nodes.is_empty():
		return
	_push({"kind": "xf", "nodes": nodes, "from": from, "to": to})
	dirty = true
	_update_status()
	_build_inspector()


## Muda uma propriedade com desfazer. merge junta mudanças seguidas do mesmo campo (arrastar um número).
func set_prop(object: Object, property: String, value: Variant, merge: bool = true) -> void:
	var before: Variant = object.get(property)
	if typeof(before) == typeof(value) and before == value:
		return
	object.set(property, value)
	if object is Node:
		_mark_edited(object as Node)
	var last: Dictionary = _undo.back() if not _undo.is_empty() else {}
	if merge and last.get("kind") == "prop" and last.get("object") == object and last.get("property") == property:
		last["to"] = value
	else:
		_push({"kind": "prop", "object": object, "property": property, "from": before, "to": value})
	dirty = true
	_update_status()
	if property == "name":
		_refresh_tree()
	_refresh_labels()


func undo() -> void:
	if _undo.is_empty():
		_toast_text("Nada para desfazer")
		return
	var entry: Dictionary = _undo.pop_back()
	_apply(entry, true)
	_redo.append(entry)


func redo() -> void:
	if _redo.is_empty():
		_toast_text("Nada para refazer")
		return
	var entry: Dictionary = _redo.pop_back()
	_apply(entry, false)
	_undo.append(entry)


func _push(entry: Dictionary) -> void:
	_undo.append(entry)
	_redo.clear()
	if _undo.size() > 300:
		_undo.pop_front()


func _apply(entry: Dictionary, backwards: bool) -> void:
	var nodes: Array = entry.get("nodes", [])
	match entry["kind"]:
		"xf":
			var values: Array = entry["from"] if backwards else entry["to"]
			for i: int in nodes.size():
				if is_instance_valid(nodes[i]):
					(nodes[i] as Node3D).transform = values[i]
		"prop":
			(entry["object"] as Object).set(entry["property"], entry["from"] if backwards else entry["to"])
			_refresh_tree()
		"add", "del":
			var removing: bool = (entry["kind"] == "add") == backwards
			for i: int in nodes.size():
				var node := nodes[i] as Node
				if removing:
					if node.get_parent():
						node.get_parent().remove_child(node)
				else:
					var parent := entry["parents"][i] as Node
					parent.add_child(node)
					parent.move_child(node, mini(int(entry["indexes"][i]), parent.get_child_count() - 1))
					_restore_owned(node, entry["owned"][i])
			_refresh_all()
	dirty = true
	select_nodes(selection.filter(func(n: Node3D) -> bool: return is_instance_valid(n) and n.is_inside_tree()))
	_update_status()


## Nó de dentro de uma peça (um inimigo dentro do grupo, a fala dentro do morador): para a mudança
## ser salva, a peça de fora vira "editável" (no Godot: Filhos editáveis).
func _mark_edited(node: Node) -> void:
	var outer := node.owner
	while outer and outer != level:
		level.set_editable_instance(outer, true)
		outer = outer.owner


## Caminhos (relativos) dos nós desta peça que pertencem à fase; refeito quando a peça volta (desfazer).
func _owned_paths(node: Node) -> Array[NodePath]:
	var paths: Array[NodePath] = []
	if node.owner == level:
		paths.append(NodePath("."))
	for inner: Node in node.find_children("*", "", true, false):
		if inner.owner == level:
			paths.append(node.get_path_to(inner))
	return paths


func _restore_owned(node: Node, paths: Array) -> void:
	for path: NodePath in paths:
		var inner := node.get_node_or_null(path)
		if inner:
			inner.owner = level


func _free_orphans() -> void:
	for entry: Dictionary in _undo + _redo:
		for node: Variant in entry.get("nodes", []):
			if is_instance_valid(node) and (node as Node).get_parent() == null:
				(node as Node).queue_free()


# --- achar peças no mapa --------------------------------------------------------------------

## Tudo o que dá para clicar: os filhos dos grupos da fase (Buildings, Rocks...) e o que está solto na raiz.
func items() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if level == null:
		return result
	for child: Node in level.get_children():
		if not child is Node3D or SYSTEM.has(String(child.name)):
			continue
		if _is_group(child):
			for inner: Node in child.get_children():
				if inner is Node3D:
					result.append(inner as Node3D)
		else:
			result.append(child as Node3D)
	return result


## Grupo da fase: Node3D simples direto na raiz que junta peças (Buildings, Rocks, Encounters...).
## Um Node3D simples feito só de malhas e colisão é uma peça, não um grupo.
func _is_group(node: Node) -> bool:
	if not (node.get_parent() == level and node.get_class() == "Node3D" and node.get_script() == null
			and node.scene_file_path == "" and not SYSTEM.has(String(node.name))):
		return false
	if node.get_child_count() == 0:
		return true
	for child: Node in node.get_children():
		if child.scene_file_path != "" or child.get_script() != null:
			return true
		if child is Node3D and not (child is VisualInstance3D or child is CollisionObject3D):
			return true
	return false


func _item_of(node: Node) -> Node3D:
	var current := node
	while current and current != level:
		var parent := current.get_parent()
		if parent == level:
			return null if SYSTEM.has(String(current.name)) or _is_group(current) else current as Node3D
		if _is_group(parent):
			return current as Node3D
		current = parent
	return null


func _pick(screen: Vector2, deep: bool) -> Node3D:
	var cam := _camera.camera
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var best: Node3D = null
	var best_d := INF
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 2000.0, 1 | 2 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var item := _item_of(hit["collider"] as Node)
		if item:
			best = item
			best_d = from.distance_to(hit["position"])
		else:
			best_d = from.distance_to(hit["position"]) + 0.5  # bateu no chão: só vale o que estiver na frente dele
	for item: Node3D in items():
		var has_body := not item.find_children("*", "CollisionObject3D", true, false).is_empty()
		if best == null or not has_body:
			var at: Variant = _bounds(item).intersects_ray(from, dir)
			if at != null and from.distance_to(at) < best_d:
				best = item
				best_d = from.distance_to(at)
	if best and deep:
		var inner_best: Node3D = null
		var inner_d := INF
		for inner: Node in best.get_children():
			if inner is Node3D:
				var at: Variant = _bounds(inner as Node3D).intersects_ray(from, dir)
				if at != null and from.distance_to(at) < inner_d:
					inner_best = inner as Node3D
					inner_d = from.distance_to(at)
		if inner_best:
			return inner_best
	return best


## Onde o mouse aponta. Por padrão no chão (atravessa as peças); on_top = pousa em cima do que tiver
## (mesa, balcão, caixote), menos as peças em `ignore`. null = céu.
func _ground_hit(screen: Vector2, ignore: Array = [], on_top: bool = false) -> Variant:
	var cam := _camera.camera
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	return _ray_surface(from, dir, ignore, on_top)


func _ray_surface(from: Vector3, dir: Vector3, ignore: Array, on_top: bool) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 2000.0, 1 | 4)
	var exclude: Array[RID] = []
	for i: int in 24:
		query.exclude = exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var item := _item_of(hit["collider"] as Node)
		if item != null and (not on_top or ignore.has(item)):
			exclude.append(hit["rid"])
			continue
		return hit["position"]
	return Plane(Vector3.UP, 0.0).intersects_ray(from, dir)


## Altura do chão (ou do que tiver embaixo, com on_top) neste ponto.
func _surface_y(point: Vector3, on_top: bool) -> Variant:
	var hit: Variant = _ray_surface(point + Vector3.UP * 60.0, Vector3.DOWN, [], on_top)
	return (hit as Vector3).y if hit != null else null


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var visuals: Array[Node] = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		visuals.append(node)
	for v: Node in visuals:
		var vi := v as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Light3D or vi is GPUParticles3D or vi is Label3D:
			continue
		var part := vi.global_transform * vi.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		box = AABB(node.global_position - Vector3(0.5, 0.0, 0.5), Vector3(1.0, 1.8, 1.0))
	return box


# --- desenho: grade, pegada, seleção e etiquetas ------------------------------------------------

func _process(_delta: float) -> void:
	var mesh := _lines.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var any := false
	_size_label.visible = false
	_footprint_fill.visible = false
	var focus: Variant = null
	if _ghost and _ghost.visible:
		var color := Color(0.45, 1.0, 0.5) if _ghost_ok else Color(1.0, 0.35, 0.3)
		_draw_footprint(mesh, _footprint(_ghost), _ghost.global_position.y, color)
		_fill_footprint(_footprint(_ghost), _ghost.global_position.y, color)
		focus = _ghost.global_position
		_show_size(_ghost)
		any = true
	for node: Node3D in selection:
		if not is_instance_valid(node) or not node.is_inside_tree() or node == level:
			continue
		var box := _bounds(node)
		_draw_box(mesh, box.grow(0.06), Color(1.0, 0.82, 0.3))
		_draw_footprint(mesh, _footprint(node), box.position.y, Color(1.0, 0.82, 0.3))
		if focus == null:
			_fill_footprint(_footprint(node), box.position.y, Color(1.0, 0.82, 0.3))
			focus = box.get_center()
			if selection.size() == 1:
				_show_size(node)
		any = true
	if not any:
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_end()
	# a grade aparece em volta do mouse (ou da peça escolhida)
	_grid_mesh.visible = snap and level != null
	if _grid_mesh.visible:
		var at: Variant = focus if focus != null else _ground_hit(_mouse)
		if at != null:
			var p: Vector3 = at
			_grid_mesh.global_position = Vector3(snappedf(p.x, grid * 4.0), p.y + 0.04, snappedf(p.z, grid * 4.0))
			var mat := _grid_mesh.material_override as ShaderMaterial
			mat.set_shader_parameter("celula", grid)
			mat.set_shader_parameter("centro", Vector2(p.x, p.z))
			mat.set_shader_parameter("raio", clampf(_camera.distance * 0.7, 10.0, 40.0))
	for entry: Dictionary in _labels:
		var target := entry["node"] as Node3D
		var label := entry["label"] as Label3D
		if is_instance_valid(target) and target.is_inside_tree():
			label.visible = true
			label.global_position = target.global_position + Vector3.UP * float(entry["height"])
		else:
			label.visible = false


func _show_size(node: Node3D) -> void:
	var box := _bounds(node)
	_size_label.visible = true
	_size_label.text = ("%.1f × %.1f m" % [box.size.x, box.size.z]).replace(".", ",")
	_size_label.global_position = Vector3(box.get_center().x, box.end.y + 0.6, box.get_center().z)


func _fill_footprint(rect: Rect2, y: float, color: Color) -> void:
	_footprint_fill.visible = true
	_footprint_fill.global_transform = Transform3D(Basis().scaled(Vector3(rect.size.x, 1, rect.size.y)),
		Vector3(rect.get_center().x, y + 0.05, rect.get_center().y))
	(_footprint_fill.material_override as StandardMaterial3D).albedo_color = Color(color, 0.28)


func _draw_footprint(mesh: ImmediateMesh, rect: Rect2, y: float, color: Color) -> void:
	mesh.surface_set_color(color)
	var h := y + 0.06
	var a := Vector3(rect.position.x, h, rect.position.y)
	var b := Vector3(rect.end.x, h, rect.position.y)
	var c := Vector3(rect.end.x, h, rect.end.y)
	var d := Vector3(rect.position.x, h, rect.end.y)
	for pair: Array in [[a, b], [b, c], [c, d], [d, a], [a, c], [b, d]]:
		mesh.surface_add_vertex(pair[0])
		mesh.surface_add_vertex(pair[1])


func _draw_box(mesh: ImmediateMesh, box: AABB, color: Color) -> void:
	mesh.surface_set_color(color)
	const EDGES := [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	for edge: Array in EDGES:
		mesh.surface_add_vertex(box.get_endpoint(edge[0]))
		mesh.surface_add_vertex(box.get_endpoint(edge[1]))


## Pisca a peça recém-colocada (para ver que entrou).
func _flash(piece: Node3D) -> void:
	var start := piece.scale
	piece.scale = start * 1.06
	create_tween().tween_property(piece, "scale", start, 0.18)


## Etiquetas no mapa para o que não se vê no jogo: começo, heróis esperando, falas, saídas, lutas, luzes.
func _refresh_labels() -> void:
	for entry: Dictionary in _labels:
		(entry["label"] as Label3D).queue_free()
	_labels.clear()
	if level == null:
		return
	for node: Node in level.find_children("*", "Node3D", true, false):
		var text := ""
		var height := 2.4
		var color := Color(1, 1, 1)
		if node.name == &"PlayerSpawn" and node.get_parent() == level:
			text = "▶ Começo"
			color = Color(0.5, 1.0, 0.55)
		elif node is HeroSpot:
			text = "Herói: %s" % (node as HeroSpot).hero_id
			color = Color(0.55, 0.85, 1.0)
		elif node is Interactable:
			var it := node as Interactable
			text = "F · %s" % it.prompt_text
			if it.action == Interactable.Action.TRAVEL:
				text += "  → %s" % it.target_scene.get_file().get_basename().capitalize()
			elif it.action == Interactable.Action.REST:
				text += "  (descanso)"
			height = 1.6
			color = Color(1.0, 0.85, 0.5)
		elif node is Encounter:
			text = "⚔ Luta: %s" % (node as Encounter).id()
			height = 3.2
			color = Color(1.0, 0.45, 0.4)
		elif node is Camera3D and node.owner == level:
			text = "🎥 %s" % node.name
			height = 0.3
			color = Color(0.75, 0.9, 1.0)
		if text == "":
			continue
		var label := Label3D.new()
		label.text = text
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.001
		label.font_size = 24
		label.outline_size = 8
		label.modulate = color
		_overlay.add_child(label)
		_labels.append({"node": node, "label": label, "height": height})


# --- painéis --------------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_tree()
	_refresh_labels()
	_update_status()


func _update_status() -> void:
	if _status == null:
		return
	_status.text = "%s%s   ·   %d peças%s" % [level_path.get_file(), " *" if dirty else "", items().size(),
		"   ·   %d escolhida(s)" % selection.size() if selection.size() > 1 else ""]


func _toast_text(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	var width := _toast.get_combined_minimum_size().x
	_toast.offset_left = -width / 2.0
	_toast.offset_right = width / 2.0
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## "Na fase": a fase inteira em árvore (o mesmo que o Godot mostra). Clique escolhe qualquer nó.
func _refresh_tree() -> void:
	if _tree == null:
		return
	_tree.clear()
	if level == null:
		return
	var root := _tree.create_item()
	_fill_tree(root, level)
	_sync_tree_selection()


func _fill_tree(item: TreeItem, node: Node) -> void:
	item.set_text(0, String(node.name) + ("  ⧉" if node.scene_file_path != "" and node != level else ""))
	item.set_metadata(0, node)
	if node.scene_file_path != "" and node != level and not level.is_editable_instance(node):
		item.set_tooltip_text(0, node.scene_file_path)
		item.collapsed = true
		return
	for child: Node in node.get_children():
		if child.owner == level or (child.owner != null and child.owner != level and node != level):
			var sub := _tree.create_item(item)
			_fill_tree(sub, child)
			if _is_group(child) or SYSTEM.has(String(child.name)):
				sub.collapsed = true


func _sync_tree_selection() -> void:
	if _tree == null or _tree.get_root() == null:
		return
	_syncing_tree = true
	_tree.deselect_all()
	if selection.size() == 1:
		var found := _find_tree_item(_tree.get_root(), selection[0])
		if found:
			var parent := found.get_parent()
			while parent:
				parent.collapsed = false
				parent = parent.get_parent()
			found.select(0)
			_tree.scroll_to_item(found)
	_syncing_tree = false


func _find_tree_item(item: TreeItem, node: Node) -> TreeItem:
	if item.get_metadata(0) == node:
		return item
	for child: TreeItem in item.get_children():
		var found := _find_tree_item(child, node)
		if found:
			return found
	return null


func _on_tree_selected() -> void:
	if _syncing_tree:
		return
	var node: Variant = _tree.get_selected().get_metadata(0)
	if node is Node3D:
		select_nodes([node])
		var box := _bounds(node as Node3D)
		_camera.focus(box.get_center(), maxf(box.get_longest_axis_size() * 2.5, 8.0))
	elif node is Node:
		selection.clear()
		_build_inspector(node as Node)


## Painel da direita: tudo o que dá para mudar na peça escolhida.
func _build_inspector(other: Node = null) -> void:
	if _inspector == null:
		return
	_section_box = null
	for child: Node in _inspector.get_children():
		_inspector.remove_child(child)
		child.queue_free()
	var node: Node = other if other else (selection[0] if selection.size() == 1 else null)
	if node == null:
		_add_note("Nada escolhido.\n\nPegue uma peça na Biblioteca (à esquerda) e clique no mapa para colocar.\nClique numa peça do mapa para mexer nela."
			if selection.is_empty() else "%d peças escolhidas.\nArraste, gire (Q/E), centralize na grade (C), duplique (Ctrl+D) ou apague (Del) todas juntas." % selection.size())
		return
	_add_header(String(node.name), _entry_name(node))
	if node == level:
		_add_section("Fase")
		_add_script_fields(level)
		_add_environment()
		return
	if node is Node3D:
		var actions := HFlowContainer.new()
		for spec: Array in [["↺ 90°", func() -> void: rotate_selection(PI / 2.0)], ["↻ 90°", func() -> void: rotate_selection(-PI / 2.0)],
				["Centralizar", center_selection], ["Duplicar", duplicate_selection], ["Apagar", delete_selection]]:
			_tool_button(actions, spec[0], "", spec[1])
		_inspector.add_child(actions)
	var name_edit := LineEdit.new()
	name_edit.text = node.name
	name_edit.editable = node.owner == level
	name_edit.text_submitted.connect(func(text: String) -> void:
		set_prop(node, "name", text.strip_edges().validate_node_name(), false)
		name_edit.text = node.name
		name_edit.release_focus())
	_add_row("Nome", name_edit)
	if node is Node3D:
		_add_section("Posição, giro e tamanho")
		_add_field(node, "position", "Posição")
		_add_field(node, "rotation_degrees", "Giro (°)")
		_add_field(node, "scale", "Tamanho")
		_add_field(node, "visible", "Visível")
	if node is Light3D:
		_add_section("Luz")
		for prop: String in ["light_color", "light_energy", "omni_range", "spot_range", "spot_angle", "shadow_enabled"]:
			if prop in node:
				_add_field(node, prop)
	_add_script_fields(node)
	var scripted: Array[Node] = []
	for inner: Node in node.find_children("*", "", true, false):
		if inner.get_script() != null and not _script_fields(inner).is_empty():
			scripted.append(inner)
	for inner: Node in scripted.slice(0, 8):
		_add_section(String(node.get_path_to(inner)), scripted.size() > 2 and not (inner is Interactable or inner is HeroSpot))
		_add_script_fields(inner)


## Nome da peça na biblioteca (ou o tipo do nó).
func _entry_name(node: Node) -> String:
	if node == level:
		return "Fase"
	if library.by_key.has(node.scene_file_path):
		return String(library.by_key[node.scene_file_path]["nome"])
	return node.scene_file_path.get_file() if node.scene_file_path != "" else node.get_class()


func _add_note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	_inspector.add_child(note)


func _add_header(title: String, kind: String) -> void:
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"TitleLabel"
	label.add_theme_font_size_override("font_size", 22)
	label.clip_text = true
	_inspector.add_child(label)
	var sub := Label.new()
	sub.text = kind
	sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.6))
	sub.add_theme_font_size_override("font_size", 13)
	_inspector.add_child(sub)


func _add_section(title: String, folded: bool = false) -> void:
	var button := Button.new()
	button.text = ("▸ " if folded else "▾ ") + title
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	_inspector.add_child(button)
	var box := VBoxContainer.new()
	box.visible = not folded
	_inspector.add_child(box)
	button.pressed.connect(func() -> void:
		box.visible = not box.visible
		button.text = ("▾ " if box.visible else "▸ ") + title)
	_section_box = box


func _add_row(title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 88
	label.clip_text = true
	label.tooltip_text = title
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("font_size", 15)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	(_section_box if _section_box and is_instance_valid(_section_box) and _section_box.get_parent() == _inspector else _inspector).add_child(row)


func _script_fields(node: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for prop: Dictionary in node.get_property_list():
		var usage := int(prop["usage"])
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			result.append(prop)
	return result


func _add_script_fields(node: Node) -> void:
	for prop: Dictionary in _script_fields(node):
		_add_field(node, String(prop["name"]))


## Um campo do painel, do jeito certo para o tipo da propriedade (texto, número, sim/não, cor, lista...).
func _add_field(object: Object, property: String, title: String = "") -> void:
	var info: Dictionary = {}
	for prop: Dictionary in object.get_property_list():
		if prop["name"] == property:
			info = prop
			break
	if info.is_empty():
		return
	if title == "":
		title = FIELD_NAMES.get(property, property.capitalize())
	var value: Variant = object.get(property)
	var hint := int(info["hint"])
	var hint_string := String(info["hint_string"])
	match int(info["type"]):
		TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = value
			check.toggled.connect(func(on: bool) -> void: set_prop(object, property, on, false))
			_add_row(title, check)
		TYPE_INT when hint == PROPERTY_HINT_ENUM:
			var options := OptionButton.new()
			var next := 0
			for part: String in hint_string.split(","):
				var bits := part.split(":")
				var id := int(bits[1]) if bits.size() > 1 else next
				var shown := ACTION_NAMES[id] if object is Interactable and property == "action" and id < ACTION_NAMES.size() else bits[0].capitalize()
				options.add_item(shown, id)
				next = id + 1
			options.select(options.get_item_index(int(value)))
			options.item_selected.connect(func(index: int) -> void:
				set_prop(object, property, options.get_item_id(index), false)
				_build_inspector.call_deferred())
			_add_row(title, options)
		TYPE_INT, TYPE_FLOAT:
			_add_row(title, _spin(float(value), hint, hint_string, int(info["type"]) == TYPE_INT,
				func(v: float) -> void: set_prop(object, property, int(v) if int(info["type"]) == TYPE_INT else v)))
		TYPE_STRING, TYPE_STRING_NAME:
			_add_row(title, _text_control(object, property, String(value), hint, hint_string))
		TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color = value
			picker.custom_minimum_size.y = 28
			picker.color_changed.connect(func(c: Color) -> void: set_prop(object, property, c))
			_add_row(title, picker)
		TYPE_VECTOR3:
			var row := HBoxContainer.new()
			for axis: int in 3:
				var v3: Vector3 = value
				var spin := _spin(v3[axis], PROPERTY_HINT_NONE, "", false, func(v: float) -> void:
					var now: Vector3 = object.get(property)
					now[axis] = v
					set_prop(object, property, now))
				spin.custom_minimum_size.x = 0
				spin.get_line_edit().add_theme_font_size_override("font_size", 13)
				row.add_child(spin)
				spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_add_row(title, row)
		TYPE_PACKED_STRING_ARRAY:
			var edit := TextEdit.new()
			edit.text = "\n".join(value as PackedStringArray)
			edit.custom_minimum_size.y = 96
			edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			edit.tooltip_text = "Uma frase por linha"
			edit.text_changed.connect(func() -> void: set_prop(object, property, PackedStringArray(edit.text.split("\n"))))
			_add_row(title, edit)
		_:
			var shown := Label.new()
			shown.text = _describe(value)
			shown.clip_text = true
			shown.tooltip_text = "Isto se edita no Godot"
			shown.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
			_add_row(title, shown)


func _spin(value: float, hint: int, hint_string: String, integer: bool, changed: Callable) -> SpinBox:
	var spin := SpinBox.new()
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.min_value = -100000.0
	spin.max_value = 100000.0
	spin.step = 1.0 if integer else 0.01
	if hint == PROPERTY_HINT_RANGE:
		var bits := hint_string.split(",")
		if bits.size() >= 2:
			spin.min_value = float(bits[0])
			spin.max_value = float(bits[1])
		if bits.size() >= 3 and bits[2].is_valid_float():
			spin.step = float(bits[2])
	spin.value = value
	spin.select_all_on_focus = true
	spin.custom_minimum_size.x = 80
	spin.value_changed.connect(changed)
	spin.get_line_edit().text_submitted.connect(func(_t: String) -> void: spin.get_line_edit().release_focus())
	return spin


func _text_control(object: Object, property: String, value: String, hint: int, hint_string: String) -> Control:
	if hint == PROPERTY_HINT_ENUM:
		var choices := OptionButton.new()
		var names := hint_string.split(",")
		for choice: String in names:
			choices.add_item(choice)
		choices.select(names.find(value))
		choices.item_selected.connect(func(i: int) -> void: set_prop(object, property, names[i], false))
		return choices
	if property == "hero_id":
		var heroes := OptionButton.new()
		var ids: Array = Game.HEROES.keys()
		for id: String in ids:
			heroes.add_item(id)
		heroes.select(ids.find(value))
		heroes.item_selected.connect(func(i: int) -> void:
			set_prop(object, property, String(ids[i]), false))
		return heroes
	if hint == PROPERTY_HINT_FILE and hint_string.contains("tscn"):
		var scenes := OptionButton.new()
		var paths: Array[String] = [""]
		scenes.add_item("(nenhuma)")
		var known: Array[String] = []
		known.assign(_levels)
		for dir: String in ["res://levels/arenas/"]:
			for file: String in DirAccess.get_files_at(dir):
				if file.ends_with(".tscn"):
					known.append(dir + file)
		if value != "" and not known.has(value):
			known.append(value)
		for path: String in known:
			paths.append(path)
			scenes.add_item(path.trim_prefix("res://"))
		scenes.select(paths.find(value))
		scenes.item_selected.connect(func(i: int) -> void:
			set_prop(object, property, paths[i], false)
			_refresh_labels())
		return scenes
	if hint == PROPERTY_HINT_MULTILINE_TEXT or value.length() > 40 or value.contains("\n"):
		var edit := TextEdit.new()
		edit.text = value
		edit.custom_minimum_size.y = 90
		edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		edit.text_changed.connect(func() -> void: set_prop(object, property, edit.text))
		return edit
	var line := LineEdit.new()
	line.text = value
	line.text_changed.connect(func(text: String) -> void: set_prop(object, property, text))
	line.text_submitted.connect(func(_t: String) -> void: line.release_focus())
	return line


func _describe(value: Variant) -> String:
	if value is Resource:
		var res := value as Resource
		return res.resource_path.get_file() if res.resource_path != "" else res.get_class()
	if value is Array:
		return "%d itens" % (value as Array).size()
	return str(value)


## Sol, céu e neblina da fase.
func _add_environment() -> void:
	var sun := level.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		_add_section("Sol")
		_add_field(sun, "light_color", "Cor")
		_add_field(sun, "light_energy", "Força")
		_add_field(sun, "rotation_degrees", "Direção (°)")
		_add_field(sun, "shadow_enabled", "Sombras")
	var world_env := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		if not world_env.environment.resource_path.contains("::") and world_env.environment.resource_path != "":
			_add_section("Céu e neblina")
			_add_note("O céu desta fase vem de %s (compartilhado). Para mudar só aqui:" % world_env.environment.resource_path.get_file())
			var own := Button.new()
			own.text = "Fazer um céu só desta fase"
			own.focus_mode = Control.FOCUS_NONE
			own.pressed.connect(func() -> void:
				set_prop(world_env, "environment", world_env.environment.duplicate(), false)
				_build_inspector(level))
			_inspector.add_child(own)
			return
		var env := world_env.environment
		_add_section("Céu e neblina")
		for prop: String in ["background_color", "ambient_light_color", "ambient_light_energy", "tonemap_exposure",
				"fog_enabled", "fog_light_color", "fog_density", "glow_enabled"]:
			_add_field(env, prop)
