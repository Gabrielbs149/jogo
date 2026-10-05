class_name CellHighlighter
extends Node3D
## Desenha casas da grade no chão (alcance de movimento, alcance de habilidade, área, caminho).

enum Style { MOVE, TARGET, AREA, PATH, HOVER }

const COLORS := {
	Style.MOVE: Color(1.0, 0.95, 0.85, 0.16),
	Style.TARGET: Color(1.0, 0.62, 0.25, 0.32),
	Style.AREA: Color(1.0, 0.3, 0.18, 0.45),
	Style.PATH: Color(1.0, 0.97, 0.88, 0.7),
	Style.HOVER: Color(1.0, 0.97, 0.9, 0.55),
}

@export var grid: CombatGrid

var _pools: Dictionary = {}  # Style -> Array[MeshInstance3D]
var _materials: Dictionary = {}


func show_cells(style: Style, cells: Array[Vector2i]) -> void:
	var pool := _pool(style)
	while pool.size() < cells.size():
		pool.append(_make_tile(style))
	for i: int in pool.size():
		var tile: MeshInstance3D = pool[i]
		tile.visible = i < cells.size()
		if tile.visible:
			_place(tile, cells[i], style)


func clear(style: Style) -> void:
	for tile: MeshInstance3D in _pool(style):
		tile.visible = false


func clear_all() -> void:
	for style: int in _pools:
		clear(style as Style)


func _pool(style: Style) -> Array:
	if not _pools.has(style):
		_pools[style] = []
	return _pools[style]


func _make_tile(style: Style) -> MeshInstance3D:
	var tile := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	var scale_factor := 0.3 if style == Style.PATH else 0.9
	mesh.size = Vector2.ONE * grid.cell_size * scale_factor
	tile.mesh = mesh
	tile.material_override = _material(style)
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.top_level = true
	add_child(tile)
	return tile


func _material(style: Style) -> StandardMaterial3D:
	if not _materials.has(style):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = COLORS[style]
		mat.no_depth_test = false
		mat.render_priority = style
		_materials[style] = mat
	return _materials[style]


func _place(tile: MeshInstance3D, c: Vector2i, style: Style) -> void:
	# Deita a casa no chão inclinado: eixo Y do plano = normal do terreno
	var normal := grid.cell_normal(c)
	var x_axis := (Vector3.RIGHT - normal * normal.dot(Vector3.RIGHT)).normalized()
	var z_axis := x_axis.cross(normal)
	var lift := 0.06 + 0.01 * style
	tile.global_transform = Transform3D(Basis(x_axis, normal, z_axis), grid.cell_to_world(c) + normal * lift)
