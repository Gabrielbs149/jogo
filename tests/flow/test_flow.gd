extends GutTest
## Começo do jogo: você joga só com o herói escolhido; os outros esperam pela fase e entram no grupo
## quando você chama.

const LEVEL := "res://levels/ethera/ethera.tscn"


func _load_level(hero_id: String) -> Node3D:
	Game.chosen = hero_id
	Game.party.clear()
	var level := (load(LEVEL) as PackedScene).instantiate() as Node3D
	level.set("skip_intro", true)
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.get("ready_to_play"), 15.0)
	return level


func test_you_start_alone_with_the_chosen_hero() -> void:
	var level := await _load_level("naumfode")
	var player := level.get("player") as Combatant
	assert_eq(player.hero_id, "naumfode")
	assert_not_null(player.get_node_or_null("PlayerController"), "você controla o escolhido")
	assert_eq((level.get("companions") as Array).size(), 0, "ninguém no grupo ainda")
	var waiting: Array = level.get("waiting")
	assert_eq(waiting.size(), 4, "os outros quatro esperam pela fase")
	var ids: Array[String] = []
	for c: Combatant in waiting:
		ids.append(c.hero_id)
		assert_true(c.recruitable)
	assert_false(ids.has("naumfode"), "o escolhido não aparece duas vezes")
	assert_true(ids.has("tico"))


func test_calling_a_hero_makes_them_a_companion() -> void:
	var level := await _load_level("chumasso")
	var tico: Combatant = null
	for c: Combatant in level.get("waiting"):
		if c.hero_id == "tico":
			tico = c
	level.call("join", tico)
	assert_false(tico.recruitable)
	assert_true((level.get("companions") as Array).has(tico))
	var brain := tico.get_node("AIBrain") as AIBrain
	assert_eq(brain.mode, AIBrain.Mode.COMPANION)
	assert_eq(brain.leader, level.get("player"))
	assert_eq(Game.party, ["tico"] as Array[String])


func test_each_hero_has_a_start_and_tico_starts_in_arandu() -> void:
	assert_eq(Game.start_level("tico"), Game.ARANDU)
	for id: String in Game.HEROES:
		assert_true(ResourceLoader.exists(Game.start_level(id)), "%s tem fase de início" % id)


func test_arandu_is_a_calm_start_with_a_way_out() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	var level := (load(Game.ARANDU) as PackedScene).instantiate() as Node3D
	level.set("skip_intro", true)
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.get("ready_to_play"), 15.0)
	assert_eq((level.get("player") as Combatant).hero_id, "tico")
	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 0, "Arandu não tem inimigos")
	var gate := level.get_node("Gate") as Interactable
	assert_eq(gate.action, Interactable.Action.TRAVEL)
	assert_true(ResourceLoader.exists(gate.target_scene), "o portão leva a uma fase que existe")
	var people := 0
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if (node as Interactable).prompt_text.begins_with("Falar com"):
			people += 1
	assert_gte(people, 3, "tem gente para conversar")
