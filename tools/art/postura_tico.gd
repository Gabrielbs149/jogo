extends SceneTree
## Golpes sem "cabeçada" (D077). Os golpes prontos (KayKit, UAL) dobram o tronco para a frente; no Tico, de cabeça enorme,
## isso vira uma cabeçada. Aqui cada quadro do golpe é tocado no esqueleto do Tico e:
## - o tronco (Spine/Chest) inclina no máximo TRONCO_MAX graus para a frente (o excesso é desfeito no Spine);
## - a cabeça inclina no máximo CABECA_MAX graus para baixo (em relação à vertical);
## - os braços (braço, antebraço, mão) ficam com a MESMA orientação no mundo que tinham: as adagas fazem o mesmo corte.
## "clip@graus" usa outro limite para o tronco (D080: andar agachado da UAL mergulhava 53°, a cabeça grande do Tico
## ia na frente do corpo; agachado fica no máximo 25°; o trote e a corrida, 29° e 33°, ficam em 18° e 22°). Pernas, quadril e rabo ficam como no original. Salva actors/tico_lirou/ataques_tico.res (biblioteca "atk"; mesmos nomes).
## Uso: godot --headless --path . -s tools/art/postura_tico.gd

const OUT := "res://actors/tico_lirou/ataques_tico.res"
const CLIPS := ["Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Stab",
	"2H_Melee_Attack_Spinning", "ual/Sword_Dash", "ual/NinjaJump_Start", "ual/Melee_Hook", "ual/Punch_Jab", "ual/Punch_Cross",
	"ual/Crouch_Fwd@25", "ual/Crouch_Idle@25", "ual/Jog_Fwd@18", "ual/Sprint@22"]
const FPS := 30.0
const TRONCO_MAX := 10.0
const CABECA_MAX := 12.0
const ARM := ["UpperArm", "LowerArm", "Hand"]

var _sk: Skeleton3D
var _player: AnimationPlayer
var _trunk_max: float = TRONCO_MAX


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tico := (load("res://actors/tico_lirou/tico_lirou.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(tico)
	_sk = tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for child: Node in _sk.get_children():
		if child is SkeletonModifier3D:
			child.free()
	_player = tico.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await process_frame
	var lib := AnimationLibrary.new()
	for spec: String in CLIPS:
		var clip := spec.split("@")[0]
		_trunk_max = float(spec.split("@")[1]) if spec.contains("@") else TRONCO_MAX
		if not _player.has_animation(clip):
			push_warning("sem " + clip)
			continue
		var name := clip.get_file() if not clip.contains("/") else clip.split("/")[1]
		var before := _worst_lean(clip)
		var anim := _bake(clip)
		lib.add_animation(name, anim)
		print("%-32s tronco/cabeça antes: %.0f°/%.0f°" % [clip, before.x, before.y])
	print("salvo ", ResourceSaver.save(lib, OUT))
	quit()


func _bake(clip: String) -> Animation:
	var source := _player.get_animation(clip)
	var anim := Animation.new()
	anim.length = source.length
	anim.loop_mode = source.loop_mode
	var tracks := {}
	for b: int in _sk.get_bone_count():
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%GeneralSkeleton:" + _sk.get_bone_name(b)))
		tracks[b] = t
	var hips := _sk.find_bone("Hips")
	var hips_pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_pos, NodePath("%GeneralSkeleton:Hips"))
	_player.play(clip)
	var frames := maxi(1, int(ceil(source.length * FPS)))
	for f: int in frames + 1:
		var time := minf(f / FPS, source.length)
		_player.seek(time, true)
		_fix_pose()
		for b: int in _sk.get_bone_count():
			anim.rotation_track_insert_key(tracks[b], time, _sk.get_bone_pose_rotation(b))
		anim.position_track_insert_key(hips_pos, time, _sk.get_bone_pose_position(hips) / _sk.motion_scale)
	return anim


func _fix_pose() -> void:
	# os braços como estão no mundo (antes de mexer no tronco)
	var arms := {}
	for side: String in ["Left", "Right"]:
		for part: String in ARM:
			var bone := _sk.find_bone(side + part)
			arms[bone] = _global(bone).basis.orthonormalized()
	# tronco: o "para cima" do peito inclina no máximo TRONCO_MAX para a frente (+Z do esqueleto)
	var chest := _sk.find_bone("Chest")
	var up := _global(chest).basis.orthonormalized() * Vector3.UP
	var fix := _limit(up, _trunk_max)
	if fix != Basis():
		_turn(_sk.find_bone("Spine"), fix)
	# cabeça: no máximo CABECA_MAX para baixo
	var head := _sk.find_bone("Head")
	var head_up := _global(head).basis.orthonormalized() * Vector3.UP
	var head_fix := _limit(head_up, CABECA_MAX)
	if head_fix != Basis():
		_turn(head, head_fix)
	# braços de volta para onde estavam no mundo, do ombro para a mão
	for side: String in ["Left", "Right"]:
		for part: String in ARM:
			var bone := _sk.find_bone(side + part)
			var parent := _global(_sk.get_bone_parent(bone)).basis.orthonormalized()
			_sk.set_bone_pose_rotation(bone, (parent.inverse() * (arms[bone] as Basis)).get_rotation_quaternion())


## Rotação que traz o vetor "para cima" de volta até inclinar no máximo `limit` graus para a frente (0 se já está).
static func _limit(up: Vector3, limit: float) -> Basis:
	var yz := Vector2(up.z, up.y)
	var lean := rad_to_deg(atan2(up.z, up.y))
	if lean <= limit:
		return Basis()
	var length := yz.length()
	var want := Vector3(up.x, cos(deg_to_rad(limit)) * length, sin(deg_to_rad(limit)) * length).normalized()
	return Basis(Quaternion(up.normalized(), want))


func _turn(bone: int, rot: Basis) -> void:
	var parent := _sk.get_bone_parent(bone)
	var pg := _global(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var g := pg * Basis(_sk.get_bone_pose_rotation(bone))
	_sk.set_bone_pose_rotation(bone, (pg.inverse() * (rot * g)).get_rotation_quaternion())


## O pior mergulho do tronco e da cabeça no golpe original (graus para a frente).
func _worst_lean(clip: String) -> Vector2:
	_player.play(clip)
	var length := _player.current_animation_length
	var worst := Vector2(-90, -90)
	for k: int in 30:
		_player.seek(length * k / 29.0, true)
		var up := _global(_sk.find_bone("Chest")).basis.orthonormalized() * Vector3.UP
		var hu := _global(_sk.find_bone("Head")).basis.orthonormalized() * Vector3.UP
		worst = Vector2(maxf(worst.x, rad_to_deg(atan2(up.z, up.y))), maxf(worst.y, rad_to_deg(atan2(hu.z, hu.y))))
	return worst


## Pose global do osso calculada na mão (pai × pose, até a raiz). Fora do jogo o get_bone_global_pose devolve um cache
## que não acompanha as mudanças feitas aqui (D079: os braços saíam até 45° fora e atravessavam o corpo).
func _global(bone: int) -> Transform3D:
	var t := _sk.get_bone_pose(bone)
	var parent := _sk.get_bone_parent(bone)
	while parent >= 0:
		t = _sk.get_bone_pose(parent) * t
		parent = _sk.get_bone_parent(parent)
	return t
