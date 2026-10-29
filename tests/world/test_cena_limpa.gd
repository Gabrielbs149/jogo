extends GutTest
## Ninguém passa na frente da cena (D089): quem anda pela rua e entra no quadro da câmera de cena some até sair.

const ARANDU := "res://levels/arandu/arandu.tscn"


func test_passerby_in_the_shot_hides_until_the_scene_ends() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge({"prologo.etapa": "fim"})
	Game.seen.assign([ARANDU])
	Game.hora = 10.0
	var level := (load(ARANDU) as PackedScene).instantiate() as Level
	level.skip_intro = true
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.ready_to_play, 20.0)
	var vida := level.get_node("Vida") as Vida
	await wait_until(func() -> bool: return vida.people.any(func(p: Passante) -> bool: return p.visible), 10.0)
	var person: Passante = null
	for p: Passante in vida.people:
		if p.visible:
			person = p
			break
	var body := person.get_node("Figure") as Node3D
	assert_null(level.camera_de_cena(), "jogando: a câmera é a do jogo")
	# uma câmera de cena olhando para a pessoa, de perto
	var cam := Camera3D.new()
	level.add_child(cam)
	var at := person.global_position
	cam.look_at_from_position(at + Vector3(0, 1.6, 4.0), at + Vector3.UP)
	cam.make_current()
	level.em_cena = true
	await wait_process_frames(3)
	assert_eq(level.camera_de_cena(), cam)
	assert_false(body.visible, "no quadro da cena, ela some")
	assert_true(person.visible, "a pessoa continua vivendo (só o corpo some)")
	level.em_cena = false
	(level.get("_camera") as ThirdPersonCamera).camera.make_current()
	cam.queue_free()
	await wait_process_frames(3)
	assert_true(body.visible, "acabou a cena, ela volta")
