extends GutTest
## O primeiro dia do Tico com a Tika (D059): acordar, a conversa na boca do beco, a rua, os jeitos de conseguir
## comida (bico do carregador, padaria), a briga da feira, o Seu Brás e o jantar no barraco.

const ARANDU := "res://levels/arandu/arandu.tscn"

var _level: Level
var _dialogue: DialogueBox
var _prologue: PrologoTico


func _open(flags: Dictionary = {}) -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge(flags)
	Game.items.clear()
	Game.objective = ""
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child_autofree(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 20.0)
	_dialogue = (_level.get_node("HUD") as GameHUD).dialogue
	_dialogue.instant = true
	_prologue = _level.get_node("Missoes/PrologoTico") as PrologoTico
	await wait_physics_frames(2)


## Faz o próximo d20 sair `value` (acha uma semente que dá esse número).
func _next_d20(value: int) -> void:
	for seed: int in 5000:
		Dice.rng.seed = seed
		if Dice.d20() == value:
			Dice.rng.seed = seed
			return
	fail_test("nenhuma semente dá %d" % value)


## As respostas automáticas da conversa (a lista precisa ser Array[int]).
func _answer(picks: Array[int]) -> void:
	_dialogue.auto_answers = picks


func _put_hero(at: Vector3) -> void:
	_level.player.global_position = at
	_level.player.reset_physics_interpolation()
	await wait_physics_frames(3)
	await wait_frames(2)  # com a cidade cheia, um quadro de tela roda vários passos de física


func _after_the_alley() -> Dictionary:
	return {"prologo.etapa": "saiu", "comida.comecou": true, "prologo.tika_resposta": "banquete"}


# --- A e B ----------------------------------------------------------------------------------------

func test_a_new_game_wakes_tico_up_and_tika_waits_at_the_alley_exit() -> void:
	await _open()
	assert_eq(_prologue.etapa(), "acordou")
	assert_true(_dialogue.history.has("Tika: Tico. Tico! Acorda."), "o diálogo de abertura aconteceu")
	assert_string_contains(Game.objective, "Tika")
	assert_true(_level.controller.enabled, "depois de acordar, o controle volta")
	assert_eq(String(_level.player.get_node("Animator").get("_held")), "", "o Tico não fica preso deitado")
	await wait_until(func() -> bool: return not _prologue.tika.is_walking() 			and _prologue.tika.global_position.distance_to(_prologue.tika_saida.global_position) < 0.1, 10.0)
	assert_lt(_prologue.tika.global_position.distance_to(_prologue.tika_saida.global_position), 0.1, "ela foi até a boca do beco")
	assert_true(_prologue.marca_tika.visible)


func test_tika_talks_at_the_exit_and_the_answer_is_remembered() -> void:
	await _open({"prologo.etapa": "acordou"})
	# chegando perto ela puxa conversa sozinha (o herói nasce perto da boca do beco); aqui a conversa é chamada
	# de novo com a resposta escolhida
	await wait_until(func() -> bool: return _prologue.etapa() == "conversou", 5.0)
	_answer([2])
	_dialogue.history.clear()
	await _prologue._talk(_prologue._conversa_saida, _prologue.tika)
	assert_eq(Game.flag("prologo.tika_resposta"), "rato")
	assert_true(_dialogue.history.has("Tika: Ontem a gente comeu MEIO rato cada. E a minha metade era o bumbum."),
		"a resposta muda a fala seguinte")
	assert_false(Game.flag("comida.comecou", false), "o objetivo da comida vem quando ele sai do beco")


func test_leaving_the_alley_shows_the_street_and_starts_the_food_quest() -> void:
	await _open({"prologo.etapa": "conversou"})
	await _put_hero(Vector3(-3.0, 0.1, -55.0))
	await wait_until(func() -> bool: return _prologue.etapa() == "saiu", 3.0)
	await wait_frames(2)
	assert_true(Game.flag("comida.comecou", false))
	assert_eq(Game.objective, "Conseguir comida para os dois.")
	assert_eq(Game.objective_title, "Fome")
	assert_true(Game.flag("padaria.comecou", false), "a padaria vira um dos caminhos")


func test_examining_turns_tico_and_shows_a_thought() -> void:
	await _open(_after_the_alley())
	var fire := _level.get_node("TicoCorner/OlharFogueira") as Interactable
	fire.interact(_level.player)
	await wait_physics_frames(2)
	var thought := _level.get_node("HUD").get("_thought") as Label
	assert_true(thought.visible, "pensa em legenda, sem caixa")
	assert_string_contains(thought.text, "rabo")
	assert_false((_level.get_node("HUD").get("_prompt_box") as Control).visible, "o F Examinar sai enquanto ele pensa")


func test_the_combat_hud_stays_out_of_the_way_in_town() -> void:
	await _open(_after_the_alley())
	await wait_seconds(1.2)
	var panel := _level.get_node("HUD/Root/PlayerPanel") as Control
	assert_false(panel.visible, "sem inimigo por perto, sem vida nem golpes na tela")


# --- C: jeitos de conseguir comida ----------------------------------------------------------------

func test_the_carrier_job_pays_with_food_for_two() -> void:
	await _open(_after_the_alley())
	var job := _level.get_node("Missoes/BicoCaixas") as BicoCaixas
	_answer([1])
	await job._talk(job._conversa)
	assert_eq(job.estado(), "aceito")
	for k: int in 3:
		job.pegar.interact(_level.player)
		assert_not_null(job._carrying, "o caixote vai na cabeça")
		job.largar.interact(_level.player)
		await wait_physics_frames(1)
	assert_eq(job.caixas(), 3)
	assert_eq(job.estado(), "carregou")
	assert_true(job.na_pilha[2].visible, "a pilha na porta do galpão")
	await job._talk(job._conversa)
	assert_eq(job.estado(), "pago")
	assert_true(Game.has_item("comida"))
	assert_eq(Game.flag("comida.de"), "bico")
	assert_string_contains(Game.objective, "Tika")


func test_bras_tells_about_the_job() -> void:
	await _open(_after_the_alley())
	var bras := _level.get_node("Missoes/MendigoBras") as ConversaMendigo
	_answer([0, 2])
	await bras._talk(bras._conversa)
	assert_true(Game.flag("bico.sabe", false))
	# o carregador lembra que foi o Brás que mandou
	var job := _level.get_node("Missoes/BicoCaixas") as BicoCaixas
	_answer([2])
	await job._talk(job._conversa)
	assert_true(_dialogue.history.has("Tico: O Seu Brás disse que você tava precisando de braço."))


# --- D: a briga na feira --------------------------------------------------------------------------

func test_the_street_fight_starts_when_you_come_close_and_you_can_walk_away() -> void:
	await _open(_after_the_alley())
	var fight := _level.get_node("Missoes/BrigaFeira") as BrigaFeira
	assert_eq(fight.estado(), "")
	await _put_hero(fight.vendedor.global_position + Vector3(-6.0, 0.1, 0.0))
	await wait_until(func() -> bool: return fight.estado() == "brigando", 3.0)
	assert_eq(fight.estado(), "brigando")
	await wait_until(func() -> bool: return fight.intervir.enabled, 3.0)
	assert_true(fight.intervir.enabled)
	await _put_hero(fight.vendedor.global_position + Vector3(-40.0, 0.1, 0.0))
	await wait_until(func() -> bool: return fight.falar_garoto.enabled, 3.0)
	assert_eq(Game.flag("feira.jeito"), "ignorou", "seguiu andando: a história continua igual")
	assert_true(fight.falar_garoto.enabled)


func test_defending_the_boy_after_reading_him_makes_him_remember_tico() -> void:
	await _open(_after_the_alley())
	var fight := _level.get_node("Missoes/BrigaFeira") as BrigaFeira
	Game.set_flag("feira.estado", "brigando")
	_next_d20(15)  # Intuição 15 + 3 contra 12; depois Persuasão com a próxima rolagem
	_answer([0, 1])  # olhar o garoto; depois "Defender" (segunda opção quando já olhou)
	await fight._talk(fight._intervir)
	assert_true(Game.flag("feira.sabe", false), "a Intuição mostra o motivo do garoto")
	assert_eq(Game.flag("feira.jeito"), "ajudou")
	_dialogue.history.clear()
	await fight._talk(fight._garoto_depois)
	assert_true(_dialogue.history.has("Garoto: Ei, moço! Valeu por aquela. Eu sou o Pipo."))


func test_siding_with_the_seller_gets_an_apple_and_a_grudge() -> void:
	await _open(_after_the_alley())
	var fight := _level.get_node("Missoes/BrigaFeira") as BrigaFeira
	Game.set_flag("feira.estado", "brigando")
	_answer([3])  # ficar do lado do vendedor
	await fight._talk(fight._intervir)
	assert_eq(Game.flag("feira.jeito"), "entregou")
	assert_true(Game.flag("feira.maca", false))
	_dialogue.history.clear()
	await fight._talk(fight._garoto_depois)
	assert_eq(_dialogue.history[0], "Garoto: Dedo-duro.")


# --- E: o fim do dia -----------------------------------------------------------------------------

func test_the_dinner_scene_changes_with_what_you_did() -> void:
	await _open(_after_the_alley())
	Game.add_item("comida")
	Game.set_flag("comida.de", "bico")
	Game.set_flag("comida.o_que", "um pão de milho e uma linguiça")
	Game.set_flag("feira.jeito", "ajudou")
	Game.add_item("fita")
	var text := _prologue.end_of_day_script()
	assert_string_contains(text, "Pronto. Um pão de milho e uma linguiça.")
	assert_string_contains(text, "Linguiça?!")
	assert_string_contains(text, "Então esse é o banquete.", "a resposta da manhã volta no jantar")
	assert_string_contains(text, "protetor dos famintos")
	assert_string_contains(text, "A minha fita!")
	assert_false(text.contains("{comida}") or text.contains("{extras}"))
	assert_string_contains(text, "muralha", "a Tika fala da gente nova perto da muralha")


func test_bringing_food_back_ends_the_day_and_tika_stays() -> void:
	await _open(_after_the_alley())
	Game.add_item("comida")
	Game.set_flag("comida.de", "padaria")
	Game.set_flag("padaria.jeito", "roubou")
	Game.set_flag("comida.o_que", "um pão escondido debaixo do capuz")
	_level.ciclo.jump_to(19.0)  # o jantar é de noite (D060)
	await wait_until(func() -> bool: return _prologue.marca_tika.visible, 3.0)
	assert_true(_prologue.marca_tika.visible, "seta em cima da Tika: é com ela")
	_prologue.falar_tika.interact(_level.player)
	await wait_until(func() -> bool: return not _prologue._busy, 20.0)
	assert_eq(_prologue.etapa(), "fim")
	assert_false(Game.has_item("comida"))
	assert_eq(Game.objective, "")
	assert_true(_prologue.tika.visible, "a Tika não some no primeiro dia")


## D060: voltando com comida antes de escurecer, a Tika guarda para o jantar; dá para esperar o sol baixar com ela.
func test_coming_back_early_waits_for_the_evening() -> void:
	await _open(_after_the_alley())
	Game.add_item("comida")
	Game.set_flag("comida.de", "bico")
	Game.set_flag("comida.o_que", "um pão de milho e uma linguiça")
	_level.ciclo.jump_to(11.0)
	_answer([1])  # dar mais uma volta
	await _prologue._talk(_prologue._too_early, _prologue.tika)
	assert_eq(_prologue.etapa(), "saiu", "ainda não jantaram")
	assert_true(Game.has_item("comida"), "ela guardou")
	_answer([0])  # esperar com ela
	await _prologue._talk(_prologue._too_early, _prologue.tika)
	await wait_until(func() -> bool: return _prologue.etapa() == "fim", 15.0)
	assert_gt(Game.hora, 18.0, "o sol baixou")


func test_continuing_a_save_in_the_middle_puts_tika_in_the_right_place() -> void:
	await _open({"prologo.etapa": "acordou"})
	assert_lt(_prologue.tika.global_position.distance_to(_prologue.tika_saida.global_position), 0.1)
	assert_false(_dialogue.history.has("Tika: Tico. Tico! Acorda."), "não acorda de novo")
