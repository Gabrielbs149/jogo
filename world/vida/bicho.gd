class_name Bicho
extends Node3D
## Bicho da cidade (D060): passeia em volta de onde mora, para, come, deita. Os animados (cachorro, cavalo, burro,
## rato) usam as animações deles; os parados (galinha, gato, pintinho: modelos sem esqueleto) ganham movimento por
## código: andar aos pulinhos, bicar o chão, balançar. Medroso foge quando você chega perto; amigo (cachorro)
## às vezes segue você um pouco e fica contente.
## Ponha como raiz do bicho, com o modelo dentro (qualquer filho).

enum Jeito { CALMO, MEDROSO, AMIGO, PREGUICOSO }

@export var jeito: Jeito = Jeito.CALMO
## Até onde passeia (m) em volta de onde começou.
@export var raio: float = 6.0
@export var velocidade: float = 0.9
## Galinha bica o chão; gato deita e dorme.
@export var bica: bool = false
@export var dorme: bool = false
## Sem esqueleto: anda aos pulinhos (galinha, gato). Desligado: só desliza devagar (vaca, cavalo de enfeite).
@export var pula: bool = true

var _home: Vector3
var _target: Vector3
var _moving: bool = false
var _timer: float = 0.0
var _player_anim: AnimationPlayer
var _anims: Dictionary = {}
var _model: Node3D
var _hop: float = 0.0
var _following: float = 0.0
var _fleeing: bool = false
var _model_base: Transform3D
var _level: Level


func _ready() -> void:
	if Level.editing:
		set_physics_process(false)
		return
	_home = global_position
	_target = _home
	_timer = randf_range(0.5, 4.0)
	for child: Node in get_children():
		if child is Node3D and not child is Sprite3D and not child is Label3D:
			_model = child as Node3D
			break
	if _model:
		_model_base = _model.transform
	var found := find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player_anim = found[0] as AnimationPlayer
		for anim: String in _player_anim.get_animation_list():
			var low := anim.to_lower()
			for key: String in ["walk", "idle", "eat", "gallop", "run", "death"]:
				if low.ends_with(key) or low.contains("|" + key) or low.ends_with("_" + key):
					if not _anims.has(key):
						_anims[key] = anim
		_play("idle")
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	_level = node as Level


func _physics_process(delta: float) -> void:
	var me: Node3D = _level.player if _level else null
	var to_me := (me.global_position - global_position) if me else Vector3(99, 0, 99)
	to_me.y = 0.0
	# reações a você
	if me and jeito == Jeito.MEDROSO and to_me.length() < 3.2:
		if not _fleeing:
			_fleeing = true
			if randf() < 0.5:
				Emote.play(self, "susto", 1.2)
		var away := -to_me.normalized()
		_target = global_position + away * 3.5
		_moving = true
	elif _fleeing and to_me.length() > 5.0:
		_fleeing = false
	if me and jeito == Jeito.AMIGO:
		if to_me.length() < 2.5 and _following <= 0.0 and randf() < delta * 0.4:
			_following = randf_range(8.0, 16.0)
			Emote.play(self, "coracao", 1.6)
		if _following > 0.0:
			_following -= delta
			if to_me.length() > 1.8:
				_target = me.global_position - to_me.normalized() * 1.3
				_moving = true
	if _moving:
		_move(delta)
	else:
		_idle(delta)


func _move(delta: float) -> void:
	var to := _target - global_position
	to.y = 0.0
	var speed := velocidade * (2.4 if _fleeing or _following > 0.0 else 1.0)
	if to.length() < 0.15:
		_moving = false
		_timer = randf_range(2.0, 7.0) * (3.0 if jeito == Jeito.PREGUICOSO else 1.0)
		_play("idle")
		if dorme and randf() < 0.4:
			_timer *= 3.0
			Emote.play(self, "zz", 2.5)
		return
	var step := to.normalized() * minf(speed * delta, to.length())
	global_position += step
	# pés no chão (degrau da praça, calçada): um raio para baixo, só em quem não está pendurado em nada
	var from := global_position + Vector3.UP * 0.6
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0, 1))
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 6.0))
	if _player_anim:
		_play("run" if speed > velocidade * 1.5 and _anims.has("run") else ("gallop" if speed > velocidade * 1.5 and _anims.has("gallop") else "walk"))
	elif _model and pula:
		# sem esqueleto: anda aos pulinhos
		_hop += delta * (14.0 if speed > velocidade * 1.5 else 9.0)
		_model.transform = _model_base.translated(Vector3(0, absf(sin(_hop)) * 0.06, 0)).rotated_local(Vector3.FORWARD, sin(_hop) * 0.06)


func _idle(delta: float) -> void:
	_timer -= delta
	if _player_anim == null and _model:
		_hop += delta * 3.0
		# parado: respira; a galinha bica o chão de vez em quando
		var peck := 0.0
		if bica:
			peck = maxf(sin(_hop * 1.7), 0.0)
			peck = pow(peck, 6.0) * 0.55
		_model.transform = _model_base.rotated_local(Vector3.RIGHT, -peck).scaled_local(Vector3(1.0, 1.0 + sin(_hop) * 0.015, 1.0))
	elif _player_anim and _anims.has("eat") and randf() < delta * 0.1:
		_play("eat")
	if _timer <= 0.0:
		var angle := randf() * TAU
		_target = _home + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.5, raio)
		_moving = true


func _play(kind: String) -> void:
	if _player_anim == null or not _anims.has(kind):
		return
	var anim: String = _anims[kind]
	if _player_anim.current_animation == anim:
		return
	_player_anim.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_player_anim.play(anim, 0.25)
