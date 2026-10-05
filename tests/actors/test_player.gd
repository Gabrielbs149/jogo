extends GutTest
## Player 2D: fica no chão, anda devagar, não anda durante diálogo.

var _player: Player


func before_each() -> void:
	_player = TestWorld.build(self)


func after_each() -> void:
	Input.action_release("move_right")
	while Dialogue.is_open():
		TestWorld.press("interact")
		await wait_process_frames(2)


func test_lands_on_floor() -> void:
	await wait_physics_frames(20)
	assert_true(_player.is_on_floor())
	assert_almost_eq(_player.global_position.y, TestWorld.FLOOR_Y, 0.5)


func test_walks_right_slowly() -> void:
	await wait_physics_frames(10)
	var start_x := _player.global_position.x
	Input.action_press("move_right")
	await wait_physics_frames(60)
	var walked := _player.global_position.x - start_x
	assert_between(walked, 20.0, _player.walk_speed + 1.0, "anda, mas devagar (no máximo walk_speed em 1 s)")


func test_does_not_walk_during_dialogue() -> void:
	await wait_physics_frames(10)
	Dialogue.start("", PackedStringArray(["Teste."]))
	var start_x := _player.global_position.x
	Input.action_press("move_right")
	await wait_physics_frames(30)
	assert_almost_eq(_player.global_position.x, start_x, 0.5)
