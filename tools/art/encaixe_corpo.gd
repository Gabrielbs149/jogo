class_name EncaixeCorpo
extends RefCounted
## Encaixe no corpo do Tico (D081), para animações feitas para outro corpo (Mixamo, UAL). O Tico tem braço curto,
## barriga e cabeça grandes e uma adaga de 42 cm em cada mão: nas animações de gente comprida o braço entrava na
## barriga e a lâmina atravessava o peito, a cabeça ou a coxa, ou fincava no chão.
## O corpo é medido na própria malha: uma elipsoide por osso (os vértices que aquele osso mais mexe, de 10% a 90%).
## Por quadro, depois que o braço já está na pose:
## 1. braço (cotovelo, meio do antebraço, mão) dentro do corpo: o braço abre para fora (em volta da frente do peito);
## 2. lâmina dentro do corpo ou no chão: o antebraço gira em volta do próprio eixo (metade nele, metade no pulso).
## Procura junto abertura e giro, o mais perto do quadro anterior (sem pular de um lado para o outro) e do original.
## Tudo no espaço do esqueleto, com as poses globais calculadas na mão (pai × pose; o cache do Skeleton3D não acompanha
## fora do jogo, D079).

const BODY := ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]
## Folga: um ponto conta como dentro se está a menos disto do meio da elipsoide (1 = na borda).
const INSIDE := 0.92
const BLADE_LENGTH := 0.42
## Da guarda para o meio do cabo, na direção da lâmina (AdagaPsiquica: o cabo fica 0,055 abaixo da guarda).
const GRIP_ANGLE := 65.0
const GRIP_OFFSET := Vector3(-0.05, 0.023, 0.0)

var _sk: Skeleton3D
var _ell := {}  # osso -> [centro, meio-eixos] no espaço do osso
var _ground: float = 0.0
var daggers: bool = true
## O giro e a abertura do quadro anterior, por lado: o próximo quadro começa deles. Sem isso um quadro girava para um
## lado e o seguinte para o outro, e entre os dois (na interpolação) a lâmina atravessava a cabeça.
var _prev := {"Left": [0.0, 0.0], "Right": [0.0, 0.0]}
var _first := true
## O máximo que o giro e a abertura mudam de um quadro para o outro (graus): mais que isso o braço dava um tranco
## (um pulo de um quadro). Melhor a lâmina raspar um instante do que o braço saltar.
const MAX_TWIST_STEP := 30.0
const MAX_OPEN_STEP := 8.0


## Começo de outra animação: esquece o quadro anterior.
func reset() -> void:
	_prev = {"Left": [0.0, 0.0], "Right": [0.0, 0.0]}
	_first = true


func _init(skeleton: Skeleton3D, mesh_owner: Node) -> void:
	_sk = skeleton
	_fit(mesh_owner)
	var lowest := INF
	for name: String in ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
		var b := _sk.find_bone(name)
		if b >= 0:
			lowest = minf(lowest, _sk.get_bone_global_rest(b).origin.y)
	_ground = (lowest - 0.03) if lowest < INF else 0.0


## Arruma os dois braços na pose de agora. Devolve quantos ajustes fez.
func fit() -> int:
	var fixes := 0
	for side: String in ["Left", "Right"]:
		var out := 1.0 if side == "Left" else -1.0
		var upper := _sk.find_bone(side + "UpperArm")
		var lower := _sk.find_bone(side + "LowerArm")
		var hand := _sk.find_bone(side + "Hand")
		if upper < 0 or lower < 0 or hand < 0:
			continue
		var keep := [_sk.get_bone_pose_rotation(upper), _sk.get_bone_pose_rotation(lower), _sk.get_bone_pose_rotation(hand)]
		var prev: Array = _prev[side]
		# melhor: o mais perto do quadro anterior que deixa tudo limpo; procura abertura e giro em volta dele
		var best := [INF, 0.0, 0.0]
		for open_deg: float in [0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0]:
			for step: int in range(-24, 25):
				var twist := float(prev[1]) + deg_to_rad(7.5 * step)
				if absf(twist) > deg_to_rad(150.0):
					continue
				if not _first and (absf(twist - float(prev[1])) > deg_to_rad(MAX_TWIST_STEP) + 0.001
						or absf(open_deg - float(prev[0])) > MAX_OPEN_STEP + 0.001):
					continue
				_sk.set_bone_pose_rotation(upper, keep[0])
				_sk.set_bone_pose_rotation(lower, keep[1])
				_sk.set_bone_pose_rotation(hand, keep[2])
				_open(upper, out, open_deg)
				_twist(lower, hand, twist)
				var bad := (1.0 if _arm_inside(side, upper, lower, hand) else 0.0) + (_blade_bad(side, hand) if daggers else 0.0)
				# custo: o que ainda entra pesa muito; depois, mudar do quadro anterior e se afastar do original
				var cost := bad * 100.0 + absf(twist - float(prev[1])) * 0.6 + absf(twist) * 0.2 					+ absf(open_deg - float(prev[0])) * 0.02 + open_deg * 0.01
				if cost < best[0]:
					best = [cost, open_deg, twist]
		_sk.set_bone_pose_rotation(upper, keep[0])
		_sk.set_bone_pose_rotation(lower, keep[1])
		_sk.set_bone_pose_rotation(hand, keep[2])
		_open(upper, out, best[1])
		_twist(lower, hand, best[2])
		if best[1] != 0.0 or best[2] != 0.0:
			fixes += 1
		_prev[side] = [best[1], best[2]]
	_first = false
	return fixes


## Quanto a lâmina está errada agora (0 = nada): o mais fundo que entra no corpo + o quanto a ponta passa do chão.
func _blade_bad(side: String, hand: int) -> float:
	var g := _global(hand)
	var grip := Transform3D(_grip_basis(side), GRIP_OFFSET * Vector3(1.0 if side == "Left" else -1.0, 1, 1))
	var t := g * grip
	var worst := 0.0
	for k: int in 7:
		var p := t * Vector3(0, 0.06 + (BLADE_LENGTH - 0.06) * k / 6.0, 0)
		worst = maxf(worst, _depth(p, side + "Hand"))
	var tip := t * Vector3(0, BLADE_LENGTH, 0)
	worst += maxf(0.0, (_ground + 0.03) - tip.y) * 4.0
	return worst


func _twist(lower: int, hand: int, angle: float) -> void:
	var axis := (_global(lower).basis.orthonormalized() * Vector3.UP).normalized()
	_turn(lower, Basis(axis, angle * 0.5))
	_turn(hand, Basis(axis, angle * 0.5))


## Algum ponto do braço (cotovelo, meio do antebraço, mão) dentro do corpo?
func _arm_inside(side: String, upper: int, lower: int, hand: int) -> bool:
	var elbow := _global(lower).origin
	var wrist := _global(hand).origin
	for p: Vector3 in [elbow, elbow.lerp(wrist, 0.5), wrist]:
		if _depth(p, side) > 0.0:
			return true
	return false


## Abre o braço (gira em volta da frente do peito, para fora), em graus.
func _open(upper: int, out: float, degrees: float) -> void:
	var chest := _global(_sk.find_bone("Chest")).basis.orthonormalized()
	var forward := (chest * Vector3.BACK).normalized()  # o Tico olha para +Z
	# para fora = a esquerda (+X) gira em -Z (como no ArmRest)
	_turn(upper, Basis(forward, -deg_to_rad(degrees) * out))


## Quanto o ponto entra no corpo (0 = fora; 1 = no meio). Ignora os ossos do próprio braço.
func _depth(p: Vector3, _side: String) -> float:
	var best := 0.0
	for b: String in _ell:
		var bone := _sk.find_bone(b)
		var local := _global(bone).affine_inverse() * p
		var e: Array = _ell[b]
		var d := ((local - (e[0] as Vector3)) / (e[1] as Vector3)).length()
		if d < INSIDE:
			best = maxf(best, INSIDE - d)
	return best


static func _grip_basis(side: String) -> Basis:
	var left := side == "Left"
	return Basis(Vector3.BACK, deg_to_rad(GRIP_ANGLE if left else -GRIP_ANGLE))


func _turn(bone: int, rot: Basis) -> void:
	var parent := _sk.get_bone_parent(bone)
	var pg := _global(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var g := pg * Basis(_sk.get_bone_pose_rotation(bone))
	_sk.set_bone_pose_rotation(bone, (pg.inverse() * (rot * g)).get_rotation_quaternion())


func _global(bone: int) -> Transform3D:
	var t := _sk.get_bone_pose(bone)
	var parent := _sk.get_bone_parent(bone)
	while parent >= 0:
		t = _sk.get_bone_pose(parent) * t
		parent = _sk.get_bone_parent(parent)
	return t


## As elipsoides do corpo, da malha.
func _fit(mesh_owner: Node) -> void:
	var pts := {}
	for b: String in BODY:
		pts[b] = [[], [], []]
	for mi: MeshInstance3D in mesh_owner.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null or mi.get_node_or_null(mi.skeleton) != _sk:
			continue
		var skin := mi.skin
		for s: int in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			for v: int in verts.size():
				var best := 0
				for k: int in per:
					if weights[v * per + k] > weights[v * per + best]:
						best = k
				var bind := bones[v * per + best]
				var name := String(skin.get_bind_name(bind))
				if not pts.has(name):
					continue
				var local := skin.get_bind_pose(bind) * verts[v]
				for a: int in 3:
					(pts[name][a] as Array).append(local[a])
	for b: String in BODY:
		var c := Vector3.ZERO
		var r := Vector3.ZERO
		for a: int in 3:
			var arr: Array = pts[b][a]
			if arr.size() < 10:
				continue
			arr.sort()
			var lo: float = arr[int(arr.size() * 0.1)]
			var hi: float = arr[int(arr.size() * 0.9)]
			c[a] = (lo + hi) * 0.5
			r[a] = maxf((hi - lo) * 0.5, 0.01)
		if r != Vector3.ZERO:
			_ell[b] = [c, r]
