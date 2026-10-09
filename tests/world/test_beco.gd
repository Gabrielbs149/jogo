extends GutTest
## O canto do Tico e da Tika no beco (D062): as peças estão lá, a cama não empurra quem deita e nada do barraco tapa as
## câmeras da cena do rato.

const ARANDU := "res://levels/arandu/arandu.tscn"

var _level: Level


func before_all() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge({"prologo.etapa": "saiu", "comida.comecou": true})
	Game.hora = 11.0
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 25.0)


func after_all() -> void:
	_level.queue_free()
	Game.flags.clear()


func test_the_corner_has_its_pieces() -> void:
	var corner := _level.get_node_or_null("TicoCorner/Barraco") as Node3D
	assert_not_null(corner, "o barraco foi montado")
	for piece: String in ["Lona", "CamaTico", "CamaTika", "Assento", "Varal", "Lenha", "Cinzas", "Prateleira", "Lanterna", "Chao", "Giz"]:
		assert_not_null(corner.get_node_or_null(piece), piece)
	assert_false((_level.get_node("TicoCorner/Blanket") as Node3D).visible, "o papelão liso de antes some")
	var look := _level.get_node("TicoCorner/Look")
	assert_eq(String(look.get("prompt_text")), "Examinar a cama")


func test_the_scene_props_have_unique_names() -> void:
	# o roteiro acha as coisas pelo nome ([na mão: Rato]); o rato que anda pela cidade se chamava "Rato" também e era
	# ele que ia parar gigante na fogueira e na mão do Tico
	for prop: String in ["Rato", "Tika", "Fogueirinha", "PedacoDaTika", "PaoDoTico", "MeioPaoTico", "MeioPaoTika",
			"EspetoNoFogo", "TicoDeitado", "TicoSentado", "TikaAcordando", "TikaSentada"]:
		var found := _level.find_children(prop, "", true, false)
		assert_eq(found.size(), 1, "só um nó chamado %s na fase" % prop)
		if found.size() > 0:
			assert_true(String(found[0].get_path()).contains("CenaTico"), "%s é o da cena" % prop)


func test_the_bed_has_no_collision() -> void:
	# o Tico deita na marca TicoDeitado: se a cama tivesse colisão, ele seria empurrado para fora
	var bed := _level.get_node("TicoCorner/Barraco/CamaTico") as Node3D
	assert_true(bed.find_children("*", "CollisionObject3D", true, false).is_empty())
	var tika_bed := _level.get_node("TicoCorner/Barraco/CamaTika") as Node3D
	assert_true(tika_bed.find_children("*", "CollisionObject3D", true, false).is_empty())


func test_nothing_blocks_the_rat_scene_cameras() -> void:
	await wait_physics_frames(2)
	var cena := _level.get_node("CenaTico") as Node3D
	var tico := (cena.get_node("TicoSentado") as Node3D).global_position + Vector3(0, 0.5, 0)
	var tika := (cena.get_node("TikaSentada") as Node3D).global_position + Vector3(0, 0.5, 0)
	var space := _level.get_world_3d().direct_space_state
	# Plano2 olha o Tico por cima do ombro da Tika; Plano3 olha a Tika por cima do ombro do Tico; Plano1 é o acordar
	for pair: Array in [["Plano2", tico], ["Plano3", tika], ["Plano1", (cena.get_node("TicoDeitado") as Node3D).global_position + Vector3(0, 0.3, 0)]]:
		var cam := cena.get_node(String(pair[0])) as Node3D
		var query := PhysicsRayQueryParameters3D.create(cam.global_position, pair[1] as Vector3, 1)
		var hit := space.intersect_ray(query)
		assert_true(hit.is_empty(), "%s vê sem nada na frente (bateu em %s)" % [pair[0], "" if hit.is_empty() else String((hit["collider"] as Node).get_path())])
