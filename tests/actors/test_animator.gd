extends GutTest
## O Tico troca de animação conforme o que faz: parado, andando, golpe de cada habilidade, esquiva, queda.
## As animações vêm do KayKit pelo esqueleto humanoide (D028); os nomes ficam no Animator.

const TICO: PackedScene = preload("res://actors/heroes/tico_lirou.tscn")

var _tico: Combatant
var _player: AnimationPlayer
var _anim: CombatantAnimator


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
	_anim = _tico.get_node("Animator") as CombatantAnimator
	await wait_physics_frames(3)


func test_tico_has_every_animation() -> void:
	var names: Array[StringName] = [_anim.idle, _anim.walk, _anim.run, _anim.dodge, _anim.hit, _anim.down, &"Sit_Floor_Idle"]
	names.append_array(_anim.ability_animations)
	for anim: StringName in names:
		assert_true(_player.has_animation(anim), String(anim))


func test_stands_still_then_walks() -> void:
	assert_eq(_player.current_animation, String(_anim.idle))
	_tico.desired_velocity = Vector3(0, 0, -4)
	await wait_physics_frames(6)
	assert_eq(_player.current_animation, String(_anim.walk))


func test_each_ability_plays_its_strike() -> void:
	_tico.ability_used.emit(0)
	assert_eq(_player.current_animation, String(_anim.ability_animations[0]))
	await wait_seconds(0.8)
	_tico.ability_used.emit(3)
	assert_eq(_player.current_animation, String(_anim.ability_animations[3]))


func test_dodge_and_falling_down() -> void:
	_tico.dodge(Vector3.FORWARD)
	assert_eq(_player.current_animation, String(_anim.dodge))
	await wait_seconds(0.6)
	_tico.take_damage(999, null)
	assert_eq(_player.current_animation, String(_anim.down))
	_tico.revive(5)
	assert_eq(_player.current_animation, String(_anim.idle))


## Os inimigos de Ethera (D036) têm todas as animações que o Animator deles pede, e uma por habilidade.
func test_enemies_have_every_animation() -> void:
	for path: String in ["res://actors/enemies/escaravelho_de_cinza.tscn", "res://actors/enemies/sentinela_estelar.tscn",
			"res://actors/enemies/ultimo_guardiao.tscn"]:
		var enemy := (load(path) as PackedScene).instantiate() as Combatant
		add_child_autofree(enemy)
		var player := enemy.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var anim := enemy.get_node("Animator") as CombatantAnimator
		assert_eq(anim.ability_animations.size(), enemy.abilities.size(), path)
		var names: Array[StringName] = [anim.idle, anim.walk, anim.run, anim.dodge, anim.hit, anim.down]
		names.append_array(anim.ability_animations)
		for name: StringName in names:
			assert_true(player.has_animation(name), "%s: %s" % [path.get_file(), name])
