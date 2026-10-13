extends SceneTree
## Junta as animações da Universal Animation Library 1 e 2 da Quaternius (versão Standard, CC0, D070) num arquivo
## só, já no padrão humanoide pelo retarget (mapa_ossos_ual.tres): assets/kits/quaternius/animacoes/ual.res.
## Qualquer personagem com esqueleto humanoide usa como biblioteca "ual" (ex.: "ual/Jog_Fwd_Loop").
## Os .glb originais vêm de quaternius.itch.io (universal-animation-library e -2), versão sem root motion.
## Uso: godot --headless --path . -s tools/art/extrair_animacoes_ual.gd

const SOURCES := ["res://assets/kits/quaternius/animacoes/ual1.glb", "res://assets/kits/quaternius/animacoes/ual2.glb"]
const OUT := "res://assets/kits/quaternius/animacoes/ual.res"
## As que no arquivo original terminam em "_Loop" (o import tira o sufixo do nome, mas não põe em laço).
const LOOPS := ["Crouch_Fwd", "Crouch_Idle", "Dance", "Driving", "Idle", "Idle_Talking", "Idle_Torch", "Jog_Fwd", "Jump",
	"Pistol_Idle", "Push", "Sitting_Idle", "Sitting_Talking", "Spell_Simple_Idle", "Sprint", "Swim_Fwd", "Swim_Idle",
	"Walk_Formal", "Walk", "Idle_FoldArms", "Idle_Lantern", "Idle_No", "Idle_Rail", "Idle_Shield", "Idle_TalkingPhone",
	"NinjaJump_Idle", "Slide", "TreeChopping", "Walk_Carry", "Zombie_Idle", "Zombie_Walk_Fwd", "Sword_Idle"]


func _initialize() -> void:
	var lib := AnimationLibrary.new()
	for path: String in SOURCES:
		var src := (load(path) as PackedScene).instantiate()
		var player := src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var from := player.get_animation_library("")
		for anim_name: StringName in from.get_animation_list():
			if lib.has_animation(anim_name) or String(anim_name) == "A_TPose":
				continue
			var anim := from.get_animation(anim_name).duplicate(true) as Animation
			anim.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(String(anim_name)) else Animation.LOOP_NONE
			lib.add_animation(anim_name, anim)
		src.free()
	print("animações: ", lib.get_animation_list().size(), " salvo: ", ResourceSaver.save(lib, OUT))
	quit()
