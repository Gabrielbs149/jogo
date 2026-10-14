extends SceneTree
## Animações da UAL (D070) no Tico com os braços certos (D072). O esqueleto da UAL tem clavícula (LeftShoulder) e o do
## Tico não: no retarget comum o giro da clavícula se perde e o braço do Tico ficava esticado para a frente, parado no
## ar. Aqui cada quadro de cada animação é tocado nos dois esqueletos e os ossos do braço (braço, antebraço, mão) do Tico
## recebem a MESMA orientação no espaço do corpo que os do esqueleto da UAL (os dois têm a pose de descanso com os
## mesmos eixos, pelo perfil humanoide). O resto do corpo fica como no retarget.
## Depois um ajuste para o corpo redondo dele: o braço nunca entra na barriga (abre para fora o que precisar).
## Salva actors/tico_lirou/ual_tico.res (biblioteca "ual" do Tico).
## Com "-- mixamo" faz o mesmo com as do Mixamo (D081): assets/kits/mixamo/fbx/*.fbx -> actors/tico_lirou/mixamo_tico.res
## (biblioteca "mix"; fora do Git, ver importar_mixamo.gd).
## Uso: godot --headless --path . -s tools/art/retarget_ual_tico.gd [-- mixamo]   (depois do extrair_animacoes_ual.gd
## ou do importar_mixamo.gd)

const UAL := {"sources": ["res://assets/kits/quaternius/animacoes/ual1.glb", "res://assets/kits/quaternius/animacoes/ual2.glb"],
	"lib": "res://assets/kits/quaternius/animacoes/ual.res", "out": "res://actors/tico_lirou/ual_tico.res", "prefix": "ual"}
const MIXAMO := {"dir": "res://assets/kits/mixamo/fbx/", "lib": "res://assets/kits/mixamo/fbx/mixamo.res",
	"out": "res://actors/tico_lirou/mixamo_tico.res", "prefix": "mix"}
const FPS := 30.0
const ARM := ["UpperArm", "LowerArm", "Hand"]
## O braço (do ombro ao cotovelo) aponta pelo menos isto para fora do corpo (seno do ângulo com o plano do meio).
const MIN_OUT := 0.32
## A cabeça do Tico é enorme: no golpe com o corpo todo inclinado ela "mergulhava" para o chão. Olha no máximo isto
## (graus) para baixo; o resto o tronco faz.
const HEAD_DOWN_MAX := 25.0

var _tico: Skeleton3D
var _tico_player: AnimationPlayer
## Encaixe no corpo (D081): braço e lâmina não entram no corpo nem no chão. Ligado nas do Mixamo (e com "-- encaixe").
var _fit: EncaixeCorpo
var _fixes: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tico := (load("res://actors/tico_lirou/tico_lirou.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(tico)
	_tico = tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for child: Node in _tico.get_children():
		if child is SkeletonModifier3D:
			child.free()
	_tico_player = tico.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_tico_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mode: Dictionary = MIXAMO if OS.get_cmdline_user_args().has("mixamo") else UAL
	if mode == MIXAMO or OS.get_cmdline_user_args().has("encaixe"):
		_fit = EncaixeCorpo.new(_tico, tico)
	var lib := (load(String(mode["lib"])) as AnimationLibrary).duplicate(true) as AnimationLibrary
	if not _tico_player.has_animation_library(String(mode["prefix"])):
		_tico_player.add_animation_library(String(mode["prefix"]), lib)
	# de onde vem cada animação: [player, esqueleto, nome lá]
	var origin := {}
	var paths: Array = mode.get("sources", [])
	if mode.has("dir"):
		paths = []
		for f: String in DirAccess.get_files_at(String(mode["dir"])):
			if f.ends_with(".fbx"):
				paths.append(String(mode["dir"]) + f)
	for path: String in paths:
		var src := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(src)
		var player := src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var skeleton := src.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		if mode.has("dir"):
			origin[StringName(path.get_file().get_basename())] = [player, skeleton, player.get_animation_list()[0]]
		else:
			for n: StringName in player.get_animation_list():
				if not origin.has(n):
					origin[n] = [player, skeleton, n]
	await process_frame
	var done := 0
	for anim_name: StringName in lib.get_animation_list():
		if not origin.has(anim_name):
			continue
		var o: Array = origin[anim_name]
		_redo_arms(lib.get_animation(anim_name), String(mode["prefix"]) + "/" + String(anim_name), o[0], o[1], o[2])
		done += 1
	print("ajustes do encaixe no corpo: ", _fixes)
	print("animações com braço refeito: ", done, " salvo: ", ResourceSaver.save(lib, String(mode["out"])))
	quit()


func _redo_arms(anim: Animation, tico_anim: String, src_player: AnimationPlayer, src: Skeleton3D, src_anim: StringName) -> void:
	# primeiro tira todas as trilhas velhas do braço, depois cria as novas (tirar uma trilha muda o número das outras)
	for side: String in ["Left", "Right"]:
		for part: String in ARM:
			var old := anim.find_track(NodePath("%GeneralSkeleton:" + side + part), Animation.TYPE_ROTATION_3D)
			if old >= 0:
				anim.remove_track(old)
	var head_old := anim.find_track(NodePath("%GeneralSkeleton:Head"), Animation.TYPE_ROTATION_3D)
	if head_old >= 0:
		anim.remove_track(head_old)
	var tracks := {}
	for side: String in ["Left", "Right"]:
		for part: String in ARM:
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%GeneralSkeleton:" + side + part))
			tracks[side + part] = t
	var head_track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(head_track, NodePath("%GeneralSkeleton:Head"))
	src_player.play(src_anim)
	_tico_player.play(tico_anim)
	if _fit:
		_fit.reset()
	var fps := FPS * (2.0 if _fit else 1.0)  # com o encaixe, 60 por s: entre dois quadros a lâmina não cruza o corpo
	var frames := maxi(1, int(ceil(anim.length * fps)))
	for f: int in frames + 1:
		var time := minf(f / fps, anim.length)
		src_player.seek(time, true)
		_tico_player.seek(time, true)
		src.force_update_all_bone_transforms()
		_tico.force_update_all_bone_transforms()
		for side: String in ["Left", "Right"]:
			var out_sign := 1.0 if side == "Left" else -1.0
			for part: String in ARM:
				var bone := side + part
				var b := _tico.find_bone(bone)
				var sb := src.find_bone(bone)
				if b < 0 or sb < 0:
					continue
				var want := _global_of(src, sb).basis.orthonormalized()
				if part == "UpperArm":
					want = _keep_out(want, out_sign)
				var parent := _global_of(_tico, _tico.get_bone_parent(b)).basis.orthonormalized()
				_tico.set_bone_pose_rotation(b, (parent.inverse() * want).get_rotation_quaternion())
				anim.rotation_track_insert_key(tracks[bone], time, _tico.get_bone_pose_rotation(b))
		var head := _tico.find_bone("Head")
		var sh := src.find_bone("Head")
		if head >= 0 and sh >= 0:
			var want := _global_of(src, sh).basis.orthonormalized()
			var face := want * Vector3.BACK  # a frente do rosto
			var limit := -sin(deg_to_rad(HEAD_DOWN_MAX))
			if face.y < limit:
				var flat := Vector3(face.x, 0.0, face.z).normalized()
				var target := (flat * cos(deg_to_rad(HEAD_DOWN_MAX)) + Vector3.DOWN * sin(deg_to_rad(HEAD_DOWN_MAX))).normalized()
				want = Basis(Quaternion(face.normalized(), target)) * want
			var hp := _global_of(_tico, _tico.get_bone_parent(head)).basis.orthonormalized()
			_tico.set_bone_pose_rotation(head, (hp.inverse() * want).get_rotation_quaternion())
			anim.rotation_track_insert_key(head_track, time, _tico.get_bone_pose_rotation(head))
		if _fit:
			_fixes += _fit.fit()
			for bone: String in tracks:
				anim.rotation_track_insert_key(tracks[bone], time, _tico.get_bone_pose_rotation(_tico.find_bone(bone)))


## O braço do Tico não entra na barriga: se aponta para dentro do corpo, gira (em volta da frente) até sair.
static func _keep_out(basis: Basis, out_sign: float) -> Basis:
	var dir := basis * Vector3.UP
	var out := dir.x * out_sign
	if out >= MIN_OUT:
		return basis
	# gira em volta do eixo da frente do corpo (Z) o que falta para o braço chegar ao mínimo para fora
	var flat := Vector2(dir.x * out_sign, dir.y)
	var now := atan2(flat.x, -flat.y)  # 0 = pendurado reto para baixo, + = abrindo para fora
	var need := asin(MIN_OUT / maxf(Vector2(dir.x, dir.y).length(), 0.001)) if Vector2(dir.x, dir.y).length() > MIN_OUT else PI / 2.0
	# braço levantado (golpe, espreguiçar) fica como está; perto da horizontal a correção some aos poucos (D081: ela
	# desligava de uma vez quando o braço passava da horizontal e o braço dava um pulo de um quadro)
	var fade := clampf((0.15 - dir.y) / 0.3, 0.0, 1.0)
	if fade <= 0.0:
		return basis
	var delta := (need - now) * out_sign * fade
	return Basis(Vector3.BACK, delta) * basis


## Pose global calculada na mão (pai × pose). Fora do jogo o get_bone_global_pose devolve um cache que não acompanha as
## mudanças feitas aqui (D079).
static func _global_of(sk: Skeleton3D, bone: int) -> Transform3D:
	var t := sk.get_bone_pose(bone)
	var parent := sk.get_bone_parent(bone)
	while parent >= 0:
		t = sk.get_bone_pose(parent) * t
		parent = sk.get_bone_parent(parent)
	return t
