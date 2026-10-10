extends GutTest
## Câmera das conversas (D064): troca de plano por quem fala, vê o rosto de quem fala e devolve tudo no fim.

const ARANDU := "res://levels/arandu/arandu.tscn"

var _level: Level


func before_all() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge({"prologo.etapa": "saiu", "comida.comecou": true})
	Game.hora = 10.0
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 25.0)


func after_all() -> void:
	_level.queue_free()
	Game.flags.clear()


func _talk_to(path: String, dist: float) -> Node3D:
	var who := _level.get_node(path) as Node3D
	var front := -who.global_basis.z
	front.y = 0.0
	_level.player.global_position = who.global_position + front.normalized() * dist + Vector3.UP * 0.1
	_level.player.reset_physics_interpolation()
	await wait_physics_frames(3)
	_level.focus_talk(who)
	await wait_seconds(0.3)
	return who


func test_shots_follow_who_is_talking() -> void:
	var who := await _talk_to("People/Bras", 1.6)
	var cam := _level.get_node("CameraConversa") as CameraConversa
	assert_eq(get_viewport().get_camera_3d(), cam, "a câmera da conversa assume")
	var box := _level.get_node("HUD").get("dialogue") as DialogueBox
	box.line_started.emit("Bras", false)
	assert_eq(String(cam.get("_shot")), "outro", "fala dele: por cima do ombro do Tico")
	box.line_started.emit("Tico", false)
	assert_eq(String(cam.get("_shot")), "heroi", "fala do Tico: por cima do ombro dele")
	box.line_started.emit("Bras", true)
	assert_eq(String(cam.get("_shot")), "dois", "escolha: os dois")
	_level.focus_talk(null)
	assert_ne(get_viewport().get_camera_3d(), cam, "no fim volta a câmera do jogo")
	assert_not_null(who)


func test_the_speaker_face_is_in_view() -> void:
	var who := await _talk_to("Crowd/Vendedor2", 2.7)
	var cam := _level.get_node("CameraConversa") as CameraConversa
	cam.shot("Vendedor", false, 0.0)
	var plan: Array = cam.call("_plan", "outro")
	var face: Vector3 = cam.call("_head", who)
	assert_true(bool(cam.call("_clear_view", plan[0], face)), "nada entre a câmera e o rosto do vendedor")
	var hidden: Array = cam.get("_hidden")
	_level.focus_talk(null)
	for node: Node3D in hidden:
		assert_true(node.visible, "%s volta a aparecer no fim da conversa" % node.name)
