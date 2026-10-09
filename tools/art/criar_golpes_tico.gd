extends SceneTree
## Animações de luta do Tico com as adagas psíquicas (D052): "Guarda" (parado em guarda, lâminas para cima, como no
## desenho), "Corte_X" (puxa as duas adagas para trás e para cima e corta cruzando um X na frente) e "Estocada"
## (recolhe e estoca as duas para a frente). As do KayKit eram de boneco de braço comprido: no Tico os braços mal
## mexiam e o corpo dobrava (parecia cabeçada).
## Cada pose diz para onde apontam braço e antebraço (fora, cima, frente, no espaço do personagem) e quanto o tronco
## inclina; o resto do corpo (pernas, respiração, rabo) vem da animação Idle naquele instante.
## Salva actors/tico_lirou/golpes_tico.res (biblioteca "tico"). Uso: godot --headless --path . -s tools/art/criar_golpes_tico.gd

const OUT := "res://actors/tico_lirou/golpes_tico.res"
const FPS := 30.0

## Poses: braço -> [direção do braço, direção do antebraço, direção da lâmina] em (fora, cima, frente); "tronco":
## inclinação (graus, + = para a frente); "quadril": quanto o quadril vai para a frente (m). A lâmina é virada pelo pulso.
## (D054, revisto quadro a quadro) "baixa": quanto o quadril abaixa (m), para agachar no impacto.
const GUARDA := {"braco": [Vector3(0.5, -0.6, 0.45), Vector3(0.3, 0.05, 0.95), Vector3(0.3, 0.45, 0.85)], "tronco": 6.0}
const GUARDA_INSPIRA := {"braco": [Vector3(0.52, -0.55, 0.47), Vector3(0.32, 0.1, 0.93), Vector3(0.32, 0.5, 0.82)], "tronco": 4.0}
## preparo: os dois braços abertos e para cima, ao lado do corpo (nada atrás da cabeça), lâminas para trás
const PREPARA := {"braco": [Vector3(0.92, 0.2, 0.35), Vector3(0.8, 0.45, 0.4), Vector3(0.55, 0.8, -0.2)], "tronco": -6.0,
	"quadril": -0.02}
## o X: os braços vêm para a frente e cruzam NA FRENTE do peito; lâminas para a frente e cruzadas (bem visíveis)
const CRUZA := {"braco": [Vector3(0.18, -0.05, 1.0), Vector3(-0.42, -0.3, 0.86), Vector3(-0.45, -0.1, 0.88)], "tronco": 16.0,
	"quadril": 0.16, "baixa": 0.06}
## continuação curta: os braços abrem para fora na frente, lâminas para fora (não para o chão)
const SEGUE := {"braco": [Vector3(0.42, -0.5, 0.76), Vector3(0.55, -0.32, 0.77), Vector3(0.58, 0.0, 0.82)], "tronco": 12.0,
	"quadril": 0.14, "baixa": 0.05}
const RECOLHE := {"braco": [Vector3(0.55, -0.25, -0.35), Vector3(0.2, 0.15, 0.96), Vector3(0.08, 0.3, 0.95)], "tronco": -4.0,
	"quadril": -0.04}
const ESTOCA := {"braco": [Vector3(0.16, 0.0, 1.0), Vector3(0.04, 0.05, 1.0), Vector3(0.02, 0.05, 1.0)], "tronco": 14.0,
	"quadril": 0.16, "baixa": 0.05}

## agacha para tomar impulso: corpo baixo e para a frente, braços para trás, lâminas para cima
const AGACHA := {"braco": [Vector3(0.62, -0.45, -0.45), Vector3(0.45, 0.2, 0.87), Vector3(0.35, 0.75, 0.55)], "tronco": 22.0,
	"quadril": -0.05, "baixa": 0.11}

var _sk: Skeleton3D
var _idle: Animation
var _player: AnimationPlayer


func _initialize() -> void:
	var tico := (load("res://actors/tico_lirou/tico_lirou.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(tico)
	_sk = tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for child: Node in _sk.get_children():
		if child is SkeletonModifier3D:
			child.free()  # sem a peça que baixa os braços: aqui a pose é a que está escrita
	_player = tico.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	lib.add_animation(&"Guarda", _make([[0.0, GUARDA], [0.9, GUARDA_INSPIRA], [1.8, GUARDA]], true))
	lib.add_animation(&"Corte_X", _make([[0.0, GUARDA], [0.16, PREPARA], [0.24, CRUZA], [0.31, SEGUE], [0.36, SEGUE], [0.58, GUARDA]], false))
	lib.add_animation(&"Bote", _make([[0.0, GUARDA], [0.14, AGACHA], [0.3, AGACHA]], false))
	lib.add_animation(&"Estocada", _make([[0.0, GUARDA], [0.14, RECOLHE], [0.22, ESTOCA], [0.38, ESTOCA], [0.62, GUARDA]], false))
	print("salvo ", ResourceSaver.save(lib, OUT))
	quit()


## Faz a animação: amostra 30 quadros por segundo, interpolando as poses (suave na ida, rápido no golpe).
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
		var pose := _pose_at(keys, time)
		_apply(pose, time)
		for b: int in _sk.get_bone_count():
			anim.rotation_track_insert_key(tracks[b], time, _sk.get_bone_pose_rotation(b))
		anim.position_track_insert_key(hips_pos, time, _sk.get_bone_pose_position(hips))
	return anim


## Mistura as duas poses em volta do instante (com aceleração: o golpe sai rápido e assenta devagar).
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
	var arm: Array = []
	for i: int in 3:
		arm.append((a["braco"][i] as Vector3).normalized().slerp((b["braco"][i] as Vector3).normalized(), k))
	return {"braco": arm, "tronco": lerpf(float(a.get("tronco", 0.0)), float(b.get("tronco", 0.0)), k),
		"quadril": lerpf(float(a.get("quadril", 0.0)), float(b.get("quadril", 0.0)), k),
		"baixa": lerpf(float(a.get("baixa", 0.0)), float(b.get("baixa", 0.0)), k)}


func _apply(pose: Dictionary, time: float) -> void:
	# o corpo todo da Idle (pernas, rabo, respiração)
	_player.play(&"Idle")
	var idle_len := _player.current_animation_length
	_player.seek(fmod(time, idle_len), true)
	var hips := _sk.find_bone("Hips")
	_sk.set_bone_pose_position(hips, _sk.get_bone_pose_position(hips) + Vector3(0, -float(pose.get("baixa", 0.0)), float(pose.get("quadril", 0.0))))
	# tronco inclina (em volta do eixo de lado a lado do personagem)
	var lean := deg_to_rad(float(pose.get("tronco", 0.0)))
	_turn(_sk.find_bone("Spine"), Basis(Vector3.RIGHT, lean * 0.45))
	_turn(_sk.find_bone("Chest"), Basis(Vector3.RIGHT, lean * 0.55))
	_turn(_sk.find_bone("Head"), Basis(Vector3.RIGHT, -lean * 0.8))  # a cabeça compensa: olha para o alvo
	# braços (espelhados): fora = o lado do ombro
	for side: String in ["Left", "Right"]:
		var upper := _sk.find_bone(side + "UpperArm")
		var lower := _sk.find_bone(side + "LowerArm")
		var hand := _sk.find_bone(side + "Hand")
		var out := signf(_sk.get_bone_global_pose(upper).origin.x)
		var dirs: Array = pose["braco"]
		_aim(upper, _to_space(dirs[0], out))
		_aim(lower, _to_space(dirs[1], out))
		_sk.set_bone_pose_rotation(hand, _sk.get_bone_rest(hand).basis.get_rotation_quaternion())
		# o pulso vira para a lâmina (que sai da mão no giro da empunhadura) apontar para onde a pose pede
		var blade := Basis.from_euler(AdagaPsiquica.GRIP_ROTATION * PI / 180.0) * Vector3.UP
		_aim(hand, _to_space(dirs[2], out), blade)


func _to_space(d: Vector3, out: float) -> Vector3:
	return Vector3(d.x * out, d.y, d.z).normalized()


## Gira o osso (a partir da pose de agora) por uma rotação dada no espaço do personagem.
func _turn(bone: int, rot: Basis) -> void:
	if bone < 0:
		return
	var parent := _sk.get_bone_parent(bone)
	var pg := _sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var g := pg * Basis(_sk.get_bone_pose_rotation(bone))
	_sk.set_bone_pose_rotation(bone, (pg.inverse() * (rot * g)).get_rotation_quaternion())


## Aponta o osso (o eixo dele que vai para o filho, +Y; ou outro eixo dele) na direção dada, no espaço do personagem.
func _aim(bone: int, dir: Vector3, axis: Vector3 = Vector3.UP) -> void:
	var parent := _sk.get_bone_parent(bone)
	var pg := _sk.get_bone_global_pose(parent).basis.orthonormalized()
	var g0 := pg * _sk.get_bone_rest(bone).basis.orthonormalized()
	var now := (g0 * axis).normalized()
	var g := Basis(Quaternion(now, dir)) * g0
	_sk.set_bone_pose_rotation(bone, (pg.inverse() * g).get_rotation_quaternion())
