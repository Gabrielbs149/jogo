class_name Morador
extends Node3D
## Morador que fica no lugar dele (D060): o freguês na banca, o ferreiro na bigorna, o pessoal da taverna, o guarda.
## Tem horário (fora dele vai para casa: some), troca de gesto de tempos em tempos (não fica a vida inteira na mesma
## animação), solta um balão de vez em quando, olha para você quando você chega perto e, se for vendedor, grita o
## pregão quando você está por perto. Ponha na raiz da pessoa (com o Figurante "Figure" dentro).

## Horas em que está ali (de/até). Iguais = o dia inteiro.
@export var de: float = 0.0
@export var ate: float = 0.0
## Gestos que vai trocando (animações do KayKit).
@export var gestos: Array[String] = ["Idle"]
## Segundos em cada gesto (mín/máx).
@export var troca: Vector2 = Vector2(5.0, 12.0)
## Balões que solta de vez em quando.
@export var emotes: Array[String] = []
## Pregão (vendedor): frases que grita quando você está a menos de 14 m.
@export var pregao: Array[String] = []
## Som que toca a cada gesto "de trabalho" (o martelo do ferreiro) e o gesto que faz o som.
@export var som: String = ""
@export var gesto_do_som: String = ""
## Vira para olhar você quando você chega perto.
@export var olha: bool = true

var _fig: Node3D
var _timer: float = 0.0
var _shout: float = 0.0
var _sound: float = 0.0
var _home_yaw: float = 0.0
var _greeted: bool = false
var _level: Level
var _here: bool = true


func _ready() -> void:
	if Level.editing:
		set_process(false)
		return
	_fig = get_node_or_null("Figure") as Node3D
	_home_yaw = rotation.y
	_timer = randf_range(0.5, troca.y)
	_shout = randf_range(3.0, 10.0)
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	_level = node as Level


func _process(delta: float) -> void:
	var here := _in_hours()
	if here != _here:
		_here = here
		visible = here
		for found: Node in find_children("*", "CollisionObject3D", true, false):
			(found as Node).process_mode = Node.PROCESS_MODE_INHERIT if here else Node.PROCESS_MODE_DISABLED
	if not here:
		return
	_timer -= delta
	if _timer <= 0.0 and not gestos.is_empty():
		_timer = randf_range(troca.x, troca.y)
		var gesture := gestos[randi() % gestos.size()]
		if _fig:
			_fig.set("animacao", gesture)
		if not emotes.is_empty() and randf() < 0.25:
			Emote.play(self, emotes[randi() % emotes.size()])
	# o martelo: um som a cada batida enquanto está no gesto de trabalho
	if som != "" and _fig and String(_fig.get("animacao")) == gesto_do_som:
		_sound -= delta
		if _sound <= 0.0:
			_sound = 0.9
			Audio.play_at(som, global_position + Vector3.UP, -10.0, 0.12)
	var me: Node3D = _level.player if _level else null
	if me == null:
		return
	var d := global_position.distance_to(me.global_position)
	if olha:
		if d < 3.5:
			var to := me.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 3.0))
			if not _greeted and randf() < 0.5:
				Emote.play(self, ["!", "nota", "..."][randi() % 3], 1.5)
			_greeted = true
		else:
			rotation.y = lerp_angle(rotation.y, _home_yaw, minf(1.0, delta * 1.5))
			if d > 8.0:
				_greeted = false
	if not pregao.is_empty() and d < 14.0:
		_shout -= delta
		if _shout <= 0.0:
			_shout = randf_range(7.0, 13.0)
			Fala.say(self, pregao[randi() % pregao.size()], 2.8)


func _in_hours() -> bool:
	if is_equal_approx(de, ate):
		return true
	var h := Game.hora
	return h >= de and h < ate if de < ate else (h >= de or h < ate)
