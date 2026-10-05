extends GutTest
## Chegar perto de um Interactable, apertar E, o diálogo abre, o player trava, e as falas avançam até fechar.

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const INTERACTABLE_SCENE: PackedScene = preload("res://components/interactable/interactable.tscn")

var _player: Player
var _thing: Interactable


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

	_thing = INTERACTABLE_SCENE.instantiate() as Interactable
	_thing.lines = PackedStringArray(["Primeira fala.", "Segunda fala."])
	world.add_child(_thing)
	_thing.global_position = Vector3(0, 1, -1)

	_player = PLAYER_SCENE.instantiate() as Player
	world.add_child(_player)
	_player.global_position = Vector3(0, 0.1, 0)


func after_each() -> void:
	Input.action_release("move_forward")
	while Dialogue.is_open():
		_press_interact()
		await wait_frames(2)


func _press_interact() -> void:
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)


func test_interact_opens_dialogue_and_freezes_player() -> void:
	await wait_physics_frames(20)
	_press_interact()
	await wait_frames(3)
	assert_true(Dialogue.is_open(), "diálogo abriu")

	var start := _player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(30)
	assert_almost_eq(_player.global_position.z, start.z, 0.01, "não anda durante o diálogo")


func test_dialogue_advances_until_closed() -> void:
	await wait_physics_frames(20)
	_press_interact()
	await wait_frames(3)
	var presses := 0
	while Dialogue.is_open() and presses < 10:
		_press_interact()
		await wait_frames(3)
		presses += 1
	assert_false(Dialogue.is_open(), "fechou depois das falas")
	assert_between(presses, 2, 4, "2 falas: termina de digitar/avança cada uma")


func test_far_away_does_nothing() -> void:
	_player.global_position = Vector3(10, 0.1, 10)
	await wait_physics_frames(20)
	_press_interact()
	await wait_frames(3)
	assert_false(Dialogue.is_open())
