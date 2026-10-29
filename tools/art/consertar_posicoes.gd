extends "res://tools/art/auditar_posicoes.gd"
## Conserta as posições que o tools/art/auditar_posicoes.gd acha (D088) e grava a fase e os interiores mexidos:
##   pessoa dentro de parede/móvel/cama, enfiada no chão ou no ar -> o lugar livre de chão mais perto (dentro da casa)
##   coisa pequena no ar (caneca, vela, panela) -> em cima do móvel mais perto (mesa, baú, barril, balcão); senão, no chão
##   peça grande no ar -> desce até o que está embaixo
##   parte arrastada para longe da peça (o "Mug" de dentro do "Mug2") -> a peça vai para onde a parte está
##   caixa de colisão do móvel do interior -> vira filha do móvel (arrastar o móvel no editor leva a colisão junto)
## Imprime cada conserto e o que ficou para olhar a olho. Uso: godot --headless --path . -s tools/art/consertar_posicoes.gd

const SURFACES := ["mesa", "table", "bau", "chest", "barril", "barrel", "caixote", "crate", "balcao", "counter", "bancada",
	"workbench", "comoda", "dresser", "criado", "nightstand", "aparador", "tonel", "cask", "shelf", "prateleira"]
## Coisa de pendurar na parede: no ar, ela vai até encostar na parede mais perto.
const WALL_ITEMS := ["peg_rack", "rack", "gancho", "hook", "cabide"]
const SMALL := 0.6  # menor que isso (m) é "coisa pequena"
## Quem está aqui é a cena das falas (o pão na mão, o pedaço da Tika): quem põe no lugar é o roteiro.
const SKIP_PARENTS: Array[String] = ["CenaTico"]

var _interior_roots: Array[Node3D] = []
var _changed: Dictionary = {}  # interior (ou a fase) -> true
var _done: Array[String] = []
var _manual: Array[String] = []
## Pontos de tampo já usados (duas canecas não vão para o mesmo lugar da mesma mesa).
var _used: Array[Vector3] = []
## O que a fase já tinha antes das colisões automáticas: o resto é criado na hora e não vai para o arquivo.
var _original_nodes: Dictionary = {}


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(DEFAULT_LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	_interior_roots = _load_interiors()
	for node: Node in level.find_children("*", "", true, false):
		_original_nodes[node.get_instance_id()] = true
	level.call("_auto_collision")
	for k: int in 3:
		await physics_frame
	space = level.get_world_3d().direct_space_state
	_collect(_interior_roots)
	# 1. a colisão de cada móvel vira filha dele (antes, para os testes de baixo já valerem com ela no lugar)
	for inside: Node3D in _interior_roots:
		_adopt_collision_boxes(inside)
	for k: int in 2:
		await physics_frame
	# 2. a fase: o Brás volta para a esquina dele (alguém arrastou ele para dentro da sapataria)
	_fix_bras()
	# 3. a auditoria, e o conserto de cada coisa
	report.clear()
	for piece: Node3D in _pieces:
		if String(piece.get_parent().name) in SKIP_PARENTS:
			continue
		if _is_person(piece):
			_check_person(piece)
		else:
			_check_piece(piece)
			_check_parts(piece)
	for r: Dictionary in report:
		var node := _node_of(r)
		if node == null:
			continue
		match String(r["tipo"]):
			"PARTE":
				_fix_part(node, String(r["parte"]))
		await physics_frame
	for r: Dictionary in report:
		var node := _node_of(r)
		if node == null:
			continue
		match String(r["tipo"]):
			"PAREDE", "PESSOA_CHAO", "PESSOA_AR":
				_fix_person(node)
			"VOANDO":
				_fix_floating(node, r)
			"AFUNDADA":
				# não levanta sozinho: na caixa empilhada e no alicerce era alarme falso (a mercadoria subiu 63 cm)
				_manual.append("%s: %s (olhar a olho: afundado de propósito?)" % [r["onde"], r["texto"]])
	for line: String in _done:
		print("CONSERTADO  ", line)
	for line: String in _manual:
		print("OLHAR       ", line)
	_save()
	quit()


func _node_of(r: Dictionary) -> Node3D:
	var scene := String(r["cena"])
	var holder: Node = level
	if scene != String(level.scene_file_path):
		for inside: Node3D in _interior_roots:
			if String(inside.get_meta("auditoria_cena")) == scene:
				holder = inside
	return holder.get_node_or_null(NodePath(String(r["caminho"]))) as Node3D


func _mark_changed(node: Node) -> void:
	var inside := _interior_of(node)
	_changed[inside if inside else level] = true


# --- colisão dos móveis ------------------------------------------------------------------------------

func _adopt_collision_boxes(inside: Node3D) -> void:
	var previous: Node3D = null
	for child: Node in inside.get_children():
		if child is StaticBody3D and String(child.name).begins_with("Colisao"):
			var body := child as StaticBody3D
			if previous and _box_over(body, previous):
				var keep := body.global_transform
				inside.remove_child(body)
				previous.add_child(body)
				body.global_transform = keep
				body.owner = inside
				for part: Node in body.get_children():
					part.owner = inside
				_owner_of[body.get_rid()] = previous
				inside.set_editable_instance(previous, true)
				_changed[inside] = true
			else:
				_manual.append("%s:%s caixa de colisão sem móvel embaixo" % [String(inside.get_meta("auditoria_cena")).get_file(), body.name])
			continue
		if child is Node3D and not child is Light3D:
			previous = child as Node3D


func _box_over(body: StaticBody3D, piece: Node3D) -> bool:
	var shape_node := body.get_child(0) as CollisionShape3D if body.get_child_count() > 0 else null
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return false
	var size := (shape_node.shape as BoxShape3D).size
	var world := shape_node.global_transform * AABB(-size / 2.0, size)
	var col := Rect2(world.position.x, world.position.z, world.size.x, world.size.z)
	var pb := _bounds(piece)
	var vis := Rect2(pb.position.x, pb.position.z, pb.size.x, pb.size.z)
	return col.intersects(vis) and col.intersection(vis).get_area() / maxf(col.get_area(), 0.0001) >= 0.5


# --- o Brás ------------------------------------------------------------------------------------------

func _fix_bras() -> void:
	var bras := level.get_node_or_null("People/Bras") as Node3D
	var mark := level.get_node_or_null("People/BrasEsquina") as Node3D
	if bras == null or mark == null:
		return
	mark.basis = mark.basis.orthonormalized()  # a marca tinha ficado 6% maior
	if bras.global_position.distance_to(mark.global_position) > 0.05:
		_done.append("People/Bras: de volta para a esquina dele (estava dentro da sapataria, a %.2f m do lugar)" % bras.global_position.distance_to(mark.global_position))
		bras.global_transform = mark.global_transform
	_changed[level] = true


# --- pessoas -----------------------------------------------------------------------------------------

func _fix_person(person: Node3D) -> void:
	if person.name == &"Bras" and person.get_parent().name == &"People":
		return
	var inside := _interior_of(person)
	var floor_y: float = _floor_of(person, inside)
	var spot: Variant = _free_spot(person, inside, floor_y)
	if spot == null:
		_manual.append("%s: não achei lugar livre perto" % _where(person))
		return
	var from := person.global_position
	var fig := person.get_node_or_null("Figure")
	var seated := fig != null and "animacao" in fig and String(fig.get("animacao")).to_lower().contains("sit")
	person.global_position = spot
	if seated and fig:
		fig.set("animacao", "Idle")  # sentado no meio do nada fica esquisito: de pé
	_done.append("%s: %.2f m para o lado, para um lugar livre de chão%s" % [_where(person), Vector2(from.x, from.z).distance_to(Vector2((spot as Vector3).x, (spot as Vector3).z)), " (e de pé)" if seated else ""])
	_mark_changed(person)


## A altura do chão do cômodo (o mais baixo dos pontos em volta; o que é mais alto é móvel).
func _floor_of(person: Node3D, inside: Node3D) -> float:
	var lowest := INF
	var c := person.global_position
	for dx: float in [-1.2, 0.0, 1.2]:
		for dz: float in [-1.2, 0.0, 1.2]:
			var h: Variant = _surface_under(person, c + Vector3(dx, 0, dz), c.y + 1.0)
			if h != null:
				lowest = minf(lowest, float(h))
	return lowest if lowest < INF else c.y


func _free_spot(person: Node3D, inside: Node3D, floor_y: float) -> Variant:
	var start := person.global_position
	var building: Node3D = inside.get_parent().get_parent() as Node3D if inside else null
	var cells: Variant = building.get_meta("celulas") if building and building.has_meta("celulas") else null
	var r := 0.0
	while r <= 3.0:
		var steps := maxi(1, int(r / 0.25) * 8)
		for k: int in steps:
			var a := TAU * k / steps
			var p := start + Vector3(cos(a), 0, sin(a)) * r
			if cells != null:
				var local := building.global_transform.affine_inverse() * p
				var c: Vector2i = cells
				if absf(local.x) > c.x - 0.5 or absf(local.z) > c.y - 0.5:
					continue
			var h: Variant = _surface_under(person, p, floor_y + 0.6)
			if h == null or absf(float(h) - floor_y) > 0.08:
				continue  # em cima de móvel ou buraco: não é chão
			if _capsule_hits(person, Vector3(p.x, float(h), p.z)):
				continue
			return Vector3(p.x, float(h), p.z)
		r += 0.25
	return null


func _capsule_hits(person: Node3D, feet: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.2
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), feet + Vector3.UP * (0.2 + 0.6))
	params.exclude = _own_rids(person)
	for hit: Dictionary in space.intersect_shape(params, 8):
		var other: Variant = _owner_of.get(hit["rid"])
		if other == null or not _is_person(other as Node):
			return true
	# também não em cima de um móvel sem colisão (tapete não conta: é baixo)
	return false


# --- coisas no ar -----------------------------------------------------------------------------------

func _fix_floating(piece: Node3D, r: Dictionary) -> void:
	var box := _bounds(piece)
	if float(r["folga"]) < 0.0:
		_manual.append("%s: nada embaixo (fora do mapa?)" % r["onde"])
		return
	if _matches(piece, WALL_ITEMS):
		var moved: Variant = _to_wall(piece, box)
		if moved != null:
			_done.append("%s: estava solto no ar; foi até encostar na parede (%.2f m)" % [r["onde"], float(moved)])
			_mark_changed(piece)
		else:
			_manual.append("%s: coisa de parede no ar, sem parede perto" % r["onde"])
		return
	if box.get_longest_axis_size() <= SMALL:
		var top: Variant = _nearest_surface(piece, box)
		if top != null:
			var at: Vector3 = top
			_used.append(at)
			piece.global_position += Vector3(at.x - box.get_center().x, at.y - box.position.y, at.z - box.get_center().z)
			_done.append("%s: estava %.2f m no ar; foi para cima do móvel mais perto" % [r["onde"], float(r["folga"])])
			_mark_changed(piece)
			return
	_lift(piece, -float(r["folga"]))
	_done.append("%s: desceu %.2f m até o que está embaixo" % [r["onde"], float(r["folga"])])


## Um lugar em cima de uma mesa/baú/barril perto (até 3 m), onde ainda não tem nada. Devolve o ponto da superfície.
func _nearest_surface(piece: Node3D, box: AABB) -> Variant:
	var inside := _interior_of(piece)
	var best: Variant = null
	var best_d := 3.0
	for other: Node3D in _pieces:
		if other == piece or _interior_of(other) != inside or not _matches(other, SURFACES) or _is_person(other):
			continue
		var ob := _bounds(other)
		var shelf := _matches(other, ["shelf", "prateleira"])
		if ob.size.x < 0.25 or ob.size.z < 0.2 or (ob.size.y < 0.3 and not shelf) or ob.size.y > 1.4:
			continue
		var d := Vector2(ob.get_center().x, ob.get_center().z).distance_to(Vector2(box.get_center().x, box.get_center().z))
		if d >= best_d:
			continue
		# um ponto livre no tampo: o meio ou perto dos cantos
		for off: Vector2 in [Vector2.ZERO, Vector2(0.25, 0.25), Vector2(-0.25, 0.25), Vector2(0.25, -0.25), Vector2(-0.25, -0.25)]:
			var p := Vector3(ob.get_center().x + off.x * ob.size.x, 0, ob.get_center().z + off.y * ob.size.z)
			if _used.any(func(u: Vector3) -> bool: return Vector2(u.x, u.z).distance_to(Vector2(p.x, p.z)) < 0.15):
				continue
			var h: Variant = _surface_under(piece, p, ob.end.y + 0.4)
			if h == null or absf(float(h) - ob.end.y) > 0.12:
				continue  # já tem coisa em cima, ou o tampo não é ali
			best = Vector3(p.x, float(h), p.z)
			best_d = d
			break
	return best


## Empurra a peça (na altura dela) até encostar na parede mais perto, nas 4 direções da casa. Devolve quanto andou.
func _to_wall(piece: Node3D, box: AABB) -> Variant:
	var inside := _interior_of(piece)
	var basis := inside.global_basis if inside else Basis()
	var best_d := 2.5
	var best_dir := Vector3.ZERO
	for dir: Vector3 in [basis.x, -basis.x, basis.z, -basis.z]:
		dir = Vector3(dir.x, 0, dir.z).normalized()
		var from := box.get_center()
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * 2.5)
		query.exclude = _own_rids(piece)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var other: Variant = _owner_of.get(hit["rid"])
		if other != null and (_is_person(other as Node) or _interior_of(other as Node) != null):
			continue  # móvel ou gente: não é parede
		var half := absf(dir.dot(box.size)) / 2.0
		var d := from.distance_to(hit["position"]) - half - 0.01
		if d < best_d:
			best_d = d
			best_dir = dir
	if best_dir == Vector3.ZERO:
		return _slide_to_wall(piece, box)
	piece.global_position += best_dir * best_d
	return best_d


## Na frente de uma janela (atrás não tem parede): desliza ao longo da parede até ter parede firme atrás, e encosta.
func _slide_to_wall(piece: Node3D, box: AABB) -> Variant:
	var back := -piece.global_basis.z
	back = Vector3(back.x, 0, back.z).normalized()
	var along := back.cross(Vector3.UP)
	for dist: float in [0.4, -0.4, 0.7, -0.7, 1.0, -1.0, 1.3, -1.3, 1.6, -1.6]:
		for facing: Vector3 in [back, -back]:
			var from := box.get_center() + along * dist
			var query := PhysicsRayQueryParameters3D.create(from, from + facing * 1.2)
			query.exclude = _own_rids(piece)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				continue
			var other: Variant = _owner_of.get(hit["rid"])
			if other != null and (_is_person(other as Node) or _interior_of(other as Node) != null):
				continue
			var half := absf(facing.dot(box.size)) / 2.0
			var d := from.distance_to(hit["position"]) - half - 0.01
			piece.global_position += along * dist + facing * d
			return absf(dist) + d
	return null


func _lift(piece: Node3D, amount: float) -> void:
	piece.global_position += Vector3.UP * amount
	_mark_changed(piece)


# --- parte arrastada -------------------------------------------------------------------------------

func _fix_part(piece: Node3D, part_name: String) -> void:
	var part := piece.get_node_or_null(NodePath(part_name)) as Node3D
	if part == null:
		return
	var fresh := (load(piece.scene_file_path) as PackedScene).instantiate() as Node3D
	var original := fresh.get_node(NodePath(part_name)) as Node3D
	var default_xf := original.transform
	var only_this := true
	for child: Node in piece.get_children():
		var orig := fresh.get_node_or_null(NodePath(child.name)) as Node3D
		if child != part and orig and child is Node3D and not (child as Node3D).transform.is_equal_approx(orig.transform):
			only_this = false
	fresh.free()
	var where := part.global_transform
	piece.global_transform = where * default_xf.affine_inverse()
	part.transform = default_xf
	var inside := _interior_of(piece)
	if only_this:
		(inside if inside else level).set_editable_instance(piece, false)
	_done.append("%s: a peça foi para onde a parte \"%s\" estava (e a parte voltou para o encaixe)" % [_where(piece), part_name])
	_mark_changed(piece)


# --- gravar -------------------------------------------------------------------------------------------

func _save() -> void:
	# as colisões automáticas (feitas ao abrir a fase) não vão para o arquivo
	for node: Node in level.find_children("*", "CollisionObject3D", true, false):
		if not _original_nodes.has(node.get_instance_id()) and node.get_parent() is MeshInstance3D:
			node.owner = null
			for part: Node in node.find_children("*", "", true, false):
				part.owner = null
	for holder: Variant in _changed.keys():
		var node := holder as Node3D
		var path := String(level.scene_file_path) if node == level else String(node.get_meta("auditoria_cena"))
		if node != level:
			node.remove_meta("auditoria_cena")
			node.remove_meta("_editor_interior")
			node.get_parent().remove_child(node)  # o interior grava sozinho, sem estar dentro da fase
		var packed := PackedScene.new()
		var err := packed.pack(node)
		if err == OK:
			err = ResourceSaver.save(packed, path)
		print("GRAVOU %s: %s" % [path, error_string(err)])
