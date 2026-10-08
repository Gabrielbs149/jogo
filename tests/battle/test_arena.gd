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


func test_first_strike_goes_first_with_an_extra_action_point() -> void:
	var arena := _arena(PackedStringArray([BEETLE, BEETLE, BEETLE]), true)
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	assert_eq(arena.order[0], arena.player, "você começa")
	assert_eq(arena.ap, arena.start_ap + 1)


func test_abilities_cost_action_points() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	arena.ap = 2
	assert_true(arena.can_afford(0), "ataque não custa")
	assert_true(arena.can_afford(1), "Bote das sombras: 2 PA")
	assert_false(arena.can_afford(2), "Espinhos: 3 PA")


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
	assert_eq((load("res://data/abilities/bote_das_sombras.tres") as Ability).damage_qte(), Ability.Golpe.SEQUENCIA)
	assert_eq((load("res://data/abilities/espinhos.tres") as Ability).damage_qte(), Ability.Golpe.MARTELAR)
	assert_eq((load("res://data/abilities/tiro_duplo.tres") as Ability).damage_qte(), Ability.Golpe.BARRA)
	assert_eq((load("res://data/abilities/chuva_de_flechas.tres") as Ability).damage_qte(), Ability.Golpe.SEGURAR)
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
	arena.ritmo = 3
	arena.call("_after_grade", "fraco")
	assert_eq(arena.ritmo, 0, "errar zera o ritmo")
	arena.call("_after_grade", "perfeito")
	assert_eq(arena.ritmo, 1)
