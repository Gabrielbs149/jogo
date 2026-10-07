@tool
class_name ArmRest
extends SkeletonModifier3D
## Traz os braços para perto do corpo depois da animação. As animações do KayKit são de bonecos largos (braço aberto
## para não bater no corpo); num herói de braço pendurado, como o Tico, elas abrem demais o braço e esticam a malha.
## Gira o braço em volta do eixo da frente do personagem: o resto do braço (antebraço e mão) vai junto.

@export_range(0.0, 60.0) var angle_degrees: float = 25.0
@export var left_bone: StringName = &"LeftUpperArm"
@export var right_bone: StringName = &"RightUpperArm"


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or angle_degrees == 0.0:
		return
	var angle := deg_to_rad(angle_degrees)
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
