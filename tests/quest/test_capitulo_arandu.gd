extends GutTest
## O capítulo de Arandu (D086): depois do primeiro dia a Tika some; o Brás viu a carroça; a pista no celeiro; meses
## depois, a noite no celeiro (a luta tutorial); a ordem de carga; pegar as coisas e sair pelo portão.

const ARANDU := "res://levels/arandu/arandu.tscn"

var _level: Level
var _dialogue: DialogueBox
var _chapter: CapituloArandu


func after_each() -> void:
	Game.battle = {}
	Engine.time_scale = 1.0


func _open(flags: Dictionary = {}, items: Array[String] = []) -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge(flags)
	Game.items.clear()
	for item: String in items:
		Game.add_item(item)
	Game.objective = ""
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child_autofree(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 20.0)
	_dialogue = (_level.get_node("HUD") as GameHUD).dialogue
	_dialogue.instant = true
	_chapter = _level.get_node("Missoes/CapituloArandu") as CapituloArandu
	await wait_physics_frames(2)


func _said(text: String) -> bool:
	return "
".join(_dialogue.history).contains(text)


func _first_day_done() -> Dictionary:
	return {"prologo.etapa": "fim", "comida.entregue": true, "prologo.fita_achada": true, "feira.estado": "resolvido",
		"feira.jeito": "ajudou"}


func test_after_the_first_day_tika_is_gone() -> void:
	await _open(_first_day_done())
	await wait_until(func() -> bool: return CapituloArandu.etapa() == "sumiu" and not _level.em_cena, 30.0)
	assert_eq(CapituloArandu.etapa(), "sumiu")
	assert_false(_chapter.tika.visible, "o canto dela está vazio")
	assert_false(_chapter.falar_tika.enabled)
	assert_string_contains(Game.objective, "Procurar a Tika")
	assert_eq(_chapter.portao.action, Interactable.Action.QUEST, "ainda não dá para ir embora")
	assert_true(_level.controller.enabled, "depois da manhã vazia dá para andar")


func test_bras_saw_the_cart_and_pipo_saw_her() -> void:
	await _open(_first_day_done().merged({"capitulo.etapa": "sumiu"}))
	var bras := _level.get_node("Missoes/MendigoBras") as ConversaMendigo
	await bras._talk(bras._conversa, bras.falar.get_parent() as Node3D)
	assert_true(Game.flag("capitulo.bras", false), "o Brás contou da carroça")
	assert_true(_said("carroça coberta"))
	assert_string_contains(Game.objective, "celeiro")
	var feira := _level.get_node("Missoes/BrigaFeira") as BrigaFeira
	await feira._talk(feira._garoto_depois, feira.garoto)
	assert_true(_said("indo pro lado do celeiro"),
		"o Pipo, que o Tico ajudou, viu ela indo pro celeiro")


func test_the_clue_then_months_later_bras_tells_about_the_forge() -> void:
	await _open(_first_day_done().merged({"capitulo.etapa": "sumiu", "capitulo.bras": true}))
	assert_true(_chapter.pista.visible)
	assert_true(_chapter.pista_laco.visible, "ela tinha a fita: a fita está no chão do celeiro")
	await _chapter._talk(_chapter._pista, null)
	await wait_until(func() -> bool: return CapituloArandu.etapa() == "celeiro" and not _level.em_cena and not _chapter._busy, 30.0)
	assert_true(Game.has_item("fita"), "o Tico guardou a fita")
	assert_true(_chapter.capangas[0].visible, "de noite, os capangas no celeiro")
	assert_true(_chapter.levado.visible)
	assert_lt(_chapter.bras.global_position.distance_to(_chapter.bras_esquina.global_position), 0.05, "o Brás volta pra esquina")
	assert_string_contains(Game.objective, "celeiro")


func test_near_the_barn_the_tutorial_fight_starts() -> void:
	await _open(_first_day_done().merged({"capitulo.etapa": "celeiro"}))
	_chapter._indo_pra_luta = true  # o teste chama a conversa direto (sem trocar de cena)
	await _chapter._talk(_chapter._confronto, _chapter.capangas[0])
	assert_true(_said("nome da lenha"))
	var fight: Dictionary = CapituloArandu.LUTA
	assert_true(bool(fight["tutorial"]), "é a luta tutorial")
	assert_true(bool(fight["nao_letal"]), "perder não é morrer: tenta de novo")
	assert_eq((fight["enemies"] as Array).size(), 2)
	for path: String in fight["enemies"]:
		var enemy := (load(path) as PackedScene).instantiate() as Combatant
		assert_eq(enemy.team, 1)
		assert_gt(enemy.abilities.size(), 0, path)
		enemy.free()


func test_winning_drops_the_cargo_order_and_losing_lets_you_retry() -> void:
	await _open(_first_day_done().merged({"capitulo.etapa": "celeiro", "luta.capangas_forja": "perdeu"}))
	await _chapter._depois_da_luta()
	assert_eq(CapituloArandu.etapa(), "celeiro", "perdeu: os capangas continuam lá")
	assert_gt(_level.player.global_position.distance_to(_chapter.carroca.global_position), _chapter.raio_celeiro,
		"o Tico fica longe o bastante para não começar outra luta na hora")
	Game.set_flag("luta.capangas_forja", "venceu")
	await _chapter._depois_da_luta()
	assert_eq(CapituloArandu.etapa(), "lutou")
	assert_true(Game.has_item("ordem_de_carga"))
	assert_true(_said("FORJA DE CINDRALIGHT"))
	assert_false(_chapter.capangas[0].visible, "eles fugiram")
	assert_true(_chapter.mochila.visible, "agora, as coisas no barraco")


func test_take_your_things_and_leave_through_the_gate() -> void:
	await _open(_first_day_done().merged({"capitulo.etapa": "lutou"}), ["fita"])
	_chapter._no_portao()
	assert_eq(CapituloArandu.etapa(), "lutou", "antes das coisas, o portão não deixa")
	await _chapter._pegar_coisas()
	assert_eq(CapituloArandu.etapa(), "pronto")
	assert_string_contains(Game.objective, "portão")
	assert_true(_level.controller.enabled, "depois de pegar as coisas dá para andar")
	assert_eq(_chapter.portao.action, Interactable.Action.QUEST)
