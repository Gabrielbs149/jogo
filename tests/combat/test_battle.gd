extends GutTest
## Luta de verdade em tempo real, com a IA dos dois lados: herói contra escaravelho num chão plano.
## Tem que acabar com alguém caído.

const CHUMASSO: PackedScene = preload("res://actors/heroes/chumasso.tscn")
const BEETLE: PackedScene = preload("res://actors/enemies/escaravelho_de_cinza.tscn")


func after_each() -> void:
	Engine.time_scale = 1.0


func _arena() -> Node3D:
	var world := Node3D.new()
	add_child_autofree(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	world.add_child(CombatFX.new())
	return world


func test_hero_and_beetle_fight_until_someone_falls() -> void:
	Dice.rng.seed = 2026
	Engine.time_scale = 3.0
	var world := _arena()
	var hero := CHUMASSO.instantiate() as Combatant
	var brain := AIBrain.new()
	brain.name = "AIBrain"
	brain.mode = AIBrain.Mode.COMPANION
	hero.add_child(brain)
	hero.position = Vector3(0, 1, 0)
	world.add_child(hero)
	var beetle := BEETLE.instantiate() as Combatant
	beetle.position = Vector3(0, 1, -6)
	world.add_child(beetle)
	await wait_until(func() -> bool: return hero.downed or not is_instance_valid(beetle) or beetle.hp <= 0, 25.0)
	assert_true(hero.downed or not is_instance_valid(beetle) or beetle.hp <= 0, "a luta acabou")
	assert_true(hero.downed or hero.hp < hero.max_hp or not is_instance_valid(beetle) or beetle.hp <= 0, "houve troca de golpes")
