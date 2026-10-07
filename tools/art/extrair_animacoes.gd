extends SceneTree
## Salva as animações do KayKit (já no padrão humanoide pelo retarget, D028) num arquivo próprio,
## para qualquer personagem com esqueleto humanoide usar: assets/kits/kaykit/animacoes/humanoide.res
## Uso: godot --headless --path . -s tools/art/extrair_animacoes.gd


func _initialize() -> void:
	var src := (load("res://assets/kits/kaykit/animacoes/kaykit_animacoes.glb") as PackedScene).instantiate()
	var player := src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
	for anim_name: StringName in lib.get_animation_list():
		var anim := lib.get_animation(anim_name)
		if String(anim_name).contains("Idle") or String(anim_name).begins_with("Walking") or String(anim_name).begins_with("Running") \
				or String(anim_name) in ["Blocking", "Spellcasting", "Lie_Idle", "Sit_Chair_Idle", "Sit_Floor_Idle"]:
			anim.loop_mode = Animation.LOOP_LINEAR
	print("animações: ", lib.get_animation_list().size(), " salvo: ", ResourceSaver.save(lib, "res://assets/kits/kaykit/animacoes/humanoide.res"))
	src.free()
	quit()
