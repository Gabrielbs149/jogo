class_name CombatRules
extends RefCounted
## Regras do D&D 5.5 adaptadas ao tempo real (sem turnos):
## - Ataque: d20 + bônus (+1d4 da Bênção) contra a CA. 20 natural = crítico (dados em dobro); 1 natural erra.
## - Vantagem: rola 2d20 e fica com o maior. Desvantagem: o menor. As duas juntas se anulam.
## - Salvamento: d20 + bônus do alvo (+Bênção) contra a CD de quem lançou. Passou: metade do dano (ou nada).
## - Ataque furtivo: +Nd6 com vantagem ou com um aliado a 2 m do alvo, uma vez a cada 2,5 s.
## - Marca do caçador: quem marcou causa +Nd6 no alvo marcado.

const SNEAK_ALLY_RANGE := 2.0
const LINE_WIDTH := 1.2
## Metade da abertura do cone, em radianos (≈ 35°).
const CONE_HALF_ANGLE := 0.61


static func everyone(tree: SceneTree) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for node: Node in tree.get_nodes_in_group("combatant"):
		var c := node as Combatant
		if c and c.is_active():
			result.append(c)
	return result


## Rola o d20 com vantagem (+1), normal (0) ou desvantagem (-1).
static func d20(advantage: int) -> Dictionary:
	var a := Dice.d20()
	if advantage == 0:
		return {"value": a, "text": str(a)}
	var b := Dice.d20()
	var value := maxi(a, b) if advantage > 0 else mini(a, b)
	return {"value": value, "text": "%d/%d %s" % [a, b, "vant." if advantage > 0 else "desv."]}


static func attack_advantage(attacker: Combatant, ability: Ability, target: Combatant) -> int:
	var adv := ability.advantage or attacker.is_hidden() or target.has_flag("expose")
	var dis := target.has_flag("dodging") or attacker.has_flag("frighten")
	return (1 if adv else 0) - (1 if dis else 0)


static func hit_chance(attacker: Combatant, target: Combatant) -> float:
	var need := target.current_ac() - attacker.attack_bonus
	return clampf((21.0 - need) / 20.0, 0.05, 0.95)


static func fail_chance(caster: Combatant, ability: Ability, target: Combatant) -> float:
	var need := caster.spell_dc - target.save_bonus(ability.save)
	return clampf((need - 1.0) / 20.0, 0.05, 0.95)


## Dano médio esperado contra o alvo (a IA usa para escolher).
static func expected(user: Combatant, ability: Ability, target: Combatant) -> float:
	match ability.roll:
		Ability.Roll.ATTACK:
			return ability.average() * hit_chance(user, target)
		Ability.Roll.SAVE:
			var fail := fail_chance(user, ability, target)
			return ability.average() * (fail + ((1.0 - fail) * 0.5 if ability.half_on_save else 0.0))
	return ability.average()


## Quem é atingido usando a habilidade no alvo/ponto.
static func affected(user: Combatant, ability: Ability, target: Combatant, point: Vector3, all: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	var wants_enemy := ability.is_offensive()
	if ability.needs_target():
		if target and is_instance_valid(target) and target.is_opponent(user) == wants_enemy:
			result.append(target)
		return result
	var forward := point - user.global_position
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.01 else -user.global_basis.z
	for c: Combatant in all:
		if not c.is_active() or c.recruitable or c.is_opponent(user) != wants_enemy:
			continue
		var to := c.global_position - user.global_position
		to.y = 0.0
		var hit := false
		match ability.shape:
			Ability.Shape.TARGET, Ability.Shape.DASH:
				hit = c == target
			Ability.Shape.SELF:
				hit = c == user
			Ability.Shape.AREA:
				hit = _flat_distance(c.global_position, point) <= ability.radius_m
			Ability.Shape.ALLIES_AROUND, Ability.Shape.ENEMIES_AROUND:
				hit = to.length() <= ability.radius_m
			Ability.Shape.LINE:
				var along := to.dot(forward)
				hit = along >= 0.0 and along <= ability.range_m and (to - forward * along).length() <= maxf(ability.radius_m, LINE_WIDTH)
			Ability.Shape.CONE:
				hit = to.length() <= ability.range_m and (to.length() < 0.5 or forward.angle_to(to.normalized()) <= CONE_HALF_ANGLE)
		if hit:
			result.append(c)
	return result


## Rola tudo. Cada resultado: {"target", "kind": "hit"|"crit"|"miss"|"save"|"fail"|"auto"|"heal"|"status", "amount", "text"}.
static func resolve(user: Combatant, ability: Ability, target: Combatant, point: Vector3, all: Array[Combatant]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var now := Time.get_ticks_msec() / 1000.0
	for t: Combatant in affected(user, ability, target, point, all):
		match ability.kind:
			Ability.Kind.HEAL:
				var amount := Dice.roll(ability.dice_count, ability.dice_sides) + ability.bonus
				results.append({"target": t, "kind": "heal", "amount": amount, "text": "cura %d" % amount})
			Ability.Kind.BUFF:
				results.append({"target": t, "kind": "status", "amount": 0, "text": ability.status_title})
			_:
				for h: int in ability.hits:
					results.append(_strike(user, ability, t, all, now))
	return results


## Aplica os resultados: dano, cura, efeitos, números na tela e linhas no registro.
static func apply(user: Combatant, ability: Ability, results: Array[Dictionary], fx: CombatFX) -> void:
	for r: Dictionary in results:
		var t := r["target"] as Combatant
		if not is_instance_valid(t):
			continue
		var kind := String(r["kind"])
		var amount := int(r["amount"])
		user.rolled.emit("%s · %s → %s: %s" % [user.display_name, ability.title, t.display_name, r["text"]])
		match kind:
			"heal":
				t.heal(amount)
				if fx:
					fx.floating_text(t.global_position, "+%d" % amount, Color(0.6, 1.0, 0.65))
					fx.rising_glow(t.global_position, ability.vfx_color)
			"status":
				t.add_status(make_status(user, ability))
				if fx:
					fx.floating_text(t.global_position, ability.status_title, ability.vfx_color)
			"miss", "save":
				if fx:
					fx.floating_text(t.global_position, "errou" if kind == "miss" else ("½ %d" % amount if amount > 0 else "resistiu"), Color(0.85, 0.85, 0.8))
				if amount > 0:
					t.take_damage(amount, user)
			_:
				if ability.status_title != "" and ability.kind != Ability.Kind.HEAL:
					t.add_status(make_status(user, ability))
				if amount > 0:
					t.take_damage(amount, user)
				if fx:
					var label := ("%d!" % amount) if kind == "crit" else (str(amount) if amount > 0 else ability.status_title)
					fx.floating_text(t.global_position, label, Color(1.0, 0.55, 0.3) if kind == "crit" else Color(1.0, 0.9, 0.7), kind == "crit")
					fx.shake(t)
		if kind in ["hit", "crit", "miss"]:
			t.remove_flag("expose")  # o "exposto" vale para o próximo ataque


static func make_status(user: Combatant, ability: Ability) -> Dictionary:
	return {
		"title": ability.status_title,
		"time": ability.status_time,
		"ac": ability.buff_ac,
		"bless": ability.bless_die,
		"invisible": ability.invisible,
		"frighten": ability.frighten,
		"expose": ability.expose,
		"mark": ability.mark_dice,
		"mark_by": user if ability.mark_dice > 0 else null,
	}


static func _strike(user: Combatant, ability: Ability, t: Combatant, all: Array[Combatant], now: float) -> Dictionary:
	match ability.roll:
		Ability.Roll.ATTACK:
			var adv := attack_advantage(user, ability, t)
			var die := d20(adv)
			var natural := int(die["value"])
			var bless := Dice.roll(1, user.bless_die()) if user.bless_die() > 0 else 0
			var total := natural + user.attack_bonus + bless
			var head := "%s+%d%s = %d vs CA %d" % [die["text"], user.attack_bonus, (" +%d bênção" % bless) if bless > 0 else "", total, t.current_ac()]
			var crit := natural == 20
			if natural == 1 or (not crit and total < t.current_ac()):
				return {"target": t, "kind": "miss", "amount": 0, "text": head + ", errou"}
			var dmg := _damage(user, ability, t, all, now, adv, crit)
			return {"target": t, "kind": "crit" if crit else "hit", "amount": dmg["amount"],
					"text": "%s, %s %s" % [head, "CRÍTICO" if crit else "acerto", dmg["text"]]}
		Ability.Roll.SAVE:
			var die := Dice.d20()
			var bless := Dice.roll(1, t.bless_die()) if t.bless_die() > 0 else 0
			var bonus := t.save_bonus(ability.save)
			var total := die + bonus + bless
			var save_name: String = ["DES", "CON", "SAB"][ability.save]
			var head := "salv. %s %d+%d%s = %d vs CD %d" % [save_name, die, bonus, (" +%d bênção" % bless) if bless > 0 else "", total, user.spell_dc]
			var dmg := _damage(user, ability, t, all, now, 0, false)
			if total >= user.spell_dc:
				var half := int(dmg["amount"]) / 2 if ability.half_on_save else 0
				return {"target": t, "kind": "save", "amount": half, "text": head + ", passou%s" % ((" (½ = %d)" % half) if half > 0 else "")}
			return {"target": t, "kind": "fail", "amount": dmg["amount"], "text": "%s, falhou %s" % [head, dmg["text"]]}
	var auto := _damage(user, ability, t, all, now, 0, false)
	return {"target": t, "kind": "auto", "amount": auto["amount"], "text": auto["text"]}


static func _damage(user: Combatant, ability: Ability, t: Combatant, all: Array[Combatant], now: float, adv: int, crit: bool) -> Dictionary:
	if ability.dice_count <= 0:
		return {"amount": 0, "text": ""}
	var mult := 2 if crit else 1
	var amount := Dice.roll(ability.dice_count * mult, ability.dice_sides) + ability.bonus
	var text := "%dd%d+%d" % [ability.dice_count * mult, ability.dice_sides, ability.bonus]
	if _sneak_applies(user, ability, t, all, now, adv):
		user.sneak_ready_at = now + Combatant.SNEAK_INTERVAL
		amount += Dice.roll(ability.sneak_dice * mult, 6)
		text += " +%dd6 furtivo" % (ability.sneak_dice * mult)
	var mark := t.mark_dice_from(user)
	if mark > 0:
		amount += Dice.roll(mark * mult, 6)
		text += " +%dd6 marca" % (mark * mult)
	return {"amount": amount, "text": "%s = %d" % [text, amount]}


static func _sneak_applies(user: Combatant, ability: Ability, t: Combatant, all: Array[Combatant], now: float, adv: int) -> bool:
	if ability.sneak_dice <= 0 or now < user.sneak_ready_at or adv < 0:
		return false
	if adv > 0:
		return true
	for c: Combatant in all:
		if c != user and c.team == user.team and c.is_active() and _flat_distance(c.global_position, t.global_position) <= SNEAK_ALLY_RANGE:
			return true
	return false


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
