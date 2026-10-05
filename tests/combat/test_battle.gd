extends GutTest
## A fase de verdade: a luta de Ethera, com a IA jogando pelos dois lados e sem animação, tem que terminar.

const LEVEL: PackedScene = preload("res://levels/ethera/ethera.tscn")

var _ended: bool = false
var _victory: bool = false


func _load_level() -> Node3D:
	var level := LEVEL.instantiate() as Node3D
	var combat := level.get_node("Combat") as CombatManager
	combat.auto_heroes = true
	combat.animate = false
	add_child_autofree(level)
	var party := level.get_node("Party") as PartyController
	await wait_until(func() -> bool: return party.enabled, 15.0)
	return level


func test_full_battle_ends_with_a_winner() -> void:
	Dice.rng.seed = 2026
	var level := await _load_level()
	var combat := level.get_node("Combat") as CombatManager
	combat.combat_ended.connect(func(victory: bool) -> void:
		_ended = true
		_victory = victory)
	level.start_encounter(level.get_node("EtheraRuins") as Encounter)
	await wait_until(func() -> bool: return _ended, 60.0)
	assert_true(_ended, "a batalha terminou")
	assert_eq(combat.units.size(), 12, "5 heróis + 7 inimigos")
	assert_gt(combat.round_number, 1, "durou mais de uma rodada")


func test_everyone_starts_on_a_free_cell() -> void:
	var level := await _load_level()
	var combat := level.get_node("Combat") as CombatManager
	level.start_encounter(level.get_node("EtheraRuins") as Encounter)
	await wait_until(func() -> bool: return combat.order.size() > 0, 10.0)
	var seen := {}
	for u: Unit in combat.units:
		assert_false(combat.grid.is_blocked(u.cell), "%s não começa em cima de ruína" % u.display_name)
		assert_false(seen.has(u.cell), "%s não divide casa" % u.display_name)
		seen[u.cell] = true
