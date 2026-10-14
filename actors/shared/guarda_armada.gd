@tool
class_name GuardaArmada
extends SkeletonModifier3D
## De armas na mão (D080). As animações de andar e trotar são de mãos vazias: os braços balançam soltos e, com uma adaga
## em cada mão, as lâminas iam para todo lado (uma cruzando a barriga, a outra para cima). Enquanto o animador diz que
## está armado (CombatantAnimator.armed), esta peça põe os braços na pose da guarda (guard_anim) e deixa só um pouco
## (swing) do balanço do andar: as pernas, o quadril e o tronco continuam os do andar, os braços seguram as armas.
## Golpeando, rolando ou numa cena, os braços são os da animação. Entra e sai aos poucos.

@export var guard_anim: StringName = &"tico/Guarda"
@export var arm_bones: Array[StringName] = [&"LeftUpperArm", &"LeftLowerArm", &"LeftHand",
	&"RightUpperArm", &"RightLowerArm", &"RightHand"]
## Quanto do balanço dos braços do andar fica (0 = braços parados na guarda).
@export_range(0.0, 1.0) var swing: float = 0.2

var _me: CharacterBody3D
var _animator: Node
var _player: AnimationPlayer
var _tracks := {}  # osso -> trilha na guard_anim
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
	var on := _wanted()
	_weight = move_toward(_weight, 1.0 if on else 0.0, delta * (5.0 if on else 4.0))
	if _weight <= 0.001:
		return
	var anim := _player.get_animation(guard_anim)
	var t := fmod(Time.get_ticks_msec() / 1000.0, anim.length)
	var amount := _weight * (1.0 - swing)
	for bone: int in _tracks:
		var q := anim.rotation_track_interpolate(int(_tracks[bone]), t)
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone).slerp(q, amount))


## Armado, em pé ou andando, sem golpe, rolagem ou cena tocando.
func _wanted() -> bool:
	if not bool(_animator.get("armed")) or _me.get("real_time") == false:
		return false
	if bool(_animator.get("_one_shot")) or bool(_animator.get("rolling")) or StringName(_animator.get("_held")) != &"":
		return false
	return true


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
	var model := _me.get_node_or_null("Model")
	var found := model.find_children("*", "AnimationPlayer", true, false) if model else []
	if _animator == null or _animator.get("armed") == null or found.is_empty():
		_animator = null
		return
	_player = found[0] as AnimationPlayer
	if not _player.has_animation(guard_anim):
		_animator = null
		return
	var anim := _player.get_animation(guard_anim)
	for name: StringName in arm_bones:
		var bone := sk.find_bone(name)
		var track := anim.find_track(NodePath("%GeneralSkeleton:" + name), Animation.TYPE_ROTATION_3D)
		if bone >= 0 and track >= 0:
			_tracks[bone] = track
