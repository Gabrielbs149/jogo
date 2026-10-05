class_name CombatGrid
extends Node3D
## Grade invisível da batalha. O nó fica no canto (casa 0,0); cada casa tem a altura do terreno embaixo.
## Movimento em 8 direções (diagonal vale 1, como em D&D), sem cortar quina de obstáculo.

@export var size: Vector2i = Vector2i(18, 14)
@export var cell_size: float = 1.6
@export_flags_3d_physics var terrain_mask: int = 1

var _heights: Dictionary = {}  # Vector2i -> float
var _normals: Dictionary = {}  # Vector2i -> Vector3
var _blocked: Dictionary = {}  # Vector2i -> GridObstacle

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## Lê a altura do terreno em cada casa e marca as casas dos GridObstacle. Chamar depois da física existir.
func build() -> void:
	_heights.clear()
	_normals.clear()
	_blocked.clear()
	var space := get_world_3d().direct_space_state
	for y: int in size.y:
		for x: int in size.x:
			var c := Vector2i(x, y)
			var top := _flat_center(c) + Vector3.UP * 60.0
			var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 120.0, terrain_mask)
			var hit := space.intersect_ray(query)
			_heights[c] = (hit["position"] as Vector3).y if hit else global_position.y
			_normals[c] = (hit["normal"] as Vector3) if hit else Vector3.UP
	for node: Node in get_tree().get_nodes_in_group("grid_obstacle"):
		var obstacle := node as GridObstacle
		var origin := world_to_cell(obstacle.global_position)
		for oy: int in obstacle.footprint.y:
			for ox: int in obstacle.footprint.x:
				_blocked[origin + Vector2i(ox, oy)] = obstacle


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func is_blocked(c: Vector2i) -> bool:
	return not in_bounds(c) or _blocked.has(c)


## Ruína/pilar que ocupa a casa (ou null).
func obstacle_at(c: Vector2i) -> GridObstacle:
	return _blocked.get(c) as GridObstacle


func cell_to_world(c: Vector2i) -> Vector3:
	var p := _flat_center(c)
	p.y = float(_heights.get(c, global_position.y))
	return p


func cell_normal(c: Vector2i) -> Vector3:
	return _normals.get(c, Vector3.UP)


func world_to_cell(p: Vector3) -> Vector2i:
	var local := p - global_position
	return Vector2i(floori(local.x / cell_size), floori(local.z / cell_size))


## Distância em casas (diagonal vale 1).
static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Casas alcançáveis a partir de "from" em até max_steps passos.
## pass_blocked: casas que não dá para atravessar (inimigos). Devolve {casa: casa_anterior}.
func reachable(from: Vector2i, max_steps: int, flying: bool, pass_blocked: Dictionary) -> Dictionary:
	var parents := {}
	var frontier: Array[Vector2i] = [from]
	var seen := {from: true}
	for step: int in max_steps:
		var next: Array[Vector2i] = []
		for c: Vector2i in frontier:
			for n: Vector2i in neighbors(c, flying):
				if seen.has(n) or pass_blocked.has(n):
					continue
				seen[n] = true
				parents[n] = c
				next.append(n)
		frontier = next
	return parents


func neighbors(c: Vector2i, flying: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d: Vector2i in DIRECTIONS:
		var n := c + d
		if not in_bounds(n):
			continue
		if not flying:
			if _blocked.has(n):
				continue
			# Diagonal não corta quina de obstáculo
			if d.x != 0 and d.y != 0 and (_blocked.has(c + Vector2i(d.x, 0)) or _blocked.has(c + Vector2i(0, d.y))):
				continue
		# Quem voa passa por cima de obstáculo, mas não pode parar nele (filtrado em quem chama)
		result.append(n)
	return result


## Caminho (sem a casa de partida) até "to", usando o resultado de reachable().
static func path_to(parents: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var c := to
	while c != from:
		if not parents.has(c):
			return []
		path.push_front(c)
		c = parents[c]
	return path


## Linha de visão: nenhum obstáculo nas casas entre a e b (as pontas não contam).
func line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var c := a
	while c != b:
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			c.x += sx
		if e2 <= dx:
			err += dx
			c.y += sy
		if c != b and _blocked.has(c):
			return false
	return true


func cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			var c := Vector2i(x, y)
			if in_bounds(c):
				result.append(c)
	return result


func _flat_center(c: Vector2i) -> Vector3:
	return global_position + Vector3((c.x + 0.5) * cell_size, 0.0, (c.y + 0.5) * cell_size)
