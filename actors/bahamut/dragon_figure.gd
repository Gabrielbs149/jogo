class_name DragonFigure
extends Node3D
## Bahamut: dragão de tecido estilo Journey. Corpo em segmentos que seguem a cabeça, flutuando e ondulando.
## No editor aparece só o "Preview"; o corpo de verdade é montado quando o jogo roda.

@export var body_color: Color = Color(0.97, 0.88, 0.66)
@export var trim_color: Color = Color(1.0, 0.72, 0.3)
@export var eye_color: Color = Color(0.75, 0.95, 1.0)
@export var segments: int = 10
@export var spacing: float = 0.3
@export var hover_height: float = 1.5

var _parts: Array[MeshInstance3D] = []
var _points: Array[Vector3] = []
var _wings: Array[MeshInstance3D] = []
var _head: Node3D
var _time: float = 0.0


func _ready() -> void:
	var preview := get_node_or_null("Preview") as Node3D
	if preview:
		preview.visible = false
	var cloth := _material(body_color, 0.0)
	var trim := _material(trim_color, 2.2)
	var eyes := _material(eye_color, 6.0)

	_head = Node3D.new()
	add_child(_head)
	_head.top_level = true
	_add_mesh(_head, _sphere(0.26), cloth, Vector3.ZERO, Vector3(1.0, 0.85, 1.3))
	_add_mesh(_head, _box(Vector3(0.22, 0.16, 0.34)), cloth, Vector3(0, -0.04, -0.3), Vector3.ONE)
	for side: float in [-1.0, 1.0]:
		_add_mesh(_head, _sphere(0.045), eyes, Vector3(0.13 * side, 0.06, -0.2), Vector3.ONE)
		var horn := _add_mesh(_head, _cone(0.05, 0.42), trim, Vector3(0.12 * side, 0.22, 0.12), Vector3.ONE)
		horn.rotation = Vector3(deg_to_rad(-55), 0, deg_to_rad(-20 * side))
		var whisker := _add_mesh(_head, _box(Vector3(0.03, 0.02, 0.5)), trim, Vector3(0.12 * side, -0.08, -0.25), Vector3.ONE)
		whisker.rotation = Vector3(0, deg_to_rad(25 * side), 0)

	for i: int in segments:
		var t := float(i) / segments
		var part := MeshInstance3D.new()
		part.mesh = _sphere(lerpf(0.24, 0.07, t))
		part.scale = Vector3(1.0, 0.9, 1.6)
		part.material_override = trim if i % 3 == 2 else cloth
		part.top_level = true
		part.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(part)
		_parts.append(part)
	for i: int in segments + 1:
		_points.append(global_position + Vector3(0, hover_height, spacing * i))

	for side: float in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.9, 0.5)
		wing.mesh = quad
		var wing_mat := _material(body_color, 0.4)
		wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wing.material_override = wing_mat
		wing.top_level = true
		add_child(wing)
		wing.set_meta("side", side)
		_wings.append(wing)
	_head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	if _head == null:
		return
	_time += delta
	# frente no plano do chão: deitado (caído) a frente apontaria para cima
	var forward := Vector3(-global_basis.z.x, 0.0, -global_basis.z.z)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right := Vector3(-forward.z, 0.0, forward.x)
	var base := global_position + Vector3.UP * hover_height
	var head_pos := base + forward * 0.35 + Vector3.UP * sin(_time * 1.6) * 0.12 + right * sin(_time * 0.9) * 0.15
	_head.global_position = head_pos
	_head.global_basis = Basis.looking_at(forward, Vector3.UP)
	_points[0] = head_pos
	for i: int in range(1, _points.size()):
		var p := _points[i]
		# o corpo ondula em S atrás da cabeça
		var wave := right * sin(_time * 2.4 - i * 0.7) * 0.06 + Vector3.UP * cos(_time * 2.0 - i * 0.5) * 0.03
		p += wave - forward * delta * 0.8
		var dir := p - _points[i - 1]
		if dir.length_squared() < 0.000001:
			dir = -forward
		_points[i] = _points[i - 1] + dir.normalized() * spacing
	for i: int in _parts.size():
		var a := _points[i]
		var b := _points[i + 1]
		var along := (a - b).normalized()
		var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		_parts[i].global_transform = Transform3D(Basis.looking_at(along, up).scaled_local(Vector3(1.0, 0.9, 1.6)), (a + b) / 2.0)
	var flap := sin(_time * 3.2) * 0.5
	for wing: MeshInstance3D in _wings:
		var side: float = wing.get_meta("side")
		var anchor := _points[2] + right * side * 0.45
		var basis := Basis.looking_at(forward, Vector3.UP) * Basis(Vector3.FORWARD, side * (0.35 + flap)) * Basis(Vector3.RIGHT, deg_to_rad(-90))
		wing.global_transform = Transform3D(basis, anchor + Vector3.UP * 0.1)


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = scl
	parent.add_child(node)
	return node


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mat.rim_enabled = true
	mat.rim = 0.5
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat
