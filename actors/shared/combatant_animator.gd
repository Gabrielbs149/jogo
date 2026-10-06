class_name CombatantAnimator
extends Node
## Toca as animações do modelo (o AnimationPlayer dentro do filho "Model") conforme o que o personagem faz:
## parado / andando / correndo pela velocidade, um golpe por habilidade, esquiva, levar dano e cair.
## Vai como filho do Combatant, depois do "Model". Os nomes das animações ficam no Inspector.

@export var idle: StringName = &"idle"
@export var walk: StringName = &"walk"
@export var run: StringName = &"run"
## Uma animação por habilidade, na mesma ordem da ficha (botão esquerdo, Q, E, R). Vazio = nenhuma.
@export var ability_animations: Array[StringName] = [&"attack", &"dash_strike", &"cast", &"hide"]
## Quanto tempo (s) cada golpe dura na tela; a animação acelera ou desacelera para caber. 0 = tempo original.
@export var ability_times: Array[float] = [0.6, 0.9, 1.0, 0.8]
@export var dodge: StringName = &"dodge"
@export var dodge_time: float = 0.45
@export var hit: StringName = &"hit"
@export var hit_time: float = 0.45
@export var down: StringName = &"down"
@export var down_time: float = 1.4
## Velocidade (m/s) em que a caminhada e a corrida rodam no ritmo normal.
@export var walk_reference_speed: float = 2.5
@export var run_reference_speed: float = 6.0
## Corre quando passa desta fração do deslocamento do personagem (abaixo disso, anda).
@export var run_threshold: float = 0.7

var _me: Combatant
var _player: AnimationPlayer
var _one_shot: bool = false


func _ready() -> void:
	_me = get_parent() as Combatant
	var model := _me.get_node_or_null("Model")
	if model:
		var found := model.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			_player = found[0] as AnimationPlayer
	if _player == null:
		push_warning("%s: modelo sem AnimationPlayer, sem animação" % _me.display_name)
		set_physics_process(false)
		return
	for loop_name: StringName in [idle, walk, run]:
		if _player.has_animation(loop_name):
			_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_finished)
	_me.ability_used.connect(_on_ability)
	_me.dodged.connect(func() -> void: _play_once(dodge, dodge_time))
	_me.hurt.connect(_on_hurt)
	_me.downed_changed.connect(_on_downed)
	_player.play(idle)


func _physics_process(_delta: float) -> void:
	if _one_shot or _me.downed:
		return
	var speed := Vector2(_me.velocity.x, _me.velocity.z).length()
	if speed < 0.3:
		_loop(idle, 1.0)
	elif speed < _me.move_speed * run_threshold:
		_loop(walk, clampf(speed / walk_reference_speed, 0.6, 1.8))
	else:
		_loop(run, clampf(speed / run_reference_speed, 0.7, 1.6))


func _loop(anim: StringName, speed: float) -> void:
	if not _player.has_animation(anim):
		return
	if _player.current_animation != anim:
		_player.play(anim, 0.15)
	_player.speed_scale = speed


func _play_once(anim: StringName, time: float = 0.0) -> void:
	if anim == &"" or not _player.has_animation(anim):
		return
	_one_shot = true
	var length := _player.get_animation(anim).length
	_player.speed_scale = length / time if time > 0.0 and length > 0.0 else 1.0
	_player.play(anim, 0.08)
	_player.seek(0.0, true)


func _on_ability(index: int) -> void:
	if index < ability_animations.size():
		_play_once(ability_animations[index], ability_times[index] if index < ability_times.size() else 0.0)


func _on_hurt(_by: Combatant) -> void:
	if not _one_shot and _me.is_active():
		_play_once(hit, hit_time)


func _on_downed(is_down: bool) -> void:
	if is_down:
		_play_once(down, down_time)
	else:
		_one_shot = false
		_player.play(idle, 0.2)


func _on_finished(anim: StringName) -> void:
	if anim != down:
		_one_shot = false
