extends GutTest
## O Tico troca de animação conforme o que faz: parado, andando, golpe de cada habilidade, esquiva, queda.

const TICO: PackedScene = preload("res://actors/heroes/tico_lirou.tscn")

var _tico: Combatant
var _player: AnimationPlayer


func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	_tico = TICO.instantiate() as Combatant
	_tico.position = Vector3(0, 0.5, 0)
	world.add_child(_tico)
	_player = _tico.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	await wait_physics_frames(3)


func test_tico_has_every_animation() -> void:
	for anim: String in ["idle", "walk", "run", "attack", "dash_strike", "cast", "hide", "dodge", "hit", "down"]:
		assert_true(_player.has_animation(anim), anim)


func test_stands_still_then_walks() -> void:
	assert_eq(_player.current_animation, "idle")
	_tico.desired_velocity = Vector3(0, 0, -4)
	await wait_physics_frames(6)
	assert_eq(_player.current_animation, "walk")


func test_each_ability_plays_its_strike() -> void:
	_tico.ability_used.emit(0)
	assert_eq(_player.current_animation, "attack")
	await wait_seconds(0.8)
	_tico.ability_used.emit(3)
	assert_eq(_player.current_animation, "hide")


func test_dodge_and_falling_down() -> void:
	_tico.dodge(Vector3.FORWARD)
	assert_eq(_player.current_animation, "dodge")
	await wait_seconds(0.6)
	_tico.take_damage(999, null)
	assert_eq(_player.current_animation, "down")
	_tico.revive(5)
	assert_eq(_player.current_animation, "idle")
