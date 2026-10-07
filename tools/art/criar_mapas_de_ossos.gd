extends SceneTree
## Cria os mapas de ossos (BoneMap, perfil humanoide do Godot) usados no retarget (D028):
## o Godot renomeia os ossos para o padrão humanoide na importação, então as animações de um personagem
## (KayKit) tocam em outro (Tico) com outro tamanho e outras proporções.
## Uso: godot --headless --path . -s tools/art/criar_mapas_de_ossos.gd

const KAYKIT := {
	"Root": "root", "Hips": "hips", "Spine": "spine", "Chest": "chest", "Head": "head",
	"LeftUpperArm": "upperarm.l", "LeftLowerArm": "lowerarm.l", "LeftHand": "wrist.l",
	"RightUpperArm": "upperarm.r", "RightLowerArm": "lowerarm.r", "RightHand": "wrist.r",
	"LeftUpperLeg": "upperleg.l", "LeftLowerLeg": "lowerleg.l", "LeftFoot": "foot.l", "LeftToes": "toes.l",
	"RightUpperLeg": "upperleg.r", "RightLowerLeg": "lowerleg.r", "RightFoot": "foot.r", "RightToes": "toes.r",
}
const TICO := ["Root", "Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot"]

## Naumfode (D032): esqueleto que veio com o modelo (nomes no estilo do Rigify).
const NAUMFODE := {
	"Root": "root", "Hips": "hips", "Spine": "spine", "Chest": "chest", "Neck": "neck", "Head": "head",
	"LeftShoulder": "shoulder.L", "LeftUpperArm": "upper_arm.L", "LeftLowerArm": "forearm.L", "LeftHand": "hand.L",
	"RightShoulder": "shoulder.R", "RightUpperArm": "upper_arm.R", "RightLowerArm": "forearm.R", "RightHand": "hand.R",
	"LeftUpperLeg": "thigh.L", "LeftLowerLeg": "shin.L", "LeftFoot": "foot.L", "LeftToes": "toe.L",
	"RightUpperLeg": "thigh.R", "RightLowerLeg": "shin.R", "RightFoot": "foot.R", "RightToes": "toe.R",
}


func _initialize() -> void:
	var kay := BoneMap.new()
	kay.profile = SkeletonProfileHumanoid.new()
	for profile_bone: String in KAYKIT:
		kay.set_skeleton_bone_name(profile_bone, KAYKIT[profile_bone])
	print("kaykit ", ResourceSaver.save(kay, "res://assets/kits/kaykit/animacoes/mapa_ossos_kaykit.tres"))
	var tico := BoneMap.new()
	tico.profile = SkeletonProfileHumanoid.new()
	for bone: String in TICO:
		tico.set_skeleton_bone_name(bone, bone)
	print("tico ", ResourceSaver.save(tico, "res://actors/tico_lirou/mapa_ossos_tico.tres"))
	var naum := BoneMap.new()
	naum.profile = SkeletonProfileHumanoid.new()
	for profile_bone: String in NAUMFODE:
		naum.set_skeleton_bone_name(profile_bone, NAUMFODE[profile_bone])
	print("naumfode ", ResourceSaver.save(naum, "res://actors/naumfode/mapa_ossos_naumfode.tres"))
	quit()
