extends GutTest
## O Tico troca de animação conforme o que faz: parado, andando, golpe de cada habilidade, esquiva, queda.
## As animações vêm do KayKit e da Universal Animation Library (D070) pelo esqueleto humanoide (D028); os nomes ficam
## no Animator.

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
	var names: Array[StringName] = [_anim.idle, _anim.walk, _anim.run, _anim.jog, _anim.sneak, _anim.sneak_idle, _anim.dodge,
		_anim.hit, _anim.down, &"Sit_Floor_Idle"]
	names.append_array(_anim.ability_animations)
	names.append_array(_anim.combo)
	for recover: StringName in _anim.combo_recover:
		if recover != &"":
			names.append(recover)
	for anim: StringName in names:
		assert_true(_player.has_animation(anim), String(anim))


func test_stands_still_then_walks() -> void:
	assert_eq(_player.current_animation, String(_anim.idle))
	_tico.desired_velocity = Vector3(0, 0, -1)
	await wait_physics_frames(10)
	assert_eq(_player.current_animation, String(_anim.walk), "devagar: anda")
	_tico.desired_velocity = Vector3(0, 0, -4)
	await wait_physics_frames(15)
	assert_eq(_player.current_animation, String(_anim.jog), "no passo normal: trota (D070)")
	_tico.desired_velocity = Vector3(0, 0, -_tico.move_speed * 1.45)
	await wait_physics_frames(15)
	assert_eq(_player.current_animation, String(_anim.run), "com Shift: corre")


## D070: com aceleração o Tico não sai na velocidade toda de uma vez, e freia em vez de parar seco.
func test_accelerates_and_brakes() -> void:
	_tico.desired_velocity = Vector3(0, 0, -5)
	await wait_physics_frames(2)
	var early := Vector2(_tico.velocity.x, _tico.velocity.z).length()
	assert_between(early, 0.1, 4.0, "arranca aos poucos")
	await wait_physics_frames(20)
	assert_almost_eq(Vector2(_tico.velocity.x, _tico.velocity.z).length(), 5.0, 0.05)
	_tico.desired_velocity = Vector3.ZERO
	await wait_physics_frames(2)
	assert_gt(Vector2(_tico.velocity.x, _tico.velocity.z).length(), 0.5, "freia, não para seco")


## D070: C agacha: anda devagar e com as animações de furtivo.
func test_sneaking() -> void:
	_tico.sneaking = true
	await wait_physics_frames(4)
	assert_eq(_player.current_animation, String(_anim.sneak_idle))
	_tico.desired_velocity = Vector3(0, 0, -5)
	await wait_physics_frames(20)
	assert_eq(_player.current_animation, String(_anim.sneak))
	assert_lt(Vector2(_tico.velocity.x, _tico.velocity.z).length(), 5.0 * _tico.sneak_multiplier + 0.05)


## D070: atacar de novo no meio do golpe encadeia o próximo do combo; sem ataque, o golpe termina na recuperação.
func test_combo_chains_and_recovers() -> void:
	_tico.ability_used.emit(0)
	assert_eq(_player.current_animation, String(_anim.combo[0]))
	_tico.ability_used.emit(0)  # cedo demais: fica guardado
	assert_eq(_player.current_animation, String(_anim.combo[0]))
	await wait_until(func() -> bool: return _player.current_animation == String(_anim.combo[1]), 2.0)
	assert_eq(_player.current_animation, String(_anim.combo[1]), "o clique guardado vira o 2º golpe")
	await wait_until(func() -> bool: return _player.current_animation == String(_anim.combo_recover[1]), 2.0)
	assert_eq(_player.current_animation, String(_anim.combo_recover[1]), "sem clique: recuperação")
	_tico.ability_used.emit(0)
	assert_eq(_player.current_animation, String(_anim.combo[2]), "na recuperação ainda continua o combo")


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
