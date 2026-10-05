extends GutTest
## Grade: alcance de movimento, obstáculos, quina, voo e linha de visão (sem terreno, altura 0).

var _grid: CombatGrid


func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	_grid = CombatGrid.new()
	_grid.size = Vector2i(10, 10)
	_grid.cell_size = 1.0
	world.add_child(_grid)
	_add_obstacle(world, Vector2i(5, 5))
	_grid.build()


func _add_obstacle(world: Node3D, c: Vector2i) -> void:
	var obstacle := GridObstacle.new()
	world.add_child(obstacle)
	obstacle.global_position = Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func test_distance_counts_diagonal_as_one() -> void:
	assert_eq(CombatGrid.distance(Vector2i(0, 0), Vector2i(3, 2)), 3)


func test_reach_in_open_field() -> void:
	var reach := _grid.reachable(Vector2i(1, 1), 1, false, {})
	assert_eq(reach.size(), 8, "8 vizinhos com 1 passo")


func test_obstacle_blocks_walking() -> void:
	assert_true(_grid.is_blocked(Vector2i(5, 5)))
	var reach := _grid.reachable(Vector2i(4, 5), 1, false, {})
	assert_false(reach.has(Vector2i(5, 5)))


func test_no_corner_cutting() -> void:
	var reach := _grid.reachable(Vector2i(4, 4), 1, false, {})
	assert_false(reach.has(Vector2i(5, 5)))
	assert_true(reach.has(Vector2i(3, 3)))


func test_flying_passes_over_obstacle() -> void:
	var walk := _grid.reachable(Vector2i(4, 5), 2, false, {})
	var fly := _grid.reachable(Vector2i(4, 5), 2, true, {})
	var path := CombatGrid.path_to(fly, Vector2i(4, 5), Vector2i(6, 5))
	assert_eq(path.size(), 2, "voa reto por cima")
	assert_eq(CombatGrid.path_to(walk, Vector2i(4, 5), Vector2i(6, 5)).size(), 0, "andando, 2 passos não bastam para contornar")
	var long_walk := _grid.reachable(Vector2i(4, 5), 4, false, {})
	assert_eq(CombatGrid.path_to(long_walk, Vector2i(4, 5), Vector2i(6, 5)).size(), 4, "com 4 passos contorna")


func test_enemies_block_passage() -> void:
	var blocked := {Vector2i(2, 1): true, Vector2i(2, 0): true, Vector2i(2, 2): true}
	var reach := _grid.reachable(Vector2i(1, 1), 2, false, blocked)
	assert_false(reach.has(Vector2i(3, 1)), "parede de inimigos")


func test_line_of_sight_blocked_by_obstacle() -> void:
	assert_false(_grid.line_of_sight(Vector2i(3, 5), Vector2i(7, 5)))
	assert_true(_grid.line_of_sight(Vector2i(3, 3), Vector2i(7, 3)))
