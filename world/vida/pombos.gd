class_name Pombos
extends Node3D
## Um bando de pombos (D060): ciscam no chão em volta de onde o bando mora, bicam, andam aos pulinhos. Você chega
## perto (ou passa correndo) e o bando inteiro levanta voo batendo as asas, dá uma volta alta e pousa de novo um
## tempo depois, longe de você. Os pombos são montados por código (corpo, cabeça, pescoço furta-cor, asas que batem).

@export var quantidade: int = 9
## Raio (m) do chão onde o bando cisca.
@export var raio: float = 6.0
## Distância (m) que espanta o bando (correndo, espanta de mais longe).
@export var susto: float = 3.2

var _birds: Array[Dictionary] = []
var _level: Level
var _flying: bool = false
var _fly_time: float = 0.0
var _sound_cool: float = 0.0

static var _mats: Dictionary = {}


func _ready() -> void:
	if Level.editing:
		set_physics_process(false)
		return
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	_level = node as Level
	for i: int in quantidade:
		var bird := _make_bird(i)
		add_child(bird)
		var angle := randf() * TAU
		bird.position = Vector3(cos(angle), 0, sin(angle)) * randf_range(0.3, raio)
		bird.rotation.y = randf() * TAU
		_birds.append({"node": bird, "target": bird.position, "timer": randf_range(0.2, 3.0), "hop": randf() * TAU,
			"wings": [bird.get_node("AsaE"), bird.get_node("AsaD")], "body": bird.get_node("Corpo"), "air": Vector3.ZERO,
			"phase": randf() * TAU})


func _physics_process(delta: float) -> void:
	_sound_cool -= delta
	var me: Node3D = _level.player if _level else null
	if not _flying and me:
		var running := false
		if me is Combatant:
			var c := me as Combatant
			running = Vector2(c.velocity.x, c.velocity.z).length() > c.move_speed * 0.9
		var limit := susto * (1.7 if running else 1.0)
		for b: Dictionary in _birds:
			var at := (b["node"] as Node3D).global_position
			if at.distance_to(me.global_position) < limit:
				_take_off(me.global_position)
				break
	if _flying:
		_fly_time -= delta
		_update_air(delta)
		if _fly_time <= 0.0:
			_land(me)
	else:
		for b: Dictionary in _birds:
			_update_ground(b, delta)


func _update_ground(b: Dictionary, delta: float) -> void:
	var bird := b["node"] as Node3D
	var body := b["body"] as Node3D
	b["timer"] = float(b["timer"]) - delta
	var to: Vector3 = (b["target"] as Vector3) - bird.position
	to.y = 0.0
	b["hop"] = float(b["hop"]) + delta * 10.0
	if to.length() > 0.05:
		bird.position += to.normalized() * minf(0.45 * delta, to.length())
		bird.rotation.y = lerp_angle(bird.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 8.0))
		body.position.y = 0.0 + absf(sin(float(b["hop"]))) * 0.025
		body.rotation.x = 0.0
	else:
		body.position.y = 0.0
		# bica o chão
		var peck := pow(maxf(sin(float(b["hop"]) * 0.35 + float(b["phase"])), 0.0), 8.0)
		body.rotation.x = -peck * 0.7
		if float(b["timer"]) <= 0.0:
			b["timer"] = randf_range(0.8, 4.0)
			var angle := randf() * TAU
			b["target"] = Vector3(cos(angle), 0, sin(angle)) * randf_range(0.2, raio)
	for wing: Node3D in b["wings"]:
		wing.rotation.z = 0.0


func _take_off(from: Vector3) -> void:
	_flying = true
	_fly_time = randf_range(5.0, 9.0)
	if _sound_cool <= 0.0:
		_sound_cool = 4.0
		Audio.play_at("pombo", global_position, -6.0)
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	for b: Dictionary in _birds:
		var spread := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 2.0
		b["air"] = (away * randf_range(2.5, 3.6) + spread * 0.4 + Vector3.UP * randf_range(2.2, 3.2))
		b["phase"] = randf() * TAU


func _update_air(delta: float) -> void:
	for b: Dictionary in _birds:
		var bird := b["node"] as Node3D
		var v: Vector3 = b["air"]
		# sobe, faz uma curva larga lá em cima e plana
		v = v.rotated(Vector3.UP, delta * 0.55)
		var height := bird.position.y
		v.y = lerpf(v.y, (6.5 - height) * 0.6, delta * 0.8)
		b["air"] = v
		bird.position += v * delta
		var flat := Vector3(v.x, 0, v.z)
		if flat.length() > 0.05:
			bird.rotation.y = lerp_angle(bird.rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 6.0))
		b["phase"] = float(b["phase"]) + delta * 22.0
		var flap := sin(float(b["phase"])) * 1.1
		var wings: Array = b["wings"]
		(wings[0] as Node3D).rotation.z = flap
		(wings[1] as Node3D).rotation.z = -flap
		(b["body"] as Node3D).rotation.x = -0.15


## Pousa de novo (longe de você), cada um num ponto do chão do bando.
func _land(me: Node3D) -> void:
	_flying = false
	for b: Dictionary in _birds:
		var bird := b["node"] as Node3D
		var angle := randf() * TAU
		var spot := Vector3(cos(angle), 0, sin(angle)) * randf_range(0.3, raio)
		if me and (global_position + spot).distance_to(me.global_position) < susto * 1.5:
			spot = -spot
		var tween := bird.create_tween()
		tween.tween_property(bird, "position", spot, randf_range(1.6, 2.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		b["target"] = spot
		b["timer"] = randf_range(1.0, 3.0)


func _make_bird(i: int) -> Node3D:
	var bird := Node3D.new()
	bird.name = "Pombo%d" % i
	var tint := randf_range(0.85, 1.12)
	var gray := _mat("cinza%d" % int(tint * 10), Color(0.55, 0.57, 0.64) * tint)
	var dark := _mat("escuro", Color(0.3, 0.31, 0.36))
	var neck := _mat("pescoco", Color(0.35, 0.5, 0.45), Color(0.1, 0.25, 0.2))
	var beak := _mat("bico", Color(0.85, 0.55, 0.3))
	var body := Node3D.new()
	body.name = "Corpo"
	bird.add_child(body)
	_part(body, _sphere(0.085, 0.15), gray, Vector3(0, 0.09, 0), Vector3(1.0, 0.85, 1.45))
	_part(body, _sphere(0.045, 0.09), neck, Vector3(0, 0.16, -0.08), Vector3.ONE)
	_part(body, _sphere(0.04, 0.08), gray, Vector3(0, 0.2, -0.11), Vector3.ONE)
	_part(body, _box(Vector3(0.018, 0.018, 0.04)), beak, Vector3(0, 0.195, -0.155), Vector3.ONE)
	_part(body, _box(Vector3(0.07, 0.015, 0.1)), dark, Vector3(0, 0.1, 0.13), Vector3.ONE).rotation.x = 0.35
	for side: int in [-1, 1]:
		_part(body, _box(Vector3(0.008, 0.07, 0.008)), beak, Vector3(side * 0.03, 0.03, 0.0), Vector3.ONE)
		var pivot := Node3D.new()
		pivot.name = "AsaE" if side < 0 else "AsaD"
		pivot.position = Vector3(side * 0.07, 0.12, 0.0)
		body.add_child(pivot)
		bird.set_meta(pivot.name, true)
		_part(pivot, _box(Vector3(0.13, 0.012, 0.1)), dark, Vector3(side * 0.065, 0, 0.01), Vector3.ONE)
	# as asas ficam como filhas do corpo; o bando acha pelo nome
	for side_name: String in ["AsaE", "AsaD"]:
		var wing := body.get_node(side_name)
		body.remove_child(wing)
		bird.add_child(wing)
	return bird


func _part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, size: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = at
	part.scale = size
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


static func _sphere(r: float, h: float) -> SphereMesh:
	var key := "s%.3f%.3f" % [r, h]
	if _mats.has(key):
		return _mats[key]
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = h
	mesh.radial_segments = 8
	mesh.rings = 4
	_mats[key] = mesh
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if _mats.has(key):
		return _mats[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_mats[key] = mesh
	return mesh


static func _mat(key: String, color: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.metallic = 0.3
	_mats[key] = mat
	return mat
