class_name PlayerController
extends Node
## Você no comando do herói (filho do Combatant). WASD anda em relação à câmera, Shift corre,
## o mouse mira (centro da tela), botão esquerdo = ataque (segure para continuar), Q/E/R = habilidades,
## Espaço = esquiva, F = interagir.

## Avisos curtos para a tela: "Sem alvo no alcance", "Recarregando"...
signal message(text: String)
## O que dá para usar com F agora (null = nada por perto).
signal interactable_changed(node: Interactable)

const ACTIONS: Array[StringName] = [&"attack", &"skill_q", &"skill_e", &"skill_r"]
const KEY_NAMES: Array[String] = ["Botão esq.", "Q", "E", "R"]

@export var sprint_multiplier: float = 1.45
@export var interact_range: float = 2.8
## Ajuda na mira: aceita alvos até este ângulo (radianos) do centro da tela.
@export var aim_assist: float = 0.3
## No mapa (D022): o botão esquerdo é só um golpe para começar a luta com vantagem; Q/E/R ficam para a arena.
@export var field_mode: bool = true

var camera: ThirdPersonCamera
var enabled: bool = true
var _me: Combatant
var _interactable: Interactable


func _ready() -> void:
	_me = get_parent() as Combatant


func _physics_process(_delta: float) -> void:
	if not enabled or camera == null or not _me.is_active():
		_me.desired_velocity = Vector3.ZERO
		_set_interactable(null)
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var dir := camera.right_flat() * input.x - camera.forward_flat() * input.y
	var speed := _me.move_speed * (sprint_multiplier if Input.is_action_pressed(&"sprint") else 1.0)
	_me.desired_velocity = dir * speed
	if Input.is_action_pressed(&"attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_ability(0, true)
	_update_interactable()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _me.is_active():
		return
	for i: int in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[i]):
			if i > 0 or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				try_ability(i, false)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"dodge"):
		var dir := _me.desired_velocity
		if dir.length_squared() < 0.01:
			dir = camera.forward_flat()
		_me.dodge(dir)
	elif event.is_action_pressed(&"interact") and _interactable:
		_interactable.interact(_me)


## Usa a habilidade da tecla i mirando pelo centro da tela. quiet = não avisa quando não dá.
func try_ability(index: int, quiet: bool) -> bool:
	if field_mode:
		if index == 0:
			_field_strike()
		elif not quiet:
			message.emit("Habilidades são usadas na luta")
		return false
	if index >= _me.abilities.size() or _me.casting:
		return false
	var ability := _me.abilities[index]
	if _me.cooldowns[index] > 0.0:
		if not quiet:
			message.emit("%s recarregando (%.0f s)" % [ability.title, ceilf(_me.cooldowns[index])])
		return false
	var target: Combatant = null
	var point := _me.global_position
	match ability.shape:
		Ability.Shape.TARGET, Ability.Shape.DASH:
			target = pick_target(ability)
			if target == null:
				if not quiet:
					message.emit("Sem alvo no alcance (%.0f m)" % ability.range_m)
				return false
		Ability.Shape.AREA:
			point = _clamp_to_range(camera.aim_point(), ability.range_m)
		Ability.Shape.LINE, Ability.Shape.CONE:
			point = _me.global_position + camera.forward_flat() * ability.range_m
	return _me.use_ability(index, target, point)


var _strike_ready_at: float = 0.0


## Golpe no mapa: acertou um inimigo de um grupo, a luta começa com você jogando primeiro.
func _field_strike() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _strike_ready_at:
		return
	_strike_ready_at = now + 0.7
	_me.ability_used.emit(0)
	var forward := -_me.global_basis.z
	if camera:
		forward = camera.forward_flat()
	for node: Node in get_tree().get_nodes_in_group("encounter"):
		var encounter := node as Encounter
		for c: Combatant in encounter.members():
			var to := c.global_position - _me.global_position
			to.y = 0.0
			if to.length() <= 3.0 and forward.dot(to.normalized()) > 0.3:
				await get_tree().create_timer(0.15).timeout
				encounter.fire(true)
				return


## O alvo mais perto do centro da tela, dentro do alcance. Cura sem ninguém na mira = quem está pior (ou você).
func pick_target(ability: Ability) -> Combatant:
	var wants_enemy := ability.is_offensive()
	var origin := camera.aim_origin()
	var dir := camera.aim_dir()
	var melee := ability.range_m < 4.0
	var best: Combatant = null
	var best_score := INF
	for node: Node in get_tree().get_nodes_in_group("combatant"):
		var c := node as Combatant
		if c == null or c.recruitable or c.is_opponent(_me) != wants_enemy:
			continue
		if not c.is_active() and not (ability.kind == Ability.Kind.HEAL and c.downed):
			continue
		if c == _me and wants_enemy:
			continue
		var flat := Vector2(c.global_position.x - _me.global_position.x, c.global_position.z - _me.global_position.z)
		if flat.length() > ability.range_m + 0.6:
			continue
		var angle := dir.angle_to((c.global_position + Vector3.UP - origin).normalized())
		var limit := 1.3 if melee else aim_assist
		if angle <= limit and angle < best_score:
			best_score = angle
			best = c
	if best == null and ability.kind == Ability.Kind.HEAL:
		best = _most_hurt_ally(ability.range_m)
	return best


## Inimigo na mira (para o quadro de alvo na tela).
func looked_at() -> Combatant:
	var origin := camera.aim_origin()
	var dir := camera.aim_dir()
	var best: Combatant = null
	var best_angle := 0.2
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var c := node as Combatant
		if c == null or not c.is_active() or c.global_position.distance_to(_me.global_position) > 35.0:
			continue
		var angle := dir.angle_to((c.global_position + Vector3.UP - origin).normalized())
		if angle < best_angle:
			best_angle = angle
			best = c
	return best


func _most_hurt_ally(reach: float) -> Combatant:
	var best: Combatant = _me
	var best_ratio := float(_me.hp) / _me.max_hp
	for node: Node in get_tree().get_nodes_in_group("heroes"):
		var c := node as Combatant
		if c == null or c.recruitable or c.global_position.distance_to(_me.global_position) > reach:
			continue
		var ratio := float(c.hp) / c.max_hp if c.is_active() else -1.0
		if ratio < best_ratio:
			best_ratio = ratio
			best = c
	return best


func _clamp_to_range(point: Vector3, reach: float) -> Vector3:
	var offset := point - _me.global_position
	offset.y = 0.0
	if offset.length() > reach:
		offset = offset.normalized() * reach
	return _me.global_position + offset


func _update_interactable() -> void:
	var best: Interactable = null
	var best_d := interact_range
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		var it := node as Interactable
		if it == null or not it.is_available():
			continue
		var d := it.global_position.distance_to(_me.global_position)
		if d < best_d:
			best_d = d
			best = it
	_set_interactable(best)


func _set_interactable(node: Interactable) -> void:
	if node != _interactable:
		_interactable = node
		interactable_changed.emit(node)
