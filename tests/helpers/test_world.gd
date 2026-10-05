class_name TestWorld
extends RefCounted
## Monta um chão e um Player para os testes.

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const FLOOR_Y: float = 100.0


static func build(test: GutTest) -> Player:
	var world := Node2D.new()
	test.add_child_autofree(world)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = WorldBoundaryShape2D.new()
	floor_body.position = Vector2(0, FLOOR_Y)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var player := PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.global_position = Vector2(100, FLOOR_Y - 2)
	return player


static func press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
