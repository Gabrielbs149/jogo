extends GutTest
## Cenas (Roteiro): o roteiro do jeito que se escreve a cena + comandos entre colchetes.


func _arandu() -> Node3D:
	Game.chosen = "tico"
	Game.party.clear()
	var level := (load(Game.ARANDU) as PackedScene).instantiate() as Node3D
	level.set("skip_intro", true)
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.get("ready_to_play"), 15.0)
	return level


func test_reads_dialogue_like_a_screenplay() -> void:
	var player := (load("res://story/cutscene_player.tscn") as PackedScene).instantiate() as CutscenePlayer
	add_child_autofree(player)
	assert_eq(player.call("_dialogue_of", 'Tico: "Você sabe que eu achei isso, né?"'), ["Tico", "Você sabe que eu achei isso, né?"])
	assert_eq(player.call("_dialogue_of", "???: Você vai mesmo dividir isso comigo?"), ["???", "Você vai mesmo dividir isso comigo?"])
	assert_eq(player.call("_dialogue_of", "Tika:"), [], "nome sozinho: a fala vem embaixo")
	assert_eq(player.call("_dialogue_of", "“Idiota.”"), ["Tika", "Idiota."])
	assert_eq(player.call("_dialogue_of", "Ele quebra o pão ao meio."), [], "direção de cena não aparece")


func test_tico_first_scene_plays_and_tika_is_gone_after() -> void:
	var level := await _arandu()
	var cena: Roteiro = level.get("cena_de_abertura")
	assert_not_null(cena, "Arandu abre com a 1ª cena do Tico")
	await level.call("play_cutscene", cena)
	var player := level.get("player") as Node3D
	var mark := level.get_node("CenaTico/TicoSentado") as Node3D
	assert_lt(player.global_position.distance_to(mark.global_position), 0.05, "o Tico fica onde estava sentado")
	assert_false((level.find_child("Tika", true, false) as Node3D).visible, "a Tika sumiu")
	assert_false((level.find_child("PaoDaTika", true, false) as Node3D).visible)
	assert_false((level.find_child("Pao", true, false) as Node3D).visible)
	assert_eq(String(player.get_node("Animator").get("_held")), "", "o Tico volta a andar normal")
	assert_eq(get_viewport().get_camera_3d(), (level.get_node("CameraRig") as ThirdPersonCamera).camera, "a câmera volta para o jogo")


func test_new_game_shows_prologue_once() -> void:
	Game.prologue_pending = true
	await _arandu()
	assert_false(Game.prologue_pending, "o prólogo só aparece na primeira fase do jogo novo")
	var prologue := load(Game.PROLOGUE) as Roteiro
	assert_string_contains(prologue.texto, "Novazul")
