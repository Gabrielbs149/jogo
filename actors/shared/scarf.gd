class_name Scarf
extends Node3D
## Cachecol que voa ao vento, estilo Journey. Corrente de pedaços que seguem o anterior com atraso.
## Coloque na nuca do personagem; ele cria os pedaços sozinho quando o jogo roda.

@export var segments: int = 9
@export var segment_length: float = 0.16
@export var width: float = 0.13
@export var color: Color = Color(0.75, 0.12, 0.08)
@export var glyph_color: Color = Color(1.0, 0.8, 0.45)
## Vento (direção e força). O cachecol tende a ir para lá.
@export var wind: Vector3 = Vector3(0.7, 0.08, 0.4)

var _points: Array[Vector3] = []
var _pieces: Array[MeshInstance3D] = []
var _cloth: StandardMaterial3D
var _glyph: StandardMaterial3D


## Atualiza as cores depois de criado (o RobedFigure chama).
func refresh_colors() -> void:
	if _cloth:
		_cloth.albedo_color = color
		_glyph.albedo_color = color
		_glyph.emission = glyph_color


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = color
	cloth.roughness = 0.85
	cloth.rim_enabled = true
	cloth.rim = 0.5
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glyph := cloth.duplicate() as StandardMaterial3D
	glyph.emission_enabled = true
	glyph.emission = glyph_color
	glyph.emission_energy_multiplier = 2.5
	_cloth = cloth
	_glyph = glyph
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.015, segment_length)
	for i: int in segments:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = glyph if i % 3 == 1 else cloth
		piece.top_level = true
		piece.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(piece)
		_pieces.append(piece)
	for i: int in segments + 1:
		_points.append(global_position + global_basis.z * segment_length * i)


func _process(delta: float) -> void:
	if _points.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	_points[0] = global_position
	for i: int in range(1, _points.size()):
		var p := _points[i]
		p += (wind + Vector3(0.0, -0.5, 0.0)) * delta * 1.6
		p += Vector3(sin(t * 3.1 + i * 0.7), sin(t * 2.3 + i) * 0.6, cos(t * 2.7 + i * 0.5)) * 0.004 * i
		var dir := p - _points[i - 1]
		if dir.length_squared() < 0.000001:
			dir = wind
		_points[i] = _points[i - 1] + dir.normalized() * segment_length
	for i: int in _pieces.size():
		var a := _points[i]
		var b := _points[i + 1]
		var forward := (b - a).normalized()
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		_pieces[i].global_transform = Transform3D(Basis.looking_at(forward, up), (a + b) / 2.0)
