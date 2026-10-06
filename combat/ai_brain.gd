class_name AIBrain
extends Node
## Cérebro em tempo real, filho de um Combatant.
## - ENEMY: parado até um herói chegar perto (ou atacar); aí persegue, usa o melhor golpe e chama os vizinhos.
## - COMPANION: segue quem lidera e luta contra o que estiver brigando perto do grupo.
## - WAITING: herói encontrado no caminho, esperando você chamar para o grupo.

enum Mode { ENEMY, COMPANION, WAITING }

@export var mode: Mode = Mode.ENEMY
## Aliados: distância atrás de quem lidera.
@export var follow_distance: float = 2.8
## Aliados: entram na luta contra inimigos a até esta distância de quem lidera.
@export var engage_radius: float = 16.0
## Inimigos: chamam para a briga os vizinhos a até esta distância.
@export var call_radius: float = 5.0
## Inimigos: tão longe de casa, desistem e voltam.
@export var leash: float = 35.0
## Sem líder e sem luta: vai atrás do inimigo mais perto (piloto automático do simulador e dos testes).
@export var hunt: bool = false

var leader: Combatant
var aggro: bool = false
## Lugar na fila atrás de quem lidera (0, 1, 2...).
var slot: int = 0
var _me: Combatant
var _agent: NavigationAgent3D
var _target: Combatant
var _plan: Dictionary = {}
var _think: float = 0.0
var _home: Vector3


func _ready() -> void:
	_me = get_parent() as Combatant
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.7
	_agent.target_desired_distance = 0.9
	_agent.radius = 0.5
	_me.add_child.call_deferred(_agent)
	_me.hurt.connect(_on_hurt)
	_set_home.call_deferred()


func _set_home() -> void:
	_home = _me.global_position


func _physics_process(delta: float) -> void:
	if _me == null or not _me.is_active():
		if _me:
			_me.desired_velocity = Vector3.ZERO
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.2 + randf() * 0.1
		_decide()
	_act()


## Inimigos vivos e à vista que eu poderia atacar agora.
func foes() -> Array[Combatant]:
	var result: Array[Combatant] = []
	var anchor := _anchor()
	for c: Combatant in CombatRules.everyone(get_tree()):
		if not c.is_opponent(_me) or c.recruitable or c.is_hidden():
			continue
		if mode == Mode.ENEMY:
			result.append(c)
		else:
			var brain := c.get_node_or_null("AIBrain") as AIBrain
			var fighting := brain != null and brain.aggro
			var near := c.global_position.distance_to(anchor) <= engage_radius
			if near and (fighting or c.global_position.distance_to(_me.global_position) < 6.0):
				result.append(c)
	return result


func _decide() -> void:
	match mode:
		Mode.WAITING:
			_plan = {}
			return
		Mode.ENEMY:
			if not aggro:
				for c: Combatant in foes():
					if c.global_position.distance_to(_me.global_position) <= _me.aggro_radius:
						_start_aggro()
						break
			elif _me.global_position.distance_to(_home) > leash or foes().is_empty():
				aggro = false
				_target = null
	if mode == Mode.ENEMY and not aggro:
		_plan = {}
		return
	_plan = _best_plan()
	if not _plan.is_empty() and _plan["target"]:
		_target = _plan["target"]
	elif _target and (not is_instance_valid(_target) or not _target.is_active() or _target.is_hidden()):
		_target = null
	if _target == null:
		var options := foes()
		if not options.is_empty():
			_target = _nearest(options)


func _act() -> void:
	if _me.casting:
		_me.desired_velocity = Vector3.ZERO
		return
	if not _plan.is_empty():
		var goal: Vector3 = _plan["point"]
		var target := _plan["target"] as Combatant
		if target:
			var healing := _me.abilities[int(_plan["index"])].kind == Ability.Kind.HEAL
			if not is_instance_valid(target) or (not target.is_active() and not healing):
				_plan = {}
				return
			goal = target.global_position
		if _flat(goal - _me.global_position).length() <= float(_plan["range"]):
			_me.desired_velocity = Vector3.ZERO
			if _me.use_ability(int(_plan["index"]), target, goal):
				_plan = {}
		else:
			_move_to(goal, 0.0)
		return
	# sem golpe pronto: fica perto do alvo (ou foge um pouco, se luta de longe)
	if _target and is_instance_valid(_target) and _target.is_active():
		var reach := _me.abilities[0].range_m if not _me.abilities.is_empty() else 2.0
		var dist := _flat(_target.global_position - _me.global_position).length()
		if reach > 6.0 and dist < 2.5:
			var away := _flat(_me.global_position - _target.global_position)
			if not _me.dodge(away):
				_me.desired_velocity = away.normalized() * _me.move_speed
			return
		_move_to(_target.global_position, reach * 0.85)
		return
	match mode:
		Mode.COMPANION:
			if hunt and (leader == null or not is_instance_valid(leader)):
				var prey := _nearest_enemy_anywhere()
				if prey:
					_move_to(prey.global_position, 2.0)
				else:
					_me.desired_velocity = Vector3.ZERO
			elif leader and is_instance_valid(leader):
				var back := _flat(leader.global_basis.z)
				var side := _flat(leader.global_basis.x) * (1.4 if slot % 2 == 0 else -1.4)
				_move_to(leader.global_position + back * (follow_distance + slot * 0.8) + side, 1.2)
			else:
				_me.desired_velocity = Vector3.ZERO
		Mode.ENEMY:
			_move_to(_home, 1.0)
		_:
			_me.desired_velocity = Vector3.ZERO


func _best_plan() -> Dictionary:
	var best := {}
	var best_score := 0.0
	var options := foes()
	var fighting := not options.is_empty()
	for i: int in _me.abilities.size():
		if _me.cooldowns[i] > 0.0:
			continue
		var ability := _me.abilities[i]
		match ability.kind:
			Ability.Kind.HEAL:
				var hurt := _most_hurt()
				if hurt and float(hurt.hp) / hurt.max_hp < 0.55:
					var score := 40.0 if not hurt.is_active() else 25.0 * (1.0 - float(hurt.hp) / hurt.max_hp)
					if score > best_score:
						best_score = score
						best = _plan_for(i, ability, hurt if ability.needs_target() else null, hurt.global_position)
			Ability.Kind.BUFF:
				if fighting and not _has_status(_me, ability.status_title):
					var score := 9.0
					if ability.invisible:
						score = 14.0 if float(_me.hp) / _me.max_hp < 0.5 else 4.0
					if score > best_score:
						best_score = score
						best = _plan_for(i, ability, null, _me.global_position)
			_:
				for foe: Combatant in options:
					var score := CombatRules.expected(_me, ability, foe)
					if ability.kind == Ability.Kind.DEBUFF:
						score = 0.0 if _has_status(foe, ability.status_title) else 7.0
					if ability.shape in [Ability.Shape.AREA, Ability.Shape.CONE, Ability.Shape.LINE, Ability.Shape.ENEMIES_AROUND]:
						var count := _count_near(options, foe.global_position, maxf(ability.radius_m, 2.5))
						if count < 2 and ability.cooldown > 20.0:
							continue  # o golpe forte fica para quando juntar gente
						score *= count
					if foe == _target:
						score *= 1.2
					score /= 1.0 + _flat(foe.global_position - _me.global_position).length() * 0.04
					if score > best_score:
						best_score = score
						best = _plan_for(i, ability, foe if ability.needs_target() else null, foe.global_position)
						best["target"] = foe if ability.needs_target() else null
	return best


func _plan_for(index: int, ability: Ability, target: Combatant, point: Vector3) -> Dictionary:
	var reach := ability.range_m
	match ability.shape:
		Ability.Shape.SELF, Ability.Shape.ALLIES_AROUND:
			reach = 999.0
		Ability.Shape.ENEMIES_AROUND:
			reach = ability.radius_m * 0.8
		Ability.Shape.CONE, Ability.Shape.LINE:
			reach = ability.range_m * 0.8
	if ability.shape in [Ability.Shape.SELF, Ability.Shape.ALLIES_AROUND, Ability.Shape.ENEMIES_AROUND]:
		point = _me.global_position if ability.shape != Ability.Shape.ENEMIES_AROUND else point
	return {"index": index, "target": target, "point": point, "range": reach}


func _start_aggro() -> void:
	if aggro:
		return
	aggro = true
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Combatant
		if other and other != _me and other.global_position.distance_to(_me.global_position) <= call_radius:
			var brain := other.get_node_or_null("AIBrain") as AIBrain
			if brain:
				brain._start_aggro()


func _on_hurt(by: Combatant) -> void:
	if mode == Mode.ENEMY:
		_start_aggro()
		if by and by.is_active():
			_target = by


func _move_to(goal: Vector3, stop_at: float) -> void:
	var flat := _flat(goal - _me.global_position)
	if flat.length() <= stop_at:
		_me.desired_velocity = Vector3.ZERO
		return
	var next := goal
	if _agent.is_inside_tree() and NavigationServer3D.map_get_iteration_id(_me.get_world_3d().navigation_map) > 0:
		_agent.target_position = goal
		next = _agent.get_next_path_position()
	var dir := _flat(next - _me.global_position)
	if dir.length() < 0.05:
		dir = flat
	_me.desired_velocity = dir.normalized() * _me.move_speed


func _anchor() -> Vector3:
	if mode == Mode.COMPANION and leader and is_instance_valid(leader):
		return leader.global_position
	return _me.global_position


func _nearest_enemy_anywhere() -> Combatant:
	var options: Array[Combatant] = []
	for c: Combatant in CombatRules.everyone(get_tree()):
		if c.is_opponent(_me) and not c.recruitable:
			options.append(c)
	return _nearest(options)


func _most_hurt() -> Combatant:
	var best: Combatant = null
	var best_ratio := 2.0
	for node: Node in get_tree().get_nodes_in_group("heroes" if _me.team == Combatant.Team.HEROES else "enemies"):
		var c := node as Combatant
		if c == null or c.recruitable or c.global_position.distance_to(_me.global_position) > 20.0:
			continue
		var ratio := float(c.hp) / c.max_hp if c.is_active() else -1.0
		if ratio < best_ratio:
			best_ratio = ratio
			best = c
	return best


func _nearest(options: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for c: Combatant in options:
		var d := c.global_position.distance_to(_me.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _count_near(options: Array[Combatant], at: Vector3, radius: float) -> int:
	var count := 0
	for c: Combatant in options:
		if _flat(c.global_position - at).length() <= radius:
			count += 1
	return count


func _has_status(c: Combatant, title: String) -> bool:
	for status: Dictionary in c.statuses:
		if status["title"] == title:
			return true
	return false


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
