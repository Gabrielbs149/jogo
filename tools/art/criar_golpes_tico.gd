extends SceneTree
## Animações de luta do Tico com as adagas psíquicas (D052, refeitas na D069): "Guarda" (parado em guarda, lâminas para
## cima), o combo do mapa ("Golpe_1" corte de direita na horizontal, "Golpe_2" revés de esquerda subindo, "Golpe_3"
## pulo com giro e X na queda), e os da luta por turnos ("Corte_X", "Estocada", "Bote" = agacha para o impulso).
## As do KayKit eram de boneco de braço comprido: no Tico os braços mal mexiam e o corpo dobrava (parecia cabeçada).
## Cada golpe tem preparo (o corpo carrega para o outro lado), o golpe (rápido, com passo e torção do tronco),
## acompanhamento (o braço passa do ponto) e volta para a guarda. O rabo faz contrapeso e a cabeça fica no alvo.
##
## Pose: "esq"/"dir" (ou "braco" para os dois, espelhado) -> [braço, antebraço, lâmina], direções em (fora, cima, frente)
## no espaço do personagem (fora = para o lado daquele ombro; negativo cruza o corpo). E, todos opcionais:
## - "tronco": inclina para a frente (graus); "giro": torce o tronco (graus, + = o peito vira para a esquerda dele);
## - "quadril": quadril para a frente (m); "baixa": quadril abaixa (m; negativo = sobe, pulo, com as pernas encolhidas);
## - "passo": -1..1, um pé à frente (+ = o esquerdo, - = o direito) e o outro atrás;
## - "volta": giro do corpo todo (graus, para o giro de 360);
## - "cabeca": (vira, sobe, inclina) em graus, além da compensação automática (olha para o alvo).
## Cada chave pode dizer como chega nela: "rapido" (sai de uma vez e freia, para o golpe) ou o padrão (suave).
## O resto do corpo vem da Idle naquele instante. Salva actors/tico_lirou/golpes_tico.res (biblioteca "tico").
## Uso: godot --headless --path . -s tools/art/criar_golpes_tico.gd

const OUT := "res://actors/tico_lirou/golpes_tico.res"
## Giro da adaga na mão esquerda (o mesmo de AdagaPsiquica.GRIP_ROTATION).
const GRIP_ROTATION := Vector3(25, 0, 90)
const FPS := 30.0

## Guarda de quem luta com faca (D080): joelhos dobrados, pé esquerdo à frente, o peito virado um pouco para a direita
## (o ombro esquerdo na frente); a mão da frente (esquerda) na altura do peito, a de trás recolhida perto do queixo,
## as duas lâminas para a frente e para cima. (A antiga, simétrica de braços abertos, parecia um abraço.)
const GUARDA := {"esq": [Vector3(0.35, -0.45, 0.82), Vector3(0.05, 0.35, 0.94), Vector3(0.1, 0.55, 0.83)],
	"dir": [Vector3(0.6, -0.7, 0.35), Vector3(-0.3, 0.55, 0.78), Vector3(0.0, 0.75, 0.65)],
	"tronco": 8.0, "baixa": 0.035, "passo": 0.35, "giro": -18.0}
const GUARDA_INSPIRA := {"esq": [Vector3(0.36, -0.42, 0.83), Vector3(0.06, 0.4, 0.92), Vector3(0.1, 0.6, 0.8)],
	"dir": [Vector3(0.6, -0.68, 0.38), Vector3(-0.28, 0.6, 0.75), Vector3(0.0, 0.78, 0.62)],
	"tronco": 6.0, "baixa": 0.045, "passo": 0.35, "giro": -16.0}
## braço de guarda recolhido junto do peito (o que não está golpeando)
const RECOLHIDO := [Vector3(0.5, -0.72, 0.3), Vector3(0.35, 0.2, 0.92), Vector3(0.45, 0.5, 0.75)]  # D080: a lâmina ao lado, não na frente da cara

# ---- Combo do mapa (D079, refeito com mais corpo): preparo bem carregado, golpe rápido com giro do tronco e passo,
# braço passando do ponto. O tronco inclina no máximo ~18° (cabeça grande: mais que isso vira cabeçada, D077).

# Golpe 1: corte de direita na horizontal, da direita dele para a esquerda; pé direito à frente
const G1_PREPARA := {"esq": RECOLHIDO,
	"dir": [Vector3(0.85, 0.3, -0.45), Vector3(0.7, 0.5, -0.5), Vector3(0.25, 0.45, -0.85)],
	"giro": -55.0, "tronco": -4.0, "quadril": -0.03, "baixa": 0.05, "passo": 0.2, "cabeca": Vector3(0, 0, 4)}
# D080: no corte o braço estica para a frente e o pulso leva a lâmina adiante do corpo (antes ela ficava atravessada
# na frente da barriga e, no acompanhamento, sumia atrás dele: com o braço curto do Tico o golpe não aparecia)
const G1_CORTA := {"esq": RECOLHIDO,
	"dir": [Vector3(0.1, 0.12, 1.0), Vector3(-0.25, 0.08, 0.96), Vector3(-0.6, 0.08, 0.8)],
	"giro": 30.0, "tronco": 14.0, "quadril": 0.14, "baixa": 0.08, "passo": -0.95}
const G1_SEGUE := {"esq": RECOLHIDO,
	"dir": [Vector3(-0.45, 0.02, 0.9), Vector3(-0.8, -0.02, 0.6), Vector3(-0.8, -0.05, 0.6)],
	"giro": 55.0, "tronco": 14.0, "quadril": 0.15, "baixa": 0.08, "passo": -0.95, "cabeca": Vector3(0, 0, -4)}
const G1_SEGUE_FIM := {"esq": RECOLHIDO,
	"dir": [Vector3(-0.5, 0.0, 0.86), Vector3(-0.85, -0.05, 0.5), Vector3(-0.85, -0.1, 0.5)],
	"giro": 60.0, "tronco": 13.0, "quadril": 0.15, "baixa": 0.08, "passo": -0.95, "cabeca": Vector3(0, 0, -4)}

# Golpe 2: revés de esquerda subindo na diagonal, de baixo (à direita dele) para cima (à esquerda); pé esquerdo à frente
const G2_PREPARA := {"dir": RECOLHIDO,
	"esq": [Vector3(-0.6, -0.5, 0.6), Vector3(-0.92, -0.38, 0.1), Vector3(-0.4, -0.42, -0.81)],  # D080: a ponta não raspa o chão
	"giro": -50.0, "tronco": 16.0, "baixa": 0.09, "passo": -0.45, "cabeca": Vector3(0, -4, 0)}
const G2_CORTA := {"dir": RECOLHIDO,
	"esq": [Vector3(0.35, 0.4, 0.85), Vector3(0.5, 0.6, 0.62), Vector3(0.85, 0.5, 0.15)],
	"giro": 28.0, "tronco": 6.0, "quadril": 0.13, "baixa": 0.04, "passo": 0.95, "cabeca": Vector3(0, 6, 0)}
const G2_SEGUE := {"dir": RECOLHIDO,
	"esq": [Vector3(0.85, 0.6, 0.0), Vector3(0.6, 0.8, -0.2), Vector3(0.25, 0.92, -0.3)],
	"giro": 50.0, "tronco": 0.0, "quadril": 0.13, "baixa": 0.03, "passo": 0.95, "cabeca": Vector3(0, 10, 0)}

# Golpe 3 (final): agacha com as duas lâminas no alto atrás, sobe e desce cortando em X na frente, agachando fundo
const G3_CARREGA := {"braco": [Vector3(0.6, 0.72, -0.3), Vector3(0.35, 0.9, -0.25), Vector3(0.1, 0.75, -0.65)],
	"tronco": -10.0, "baixa": 0.1, "quadril": -0.04, "cabeca": Vector3(0, 6, 0)}
const G3_SOBE := {"braco": [Vector3(0.5, 0.85, 0.15), Vector3(0.3, 0.92, 0.25), Vector3(0.05, 0.85, 0.5)],
	"tronco": -6.0, "baixa": -0.08, "quadril": 0.03, "cabeca": Vector3(0, 8, 0)}
# D080: o X acaba com as lâminas cruzadas na frente, para baixo e para dentro (antes elas fincavam no chão)
const G3_X := {"braco": [Vector3(0.15, -0.25, 0.95), Vector3(-0.5, -0.15, 0.85), Vector3(-0.6, -0.1, 0.8)],
	"tronco": 18.0, "baixa": 0.13, "quadril": 0.16, "passo": 0.6, "cabeca": Vector3(0, -2, 0)}

# ---- Luta por turnos: Corte em X (salta e corta) e Estocada dupla (avança e estoca)
const PREPARA := {"braco": [Vector3(0.92, 0.25, 0.3), Vector3(0.75, 0.55, 0.35), Vector3(0.5, 0.85, -0.2)], "tronco": -10.0,
	"quadril": -0.03, "baixa": -0.02, "cabeca": Vector3(0, 6, 0)}
const CRUZA := {"braco": [Vector3(0.18, -0.05, 1.0), Vector3(-0.42, -0.3, 0.86), Vector3(-0.45, -0.1, 0.88)], "tronco": 22.0,
	"quadril": 0.16, "baixa": 0.1, "passo": 0.7}
const SEGUE := {"braco": [Vector3(0.42, -0.5, 0.76), Vector3(0.55, -0.32, 0.77), Vector3(0.58, 0.0, 0.82)], "tronco": 18.0,
	"quadril": 0.16, "baixa": 0.1, "passo": 0.75}
const RECOLHE := {"braco": [Vector3(0.55, -0.25, -0.35), Vector3(0.2, 0.15, 0.96), Vector3(0.08, 0.3, 0.95)], "tronco": -4.0,
	"quadril": -0.04, "giro": -18.0, "passo": -0.3}
const ESTOCA := {"braco": [Vector3(0.16, 0.0, 1.0), Vector3(0.04, 0.05, 1.0), Vector3(0.02, 0.05, 1.0)], "tronco": 18.0,
	"quadril": 0.2, "baixa": 0.08, "giro": 8.0, "passo": 1.0}
const ESTOCA_FUNDO := {"braco": [Vector3(0.12, -0.02, 1.0), Vector3(0.02, 0.02, 1.0), Vector3(0.0, 0.02, 1.0)], "tronco": 20.0,
	"quadril": 0.22, "baixa": 0.09, "giro": 4.0, "passo": 1.0}

## agacha para tomar impulso: corpo baixo e para a frente, braços para trás, lâminas para cima
const AGACHA := {"braco": [Vector3(0.62, -0.45, -0.45), Vector3(0.45, 0.2, 0.87), Vector3(0.35, 0.75, 0.55)], "tronco": 22.0,
	"quadril": -0.05, "baixa": 0.11}

const FLOATS := ["tronco", "giro", "quadril", "baixa", "passo", "volta"]

var _sk: Skeleton3D
var _player: AnimationPlayer


func _initialize() -> void:
	var tico := (load("res://actors/tico_lirou/tico_lirou.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(tico)
	_sk = tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for child: Node in _sk.get_children():
		if child is SkeletonModifier3D:
			child.free()  # sem as peças que mexem depois da animação: aqui a pose é a que está escrita
	_player = tico.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	lib.add_animation(&"Guarda", _make([[0.0, GUARDA], [0.9, GUARDA_INSPIRA], [1.8, GUARDA]], true))
	lib.add_animation(&"Golpe_1", _make([[0.0, GUARDA], [0.11, G1_PREPARA], [0.18, G1_CORTA, "rapido"],
		[0.26, G1_SEGUE, "rapido"], [0.36, G1_SEGUE_FIM], [0.6, GUARDA]], false))
	lib.add_animation(&"Golpe_2", _make([[0.0, GUARDA], [0.11, G2_PREPARA], [0.18, G2_CORTA, "rapido"],
		[0.26, G2_SEGUE, "rapido"], [0.36, G2_SEGUE], [0.62, GUARDA]], false))
	lib.add_animation(&"Golpe_3", _make([[0.0, GUARDA], [0.16, G3_CARREGA], [0.24, G3_SOBE, "rapido"], [0.32, G3_X, "rapido"],
		[0.5, G3_X], [0.82, GUARDA]], false))
	lib.add_animation(&"Corte_X", _make([[0.0, GUARDA], [0.16, PREPARA], [0.24, CRUZA, "rapido"], [0.31, SEGUE, "rapido"],
		[0.38, SEGUE], [0.62, GUARDA]], false))
	lib.add_animation(&"Bote", _make([[0.0, GUARDA], [0.14, AGACHA], [0.3, AGACHA]], false))
	lib.add_animation(&"Estocada", _make([[0.0, GUARDA], [0.14, RECOLHE], [0.22, ESTOCA, "rapido"], [0.3, ESTOCA_FUNDO],
		[0.4, ESTOCA_FUNDO], [0.66, GUARDA]], false))
	print("salvo ", ResourceSaver.save(lib, OUT))
	quit()


## A guarda depois do giro de 360: igual, mas com a volta completa (senão o corpo desgiraria de volta).
func _full_turn(pose: Dictionary) -> Dictionary:
	var p := pose.duplicate()
	p["volta"] = 360.0
	return p


## Faz a animação: amostra 30 quadros por segundo, interpolando as poses.
func _make(keys: Array, loop: bool) -> Animation:
	var anim := Animation.new()
	var length: float = keys[keys.size() - 1][0]
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for b: int in _sk.get_bone_count():
		var path := NodePath("%GeneralSkeleton:" + _sk.get_bone_name(b))
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, path)
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
			var ease: String = b[2] if b.size() > 2 else ""
			if ease == "rapido":
				k = 1.0 - pow(1.0 - k, 3.0)  # sai de uma vez e freia no fim: o golpe
			elif ease != "linear":
				k = k * k * (3.0 - 2.0 * k)
			return _mix(a[1], b[1], k)
	return keys[keys.size() - 1][1]


static func _arm(pose: Dictionary, side: String) -> Array:
	return pose[side] if pose.has(side) else pose["braco"]


func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for side: String in ["esq", "dir"]:
		var arm: Array = []
		for i: int in 3:
			arm.append((_arm(a, side)[i] as Vector3).normalized().slerp((_arm(b, side)[i] as Vector3).normalized(), k))
		out[side] = arm
	for key: String in FLOATS:
		out[key] = lerpf(float(a.get(key, 0.0)), float(b.get(key, 0.0)), k)
	out["cabeca"] = (a.get("cabeca", Vector3.ZERO) as Vector3).lerp(b.get("cabeca", Vector3.ZERO) as Vector3, k)
	return out


func _apply(pose: Dictionary, time: float) -> void:
	# o corpo todo da Idle (pernas, rabo, respiração)
	_player.play(&"Idle")
	_player.seek(fmod(time, _player.current_animation_length), true)
	var hips := _sk.find_bone("Hips")
	var step := float(pose["passo"])
	var drop := float(pose["baixa"]) + absf(step) * 0.03  # passo largo abaixa um pouco o quadril
	_sk.set_bone_pose_position(hips, _sk.get_bone_pose_position(hips) + Vector3(0, -drop, float(pose["quadril"])))
	# pernas: quem abaixa dobra os joelhos (senão os pés entram no chão); no pulo (sobe) encolhe
	var crouch := clampf(drop / 0.13, 0.0, 1.0) + clampf(-drop / 0.08, 0.0, 1.0) * 0.7
	for side: String in ["Left", "Right"]:
		_turn(_sk.find_bone(side + "UpperLeg"), Basis(Vector3.RIGHT, -crouch * 0.9))
		_turn(_sk.find_bone(side + "LowerLeg"), Basis(Vector3.RIGHT, crouch * 1.5))
		_turn(_sk.find_bone(side + "Foot"), Basis(Vector3.RIGHT, -crouch * 0.6))
	# passo: a perna da frente vai à frente e dobra; a de trás estica para trás
	if absf(step) > 0.001:
		var front := "Left" if step > 0.0 else "Right"
		var back := "Right" if step > 0.0 else "Left"
		var s := absf(step)
		_turn(_sk.find_bone(front + "UpperLeg"), Basis(Vector3.RIGHT, -s * 0.6))
		_turn(_sk.find_bone(front + "LowerLeg"), Basis(Vector3.RIGHT, s * 0.45))
		_turn(_sk.find_bone(front + "Foot"), Basis(Vector3.RIGHT, -s * 0.05))
		_turn(_sk.find_bone(back + "UpperLeg"), Basis(Vector3.RIGHT, s * 0.45))
		_turn(_sk.find_bone(back + "LowerLeg"), Basis(Vector3.RIGHT, s * 0.2))
		_turn(_sk.find_bone(back + "Foot"), Basis(Vector3.RIGHT, s * 0.35))
	# tronco: inclina e torce (o peito vira; o quadril acompanha um pouco)
	var lean := deg_to_rad(float(pose["tronco"]))
	var twist := deg_to_rad(float(pose["giro"]))
	_turn(_sk.find_bone("Spine"), Basis(Vector3.UP, twist * 0.45) * Basis(Vector3.RIGHT, lean * 0.45))
	_turn(_sk.find_bone("Chest"), Basis(Vector3.UP, twist * 0.55) * Basis(Vector3.RIGHT, lean * 0.55))
	# cabeça: compensa a inclinação e a torção (fica no alvo) e soma o que a pose pedir
	var head: Vector3 = pose["cabeca"]
	_turn(_sk.find_bone("Head"), Basis(Vector3.UP, deg_to_rad(head.x) - twist * 0.75)
		* Basis(Vector3.RIGHT, deg_to_rad(-head.y) - lean * 0.8) * Basis(Vector3.BACK, deg_to_rad(head.z)))
	# rabo: contrapeso (vai para o lado contrário da torção)
	for i: int in 3:
		_turn(_sk.find_bone("Tail%d" % (i + 1)), Basis(Vector3.UP, -twist * (0.35 + 0.15 * i)))
	# giro do corpo todo
	var spin := Basis(Vector3.UP, deg_to_rad(float(pose["volta"])))
	if float(pose["volta"]) != 0.0:
		_turn(hips, spin)
	# braços: as direções são no espaço do personagem (giram junto no giro de 360)
	for side: String in ["Left", "Right"]:
		var upper := _sk.find_bone(side + "UpperArm")
		var lower := _sk.find_bone(side + "LowerArm")
		var hand := _sk.find_bone(side + "Hand")
		# o lado é pelo nome do braço (a esquerda dele é +X); pela posição do ombro, com o tronco torcido no golpe o ombro
		# ia para o meio do peito, o lado virava e o braço atravessava o corpo (D079)
		var out := 1.0 if side == "Left" else -1.0
		var dirs: Array = pose["esq" if side == "Left" else "dir"]
		_aim(upper, spin * _to_space(dirs[0], out))
		_aim(lower, spin * _to_space(dirs[1], out))
		_sk.set_bone_pose_rotation(hand, _sk.get_bone_rest(hand).basis.get_rotation_quaternion())
		# o pulso vira para a lâmina (que sai da mão no giro da empunhadura) apontar para onde a pose pede
		# (o mesmo que AdagaPsiquica.grip_rotation: a mão direita é o espelho da esquerda, D080; o script da adaga não
		# compila aqui fora do jogo, porque usa o Audio)
		var grip := GRIP_ROTATION
		if side == "Right":
			grip = Vector3(grip.x, -grip.y, -grip.z)
		var blade := Basis.from_euler(grip * PI / 180.0) * Vector3.UP
		_aim(hand, spin * _to_space(dirs[2], out), blade)


func _to_space(d: Vector3, out: float) -> Vector3:
	return Vector3(d.x * out, d.y, d.z).normalized()


## Gira o osso (a partir da pose de agora) por uma rotação dada no espaço do personagem.
func _turn(bone: int, rot: Basis) -> void:
	if bone < 0:
		return
	var parent := _sk.get_bone_parent(bone)
	var pg := _global(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var g := pg * Basis(_sk.get_bone_pose_rotation(bone))
	_sk.set_bone_pose_rotation(bone, (pg.inverse() * (rot * g)).get_rotation_quaternion())


## Aponta o osso (o eixo dado, no espaço dele) para a direção pedida, no espaço do personagem.
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
