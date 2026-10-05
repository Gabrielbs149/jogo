extends GutTest
## Regras: chance de acerto, crítico/erro, cura, reforço e área só em inimigos.

var _grid: CombatGrid
var _hero: Unit
var _enemy: Unit
var _ally: Unit


func before_each() -> void:
	Dice.rng.seed = 7
	var world := Node3D.new()
	add_child_autofree(world)
	_grid = CombatGrid.new()
	_grid.size = Vector2i(10, 10)
	_grid.cell_size = 1.0
	world.add_child(_grid)
	_grid.build()
	_hero = _unit(world, "Herói", Unit.Team.HEROES, Vector2i(1, 1))
	_ally = _unit(world, "Aliado", Unit.Team.HEROES, Vector2i(2, 1))
	_enemy = _unit(world, "Inimigo", Unit.Team.ENEMIES, Vector2i(3, 1))


func _unit(world: Node3D, unit_name: String, team: Unit.Team, c: Vector2i) -> Unit:
	var u := Unit.new()
	u.display_name = unit_name
	u.team = team
	u.max_hp = 20
	u.armor_class = 12
	u.attack_bonus = 4
	world.add_child(u)
	u.cell = c
	return u


func _units() -> Array[Unit]:
	return [_hero, _ally, _enemy]


func test_hit_chance() -> void:
	# precisa de 8+ no d20 (12 - 4) = 13 em 20
	assert_almost_eq(CombatRules.hit_chance(_hero, _enemy), 0.65, 0.001)
	_enemy.armor_class = 40
	assert_almost_eq(CombatRules.hit_chance(_hero, _enemy), 0.05, 0.001, "sempre sobra o 20 natural")


func test_buff_changes_ac() -> void:
	_enemy.add_status("Escudo", 3, 0, 1)
	assert_eq(_enemy.current_ac(), 15)
	_enemy.start_turn()
	assert_eq(_enemy.current_ac(), 12, "acaba no próximo turno dele")


func test_area_hits_only_enemies() -> void:
	var blast := Ability.new()
	blast.kind = Ability.Kind.ATTACK
	blast.target = Ability.Target.AREA
	blast.radius = 1
	blast.reach = 6
	blast.needs_roll = false
	var hit := CombatRules.affected(_hero, blast, Vector2i(2, 1), _grid, _units())
	assert_eq(hit.size(), 1)
	assert_eq(hit[0], _enemy)


func test_heal_never_above_max() -> void:
	_ally.hp = 18
	_ally.heal(10)
	assert_eq(_ally.hp, 20)


func test_attack_rolls_are_reproducible() -> void:
	var stab := Ability.new()
	stab.reach = 5
	Dice.rng.seed = 123
	var first := CombatRules.resolve(_hero, stab, _enemy.cell, _grid, _units())
	Dice.rng.seed = 123
	var second := CombatRules.resolve(_hero, stab, _enemy.cell, _grid, _units())
	assert_eq(first[0]["amount"], second[0]["amount"])
	assert_eq(first[0]["kind"], second[0]["kind"])
