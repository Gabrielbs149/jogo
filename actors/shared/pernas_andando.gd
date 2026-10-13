@tool
class_name PernasAndando
extends SkeletonModifier3D
## Golpe andando (D069): o golpe é uma animação do corpo todo, então quem atacava andando ficava com as pernas paradas,
## deslizando. Esta peça roda logo depois da animação e, enquanto o personagem golpeia e anda, põe nas pernas (e na
## altura do quadril) a caminhada, no mesmo passo em que ela estava: o tronco golpeia, as pernas seguem andando.
## As coxas são postas no rumo da caminhada mesmo com o tronco torcido pelo golpe (o pé não vira junto).
## Parado, o golpe fica inteiro (com o passo e o agachamento dele). Precisa do CombatantAnimator (walk, walk_phase).

@export var leg_bones: Array[StringName] = [&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
	&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes"]
@export var hips_bone: StringName = &"Hips"
## Golpes que ficam com o corpo todo mesmo andando (o pulo com giro: está no ar).
@export var keep_body: Array[StringName] = []

var _me: CharacterBody3D
var _animator: Node
var _player: AnimationPlayer
var _walk: Animation
var _walk_name: StringName = &""
var _bone_tracks := {}  # osso -> trilha de rotação na caminhada
var _hips_rot := -1
var _hips_pos := -1
var _weight: float = 0.0


func _process_modification_with_delta(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sk := get_skeleton()
	if sk == null:
		return
	if _animator == null:
		_find(sk)
		if _animator == null:
			return
	_weight = move_toward(_weight, 1.0 if _striding() else 0.0, delta * 8.0)
	if _weight <= 0.001 or _walk == null:
		return
	var t := fmod(float(_animator.get("walk_phase")), _walk.length)
	var hips := sk.find_bone(hips_bone)
	if hips < 0:
		return
	# altura do quadril da caminhada (com o agachamento do golpe a perna esticada entraria no chão)
	if _hips_pos >= 0:
		var walk_y := _walk.position_track_interpolate(_hips_pos, t).y * sk.motion_scale
		var now := sk.get_bone_pose_position(hips)
		sk.set_bone_pose_position(hips, now.lerp(Vector3(now.x, walk_y, now.z), _weight))
	# as coxas vão no rumo que teriam com o quadril da caminhada, não com o quadril torcido do golpe
	var parent := sk.get_bone_parent(hips)
	var above := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var walk_hips := above * Basis(_walk.rotation_track_interpolate(_hips_rot, t)) if _hips_rot >= 0 \
		else sk.get_bone_global_pose(hips).basis.orthonormalized()
	var hips_now := sk.get_bone_global_pose(hips).basis.orthonormalized()
	for bone: int in _bone_tracks:
		var q: Quaternion = _walk.rotation_track_interpolate(_bone_tracks[bone], t)
		if sk.get_bone_parent(bone) == hips:
			q = (hips_now.inverse() * walk_hips * Basis(q)).get_rotation_quaternion()
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(q, _weight))


func _find(sk: Skeleton3D) -> void:
	var node: Node = get_parent()
	while node:
		if node is CharacterBody3D:
			_me = node as CharacterBody3D
			break
		node = node.get_parent()
	if _me == null:
		return
	_animator = _me.get_node_or_null("Animator")
	if _animator == null or _animator.get("walk_phase") == null:
		_animator = null
		return
	var model := _me.get_node_or_null("Model")
	var found := model.find_children("*", "AnimationPlayer", true, false) if model else []
	if found.is_empty():
		_animator = null
		return
	_player = found[0] as AnimationPlayer
	_walk_name = StringName(_animator.get("walk"))
	if not _player.has_animation(_walk_name):
		return
	_walk = _player.get_animation(_walk_name)
	var prefix := "%GeneralSkeleton:"
	for name: StringName in leg_bones:
		var bone := sk.find_bone(name)
		var track := _walk.find_track(NodePath(prefix + name), Animation.TYPE_ROTATION_3D)
		if bone >= 0 and track >= 0:
			_bone_tracks[bone] = track
	_hips_rot = _walk.find_track(NodePath(prefix + hips_bone), Animation.TYPE_ROTATION_3D)
	_hips_pos = _walk.find_track(NodePath(prefix + hips_bone), Animation.TYPE_POSITION_3D)


## Golpeando (habilidade, no mapa) e andando.
func _striding() -> bool:
	if _me == null or not _me.is_inside_tree() or _me.get("real_time") == false:
		return false
	if not _animator.get("_one_shot") or _animator.get("_cancelable") or StringName(_animator.get("_held")) != &"":
		return false
	var now := StringName(_player.current_animation)
	if keep_body.has(now):
		return false
	if not (_animator.get("ability_animations") as Array).has(now) and not (_animator.get("combo") as Array).has(now):
		return false
	return Vector2(_me.velocity.x, _me.velocity.z).length() > 0.3
