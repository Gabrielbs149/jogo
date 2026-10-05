extends GutTest
## Chegar perto de um Interactable, apertar E, ler as falas até fechar.

const INTERACTABLE_SCENE: PackedScene = preload("res://components/interactable/interactable.tscn")

var _player: Player
var _thing: Interactable


func before_each() -> void:
	_player = TestWorld.build(self)
	_thing = INTERACTABLE_SCENE.instantiate() as Interactable
	_thing.lines = PackedStringArray(["Primeira.", "Segunda."])
	_player.get_parent().add_child(_thing)
	_thing.global_position = _player.global_position + Vector2(10, -16)


func after_each() -> void:
	while Dialogue.is_open():
		TestWorld.press("interact")
		await wait_process_frames(2)


func test_interact_opens_and_closes_dialogue() -> void:
	await wait_physics_frames(10)
	TestWorld.press("interact")
	await wait_process_frames(3)
	assert_true(Dialogue.is_open(), "abriu")
	var presses := 0
	while Dialogue.is_open() and presses < 10:
		TestWorld.press("interact")
		await wait_process_frames(3)
		presses += 1
	assert_false(Dialogue.is_open(), "fechou")


func test_far_away_does_nothing() -> void:
	_thing.global_position = _player.global_position + Vector2(200, 0)
	await wait_physics_frames(10)
	TestWorld.press("interact")
	await wait_process_frames(3)
	assert_false(Dialogue.is_open())
