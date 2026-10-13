@tool
class_name Passada
extends SkeletonModifier3D
## Passo do tamanho da velocidade (D070). O Tico tem a perna curta (o quadril fica a 30 cm do chão): as animações de
## andar e correr, no tamanho dele, levariam menos de 1 m/s; mais rápido que isso o pé desliza no chão e o corpo
## parece "patinar". O animador acelera o ritmo até um limite (passinho rápido) e diz quanto ainda falta
## (stride_need); esta peça alonga o passo nessa medida: as coxas balançam mais para a frente e para trás, e o quadril
## desce o que for preciso para o pé de apoio continuar no chão (sem afundar nem flutuar).
## Vai logo depois da animação (e da PernasAndando). Precisa do CombatantAnimator.

@export var left_leg: StringName = &"LeftUpperLeg"
@export var right_leg: StringName = &"RightUpperLeg"
@export var left_foot: StringName = &"LeftFoot"
@export var right_foot: StringName = &"RightFoot"
@export var hips_bone: StringName = &"Hips"
## Até quanto o balanço da coxa pode crescer (1,3 = 30% a mais). Mais que isso o boneco abre as pernas e agacha
## (testado: 1,7 ficou feio).
@export_range(1.0, 2.5) var max_stride: float = 1.3

var _me: CharacterBody3D
var _animator: Node
var _k: float = 1.0


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
	var goal := 1.0
	var speed := Vector2(_me.velocity.x, _me.velocity.z).length()
	if speed > 0.3 and _me.get("real_time") != false and StringName(_animator.get("_held")) == &"":
		goal = clampf(float(_animator.get("stride_need")), 1.0, max_stride)
	_k = move_toward(_k, goal, delta * 3.0)
	if _k <= 1.001:
		return
	var before := _lowest_foot(sk)
	_widen(sk, left_leg, _k)
	_widen(sk, right_leg, _k)
	var after := _lowest_foot(sk)
	var hips := sk.find_bone(hips_bone)
	if hips >= 0 and is_finite(before) and is_finite(after):
		# a coxa mais aberta levanta o pé: o quadril desce o mesmo tanto (o pé de apoio fica no chão)
		var pos := sk.get_bone_pose_position(hips)
		sk.set_bone_pose_position(hips, pos - Vector3(0.0, after - before, 0.0))


## Aumenta o quanto o osso está girado em relação ao descanso dele (k = 1 não muda).
static func _widen(sk: Skeleton3D, bone_name: StringName, k: float) -> void:
	var bone := sk.find_bone(bone_name)
	if bone < 0:
		return
	var rest := sk.get_bone_rest(bone).basis.get_rotation_quaternion()
	var now := sk.get_bone_pose_rotation(bone)
	var delta := rest.inverse() * now
	var angle := delta.get_angle()
	if angle < 0.0001:
		return
	var wider := Quaternion(delta.get_axis().normalized(), wrapf(angle * k, -PI, PI))
	sk.set_bone_pose_rotation(bone, rest * wider)


func _lowest_foot(sk: Skeleton3D) -> float:
	var low := INF
	for name: StringName in [left_foot, right_foot]:
		var bone := sk.find_bone(name)
		if bone >= 0:
			low = minf(low, sk.get_bone_global_pose(bone).origin.y)
	return low


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
	if _animator == null or _animator.get("stride_need") == null:
		_animator = null
