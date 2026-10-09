class_name Vida
extends Node3D
## A vida da cidade (D060): cria a gente que anda pelas ruas (Passante), cada um com casa, jeito e horário, e
## escolhe para onde cada um vai conforme a hora (bancas de manhã, praça à tarde, taverna à noite, casa para dormir).
## Junta duplas para conversar, faz as crianças brincarem, e cuida das reações a você (licença, susto, "bom dia").
## Os pontos (onde dá para ir) são Marker3D filhos de "Pontos", com metadados: tipo (rua, praca, banca, conversa,
## olhar, loja, casa, taverna, brincar), olhar (para onde vira), anims, min/max (segundos parado).
## A gente é sempre a mesma (sorteio com semente fixa): o padeiro de hoje é o mesmo amanhã.

## Quantas pessoas andando pela cidade (de dia; de noite a maioria está em casa).
@export var quantidade: int = 34
## Crianças brincando na praça.
@export var criancas: int = 3
@export var semente: int = 60
## Distância (m) em que alguém fala com você quando você passa.
@export var raio_fala: float = 2.6
## Uma fala de cada vez na cidade, com folga entre elas (s).
@export var folga_fala: float = 5.0

const MODELS: Array[String] = ["Rogue_Hooded", "Barbarian", "Rogue", "Mage", "Barbarian", "Rogue_Hooded", "Knight"]
const HUES: Array[float] = [-1.0, 0.08, 0.16, 0.3, 0.45, 0.55, 0.65, 0.78, 0.9]
## O que dizem quando você passa perto (pela hora do dia). *(proposta)*
const FALAS_DIA: Array[String] = ["Bom dia, pequeno.", "Olha o kobold do beco...", "Viu o preço da farinha?",
	"Sai da frente, lagartixa.", "Dizem que chegou gente nova perto da muralha.", "Hoje o dia tá bonito.",
	"Ô, Tico! Tá vivo ainda?", "Cuidado com a carteira, gente.", "Alguém viu meu gato?", "Hm."]
const FALAS_NOITE: Array[String] = ["Boa noite...", "Vai pra casa, pequeno. A noite tá estranha.", "Tá tarde pra andar por aí.",
	"Ouviu isso? ...Nada. Deve ser o vento.", "As estrelas tão esquisitas hoje."]
const FALAS_ESBARRAO: Array[String] = ["Licença!", "Ô, olha por onde anda!", "Com licença, pequeno.", "Ei!", "Dá passagem?"]
const FALAS_SUSTO: Array[String] = ["Ai! Que susto!", "Calma, pequeno!", "Vai tirar o pai da forca?", "Devagar!"]

var people: Array[Passante] = []
var _spots: Array[Dictionary] = []
var _homes: Array[Vector3] = []
var _level: Level
var _rng := RandomNumberGenerator.new()
var _map: RID
var _last_talk: float = -99.0
var _clock: float = 0.0
var _check: float = 0.0


func _ready() -> void:
	if Level.editing:
		return
	_level = get_parent() as Level
	if _level == null:
		return
	_level.play_started.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	_map = get_world_3d().navigation_map
	# espera o mapa de navegação ficar pronto (a fase acabou de assar)
	for i: int in 30:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) > 0:
			break
	_read_spots()
	_spawn()


func _process(delta: float) -> void:
	_clock += delta
	_check -= delta
	if _check > 0.0 or _level == null or _level.player == null:
		return
	_check = 0.25
	var me := _level.player
	var running := Vector2(me.velocity.x, me.velocity.z).length() > me.move_speed * 1.15
	for person: Passante in people:
		if not person.visible:
			continue
		var d := person.global_position.distance_to(me.global_position)
		if running and d < 1.6 and randf() < 0.5:
			person.startle()
			_say(person, FALAS_SUSTO)
		elif d < raio_fala and randf() < 0.05:
			_say(person, FALAS_NOITE if _is_night() else FALAS_DIA)


# --- pontos e caminhos --------------------------------------------------------------------------------

func _read_spots() -> void:
	var holder := get_node_or_null("Pontos")
	if holder == null:
		return
	for child: Node in holder.get_children():
		var mark := child as Node3D
		if mark == null:
			continue
		var spot := {"pos": _snap(mark.global_position), "tipo": String(mark.get_meta("tipo", "rua"))}
		for key: String in ["anims", "min", "max", "emotes", "emote_chance", "horas", "peso"]:
			if mark.has_meta(key):
				spot[key] = mark.get_meta(key)
		if mark.has_meta("olhar"):
			spot["olhar"] = mark.get_meta("olhar")
		if spot["tipo"] == "casa":
			_homes.append(spot["pos"])
		else:
			_spots.append(spot)


func _snap(p: Vector3) -> Vector3:
	if not _map.is_valid():
		return p
	var on_map := NavigationServer3D.map_get_closest_point(_map, p)
	return on_map if on_map.distance_to(p) < 3.0 else p


## Caminho pelo mapa de navegação (vazio se não dá).
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not _map.is_valid():
		return PackedVector3Array([to])
	var route := NavigationServer3D.map_get_path(_map, from, to, true)
	if route.is_empty():
		return PackedVector3Array([to])
	return route


func player() -> Combatant:
	return _level.player if _level else null


# --- gente --------------------------------------------------------------------------------------------

func _spawn() -> void:
	_rng.seed = semente
	if _homes.is_empty():
		_homes.append(global_position)
	for i: int in quantidade + criancas:
		var kid := i >= quantidade
		var person := Passante.new()
		person.name = "Passante%d" % i
		person.crianca = kid
		var fig := Node3D.new()
		fig.name = "Figure"
		fig.set_script(load("res://world/figurante.gd"))
		var model := "Rogue" if kid and _rng.randf() < 0.6 else MODELS[_rng.randi() % MODELS.size()]
		fig.scale = Vector3.ONE * (_rng.randf_range(0.42, 0.47) if kid else _rng.randf_range(0.56, 0.66))
		person.add_child(fig)
		add_child(person)
		fig.set("personagem", model)
		fig.set("cor_roupa", HUES[_rng.randi() % HUES.size()])
		fig.set("sem_chapeu", _rng.randf() < 0.45)
		fig.set("sem_capa", _rng.randf() < 0.4)
		fig.set("na_mao", "Mug" if model == "Barbarian" and _rng.randf() < 0.3 else "")
		fig.set("animacao", "Idle")
		person.vida = self
		person.velocidade = _rng.randf_range(1.05, 1.5)
		person.casa = _homes[_rng.randi() % _homes.size()]
		# horários diferentes: uns madrugam, outros ficam até tarde (os da taverna)
		person.acorda = _rng.randf_range(6.0, 8.5)
		person.dorme = _rng.randf_range(18.5, 21.0) if _rng.randf() < 0.8 else _rng.randf_range(22.0, 23.8)
		if kid:
			person.acorda = _rng.randf_range(7.5, 9.0)
			person.dorme = _rng.randf_range(17.5, 18.5)
		# começam espalhados pela cidade (não todos saindo de casa juntos)
		var start: Dictionary = _spots[_rng.randi() % _spots.size()] if not _spots.is_empty() else {"pos": person.casa}
		person.global_position = start["pos"]
		person.rotation.y = _rng.randf() * TAU
		people.append(person)
		person.start(false)


## Para onde vai agora (pelo tipo de ponto, pela hora e pelo jeito da pessoa).
func pick_spot(person: Passante) -> Dictionary:
	if _spots.is_empty():
		return {}
	var h := Game.hora
	var wanted: Array[Dictionary] = []
	var weights: Array[float] = []
	for spot: Dictionary in _spots:
		var kind := String(spot["tipo"])
		var w := float(spot.get("peso", 1.0))
		if person.crianca:
			w *= 6.0 if kind == "brincar" else (0.4 if kind in ["praca", "rua"] else 0.0)
		else:
			if kind == "brincar":
				w = 0.0
			elif kind == "banca":
				w *= 2.2 if h < 13.0 else 0.8
			elif kind == "taverna":
				w *= 3.0 if h >= 17.0 else 0.1
			elif kind == "conversa" or kind == "praca":
				w *= 1.6 if h >= 11.0 and h < 18.0 else 0.8
			elif kind == "loja":
				w *= 1.2 if h >= 8.0 and h < 18.0 else 0.0
		if spot.has("horas"):
			var hours: Array = spot["horas"]
			if h < float(hours[0]) or h >= float(hours[1]):
				w = 0.0
		# perto pesa mais (ninguém atravessa a cidade toda o tempo todo)
		var d := person.global_position.distance_to(spot["pos"])
		w *= 1.0 / (1.0 + d / 45.0)
		if w > 0.0:
			wanted.append(spot)
			weights.append(w)
	if wanted.is_empty():
		return {}
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := randf() * total
	for k: int in wanted.size():
		roll -= weights[k]
		if roll <= 0.0:
			return wanted[k]
	return wanted[-1]


## Chegou num ponto de conversa: se tem alguém esperando por ali, os dois conversam.
func find_partner(person: Passante) -> bool:
	for other: Passante in people:
		if other == person or not other.visible or other.estado != Passante.Estado.FAZENDO or other.parceiro:
			continue
		if String(other.ponto.get("tipo", "")) != "conversa":
			continue
		if other.global_position.distance_to(person.global_position) < 3.0:
			var seconds := randf_range(10.0, 22.0)
			person.begin_talk(other, seconds)
			other.begin_talk(person, seconds)
			return true
	return false


## Você ficou no caminho de alguém.
func react_blocked(person: Passante) -> void:
	if randf() < 0.35:
		_say(person, FALAS_ESBARRAO)


func _say(person: Node3D, lines: Array) -> void:
	if _clock - _last_talk < folga_fala:
		return
	_last_talk = _clock
	var line := String(lines[randi() % lines.size()])
	Fala.say(person, line)


func _is_night() -> bool:
	return Game.hora >= 19.5 or Game.hora < 6.0
