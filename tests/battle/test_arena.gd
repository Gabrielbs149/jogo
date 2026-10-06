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
