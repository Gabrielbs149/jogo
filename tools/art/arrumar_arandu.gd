extends SceneTree
## Arruma as coisinhas de Arandu (D071). Roda DEPOIS dos outros montadores (é o último), COM janela (a colisão de
## teste sai das malhas): godot --path . -s tools/art/arrumar_arandu.gd
## - Tira a "tralha de rua" sorteada pelo montar_arandu (barril, vaso, balde, caixote, cesto e banquinho soltos
##   encostados em qualquer parede, sem dono): ficava parecendo coisa perdida.
## - Feira: o estoque (barris, caixote, cesto) vai para trás dos vendedores, entre as barracas.
## - Cada lugar ganha, na frente da porta, o que faz sentido para ele: a taverna com barris e banco, o empório com
##   caixotes de mercadoria, a capela com vasos e velas, a ferraria com tina d'água e balde, o estábulo com feno...
##   As casas de morar ganham (umas sim, outras não) floreiras dos lados da porta, um banquinho, um barril de chuva no
##   canto, um caixote com cesto. Nada na frente da porta (o vão e 1,8 m para fora ficam livres) e nada no meio da rua
##   (tudo encostado na parede, até ~1 m dela). Peça que bateria em parede, poste, árvore, gente ou outra peça não
##   entra (teste de colisão de verdade, com a forma das malhas).
## - Corrige o que o Gabriel arrumou no editor em 13/10 (o editor moveu só o boneco, não a pessoa).
## Rodar de novo dá o mesmo resultado (sorteio pelo nome da casa) e não duplica nada (apaga os "Fachada_*" antes).

const LEVEL := "res://levels/arandu/arandu.tscn"
const P := "res://world/props/%s.tscn"
const OBJ := "res://assets/kits/quaternius/objetos/%s.gltf"
## Tralha de rua do montar_arandu (em Props): sai.
const CLUTTER := ["barril", "vaso", "balde", "caixote", "cesto", "banquinho", "barril_vinho", "caixote_macas"]
## Peças que estavam no lugar errado e saem (o conjunto do lugar põe de novo, no lugar certo).
const REMOVE := ["Props/Barrel2", "Props/Caixote_alto", "Props/Caixote_alto2"]

## O que cada loja ganha na frente: [peça, ao longo da parede a partir da porta (m, + = à direita de quem sai),
## para fora da parede (m), giro (graus)]. Peça "obj:Nome" = objeto do kit da Quaternius.
const LOJAS := {
	"Taverna": [["barris", -2.5, 0.55, 0], ["barril_vinho", 2.0, 0.55, 0], ["banco", 3.9, 0.4, 0], ["banquinho", -3.7, 0.45, 0]],
	"CasaDoMercador": [["caixote", -1.7, 0.6, 10], ["caixote_macas", -2.7, 0.45, -8], ["obj:Barrel_Apples", 1.7, 0.5, 0],
		["cesto", 2.6, 0.45, 0]],
	"Capela": [["vaso", -1.3, 0.45, 0], ["vaso", 1.3, 0.45, 0], ["velas", -2.0, 0.35, 0], ["velas", 2.0, 0.35, 0]],
	"Sapateiro": [["banquinho", -1.4, 0.45, 15], ["obj:Bag", -2.1, 0.4, 0]],
	"CasaDoConselho": [["estandarte", -1.6, 0.35, 0], ["estandarte", 1.6, 0.35, 0]],
	"Estalagem": [["banco", -3.0, 0.4, 0], ["barril", 2.0, 0.5, 0], ["balde", 2.7, 0.35, 0]],
	"Ferreiro": [["barril", -2.0, 0.55, 0], ["balde", -2.8, 0.4, 0], ["obj:WeaponStand", 2.2, 0.45, 0]],
	"Casa_estreita": [["cesto", -1.3, 0.45, 0], ["obj:Bag", 1.3, 0.4, 0]],
	"Casa_estreita_pedra2": [["jarro", -1.2, 0.4, 0], ["jarro", 1.2, 0.4, 0], ["vaso", -1.9, 0.45, 0]],
	"CasaDaViuva": [["vaso", -1.3, 0.45, 0], ["banquinho", 1.4, 0.45, 0]],
	"CasaDoPortao": [["barril", -1.6, 0.55, 0]],
}
## Casas de morar: um destes por casa (sorteado pelo nome; "" = nada). Mesmo formato; "canto" no lugar do número =
## encostado no canto da frente (esquerdo ou direito, também sorteado).
const LAR := [
	[],
	[["vaso", -1.3, 0.45, 0], ["vaso", 1.3, 0.45, 0]],
	[["banquinho", -1.4, 0.45, 0], ["vaso", -2.1, 0.45, 0]],
	[["barril", "canto", 0.55, 0], ["balde", "canto+", 0.35, 0]],
	[["flores", -1.6, 0.4, 0], ["flores", 1.6, 0.4, 0]],
	[["caixote", "canto", 0.6, 12], ["cesto", "canto+", 0.45, 0]],
	[],
	[["vaso", 1.3, 0.45, 0]],
]
## Prédios sem metadados de casa (do kit): o que vai nos cantos da frente. [peça, canto (-1 esquerdo, 1 direito), para fora]
const GRANDES := {
	"Estabulo": [["feno", -1, 0.5], ["feno", -1, 1.3], ["balde", 1, 0.4]],
	"Serraria": [["caixote_alto", -1, 0.8], ["barril", 1, 0.55]],
	"Galpao": [["sacos", 1, 0.6]],
	"CeleiroDaCidade": [["sacos", -1, 0.6], ["fardos", 1, 0.5]],
	"Celeiro": [["feno", -1, 0.5], ["feno", 1, 0.5]],
	"CeleiroGrande": [["fardos", 1, 0.6]],
	"Moinho": [["sacos", 1, 0.6]],
	"Padaria": [["sacos", -1, 0.55], ["cesto", 1, 0.45]],
	"Guarita": [["barril", 1, 0.55]],
}

var level: Node3D
var _props: Node3D
var _space: PhysicsDirectSpaceState3D
var _temp_bodies: Array[Node] = []
var _doors: Array[Rect2] = []  # vão das portas (no chão, mundo): nada entra
var _placed := 0
var _skipped := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	_props = level.get_node("Props") as Node3D
	await process_frame
	var removed := _clear()
	_user_moves()
	_market()
	await process_frame
	_collide()
	for i in 3:
		await physics_frame
	_space = level.get_world_3d().direct_space_state
	_find_doors()
	for b: Node in level.get_node("Buildings").get_children():
		var house := b as Node3D
		if house == null:
			continue
		if house.has_meta("celulas"):
			_dress_house(house)
		elif GRANDES.has(String(house.name)):
			_dress_big(house, GRANDES[String(house.name)])
		await physics_frame  # o que entrou já conta como obstáculo para o próximo
	for body: Node in _temp_bodies:
		if is_instance_valid(body):
			body.get_parent().remove_child(body)
			body.free()
	var packed := PackedScene.new()
	print("tirados %d | postos %d | sem espaço %d: %s" % [removed, _placed, _skipped.size(), ", ".join(_skipped)])
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


## Tira a tralha de rua, as peças fora do lugar e o que este script pôs antes.
func _clear() -> int:
	var count := 0
	for child: Node in _props.get_children():
		var base := child.scene_file_path.get_file().get_basename()
		if String(child.name).begins_with("Fachada_") or CLUTTER.has(base):
			_props.remove_child(child)
			child.free()
			count += 1
	for path: String in REMOVE:
		var node := level.get_node_or_null(path)
		if node:
			node.get_parent().remove_child(node)
			node.free()
			count += 1
	return count


## O que o Gabriel arrumou no editor em 13/10 (o editor moveu só o boneco "Figure"; aqui vai a pessoa inteira).
func _user_moves() -> void:
	var moves := {
		"Crowd/Freguês2": [Vector3(-0.6976869, 0, -0.13614655), 0.0],
		"Crowd/Crianca3": [Vector3(0.75471795, 0, -1.1338582), -30.0],
	}
	for path: String in moves:
		var who := level.get_node_or_null(path) as Node3D
		if who == null:
			continue
		var offset: Vector3 = moves[path][0]
		who.global_position = who.global_transform * offset
		who.rotate_y(deg_to_rad(float(moves[path][1])))
	var juggler := level.get_node_or_null("Atracoes/Malabarista") as Node3D
	if juggler:
		juggler.global_position = Vector3(-5.5, 0, 7.5479565)


## Feira: o estoque fica atrás dos vendedores (x 17,4), nos vãos entre as barracas (D071: as bancas agora têm o balcão
## comprido para a praça, z ±1,8 em volta de -9, -3, 3 e 9).
func _market() -> void:
	var spots := {"Barril": Vector3(17.4, 0, -12.2), "Caixote": Vector3(17.5, 0, -6.0), "Caixote_macas": Vector3(17.3, 0, 0.0),
		"Barris": Vector3(17.4, 0, 6.0), "Cesto": Vector3(17.6, 0, 11.6)}
	for name: String in spots:
		var node := level.get_node_or_null("Market/" + name) as Node3D
		if node:
			node.global_position = spots[name]


## Colisão de teste: o formato das malhas das peças (como o jogo faz ao abrir a fase). Sai antes de salvar.
func _collide() -> void:
	for node: Node in get_nodes_in_group("colisao_auto"):
		if not level.is_ancestor_of(node):
			continue
		for found: Node in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := found as MeshInstance3D
			if mesh.mesh == null or mesh.get_meta("sem_colisao", false):
				continue
			var body := StaticBody3D.new()
			body.name = "TesteColisao"
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			mesh.add_child(body)
			_temp_bodies.append(body)


## O vão de cada porta (e 1,8 m para fora) fica livre.
func _find_doors() -> void:
	for b: Node in level.get_node("Buildings").get_children():
		var house := b as Node3D
		if house == null or not house.has_meta("celulas"):
			continue
		var cells: Vector2i = house.get_meta("celulas")
		var door_x := -cells.x + 1.0 + 2.0 * int(house.get_meta("porta", 0))
		var corners: Array[Vector3] = []
		for local: Vector3 in [Vector3(door_x - 0.85, 0, -cells.y), Vector3(door_x + 0.85, 0, -cells.y),
				Vector3(door_x - 0.85, 0, -cells.y - 1.8), Vector3(door_x + 0.85, 0, -cells.y - 1.8)]:
			corners.append(house.global_transform * local)
		_doors.append(_rect_of(corners))


func _dress_house(house: Node3D) -> void:
	var cells: Vector2i = house.get_meta("celulas")
	var door_x := -cells.x + 1.0 + 2.0 * int(house.get_meta("porta", 0))
	var name := String(house.name)
	var plan: Array = []
	if LOJAS.has(name):
		plan = LOJAS[name]
	elif String(house.get_meta("frente", "")) != "arcos":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(name) ^ 71
		plan = LAR[rng.randi() % LAR.size()]
	if plan.is_empty():
		return
	var rng_side := RandomNumberGenerator.new()
	rng_side.seed = hash(name) ^ 13
	var corner_side := -1.0 if rng_side.randf() < 0.5 else 1.0
	var k := 0
	for item: Array in plan:
		var along: float
		if item[1] is String:
			# canto da frente: encostado na quina (o "+" fica um pouco mais para dentro)
			var corner := corner_side * (cells.x - 0.55)
			along = corner - door_x - (corner_side * 0.85 if String(item[1]).ends_with("+") else 0.0)
		else:
			along = float(item[1])
		var local := Vector3(door_x + along, 0, -cells.y - float(item[2]))
		_put(String(item[0]), house.global_transform * local, house.global_rotation.y + deg_to_rad(float(item[3])),
			"Fachada_%s_%d" % [name, k])
		k += 1


## Prédio do kit (sem metadados): pelos cantos da frente da caixa dele (a frente das peças é -Z). A beira do telhado
## entra na caixa, então a parede de verdade é achada por um raio de fora para dentro.
func _dress_big(house: Node3D, plan: Array) -> void:
	var inv := house.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for v: Node in house.find_children("*", "VisualInstance3D", true, false):
		var b := inv * (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var k := 0
	for item: Array in plan:
		var side := float(item[1])
		var x := box.get_center().x + side * (box.size.x * 0.5 - 0.9)
		# a parede: raio vindo da frente, na altura do joelho
		var from := house.global_transform * Vector3(x, 0.5, box.position.z - 3.0)
		var to := house.global_transform * Vector3(x, 0.5, box.end.z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := _space.intersect_ray(q)
		var wall_z := box.position.z
		if not hit.is_empty():
			wall_z = (inv * (hit["position"] as Vector3)).z
		var local := Vector3(x, 0, wall_z - float(item[2]))
		_put(String(item[0]), house.global_transform * local, house.global_rotation.y, "Fachada_%s_%d" % [house.name, k])
		k += 1


## Põe a peça se couber: sem bater em nada (colisão de verdade) e fora do vão das portas.
func _put(piece: String, at: Vector3, yaw: float, node_name: String) -> void:
	var path := OBJ % piece.substr(4) if piece.begins_with("obj:") else P % piece
	var scene := load(path) as PackedScene
	if scene == null:
		_skipped.append(node_name + "(sem peça)")
		return
	var node := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = node_name
	_props.add_child(node)
	node.owner = level
	node.global_position = Vector3(at.x, 0.0, at.z)
	node.rotation.y = yaw
	var box := _box(node)
	var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(-0.04)
	var blocked := false
	for door: Rect2 in _doors:
		if door.intersects(foot):
			blocked = true
	if not blocked:
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(foot.size.x, 0.1), 0.8, maxf(foot.size.y, 0.1))
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis(), Vector3(foot.get_center().x, 0.55, foot.get_center().y))
		params.collide_with_areas = false
		for hit: Dictionary in _space.intersect_shape(params, 8):
			var col := hit["collider"] as Node
			if col and not node.is_ancestor_of(col) and not String(col.name).begins_with("Ground") \
					and not (col.get_parent() and String(col.get_parent().name) == "Ground"):
				blocked = true
				break
	if blocked:
		_props.remove_child(node)
		node.free()
		_skipped.append(node_name)
		return
	# a peça nova também vira obstáculo para as próximas
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null:
			continue
		var body := StaticBody3D.new()
		body.name = "TesteColisao"
		var cs := CollisionShape3D.new()
		cs.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(cs)
		mesh.add_child(body)
		_temp_bodies.append(body)
	_placed += 1


func _box(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	var first := true
	for v: Node in node.find_children("*", "VisualInstance3D", true, false):
		var b := (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _rect_of(points: Array[Vector3]) -> Rect2:
	var r := Rect2(points[0].x, points[0].z, 0, 0)
	for p: Vector3 in points:
		r = r.expand(Vector2(p.x, p.z))
	return r
