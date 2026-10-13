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
@export var dodge: StringName = &"dodge"
@export var hit: StringName = &"hit"
@export var down: StringName = &"down"
## Animações extras de outra fonte (ex.: a biblioteca do KayKit, `kaykit/Dodge_Forward`), para quem tem animações
## próprias mas não todas. Precisa de esqueleto humanoide (D028). Os nomes acima usam o prefixo do apelido.
@export var extra_library: AnimationLibrary
@export var extra_library_name: StringName = &"kaykit"
## Velocidade (m/s) em que a caminhada e a corrida rodam no ritmo normal.
@export var walk_reference_speed: float = 4.0
@export var run_reference_speed: float = 7.5
## Corre quando passa desta fração do deslocamento do personagem (Shift).
@export var run_threshold: float = 1.15
## Manias de quando fica parado (D068): de vez em quando, depois de um tempo parado, toca uma delas. Andar cancela.
@export var fidgets: Array[StringName] = []
## Segundos parado antes de uma mania (sorteado entre x e y).
@export var fidget_after: Vector2 = Vector2(7.0, 14.0)
## Gestos pedidos pelo jogo (gesture("pega")): nome do gesto -> animação.
@export var gestures: Dictionary = {}

var _me: Combatant
var _player: AnimationPlayer
var _one_shot: bool = false
## Animação presa por uma cena (sentado, comendo...): fica nela até release().
var _held: StringName = &""
var _idle_for: float = 0.0
var _next_fidget: float = 10.0
var _last_fidget: StringName = &""
## O que está tocando agora é mania ou gesto (andar corta).
var _cancelable: bool = false


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
	if extra_library and not _player.has_animation_library(extra_library_name):
		_player.add_animation_library(extra_library_name, extra_library)
	for loop_name: StringName in [idle, walk, run]:
		if _player.has_animation(loop_name):
			if _player.get_animation(loop_name).loop_mode != Animation.LOOP_LINEAR:
				_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_finished)
	_me.ability_used.connect(_on_ability)
	_me.dodged.connect(func() -> void: _play_once(dodge))
	_me.hurt.connect(_on_hurt)
	_me.downed_changed.connect(_on_downed)
	_player.play(idle)
	_next_fidget = randf_range(fidget_after.x, fidget_after.y)


func _physics_process(delta: float) -> void:
	var speed := Vector2(_me.velocity.x, _me.velocity.z).length()
	if _one_shot and _cancelable and speed > 0.3:
		_one_shot = false  # começou a andar: a mania para na hora
		_cancelable = false
	if _one_shot or _me.downed or _held != &"":
		return
	if speed < 0.3:
		_idle_for += delta
		if not fidgets.is_empty() and _me.get("real_time") != false and _idle_for > _next_fidget:
			_idle_for = 0.0
			_next_fidget = randf_range(fidget_after.x, fidget_after.y)
			var options := fidgets.filter(func(f: StringName) -> bool: return f != _last_fidget)
			var pick: StringName = options[randi() % options.size()] if not options.is_empty() else fidgets[0]
			_last_fidget = pick
			_play_once(pick)
			_cancelable = true
			return
		_loop(idle, 1.0)
	elif speed < _me.move_speed * run_threshold:
		_loop(walk, clampf(speed / walk_reference_speed, 0.6, 1.8))
	else:
		_loop(run, clampf(speed / run_reference_speed, 0.7, 1.6))
	if speed >= 0.3:
		_idle_for = 0.0


## Um gesto pedido pelo jogo (pegar uma coisa, examinar): toca uma vez, e andar corta. Devolve false se não tem.
func gesture(kind: String) -> bool:
	var anim: StringName = StringName(gestures.get(kind, ""))
	if _player == null or anim == &"" or not _player.has_animation(anim) or _held != &"" or _me.downed:
		return false
	_play_once(anim)
	_cancelable = true
	_idle_for = 0.0
	return true


func _loop(anim: StringName, speed: float) -> void:
	if not _player.has_animation(anim):
		return
	if _player.current_animation != anim:
		_player.play(anim, 0.15)
	_player.speed_scale = speed


## Prende o personagem numa animação (em laço) até release(). Usado pelas cenas. Devolve false se não existe.
func hold(anim: StringName) -> bool:
	if _player == null or not _player.has_animation(anim):
		return false
	_held = anim
	_one_shot = false
	var res := _player.get_animation(anim)
	if res.loop_mode != Animation.LOOP_LINEAR:
		res.loop_mode = Animation.LOOP_LINEAR  # só se mudar (D067): mexer na animação, que é a mesma para todos os bonecos, refazia o cache de animação de todos
	_player.speed_scale = 1.0
	_player.play(anim, 0.3)
	return true


func release() -> void:
	_held = &""


## Toca uma animação uma vez (sem prender), na velocidade dada. Usado pela arena para montar o golpe (D056).
func act(anim: StringName, speed: float = 1.0) -> void:
	_held = &""
	_play_once(anim)
	if _player:
		_player.speed_scale = speed


func _play_once(anim: StringName) -> void:
	if anim == &"" or not _player.has_animation(anim):
		return
	_one_shot = true
	_cancelable = false
	_player.speed_scale = 1.0
	_player.play(anim, 0.08)
	_player.seek(0.0, true)


func _on_ability(index: int) -> void:
	if index < ability_animations.size():
		_play_once(ability_animations[index])


func _on_hurt(_by: Combatant) -> void:
	if not _one_shot and _me.is_active():
		_play_once(hit)


func _on_downed(is_down: bool) -> void:
	if is_down:
		_play_once(down)
	else:
		_one_shot = false
		_player.play(idle, 0.2)


func _on_finished(anim: StringName) -> void:
	if anim != down:
		_one_shot = false
		_cancelable = false
