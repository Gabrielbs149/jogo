extends GutTest
## 1ª missão do Tico (D040): a fome e a padaria. O dono não dá pão de graça; dá para conversar, convencer,
## fazer o favor (levar a encomenda até a casa da viúva), intimidar ou roubar. Os testes de perícia rolam o d20.
## D058: o padeiro anda; falar só no balcão, roubar só com ele de costas (sem conversa).

const ARANDU := "res://levels/arandu/arandu.tscn"
# opções do padeiro na primeira conversa
const CONVERSAR := 0
const FAVOR := 1
const CONVENCER := 2
const INTIMIDAR := 3
const SAIR := 4

var _level: Level
var _quest: MissaoPadaria
var _dialogue: DialogueBox


func before_each() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.items.clear()
	Game.objective = ""
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child_autofree(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 20.0)
	_quest = _level.get_node("Missoes/MissaoPadaria") as MissaoPadaria
	_dialogue = (_level.get_node("HUD") as GameHUD).dialogue
	_dialogue.instant = true


## Faz o próximo d20 sair `value` (acha uma semente que dá esse número).
func _next_d20(value: int) -> void:
	for seed: int in 5000:
		Dice.rng.seed = seed
		if Dice.d20() == value:
			Dice.rng.seed = seed
			return
	fail_test("nenhuma semente dá %d" % value)


func _talk_baker(answers: Array[int]) -> void:
	_dialogue.auto_answers = answers
	await _quest._talk(_quest._padeiro)


func test_tico_wakes_up_hungry_and_the_baker_has_a_quest_mark() -> void:
	assert_true(Game.flag("padaria.comecou", false))
	assert_string_contains(Game.objective, "comer")
	assert_true(_quest.marca_padeiro.visible, "! em cima do padeiro")
	assert_false(_quest.marca_viuva.visible)


func test_the_favor_delivery_trip_ends_with_bread() -> void:
	await _talk_baker([CONVERSAR, FAVOR])
	assert_true(Game.has_item("encomenda"))
	assert_eq(_quest.estado(), "entrega")
	assert_string_contains(Game.objective, "viúva")
	assert_true(_quest.marca_viuva.visible, "seta em cima da viúva")
	assert_false(_quest.marca_padeiro.visible)
	_dialogue.auto_answers = []
	await _quest._talk(_quest._viuva)
	assert_false(Game.has_item("encomenda"))
	assert_eq(_quest.estado(), "entregue")
	assert_true(_quest.marca_padeiro.visible, "? em cima do padeiro na volta")
	await _talk_baker([])
	assert_eq(_quest.estado(), "feito")
	assert_eq(Game.flag("padaria.jeito"), "favor")
	assert_eq(Game.objective, "", "fome resolvida")
	assert_false(_quest.marca_padeiro.visible)


## D058: o padeiro vai trabalhar de costas (forno) e volta a atender no balcão.
func _baker_at(step: int) -> void:
	_quest.ia.call("_go_to", step, true)
	await wait_seconds(0.6)


func test_talk_only_at_the_counter_and_steal_only_with_his_back_turned() -> void:
	await _baker_at(0)  # balcão
	await wait_physics_frames(2)
	assert_true(_quest.ia.attending())
	assert_true(_quest.padeiro.enabled, "atendendo: dá para falar")
	assert_false(_quest.roubo.enabled, "de frente: não dá para roubar")
	await _baker_at(1)  # forno
	await wait_physics_frames(2)
	assert_true(_quest.ia.back_turned())
	assert_false(_quest.padeiro.enabled, "no forno: não dá para falar")
	assert_true(_quest.roubo.enabled, "de costas: dá para pegar um pão")


func test_the_baker_walks_between_his_stations() -> void:
	await _baker_at(0)
	var start := (_quest.padeiro.get_parent() as Node3D).global_position
	_quest.ia.set("_wait", 0.0)  # acabou o tempo no balcão: vai para o forno
	await wait_seconds(1.0)
	var now := (_quest.padeiro.get_parent() as Node3D).global_position
	assert_gt(start.distance_to(now), 0.5, "andou")


func test_stealing_rolls_stealth_and_a_good_roll_gets_the_bread() -> void:
	await _baker_at(1)
	_next_d20(10)  # 10 + 7 (Furtividade do Tico) = 17 contra CD 12
	await _quest._steal_at_counter(_level.player)
	assert_eq(_quest.estado(), "feito")
	assert_eq(_dialogue.history.size(), 0, "roubar não tem conversa")
	assert_eq(Game.flag("padaria.jeito"), "roubou")
	var check: Dictionary = Game.flag("padaria.ultimo_teste")
	assert_eq(check["pericia"], "Furtividade")
	assert_eq(check["total"], 17)


func test_failed_intimidation_gets_you_thrown_out() -> void:
	_next_d20(5)  # 5 + 0 contra CD 14
	await _talk_baker([INTIMIDAR])
	assert_eq(_quest.estado(), "expulso")
	assert_string_contains(Game.objective, "expuls")
	# expulso: falar só dá "FORA"; roubar fica mais difícil
	await _talk_baker([])
	assert_true(_dialogue.history[_dialogue.history.size() - 1].contains("FORA"))
	await _baker_at(1)
	_next_d20(2)
	await _quest._steal_at_counter(_level.player)
	assert_eq(_quest.estado(), "expulso", "2 + 7 = 9 não passa da CD 16")


func test_persuasion_can_only_be_tried_once() -> void:
	_next_d20(3)  # 3 + 2 contra CD 13: falha
	await _talk_baker([CONVENCER, 3])  # tenta convencer; o menu volta sem "Convencer" e a 4ª é ir embora
	assert_true(Game.flag("padaria.tentou_convencer", false))
	assert_eq(_quest.estado(), "")
	_dialogue.history.clear()
	await _talk_baker([3])  # sem "Convencer" o menu tem 4 opções; a última é ir embora
	assert_false(_dialogue.history.has("> Convencer  [Persuasão]"))
	assert_true(_dialogue.history.has("> Ir embora"))


func test_quest_marks_go_into_the_saved_game() -> void:
	var old := Game.save_path
	Game.save_path = "user://save_teste_missao.json"
	Game.set_flag("padaria.estado", "entrega")
	Game.add_item("encomenda")
	Game.set_objective("Levar a encomenda")
	assert_true(Game.save_game(ARANDU, Transform3D.IDENTITY))
	Game.flags.clear()
	Game.items.clear()
	Game.objective = ""
	assert_true(Game.continue_game(false))
	Game.returning = false
	assert_eq(Game.flag("padaria.estado"), "entrega")
	assert_true(Game.has_item("encomenda"))
	assert_eq(Game.objective, "Levar a encomenda")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game.save_path = old
