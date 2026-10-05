class_name CombatRules
extends RefCounted
## Regras do combate, sem animação: alcance, alvos, chance de acerto e rolagens.
## Ataque: d20 + bônus de acerto >= CA do alvo. 20 natural = crítico (dados em dobro); 1 natural = erra.


static func hit_chance(attacker: Unit, defender: Unit) -> float:
	var need := defender.current_ac() - attacker.hit_bonus()
	return clampf((21.0 - need) / 20.0, 0.05, 0.95)


static func unit_at(units: Array[Unit], c: Vector2i) -> Unit:
	for u: Unit in units:
		if u.is_alive() and u.cell == c:
			return u
	return null


## Casas onde dá para mirar a habilidade estando em from_cell.
## only_units: para área, só considera casas com alguém (a IA usa para pensar mais rápido).
static func target_cells(user: Unit, ability: Ability, from_cell: Vector2i, grid: CombatGrid,
		units: Array[Unit], only_units: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match ability.target:
		Ability.Target.SELF:
			result.append(from_cell)
		Ability.Target.ENEMY, Ability.Target.ALLY:
			for u: Unit in units:
				if not u.is_alive():
					continue
				var wants_enemy := ability.target == Ability.Target.ENEMY
				if u.is_opponent(user) != wants_enemy:
					continue
				var c := from_cell if u == user else u.cell
				if CombatGrid.distance(from_cell, c) <= ability.reach and grid.line_of_sight(from_cell, c):
					result.append(c)
		Ability.Target.AREA:
			if only_units:
				for u: Unit in units:
					if u.is_alive() and u.is_opponent(user) and CombatGrid.distance(from_cell, u.cell) <= ability.reach \
							and grid.line_of_sight(from_cell, u.cell):
						result.append(u.cell)
			else:
				for c: Vector2i in grid.cells_in_radius(from_cell, ability.reach):
					if grid.line_of_sight(from_cell, c):
						result.append(c)
	return result


## Quem é afetado ao usar a habilidade mirando em target_cell.
static func affected(user: Unit, ability: Ability, target_cell: Vector2i, grid: CombatGrid, units: Array[Unit]) -> Array[Unit]:
	var result: Array[Unit] = []
	if ability.target == Ability.Target.SELF:
		result.append(user)
		return result
	var area := grid.cells_in_radius(target_cell, ability.radius)
	var wants_enemy := ability.kind == Ability.Kind.ATTACK
	for u: Unit in units:
		if u.is_alive() and area.has(u.cell) and u.is_opponent(user) == wants_enemy:
			result.append(u)
	return result


## Rola tudo. Cada resultado: {"unit", "kind": "hit"|"crit"|"miss"|"heal"|"buff", "amount", "roll"}.
static func resolve(user: Unit, ability: Ability, target_cell: Vector2i, grid: CombatGrid, units: Array[Unit]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for target: Unit in affected(user, ability, target_cell, grid, units):
		for h: int in ability.hits:
			match ability.kind:
				Ability.Kind.ATTACK:
					results.append(_attack(user, ability, target))
				Ability.Kind.HEAL:
					results.append({"unit": target, "kind": "heal", "amount": Dice.roll(ability.dice_count, ability.dice_sides) + ability.bonus, "roll": 0})
				Ability.Kind.BUFF:
					results.append({"unit": target, "kind": "buff", "amount": 0, "roll": 0})
	return results


static func expected_damage(user: Unit, ability: Ability, target: Unit) -> float:
	var chance := hit_chance(user, target) if ability.needs_roll else 1.0
	return ability.average() * chance


static func _attack(user: Unit, ability: Ability, target: Unit) -> Dictionary:
	if not ability.needs_roll:
		return {"unit": target, "kind": "hit", "amount": Dice.roll(ability.dice_count, ability.dice_sides) + ability.bonus, "roll": 0}
	var d20 := Dice.d20()
	var crit := d20 == 20
	var hit := crit or (d20 != 1 and d20 + user.hit_bonus() >= target.current_ac())
	if not hit:
		return {"unit": target, "kind": "miss", "amount": 0, "roll": d20}
	var count := ability.dice_count * (2 if crit else 1)
	return {"unit": target, "kind": "crit" if crit else "hit", "amount": Dice.roll(count, ability.dice_sides) + ability.bonus, "roll": d20}
