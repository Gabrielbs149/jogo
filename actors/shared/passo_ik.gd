@tool
class_name PassoIK
extends SkeletonModifier3D
## Pé no chão de verdade (D075). As animações de andar são de gente de perna comprida: no Tico (coxa 13 cm, canela
## 12 cm) a passada delas cobre bem menos chão do que ele anda, e o pé de apoio patinava (40% a 84% da velocidade).
## Aqui cada pé, enquanto apoia, fica CRAVADO no chão (no ponto onde pisou); no ar ele vai do ponto onde levantou até
## onde vai pisar, num arco. A perna (coxa e canela) é dobrada por cinemática inversa de dois ossos para chegar lá, com
## o joelho para a frente, e o quadril desce o que for preciso para o pé alcançar.
## Quando apoia e quando pisa vem do animador (CombatantAnimator: loco_phase, cadence, gait_*), que também toca a
## animação de andar no mesmo ritmo dos passos: os braços balançam casados com as pernas.
## Parado, rolando, sentado ou em cena, a perna volta a ser a da animação.

@export var hips_bone: StringName = &"Hips"
@export var legs: Array[StringName] = [&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"RightUpperLeg", &"RightLowerLeg", &"RightFoot"]
## Altura do tornozelo com o pé no chão (m, como no descanso).
@export var ankle_height: float = 0.05
## Quanto o quadril sobe e desce a cada passo (m).
@export var bob: float = 0.018

var _me: CharacterBody3D
var _animator: Node
var _weight: float = 0.0
## Por pé: {"apoio": bool, "pisou": Vector3 (mundo), "saiu": Vector3 (mundo)}
var _feet: Array[Dictionary] = [{}, {}]


func _process_modification_with_delta(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sk := get_skeleton()
	if sk == null:
		return
	if _animator == null:
		_find()
		if _animator == null:
			return
	var speed := Vector2(_me.velocity.x, _me.velocity.z).length()
	var on := _active(speed)
	_weight = move_toward(_weight, 1.0 if on else 0.0, delta * (6.0 if on else 8.0))
	if _weight <= 0.001:
		_feet = [{}, {}]
		return
	var cadence := float(_animator.get("cadence"))
	var duty := float(_animator.get("gait_duty"))
	var height := float(_animator.get("gait_height"))
	var phase := _phase()
	if cadence <= 0.01 or duty <= 0.0:
		return
	var to_sk := sk.global_transform.affine_inverse()
	var ground := _me.global_position.y + ankle_height
	var vel := Vector3(_me.velocity.x, 0.0, _me.velocity.z)
	var cycle := 2.0 / cadence  # dois passos
	var step := speed / cadence
	var facing := -_me.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var side := facing.cross(Vector3.UP).normalized()  # para a direita do personagem
	var targets: Array[Vector3] = []
	var hip_drop := 0.0
	for i: int in 2:
		var upper := sk.find_bone(legs[i * 3])
		var hip_world := sk.global_transform * sk.get_bone_global_pose(upper).origin
		# fase deste pé: 0 = acabou de pisar; o direito meio ciclo depois
		var p := fposmod(phase - 0.5 * i, 1.0)
		var foot: Dictionary = _feet[i]
		var lateral := side.dot(Vector3(hip_world.x, 0, hip_world.z) - Vector3(_me.global_position.x, 0, _me.global_position.z))
		var home := Vector3(_me.global_position.x, ground, _me.global_position.z) + side * lateral
		var target: Vector3
		if p < duty:
			# apoio: o pé fica onde pisou
			if not foot.get("apoio", false):
				foot["apoio"] = true
				# pisa à frente do quadril: metade do caminho que o corpo anda enquanto o pé apoia
				foot["pisou"] = home + facing * step * duty if not foot.has("indo") else foot["indo"]
				foot["pisou"].y = ground
			target = foot["pisou"]
		else:
			if foot.get("apoio", true):
				foot["apoio"] = false
				foot["saiu"] = foot.get("pisou", home - facing * step * duty)
			var s := (p - duty) / (1.0 - duty)
			var left := (1.0 - s) * (1.0 - duty) * cycle  # tempo até pisar
			var land := home + vel * left + facing * step * duty
			land.y = ground
			foot["indo"] = land
			var k := s * s * (3.0 - 2.0 * s)
			target = (foot["saiu"] as Vector3).lerp(land, k) + Vector3.UP * height * sin(PI * s)
		_feet[i] = foot
		targets.append(target)
		# quanto o quadril precisa descer para este pé alcançar
		var reach := _leg_length(sk, i) * 0.97
		var flat := Vector2(target.x - hip_world.x, target.z - hip_world.z).length()
		var need_y := sqrt(maxf(reach * reach - flat * flat, 0.0))
		hip_drop = maxf(hip_drop, (hip_world.y - target.y) - need_y)
	# o quadril: desce o que for preciso e balança a cada passo (mais baixo no meio do apoio)
	var hips := sk.find_bone(hips_bone)
	var bounce := bob * (0.5 - 0.5 * cos(phase * TAU * 2.0))
	var pose := sk.get_bone_pose_position(hips)
	var down := (maxf(hip_drop, 0.0) + bounce) * _weight
	sk.set_bone_pose_position(hips, pose - Vector3(0.0, down, 0.0))
	for i: int in 2:
		_solve(sk, i, to_sk * targets[i], facing, i)


## Fase dos passos (0..1): da animação de andar do animador, a partir de quando o pé esquerdo pisa nela.
func _phase() -> float:
	var anim := StringName(_animator.get("loco_anim"))
	var length := float(_animator.get("loco_length"))
	if length <= 0.0:
		return 0.0
	return fposmod(float(_animator.get("loco_phase")) / length - float(_animator.get("gait_strike")), 1.0)


func _active(speed: float) -> bool:
	if speed < 0.25 or _me.get("real_time") == false or not _me.is_on_floor():
		return false
	if StringName(_animator.get("_held")) != &"" or bool(_animator.get("rolling")):
		return false
	return float(_animator.get("cadence")) > 0.0


func _leg_length(sk: Skeleton3D, i: int) -> float:
	var a := sk.get_bone_global_rest(sk.find_bone(legs[i * 3])).origin
	var b := sk.get_bone_global_rest(sk.find_bone(legs[i * 3 + 1])).origin
	var c := sk.get_bone_global_rest(sk.find_bone(legs[i * 3 + 2])).origin
	return a.distance_to(b) + b.distance_to(c)


## Dois ossos: coxa e canela até o tornozelo chegar no alvo (espaço do esqueleto), joelho para a frente; o pé reto.
func _solve(sk: Skeleton3D, i: int, target: Vector3, facing_world: Vector3, _idx: int) -> void:
	var upper := sk.find_bone(legs[i * 3])
	var lower := sk.find_bone(legs[i * 3 + 1])
	var foot := sk.find_bone(legs[i * 3 + 2])
	var a := sk.get_bone_global_rest(upper).origin.distance_to(sk.get_bone_global_rest(lower).origin)
	var b := sk.get_bone_global_rest(lower).origin.distance_to(sk.get_bone_global_rest(foot).origin)
	var hip := sk.get_bone_global_pose(upper).origin
	var to := target - hip
	var d := clampf(to.length(), absf(a - b) + 0.001, (a + b) * 0.999)
	var dir := to.normalized()
	# o joelho dobra para a frente do personagem
	var fwd := (sk.global_transform.basis.inverse() * facing_world).normalized()
	var pole := (fwd - dir * fwd.dot(dir)).normalized()
	if pole.length() < 0.01:
		pole = Vector3.FORWARD
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var knee := hip + dir * (a * cos_a) + pole * (a * sqrt(maxf(1.0 - cos_a * cos_a, 0.0)))
	var ankle := hip + dir * d
	# a junta seguinte não fica no eixo do osso neste esqueleto (16° a 22° fora): mira pela posição dela
	_aim(sk, upper, (knee - hip).normalized(), sk.get_bone_rest(lower).origin.normalized())
	_aim(sk, lower, (ankle - knee).normalized(), sk.get_bone_rest(foot).origin.normalized())
	# pé: o eixo do osso (para a ponta) vai reto para a frente, no chão
	var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	_aim(sk, foot, flat, Vector3.UP)


## Gira o osso (a partir da pose de agora) para o eixo dele apontar na direção dada, misturando pelo peso.
func _aim(sk: Skeleton3D, bone: int, dir: Vector3, axis: Vector3) -> void:
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var g := pg * Basis(sk.get_bone_pose_rotation(bone))
	var now := (g * axis).normalized()
	if now.dot(dir) > 0.99999:
		return
	var turned := Basis(Quaternion(now, dir)) * g
	var q := (pg.inverse() * turned).get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(q, _weight))


func _find() -> void:
	var node: Node = get_parent()
	while node:
		if node is CharacterBody3D:
			_me = node as CharacterBody3D
			break
		node = node.get_parent()
	if _me == null:
		return
	_animator = _me.get_node_or_null("Animator")
	if _animator == null or _animator.get("cadence") == null:
		_animator = null
