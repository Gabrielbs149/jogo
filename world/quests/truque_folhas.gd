class_name TruqueFolhas
extends Missao
## A criança da praça que chama o Tico de "moço-planta" (D089): pede o truque das folhas e o Tico escolhe se faz.
## Fazendo, o Tico ergue as mãos, as folhas saem delas, rodam em volta da criança subindo, estouram no alto e caem
## devagar, e ela pula de alegria. Marca: "truque.vezes" (quantas vezes ele fez). Falas *(proposta)*.

## "Falar com a criança" (filho dela).
@export var falar: Interactable

const CRIANCA := "Criança"
const FOLHAS := 28
const DURACAO := 5.0
## Quando, de 0 a 1, as folhas estouram lá em cima.
const ESTOURO := 0.72
const CORES: Array[Color] = [Color(0.34, 0.62, 0.2), Color(0.5, 0.74, 0.24), Color(0.8, 0.66, 0.18), Color(0.24, 0.5, 0.2)]

var _kid: Node3D
var _leaves: Array[MeshInstance3D] = []
## Por folha: ângulo, raio, altura extra, giro, balanço (sorteados uma vez por truque).
var _seed: Array[Vector4] = []
var _from: Vector3
var _burst_done: bool = false


func _setup() -> void:
	_kid = falar.get_parent() as Node3D
	falar.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_conversa, _kid))


func _conversa() -> void:
	var d := _hud.dialogue
	if Game.chosen != "tico":
		await d.say(CRIANCA, "Você não é o moço-planta. Cadê o moço-planta?")
		return
	var vezes := int(Game.flag("truque.vezes", 0))
	var pede := "Moço-planta! Faz de novo aquele truque das folhas?" if vezes == 0 \
			else "Moço-planta! Mais uma vez? Só mais uma, juro!"
	var pick: int = await d.choose(CRIANCA, pede, ["Fazer o truque das folhas", "Hoje não, pequeno."])
	if pick == 1:
		await d.say("Tico", "Hoje não, pequeno. Tô sem folha nenhuma.")
		await d.say(CRIANCA, "Ahh... Amanhã, então? Promete?")
		await d.say("Tico", "Prometo.")
		Emote.play(_kid, "...", 1.5)
		return
	await d.say("Tico", "Tá bom. Mas fica paradinho, senão as folhas se perdem.")
	d.close()
	await _truque()
	Game.set_flag("truque.vezes", vezes + 1)
	if vezes == 0:
		await d.say(CRIANCA, "DE NOVO! De novo, de novo!")
		await d.say("Tico", "Amanhã. Folha também cansa.")
	else:
		await d.say(CRIANCA, "Um dia você me ensina?")
		await d.say("Tico", "Primeiro aprende a ficar paradinho.")


## A cena: o Tico ergue as mãos, as folhas rodam em volta da criança, estouram e caem.
func _truque() -> void:
	if DisplayServer.get_name() == "headless" or _hud.dialogue.instant:
		return
	var hero := _level.player
	var animator := hero.get_node_or_null("Animator") if hero else null
	var before := get_viewport().get_camera_3d()
	var cam := _plano(hero)
	if animator:
		animator.call("act", &"ual/Spell_Simple_Enter")
	await _wait(0.5)
	if animator:
		animator.call("hold", &"ual/Spell_Simple_Idle")
	# as folhas saem das mãos do Tico
	_from = hero.global_position + hero.global_basis.z * -0.35 + Vector3.UP * 0.8 if hero else _kid.global_position
	_spawn()
	_kid.set("_timer", DURACAO + 4.0)  # o Morador não troca o gesto no meio
	Audio.play_at("esquiva", _kid.global_position, -8.0, 0.1)
	var tween := create_tween()
	tween.tween_method(_move, 0.0, 1.0, DURACAO)
	await _wait(DURACAO * ESTOURO)
	if animator:
		animator.call("act", &"ual/Spell_Simple_Exit")
	await _wait(DURACAO * (1.0 - ESTOURO))
	if tween.is_running():
		await tween.finished
	for leaf: MeshInstance3D in _leaves:
		leaf.queue_free()
	_leaves.clear()
	if animator:
		animator.call("release")
	if before and is_instance_valid(before):
		before.make_current()
	cam.queue_free()
	var figure := _kid.get_node_or_null("Figure")
	if figure:
		figure.set("animacao", "Idle")


## O plano do truque: de lado, aberto, o Tico e a criança no quadro (a câmera da conversa fica perto demais e as
## folhas sobem para fora dela). Do lado de onde a câmera já estava; se tem parede no caminho, o outro lado.
func _plano(hero: Node3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 50.0
	_level.add_child(cam)
	var a := hero.global_position if hero else _kid.global_position
	var b := _kid.global_position
	var mid := (a + b) * 0.5 + Vector3.UP * 0.9
	var across := b - a
	across.y = 0.0
	var side := across.normalized().cross(Vector3.UP) if across.length() > 0.05 else Vector3.FORWARD
	var now := get_viewport().get_camera_3d()
	if now and side.dot(now.global_position - mid) < 0.0:
		side = -side
	var space := _level.get_world_3d().direct_space_state
	var pos := mid + side * 3.0 + Vector3.UP * 0.35
	for tries: Array in [[side, 3.0], [-side, 3.0], [side, 2.2], [-side, 2.2]]:
		var at: Vector3 = mid + (tries[0] as Vector3) * float(tries[1]) + Vector3.UP * 0.35
		var ray := PhysicsRayQueryParameters3D.create(mid, at, 1)
		if space.intersect_ray(ray).is_empty():
			pos = at
			break
	cam.look_at_from_position(pos, mid + Vector3.UP * 0.3)
	cam.set_meta("foco", [hero, _kid])  # a Vida só esconde quem passar entre a câmera e os dois
	cam.make_current()
	return cam


## Uma folha: ponta dos dois lados, a nervura no meio dobrada para cima (dos dois lados aparece).
static func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const LEN := 0.16
	const STEPS := 6
	var rib: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for k: int in STEPS + 1:
		var t := float(k) / STEPS
		var z := (t - 0.5) * LEN
		var w := pow(sin(t * PI), 0.8) * 0.042
		rib.append(Vector3(0, 0.008, z))
		left.append(Vector3(-w, 0, z))
		right.append(Vector3(w, 0, z))
	for k: int in STEPS:
		for tri: Array in [[rib[k], left[k], left[k + 1]], [rib[k], left[k + 1], rib[k + 1]],
				[rib[k], right[k + 1], right[k]], [rib[k], rib[k + 1], right[k + 1]]]:
			for v: Vector3 in tri:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _spawn() -> void:
	_burst_done = false
	_seed.clear()
	var mesh := _leaf_mesh()
	var mats: Array[StandardMaterial3D] = []
	for color: Color in CORES:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.3
		mat.roughness = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mats.append(mat)
	for i: int in FOLHAS:
		var leaf := MeshInstance3D.new()
		leaf.mesh = mesh
		leaf.material_override = mats[i % mats.size()]
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_level.add_child(leaf)
		leaf.global_position = _from
		_leaves.append(leaf)
		_seed.append(Vector4(TAU * i / FOLHAS + randf_range(-0.2, 0.2), randf_range(0.85, 1.15),
				randf_range(-0.15, 0.15), randf_range(4.0, 9.0)))


## t de 0 a 1: junta (sai das mãos), roda subindo em volta da criança, estoura e cai balançando.
func _move(t: float) -> void:
	var center := _kid.global_position
	if t >= ESTOURO and not _burst_done:
		_burst_done = true
		var figure := _kid.get_node_or_null("Figure")
		if figure:
			figure.set("animacao", "Cheer")
		Emote.play(_kid, "!", 1.6)
		Audio.play("qte_perfeito", -10.0, 0.0)
		Audio.play_at("esquiva", center + Vector3.UP * 1.8, -6.0, 0.15)
	for i: int in _leaves.size():
		var s := _seed[i]
		var leaf := _leaves[i]
		var pos: Vector3
		var spin := t * 18.0 + t * t * 14.0  # vai acelerando
		if t < ESTOURO:
			var up := t / ESTOURO
			var angle := s.x + spin
			var radius := lerpf(0.85, 0.45, up) * s.y
			var orbit := center + Vector3(cos(angle) * radius, lerpf(0.15, 1.6, up) + s.z, sin(angle) * radius)
			var gather := clampf(t / 0.18 - float(i) / FOLHAS * 0.6, 0.0, 1.0)  # uma atrás da outra
			pos = _from.lerp(orbit, smoothstep(0.0, 1.0, gather))
		else:
			var fall := (t - ESTOURO) / (1.0 - ESTOURO)
			var angle := s.x + ESTOURO * 18.0 + fall * 2.0
			var radius := lerpf(0.45, 1.7, sqrt(fall)) * s.y
			var height := 1.6 + s.z + 0.9 * sin(minf(fall * 2.2, 1.0) * PI * 0.5) - fall * fall * 1.9
			pos = center + Vector3(cos(angle) * radius + sin(fall * s.w + s.x) * 0.15, height, sin(angle) * radius)
			leaf.scale = Vector3.ONE * maxf(0.01, 1.0 - smoothstep(0.75, 1.0, fall))
		leaf.global_position = pos
		leaf.rotation = Vector3(t * s.w, t * s.w * 0.7 + s.x, t * s.w * 0.4)
