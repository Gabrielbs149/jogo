class_name MapEditor
extends Node3D
## Editor de mapas dentro do jogo (F2 numa fase, ou "Editor de mapas" na tela inicial).
## A fase abre parada e vista de cima. Dá para colocar peças prontas (world/props), clicar e arrastar,
## girar, mudar tamanho e altura, apagar, duplicar, desfazer e editar tudo o que a peça tem no painel da
## direita (textos, falas, para onde a saída leva, cores, luz...). Salvar grava a própria .tscn da fase,
## o mesmo arquivo que o Godot abre. Testar joga a fase como está, sem salvar; F2 lá volta para cá.

signal selection_changed

const PROPS_DIR := "res://world/props/"
const LEVELS_DIR := "res://levels/"
## Fase usada de molde para "Nova fase" (fica só o chão, o sol e o que toda fase precisa).
const TEMPLATE := "res://levels/arandu/arandu.tscn"
## Nós que toda fase tem e que não se clicam no mapa (aparecem na aba Cena).
const SYSTEM: Array[String] = ["WorldEnvironment", "Sun", "Navigation", "CameraRig", "HUD", "FX", "Terrain", "Ground", "Embers"]
## Peças do catálogo: arquivo em world/props -> [nome no botão, categoria, grupo da fase onde entra, varia ao colocar, dica].
## Peça nova em world/props aparece sozinha em "Outras".
const CATALOG: Dictionary[String, Array] = {
	"casa": ["Casa", "Construções", "Buildings", false, "Casa de reboco com telhado de telha (6 x 6 m)"],
	"casa_barro": ["Casa de pedra", "Construções", "Buildings", false, "Casa de pedra com telhado de telha (6 x 6 m)"],
	"casa_grande": ["Sobrado", "Construções", "Buildings", false, "Sobrado de dois andares, pedra embaixo e reboco em cima (8 x 8 m)"],
	"casa_grande_barro": ["Sobrado enxaimel", "Construções", "Buildings", false, "Sobrado com o andar de cima em enxaimel (8 x 8 m)"],
	"muro": ["Muro", "Construções", "Walls", false, "Muro de pedra de 6 m"],
	"portao": ["Portão", "Construções", "Walls", false, "Arco de passagem entre muros"],
	"marquise": ["Marquise", "Construções", "Buildings", false, "Cobertura de madeira presa na parede (encoste o lado de trás na parede)"],
	"barraca": ["Barraca", "Construções", "Market", false, "Barraca de feira com frutas"],
	"barraca_carroca": ["Carrinho de feira", "Construções", "Market", false, "Carrinho de vendedor"],
	"poco": ["Poço", "Construções", "Buildings", false, "Poço de pedra com telhadinho"],
	"pilar": ["Pilar", "Construções", "Ruins", false, "Pilar de arenito (ruínas)"],
	"arvore": ["Árvore", "Natureza", "Trees", true, "Árvore comum (cada uma sai um pouco diferente)"],
	"arvore_pequena": ["Árvore pequena", "Natureza", "Trees", true, "Árvore pequena"],
	"pinheiro": ["Pinheiro", "Natureza", "Trees", true, "Pinheiro"],
	"arvore_torta": ["Árvore torta", "Natureza", "Trees", true, "Árvore grande e retorcida"],
	"arvore_morta": ["Árvore morta", "Natureza", "Trees", true, "Árvore seca, sem folhas"],
	"tronco_seco": ["Tronco seco", "Natureza", "Trees", true, "Tronco morto alto"],
	"toco": ["Toco", "Natureza", "Trees", true, "Toco de árvore"],
	"arbusto": ["Arbusto", "Natureza", "Trees", true, "Arbusto, sem colisão"],
	"arbusto_baixo": ["Arbusto florido", "Natureza", "Trees", true, "Arbusto com flores, sem colisão"],
	"suculenta": ["Planta", "Natureza", "Trees", true, "Planta de folhas grandes, sem colisão"],
	"samambaia": ["Samambaia", "Natureza", "Trees", true, "Samambaia, sem colisão"],
	"grama": ["Grama", "Natureza", "Trees", true, "Tufo de grama alta, sem colisão"],
	"flores": ["Flores", "Natureza", "Trees", true, "Flores, sem colisão"],
	"rocha": ["Rocha", "Natureza", "Rocks", true, "Rocha média"],
	"rocha_grande": ["Rocha grande", "Natureza", "Rocks", true, "Rocha grande"],
	"penhasco": ["Penhasco", "Natureza", "Rocks", true, "Rochedo enorme"],
	"pedregulhos": ["Caminho de pedras", "Natureza", "Rocks", true, "Pedras redondas no chão, sem colisão"],
	"pedras": ["Pedras no chão", "Natureza", "Rocks", true, "Pedras chatas no chão, sem colisão"],
	"pedrinhas": ["Pedrinha", "Natureza", "Rocks", true, "Pedrinha solta, sem colisão"],
	"caixote": ["Caixote", "Objetos", "Props", false, "Caixote de madeira"],
	"caixote_alto": ["Caixote grande", "Objetos", "Props", false, "Caixote grande"],
	"caixote_macas": ["Caixa de maçãs", "Objetos", "Props", false, "Caixinha com maçãs"],
	"barril": ["Barril", "Objetos", "Props", false, "Barril"],
	"barril_vinho": ["Barril de maçãs", "Objetos", "Props", false, "Barril cheio de maçãs"],
	"barris": ["Suporte de barris", "Objetos", "Props", false, "Barris deitados num suporte"],
	"balde": ["Balde", "Objetos", "Props", false, "Balde de madeira"],
	"cesto": ["Saco", "Objetos", "Props", false, "Saco de pano"],
	"jarro": ["Panela", "Objetos", "Props", false, "Panela de barro"],
	"vaso": ["Vaso", "Objetos", "Props", false, "Vaso de cerâmica"],
	"banquinho": ["Banquinho", "Objetos", "Props", false, "Banquinho"],
	"cadeira": ["Cadeira", "Objetos", "Props", false, "Cadeira"],
	"banco": ["Banco", "Objetos", "Props", false, "Banco de madeira"],
	"mesa": ["Mesa", "Objetos", "Props", false, "Mesa grande"],
	"bau": ["Baú", "Objetos", "Props", false, "Baú de madeira"],
	"bigorna": ["Bigorna", "Objetos", "Props", false, "Bigorna de ferreiro"],
	"bancada": ["Bancada", "Objetos", "Props", false, "Bancada de trabalho"],
	"caldeirao": ["Caldeirão", "Objetos", "Props", false, "Caldeirão"],
	"boneco_treino": ["Boneco de treino", "Objetos", "Props", false, "Boneco de palha para treinar"],
	"carroca": ["Carroça", "Objetos", "Props", false, "Carroça de madeira"],
	"cerca": ["Cerca", "Objetos", "Props", false, "Cerca de madeira de 2 m"],
	"grade_ferro": ["Grade de ferro", "Objetos", "Props", false, "Grade de ferro de 2 m"],
	"estandarte": ["Estandarte", "Objetos", "Props", false, "Estandarte de pano"],
	"pao": ["Pão", "Objetos", "Props", false, "Pão (com a metade escondida, para cenas)"],
	"meio_pao": ["Meio pão", "Objetos", "Props", false, "Metade de um pão"],
	"lanterna": ["Lanterna", "Objetos", "Lights", false, "Lanterna de parede acesa"],
	"tocha": ["Tocha", "Objetos", "Lights", false, "Tocha acesa"],
	"luz": ["Luz", "Objetos", "Lights", false, "Luz sozinha, que ilumina em volta"],
	"morador": ["Morador", "Gente e história", "People", false, "Pessoa da cidade: F mostra a fala. Escolha o personagem e a animação no painel"],
	"inscricao": ["Inscrição", "Gente e história", "Ruins", false, "Pedra com inscrição: F mostra o texto"],
	"fogueira": ["Fogueira", "Gente e história", "Places", false, "Fogueira: F descansa e enche a vida"],
	"saida": ["Saída", "Gente e história", "Places", false, "Arco: F leva para outra fase (escolha qual no painel)"],
	"lugar_heroi": ["Herói", "Gente e história", "HeroSpots", false, "Onde um herói espera para entrar no grupo (escolha qual no painel)"],
	"grupo_escaravelhos": ["Escaravelhos", "Inimigos", "Encounters", false, "Grupo com 2 Escaravelhos de Cinza: encostar leva para a luta"],
	"grupo_sentinela": ["Sentinela", "Inimigos", "Encounters", false, "Sentinela Estelar: encostar leva para a luta"],
	"grupo_guardiao": ["Guardião", "Inimigos", "Encounters", false, "O Último Guardião, chefe de Ethera"],
}
## Peças soltas dos kits (D026): aparecem no catálogo com busca. Pasta -> [categoria, grupo da fase].
const KITS: Dictionary[String, Array] = {
	"res://assets/kits/quaternius/vila/": ["Kit: peças de casa", "Buildings"],
	"res://assets/kits/quaternius/objetos/": ["Kit: objetos", "Props"],
	"res://assets/kits/quaternius/natureza/": ["Kit: natureza", "Trees"],
}
## Peças pequenas dos kits (menos que isso, em metros) não ganham colisão.
const KIT_MIN_COLLISION := 0.6
## Grupos que entram no mapa de navegação (os aliados e inimigos desviam deles).
const NAV_GROUPS: Array[String] = ["Buildings", "Walls", "Market", "Ruins", "Trees", "Rocks", "Props", "Places"]
const ACTION_NAMES: Array[String] = ["Mostrar texto", "Descansar", "Chamar herói", "Viajar"]
## Nomes dos campos no painel (o que não estiver aqui aparece com o nome do código).
const FIELD_NAMES: Dictionary[String, String] = {
	"chapter_title": "Nome da fase", "intro_lines": "Abertura", "start_story": "Texto do começo",
	"victory_text": "Texto de vitória", "defeat_text": "Texto de derrota", "skip_intro": "Pular abertura",
	"stabilize_after": "Levanta após (s)", "action": "F faz", "prompt_text": "Aviso na tela", "text": "Texto",
	"target_scene": "Leva para", "hero_id": "Herói", "encounter_id": "Nome da luta", "arena_scene": "Arena",
	"trigger_radius": "Começa a (m)", "after_text": "Texto ao vencer", "cloth_color": "Roupa", "trim_color": "Detalhe",
	"eye_color": "Olhos", "face_color": "Rosto", "body_scale": "Corpo", "robe_width": "Largura do manto",
	"leg_height": "Pernas", "peg_leg": "Perna de pau", "light_color": "Cor", "light_energy": "Força",
	"omni_range": "Alcance", "spot_range": "Alcance", "spot_angle": "Abertura", "shadow_enabled": "Sombras",
	"background_color": "Cor do fundo", "ambient_light_color": "Luz ambiente", "ambient_light_energy": "Força ambiente",
	"tonemap_exposure": "Exposição", "fog_enabled": "Neblina", "fog_light_color": "Cor da neblina",
	"fog_density": "Densidade", "glow_enabled": "Brilho", "display_name": "Nome", "max_hp": "Vida máx.",
	"hp": "Vida", "armor_class": "CA", "speed": "Velocidade", "personagem": "Personagem", "animacao": "Animação",
	"na_mao": "Na mão", "deslocamento": "Começa em (s)",
}
const HELP := "Clique: escolhe   Arrastar: move   Shift+clique: junta   Arrastar no vazio: seleciona área   Alt+clique: parte de dentro\n" \
	+ "Q/E: gira (Shift = 5°; com a grade ligada, 90°)   PgUp/PgDn: altura   +/- ou Ctrl+roda: tamanho   R: zera giro/tamanho   Del: apaga   Ctrl+D: duplica\n" \
	+ "Ctrl+Z/Ctrl+Y: desfaz/refaz   Ctrl+S: salva   G: grade   F: foca   T: de cima   WASD: anda   Botão dir.: gira   Meio: arrasta   Esc: solta"

## A fase aberta (raiz da cena) e o arquivo dela.
var level: Node3D
var level_path: String = ""
var selection: Array[Node3D] = []
var dirty: bool = false
var snap: bool = false
var grid: float = 0.5

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _placing: String = ""
var _ghost: Node3D
var _ghost_yaw: float = 0.0
var _ghost_scale: float = 1.0
var _press_pos: Vector2
var _pressing: bool = false
var _dragging: bool = false
var _boxing: bool = false
var _drag_hit: Vector3
var _drag_from: Array[Transform3D] = []
var _labels: Array[Dictionary] = []
var _syncing_tree: bool = false
var _hud_was_visible: bool = true
var _levels: PackedStringArray = []
var _after_confirm: Callable
var _section_box: VBoxContainer

@onready var _world: Node3D = $World
@onready var _camera: EditorCamera = $Camera
@onready var _overlay: Node3D = $Overlay
@onready var _lines: MeshInstance3D = $Overlay/Lines
@onready var _level_pick: OptionButton = %LevelPick
@onready var _status: Label = %Status
@onready var _catalog: VBoxContainer = %Catalog
@onready var _tree: Tree = $UI/Root/Left/Tabs/Cena
@onready var _inspector: VBoxContainer = %Inspector
@onready var _box: Panel = %Box
@onready var _toast: Label = %Toast
@onready var _help: Label = %Help
@onready var _snap_button: CheckButton = %Snap
@onready var _new_dialog: ConfirmationDialog = %NewDialog
@onready var _new_name: LineEdit = %NewName
@onready var _confirm: ConfirmationDialog = %Confirm


func _ready() -> void:
	Level.editing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_help.text = HELP
	_lines.mesh = ImmediateMesh.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.no_depth_test = true
	line_mat.vertex_color_use_as_albedo = true
	_lines.material_override = line_mat
	_build_catalog()
	%Save.pressed.connect(save)
	%Undo.pressed.connect(undo)
	%Redo.pressed.connect(redo)
	%LevelProps.pressed.connect(func() -> void: select_nodes([level]))
	%TopView.pressed.connect(_camera.toggle_top_view)
	%Test.pressed.connect(test_level)
	%NewLevel.pressed.connect(_ask_new_level)
	%Exit.pressed.connect(func() -> void: _leave(Game.go_to_title))
	_snap_button.toggled.connect(func(on: bool) -> void: snap = on)
	var grid_spin := SpinBox.new()
	grid_spin.min_value = 0.25
	grid_spin.max_value = 8.0
	grid_spin.step = 0.25
	grid_spin.value = grid
	grid_spin.suffix = "m"
	grid_spin.tooltip_text = "Tamanho da grade (as peças de casa dos kits encaixam em 2 m)"
	grid_spin.value_changed.connect(func(v: float) -> void: grid = v)
	_snap_button.get_parent().add_child(grid_spin)
	_snap_button.get_parent().move_child(grid_spin, _snap_button.get_index() + 1)
	_level_pick.item_selected.connect(_on_level_picked)
	_tree.item_selected.connect(_on_tree_selected)
	_new_dialog.confirmed.connect(_create_level)
	_confirm.confirmed.connect(func() -> void: _after_confirm.call())
	for button: Node in find_children("*", "BaseButton", true, false):
		(button as BaseButton).focus_mode = Control.FOCUS_NONE
	var path := Game.edit_level if Game.edit_level != "" else Game.ARANDU
	if Game.edit_draft != "" and FileAccess.file_exists(Game.edit_draft):
		open_level(path, Game.edit_draft)
		dirty = true
		_toast_text("Voltou do teste: o que não foi salvo continua aqui")
	else:
		open_level(path)
	Game.edit_draft = ""
	_update_status()


func _exit_tree() -> void:
	Level.editing = false
	_free_orphans()


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
	_world.add_child(level)
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
	var packed := PackedScene.new()
	var err := packed.pack(level)
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
	_new_dialog.popup_centered()
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
			if not (SYSTEM.has(String(child.name)) or child.name == &"PlayerSpawn"):
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
		var packed := PackedScene.new()
		packed.pack(fresh)
		fresh.free()
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if ResourceSaver.save(packed, path) != OK:
			_toast_text("Não deu para criar a fase (só rodando pelo Godot)")
			return
		open_level(path)
		_toast_text("Fase nova: %s. Coloque peças pelo catálogo e salve." % path))


# --- peças do catálogo ----------------------------------------------------------------------

func _build_catalog() -> void:
	var search := LineEdit.new()
	search.placeholder_text = "Buscar peça (ex.: porta, telhado, barril)"
	search.clear_button_enabled = true
	search.text_changed.connect(_filter_catalog)
	_catalog.add_child(search)
	var by_category: Dictionary[String, Array] = {}
	var order: Array[String] = []
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(PROPS_DIR):
		if file.ends_with(".tscn"):
			files.append(file.get_basename())
	var keys: Array[String] = []
	keys.assign(CATALOG.keys())
	for file: String in files:
		if not keys.has(file):
			keys.append(file)
	for key: String in keys:
		if not files.has(key):
			continue
		var category := String(CATALOG[key][1]) if CATALOG.has(key) else "Outras"
		if not by_category.has(category):
			by_category[category] = []
			order.append(category)
		by_category[category].append(key)
	for category: String in order:
		var entries: Array = []
		for key: String in by_category[category]:
			entries.append([key, String(CATALOG[key][0]) if CATALOG.has(key) else key.capitalize(),
				(String(CATALOG[key][4]) + "\n" if CATALOG.has(key) else "") + PROPS_DIR + key + ".tscn"])
		_add_catalog_section(category, entries, false)
	for dir: String in KITS:
		var entries: Array = []
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gltf") or file.ends_with(".glb"):
				entries.append([dir + file, file.get_basename().replace("_", " "), dir + file])
		if not entries.is_empty():
			_add_catalog_section(String(KITS[dir][0]) + " (%d)" % entries.size(), entries, true)


func _add_catalog_section(title: String, entries: Array, folded: bool) -> void:
	var header := Button.new()
	header.text = ("▸ " if folded else "▾ ") + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	header.set_meta("header", true)
	_catalog.add_child(header)
	var grid_box := GridContainer.new()
	grid_box.columns = 2
	grid_box.visible = not folded
	_catalog.add_child(grid_box)
	header.pressed.connect(func() -> void:
		grid_box.visible = not grid_box.visible
		header.text = ("▾ " if grid_box.visible else "▸ ") + title)
	for entry: Array in entries:
		var key: String = entry[0]
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.tooltip_text = entry[2]
		button.set_meta("key", key)
		button.set_meta("search", (String(entry[1]) + " " + key).to_lower())
		button.pressed.connect(func() -> void: start_placing(key if _placing != key else ""))
		grid_box.add_child(button)


## Busca no catálogo: mostra só as peças com esse texto (e abre as categorias que têm alguma).
func _filter_catalog(text: String) -> void:
	var query := text.strip_edges().to_lower()
	var children := _catalog.get_children()
	for i: int in children.size():
		var grid_box := children[i] as GridContainer
		if grid_box == null:
			continue
		var any := false
		for child: Node in grid_box.get_children():
			var button := child as Button
			button.visible = query == "" or String(button.get_meta("search", "")).contains(query)
			any = any or button.visible
		var header := children[i - 1] as Button
		if query != "":
			grid_box.visible = any
			header.visible = any
		else:
			header.visible = true
			grid_box.visible = not header.text.begins_with("▸")


func _scene_path(key: String) -> String:
	return key if key.begins_with("res://") else PROPS_DIR + key + ".tscn"


## Começa a colocar uma peça: ela segue o mouse; clique coloca (pode colocar várias), Esc para.
func start_placing(key: String) -> void:
	_cancel_placing()
	if key == "":
		return
	_placing = key
	_ghost_yaw = 0.0
	_ghost_scale = 1.0
	_ghost = (load(_scene_path(key)) as PackedScene).instantiate() as Node3D
	_overlay.add_child(_ghost)
	for body: Node in _ghost.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = 0
	_vary_ghost()
	_sync_catalog_buttons()
	_toast_text("Clique no mapa para colocar. Q/E gira. Esc para.")


## Coloca uma peça do catálogo neste ponto (é o que o clique faz). Devolve a peça colocada.
func place(key: String, at: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	var scene := load(_scene_path(key)) as PackedScene
	var piece := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	var parent := _container_for(key)
	parent.add_child(piece, true)
	piece.owner = level
	piece.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), _snapped(at))
	if key.begins_with("res://") and _kit_collides(key, piece):
		piece.add_to_group("colisao_auto", true)  # a fase dá colisão do formato da peça
	_push({"kind": "add", "nodes": [piece], "parents": [parent], "indexes": [piece.get_index()], "owned": [_owned_paths(piece)]})
	dirty = true
	_refresh_all()
	select_nodes([piece])
	return piece


func _cancel_placing() -> void:
	_placing = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if is_node_ready():
		_sync_catalog_buttons()


func _vary_ghost() -> void:
	if CATALOG.has(_placing) and CATALOG[_placing][3]:
		_ghost_yaw = randf() * TAU
		_ghost_scale = randf_range(0.8, 1.25)
	if _ghost:
		_ghost.scale = Vector3.ONE * _ghost_scale
		_ghost.rotation.y = _ghost_yaw


func _sync_catalog_buttons() -> void:
	for node: Node in _catalog.find_children("*", "Button", true, false):
		var button := node as Button
		button.set_pressed_no_signal(String(button.get_meta("key", "")) == _placing)


## Peça solta de kit: paredes e móveis ganham colisão; plantas e coisas pequenas, não.
func _kit_collides(path: String, piece: Node3D) -> bool:
	var file := path.get_file()
	if path.contains("/natureza/"):
		return file.begins_with("Rock_") or file.begins_with("DeadTree") or file.begins_with("TwistedTree")
	var box := _bounds(piece)
	return maxf(box.size.x, maxf(box.size.y, box.size.z)) >= KIT_MIN_COLLISION


## O grupo da fase onde a peça entra (cria o grupo se a fase ainda não tem).
func _container_for(key: String) -> Node3D:
	var group_name := String(CATALOG[key][2]) if CATALOG.has(key) else "Props"
	for dir: String in KITS:
		if key.begins_with(dir):
			group_name = String(KITS[dir][1])
			if dir.ends_with("natureza/") and key.get_file().begins_with("Rock"):
				group_name = "Rocks"
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
	if event.ctrl_pressed and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var factor := 1.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.08
		if _ghost:
			_ghost_scale *= factor
			_ghost.scale = Vector3.ONE * _ghost_scale
		else:
			scale_selection(factor)
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if _placing != "":
			var hit: Variant = _ground_hit(event.position)
			if hit != null:
				place(_placing, hit, _ghost_yaw, _ghost_scale)
				_vary_ghost()
			return
		_press_pos = event.position
		_pressing = true
		var picked := _pick(event.position, event.alt_pressed)
		if picked == null:
			_boxing = true
			if not event.shift_pressed:
				select_nodes([])
			return
		if event.shift_pressed:
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
		var hit: Variant = _ground_hit(event.position)
		_drag_hit = hit if hit != null else picked.global_position
		_drag_from.clear()
		for node: Node3D in selection:
			_drag_from.append(node.global_transform)
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


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _ghost:
		var hit: Variant = _ground_hit(event.position)
		_ghost.visible = hit != null
		if hit != null:
			_ghost.global_position = _snapped(hit)
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
	if selection.is_empty() or _drag_from.size() != selection.size():
		return
	_dragging = true
	var hit: Variant = _ground_hit(event.position)
	if hit == null:
		return
	var delta: Vector3 = (hit as Vector3) - _drag_hit
	# a primeira peça "manda" na grade; as outras andam junto, do mesmo tanto
	var lead := _drag_from[0].origin + delta
	delta += _snapped(lead) - lead
	for i: int in selection.size():
		var xf := _drag_from[i]
		xf.origin += delta
		selection[i].global_transform = xf


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
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if event.echo and key not in [KEY_Q, KEY_E, KEY_PAGEUP, KEY_PAGEDOWN, KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
		return
	match key:
		KEY_Q, KEY_E:
			var step := deg_to_rad(5.0 if fine else (90.0 if snap else 15.0)) * (1.0 if key == KEY_Q else -1.0)
			if _ghost:
				_ghost_yaw += step
				_ghost.rotation.y = _ghost_yaw
			else:
				rotate_selection(step)
		KEY_PAGEUP, KEY_PAGEDOWN:
			move_selection(Vector3.UP * (1.0 if fine else 0.25) * (1.0 if key == KEY_PAGEUP else -1.0))
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			scale_selection(1.1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			scale_selection(1.0 / 1.1)
		KEY_R:
			_transform_selection(func(n: Node3D) -> Transform3D: return Transform3D(Basis(), n.transform.origin))
		KEY_DELETE, KEY_BACKSPACE:
			delete_selection()
		KEY_G:
			_snap_button.button_pressed = not _snap_button.button_pressed
			_toast_text("Grade de %s m: %s" % [grid, "ligada" if snap else "desligada"])
		KEY_T:
			_camera.toggle_top_view()
		KEY_F:
			if not selection.is_empty():
				var box := _bounds(selection[0])
				_camera.focus(selection[0].global_position, maxf(box.get_longest_axis_size() * 2.5, 8.0))
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
	selection_changed.emit()


func rotate_selection(angle: float) -> void:
	_transform_selection(func(n: Node3D) -> Transform3D: return n.transform.rotated_local(Vector3.UP, angle))


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
		var offset := _camera.ground_axes()[1] * maxf(grid * 2.0, 1.0)
		copy.global_position += offset
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
## Um Node3D simples feito só de malhas e colisão (o poço) é uma peça, não um grupo.
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


## Onde o mouse aponta no chão (terreno, piso), atravessando as peças. null = céu.
func _ground_hit(screen: Vector2) -> Variant:
	var cam := _camera.camera
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 2000.0, 1 | 4)
	var exclude: Array[RID] = []
	for i: int in 16:
		query.exclude = exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		if _item_of(hit["collider"] as Node) != null:
			exclude.append(hit["rid"])
			continue
		return hit["position"]
	return Plane(Vector3.UP, 0.0).intersects_ray(from, dir)


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var visuals: Array[Node] = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		visuals.append(node)
	for v: Node in visuals:
		var vi := v as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Light3D or vi is GPUParticles3D:
			continue
		var part := vi.global_transform * vi.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		box = AABB(node.global_position - Vector3(0.5, 0.0, 0.5), Vector3(1.0, 1.8, 1.0))
	return box


func _snapped(point: Vector3) -> Vector3:
	if not snap:
		return point
	return Vector3(snappedf(point.x, grid), point.y, snappedf(point.z, grid))


# --- desenho: seleção e etiquetas -----------------------------------------------------------

func _process(_delta: float) -> void:
	var mesh := _lines.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var any := false
	for node: Node3D in selection:
		if not is_instance_valid(node) or not node.is_inside_tree() or node == level:
			continue
		if not any:
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		_draw_box(mesh, _bounds(node).grow(0.08), Color(1.0, 0.82, 0.3))
	if any:
		mesh.surface_end()
	for entry: Dictionary in _labels:
		var target := entry["node"] as Node3D
		var label := entry["label"] as Label3D
		if is_instance_valid(target) and target.is_inside_tree():
			label.visible = true
			label.global_position = target.global_position + Vector3.UP * float(entry["height"])
		else:
			label.visible = false


func _draw_box(mesh: ImmediateMesh, box: AABB, color: Color) -> void:
	mesh.surface_set_color(color)
	for i: int in 12:
		var edge := _box_edge(box, i)
		mesh.surface_add_vertex(edge[0])
		mesh.surface_add_vertex(edge[1])


func _box_edge(box: AABB, i: int) -> Array[Vector3]:
	const EDGES := [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	return [box.get_endpoint(EDGES[i][0]), box.get_endpoint(EDGES[i][1])]


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
		elif node is OmniLight3D and node.owner == level:
			text = "✦ Luz"
			height = 0.4
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
	if not is_node_ready():
		return
	_status.text = "%s%s   ·   %d peças%s" % [level_path.get_file(), " *" if dirty else "", items().size(),
		"   ·   %d escolhida(s)" % selection.size() if selection.size() > 1 else ""]


func _toast_text(text: String) -> void:
	if not is_node_ready():
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.6)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Aba "Cena": a fase inteira em árvore (o mesmo que o Godot mostra). Clique escolhe qualquer nó.
func _refresh_tree() -> void:
	if not is_node_ready():
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
		for inner: Node in node.get_children():
			if inner is Node3D and inner.owner == node:
				_fill_tree(_tree.create_item(item), inner)
		return
	for child: Node in node.get_children():
		if child.owner == level or (child.owner != null and child.owner != level and node != level):
			var sub := _tree.create_item(item)
			_fill_tree(sub, child)
			if _is_group(child) or SYSTEM.has(String(child.name)):
				sub.collapsed = true


func _sync_tree_selection() -> void:
	if not is_node_ready() or _tree.get_root() == null:
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
	elif node is Node:
		selection.clear()
		_build_inspector(node as Node)


## Painel da direita: tudo o que dá para mudar na peça escolhida.
func _build_inspector(other: Node = null) -> void:
	if not is_node_ready():
		return
	_section_box = null
	for child: Node in _inspector.get_children():
		_inspector.remove_child(child)
		child.queue_free()
	var node: Node = other if other else (selection[0] if selection.size() == 1 else null)
	if node == null:
		_add_note("Nada escolhido.\n\nClique numa peça no mapa, escolha uma na aba Cena ou pegue uma peça no catálogo." if selection.is_empty()
			else "%d peças escolhidas.\nArraste, gire (Q/E), mude o tamanho (+/-), duplique (Ctrl+D) ou apague (Del) todas juntas." % selection.size())
		return
	_add_header(String(node.name), node.scene_file_path.get_file() if node.scene_file_path != "" and node != level else node.get_class())
	if node == level:
		_add_section("Fase")
		_add_script_fields(level)
		_add_environment()
		return
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
	_add_colors(node)


func _add_note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	_inspector.add_child(note)


func _add_header(title: String, kind: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
	_inspector.add_child(label)
	var sub := Label.new()
	sub.text = kind
	sub.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
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
	label.custom_minimum_size.x = 104
	label.clip_text = true
	label.tooltip_text = title
	label.mouse_filter = Control.MOUSE_FILTER_PASS
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
				_build_inspector_later())
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


func _build_inspector_later() -> void:
	_build_inspector.call_deferred()


## Cores das partes da peça. A primeira mudança faz uma cópia da tinta, para não pintar as outras peças iguais.
func _add_colors(node: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for inner: Node in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(inner as MeshInstance3D)
	var seen: Array[Material] = []
	for mesh: MeshInstance3D in meshes:
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null or seen.has(mat) or seen.size() >= 10:
			continue
		if seen.is_empty():
			_add_section("Cores")
		seen.append(mat)
		var users: Array[MeshInstance3D] = []
		for other: MeshInstance3D in meshes:
			if other.material_override == mat:
				users.append(other)
		var picker := ColorPickerButton.new()
		picker.color = mat.albedo_color
		picker.custom_minimum_size.y = 28
		var own: Array[StandardMaterial3D] = [null]
		picker.color_changed.connect(func(c: Color) -> void:
			if own[0] == null:
				own[0] = mat.duplicate() as StandardMaterial3D
				for user: MeshInstance3D in users:
					set_prop(user, "material_override", own[0], false)
			set_prop(own[0], "albedo_color", c))
		_add_row(String(mesh.name), picker)


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
