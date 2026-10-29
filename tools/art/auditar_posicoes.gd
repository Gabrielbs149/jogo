extends SceneTree
## Confere as posições de uma fase (D088): abre a fase com TODOS os interiores das casas e as colisões do jogo e
## procura, peça por peça e pessoa por pessoa:
##   VOANDO      nada embaixo da peça (nem chão, nem móvel, nem preso numa parede)
##   AFUNDADA    a peça está enfiada no chão (ou no que está embaixo dela)
##   PAREDE      pessoa dentro de parede/móvel (a cápsula dela bate em alguma coisa)
##   PESSOA_AR   pessoa de pé no ar          PESSOA_CHAO  pessoa com os pés enfiados no chão
##   COLISAO     caixa de colisão de um móvel do interior que ficou para trás quando o móvel foi arrastado
##   FORA        peça do interior fora da casa
##   PARTE       parte de dentro de uma peça arrastada para longe dela (a caneca longe do "pé" dela)
## Uso: godot --headless --path . -s tools/art/auditar_posicoes.gd [-- fase.tscn] [-- --json saida.json]
## Só lê: não muda nada. Quem conserta é o tools/art/consertar_posicoes.gd (com o que esta auditoria acha).

const DEFAULT_LEVEL := "res://levels/arandu/arandu.tscn"
const SYSTEM: Array[String] = ["WorldEnvironment", "Sun", "Navigation", "CameraRig", "HUD", "FX", "Terrain", "Ground", "Embers",
	"Grama", "Smoke", "Missoes", "Vida", "CicloDoDia", "AmbienteCamadas", "Lights"]
## O que fica no ar de propósito (pendurado, preso na parede, voando, só luz/marca).
const AIRBORNE := ["lanterna", "lantern", "lamp", "lustre", "chandelier", "placa", "sign", "banner", "bandeira", "flag", "varal",
	"corda", "rope", "pombo", "pigeon", "bird", "passaro", "fumaca", "smoke", "janela", "window", "luz", "light", "shelf", "prateleira",
	"gancho", "hook", "quadro", "painting", "frame", "coifa", "chamine", "chimney", "telhado", "roof", "toldo", "awning", "cortina",
	"curtain", "relogio", "clock", "sino", "bell", "tocha", "torch", "vela_parede", "candle_wall", "espada_parede", "escudo",
	"shield", "cabeca", "trofeu", "estandarte", "pendurad", "ninho", "nest", "teia", "web", "marca", "spawn", "plano", "camera", "espeto"]
const SEATED := ["sit", "sentad", "lie", "deitad"]
## Folgas (m).
const GAP_FLOATING := 0.1
const SUNK := 0.2
## A superfície embaixo é procurada desta altura acima da base (acha também o chão que passou da base).
const START := 0.35
## Grupos da fase enterrados de propósito (muralha com alicerce, tronco de árvore, pedra, canteiro, caminho).
const NATURAL_GROUPS: Array[String] = ["Walls", "Trees", "Rocks", "Gardens", "Paths", "Caminhos", "Plaza", "Ground", "Terrain", "Grass", "Decals"]

var level: Node3D
var space: PhysicsDirectSpaceState3D
var report: Array[Dictionary] = []
var _owner_of: Dictionary = {}  # RID do corpo de colisão -> peça dona
var _pieces: Array[Node3D] = []
var _grid: Dictionary = {}  # célula 2 m -> peças cuja caixa passa nela (para achar o que está embaixo sem olhar tudo)
var _boxes: Dictionary = {}
var _tri: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := DEFAULT_LEVEL
	var json_out := ""
	var i := 0
	while i < args.size():
		if args[i] == "--json" and i + 1 < args.size():
			json_out = args[i + 1]
			i += 1
		elif args[i].ends_with(".tscn"):
			path = args[i]
		i += 1
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	var interiors := _load_interiors()
	if level.has_method("_auto_collision"):
		level.call("_auto_collision")
	for k: int in 3:
		await physics_frame
	space = level.get_world_3d().direct_space_state
	_collect(interiors)
	print("fase %s: %d peças, %d interiores carregados" % [path, _pieces.size(), interiors.size()])
	for piece: Node3D in _pieces:
		if String(piece.get_parent().name) == "CenaTico":
			continue  # o pão na mão, o pedaço da Tika: quem põe no lugar é o roteiro da cena
		if _is_person(piece):
			_check_person(piece)
		else:
			_check_piece(piece)
			_check_parts(piece)
	for inside: Node3D in interiors:
		_check_interior(inside)
	var counts := {}
	for r: Dictionary in report:
		counts[r["tipo"]] = int(counts.get(r["tipo"], 0)) + 1
		print("%-9s %-70s %s" % [r["tipo"], r["onde"], r["texto"]])
	print("RESUMO ", counts)
	if json_out != "":
		var file := FileAccess.open(json_out, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	quit()


## Põe cada interior dentro da casa dele (como o jogo faz quando você chega perto). Devolve os interiores.
func _load_interiors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for found: Node in level.find_children("Interior", "", true, false):
		var cena := String(found.get("cena")) if "cena" in found else ""
		if cena == "" or not ResourceLoader.exists(cena):
			continue
		var inside := (load(cena) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
		inside.set_meta("auditoria_cena", cena)
		found.add_child(inside)
		result.append(inside)
	return result


## As peças: os filhos dos grupos da fase (Buildings, Props...), o que está solto na raiz e os filhos de cada interior.
func _collect(interiors: Array[Node3D]) -> void:
	for child: Node in level.get_children():
		if not child is Node3D or SYSTEM.has(String(child.name)):
			continue
		if _is_group(child):
			for inner: Node in child.get_children():
				if inner is Node3D:
					_add_piece(inner as Node3D)
		else:
			_add_piece(child as Node3D)
	for inside: Node3D in interiors:
		for inner: Node in inside.get_children():
			if inner is Node3D and not inner is CollisionObject3D and not inner is Light3D:
				_add_piece(inner as Node3D)


func _add_piece(piece: Node3D) -> void:
	_pieces.append(piece)
	for body: Node in [piece] + piece.find_children("*", "CollisionObject3D", true, false):
		if body is CollisionObject3D:
			_owner_of[(body as CollisionObject3D).get_rid()] = piece
	var box := _bounds(piece)
	_boxes[piece] = box
	if box.get_longest_axis_size() > 40.0:
		return
	for x: int in range(floori(box.position.x / 2.0), floori(box.end.x / 2.0) + 1):
		for z: int in range(floori(box.position.z / 2.0), floori(box.end.z / 2.0) + 1):
			var key := Vector2i(x, z)
			if not _grid.has(key):
				_grid[key] = []
			(_grid[key] as Array).append(piece)


func _is_group(node: Node) -> bool:
	if not (node.get_class() == "Node3D" and node.get_script() == null and node.scene_file_path == ""):
		return false
	for child: Node in node.get_children():
		if child.scene_file_path != "" or child.get_script() != null:
			return true
		if child is Node3D and not (child is VisualInstance3D or child is CollisionObject3D):
			return true
	return node.get_child_count() == 0


func _is_person(node: Node) -> bool:
	return node.get_node_or_null("Figure") != null or node.get_script() != null and String((node.get_script() as Script).resource_path).contains("/vida/")


func _where(node: Node) -> String:
	var inside := _interior_of(node)
	if inside:
		return "%s:%s" % [String(inside.get_meta("auditoria_cena")).get_file().get_basename(), inside.get_path_to(node)]
	return String(level.get_path_to(node))


func _interior_of(node: Node) -> Node3D:
	var current := node
	while current:
		if current.has_meta("auditoria_cena"):
			return current as Node3D
		current = current.get_parent()
	return null


func _matches(node: Node, words: Array) -> bool:
	var text := (String(node.name) + " " + node.scene_file_path.get_file()).to_lower()
	for w: String in words:
		if text.contains(w):
			return true
	return false


func _add(tipo: String, node: Node3D, texto: String, extra: Dictionary = {}) -> void:
	var entry := {"tipo": tipo, "onde": _where(node), "texto": texto, "pos": [node.global_position.x, node.global_position.y, node.global_position.z]}
	var inside := _interior_of(node)
	entry["cena"] = String(inside.get_meta("auditoria_cena")) if inside else String(level.scene_file_path)
	entry["caminho"] = String((inside if inside else level).get_path_to(node))
	entry.merge(extra)
	report.append(entry)


# --- peças ---------------------------------------------------------------------------------------

## VOANDO / AFUNDADA: a superfície mais alta embaixo da pegada (procurada um pouco acima da base, para achar também o
## chão que já passou da base). Muralha, árvore, pedra e canteiro enterrados de propósito não contam como afundados.
func _check_piece(piece: Node3D) -> void:
	var box: AABB = _boxes[piece]
	if box.get_longest_axis_size() > 40.0 or box.size.y < 0.01 or _matches(piece, AIRBORNE):
		return
	if piece.find_children("*", "VisualInstance3D", true, false).is_empty() and not piece is VisualInstance3D:
		return  # marca, luz, começo: não tem corpo
	var bottom := box.position.y
	var start := bottom + START
	var highest: Variant = null
	var center: Variant = null
	for p: Vector3 in _samples(box):
		var h: Variant = _surface_under(piece, p, start)
		if p == box.get_center():
			center = h
		if h != null and (highest == null or float(h) > float(highest)):
			highest = h
	if highest == null or bottom - float(highest) > GAP_FLOATING:
		if _touches_wall(piece, box):
			return  # preso numa parede (lanterna, placa, prateleira)
		var gap := bottom - float(highest) if highest != null else -1.0
		_add("VOANDO", piece, ("%.2f m acima do que está embaixo" % gap) if gap >= 0.0 else "nada embaixo", {"folga": gap, "apoio": highest})
		return
	var natural := _interior_of(piece) == null and String(piece.get_parent().name) in NATURAL_GROUPS
	if center != null and float(center) - bottom > SUNK and box.size.y > 0.2 and not natural:
		_add("AFUNDADA", piece, "%.2f m enfiada no que está embaixo" % (float(center) - bottom), {"folga": bottom - float(center), "apoio": center})


## Pontos da pegada: o meio e quatro perto dos cantos.
func _samples(box: AABB) -> Array[Vector3]:
	var c := box.get_center()
	var hx := box.size.x * 0.3
	var hz := box.size.z * 0.3
	return [c, c + Vector3(hx, 0, hz), c + Vector3(-hx, 0, hz), c + Vector3(hx, 0, -hz), c + Vector3(-hx, 0, -hz)]


## A altura da coisa mais alta embaixo de `at`, procurando da altura `start` para baixo: colisão (menos as pessoas) ou o
## desenho de outra peça (o prato em cima da mesa, a caneca na prateleira não têm colisão). null = nada em 8 m.
func _surface_under(piece: Node3D, at: Vector3, start: float) -> Variant:
	var from := Vector3(at.x, start, at.z)
	var best: Variant = null
	var exclude := _own_rids(piece)
	for k: int in 6:
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var other: Variant = _owner_of.get(hit["rid"])
		if other != null and _is_person(other as Node):
			exclude.append(hit["rid"])
			continue
		best = (hit["position"] as Vector3).y
		break
	var key := Vector2i(floori(at.x / 2.0), floori(at.z / 2.0))
	for other: Node3D in _grid.get(key, []):
		if other == piece or piece.is_ancestor_of(other) or other.is_ancestor_of(piece) or _is_person(other):
			continue
		var ob: AABB = _boxes[other]
		if at.x < ob.position.x or at.x > ob.end.x or at.z < ob.position.z or at.z > ob.end.z:
			continue
		if ob.position.y > from.y or ob.end.y < from.y - 8.0:
			continue
		var d := _mesh_down(other, from)
		if d < INF and (best == null or from.y - d > float(best)):
			best = from.y - d
	return best


func _own_rids(piece: Node3D) -> Array[RID]:
	var rids: Array[RID] = []
	for body: Node in [piece] + piece.find_children("*", "CollisionObject3D", true, false):
		if body is CollisionObject3D:
			rids.append((body as CollisionObject3D).get_rid())
	return rids


## Distância de `from` (para baixo) até o desenho da peça, INF se o raio não encosta.
func _mesh_down(piece: Node3D, from: Vector3) -> float:
	var best := INF
	var meshes: Array[Node] = piece.find_children("*", "MeshInstance3D", true, false)
	if piece is MeshInstance3D:
		meshes.append(piece)
	for found: Node in meshes:
		var mi := found as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var tri: TriangleMesh = _tri.get(mi.mesh)
		if tri == null:
			tri = mi.mesh.generate_triangle_mesh()
			if tri == null:
				continue
			_tri[mi.mesh] = tri
		var inv := mi.global_transform.affine_inverse()
		var hit := tri.intersect_ray(inv * from, (inv.basis * Vector3.DOWN).normalized())
		if not hit.is_empty():
			best = minf(best, from.y - (mi.global_transform * (hit["position"] as Vector3)).y)
	return best


## Presa numa parede: a caixa da peça (um pouco maior) encosta numa colisão de outra peça que não está embaixo dela.
func _touches_wall(piece: Node3D, box: AABB) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(box.size.x + 0.08, maxf(box.size.y - 0.1, 0.02), box.size.z + 0.08)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), box.get_center() + Vector3.UP * 0.05)
	params.exclude = _own_rids(piece)
	for hit: Dictionary in space.intersect_shape(params, 8):
		var other: Variant = _owner_of.get(hit["rid"])
		if other == null or not _is_person(other as Node):
			return true
	return false


func _surface_from_above(piece: Node3D, box: AABB) -> Variant:
	var c := box.get_center()
	var from := Vector3(c.x, box.end.y + 0.5, c.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (box.size.y + 6.0))
	var exclude := _own_rids(piece)
	for k: int in 6:
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return null
		var other: Variant = _owner_of.get(hit["rid"])
		# o que está em cima de outra peça vale pela outra; ignora o que fica por cima (telhado, galho)
		if other != null and (other as Node3D) != piece and _boxes.has(other) and (_boxes[other] as AABB).position.y > box.position.y + 0.05:
			exclude.append(hit["rid"])
			continue
		return (hit["position"] as Vector3).y
	return null


## PARTE: alguém arrastou a parte de dentro de uma peça (o "Mug" de dentro do "Mug2") para longe da peça.
func _check_parts(piece: Node3D) -> void:
	if piece.scene_file_path == "":
		return
	var home := _interior_of(piece)
	var holder: Node = home if home else level
	if not holder.is_editable_instance(piece):
		return
	var fresh := (load(piece.scene_file_path) as PackedScene).instantiate() as Node3D
	for child: Node in piece.get_children():
		var original := fresh.get_node_or_null(NodePath(child.name)) as Node3D
		if original == null or not child is Node3D:
			continue
		var moved := (child as Node3D).position.distance_to(original.position)
		if moved > 0.25:
			_add("PARTE", piece, "a parte \"%s\" foi arrastada %.2f m para longe da peça" % [child.name, moved], {"parte": String(child.name)})
	fresh.free()


# --- pessoas -------------------------------------------------------------------------------------

func _check_person(person: Node3D) -> void:
	var anim := ""
	var fig := person.get_node_or_null("Figure")
	if fig and "animacao" in fig:
		anim = String(fig.get("animacao")).to_lower()
	var seated := false
	for w: String in SEATED:
		seated = seated or anim.contains(w)
	var feet := person.global_position.y
	var floor_y: Variant = _surface_under(person, person.global_position, feet + 0.6)
	# PESSOA_AR / PESSOA_CHAO: de pé, os pés no chão (sentado fica na altura da cadeira)
	if not seated:
		if floor_y == null or feet - float(floor_y) > 0.12:
			_add("PESSOA_AR", person, ("%.2f m acima do chão" % (feet - float(floor_y))) if floor_y != null else "nada embaixo",
				{"apoio": floor_y})
		elif float(floor_y) - feet > 0.12:
			_add("PESSOA_CHAO", person, "pés %.2f m enfiados no chão" % (float(floor_y) - feet), {"apoio": floor_y})
	# PAREDE: a cápsula da pessoa (de pé em cima do chão de verdade) bate em parede ou móvel
	var base := maxf(feet, float(floor_y)) if floor_y != null and not seated else feet
	var shape := CapsuleShape3D.new()
	shape.radius = 0.22
	shape.height = 0.9 if seated else 1.2
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), Vector3(person.global_position.x, base + 0.2 + shape.height / 2.0 + (0.2 if seated else 0.0), person.global_position.z))
	params.exclude = _own_rids(person)
	var hits: Array[String] = []
	for hit: Dictionary in space.intersect_shape(params, 8):
		var other: Variant = _owner_of.get(hit["rid"])
		var what := String((other as Node).name) if other != null else String((hit["collider"] as Node).name)
		if other != null and _is_person(other as Node):
			continue  # outra pessoa encostada não prende ninguém
		if seated and other != null and _matches(other as Node, ["cadeira", "chair", "banco", "bench", "stool", "banquinho", "cama", "bed", "sofa"]):
			continue  # sentado na cadeira / deitado na cama
		if not hits.has(what):
			hits.append(what)
	if not hits.is_empty():
		_add("PAREDE", person, "dentro de: %s" % ", ".join(hits), {"apoio": floor_y, "sentado": seated})


# --- interiores ----------------------------------------------------------------------------------

func _check_interior(inside: Node3D) -> void:
	var building := inside.get_parent().get_parent() as Node3D if inside.get_parent() else null
	var cells: Variant = building.get_meta("celulas") if building and building.has_meta("celulas") else null
	var previous: Node3D = null
	for child: Node in inside.get_children():
		if child is StaticBody3D and String(child.name).begins_with("Colisao"):
			_check_collision_box(child as StaticBody3D, previous)
			continue
		if not child is Node3D or child is Light3D:
			continue
		previous = child as Node3D
		if cells != null:
			var local := building.global_transform.affine_inverse() * (child as Node3D).global_position
			var c: Vector2i = cells
			if absf(local.x) > c.x + 0.05 or absf(local.z) > c.y + 0.05:
				_add("FORA", child as Node3D, "fora da casa (%.1f, %.1f) — a casa vai até ±%d, ±%d" % [local.x, local.z, c.x, c.y])


## COLISAO: a caixa de colisão vem logo depois do móvel dela (tools/art/montar_interiores.gd). Se ela não está mais
## em cima do móvel, o móvel foi arrastado e a caixa ficou para trás (parede invisível no lugar antigo).
func _check_collision_box(body: StaticBody3D, piece: Node3D) -> void:
	if piece == null or not _boxes.has(piece):
		return
	var shape_node := body.get_child(0) as CollisionShape3D if body.get_child_count() > 0 else null
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return
	var size := (shape_node.shape as BoxShape3D).size
	var world := shape_node.global_transform * AABB(-size / 2.0, size)  # com o giro da caixa
	var center := world.get_center()
	var col := Rect2(world.position.x, world.position.z, world.size.x, world.size.z)
	var pb: AABB = _boxes[piece]
	var vis := Rect2(pb.position.x, pb.position.z, pb.size.x, pb.size.z)
	var overlap := col.intersection(vis)
	var ratio := overlap.get_area() / maxf(col.get_area(), 0.0001) if col.intersects(vis) else 0.0
	if ratio < 0.5:
		_add("COLISAO", piece, "a colisão de \"%s\" ficou %.2f m longe dele (%s)" % [piece.name, Vector2(center.x, center.z).distance_to(Vector2(pb.get_center().x, pb.get_center().z)), body.name],
			{"corpo": String(body.name)})


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var visuals: Array[Node] = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		visuals.append(node)
	for v: Node in visuals:
		var vi := v as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Light3D or vi is GPUParticles3D or vi is Label3D or vi is Decal:
			continue
		var part := vi.global_transform * vi.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		box = AABB(node.global_position - Vector3(0.2, 0.0, 0.2), Vector3(0.4, 0.4, 0.4))
	return box
