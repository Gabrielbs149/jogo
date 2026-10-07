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
	# o beco é estreito (~3,2 m) e o papelão fica perto de uma das paredes: mede para que lado há espaço
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
	var sgn := 1.0 if free_pos >= free_neg else -1.0
	var near := minf(free_pos, free_neg)
	var far := maxf(free_pos, free_neg)
	var c := sgn * (far - near) / 2.0  # linha do meio do beco (em x da cena)
	print("beco: ", near + far, " m de largura")
	# Tico encostado na parede, um pouco para um lado; Tika do outro lado da fogueirinha, um pouco para o outro:
	# assim nenhuma câmera vê um tapando o outro
	var tico_l := Vector3(c - sgn * 0.6, 0, tico_z)
	var tika_l := Vector3(c + sgn * 0.6, 0, tika_z)
	var fire_l := Vector3(c + sgn * 0.05, 0, (tico_z + tika_z) / 2.0 + 0.1)
	_scene("res://world/props/marquise.tscn", "Marquise", cena, Transform3D(basis, to_world.call(Vector3(c, 0, wall))))
	var tico_look := Basis.looking_at(basis * (tika_l - tico_l))
	var tika_look := Basis.looking_at(basis * (tico_l - tika_l))
	_add(Marker3D.new(), cena, Transform3D(tico_look, to_world.call(tico_l))).name = "TicoSentado"
	var tika := _scene("res://actors/tika_muro/tika_muro.tscn", "Tika", cena, Transform3D(tika_look, to_world.call(tika_l)))
	tika.visible = false
	# fogueirinha entre os dois com o rato no espeto em cima (D029)
	var fire_at: Vector3 = to_world.call(fire_l)
	var fire := Node3D.new()
	fire.name = "Fogueirinha"
	_add(fire, cena, Transform3D(Basis(), fire_at))
	for i: int in 8:
		var a := i * TAU / 8.0
		_scene("res://assets/kits/quaternius/natureza/Pebble_Round_%d.gltf" % (1 + i % 5), "Pedra", fire,
			Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 0.55), fire_at + Vector3(cos(a), 0, sin(a)) * 0.2))
	var flame := _scene("res://assets/vfx/fogo.tscn", "Fogo", fire, Transform3D(Basis().scaled(Vector3.ONE * 0.32), fire_at + Vector3.UP * 0.03))
	var glow := flame.get_node("Light") as OmniLight3D
	glow.light_energy = 0.9
	glow.set("base_energy", 0.9)
	glow.omni_range = 3.0
	level.set_editable_instance(flame, true)
	fire.visible = false
	var toward: Vector3 = fire_at - to_world.call(tico_l)
	toward.y = 0.0
	var spit := Basis(Vector3.UP, atan2(-toward.z, toward.x)).rotated(toward.normalized().cross(Vector3.UP), -0.15)
	_add(Marker3D.new(), cena, Transform3D(spit, fire_at + Vector3.UP * 0.2)).name = "EspetoNoFogo"
	var rat := _scene("res://actors/props/rato/rato_espeto.glb", "Rato", cena, Transform3D(spit, fire_at + Vector3.UP * 0.2))
	rat.visible = false
	rat.set_meta("pega", Vector3(-0.34, -0.02, 0.0))  # ponta do graveto (cutscene: [na mão: Rato])
	rat.set_meta("inclinacao", 0.45)
	var piece := _scene("res://actors/props/rato/rato_traseiro.glb", "PedacoDaTika", cena,
		Transform3D(tika_look.rotated(Vector3.UP, 0.6), to_world.call(tika_l + Vector3(-sgn * 0.12, 0.48, 0.22))))
	piece.visible = false
	var mid_l := (tico_l + tika_l) / 2.0
	var cam := func(name: String, from: Vector3, to: Vector3, fov: float) -> void:
		_camera(name, cena, to_world.call(from), to_world.call(to), fov)
	# 1: os dois, vistos da boca do beco; 2: por cima do ombro da Tika, para o Tico; 3: por cima do ombro do
	# Tico, para a Tika; 4: plano aberto e alto para o fim; 5: perto do fogo e do rato
	cam.call("Plano1", Vector3(c - sgn * 1.6, 1.5, tika_z - 2.6), mid_l + Vector3(0, 0.5, 0), 50)
	# 2 e 3: close de cada um, de frente; a câmera fica ao lado do outro (fora da linha de visão)
	cam.call("Plano2", Vector3(c + sgn * 2.2, 1.0, tico_z - 0.75), tico_l + Vector3(0, 0.55, 0), 34)
	cam.call("Plano3", Vector3(c - sgn * 2.2, 1.15, tika_z + 0.75), tika_l + Vector3(0, 0.75, 0), 34)
	cam.call("Plano4", Vector3(c - sgn * 0.3, 2.6, tika_z - 4.2), mid_l + Vector3(0, 0.55, 0), 50)
	cam.call("Plano5", fire_l + Vector3(sgn * 0.7, 0.42, -0.35), fire_l + Vector3(0, 0.17, 0), 38)
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
