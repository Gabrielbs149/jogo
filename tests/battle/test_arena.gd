extends GutTest
## Arena por turnos (D022): você sozinho contra o grupo, QTE no golpe, esquivar/aparar na defesa.

const ARENA := "res://levels/arenas/ethera_arena.tscn"
const BEETLE := "res://actors/enemies/escaravelho_de_cinza.tscn"


func after_each() -> void:
	Engine.time_scale = 1.0
	Game.battle = {}
	CombatRules.turn_mode = false


func _arena(enemies: PackedStringArray, first_strike: bool = false) -> BattleArena:
	Game.chosen = "tico"
	Game.hero_hp = -1
	Game.battle = {"id": "teste", "enemies": enemies, "first_strike": first_strike}
	var arena := (load(ARENA) as PackedScene).instantiate() as BattleArena
	arena.auto_play = true
	add_child_autofree(arena)
	return arena


func test_a_good_player_beats_two_beetles() -> void:
	Dice.rng.seed = 7
	seed(7)
	Engine.time_scale = 6.0
	var arena := _arena(PackedStringArray([BEETLE, BEETLE]))
	arena.auto_perfect = 0.8
	arena.auto_dodge = 0.5
	arena.auto_parry = 0.3
	var result := []
	arena.finished.connect(func(victory: bool) -> void: result.append(victory))
	await wait_until(func() -> bool: return not result.is_empty(), 40.0)
	assert_eq(result, [true], "venceu")
	assert_eq(arena.alive_enemies().size(), 0)


func test_first_strike_goes_first() -> void:
	var arena := _arena(PackedStringArray([BEETLE, BEETLE, BEETLE]), true)
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	assert_eq(arena.order[0], arena.player, "você começa")


## D052: o ataque é sempre livre; a habilidade usada fica alguns turnos recarregando.
func test_abilities_recharge_after_use() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	arena.recharge.clear()
	assert_true(arena.can_afford(0), "ataque sempre livre")
	assert_eq(arena.player.abilities[0].recharge_turns(), 0)
	assert_eq(arena.player.abilities[2].recharge_turns(), 3, "Espinhos: 3 turnos")
	arena.recharge[2] = 2
	assert_false(arena.can_afford(2), "recarregando")
	assert_true(arena.can_afford(1))


## D048: o d20 vem com as faces para aparecer na tela, e o golpe com tempo multiplica o dano já rolado.
func test_attack_roll_carries_the_die_to_show() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	var results := CombatRules.resolve(arena.player, arena.player.abilities[0], arena.enemies[0], arena.enemies[0].global_position,
		CombatRules.everyone(get_tree()), 1)
	var die: Dictionary = results[0]["die"]
	assert_eq((die["rolls"] as Array).size(), 2, "com vantagem rola dois d20")
	assert_true(int(die["kept"]) == maxi(int(die["rolls"][0]), int(die["rolls"][1])), "fica com o maior")
	assert_eq(int(die["total"]), int(die["kept"]) + int(die["mod"]))
	assert_true(String(die["verdict"]) in ["ACERTOU", "CRÍTICO!", "ERROU", "FALHA"])


func test_damage_timing_scales_the_damage() -> void:
	var results: Array[Dictionary] = [{"amount": 10, "text": "x"}, {"amount": 0, "text": "errou"}, {"amount": 1, "text": "y"}]
	CombatRules.scale_damage(results, 1.5, "perfeito")
	assert_eq(int(results[0]["amount"]), 15)
	assert_eq(int(results[1]["amount"]), 0, "errou continua sem dano")
	CombatRules.scale_damage(results, 0.3)
	assert_eq(int(results[2]["amount"]), 1, "acertou leva pelo menos 1")


func test_each_ability_picks_its_challenge() -> void:
	assert_eq((load("res://data/abilities/adaga.tres") as Ability).damage_qte(), Ability.Golpe.ANEL)
	assert_eq((load("res://data/abilities/bote_das_sombras.tres") as Ability).damage_qte(), Ability.Golpe.RAJADA, "investida: anéis seguidos")
	assert_eq((load("res://data/abilities/espinhos.tres") as Ability).damage_qte(), Ability.Golpe.ANEL)
	assert_eq((load("res://data/abilities/tiro_duplo.tres") as Ability).damage_qte(), Ability.Golpe.RAJADA, "um anel por flecha")
	assert_eq((load("res://data/abilities/camuflagem.tres") as Ability).damage_qte(), Ability.Golpe.NENHUM)
	assert_eq((load("res://data/abilities/raio_vigia.tres") as Ability).defense_qte(), Ability.Defesa.DIRECAO)
	assert_eq((load("res://data/abilities/pancada.tres") as Ability).defense_qte(), Ability.Defesa.COMBO)
	assert_eq((load("res://data/abilities/onda_de_cinza.tres") as Ability).defense_qte(), Ability.Defesa.FINTA)


func test_posture_breaks_and_the_enemy_loses_a_turn() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	var beetle := arena.enemies[0]
	arena.call("_add_posture", beetle, beetle.posture_limit())
	assert_true(beetle.quebrado, "postura cheia quebra")


## D050: ações do meio da luta. Defender dá CA; a poção cura e acaba; do chefe não dá para fugir.
func test_extra_actions() -> void:
	# sem o piloto automático: a luta fica parada esperando você escolher (primeiro golpe = você começa)
	Game.chosen = "tico"
	Game.hero_hp = -1
	Game.battle = {"id": "teste", "enemies": PackedStringArray([BEETLE]), "first_strike": true}
	var arena := (load(ARENA) as PackedScene).instantiate() as BattleArena
	add_child_autofree(arena)
	await wait_until(func() -> bool: return arena.get_node("BattleHUD").get("_choosing"), 20.0)
	var ac := arena.player.current_ac()
	await arena.call("_extra_action", BattleArena.DEFEND)
	assert_eq(arena.player.current_ac(), ac + 2, "defendendo: +2 CA")
	arena.player.hp = 5
	assert_true(arena.can_use_extra(BattleArena.POTION))
	await arena.call("_extra_action", BattleArena.POTION)
	assert_gt(arena.player.hp, 5, "a poção cura")
	assert_eq(arena.potions, 1)
	arena.potions = 0
	assert_false(arena.can_use_extra(BattleArena.POTION), "sem poção")
	assert_true(arena.can_use_extra(BattleArena.FLEE), "do escaravelho dá para fugir")
	await arena.call("_extra_action", BattleArena.ANALYZE)
	assert_true(arena.target.has_flag("expose"), "analisar deixa o alvo exposto")


func test_cannot_flee_from_the_boss() -> void:
	var arena := _arena(PackedStringArray(["res://actors/enemies/ultimo_guardiao.tscn"]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	assert_false(arena.can_use_extra(BattleArena.FLEE))


## D051: o Tico luta com as adagas psíquicas, uma em cada mão.
func test_tico_fights_with_psychic_daggers() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	var daggers := arena.player.find_children("*", "AdagaPsiquica", true, false)
	assert_eq(daggers.size(), 2, "uma em cada mão")
	var dagger := daggers[0] as AdagaPsiquica
	assert_gt(dagger.blade_length, 0.3, "a lâmina tem tamanho de adaga")
	assert_true(dagger.has_node("Lamina"), "a lâmina foi montada")
