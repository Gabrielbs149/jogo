extends SceneTree
## Monta Arandu (D027): planta da cidade, ruas, praça, casas, muralha, chão pintado, grama e decoração.
## Mantém o que é da história (moradores e falas, portão de saída, canto do Tico) e refaz o resto.
## Depois rode a montagem da cena do Tico (marquise, câmeras) e ajuste à mão no editor de mapas.
## ATENÇÃO: rodar de novo APAGA o que foi mudado à mão em prédios, ruas e decoração.
## Uso: godot --headless --path . -s tools/art/montar_arandu.gd

const PROPS := "res://world/props/"
const KIT := "res://assets/kits/quaternius/"
const LEVEL := "res://levels/arandu/arandu.tscn"
const ART := "res://levels/arandu/art/"
const AREA := 220.0
const MASK_PX := 1024
const HALF := 35.0  # muralha: quadrado de 70 m

## Tamanho das casas: [largura da fachada, fundo]
const SIZE := {
	"casa": Vector2(6, 6), "casa_barro": Vector2(6, 6), "casa_grande": Vector2(8, 8), "casa_grande_barro": Vector2(8, 8),
	"casa_estreita": Vector2(4, 6), "casa_estreita_pedra": Vector2(4, 6), "casa_longa": Vector2(6, 8),
	"sobrado_longo": Vector2(6, 8), "torre": Vector2(4, 4),
}

var level: Node3D
var rng := RandomNumberGenerator.new()
var mask: Image
var blocks: Array[Rect2] = []  # onde não nasce grama nem árvore (casas, muros, barracas)
var houses: Array[Dictionary] = []
var groups := {}
var tico_alley := Rect2()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 2027
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	await physics_frame
	_clear()
	mask = Image.create(MASK_PX, MASK_PX, false, Image.FORMAT_RGB8)
	mask.fill(Color(0, 0, 0))
	_streets()
	_town()
	_walls()
	_plaza()
	_story_spots()
	_yards()
	_crowd()
	_outside()
	_paint_ground()
	await physics_frame
	level.call("_auto_collision")  # para a grama não nascer dentro das casas novas
	await physics_frame
	_grass()
	_light_and_camera()
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


# --- ajudas ---------------------------------------------------------------------------------------

func _group(name: String, nav: bool = true) -> Node3D:
	if groups.has(name):
		return groups[name]
	var found := level.get_node_or_null(name) as Node3D
	if found == null:
		found = Node3D.new()
		found.name = name
		level.add_child(found)
		found.owner = level
		if nav:
			found.add_to_group("nav_source", true)
	groups[name] = found
	return found


func _clear() -> void:
	for name: String in ["Buildings", "Walls", "Market", "Trees", "Rocks", "Props", "Lights", "Places", "Well", "CenaTico", "Grama", "Gardens", "Crowd"]:
		var node := level.get_node_or_null(name)
		if node:
			level.remove_child(node)
			node.free()
	var ground := level.get_node("Ground")
	for part: String in ["Square", "Road", "Alley"]:
		var node := ground.get_node_or_null(part)
		if node:
			ground.remove_child(node)
			node.free()
	var corner := level.get_node_or_null("TicoCorner")
	if corner:
		for child: Node in corner.get_children():
			if child.name != &"Look":
				corner.remove_child(child)
				child.free()


func _place(key: String, parent: Node, pos: Vector3, yaw: float = 0.0, size: float = 1.0, node_name: String = "") -> Node3D:
	var piece := (load(PROPS + key + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	if node_name != "":
		piece.name = node_name
	parent.add_child(piece, true)
	piece.owner = level
	piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), pos)
	return piece


func _kit(path: String, parent: Node, pos: Vector3, yaw: float = 0.0, size: float = 1.0, collide: bool = true) -> Node3D:
	var piece := (load(KIT + path + ".gltf") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	parent.add_child(piece, true)
	piece.owner = level
	piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), pos)
	if collide:
		piece.add_to_group("colisao_auto", true)
	return piece


func _yaw_facing(front: Vector3) -> float:
	return atan2(-front.x, -front.z)


func _block(center: Vector3, size: Vector2, yaw: float, margin: float = 0.6) -> void:
	# retângulo que cobre a peça girada (para a grama e as árvores não nascerem em cima)
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	var w := size.x * c + size.y * s + margin * 2.0
	var d := size.x * s + size.y * c + margin * 2.0
	blocks.append(Rect2(center.x - w / 2.0, center.z - d / 2.0, w, d))


func _free_at(p: Vector3, margin: float = 0.0) -> bool:
	# margem negativa = pode chegar mais perto (a grama encosta nas paredes)
	for r: Rect2 in blocks:
		if p.x > r.position.x - margin and p.x < r.end.x + margin and p.z > r.position.y - margin and p.z < r.end.y + margin:
			return false
	return true


func _mask_at(p: Vector3) -> Color:
	var px := clampi(int((p.x / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	var pz := clampi(int((p.z / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	return mask.get_pixel(px, pz)


## Pinta a máscara do chão: canal 0 = terra (R), 1 = calçada (G). Retângulo em metros (x, z).
func _paint_rect(r: Rect2, channel: int) -> void:
	var a := Vector2i(int((r.position.x / AREA + 0.5) * MASK_PX), int((r.position.y / AREA + 0.5) * MASK_PX))
	var b := Vector2i(int((r.end.x / AREA + 0.5) * MASK_PX), int((r.end.y / AREA + 0.5) * MASK_PX))
	for x: int in range(maxi(a.x, 0), mini(b.x + 1, MASK_PX)):
		for z: int in range(maxi(a.y, 0), mini(b.y + 1, MASK_PX)):
			var c := mask.get_pixel(x, z)
			c[channel] = 1.0
			mask.set_pixel(x, z, c)


func _paint_disc(center: Vector2, radius: float, channel: int) -> void:
	_paint_shape(center, radius, channel, func(p: Vector2) -> bool: return p.distance_to(center) <= radius)


func _paint_shape(center: Vector2, reach: float, channel: int, inside: Callable) -> void:
	var px_per_m := MASK_PX / AREA
	var cx := int((center.x / AREA + 0.5) * MASK_PX)
	var cz := int((center.y / AREA + 0.5) * MASK_PX)
	var rp := int(reach * px_per_m) + 1
	for x: int in range(maxi(cx - rp, 0), mini(cx + rp + 1, MASK_PX)):
		for z: int in range(maxi(cz - rp, 0), mini(cz + rp + 1, MASK_PX)):
			var world := Vector2((float(x) / MASK_PX - 0.5) * AREA, (float(z) / MASK_PX - 0.5) * AREA)
			if inside.call(world):
				var c := mask.get_pixel(x, z)
				c[channel] = 1.0
				mask.set_pixel(x, z, c)


# --- ruas e praça (só a pintura do chão) ----------------------------------------------------------

func _streets() -> void:
	# calçada de pedra nas ruas principais e na praça; terra em volta, nos becos e na estrada
	# a calçada vai até as fachadas (as casas ficam 0,4 m para trás da beira da rua)
	for r: Rect2 in [Rect2(-5.2, -HALF, 10.4, HALF - 10), Rect2(-5.2, 10, 10.4, HALF - 12), Rect2(-HALF + 2, -5.2, HALF - 12, 10.4),
			Rect2(10, -5.2, HALF - 12, 10.4)]:
		_paint_rect(r, 1)
	_paint_disc(Vector2.ZERO, 14.5, 1)
	_paint_rect(Rect2(14.0, 6.0, 15.0, 6.0), 0)  # quintal da ferraria
	_paint_rect(Rect2(-3.2, -110, 6.4, 110 - HALF + 1), 0)  # estrada que sai pelo portão
	_paint_rect(Rect2(-1.2, -HALF - 2, 2.4, 6), 1)


# --- casas ----------------------------------------------------------------------------------------

## Uma fileira de casas com a frente na beira da rua. lots: ["chave", "Nome"] ou ["vão", metros].
func _row(start: Vector3, along: Vector3, front: Vector3, lots: Array) -> void:
	var cursor := 0.0
	var yaw := _yaw_facing(front)
	for lot: Array in lots:
		if lot[0] == "vão":
			var gap: float = lot[1]
			if lot.size() > 2 and lot[2] == "beco_tico":
				var a := start + along * cursor
				var b := start + along * (cursor + gap) - front * 7.0
				tico_alley = Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))
			cursor += gap
			continue
		var key: String = lot[0]
		var size: Vector2 = SIZE[key]
		var center := start + along * (cursor + size.x / 2.0) - front * (size.y / 2.0 + 0.4)
		var house := _place(key, _group("Buildings"), center, yaw, 1.0, lot[1] if lot.size() > 1 else "")
		_block(center, size, yaw)
		houses.append({"node": house, "center": center, "front": front, "along": along, "size": size})
		cursor += size.x + 0.3


func _town() -> void:
	# rua do portão (norte)
	_row(Vector3(-4.6, 0, -HALF + 2), Vector3.BACK, Vector3.RIGHT,
		[["casa_estreita", "CasaDoPortao"], ["casa", "CasaDaViuva"], ["vão", 3.2, "beco_tico"], ["casa_estreita_pedra", "Sapateiro"], ["casa_estreita", "Alfaiate"]])
	_row(Vector3(4.6, 0, -HALF + 2), Vector3.BACK, Vector3.LEFT,
		[["casa_grande_barro", "PousoDoPortao"], ["casa_estreita", ""], ["casa", ""], ["casa_estreita_pedra", ""]])
	# rua do sul
	_row(Vector3(-4.6, 0, 12), Vector3.BACK, Vector3.RIGHT, [["casa", ""], ["casa_estreita", ""], ["casa_grande", "Armazem"]])
	_row(Vector3(4.6, 0, 12), Vector3.BACK, Vector3.LEFT, [["casa_barro", "Padaria"], ["casa_estreita_pedra", ""], ["casa", ""], ["casa_estreita", ""]])
	# rua do oeste
	_row(Vector3(-12, 0, -4.6), Vector3.LEFT, Vector3.BACK, [["casa", ""], ["casa_estreita", ""], ["casa_barro", ""], ["casa_estreita_pedra", ""]])
	_row(Vector3(-12, 0, 4.6), Vector3.LEFT, Vector3.FORWARD, [["casa_barro", ""], ["casa_longa", ""], ["casa_estreita", ""], ["casa_estreita", ""]])
	# rua do leste
	_row(Vector3(12, 0, -4.6), Vector3.RIGHT, Vector3.BACK, [["casa_estreita", ""], ["casa", ""], ["casa_barro", ""], ["casa_estreita_pedra", ""]])
	_row(Vector3(12, 0, 4.6), Vector3.RIGHT, Vector3.FORWARD, [["casa_longa", "Ferraria"], ["vão", 5.5], ["casa", ""], ["casa_estreita", ""]])
	# esquinas da praça: prédios maiores virados para o centro
	for spot: Array in [[Vector3(19, 0, -19), "casa_grande_barro", "Taverna"], [Vector3(-19, 0, -19), "sobrado_longo", "CasaDoConselho"],
			[Vector3(19, 0, 19), "casa_grande", "CasaDoMercador"], [Vector3(-19.5, 0, 19.5), "casa_longa", "Capela"]]:
		var front: Vector3 = -(spot[0] as Vector3).normalized()
		var yaw := _yaw_facing(front)
		var house := _place(spot[1], _group("Buildings"), spot[0], yaw, 1.0, spot[2])
		_block(spot[0], SIZE[spot[1]], yaw)
		houses.append({"node": house, "center": spot[0], "front": front, "along": front.cross(Vector3.UP), "size": SIZE[spot[1]]})
	# a capela ganha um campanário
	_place("torre", _group("Buildings"), Vector3(-27, 0, 27), PI / 4.0, 1.0, "Campanario")
	_block(Vector3(-27, 0, 27), SIZE["torre"], PI / 4.0)
	# coisas na frente das casas: barris, caixotes, sacos, flores, bancos e lanternas
	var small: Array[String] = ["barril", "caixote", "cesto", "balde", "vaso", "caixote_macas", "banquinho", "barril_vinho"]
	for h: Dictionary in houses:
		var c: Vector3 = h["center"]
		var f: Vector3 = h["front"]
		var a: Vector3 = h["along"]
		var size: Vector2 = h["size"]
		var door := c + f * (size.y / 2.0 + 0.4)
		if rng.randf() < 0.75:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			_place(small[rng.randi() % small.size()], _group("Props"), door + f * 0.5 + a * side * (size.x / 2.0 - 0.6), rng.randf() * TAU)
		if rng.randf() < 0.35:
			_place(small[rng.randi() % small.size()], _group("Props"), door + f * 0.45 - a * (size.x / 2.0 - 0.9), rng.randf() * TAU)
		if rng.randf() < 0.55:
			_place("lanterna", _group("Lights", false), door + f * 0.02 + a * 1.25 + Vector3.UP * 2.75, _yaw_facing(f))
		if rng.randf() < 0.3:
			_place("flores", _group("Gardens", false), door + f * 0.6 - a * (size.x / 2.0 - 0.4), rng.randf() * TAU, 0.45)


# --- muralha -------------------------------------------------------------------------------------

func _wall_run(a: Vector3, b: Vector3) -> void:
	# pedaços de muro de 6 m e, no que sobrar, paredes de 2 m do kit (sempre múltiplo de 2)
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var mid := (a + b) / 2.0
	var outward := Vector3(signf(mid.x), 0, 0) if absf(dir.z) > 0.5 else Vector3(0, 0, signf(mid.z))
	var yaw := atan2(outward.x, outward.z)  # a face de pedra do kit (+Z) fica para fora
	var at := 0.0
	# dois muros de costas um para o outro: pedra dos dois lados (de dentro da cidade também)
	while length - at >= 6.0 - 0.01:
		_place("muro", _group("Walls"), a + dir * (at + 3.0), yaw)
		_place("muro", _group("Walls"), a + dir * (at + 3.0) - outward * 0.42, yaw + PI, 1.0, "MuroDentro")
		at += 6.0
	while length - at >= 2.0 - 0.01:
		_kit("vila/Wall_UnevenBrick_Straight", _group("Walls"), a + dir * (at + 1.0), yaw)
		_kit("vila/Wall_UnevenBrick_Straight", _group("Walls"), a + dir * (at + 1.0) - outward * 0.42, yaw + PI)
		at += 2.0
	_block((a + b) / 2.0, Vector2(length, 1.0), yaw, 0.8)


func _walls() -> void:
	var h := HALF
	for corner: Vector3 in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]:
		_place("torre", _group("Walls"), corner, 0.0, 1.0, "Torre")
		_block(corner, Vector2(4, 4), 0.0)
	for x: float in [-3.0, 3.0]:
		_place("torre", _group("Walls"), Vector3(x, 0, -h), 0.0, 1.0, "TorreDoPortao")
		_block(Vector3(x, 0, -h), Vector2(4, 4), 0.0)
	_kit("vila/Wall_Arch", _group("Walls"), Vector3(0, 0, -h))
	_kit("vila/Wall_Arch", _group("Walls"), Vector3(0, 0, -h + 0.35), PI)
	_wall_run(Vector3(-h + 2, 0, -h), Vector3(-5, 0, -h))
	_wall_run(Vector3(5, 0, -h), Vector3(h - 2, 0, -h))
	_wall_run(Vector3(-h + 2, 0, h), Vector3(h - 2, 0, h))
	_wall_run(Vector3(-h, 0, -h + 2), Vector3(-h, 0, h - 2))
	_wall_run(Vector3(h, 0, -h + 2), Vector3(h, 0, h - 2))
	for x: float in [-5.2, 5.2]:
		_place("estandarte", _group("Walls"), Vector3(x, 0.4, -h + 2.35), 0.0, 1.0, "Estandarte")
		_place("tocha", _group("Lights", false), Vector3(x * 0.42, 2.2, -h + 0.6), 0.0, 1.0, "TochaDoPortao")


# --- praça ----------------------------------------------------------------------------------------

func _plaza() -> void:
	_place("poco", _group("Buildings"), Vector3.ZERO, 0.3, 1.0, "Well")
	_block(Vector3.ZERO, Vector2(3, 3), 0.0)
	var stalls: Array[String] = ["barraca", "barraca", "barraca_carroca", "barraca"]
	for i: int in 4:
		var angle := PI / 4.0 + i * PI / 2.0
		var at := Vector3(cos(angle), 0, sin(angle)) * 8.8
		var yaw := _yaw_facing(-at.normalized())
		_place(stalls[i], _group("Market"), at, yaw, 1.0, "Barraca%d" % (i + 1))
		_block(at, Vector2(3, 1.5), yaw)
		var side := (-at.normalized()).cross(Vector3.UP)
		_place(["barril", "caixote", "cesto", "caixote_macas"][i], _group("Props"), at + side * 2.1 + at.normalized() * 0.6, rng.randf() * TAU)
		for k: int in [-1, 1]:
			var tree_angle := angle + k * 0.3
			var tree_at := Vector3(cos(tree_angle), 0, sin(tree_angle)) * 12.2
			_place("arvore_pequena", _group("Trees"), tree_at, rng.randf() * TAU, rng.randf_range(0.85, 1.05))
			_block(tree_at, Vector2(1.2, 1.2), 0.0)
	for i: int in 4:
		var angle := i * PI / 2.0 + PI / 4.0
		var at := Vector3(cos(angle), 0, sin(angle)) * 4.2
		_place("banco", _group("Props"), at, _yaw_facing(at.normalized()) + PI, 0.8)


# --- lugares da história: moradores, portão, beco do Tico ------------------------------------------

func _story_spots() -> void:
	var people := level.get_node("People")
	var spots := {
		"Padeira": [Vector3(7.6, 0, 16.0), Vector3.LEFT],
		"Vendedor": [Vector3(6.2, 0, -5.4), Vector3(-1, 0, 1).normalized()],
		"Guarda": [Vector3(2.6, 0, -HALF + 3.0), Vector3.BACK],
		"Crianca": [Vector3(2.4, 0, 2.6), Vector3(-1, 0, -1).normalized()],
	}
	for person: Node in people.get_children():
		if spots.has(String(person.name)):
			var spot: Array = spots[String(person.name)]
			(person as Node3D).global_transform = Transform3D(Basis(Vector3.UP, _yaw_facing(spot[1])), spot[0])
	var gate := level.get_node_or_null("Gate") as Node3D
	if gate:
		gate.global_position = Vector3(0, 1, -HALF + 0.2)
	# beco do Tico: papelão no fundo, encostado na parede da casa do lado norte
	var corner := level.get_node("TicoCorner") as Node3D
	corner.global_transform = Transform3D.IDENTITY
	var spot := Vector3(tico_alley.position.x + 1.6, 0, tico_alley.position.y + 0.65)
	var cardboard := MeshInstance3D.new()
	cardboard.name = "Blanket"
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.04, 0.9)
	cardboard.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.56, 0.43, 0.28)
	mat.roughness = 1.0
	cardboard.material_override = mat
	corner.add_child(cardboard)
	cardboard.owner = level
	cardboard.position = spot + Vector3(0, 0.02, 0.15)
	var cup := _kit("objetos/Mug", corner, spot + Vector3(0.9, 0, 0.9), 0.4, 1.0, false)
	cup.name = "Cup"
	_place("caixote", corner, Vector3(tico_alley.position.x + 0.6, 0, tico_alley.end.y - 0.6), 0.3, 0.8, "Crate1")
	_place("barril", corner, Vector3(tico_alley.position.x + 0.5, 0, tico_alley.end.y - 1.6), 0.0, 1.0, "Barrel")
	# o fundo do beco é fechado por um muro
	for k: int in 2:
		_kit("vila/Wall_UnevenBrick_Straight", corner, Vector3(tico_alley.position.x - 0.2, 0, tico_alley.position.y + 0.6 + k * 2.0), PI / 2.0)
	var look := corner.get_node_or_null("Look") as Node3D
	if look:
		look.position = spot + Vector3(0.4, 0.6, 0.4)
	var spawn := level.get_node("PlayerSpawn") as Node3D
	spawn.global_transform = Transform3D(Basis(Vector3.UP, _yaw_facing(Vector3.RIGHT)), Vector3(tico_alley.end.x - 1.0, 1.0, tico_alley.get_center().y))
	_block(Vector3(tico_alley.get_center().x, 0, tico_alley.get_center().y), tico_alley.size, 0.0, 0.0)
	_paint_rect(tico_alley, 0)


# --- quintais, hortas e pomares atrás das casas -------------------------------------------------------

func _yards() -> void:
	var inner := HALF - 2.5
	var tries := 0
	var placed := 0
	while placed < 46 and tries < 2000:
		tries += 1
		var p := Vector3(rng.randf_range(-inner, inner), 0, rng.randf_range(-inner, inner))
		if not _free_at(p, 1.4) or _mask_at(p).r > 0.5 or _mask_at(p).g > 0.5:
			continue
		var roll := rng.randf()
		if roll < 0.55:
			_place(["arvore", "arvore_pequena", "pinheiro"][rng.randi() % 3], _group("Trees"), p, rng.randf() * TAU, rng.randf_range(0.75, 1.1))
			_block(p, Vector2(1.4, 1.4), 0.0)
		elif roll < 0.8:
			_place(["arbusto", "arbusto_baixo"][rng.randi() % 2], _group("Gardens", false), p, rng.randf() * TAU, rng.randf_range(0.7, 1.1))
		else:
			_place(["carroca", "barris", "caixote_alto", "mesa", "boneco_treino"][rng.randi() % 5], _group("Props"), p, rng.randf() * TAU)
			_block(p, Vector2(2, 2), 0.0)
		placed += 1
	# cercas nos quintais grandes dos cantos
	for corner: Vector3 in [Vector3(-26, 0, -26), Vector3(26, 0, -26), Vector3(26, 0, 26)]:
		for k: int in 3:
			var at := corner + Vector3(k * 2.06 - 2.06, 0, 0)
			if _free_at(at, 0.2):
				_place("cerca", _group("Props"), at, 0.0)
	# fim das ruas, junto da muralha: carroça, barris, caixotes e uma árvore (a rua não termina no vazio)
	for end: Array in [[Vector3(-HALF + 3.2, 0, -2.2), Vector3.RIGHT], [Vector3(HALF - 3.2, 0, 2.2), Vector3.LEFT], [Vector3(2.4, 0, HALF - 3.0), Vector3.FORWARD]]:
		var at: Vector3 = end[0]
		var look: Vector3 = end[1]
		var side := look.cross(Vector3.UP)
		_place("carroca", _group("Props"), at, _yaw_facing(side), 1.0)
		_place("barris", _group("Props"), at - side * 3.4 + look * 0.2, _yaw_facing(look))
		_place("caixote", _group("Props"), at + side * 2.8 + look * 0.6, rng.randf() * TAU)
		_place("caixote_alto", _group("Props"), at + side * 3.6 - look * 0.2, rng.randf() * TAU, 0.8)
		_place("arvore_pequena", _group("Trees"), at - side * 5.6 - look * 0.6, rng.randf() * TAU, 0.9)
		_place("lanterna", _group("Lights", false), at - look * 0.5 + Vector3.UP * 2.75 + side * 1.2, _yaw_facing(look))
		_block(at, Vector2(9, 4), 0.0)
	# ferraria: bigorna, bancada e barris no quintal ao lado
	var smithy := Vector3(21.5, 0, 8.2)
	_place("bigorna", _group("Props"), smithy, 0.4)
	_place("bancada", _group("Props"), smithy + Vector3(1.8, 0, 1.2), -0.3)
	_place("barris", _group("Props"), smithy + Vector3(-1.6, 0, 1.6), 1.2)
	_place("tocha", _group("Lights", false), smithy + Vector3(0.6, 1.4, -0.6), 0.0)


# --- gente de fundo: quem vive na cidade (sem fala; os moradores com fala ficam em People) -------------

func _figurante(pos: Vector3, look: Vector3, who: String, anim: String, hand: String = "", size: float = 0.62, label: String = "") -> void:
	var person := Node3D.new()
	person.name = label if label != "" else who
	_group("Crowd", false).add_child(person, true)
	person.owner = level
	var dir := look - pos
	dir.y = 0.0
	person.transform = Transform3D(Basis(Vector3.UP, _yaw_facing(dir.normalized()) if dir.length() > 0.01 else 0.0), pos)
	var figure := Figurante.new()
	figure.name = "Figure"
	figure.personagem = who
	figure.animacao = anim
	figure.na_mao = hand
	person.add_child(figure)
	figure.owner = level
	figure.scale = Vector3.ONE * size
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 4
	body.collision_mask = 0
	person.add_child(body)
	body.owner = level
	body.position = Vector3(0, 0.9, 0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	shape.owner = level
	_block(pos, Vector2(0.8, 0.8), 0.0, 0.0)


func _crowd() -> void:
	# guardas nas torres do portão, por dentro
	_figurante(Vector3(-5.2, 0, -HALF + 3.2), Vector3(0, 0, 0), "Knight", "2H_Melee_Idle", "2H_Sword", 0.66, "GuardaPortao")
	# feira: gente olhando as barracas
	for i: int in 4:
		var angle := PI / 4.0 + i * PI / 2.0
		var stall := Vector3(cos(angle), 0, sin(angle)) * 8.8
		var buyer := stall - stall.normalized() * 1.9 + stall.normalized().cross(Vector3.UP) * (0.7 if i % 2 == 0 else -0.7)
		_figurante(buyer, stall, ["Rogue_Hooded", "Mage", "Barbarian", "Rogue"][i], ["Interact", "Idle", "Unarmed_Idle", "Use_Item"][i], "", 0.6, "Comprador")
	# bancos da praça: gente sentada
	for i: int in [0, 2]:
		var angle := i * PI / 2.0 + PI / 4.0
		var bench := Vector3(cos(angle), 0, sin(angle)) * 4.2
		_figurante(bench + bench.normalized() * 0.15, bench * 2.0, ["Mage", "Rogue_Hooded"][int(i / 2.0)], "Sit_Chair_Idle", "", 0.6, "Sentado")
	# conversa na porta da taverna
	var tavern := Vector3(19, 0, -19) + Vector3(-1, 0, 1).normalized() * 6.2
	_figurante(tavern + Vector3(-0.9, 0, 0), tavern + Vector3(0.6, 0, 0.4), "Barbarian", "Cheer", "Mug", 0.64, "NaTaverna")
	_figurante(tavern + Vector3(0.7, 0, 0.5), tavern + Vector3(-0.9, 0, 0), "Knight", "Idle", "", 0.64, "NaTaverna")
	# ferreiro trabalhando na bigorna
	_figurante(Vector3(21.5, 0, 9.4), Vector3(21.5, 0, 8.2), "Barbarian", "Use_Item", "1H_Axe", 0.66, "Ferreiro")
	# crianças brincando na rua do sul e alguém sentado no chão perto da capela
	_figurante(Vector3(-1.5, 0, 20), Vector3(1, 0, 22), "Rogue", "Cheer", "", 0.45, "Crianca2")
	_figurante(Vector3(1.0, 0, 22.3), Vector3(-1.5, 0, 20), "Rogue_Hooded", "Idle", "", 0.43, "Crianca3")
	_figurante(Vector3(-12.5, 0, 13.5), Vector3(-6, 0, 8), "Mage", "Sit_Floor_Idle", "Spellbook_open", 0.6, "Leitora")


# --- fora da muralha: estrada, floresta, pedras ---------------------------------------------------

func _outside() -> void:
	var tries := 0
	var placed := 0
	while placed < 230 and tries < 6000:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(HALF + 7.0, 104.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < 6.5 and p.z < -HALF:
			continue  # estrada livre
		if absf(p.x) > 106 or absf(p.z) > 106:
			continue
		var far := smoothstep(HALF + 7.0, 70.0, r)
		var roll := rng.randf()
		if roll < 0.35 + far * 0.35:
			_place(["pinheiro", "arvore", "pinheiro", "arvore", "arvore_pequena"][rng.randi() % 5] if rng.randf() > 0.06 else "arvore_torta", _group("Trees"), p, rng.randf() * TAU,
				rng.randf_range(0.9, 1.5) * (1.0 if rng.randf() > 0.05 else 0.5))
		elif roll < 0.8:
			_place(["arbusto", "arbusto_baixo"][rng.randi() % 2], _group("Gardens", false), p, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		else:
			_place(["rocha", "rocha_grande", "pedregulhos"][rng.randi() % 3], _group("Rocks"), p, rng.randf() * TAU, rng.randf_range(0.7, 1.3))
		_block(p, Vector2(1.5, 1.5), 0.0)
		placed += 1
	# cerca dos dois lados da estrada que chega ao portão
	for k: int in 6:
		for x: float in [-4.6, 4.6]:
			_place("cerca", _group("Props"), Vector3(x, 0, -HALF - 6.0 - k * 2.06), PI / 2.0)


# --- chão -----------------------------------------------------------------------------------------

func _paint_ground() -> void:
	# bordas macias: reduz e volta a ampliar (desfoca uns 70 cm), o shader ainda quebra com ruído
	var soft := mask.duplicate() as Image
	soft.resize(MASK_PX / 3, MASK_PX / 3, Image.INTERPOLATE_LANCZOS)
	soft.resize(MASK_PX, MASK_PX, Image.INTERPOLATE_CUBIC)
	DirAccess.make_dir_recursive_absolute(ART)
	soft.save_png(ART + "chao_mascara.png")  # para ver/pintar à mão
	ResourceSaver.save(ImageTexture.create_from_image(soft), ART + "chao_mascara.res")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/chao_pintado.gdshader")
	var vila := "res://assets/kits/quaternius/vila/"
	mat.set_shader_parameter("noise", load(vila + "T_Noise_Terrain.png"))
	mat.set_shader_parameter("cobble_albedo", load(vila + "T_Brick_BaseColor.png"))
	mat.set_shader_parameter("cobble_normal", load(vila + "T_Brick_Normal.png"))
	mat.set_shader_parameter("area_size", Vector2(AREA, AREA))
	var ground := level.get_node("Ground")
	var dirt := ground.get_node("Dirt") as MeshInstance3D
	var box := BoxMesh.new()
	box.size = Vector3(AREA, 1.0, AREA)
	dirt.mesh = box
	dirt.material_override = mat
	var shape := ground.get_node("Body/Shape") as CollisionShape3D
	var bs := BoxShape3D.new()
	bs.size = Vector3(AREA, 1.0, AREA)
	shape.shape = bs
	mat.set_shader_parameter("mask", load(ART + "chao_mascara.res"))
	var nav := level.get_node("Navigation") as NavigationRegion3D
	nav.navigation_mesh.filter_baking_aabb = AABB(Vector3(-HALF - 3, -2, -HALF - 3), Vector3(HALF * 2 + 6, 22, HALF * 2 + 6))


# --- grama espalhada (muitas, leves, por pedaços de 20 m que somem de longe) -------------------------

func _grass_mesh(name: String) -> Mesh:
	var path := KIT + "natureza/malhas/" + name + ".res"
	if ResourceLoader.exists(path):
		return load(path)
	var scene := (load(KIT + "natureza/" + name + ".gltf") as PackedScene).instantiate()
	var mesh: Mesh = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	DirAccess.make_dir_recursive_absolute(KIT + "natureza/malhas")
	ResourceSaver.save(mesh, path)
	return load(path)


func _grass() -> void:
	var kinds := {"Grass_Common_Short": [0.42, 0.7], "Grass_Wispy_Short": [0.4, 0.6], "Clover_1": [0.35, 0.55], "Plant_7": [0.8, 1.2],
		"Flower_3_Single": [0.3, 0.45]}
	var weights := {"Grass_Common_Short": 0.5, "Grass_Wispy_Short": 0.2, "Clover_1": 0.15, "Plant_7": 0.1, "Flower_3_Single": 0.05}
	var chunks := {}  # "kind|cx|cz" -> Array[Transform3D]
	var space := level.get_world_3d().direct_space_state
	var count := 0
	var step := 1.25
	var x := -100.0
	while x < 100.0:
		var z := -100.0
		while z < 100.0:
			var p := Vector3(x + rng.randf_range(-0.55, 0.55), 0, z + rng.randf_range(-0.55, 0.55))
			z += step
			var m := _mask_at(p)
			var dist := Vector2(p.x, p.z).length()
			var keep := 0.85 if dist < 95.0 else 0.0
			# mato também na terra (menos) e encostado nas paredes; na calçada, não
			keep *= (1.0 - clampf(m.g * 2.5, 0.0, 1.0)) * (1.0 - m.r * 0.7)
			if rng.randf() > keep or not _free_at(p, -0.55):
				continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 12.0, p + Vector3.DOWN, 1 | 4))
			if hit.is_empty() or (hit["position"] as Vector3).y > 0.15:
				continue  # caiu em cima de alguma coisa
			var kind := _pick_weighted(weights)
			var range_s: Array = kinds[kind]
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(range_s[0], range_s[1])), p)
			var key := "%s|%d|%d" % [kind, floori(p.x / 30.0), floori(p.z / 30.0)]
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(t)
			count += 1
		x += step
	var holder := _group("Grama", false)
	DirAccess.make_dir_recursive_absolute(ART + "grama")
	for f: String in DirAccess.get_files_at(ART + "grama"):
		DirAccess.remove_absolute(ART + "grama/" + f)
	var i := 0
	for key: String in chunks:
		var parts := key.split("|")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _grass_mesh(parts[0])
		var list: Array = chunks[key]
		mm.instance_count = list.size()
		for k: int in list.size():
			mm.set_instance_transform(k, list[k])
		var path := ART + "grama/g%03d.res" % i
		ResourceSaver.save(mm, path)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "G%03d" % i
		mmi.multimesh = load(path)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 75.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		holder.add_child(mmi)
		mmi.owner = level
		i += 1
	print("grama: ", count, " tufos em ", i, " pedaços")


func _pick_weighted(weights: Dictionary) -> String:
	var r := rng.randf()
	for k: String in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


# --- luz e câmera ---------------------------------------------------------------------------------

func _light_and_camera() -> void:
	var env := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.84, 0.86, 0.8)
	env.fog_density = 0.0045
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var sun := level.get_node("Sun") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.9
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 110.0
	var rig := level.get_node("CameraRig")
	rig.set("distance", 5.8)
	rig.set("height", 1.9)
