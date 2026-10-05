class_name CombatAI
extends RefCounted
## Decide o turno de quem não é controlado pelo jogador: onde parar e o que usar.
## Testa cada casa alcançável x cada habilidade x cada alvo e fica com a melhor nota.
## Devolve {"move_to": Vector2i, "ability": Ability ou null, "target": Vector2i}.


static func plan(unit: Unit, grid: CombatGrid, units: Array[Unit]) -> Dictionary:
	var stands := standing_cells(unit, grid, units)
	var best := {"move_to": unit.cell, "ability": null, "target": unit.cell, "score": 0.0}
	if unit.has_action:
		for stand: Vector2i in stands:
			var travel := CombatGrid.distance(unit.cell, stand) * 0.05
			for ability: Ability in unit.abilities:
				for target: Vector2i in CombatRules.target_cells(unit, ability, stand, grid, units, true):
					var score := _score(unit, ability, target, stand, grid, units) - travel
					if score > float(best["score"]):
						best = {"move_to": stand, "ability": ability, "target": target, "score": score}
	if best["ability"] != null:
		return best
	# Ninguém ao alcance: chega o mais perto possível do oponente mais próximo
	var closest := unit.cell
	var closest_distance := _distance_to_opponents(unit, unit.cell, units)
	for stand: Vector2i in stands:
		var d := _distance_to_opponents(unit, stand, units)
		if d < closest_distance:
			closest = stand
			closest_distance = d
	return {"move_to": closest, "ability": null, "target": closest, "score": 0.0}


## Casas onde a unidade pode terminar o movimento (inclui ficar parada).
static func standing_cells(unit: Unit, grid: CombatGrid, units: Array[Unit]) -> Array[Vector2i]:
	var pass_blocked := {}
	var occupied := {}
	for u: Unit in units:
		if u.is_alive() and u != unit:
			occupied[u.cell] = true
			if u.is_opponent(unit):
				pass_blocked[u.cell] = true
	var result: Array[Vector2i] = [unit.cell]
	for c: Vector2i in grid.reachable(unit.cell, unit.moves_left, unit.flying, pass_blocked):
		if not occupied.has(c) and not grid.is_blocked(c):
			result.append(c)
	return result


static func _score(unit: Unit, ability: Ability, target: Vector2i, stand: Vector2i, grid: CombatGrid, units: Array[Unit]) -> float:
	# A habilidade é avaliada como se a unidade já estivesse em "stand"
	var original := unit.cell
	unit.cell = stand
	var hit_units := CombatRules.affected(unit, ability, target, grid, units)
	unit.cell = original
	var score := 0.0
	match ability.kind:
		Ability.Kind.ATTACK:
			for u: Unit in hit_units:
				var expected := CombatRules.expected_damage(unit, ability, u)
				score += expected
				if expected >= u.hp:
					score += 8.0  # derrubar alguém vale muito
		Ability.Kind.HEAL:
			for u: Unit in hit_units:
				var missing := u.max_hp - u.hp
				if missing >= ability.average() * 0.6:
					score += minf(missing, ability.average()) * 1.3
		Ability.Kind.BUFF:
			if _distance_to_opponents(unit, stand, units) <= 6:
				score += 2.5 * hit_units.size()
	return score


static func _distance_to_opponents(unit: Unit, from: Vector2i, units: Array[Unit]) -> int:
	var best := 9999
	for u: Unit in units:
		if u.is_alive() and u.is_opponent(unit):
			best = mini(best, CombatGrid.distance(from, u.cell))
	return best
