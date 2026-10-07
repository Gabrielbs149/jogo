extends SceneTree
## Uso: godot --headless --path . -s tools/art/montar_cena_tico.gd  (depois do montar_arandu.gd)
## Monta o cenário da 1ª cena do Tico em Arandu (nó CenaTico) e tira a Tika do acampamento de Ethera.

var level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _open(path: String) -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	for i: int in 3:
		await physics_frame


func _save(path: String) -> void:
	var packed := PackedScene.new()
	print(path, " pack ", packed.pack(level), " save ", ResourceSaver.save(packed, path))
	level.queue_free()
	await process_frame


func _add(node: Node3D, parent: Node, at: Transform3D) -> Node3D:
	parent.add_child(node, true)
	node.owner = level
	node.global_transform = at
	return node


func _scene(path: String, name: String, parent: Node, at: Transform3D) -> Node3D:
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = name
	return _add(node, parent, at)


func _camera(name: String, parent: Node, from: Vector3, to: Vector3, fov: float) -> void:
	var cam := Camera3D.new()
	cam.name = name
	cam.fov = fov
	cam.current = false
	_add(cam, parent, Transform3D(Basis(), from))
	cam.look_at(to, Vector3.UP)


func _run() -> void:
	await _open("res://levels/arandu/arandu.tscn")
	var old := level.get_node_or_null("CenaTico")
	if old:
		level.remove_child(old)
		old.free()
	var blanket := level.get_node("TicoCorner/Blanket") as MeshInstance3D
	var cardboard := StandardMaterial3D.new()
	cardboard.albedo_color = Color(0.56, 0.43, 0.28)
	cardboard.roughness = 1.0
	blanket.material_override = cardboard  # o papelão onde o Tico dorme
	var spot := blanket.global_position
	spot.y = 0.0
	# a parede mais perto do papelão: o Tico senta encostado nela, com a marquise em cima
	var best := Vector3.ZERO
	var best_d := INF
	var space := level.get_world_3d().direct_space_state
	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP, spot + Vector3.UP + dir * 6.0, 1))
		if not hit.is_empty() and spot.distance_to(hit["position"] - Vector3.UP) < best_d:
			best_d = spot.distance_to(hit["position"] - Vector3.UP)
			best = dir
	print("parede: ", best, " a ", best_d, " m")
	var yaw := atan2(best.x, best.z)  # +Z da cena aponta para a parede
	var basis := Basis(Vector3.UP, yaw)
	var cena := Node3D.new()
	cena.name = "CenaTico"
	_add(cena, level, Transform3D(basis, spot))
	var wall := best_d
	var tico_z := wall - 0.5
	var tika_z := tico_z - 1.15
	var to_world := func(local: Vector3) -> Vector3: return cena.global_transform * local
	_scene("res://world/props/marquise.tscn", "Marquise", cena, Transform3D(basis, to_world.call(Vector3(0, 0, wall))))
	_add(Marker3D.new(), cena, Transform3D(basis, to_world.call(Vector3(0, 0, tico_z)))).name = "TicoSentado"
	var tika := _scene("res://actors/tika_muro/tika_muro.tscn", "Tika", cena, Transform3D(basis.rotated(Vector3.UP, PI), to_world.call(Vector3(0, 0, tika_z))))
	tika.visible = false
	var pao := _scene("res://world/props/pao.tscn", "Pao", cena, Transform3D(basis, to_world.call(Vector3(0.25, 0.25, tico_z - 0.1))))
	pao.visible = false
	var meio := _scene("res://world/props/meio_pao.tscn", "PaoDaTika", cena, Transform3D(basis.rotated(Vector3.UP, 0.5), to_world.call(Vector3(-0.12, 0.5, tika_z + 0.22))))
	meio.visible = false
	var mid: Vector3 = to_world.call(Vector3(0, 0, (tico_z + tika_z) / 2.0))
	var tico_at: Vector3 = to_world.call(Vector3(0, 0, tico_z))
	var tika_at: Vector3 = to_world.call(Vector3(0, 0, tika_z))
	# as câmeras ficam do lado aberto do beco (o outro lado pode ser parede)
	var side := basis.x
	var free_pos := 0.0
	var free_neg := 0.0
	for k: int in 2:
		var dir := basis.x * (1.0 if k == 0 else -1.0)
		var from: Vector3 = to_world.call(Vector3(0, 1.0, (tico_z + tika_z) / 2.0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 8.0, 1))
		var dist := 8.0 if hit.is_empty() else from.distance_to(hit["position"])
		if k == 0:
			free_pos = dist
		else:
			free_neg = dist
	if free_neg > free_pos:
		side = -basis.x
	print("lado aberto: ", maxf(free_pos, free_neg), " m")
	_camera("Plano1", cena, mid + side * 2.7 + Vector3.UP * 1.25 + basis.z * -0.4, mid + Vector3.UP * 0.45, 48)
	_camera("Plano2", cena, tika_at + side * 0.85 + Vector3.UP * 1.15 + basis.z * -0.95, tico_at + Vector3.UP * 0.45, 40)
	_camera("Plano3", cena, tico_at + side * 1.15 + Vector3.UP * 1.05 + basis.z * -0.15, tika_at + Vector3.UP * 0.7, 40)
	_camera("Plano4", cena, mid + side * 3.2 + Vector3.UP * 2.2 + basis.z * -0.6, mid + Vector3.UP * 0.6, 55)
	level.set("cena_de_abertura", load("res://story/tico_cena1.tres"))
	level.set("intro_lines", PackedStringArray())
	await _save("res://levels/arandu/arandu.tscn")
	# Ethera: a Tika foi levada (história do Tico) — ela não espera mais no acampamento
	await _open("res://levels/ethera/ethera.tscn")
	var tika_camp := level.get_node_or_null("Camp/TikaMuro")
	if tika_camp:
		tika_camp.get_parent().remove_child(tika_camp)
		tika_camp.free()
	await _save("res://levels/ethera/ethera.tscn")
	quit()
