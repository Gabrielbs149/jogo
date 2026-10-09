class_name Passante
extends Node3D
## Uma pessoa da cidade que vive o dia (D060): sai de casa de manhã, anda pela rua (pelo mapa de navegação), para
## nas bancas, conversa com outros na praça, entra nas lojas e volta, e de noite vai para casa (some na porta).
## Reage a você: dá licença, se assusta se você passa correndo, cumprimenta. Quem cria e escolhe para onde vai é a
## Vida (world/vida/vida.gd); o corpo é um Figurante (filho "Figure").

enum Estado { INDO, FAZENDO, EM_CASA, CONVERSANDO }

## Metros por segundo andando.
@export var velocidade: float = 1.3
## Horas em que sai de casa e em que volta.
@export var acorda: float = 7.0
@export var dorme: float = 19.5
## Criança: corre em vez de andar e brinca.
@export var crianca: bool = false

var vida: Vida
var casa: Vector3
var estado: Estado = Estado.EM_CASA
var ponto: Dictionary = {}
var parceiro: Passante

var _fig: Node3D
var _path: PackedVector3Array = PackedVector3Array()
var _step: int = 0
var _timer: float = 0.0
var _anim: String = ""
var _yield_time: float = 0.0
var _talk_beat: float = 0.0
var _body: AnimatableBody3D
var _repath: float = 0.0


func _ready() -> void:
	_fig = get_node_or_null("Figure") as Node3D
	_body = AnimatableBody3D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	_body.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28 if crianca else 0.33
	capsule.height = 1.1 if crianca else 1.6
	shape.shape = capsule
	shape.position = Vector3(0, capsule.height / 2.0, 0)
	_body.add_child(shape)
	add_child(_body)


## Começa a vida dele (a Vida chama quando a navegação está pronta).
func start(at_home: bool) -> void:
	if at_home or not _awake():
		_enter_home()
	else:
		visible = true
		_choose_next()


func _physics_process(delta: float) -> void:
	if vida == null:
		return
	match estado:
		Estado.EM_CASA:
			_timer -= delta
			if _timer <= 0.0:
				_timer = 20.0
				if _awake():
					global_position = casa
					visible = true
					_body.process_mode = Node.PROCESS_MODE_INHERIT
					_choose_next()
		Estado.INDO:
			_walk(delta)
		Estado.FAZENDO:
			_timer -= delta
			_look_around(delta)
			if _timer <= 0.0:
				_choose_next()
		Estado.CONVERSANDO:
			_talk(delta)


# --- andar --------------------------------------------------------------------------------------------

func go_to(target: Vector3, what: Dictionary) -> void:
	ponto = what
	_path = vida.path(global_position, target)
	_step = 0
	estado = Estado.INDO
	_set_anim(&"Running_A" if crianca or what.get("corre", false) else &"Walking_A")
	if _path.is_empty():
		_arrive()


func _walk(delta: float) -> void:
	if _step >= _path.size():
		_arrive()
		return
	var target := _path[_step]
	target.y = global_position.y
	var to := target - global_position
	var player := vida.player()
	# você na frente: espera um pouco (e às vezes reclama), depois contorna
	if player and _yield_time <= 0.0:
		var me_to_you := player.global_position - global_position
		me_to_you.y = 0.0
		if me_to_you.length() < 1.1 and to.length() > 0.05 and me_to_you.normalized().dot(to.normalized()) > 0.6:
			_yield_time = 0.8
			_set_anim(&"Idle")
			vida.react_blocked(self)
	if _yield_time > 0.0:
		_yield_time -= delta
		if _yield_time <= 0.0:
			# dá a volta: um passo para o lado antes de seguir
			var side := to.normalized().cross(Vector3.UP) * (0.9 if randf() < 0.5 else -0.9)
			_path.insert(_step, global_position + side + to.normalized() * 0.6)
			_set_anim(&"Running_A" if crianca else &"Walking_A")
		return
	var speed := velocidade * (2.1 if crianca or ponto.get("corre", false) else 1.0)
	var move := speed * delta
	if to.length() <= move:
		global_position = target
		_step += 1
	else:
		global_position += to.normalized() * move
		_turn_to(to, delta * 8.0)


func _turn_to(dir: Vector3, weight: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(weight, 0.0, 1.0))


func _arrive() -> void:
	var kind := String(ponto.get("tipo", "rua"))
	if kind == "casa":
		_enter_home()
		return
	if kind == "loja":
		# entra na loja um tempo (some na porta) e depois sai
		visible = false
		_body.process_mode = Node.PROCESS_MODE_DISABLED
		estado = Estado.FAZENDO
		_timer = randf_range(12.0, 35.0)
		ponto = {"tipo": "saindo_da_loja"}
		return
	if kind == "conversa" and vida.find_partner(self):
		return
	estado = Estado.FAZENDO
	var look: Variant = ponto.get("olhar")
	if look is Vector3:
		_turn_to((look as Vector3) - global_position, 1.0)
	var anims: Array = ponto.get("anims", ["Idle"])
	_set_anim(StringName(anims[randi() % anims.size()]))
	_timer = randf_range(float(ponto.get("min", 4.0)), float(ponto.get("max", 12.0)))
	if randf() < float(ponto.get("emote_chance", 0.15)):
		var emotes: Array = ponto.get("emotes", ["..."])
		Emote.play(self, String(emotes[randi() % emotes.size()]))


func _look_around(delta: float) -> void:
	if String(ponto.get("tipo", "")) == "saindo_da_loja" and _timer <= 0.1:
		visible = true
		_body.process_mode = Node.PROCESS_MODE_INHERIT
	# de vez em quando vira a cabeça (o corpo inteiro, devagar) para olhar outra coisa
	if randf() < delta * 0.08 and String(ponto.get("tipo", "")) in ["praca", "olhar"]:
		rotation.y += randf_range(-0.9, 0.9)


func _choose_next() -> void:
	if not _awake():
		go_to(casa, {"tipo": "casa"})
		return
	var next := vida.pick_spot(self)
	if next.is_empty():
		estado = Estado.FAZENDO
		_timer = 3.0
		return
	go_to(next["pos"], next)


func _enter_home() -> void:
	estado = Estado.EM_CASA
	visible = false
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_timer = randf_range(5.0, 30.0)


func _awake() -> bool:
	var h := Game.hora
	return h >= acorda and h < dorme if acorda < dorme else (h >= acorda or h < dorme)


# --- conversa -----------------------------------------------------------------------------------------

## Começa a conversar com outro (os dois de frente, gestos e balões alternados).
func begin_talk(other: Passante, seconds: float) -> void:
	parceiro = other
	estado = Estado.CONVERSANDO
	_timer = seconds
	_talk_beat = randf_range(0.5, 2.0)
	_set_anim(&"Idle")


func _talk(delta: float) -> void:
	if parceiro == null or not is_instance_valid(parceiro) or parceiro.parceiro != self:
		parceiro = null
		_choose_next()
		return
	_turn_to(parceiro.global_position - global_position, delta * 5.0)
	_timer -= delta
	_talk_beat -= delta
	if _talk_beat <= 0.0:
		_talk_beat = randf_range(2.0, 4.5)
		var gesture: Array[StringName] = [&"Interact", &"Idle", &"Cheer", &"Idle", &"Use_Item"]
		_set_anim(gesture[randi() % gesture.size()])
		if randf() < 0.45:
			Emote.play(self, ["...", "...", "nota", "?", "!"][randi() % 5], 1.6)
	if _timer <= 0.0:
		var other := parceiro
		parceiro = null
		if other and is_instance_valid(other):
			other.parceiro = null
		_choose_next()


# --- reações ------------------------------------------------------------------------------------------

## Susto: você passou correndo do lado (pula para trás, balão de susto).
func startle() -> void:
	if estado == Estado.EM_CASA or not visible:
		return
	Emote.play(self, "susto" if randf() < 0.5 else "!", 1.4)
	var player := vida.player()
	if player:
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() > 0.01:
			var tween := create_tween()
			tween.tween_property(self, "global_position", global_position + away.normalized() * 0.45, 0.2)


func _set_anim(anim: StringName) -> void:
	if _fig == null or _anim == String(anim):
		return
	_anim = String(anim)
	_fig.set("animacao", _anim)
