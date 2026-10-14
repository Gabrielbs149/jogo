extends SceneTree
## Animações do Mixamo (D081) para o padrão humanoide. Os .fbx ficam em assets/kits/mixamo/fbx/ (fora do Git: a licença
## do Mixamo não deixa publicar as animações soltas e o repositório é público). Foram exportados no "Tico_para_Mixamo"
## (o próprio Tico subido no Mixamo), sem malha, 30 quadros por segundo: o movimento já vem nas proporções dele.
## Fase 1 (sem o mapa nos .import): põe o mapa de ossos (mapa_ossos_mixamo.tres) em cada .fbx.import. Depois rode
##   godot --headless --path . --import
## Fase 2: junta todas numa biblioteca (assets/kits/mixamo/fbx/mixamo.res), nomeada pelo arquivo (ninja_idle.fbx ->
##   "ninja_idle"). As guardas ficam em laço. O quadril não anda no chão (só sobe e desce): quem anda o corpo no jogo é o
##   código (golpe, esquiva); com o deslocamento da animação o boneco saía da cápsula e voltava de supetão.
## Depois: godot --headless --path . -s tools/art/retarget_ual_tico.gd -- mixamo   (braços certos no Tico)
## Uso: godot --headless --path . -s tools/art/importar_mixamo.gd

const DIR := "res://assets/kits/mixamo/fbx/"
const MAP := "res://assets/kits/mixamo/mapa_ossos_mixamo.tres"
const OUT := "res://assets/kits/mixamo/fbx/mixamo.res"
const LOOPS := ["ninja_idle", "ninja_idle_1"]


func _initialize() -> void:
	var files: Array[String] = []
	for f: String in DirAccess.get_files_at(DIR):
		if f.ends_with(".fbx"):
			files.append(f)
	if files.is_empty():
		print("nenhum .fbx em ", DIR, " (baixe do Mixamo, ver D081)")
		quit(1)
		return
	var changed := 0
	for f: String in files:
		if _configure(DIR + f + ".import"):
			changed += 1
	if changed > 0:
		print("mapa de ossos posto em ", changed, " arquivos; agora rode: godot --headless --path . --import, e de novo este")
		quit()
		return
	var lib := AnimationLibrary.new()
	for f: String in files:
		var scene := (load(DIR + f) as PackedScene).instantiate()
		var player := scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var name := f.get_basename()
		var source := player.get_animation(player.get_animation_list()[0])
		var anim := source.duplicate(true) as Animation
		anim.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(name) else Animation.LOOP_NONE
		_root_in_place(anim)
		lib.add_animation(name, anim)
		scene.free()
	print("animações: ", lib.get_animation_list().size(), " salvo: ", ResourceSaver.save(lib, OUT))
	quit()


## Põe o mapa de ossos no .import (devolve true se mudou).
func _configure(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	var subs: Dictionary = cfg.get_value("params", "_subresources", {})
	var nodes: Dictionary = subs.get("nodes", {})
	if nodes.has("PATH:Skeleton3D"):
		return false
	nodes["PATH:Skeleton3D"] = {
		"retarget/bone_map": load(MAP),
		"retarget/bone_renamer/rename_bones": true,
		"retarget/bone_renamer/unique_node/make_unique": true,
		"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",
		"retarget/remove_tracks/unmapped_bones": true,
	}
	subs["nodes"] = nodes
	cfg.set_value("params", "_subresources", subs)
	cfg.set_value("params", "animation/trimming", false)
	return cfg.save(path) == OK


## O quadril fica no lugar no chão (x e z do primeiro quadro); a altura continua a da animação.
static func _root_in_place(anim: Animation) -> void:
	var track := anim.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
	if track < 0:
		return
	var first: Vector3 = anim.track_get_key_value(track, 0)
	for k: int in anim.track_get_key_count(track):
		var v: Vector3 = anim.track_get_key_value(track, k)
		anim.track_set_key_value(track, k, Vector3(first.x, v.y, first.z))
