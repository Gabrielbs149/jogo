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
	_tico.desired_velocity = Vector3(0, 0, -_tico.move_speed)
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
func test_combo_chains() -> void:
	_tico.ability_used.emit(0)
	assert_eq(_player.current_animation, String(_anim.combo[0]))
	_tico.ability_used.emit(0)  # cedo demais: fica guardado
	assert_eq(_player.current_animation, String(_anim.combo[0]))
	await wait_until(func() -> bool: return _player.current_animation == String(_anim.combo[1]), 2.0)
	assert_eq(_player.current_animation, String(_anim.combo[1]), "o clique guardado vira o 2º golpe")
	_tico.ability_used.emit(0)  # já passou da metade? encadeia; senão fica guardado
	await wait_until(func() -> bool: return _player.current_animation == String(_anim.combo[2]), 2.0)
	assert_eq(_player.current_animation, String(_anim.combo[2]), "o terceiro golpe do combo")
	await wait_until(func() -> bool: return not _anim.combo.has(StringName(_player.current_animation)), 3.0)
	assert_false(_anim.combo.has(StringName(_player.current_animation)), "sem clique, o combo termina")


## D075: a esquiva do Tico é curta (2,2 m) e freia, não um tiro de 5 m.
func test_dodge_is_short_and_brakes() -> void:
	var start := _tico.global_position
	_tico.dodge(Vector3.FORWARD)
	await wait_physics_frames(2)
	var early := Vector2(_tico.velocity.x, _tico.velocity.z).length()
	await wait_seconds(0.3)
	var late := Vector2(_tico.velocity.x, _tico.velocity.z).length()
	assert_lt(late, early, "freia")
	await wait_seconds(0.4)
	assert_between(start.distance_to(_tico.global_position), 1.6, 2.8)


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


## D078: andando e correndo o Tico não afunda no chão (o quadril descia até 7 cm e o joelho encostava).
func test_does_not_sink_while_running() -> void:
	var sk := _tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hips := BoneAttachment3D.new()
	hips.bone_name = "Hips"
	sk.add_child(hips)
	for speed: float in [_tico.move_speed, _tico.move_speed * 1.45]:
		var lowest := 9.0
		for i: int in 90:
			_tico.desired_velocity = Vector3(0, 0, -speed)
			await wait_physics_frames(1)
			if i > 30:
				lowest = minf(lowest, hips.global_position.y - _tico.global_position.y)
		assert_gt(lowest, 0.18, "quadril a %.1f m/s" % speed)


## D080: as duas adagas apontam para a frente (a mão direita é o espelho da esquerda) e o cabo fica dentro do punho.
func test_daggers_are_mirrored_and_held() -> void:
	var sk := _tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for m: Node in sk.get_children():
		if m is SkeletonModifier3D:
			(m as SkeletonModifier3D).active = false
	_anim.set_physics_process(false)
	_player.stop()
	var daggers := AdagaPsiquica.attach_to(_tico)
	sk.reset_bone_poses()
	await wait_process_frames(3)
	assert_eq(daggers.size(), 2)
	var forward := sk.global_basis * Vector3.BACK  # o Tico olha para +Z no esqueleto
	for d: AdagaPsiquica in daggers:
		var blade := (d.tip() - d.base()).normalized()
		assert_gt(blade.dot(forward.normalized()), 0.9, "%s: lâmina para a frente" % d.get_parent().name)
		var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone((d.get_parent() as BoneAttachment3D).bone_name)).origin
		var grip := d.global_transform * Vector3(0, -0.055, 0)
		assert_lt(grip.distance_to(hand), 0.03, "%s: o cabo no punho" % d.get_parent().name)


## D080: o osso que a animação não mexe volta para o descanso. Antes a coluna torcida de um golpe ficava no andar.
func test_bones_do_not_leak_between_animations() -> void:
	assert_true(_player.deterministic)
	var sk := _tico.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var spine := sk.find_bone("Spine")
	_anim.set_physics_process(false)
	_player.play(&"tico/Golpe_1")
	_player.seek(0.2, true)
	_player.play(&"ual/Walk")
	_player.seek(0.3, true)
	var now := sk.get_bone_pose_rotation(spine)
	var rest := sk.get_bone_rest(spine).basis.get_rotation_quaternion()
	assert_lt(rad_to_deg(now.angle_to(rest)), 1.0, "a coluna do andar é a do descanso")


## D080: de adagas na mão o Tico fica em guarda parado; sem elas, volta à idle.
func test_armed_stands_in_guard() -> void:
	_anim.armed = true
	await wait_physics_frames(3)
	assert_eq(_player.current_animation, String(_anim.armed_idle))
	_anim.armed = false
	await wait_physics_frames(3)
	assert_eq(_player.current_animation, String(_anim.idle))


## D080: apertar logo depois do fim de um golpe ainda continua o combo (andando, recomeçava sempre do primeiro).
func test_combo_continues_right_after_a_strike() -> void:
	_tico.ability_used.emit(0)
	await wait_until(func() -> bool: return _player.current_animation != String(_anim.combo[0]), 2.0)
	_tico.ability_used.emit(0)
	assert_eq(_player.current_animation, String(_anim.combo[1]), "o segundo golpe, não o primeiro de novo")
