extends GutTest
## Testa o Player com física de verdade: chão, gravidade, andar e pular.

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")

var _player: Player


func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	_player = PLAYER_SCENE.instantiate() as Player
	world.add_child(_player)
	_player.global_position = Vector3(0, 0.5, 0)


func after_each() -> void:
	for action: String in ["move_forward", "move_right", "jump"]:
		Input.action_release(action)


func test_forward_points_where_camera_looks() -> void:
	var dir := Player.direction_from_input(Vector2(0, -1), 0.0)
	assert_almost_eq(dir, Vector3(0, 0, -1), Vector3.ONE * 0.001)


func test_forward_follows_camera_yaw() -> void:
	# Câmera girada 90° para a esquerda: "frente" passa a ser -X.
	var dir := Player.direction_from_input(Vector2(0, -1), PI / 2.0)
	assert_almost_eq(dir, Vector3(-1, 0, 0), Vector3.ONE * 0.001)


func test_falls_and_lands_on_floor() -> void:
	await wait_physics_frames(30)
	assert_true(_player.is_on_floor(), "deveria estar no chão")
	assert_almost_eq(_player.global_position.y, 0.0, 0.05)


func test_walks_forward() -> void:
	await wait_physics_frames(20)
	Input.action_press("move_forward")
	await wait_physics_frames(30)
	assert_lt(_player.global_position.z, -1.0, "andou para -Z (frente da câmera)")
	assert_almost_eq(_player.global_position.x, 0.0, 0.05)


func test_jumps() -> void:
	await wait_physics_frames(20)
	var press := InputEventAction.new()
	press.action = "jump"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(10)
	assert_gt(_player.global_position.y, 0.5, "subiu")
	await wait_physics_frames(90)
	assert_true(_player.is_on_floor(), "voltou para o chão")
