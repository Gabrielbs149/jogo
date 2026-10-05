extends GutTest
## A arena de verdade, com a IA jogando pelos dois lados e sem animação, tem que terminar com um vencedor.

const ARENA: PackedScene = preload("res://levels/dunes_arena/dunes_arena.tscn")

var _ended: bool = false
var _victory: bool = false


func test_full_battle_ends_with_a_winner() -> void:
	Dice.rng.seed = 2026
	var arena := ARENA.instantiate()
	var combat := arena.get_node("Combat") as CombatManager
	combat.auto_heroes = true
	combat.animate = false
	combat.combat_ended.connect(func(victory: bool) -> void:
		_ended = true
		_victory = victory)
	add_child_autofree(arena)
	await wait_until(func() -> bool: return _ended, 60.0)
	assert_true(_ended, "a batalha terminou")
	assert_gt(combat.units.size(), 10, "achou heróis e inimigos")
	assert_gt(combat.round_number, 1, "durou mais de uma rodada")
	gut.p("Resultado: %s em %d rodadas" % ["heróis venceram" if _victory else "inimigos venceram", combat.round_number])


func test_everyone_stands_on_a_free_cell() -> void:
	var arena := ARENA.instantiate()
	var combat := arena.get_node("Combat") as CombatManager
	combat.auto_heroes = true
	combat.animate = false
	add_child_autofree(arena)
	await wait_until(func() -> bool: return combat.order.size() > 0, 10.0)
	var seen := {}
	for u: Unit in combat.units:
		assert_false(combat.grid.is_blocked(u.cell), "%s não começa em cima de ruína" % u.display_name)
		assert_false(seen.has(u.cell), "%s não divide casa" % u.display_name)
		seen[u.cell] = true
