@tool
class_name VidaCorpo
extends SkeletonModifier3D
## O corpo vivo por cima das animações (D068). As animações emprestadas do KayKit são de boneco sem rabo e com o
## corpo duro: o Tico parecia "travado". Este modificador roda depois da animação, a cada quadro, e soma:
## - rabo: balança (devagar parado, no ritmo dos passos andando, mais correndo), sobe correndo e chicoteia para fora
##   nas curvas (com mola: atrasa e passa um pouco do ponto);
## - tronco: inclina para dentro da curva, para a frente correndo, e assenta com mola quando para ou arranca;
## - respiração: o peito sobe e desce devagar;
## - cabeça: olha para a coisa que dá para usar (F), para quem está perto, e parado dá umas olhadas em volta.
## Durante golpe, cena presa (sentado, deitado) e luta por turnos, o corpo e a cabeça saem de cena; o rabo continua.
## O personagem olha para +Z no espaço do esqueleto (a esquerda é +X), como o Tico e os do KayKit.

@export var tail_bones: Array[StringName] = [&"Tail1", &"Tail2", &"Tail3"]
@export var spine_bone: StringName = &"Spine"
@export var chest_bone: StringName = &"Chest"
@export var neck_bone: StringName = &"Neck"
@export var head_bone: StringName = &"Head"
## Quanto (0..1) cada parte entra. Zero desliga.
@export_range(0.0, 2.0) var rabo: float = 1.0
@export_range(0.0, 2.0) var tronco: float = 1.0
@export_range(0.0, 2.0) var cabeca: float = 1.0
@export_range(0.0, 2.0) var respiracao: float = 1.0

var _me: Node3D
var _animator: Node
var _time: float = 0.0
var _last_yaw: float = 0.0
var _last_pos: Vector3
var _yaw_rate: float = 0.0
var _speed: float = 0.0
var _accel: float = 0.0
## Molas: [valor, velocidade]
var _lean_fwd := Vector2.ZERO
var _lean_side := Vector2.ZERO
var _tail_side := Vector2.ZERO
var _tail_lift := Vector2.ZERO
var _look := Vector2.ZERO  # yaw, pitch atuais (rad)
var _look_goal := Vector2.ZERO
var _look_check: float = 0.0
var _glance_time: float = 0.0
var _glance := Vector2.ZERO
var _idle_time: float = 0.0
## Fase do balanço do rabo, somada a cada quadro (D073). Antes era tempo x frequência: com o tempo já grande, qualquer
## mudança na frequência (velocidade) fazia o rabo pular de lugar de um quadro para o outro e a ponta "piscava".
var _tail_phase: float = 0.0
var _yaw_wait: float = 0.0
var _body_weight: float = 1.0
var _first: bool = true


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or delta <= 0.0:
		return
	if _me == null:
		_find_owner()
	delta = minf(delta, 0.05)
	_time += delta
	_read_motion(delta)
	var body_target := 0.0 if _busy() else 1.0
	_body_weight = move_toward(_body_weight, body_target, delta * 3.0)
	var run := clampf(_speed / maxf(_move_speed(), 0.1), 0.0, 2.2)
	# --- molas do tronco
	var fwd_goal := deg_to_rad(5.5) * minf(run, 1.8) - _accel * 0.012
	_lean_fwd = _spring(_lean_fwd, clampf(fwd_goal, -0.2, 0.3), 38.0, 7.5, delta)
	var side_goal := clampf(-_yaw_rate * 0.055 * minf(run + 0.2, 1.6), -0.22, 0.22)
	_lean_side = _spring(_lean_side, side_goal, 30.0, 7.0, delta)
	# --- molas do rabo: fica para trás nas curvas e sobe correndo
	_tail_side = _spring(_tail_side, clampf(-_yaw_rate * 0.16, -0.55, 0.55), 18.0, 3.2, delta)
	_tail_lift = _spring(_tail_lift, deg_to_rad(4.0) + deg_to_rad(10.0) * minf(run, 1.6), 20.0, 5.0, delta)
	if tronco > 0.0 and _body_weight > 0.001:
		var w := tronco * _body_weight
		var breath := sin(_time * TAU / 3.4) * deg_to_rad(1.6) * respiracao * (1.0 - clampf(run, 0.0, 1.0) * 0.6)
		_turn(sk, spine_bone, Basis(Vector3.BACK, _lean_side.x * 0.6 * w) * Basis(Vector3.RIGHT, _lean_fwd.x * 0.55 * w))
		_turn(sk, chest_bone, Basis(Vector3.BACK, _lean_side.x * 0.4 * w) * Basis(Vector3.RIGHT, (_lean_fwd.x * 0.45 - breath) * w))
	if rabo > 0.0:
		_tail(sk, run, delta)
	if cabeca > 0.0 and _body_weight > 0.001:
		_head(sk, delta)


func _find_owner() -> void:
	var node: Node = get_parent()
	while node:
		if node is Combatant or node is CharacterBody3D:
			_me = node as Node3D
			break
		node = node.get_parent()
	if _me:
		_animator = _me.get_node_or_null("Animator")
		_last_yaw = _me.global_rotation.y
		_last_pos = _me.global_position


func _move_speed() -> float:
	if _me and _me.get("move_speed") != null:
		return float(_me.get("move_speed"))
	return 4.0


func _read_motion(delta: float) -> void:
	if _me == null or not _me.is_inside_tree():
		return
	var pos := _me.global_position
	var yaw := _me.global_rotation.y
	if _first:
		_first = false
		_last_pos = pos
		_last_yaw = yaw
	# a velocidade vem da física (a posição só muda no passo da física: com o jogo a mais de 60 quadros por segundo,
	# medir pela posição dava 0 num quadro e o dobro no outro, e o rabo e o tronco tremiam)
	var speed := 0.0
	if _me is CharacterBody3D:
		var v := (_me as CharacterBody3D).velocity
		speed = Vector2(v.x, v.z).length()
	else:
		var moved := pos - _last_pos
		moved.y = 0.0
		speed = moved.length() / delta
	if speed > 30.0:
		speed = 0.0  # teleporte (cena, porta): não é corrida
	_accel = lerpf(_accel, (speed - _speed) / delta, minf(1.0, delta * 8.0))
	_speed = lerpf(_speed, speed, minf(1.0, delta * 10.0))
	# o giro também só muda no passo da física: mede o quanto girou desde a última mudança, não por quadro
	_yaw_wait += delta
	var diff := wrapf(yaw - _last_yaw, -PI, PI)
	if absf(diff) > 0.00001:
		var turn := diff / _yaw_wait
		if absf(turn) > 25.0:
			turn = 0.0
		_yaw_rate = lerpf(_yaw_rate, turn, minf(1.0, _yaw_wait * 10.0))
		_yaw_wait = 0.0
		_last_yaw = yaw
	elif _yaw_wait > 0.05:
		_yaw_rate = lerpf(_yaw_rate, 0.0, minf(1.0, delta * 10.0))  # parou de girar
	_last_pos = pos
	_idle_time = _idle_time + delta if _speed < 0.25 else 0.0


## Golpe, cena presa ou luta por turnos: o corpo é da animação.
func _busy() -> bool:
	if _animator == null:
		return false
	if _animator.get("_one_shot") or StringName(_animator.get("_held")) != &"":
		return true
	return _me != null and _me.get("real_time") == false


func _tail(sk: Skeleton3D, run: float, delta: float) -> void:
	# balanço: parado devagar e largo; andando no ritmo dos passos; cada pedaço atrasa um pouco (onda)
	var freq := lerpf(0.42, 1.7, clampf(run, 0.0, 1.0)) + maxf(run - 1.0, 0.0) * 0.6
	var amp := lerpf(deg_to_rad(9.0), deg_to_rad(13.0), clampf(run, 0.0, 1.5))
	var w := rabo
	_tail_phase = fmod(_tail_phase + delta * TAU * freq, TAU * 1000.0)
	for i: int in tail_bones.size():
		var k := float(i + 1) / tail_bones.size()
		var phase := _tail_phase - i * 0.75
		var sway := sin(phase) * amp * (0.55 + 0.45 * k) + _tail_side.x * (0.45 + 0.35 * k)
		var lift := _tail_lift.x * (1.0 - 0.35 * i) + sin(phase * 2.0) * deg_to_rad(2.5) * k
		_turn(sk, tail_bones[i], Basis(Vector3.UP, sway * w) * Basis(Vector3.RIGHT, lift * w))


func _head(sk: Skeleton3D, delta: float) -> void:
	_look_check -= delta
	if _look_check <= 0.0:
		_look_check = 0.2
		_look_goal = _choose_look(sk)
	var speed := 5.0 if _look_goal != Vector2.ZERO else 3.0
	_look = _look.lerp(_look_goal, minf(1.0, delta * speed))
	var w := cabeca * _body_weight
	_turn(sk, neck_bone, Basis(Vector3.UP, _look.x * 0.4 * w) * Basis(Vector3.RIGHT, -_look.y * 0.4 * w))
	_turn(sk, head_bone, Basis(Vector3.UP, _look.x * 0.6 * w) * Basis(Vector3.RIGHT, -_look.y * 0.6 * w))


## Para onde olhar (yaw, pitch em rad, no espaço do personagem): a coisa de usar, alguém perto, ou uma olhada à toa.
func _choose_look(sk: Skeleton3D) -> Vector2:
	if Engine.is_editor_hint() or _me == null:
		return Vector2.ZERO
	var head_at := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(head_bone)).origin
	var target: Variant = null
	var thing: Variant = _me.get_meta("olhar") if _me.has_meta("olhar") else null
	if thing is Node3D and is_instance_valid(thing) and (thing as Node3D).is_inside_tree():
		target = (thing as Node3D).global_position
	if target == null:
		var best := 4.5
		for node: Node in get_tree().get_nodes_in_group(&"gente"):
			var person := node as Node3D
			if person == null or person == _me or not person.is_visible_in_tree():
				continue
			var d := person.global_position.distance_to(_me.global_position)
			if d < best and _in_front(person.global_position, 1.7):
				best = d
				target = person.global_position + Vector3.UP * 0.9 * person.global_basis.get_scale().y
	if target != null:
		return _angles_to(sk, head_at, target as Vector3)
	# parado um tempo: olha em volta de vez em quando
	if _idle_time > 2.5:
		_glance_time -= 0.2
		if _glance_time <= 0.0:
			_glance_time = randf_range(1.6, 4.0)
			_glance = Vector2(randf_range(-1.0, 1.0), randf_range(-0.12, 0.3)) if randf() < 0.65 else Vector2.ZERO
		return _glance
	_glance = Vector2.ZERO
	return Vector2.ZERO


func _in_front(point: Vector3, half_angle: float) -> bool:
	var to := point - _me.global_position
	to.y = 0.0
	var ahead := -_me.global_basis.z
	ahead.y = 0.0
	return to.length() < 0.05 or ahead.normalized().angle_to(to.normalized()) < half_angle


func _angles_to(sk: Skeleton3D, from: Vector3, target: Vector3) -> Vector2:
	var local := sk.global_transform.affine_inverse() * target
	var origin := sk.global_transform.affine_inverse() * from
	var d := local - origin
	var yaw := atan2(d.x, d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	return Vector2(clampf(yaw, -1.25, 1.25), clampf(pitch, -0.35, 0.5))


## Mola amortecida: v = [posição, velocidade].
static func _spring(v: Vector2, goal: float, stiffness: float, damping: float, delta: float) -> Vector2:
	var vel := v.y + ((goal - v.x) * stiffness - v.y * damping) * delta
	return Vector2(v.x + vel * delta, vel)


## Gira o osso (a partir da pose já animada) por uma rotação no espaço do personagem.
static func _turn(sk: Skeleton3D, bone_name: StringName, rot: Basis) -> void:
	var bone := sk.find_bone(bone_name)
	if bone < 0:
		return
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var g := pg * Basis(sk.get_bone_pose_rotation(bone))
	sk.set_bone_pose_rotation(bone, (pg.inverse() * (rot * g)).get_rotation_quaternion())
