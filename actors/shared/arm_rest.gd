@tool
class_name ArmRest
extends SkeletonModifier3D
## Traz os braços para perto do corpo depois da animação. As animações do KayKit são de bonecos largos (braço aberto
## para não bater no corpo); num herói de braço pendurado, como o Tico, elas abrem demais o braço e esticam a malha.
## Gira o braço em volta do eixo da frente do personagem: o resto do braço (antebraço e mão) vai junto.

@export_range(0.0, 60.0) var angle_degrees: float = 25.0
@export var left_bone: StringName = &"LeftUpperArm"
@export var right_bone: StringName = &"RightUpperArm"
## Animações que já põem o braço do jeito certo e ficam de fora (D072): as da UAL (refeitas para o braço do Tico) e as
## feitas por pose. Trocar de uma para outra muda o peso aos poucos (sem tranco).
@export var skip_prefixes: PackedStringArray = ["ual/", "gestos/", "tico/", "atk/Crouch", "atk/Jog", "atk/Sprint", "atk/Sword_Dash", "atk/NinjaJump", "atk/Melee_Hook", "atk/Punch"]

var _player: AnimationPlayer
var _weight: float = 1.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or angle_degrees == 0.0:
		return
	if _player == null and not Engine.is_editor_hint():
		var node: Node = skeleton
		for i in 4:
			node = node.get_parent()
			if node == null:
				break
			var found := node.find_children("*", "AnimationPlayer", true, false)
			if not found.is_empty():
				_player = found[0] as AnimationPlayer
				break
	var goal := 1.0
	if _player and not skip_prefixes.is_empty():
		var now := String(_player.current_animation)
		for prefix: String in skip_prefixes:
			if now.begins_with(prefix):
				goal = 0.0
				break
	_weight = move_toward(_weight, goal, delta * 5.0)
	if _weight <= 0.001:
		return
	var angle := deg_to_rad(angle_degrees) * _weight
	# o personagem olha para +Z: a esquerda dele fica em +X; baixar o braço esquerdo é girar em -Z, o direito em +Z
	_lower(skeleton, left_bone, -angle)
	_lower(skeleton, right_bone, angle)


func _lower(skeleton: Skeleton3D, bone_name: StringName, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var parent := skeleton.get_bone_parent(bone)
	var parent_global := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var global := skeleton.get_bone_global_pose(bone)
	global.basis = Basis(Vector3.BACK, angle) * global.basis
	skeleton.set_bone_pose_rotation(bone, (parent_global.basis.inverse() * global.basis).get_rotation_quaternion())
