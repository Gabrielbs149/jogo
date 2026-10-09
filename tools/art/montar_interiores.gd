extends SceneTree
## Dá para entrar nas casas e lojas de Arandu (D061): cada prédio modular (metadados "celulas" e "porta", vindos de
## tools/art/gerar_pecas.py) ganha um nó "Interior" com móveis, luz e moradores. Casas de família: cama, mesa com
## cadeiras e tapete, lareira, baú, estante, barris, prateleiras e lanternas, sorteados por casa (nenhuma igual à
## outra); de dia alguém em casa (na mesa ou na lareira), de noite dormindo na cama. Lojas têm planta própria
## (taverna, empório, capela, sapataria, conselho, estalagem, ferraria, alfaiate, boticário), com o dono lá dentro e
## placa na porta. Os móveis grandes têm colisão (caixa) e somem de longe (alcance de visão).
## Cada interior é salvo numa cena própria (levels/arandu/interiores/<prédio>.tscn) e entra na fase por um nó
## "Interior" (world/interior_sob_demanda.gd) que só carrega quando você chega perto. A placa da loja fica na fase.
## Rodar depois de gerar_pecas.py e dos montadores da fase. Pode rodar de novo: refaz os interiores.
## Uso: godot --headless --path . -s tools/art/montar_interiores.gd

const LEVEL := "res://levels/arandu/arandu.tscn"
const OBJ := "res://assets/kits/quaternius/objetos/"
const PROPS := "res://world/props/"
const WALL := 0.36  # espessura da parede para dentro
const VIEW := 42.0  # some de longe (m)
const OUT_DIR := "res://levels/arandu/interiores/"

## Lojas: nome do prédio na fase -> tipo (planta própria) e placa.
const SHOPS := {
	"Taverna": ["taverna", "Taverna do Caneco Torto"],
	"CasaDoMercador": ["emporio", "Empório"],
	"Capela": ["capela", ""],
	"Sapateiro": ["sapataria", "Sapataria"],
	"CasaDoConselho": ["conselho", "Conselho"],
	"Estalagem": ["estalagem", ""],
	"Ferreiro": ["ferraria", ""],
	"Casa_estreita": ["alfaiate", "Alfaiate"],
	"Casa_estreita_pedra2": ["boticario", "Boticário"],
}
## Itens: caminho, largura (x), fundura (z), altura, frente do modelo (+1 = olha para +Z, como o kit; -1 = -Z, como as
## peças do projeto) e se tem colisão.
const ITEMS := {
	"cama": [OBJ + "Bed_Twin1.gltf", 1.9, 2.45, 0.8, 1, true],
	"cama2": [OBJ + "Bed_Twin2.gltf", 1.9, 2.45, 0.8, 1, true],
	"mesa": [OBJ + "Table_Large.gltf", 2.85, 1.1, 0.8, 1, true],
	"cadeira": [OBJ + "Chair_1.gltf", 0.6, 0.6, 1.1, 1, true],
	"banquinho": [OBJ + "Stool.gltf", 0.5, 0.5, 0.6, 1, false],
	"banco": [OBJ + "Bench.gltf", 2.8, 0.55, 0.55, 1, true],
	"bau": [OBJ + "Chest_Wood.gltf", 1.3, 0.78, 0.7, 1, true],
	"estante": [OBJ + "Bookcase_2.gltf", 1.48, 0.44, 2.5, 1, true],
	"armario": [OBJ + "Cabinet.gltf", 1.38, 0.38, 1.0, 1, true],
	"criado": [OBJ + "Nightstand_Shelf.gltf", 0.72, 0.42, 1.2, 1, true],
	"barril": [OBJ + "Barrel.gltf", 0.72, 0.72, 0.9, 1, true],
	"barril_macas": [OBJ + "Barrel_Apples.gltf", 0.72, 0.72, 0.9, 1, true],
	"barris": [OBJ + "Barrel_Holder.gltf", 1.38, 0.78, 1.25, 1, true],
	"caixote": [OBJ + "Crate_Wooden.gltf", 0.88, 0.92, 0.9, 1, true],
	"castical": [OBJ + "CandleStick_Stand.gltf", 0.75, 0.75, 1.3, 1, false],
	"caldeirao": [OBJ + "Cauldron.gltf", 1.0, 0.98, 0.8, 1, true],
	"atril": [OBJ + "BookStand.gltf", 0.52, 0.54, 1.45, 1, false],
	"bancada": [OBJ + "Workbench.gltf", 2.04, 1.04, 0.9, 1, true],
	"armas": [OBJ + "WeaponStand.gltf", 1.4, 1.0, 1.1, 1, true],
	"bigorna": [OBJ + "Anvil.gltf", 1.1, 0.42, 0.56, 1, true],
	"rebolo": [OBJ + "Whetstone.gltf", 1.16, 0.92, 1.2, 1, true],
	"manequim": [OBJ + "Dummy.gltf", 0.82, 0.6, 1.9, 1, true],
	"caixa_metal": [OBJ + "Crate_Metal.gltf", 0.9, 0.9, 0.9, 1, true],
	"lareira": [PROPS + "lareira.tscn", 1.9, 0.92, 2.9, -1, false],
	"balcao": [PROPS + "balcao.tscn", 2.55, 0.85, 1.0, -1, false],
	"altar": [PROPS + "altar.tscn", 1.86, 0.86, 1.1, -1, false],
	"estante_potes": [PROPS + "estante_potes.tscn", 1.66, 0.44, 2.3, -1, false],
	"estante_pocoes": [PROPS + "estante_pocoes.tscn", 1.66, 0.44, 2.3, -1, false],
	"estante_livros": [PROPS + "estante_livros.tscn", 1.66, 0.44, 2.3, -1, false],
	"estante_tecidos": [PROPS + "estante_tecidos.tscn", 1.66, 0.44, 2.3, -1, false],
	"estante_ferramentas": [PROPS + "estante_ferramentas.tscn", 1.66, 0.44, 2.3, -1, false],
	"sacos": [PROPS + "sacos.tscn", 1.1, 1.0, 0.7, -1, false],
}
## O que o morador de casa diz quando você entra. *(proposta)*
const FALAS_CASA: Array[String] = ["— Ei! Isso aqui é casa de família, pequeno!", "— Fecha essa porta, tá entrando frio.",
	"— Se veio pedir, a panela tá vazia.", "— Ô, menino. Limpa os pés antes de entrar.", "— Tá perdido? A praça é pra lá.",
	"— Não tem nada pra roubar aqui, juro.", "— Quer sopa? ...Brincadeira. Não tem sopa."]

var level: Node3D
var rng := RandomNumberGenerator.new()
var _placed: Array[Rect2] = []
var _w: float
var _d: float
var _door_x: float
var _interior: Node3D
var _building: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	for i: int in 3:
		await process_frame
	var homes := 0
	var shops := 0
	for child: Node in level.get_node("Buildings").get_children():
		var b := child as Node3D
		if b == null or not b.has_meta("celulas"):
			continue
		for old_name: String in ["Interior", "PlacaLoja", "PlacaLojaTexto"]:
			var old := b.get_node_or_null(old_name)
			if old:
				b.remove_child(old)
				old.free()
		_building = b
		var cells: Vector2i = b.get_meta("celulas")
		_w = cells.x
		_d = cells.y
		_door_x = -_w + 1.0 + 2.0 * int(b.get_meta("porta", 0))
		_placed.clear()
		_interior = Node3D.new()
		_interior.name = "Interior" + String(b.name)
		root.add_child(_interior)
		rng.seed = hash(String(b.name)) ^ 61
		# a entrada fica livre (da porta até um passo e meio para dentro)
		if String(b.get_meta("frente", "")) == "arcos":
			_placed.append(Rect2(-_w, -_d, 2.0 * _w, 1.6))
		else:
			_placed.append(Rect2(_door_x - 0.85, -_d, 1.7, 1.9))
		var kind := String(SHOPS.get(String(b.name), ["lar", ""])[0])
		match kind:
			"taverna":
				_taverna()
			"emporio":
				_emporio()
			"capela":
				_capela()
			"sapataria":
				_sapataria()
			"conselho":
				_conselho()
			"estalagem":
				_estalagem()
			"ferraria":
				_ferraria()
			"alfaiate":
				_alfaiate()
			"boticario":
				_boticario()
			_:
				_lar()
		if kind == "lar":
			homes += 1
		else:
			shops += 1
			var title := String(SHOPS[String(b.name)][1])
			if title != "":
				_shop_sign(title)
		_light(Vector3(0, 2.6, 0), 0.75 if kind == "lar" else 1.1, maxf(_w, _d) * 1.9)
		_finish()
		# salva a cena do interior e põe na fase o nó que carrega ela quando você chega perto
		var path := OUT_DIR + String(b.name) + ".tscn"
		var scene := PackedScene.new()
		var err := scene.pack(_interior)
		if err == OK:
			err = ResourceSaver.save(scene, path)
		if err != OK:
			push_error("interior %s: %d" % [b.name, err])
		root.remove_child(_interior)
		_interior.free()
		var loader := Node3D.new()
		loader.name = "Interior"
		b.add_child(loader)
		loader.owner = level
		loader.set_script(load("res://world/interior_sob_demanda.gd"))
		loader.set("cena", path)
	print("casas mobiliadas: ", homes, "  lojas: ", shops)
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


# --- colocar coisas -----------------------------------------------------------------------------------

## Põe um item (do catálogo) no chão, no ponto (x, z) local do prédio, virado para `facing` (direção para onde a
## frente olha). Devolve o nó, ou null se bate em algo (e then nada é posto). force: põe mesmo batendo.
func _item(key: String, x: float, z: float, facing: Vector3, force: bool = false, y: float = 0.0) -> Node3D:
	var info: Array = ITEMS[key]
	var yaw := atan2(facing.x, facing.z)  # a frente do item vai para `facing`
	if int(info[4]) < 0:
		yaw += PI  # peças do projeto olham para -Z
	var width := float(info[1])
	var depth := float(info[2])
	var along_x := absf(facing.z) > absf(facing.x)
	var size := Vector2(width, depth) if along_x else Vector2(depth, width)
	var rect := Rect2(x - size.x / 2.0, z - size.y / 2.0, size.x, size.y)
	if not force:
		if not _inside(rect):
			return null
		for other: Rect2 in _placed:
			if other.grow(-0.04).intersects(rect):
				return null
	var node := (load(String(info[0])) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = key.capitalize().replace(" ", "")
	_interior.add_child(node, true)
	node.owner = _interior
	node.position = Vector3(x, y, z)
	node.rotation.y = yaw
	_placed.append(rect)
	if bool(info[5]):
		_box(rect, float(info[3]))
	return node


## Encosta um item numa parede: "fundo" (+Z), "esq" (-X), "dir" (+X), "frente" (-Z), na posição t (0..1) ao longo dela.
func _wall_item(key: String, wall: String, t: float) -> Node3D:
	var info: Array = ITEMS[key]
	var depth := float(info[2])
	var lim_x := _w - WALL
	var lim_z := _d - WALL
	match wall:
		"fundo":
			return _item(key, lerpf(-lim_x + float(info[1]) / 2.0, lim_x - float(info[1]) / 2.0, t), lim_z - depth / 2.0, Vector3.BACK * -1.0)
		"frente":
			return _item(key, lerpf(-lim_x + float(info[1]) / 2.0, lim_x - float(info[1]) / 2.0, t), -lim_z + depth / 2.0, Vector3.BACK)
		"esq":
			return _item(key, -lim_x + depth / 2.0, lerpf(-lim_z + float(info[1]) / 2.0, lim_z - float(info[1]) / 2.0, t), Vector3.RIGHT)
		"dir":
			return _item(key, lim_x - depth / 2.0, lerpf(-lim_z + float(info[1]) / 2.0, lim_z - float(info[1]) / 2.0, t), Vector3.LEFT)
	return null


## Tenta encostar numa parede qualquer (sorteando lugar) até caber. Devolve o nó ou null.
func _somewhere(key: String, walls: Array = ["fundo", "esq", "dir"], tries: int = 14) -> Node3D:
	for k: int in tries:
		var node := _wall_item(key, walls[rng.randi() % walls.size()], rng.randf())
		if node:
			return node
	return null


func _inside(r: Rect2) -> bool:
	var room := Rect2(-_w + WALL, -_d + WALL, 2.0 * (_w - WALL), 2.0 * (_d - WALL))
	return room.encloses(r)


## Coisa pequena em cima de algo (mesa, balcão): sem colisão e sem ocupar chão.
func _small(path: String, at: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	_interior.add_child(node, true)
	node.owner = _interior
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	return node


## Presa na parede (prateleira, lanterna, gancho), na altura y.
func _on_wall(path: String, wall: String, t: float, y: float, size: float = 1.0, project_front: bool = false) -> void:
	var lim_x := _w - WALL
	var lim_z := _d - WALL
	var at := Vector3.ZERO
	var facing := Vector3.ZERO
	match wall:
		"fundo":
			at = Vector3(lerpf(-lim_x + 0.7, lim_x - 0.7, t), y, lim_z)
			facing = Vector3.FORWARD
		"esq":
			at = Vector3(-lim_x, y, lerpf(-lim_z + 0.7, lim_z - 0.7, t))
			facing = Vector3.RIGHT
		"dir":
			at = Vector3(lim_x, y, lerpf(-lim_z + 0.7, lim_z - 0.7, t))
			facing = Vector3.LEFT
	var yaw := atan2(facing.x, facing.z)
	if project_front:
		yaw += PI
	_small(path, at, yaw, size)


func _box(r: Rect2, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Colisao"
	_interior.add_child(body, true)
	body.owner = _interior
	body.position = Vector3(r.get_center().x, height / 2.0, r.get_center().y)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(r.size.x - 0.06, 0.1), height, maxf(r.size.y - 0.06, 0.1))
	shape.shape = box
	body.add_child(shape)
	shape.owner = _interior


func _light(at: Vector3, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Luz"
	_interior.add_child(light, true)
	light.owner = _interior
	light.position = at
	light.light_color = Color(1.0, 0.72, 0.45)
	light.light_energy = energy
	light.omni_range = clampf(reach, 4.0, 9.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 32.0
	light.distance_fade_length = 10.0


## Mesa no meio com cadeiras, tapete embaixo e coisas em cima (prato, caneca, pão, vela).
func _table_set(center: Vector2, chairs: int, rug: String = "") -> bool:
	if rug != "":
		var r := _small(PROPS + rug + ".tscn", Vector3(center.x, 0, center.y), 0.0 if rng.randf() < 0.5 else PI / 2.0)
		r.name = "Tapete"
	var table := _item("mesa", center.x, center.y, Vector3.BACK)
	if table == null:
		return false
	var spots := [Vector2(-0.75, -0.85), Vector2(0.75, -0.85), Vector2(-0.75, 0.85), Vector2(0.75, 0.85), Vector2(-1.8, 0), Vector2(1.8, 0)]
	for k: int in mini(chairs, spots.size()):
		var s: Vector2 = spots[k]
		var at := center + s
		var face := Vector3(-s.x if absf(s.y) < 0.1 else 0.0, 0, -signf(s.y) if absf(s.y) > 0.1 else 0.0).normalized()
		_item("cadeira" if rng.randf() < 0.7 else "banquinho", at.x, at.y, face)
	# em cima da mesa
	var top := 0.82
	_small(OBJ + "Table_Plate.gltf", Vector3(center.x - 0.6, top, center.y - 0.15))
	_small(OBJ + "Mug.gltf", Vector3(center.x - 0.25, top, center.y - 0.2), rng.randf() * TAU)
	_small(OBJ + "CandleStick.gltf", Vector3(center.x + 0.4, top, center.y + 0.1), rng.randf() * TAU)
	if rng.randf() < 0.6:
		_small(PROPS + "pao.tscn", Vector3(center.x + 0.8, top + 0.02, center.y - 0.2), rng.randf() * TAU, 1.5)
	if rng.randf() < 0.4:
		_small(OBJ + "Bottle_1.gltf", Vector3(center.x + 0.05, top, center.y + 0.25), 0.0)
	return true


## Alguém na casa/loja: Morador com horário, gestos e falas (o "Talk" de quem mora: F conversa).
func _person(at: Vector3, yaw: float, model: String, anim: Array, de: float, ate: float, line: String, emotes: Array = [],
		hue: float = -1.0, hand: String = "", gestos_troca: Vector2 = Vector2(6, 14), sem_chapeu: bool = true) -> Node3D:
	var person := (load(PROPS + "morador.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	person.name = "Morador"
	_interior.add_child(person, true)
	person.owner = _interior
	var first := String(anim[0])
	if first.begins_with("Sit_Chair"):
		at.y += 0.35  # na altura do assento (como os sentados da praça)
	person.position = at
	person.rotation.y = yaw
	var fig := person.get_node("Figure")
	fig.set("personagem", model)
	fig.set("animacao", String(anim[0]))
	fig.set("cor_roupa", hue)
	fig.set("sem_chapeu", sem_chapeu)
	fig.set("na_mao", hand)
	var talk := person.get_node("Talk")
	talk.set("prompt_text", "Falar")
	talk.set("text", line)
	person.set_script(load("res://world/vida/morador.gd"))
	person.set("de", de)
	person.set("ate", ate)
	var gestures: Array[String] = []
	for g: Variant in anim:
		gestures.append(String(g))
	person.set("gestos", gestures)
	person.set("troca", gestos_troca)
	var em: Array[String] = []
	for e: Variant in emotes:
		em.append(String(e))
	person.set("emotes", em)
	# sentado ou deitado não vira o corpo para olhar quem entra
	person.set("olha", not (first.begins_with("Sit") or first.begins_with("Lie")))
	_interior.set_editable_instance(person, true)
	return person


## Liga as coisas de longe: visibilidade por distância nos modelos do interior.
func _finish() -> void:
	for found: Node in _interior.find_children("*", "GeometryInstance3D", true, false):
		var g := found as GeometryInstance3D
		g.visibility_range_end = VIEW
		g.visibility_range_end_margin = 4.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _shop_sign(title: String) -> void:
	var wood := load("res://assets/materials/tabuas.tres") as Material
	var board := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(1.2, title.length() * 0.13), 0.42, 0.06)
	board.mesh = mesh
	board.material_override = wood
	board.name = "PlacaLoja"
	_building.add_child(board, true)
	board.owner = level
	board.position = Vector3(_door_x, 2.62, -_d - 0.16)
	var label := Label3D.new()
	label.name = "PlacaLojaTexto"
	label.text = title
	label.font = load("res://assets/fonts/cinzel.ttf")
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color(0.25, 0.13, 0.06)
	label.outline_size = 0
	label.double_sided = false
	_building.add_child(label, true)
	label.owner = level
	label.position = Vector3(_door_x, 2.6, -_d - 0.2)
	label.rotation.y = PI


# --- casas de família ---------------------------------------------------------------------------------

func _lar() -> void:
	var big := _w >= 3
	# a cama (uma ou duas) num canto do fundo; a lareira no fundo também, se couber
	var bed_side := -1.0 if rng.randf() < 0.5 else 1.0
	var beds: Array[Node3D] = []
	var bed := _item("cama" if rng.randf() < 0.5 else "cama2", bed_side * (_w - WALL - 0.96), _d - WALL - 1.23, Vector3.FORWARD)
	if bed:
		beds.append(bed)
	if big and rng.randf() < 0.55:
		var bed2 := _item("cama2", bed_side * (_w - WALL - 0.96 - 2.05), _d - WALL - 1.23, Vector3.FORWARD)
		if bed2:
			beds.append(bed2)
	if bed:
		_item("criado", bed_side * (_w - WALL - 0.96) - bed_side * 1.35, _d - WALL - 0.21, Vector3.FORWARD)
	if big or rng.randf() < 0.5:
		_somewhere("lareira", ["fundo", "dir" if bed_side < 0 else "esq"])
	# mesa no meio (casas grandes) ou encostada (casas estreitas)
	var center := Vector2(0, -0.2 if _d >= 3 else 0.0)
	if big:
		_table_set(center, rng.randi_range(2, 4), ["tapete", "tapete_azul", "tapete_verde"][rng.randi() % 3])
	else:
		_item("mesa", 0, -0.4, Vector3.BACK)
		_item("banquinho", -0.8, 0.35, Vector3.FORWARD)
		_item("banquinho", 0.7, 0.35, Vector3.FORWARD)
		_small(OBJ + "Mug.gltf", Vector3(0.2, 0.82, -0.5))
		_small(OBJ + "CandleStick.gltf", Vector3(-0.5, 0.82, -0.45))
	for key: String in ["bau", "estante" if rng.randf() < 0.5 else "armario", "barril", "caixote", "barril_macas" if rng.randf() < 0.4 else "castical"]:
		_somewhere(key, ["esq", "dir", "fundo"])
	# prateleira com potes e lanterna na parede
	_on_wall(OBJ + "Shelf_Simple.gltf", "esq" if bed_side > 0 else "dir", rng.randf_range(0.2, 0.8), 1.55, 1.0, false)
	_on_wall(OBJ + "Pot_1.gltf", "esq" if bed_side > 0 else "dir", 0.5, 1.6, 0.5, false)
	if rng.randf() < 0.7:
		_on_wall(PROPS + "lanterna.tscn", "fundo", rng.randf(), 2.0, 1.0, true)
	if big and rng.randf() < 0.5:
		_small(OBJ + "Chandelier.gltf", Vector3(center.x, 3.05, center.y))
	# quem mora: de dia em casa (na mesa ou na lareira), de noite dormindo na cama
	if rng.randf() < 0.55 or beds.size() > 0 and rng.randf() < 0.4:
		var models := ["Barbarian", "Mage", "Rogue", "Rogue_Hooded"]
		var model: String = models[rng.randi() % models.size()]
		var hue: float = [-1.0, 0.1, 0.3, 0.5, 0.65, 0.85][rng.randi() % 6]
		var line := FALAS_CASA[rng.randi() % FALAS_CASA.size()]
		var day_at := Vector3(center.x - 0.75, 0, center.y - 0.85) if big else Vector3(-0.8, 0, 0.35)
		_person(day_at, PI if big else 0.0, model, ["Sit_Chair_Idle", "Sit_Chair_Idle", "Interact"] if big else ["Idle", "Interact", "Use_Item"],
			7.0, 21.0, line, ["...", "nota", "?"], hue)
		if not beds.is_empty():
			var b := beds[0]
			_person(b.position + Vector3(0, 0.55, 0), b.rotation.y, model, ["Lie_Idle"], 21.0, 7.0, "— Zzz... só mais cinco minutos...",
				["zz", "zz", "zz"], hue, "", Vector2(30, 60))


# --- lojas ---------------------------------------------------------------------------------------------

func _taverna() -> void:
	# o balcão atravessa o fundo; atrás dele, barris de cerveja e prateleira de garrafas
	var z_bar := _d - WALL - 1.9
	_item("balcao", -1.3, z_bar, Vector3.FORWARD, true)
	_item("balcao", 1.25, z_bar, Vector3.FORWARD, true)
	_wall_item("barris", "fundo", 0.2)
	_wall_item("barris", "fundo", 0.75)
	_on_wall(OBJ + "Shelf_Small_Bottles.gltf", "fundo", 0.5, 1.45)
	_on_wall(OBJ + "Shelf_Small_Bottles.gltf", "fundo", 0.95, 1.45)
	for k: int in 5:
		_small(OBJ + "Mug.gltf", Vector3(-2.3 + k * 0.9, 0.98, z_bar - 0.1), rng.randf() * TAU)
	_person(Vector3(0.0, 0, z_bar + 0.85), PI, "Barbarian", ["Interact", "Use_Item", "Idle", "Cheer"], 9.0, 2.0,
		"— Bem-vindo ao Caneco Torto! Cerveja é pra quem paga. Água da fonte é de graça, lá fora.", ["nota", "..."], 0.08, "Mug")
	# mesas com fregueses
	_table_set(Vector2(-2.0, -1.0), 4, "tapete")
	_table_set(Vector2(2.0, -1.0), 3)
	_somewhere("lareira", ["esq", "dir"])
	_somewhere("barril", ["esq", "dir"])
	_somewhere("barril", ["esq", "dir"])
	_somewhere("banco", ["esq", "dir"])
	_small(OBJ + "Chandelier.gltf", Vector3(-2.0, 3.05, -1.0))
	_small(OBJ + "Chandelier.gltf", Vector3(2.0, 3.05, -1.0))
	_on_wall(OBJ + "Banner_1.gltf", "esq", 0.5, 2.6)
	var tipsy := [["Barbarian", 0.55, "— Hic! Mais uma rodada, que hoje eu pago! ...Com o dinheiro dele.", "Mug"],
		["Rogue_Hooded", 0.3, "— Psst. Dizem que o Bren trapaceia nos dados. Eu acho que é sorte. Muita sorte.", ""],
		["Knight", 0.78, "— Folga da guarda. Não conta pro capitão.", "Mug"]]
	var seats := [Vector3(-2.75, 0, -1.85), Vector3(-1.25, 0, -0.15), Vector3(2.75, 0, -1.85)]
	var yaws := [0.0, PI, 0.0]
	for k: int in tipsy.size():
		var t: Array = tipsy[k]
		_person(seats[k], yaws[k], String(t[0]), ["Sit_Chair_Idle", "Sit_Chair_Idle", "Cheer"] if k != 1 else ["Sit_Chair_Idle"], 15.0, 1.0,
			String(t[2]), ["nota", "nota", "coracao", "..."], float(t[1]), String(t[3]))
	# o bardo no canto, tocando (a música da taverna toca dali)
	var bard := _person(Vector3(_w - WALL - 0.8, 0, -_d + WALL + 2.4), -PI / 2.0, "Mage", ["Cheer", "Idle", "Cheer", "Interact"], 17.0, 1.0,
		"— Quer ouvir a balada do kobold que roubou o sol? ...Eu ainda tô escrevendo o fim.", ["nota", "nota", "nota"], 0.92, "", Vector2(3, 7), false)
	var music := AudioStreamPlayer3D.new()
	music.name = "MusicaDoBardo"
	bard.add_child(music)
	music.owner = _interior
	music.stream = load("res://assets/audio/musica/taverna.wav") if ResourceLoader.exists("res://assets/audio/musica/taverna.wav") else null
	music.autoplay = music.stream != null
	music.unit_size = 3.0
	music.max_distance = 18.0
	music.volume_db = -8.0
	music.bus = &"Musica"


func _emporio() -> void:
	_item("balcao", _door_x + 1.9, -0.2, Vector3.LEFT if _door_x > 0 else Vector3.RIGHT, true)
	for key: String in ["estante_potes", "estante_tecidos", "estante_potes"]:
		_somewhere(key, ["fundo", "esq", "dir"])
	for key: String in ["barril_macas", "barril_macas", "caixote", "sacos", "barril"]:
		_somewhere(key, ["fundo", "esq", "dir"])
	for k: int in 3:
		var crate := _small(PROPS + ["caixote_macas", "caixa_cenoura", "caixa_couve"][k] + ".tscn", Vector3(-1.4 + k * 1.1, 0, 1.3), 0.0)
		crate.name = "Mercadoria"
	_small(OBJ + "Coin_Pile.gltf", Vector3(_door_x + 1.9, 0.98, -0.2))
	_person(Vector3(_door_x + 1.9 + (0.8 if _door_x < 0 else -0.8), 0, -0.2), PI / 2.0 if _door_x < 0 else -PI / 2.0, "Rogue", ["Idle", "Interact", "Use_Item"], 7.0, 19.0,
		"— Empório do Ferraz: tem de tudo, menos fiado. Principalmente fiado pra kobold.", ["?", "nota"], 0.45)


func _capela() -> void:
	_wall_item("altar", "fundo", 0.5)
	_on_wall(OBJ + "Banner_1.gltf", "fundo", 0.2, 2.7)
	_on_wall(OBJ + "Banner_1.gltf", "fundo", 0.78, 2.7)
	_item("castical", -1.6, _d - WALL - 0.6, Vector3.FORWARD)
	_item("castical", 1.6, _d - WALL - 0.6, Vector3.FORWARD)
	# bancos mais curtos (o banco do kit encolhido) dos dois lados de um corredor até o altar
	for row: int in 3:
		var z := 0.9 - row * 1.25
		for side: float in [-1.0, 1.0]:
			var pew := _small(OBJ + "Bench.gltf", Vector3(side * 1.4, 0, z), 0.0, 0.8)
			pew.name = "Banco"
			var r := Rect2(side * 1.4 - 1.12, z - 0.22, 2.24, 0.44)
			_placed.append(r)
			_box(r, 0.5)
	_person(Vector3(0, 0, _d - WALL - 1.5), PI, "Mage", ["Idle", "Interact", "Idle"], 6.0, 20.0,
		"— A Lua chama quem pode suportar, menino. Senta um pouco. Ninguém aqui pergunta de onde você veio.", ["...", "..."], 0.62, "", Vector2(8, 16), false)
	_person(Vector3(-1.4, 0.0, 0.25), PI, "Rogue_Hooded", ["Sit_Chair_Idle"], 8.0, 12.0, "— Shh. Tô rezando pela minha filha.", ["...", "gota"], 0.15)
	_person(Vector3(1.4, 0.0, -1.0), PI, "Barbarian", ["Sit_Chair_Idle"], 15.0, 19.0, "— Desde que as estrelas ficaram esquisitas, a capela vive cheia.", ["..."], 0.7)


func _sapataria() -> void:
	_somewhere("bancada", ["esq", "dir", "fundo"])
	_somewhere("estante_ferramentas", ["fundo", "esq", "dir"])
	_somewhere("caixote", ["esq", "dir", "fundo"])
	_somewhere("sacos", ["esq", "dir", "fundo"])
	_on_wall(OBJ + "Peg_Rack.gltf", "esq", 0.5, 1.6)
	_person(Vector3(0.3, 0, 0.6), PI, "Barbarian", ["Use_Item", "Interact", "Use_Item"], 8.0, 18.0,
		"— Bota nova? Pra esse pé de lagartixa? ...Eu faço. Mas você paga adiantado.", ["gota", "..."], 0.3)


func _conselho() -> void:
	_item("mesa", 0, 0.4, Vector3.BACK)
	_item("mesa", 0, -0.75, Vector3.BACK)
	for k: int in 4:
		var x := -1.0 + (k % 2) * 2.0
		var z := 0.4 if k < 2 else -0.75
		_item("cadeira", x, z + (0.85 if k < 2 else -0.85), Vector3.FORWARD if k < 2 else Vector3.BACK)
	_somewhere("estante", ["fundo", "esq", "dir"])
	_somewhere("estante_livros", ["fundo", "esq", "dir"])
	_somewhere("bau", ["esq", "dir"])
	_somewhere("atril", ["esq", "dir", "fundo"])
	_on_wall(OBJ + "Banner_1.gltf", "fundo", 0.5, 2.7)
	_small(OBJ + "Scroll_1.gltf", Vector3(-0.3, 0.82, 0.3))
	_small(OBJ + "Book_Stack_1.gltf", Vector3(0.6, 0.82, -0.7))
	_small(OBJ + "CandleStick_Triple.gltf", Vector3(0.0, 0.82, -0.2))
	_person(Vector3(1.0, 0, 1.25), PI, "Knight", ["Idle", "Interact"], 9.0, 17.0,
		"— O conselho está reunido. Assunto: a gente nova acampada perto da muralha. ...Não é da sua conta, pequeno.", ["...", "?"], -1.0, "", Vector2(8, 16), false)
	_person(Vector3(-1.0, 0.05, -1.6), 0.0, "Mage", ["Sit_Chair_Idle"], 10.0, 16.0,
		"— Ordem do dia: o preço da farinha, o poço da praça e... de novo os mendigos. Sempre os mendigos.", ["...", "gota"], 0.55)


func _estalagem() -> void:
	_item("balcao", _door_x + 2.2, -_d + WALL + 2.4, Vector3.LEFT if _door_x > 0 else Vector3.RIGHT, true)
	_on_wall(OBJ + "Peg_Rack.gltf", "esq" if _door_x > 0 else "dir", 0.2, 1.7)
	_somewhere("lareira", ["fundo"])
	_table_set(Vector2(-1.2, 0.8), 4, "tapete_azul")
	_table_set(Vector2(1.6, 3.0), 2)
	for key: String in ["bau", "barril", "estante", "castical"]:
		_somewhere(key, ["esq", "dir", "fundo"])
	_small(OBJ + "Chandelier.gltf", Vector3(0, 3.05, 1.0))
	_person(Vector3(_door_x + 2.2 + (0.8 if _door_x < 0 else -0.8), 0, -_d + WALL + 2.4), PI / 2.0 if _door_x < 0 else -PI / 2.0, "Rogue_Hooded",
		["Idle", "Interact", "Idle"], 0.0, 0.0, "— Quarto? Uma moeda de prata a noite. Pra você, duas: kobold ronca.", ["...", "nota"], 0.86)


func _ferraria() -> void:
	# a forja já vem no prédio (fundo à esquerda); bigorna na frente dela, bancada, armas e o barril de esfriar
	_placed.append(Rect2(-3.2, 2.2, 2.2, 1.6))
	_item("bigorna", -2.2, 1.0, Vector3.FORWARD, true)
	_wall_item("bancada", "dir", 0.6)
	_wall_item("armas", "fundo", 0.75)
	_somewhere("rebolo", ["dir", "esq"])
	_somewhere("barril", ["esq", "dir"])
	_somewhere("estante_ferramentas", ["fundo", "dir"])
	_somewhere("caixa_metal", ["esq", "dir", "fundo"])
	_on_wall(OBJ + "Peg_Rack.gltf", "dir", 0.3, 1.7)
	# o ferreiro da praça trabalha aqui dentro agora, na bigorna
	var smith := level.get_node_or_null("Crowd/FerreiroTrabalhando") as Node3D
	if smith:
		smith.global_transform = _building.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(-2.2, 0, 0.25))


func _alfaiate() -> void:
	_somewhere("bancada", ["fundo", "esq", "dir"])
	_somewhere("estante_tecidos", ["fundo", "esq", "dir"])
	_somewhere("estante_tecidos", ["fundo", "esq", "dir"])
	_somewhere("manequim", ["esq", "dir", "fundo"])
	_somewhere("manequim", ["esq", "dir", "fundo"])
	_somewhere("banquinho", ["esq", "dir"])
	_person(Vector3(0.2, 0, 0.2), PI, "Mage", ["Use_Item", "Interact", "Idle"], 8.0, 18.0,
		"— Um capuz desses? Furado assim? Me dá aqui que eu remendo. ...Não, de graça não.", ["?", "nota"], 0.82, "", Vector2(6, 12), false)


func _boticario() -> void:
	_somewhere("estante_pocoes", ["fundo", "esq", "dir"])
	_somewhere("estante_pocoes", ["fundo", "esq", "dir"])
	_somewhere("estante_livros", ["fundo", "esq", "dir"])
	_item("caldeirao", 0.2, 0.6, Vector3.BACK)
	_somewhere("atril", ["esq", "dir"])
	_on_wall(OBJ + "Peg_Rack.gltf", "esq", 0.6, 1.7)
	var glow := OmniLight3D.new()
	glow.name = "BrilhoDoCaldeirao"
	_interior.add_child(glow)
	glow.owner = _interior
	glow.position = Vector3(0.2, 1.1, 0.6)
	glow.light_color = Color(0.45, 1.0, 0.55)
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	_person(Vector3(-0.6, 0, -0.4), PI * 0.8, "Rogue_Hooded", ["Use_Item", "Interact", "Idle"], 8.0, 20.0,
		"— Chá pra tosse, unguento pra frieira, xarope pra saudade. Esse último ainda não funciona.", ["?", "...", "nota"], 0.35)
