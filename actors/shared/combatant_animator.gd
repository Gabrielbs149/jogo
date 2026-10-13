class_name CombatantAnimator
extends Node
## Toca as animações do modelo (o AnimationPlayer dentro do filho "Model") conforme o que o personagem faz:
## parado / andando / trotando / correndo pela velocidade, agachado (furtivo), golpes (com combo), esquiva, levar dano
## e cair. Vai como filho do Combatant, depois do "Model". Os nomes das animações ficam no Inspector.

## Avisa cada golpe do combo que começa (0 = primeiro): quem controla dá o passo à frente e acende a lâmina.
signal combo_strike(step: int)

@export var idle: StringName = &"idle"
@export var walk: StringName = &"walk"
@export var run: StringName = &"run"
## Trote (D070): o andar normal de quem tem trote. Vazio = anda com walk até correr.
@export var jog: StringName = &""
## Agachado (furtivo, D070): andando e parado. Vazio = sem furtivo.
@export var sneak: StringName = &""
@export var sneak_idle: StringName = &""
## Uma animação por habilidade, na mesma ordem da ficha (botão esquerdo, Q, E, R). Vazio = nenhuma.
@export var ability_animations: Array[StringName] = [&"attack", &"dash_strike", &"cast", &"hide"]
@export var dodge: StringName = &"dodge"
## Ritmo da esquiva (a animação de rolar é mais longa que o salto).
@export var dodge_speed: float = 1.0
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
## Com trote: abaixo desta velocidade (m/s) anda em vez de trotar.
@export var walk_below: float = 2.0
## Velocidade (m/s) em que cada animação de andar não desliza o pé, no tamanho do personagem (D070). Com ela o ritmo
## da animação segue a velocidade de verdade; sem, usa walk/run_reference_speed.
@export var natural_speeds: Dictionary = {}
## Ritmo máximo das animações de andar (perna curta corre com passinho rápido).
@export var max_play_rate: float = 1.8
## Tempo de mistura entre parado, andando e correndo.
@export var loco_blend: float = 0.15
## Manias de quando fica parado (D068): de vez em quando, depois de um tempo parado, toca uma delas. Andar cancela.
@export var fidgets: Array[StringName] = []
## Segundos parado antes de uma mania (sorteado entre x e y).
@export var fidget_after: Vector2 = Vector2(7.0, 14.0)
## Gestos pedidos pelo jogo (gesture("pega")): nome do gesto -> animação.
@export var gestures: Dictionary = {}
## Combo do ataque básico (D069/D070): atacar de novo durante um golpe encadeia o próximo; antes da metade, fica
## guardado e sai quando o golpe acaba. Sem ataque, o golpe termina na recuperação dele (andar corta). Vazio = usa
## ability_animations[0].
@export var combo: Array[StringName] = []
## Recuperação de cada golpe do combo (volta para a guarda). Vazio na posição = sem.
@export var combo_recover: Array[StringName] = []
## A partir desta fração do golpe, atacar encadeia na hora.
@export var combo_open: float = 0.45
## Ritmo dos golpes do combo.
@export var combo_speed: float = 1.0

var _me: Combatant
var _player: AnimationPlayer
var _one_shot: bool = false
## Animação presa por uma cena (sentado, comendo...): fica nela até release().
var _held: StringName = &""
var _idle_for: float = 0.0
var _next_fidget: float = 10.0
var _last_fidget: StringName = &""
## O que está tocando agora é mania, gesto ou recuperação (andar corta).
var _cancelable: bool = false
## A animação de andar da velocidade de agora e onde ela está (s). Segue contando durante um golpe andando: as
## pernas continuam no passo (PernasAndando) e, quando o golpe acaba, o andar volta de onde estaria.
var loco_anim: StringName = &""
var loco_phase: float = 0.0
## Quanto o pé ainda deslizaria com o ritmo no máximo (1 = nada): a peça Passada alonga o passo nessa medida.
var stride_need: float = 1.0
var _combo_step: int = -1
var _buffered: bool = false
## Quando acaba a mania/gesto de agora (as que são em laço, como cruzar os braços, tocam uma volta só).
var _shot_end: float = 0.0


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
	for loop_name: StringName in [idle, walk, run, jog, sneak, sneak_idle]:
		if loop_name != &"" and _player.has_animation(loop_name):
			if _player.get_animation(loop_name).loop_mode != Animation.LOOP_LINEAR:
				_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_finished)
	_me.ability_used.connect(_on_ability)
	_me.dodged.connect(func() -> void:
		_play_once(dodge)
		_player.speed_scale = dodge_speed)
	_me.hurt.connect(_on_hurt)
	_me.downed_changed.connect(_on_downed)
	_player.play(idle)
	_next_fidget = randf_range(fidget_after.x, fidget_after.y)


func _physics_process(delta: float) -> void:
	var speed := Vector2(_me.velocity.x, _me.velocity.z).length()
	var pick := _locomotion(speed)
	if pick[0] != loco_anim and _player.has_animation(pick[0]):
		# trocou de andar: o novo começa na mesma fração do passo (o pé que estava no chão continua no chão)
		var old_len := _player.get_animation(loco_anim).length if loco_anim != &"" and _player.has_animation(loco_anim) else 1.0
		var fraction := fmod(loco_phase, old_len) / old_len
		loco_anim = pick[0]
		loco_phase = fraction * _player.get_animation(loco_anim).length
	if _player.current_animation == loco_anim:
		loco_phase = _player.current_animation_position
	elif _one_shot and speed > 0.3 and loco_anim != &"" and _player.has_animation(loco_anim):
		loco_phase = fmod(loco_phase + delta * float(pick[1]), _player.get_animation(loco_anim).length)
	if _one_shot and _cancelable and (speed > 0.3 or Time.get_ticks_msec() / 1000.0 > _shot_end):
		_one_shot = false  # começou a andar (ou a mania deu a volta dela): para na hora
		_cancelable = false
	if _one_shot or _me.downed or _held != &"":
		return
	if speed < 0.3:
		_idle_for += delta
		if not fidgets.is_empty() and _me.get("real_time") != false and not _me.sneaking and _idle_for > _next_fidget:
			_idle_for = 0.0
			_next_fidget = randf_range(fidget_after.x, fidget_after.y)
			var options := fidgets.filter(func(f: StringName) -> bool: return f != _last_fidget)
			var chosen: StringName = options[randi() % options.size()] if not options.is_empty() else fidgets[0]
			_last_fidget = chosen
			_play_once(chosen)
			_cancelable = true
			return
		_loop(sneak_idle if _me.sneaking and sneak_idle != &"" else idle, 1.0)
		return
	_idle_for = 0.0
	_loop(pick[0], float(pick[1]))


## A animação de andar para esta velocidade e o ritmo dela: [nome, ritmo]. Também diz quanto o passo precisa alongar.
func _locomotion(speed: float) -> Array:
	var anim := walk
	var reference := walk_reference_speed
	if _me.sneaking and sneak != &"":
		anim = sneak
	elif speed >= _me.move_speed * run_threshold:
		anim = run
		reference = run_reference_speed
	elif jog != &"" and speed >= walk_below:
		anim = jog
		reference = run_reference_speed
	if natural_speeds.has(anim):
		var natural := float(natural_speeds[anim])
		var rate := clampf(speed / natural, 0.75, max_play_rate)
		stride_need = maxf(1.0, speed / (natural * rate))
		return [anim, rate]
	stride_need = 1.0
	if anim == run:
		return [anim, clampf(speed / reference, 0.7, 1.6)]
	return [anim, clampf(speed / reference, 0.6, max_play_rate)]


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
		_player.play(anim, loco_blend)
		if anim == loco_anim:
			_player.seek(loco_phase)  # volta no passo em que as pernas estavam
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


func _play_once(anim: StringName, blend: float = 0.08) -> void:
	if anim == &"" or not _player.has_animation(anim):
		return
	_one_shot = true
	_cancelable = false
	_player.speed_scale = 1.0
	_player.play(anim, blend)
	_player.seek(0.0, true)
	_shot_end = Time.get_ticks_msec() / 1000.0 + _player.get_animation(anim).length


func _on_ability(index: int) -> void:
	if index == 0 and not combo.is_empty():
		_combo_input()
		return
	if index < ability_animations.size():
		_play_once(ability_animations[index])


## Ataque com combo: no meio de um golpe encadeia (ou guarda para quando acabar); na recuperação, continua; parado
## ou andando, começa do primeiro.
func _combo_input() -> void:
	var now := StringName(_player.current_animation)
	var at := _player.current_animation_position / maxf(_player.current_animation_length, 0.001)
	var step := combo.find(now)
	if _one_shot and step >= 0:
		if at >= combo_open:
			_strike(step + 1)
		else:
			_buffered = true
		return
	var recovering := combo_recover.find(now)
	if _one_shot and recovering >= 0 and now != &"" and at < 0.6:
		_strike(recovering + 1)
		return
	_strike(0)


func _strike(step: int) -> void:
	step = step % combo.size()
	_combo_step = step
	_buffered = false
	_play_once(combo[step], 0.06)
	_player.speed_scale = combo_speed
	combo_strike.emit(step)


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
	if anim == down:
		return
	var step := combo.find(anim)
	if step >= 0 and not _me.downed:
		if _buffered:
			_strike(step + 1)
			return
		var recover: StringName = combo_recover[step] if step < combo_recover.size() else &""
		if recover != &"" and _player.has_animation(recover):
			_play_once(recover, 0.04)
			_player.speed_scale = combo_speed
			_cancelable = true
			return
	_one_shot = false
	_cancelable = false
