extends GutTest
## Regras do D&D 5.5 em tempo real: vantagem, crítico, 1 natural, salvamento com metade,
## área só em inimigos, ataque furtivo, cura que levanta quem caiu, recarga.

var _world: Node3D
var _hero: Combatant
var _ally: Combatant
var _enemy: Combatant


func before_each() -> void:
	Dice.rng.seed = 7
	_world = Node3D.new()
	add_child_autofree(_world)
	_hero = _make("Herói", Combatant.Team.HEROES, Vector3(0, 0, 0))
	_ally = _make("Aliado", Combatant.Team.HEROES, Vector3(10, 0, 0))
	_enemy = _make("Inimigo", Combatant.Team.ENEMIES, Vector3(0, 0, -2))


func _make(unit_name: String, team: Combatant.Team, at: Vector3) -> Combatant:
	var c := Combatant.new()
	c.display_name = unit_name
	c.team = team
	c.max_hp = 40
	c.armor_class = 12
	c.attack_bonus = 4
	c.spell_dc = 13
	_world.add_child(c)
	c.global_position = at
	c.set_physics_process(false)
	return c


func _ability(roll: Ability.Roll, count: int, sides: int, bonus: int = 0) -> Ability:
	var a := Ability.new()
	a.roll = roll
	a.dice_count = count
	a.dice_sides = sides
	a.bonus = bonus
	a.range_m = 30.0
	return a


func _all() -> Array[Combatant]:
	return [_hero, _ally, _enemy]


## Semente em que o primeiro d20 dá o valor pedido.
func _seed_for_d20(value: int) -> int:
	for s: int in 5000:
		Dice.rng.seed = s
		if Dice.d20() == value:
			return s
	return -1


func test_advantage_keeps_the_higher_die() -> void:
	Dice.rng.seed = 11
	var a := Dice.d20()
	var b := Dice.d20()
	Dice.rng.seed = 11
	assert_eq(int(CombatRules.d20(1)["value"]), maxi(a, b))
	Dice.rng.seed = 11
	assert_eq(int(CombatRules.d20(-1)["value"]), mini(a, b))


func test_natural_20_is_a_crit_with_double_dice() -> void:
	var ability := _ability(Ability.Roll.ATTACK, 2, 1, 0)
	Dice.rng.seed = _seed_for_d20(20)
	var r := CombatRules.resolve(_hero, ability, _enemy, _enemy.global_position, _all())
	assert_eq(r[0]["kind"], "crit")
	assert_eq(r[0]["amount"], 4, "2d1 vira 4d1")


func test_natural_1_always_misses() -> void:
	_hero.attack_bonus = 50
	Dice.rng.seed = _seed_for_d20(1)
	var r := CombatRules.resolve(_hero, _ability(Ability.Roll.ATTACK, 1, 6), _enemy, _enemy.global_position, _all())
	assert_eq(r[0]["kind"], "miss")


func test_passing_a_save_takes_half() -> void:
	var ability := _ability(Ability.Roll.SAVE, 4, 1, 0)
	ability.shape = Ability.Shape.AREA
	ability.radius_m = 2.0
	_enemy.dex_save = 40
	var r := CombatRules.resolve(_hero, ability, null, _enemy.global_position, _all())
	assert_eq(r.size(), 1)
	assert_eq(r[0]["kind"], "save")
	assert_eq(r[0]["amount"], 2, "4 de dano, metade = 2")


func test_area_attack_only_hits_enemies() -> void:
	_ally.global_position = _enemy.global_position + Vector3(0.5, 0, 0)
	var ability := _ability(Ability.Roll.AUTO, 1, 4)
	ability.shape = Ability.Shape.AREA
	ability.radius_m = 3.0
	var hit := CombatRules.affected(_hero, ability, null, _enemy.global_position, _all())
	assert_eq(hit, [_enemy] as Array[Combatant])


func test_sneak_attack_needs_an_ally_next_to_the_target() -> void:
	var ability := _ability(Ability.Roll.AUTO, 1, 1)
	ability.sneak_dice = 2
	var alone := CombatRules.resolve(_hero, ability, _enemy, _enemy.global_position, _all())
	assert_eq(alone[0]["amount"], 1, "sem aliado perto e sem vantagem: sem furtivo")
	_ally.global_position = _enemy.global_position + Vector3(1, 0, 0)
	var flanked := CombatRules.resolve(_hero, ability, _enemy, _enemy.global_position, _all())
	assert_gt(int(flanked[0]["amount"]), 2, "aliado colado no alvo: +2d6")
	var again := CombatRules.resolve(_hero, ability, _enemy, _enemy.global_position, _all())
	assert_eq(again[0]["amount"], 1, "furtivo só de novo depois do intervalo")


func test_hidden_attacker_has_advantage_and_dodging_target_gives_disadvantage() -> void:
	var ability := _ability(Ability.Roll.ATTACK, 1, 6)
	_hero.add_status({"title": "Camuflado", "time": 5.0, "invisible": true})
	assert_eq(CombatRules.attack_advantage(_hero, ability, _enemy), 1)
	_enemy.add_status({"title": "Esquiva", "time": 5.0, "dodging": true})
	assert_eq(CombatRules.attack_advantage(_hero, ability, _enemy), 0, "vantagem e desvantagem se anulam")


func test_healing_gets_a_fallen_hero_back_up() -> void:
	_hero.take_damage(999, _enemy)
	assert_true(_hero.downed)
	_hero.heal(5)
	assert_false(_hero.downed)
	assert_eq(_hero.hp, 5)


func test_cooldown_blocks_using_again() -> void:
	var ability := _ability(Ability.Roll.AUTO, 1, 1)
	ability.cooldown = 5.0
	ability.windup = 0.0
	_hero.abilities = [ability]
	_hero.cooldowns = [0.0]
	assert_true(_hero.use_ability(0, _enemy, _enemy.global_position))
	await wait_physics_frames(2)
	assert_false(_hero.use_ability(0, _enemy, _enemy.global_position), "em recarga")
	assert_lt(_enemy.hp, _enemy.max_hp, "o primeiro uso acertou")


func test_perfect_timing_turns_into_advantage() -> void:
	var r := CombatRules.resolve(_hero, _ability(Ability.Roll.ATTACK, 1, 6), _enemy, _enemy.global_position, _all(), 1)
	assert_string_contains(String(r[0]["text"]), "vant.")
	var bad := CombatRules.resolve(_hero, _ability(Ability.Roll.ATTACK, 1, 6), _enemy, _enemy.global_position, _all(), -1)
	assert_string_contains(String(bad[0]["text"]), "desv.")
