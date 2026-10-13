extends SceneTree
## Gestos do Tico fora da luta (D068), feitos pose a pose como os golpes (criar_golpes_tico.gd):
## - manias de quando fica parado: "Coca_cabeca", "Espreguica", "Bate_pe";
## - "Pega" (abaixa e pega do chão) e "Pensa" (mão no queixo, cabeça de lado) para examinar.
## Cada pose diz para onde apontam braço e antebraço de cada lado (fora, cima, frente, no espaço do personagem), quanto
## o tronco inclina, quanto o quadril abaixa e para onde a cabeça vira; o resto (pernas, rabo) vem da Idle.
## Salva actors/tico_lirou/gestos_tico.res (biblioteca "gestos"). Uso: godot --headless --path . -s tools/art/criar_gestos_tico.gd

const OUT := "res://actors/tico_lirou/gestos_tico.res"
const FPS := 30.0

## braços soltos (como na Idle, já com o braço perto do corpo)
const SOLTO := [Vector3(0.22, -0.96, 0.12), Vector3(0.12, -0.94, 0.3)]
## mão na cabeça (coçando): o braço sobe pelo lado, o antebraço dobra por cima da cabeça
const COCA_A := [Vector3(0.62, 0.62, 0.2), Vector3(-0.45, 0.82, 0.12)]
const COCA_B := [Vector3(0.66, 0.58, 0.16), Vector3(-0.3, 0.9, -0.05)]
## espreguiçar: os dois braços bem para cima
const ESTICA := [Vector3(0.3, 0.92, -0.05), Vector3(0.12, 0.99, -0.08)]
const ESTICA_SOBE := [Vector3(0.38, 0.88, 0.1), Vector3(0.25, 0.95, 0.05)]
## pegar do chão: braços para a frente e para baixo
const ALCANCA := [Vector3(0.18, -0.55, 0.8), Vector3(0.08, -0.75, 0.65)]
const SEGURA := [Vector3(0.2, -0.45, 0.85), Vector3(-0.15, 0.3, 0.95)]
## mão no queixo: braço para a frente, antebraço sobe até o rosto
const QUEIXO := [Vector3(0.12, -0.35, 0.93), Vector3(-0.3, 0.88, 0.35)]
## braços cruzados atrás (impaciente)
const ATRAS := [Vector3(0.25, -0.85, -0.45), Vector3(-0.35, -0.2, -0.9)]

var _sk: Skeleton3D
var _player: AnimationPlayer


func _initialize() -> void:
	var tico := (load("res://actors/tico_lirou/tico_lirou.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(tico)
	_sk = tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for child: Node in _sk.get_children():
		if child is SkeletonModifier3D:
			child.free()
	_player = tico.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	var rest := {"esq": SOLTO, "dir": SOLTO}
	var scratch := []
	scratch.append([0.0, rest])
	scratch.append([0.45, {"esq": SOLTO, "dir": COCA_A, "cabeca": Vector3(-8, -10, -12), "tronco": 2.0}])
	var t := 0.45
	for k: int in 6:
		t += 0.16
		scratch.append([t, {"esq": SOLTO, "dir": COCA_B if k % 2 == 0 else COCA_A, "cabeca": Vector3(-8, -10, -14), "tronco": 2.0}])
	scratch.append([t + 0.45, rest])
	lib.add_animation(&"Coca_cabeca", _make(scratch))
	lib.add_animation(&"Espreguica", _make([[0.0, rest],
		[0.55, {"esq": ESTICA, "dir": ESTICA, "tronco": -10.0, "baixa": -0.02, "cabeca": Vector3(0, 18, 0)}],
		[1.3, {"esq": ESTICA_SOBE, "dir": ESTICA_SOBE, "tronco": -14.0, "baixa": -0.03, "cabeca": Vector3(0, 22, 0)}],
		[1.9, {"esq": SOLTO, "dir": SOLTO, "tronco": 4.0, "cabeca": Vector3(0, -4, 0)}], [2.4, rest]]))
	var tap := [[0.0, rest], [0.35, {"esq": ATRAS, "dir": ATRAS, "cabeca": Vector3(15, -6, 0), "pe": 0.0}]]
	t = 0.35
	for k: int in 5:
		t += 0.17
		tap.append([t, {"esq": ATRAS, "dir": ATRAS, "cabeca": Vector3(15, -6, 0), "pe": 1.0 if k % 2 == 0 else 0.0}])
	tap.append([t + 0.2, {"esq": ATRAS, "dir": ATRAS, "cabeca": Vector3(-20, 4, 0), "pe": 0.0}])
	tap.append([t + 0.75, rest])
	lib.add_animation(&"Bate_pe", _make(tap))
	lib.add_animation(&"Pega", _make([[0.0, rest],
		[0.28, {"esq": ALCANCA, "dir": ALCANCA, "tronco": 30.0, "baixa": 0.12, "cabeca": Vector3(0, -20, 0)}],
		[0.42, {"esq": ALCANCA, "dir": ALCANCA, "tronco": 32.0, "baixa": 0.13, "cabeca": Vector3(0, -22, 0)}],
		[0.75, {"esq": SOLTO, "dir": SEGURA, "tronco": 4.0, "cabeca": Vector3(0, -12, 0)}],
		[1.05, rest]]))
	lib.add_animation(&"Pensa", _make([[0.0, rest],
		[0.4, {"esq": SOLTO, "dir": QUEIXO, "cabeca": Vector3(0, -6, 12), "tronco": 4.0}],
		[1.4, {"esq": SOLTO, "dir": QUEIXO, "cabeca": Vector3(4, -4, 16), "tronco": 5.0}],
		[1.8, rest]]))
	print("salvo ", ResourceSaver.save(lib, OUT))
	quit()


func _make(keys: Array) -> Animation:
	var anim := Animation.new()
	var length: float = keys[keys.size() - 1][0]
	anim.length = length
	anim.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for b: int in _sk.get_bone_count():
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%GeneralSkeleton:" + _sk.get_bone_name(b)))
		tracks[b] = t
	var hips := _sk.find_bone("Hips")
	var hips_pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_pos, NodePath("%GeneralSkeleton:Hips"))
	var frames := int(ceil(length * FPS))
	for f: int in frames + 1:
		var time := minf(f / FPS, length)
		_apply(_pose_at(keys, time), time)
		for b: int in _sk.get_bone_count():
			anim.rotation_track_insert_key(tracks[b], time, _sk.get_bone_pose_rotation(b))
		# a pose lida já vem multiplicada pelo motion_scale do esqueleto (0,3); a trilha guarda sem ele, senão o
		# quadril afunda (D068: o Tico entrava no chão ao atacar)
		anim.position_track_insert_key(hips_pos, time, _sk.get_bone_pose_position(hips) / _sk.motion_scale)
	return anim


func _pose_at(keys: Array, time: float) -> Dictionary:
	for i: int in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if time <= float(b[0]):
			var k := (time - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			k = k * k * (3.0 - 2.0 * k)
			return _mix(a[1], b[1], k)
	return keys[keys.size() - 1][1]


func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for side: String in ["esq", "dir"]:
		var arm: Array = []
		for i: int in 2:
			arm.append((a[side][i] as Vector3).normalized().slerp((b[side][i] as Vector3).normalized(), k))
		out[side] = arm
	for key: String in ["tronco", "baixa", "pe"]:
		out[key] = lerpf(float(a.get(key, 0.0)), float(b.get(key, 0.0)), k)
	out["cabeca"] = (a.get("cabeca", Vector3.ZERO) as Vector3).lerp(b.get("cabeca", Vector3.ZERO) as Vector3, k)
	return out


func _apply(pose: Dictionary, time: float) -> void:
	_player.play(&"Idle")
	_player.seek(fmod(time, _player.current_animation_length), true)
	var hips := _sk.find_bone("Hips")
	_sk.set_bone_pose_position(hips, _sk.get_bone_pose_position(hips) + Vector3(0, -float(pose["baixa"]), 0))
	var lean := deg_to_rad(float(pose["tronco"]))
	_turn(_sk.find_bone("Spine"), Basis(Vector3.RIGHT, lean * 0.45))
	_turn(_sk.find_bone("Chest"), Basis(Vector3.RIGHT, lean * 0.55))
	# quem abaixa dobra os joelhos: as coxas vão para a frente e as canelas voltam
	var crouch := clampf(float(pose["baixa"]) / 0.13, -0.3, 1.0)
	for side: String in ["Left", "Right"]:
		_turn(_sk.find_bone(side + "UpperLeg"), Basis(Vector3.RIGHT, -crouch * 0.9))
		_turn(_sk.find_bone(side + "LowerLeg"), Basis(Vector3.RIGHT, crouch * 1.5))
		_turn(_sk.find_bone(side + "Foot"), Basis(Vector3.RIGHT, -crouch * 0.6))
	# batida do pé direito: a ponta sobe
	_turn(_sk.find_bone("RightFoot"), Basis(Vector3.RIGHT, -float(pose["pe"]) * 0.45))
	# cabeça: (vira, sobe, inclina) em graus; compensa a inclinação do tronco para continuar olhando em frente
	var head: Vector3 = pose["cabeca"]
	_turn(_sk.find_bone("Head"), Basis(Vector3.UP, deg_to_rad(head.x)) * Basis(Vector3.RIGHT, deg_to_rad(-head.y) - lean * 0.7)
		* Basis(Vector3.BACK, deg_to_rad(head.z)))
	for side: String in ["Left", "Right"]:
		var upper := _sk.find_bone(side + "UpperArm")
		var lower := _sk.find_bone(side + "LowerArm")
		# o lado é pelo nome do braço (a esquerda dele é +X); pela posição do ombro, com o tronco torcido no golpe o ombro
		# ia para o meio do peito, o lado virava e o braço atravessava o corpo (D079)
		var out := 1.0 if side == "Left" else -1.0
		var dirs: Array = pose["esq" if side == "Left" else "dir"]
		_aim(upper, _to_space(dirs[0], out))
		_aim(lower, _to_space(dirs[1], out))


func _to_space(d: Vector3, out: float) -> Vector3:
	return Vector3(d.x * out, d.y, d.z).normalized()


func _turn(bone: int, rot: Basis) -> void:
	if bone < 0:
		return
	var parent := _sk.get_bone_parent(bone)
	var pg := _global(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var g := pg * Basis(_sk.get_bone_pose_rotation(bone))
	_sk.set_bone_pose_rotation(bone, (pg.inverse() * (rot * g)).get_rotation_quaternion())


func _aim(bone: int, dir: Vector3, axis: Vector3 = Vector3.UP) -> void:
	var parent := _sk.get_bone_parent(bone)
	var pg := _global(parent).basis.orthonormalized()
	var g0 := pg * _sk.get_bone_rest(bone).basis.orthonormalized()
	var now := (g0 * axis).normalized()
	var g := Basis(Quaternion(now, dir)) * g0
	_sk.set_bone_pose_rotation(bone, (pg.inverse() * g).get_rotation_quaternion())


## Pose global do osso calculada na mão (pai × pose, até a raiz). Fora do jogo o get_bone_global_pose devolve um cache
## que não acompanha as mudanças feitas aqui (D079: os braços saíam até 45° fora e atravessavam o corpo).
func _global(bone: int) -> Transform3D:
	var t := _sk.get_bone_pose(bone)
	var parent := _sk.get_bone_parent(bone)
	while parent >= 0:
		t = _sk.get_bone_pose(parent) * t
		parent = _sk.get_bone_parent(parent)
	return t
