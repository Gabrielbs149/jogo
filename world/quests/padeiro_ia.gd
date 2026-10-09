class_name PadeiroIA
extends Node
## O padeiro anda pela padaria (D058): atende no balcão olhando os fregueses e, de tempos em tempos, vai trabalhar no
## forno, na mesa de sovar e nas prateleiras, de costas para o balcão. Vai como filho do padeiro (o nó dele com Figure
## e Talk). Os pontos são os Marker3D "Ponto*" da padaria (a frente do marcador é -Z).
## attending(): parado no balcão, de frente: dá para conversar. back_turned(): trabalhando de costas: dá para roubar.

## A padaria (world/props/padaria.tscn), com os marcadores dos pontos.
@export var padaria: Node3D
## Metros por segundo andando.
@export var speed: float = 1.3
## O caminho: ponto e quantos segundos fica lá. Volta ao começo no fim.
@export var rota: Array[Dictionary] = [
	{"ponto": "PontoBalcao", "tempo": 7.0},
	{"ponto": "PontoForno", "tempo": 5.0},
	{"ponto": "PontoMesa", "tempo": 5.0},
	{"ponto": "PontoBalcao", "tempo": 6.0},
	{"ponto": "PontoPrateleira", "tempo": 4.5},
]
## Passagens (no espaço da padaria) para não atravessar o balcão nem a mesa: a cozinha tem um corredor na frente da
## mesa; as prateleiras ficam do lado de lá da mesa.
const CORREDOR := Vector3(-0.6, 0, 0.45)
const LADO_PRATELEIRA := Vector3(1.9, 0, 0.6)
## Animação de cada ponto (KayKit) e a de andar.
const TRABALHO := {"PontoBalcao": "Unarmed_Idle", "PontoForno": "Interact", "PontoMesa": "Use_Item", "PontoPrateleira": "PickUp"}
const ANDAR := "Walking_A"

var _baker: Node3D
var _figure: Node
var _step: int = 0
var _path: Array[Vector3] = []
var _at: String = ""
var _wait: float = 0.0
var _turning: float = 0.0
var _hold: bool = false
var _face_to: Variant = null  # ponto para onde olhar quando parado por fora (pego no flagra)


func _ready() -> void:
	_baker = get_parent() as Node3D
	_figure = _baker.get_node_or_null("Figure")
	if Level.editing or padaria == null:
		set_physics_process(false)
		return
	_go_to(0, true)


## Parado no balcão, de frente para os fregueses.
func attending() -> bool:
	return _at == "PontoBalcao" and _path.is_empty() and _turning <= 0.0


## Trabalhando num ponto de costas para o balcão (e longe dele).
func back_turned() -> bool:
	return _at != "" and _at != "PontoBalcao" and _path.is_empty() and _turning <= 0.0 and _face_to == null


## Para onde ele está (fica parado durante a conversa).
func hold(on: bool) -> void:
	_hold = on


## Vira para um ponto (pego no flagra) e fica olhando uns segundos; depois volta ao serviço.
func look_at_thief(point: Vector3, seconds: float = 3.0) -> void:
	_face_to = point
	_set_anim("Unarmed_Idle")
	_wait = maxf(_wait, seconds)
	await get_tree().create_timer(seconds).timeout
	_face_to = null


func _physics_process(delta: float) -> void:
	if _face_to != null:
		_turn_towards((_face_to as Vector3) - _baker.global_position, delta * 8.0)
		return
	if _hold:
		return
	if not _path.is_empty():
		var goal := _path[0]
		var to := goal - _baker.global_position
		to.y = 0.0
		var dist := to.length()
		if dist < 0.06:
			_path.pop_front()
			if _path.is_empty():
				_arrive()
			return
		var move := minf(dist, speed * delta)
		_baker.global_position += to / dist * move
		_turn_towards(to, delta * 10.0)
		return
	if _turning > 0.0:
		_turning -= delta
		var marker := _marker(_at)
		if marker:
			_turn_towards(-marker.global_basis.z, delta * 8.0)
		return
	_wait -= delta
	if _wait <= 0.0:
		_go_to((_step + 1) % rota.size(), false)


func _go_to(index: int, instant: bool) -> void:
	_step = index
	var target := String(rota[index]["ponto"])
	var marker := _marker(target)
	if marker == null:
		return
	_at = ""
	if instant:
		_baker.global_transform = Transform3D(_baker.global_basis, marker.global_position)
		_path.clear()
		_arrive_at(target)
		return
	_path.clear()
	var here := padaria.to_local(_baker.global_position)
	var there := padaria.to_local(marker.global_position)
	# do balcão para a cozinha (e de volta) passa pelo corredor; as prateleiras, pelo lado de lá da mesa
	var via: Array[Vector3] = [CORREDOR]
	if target == "PontoPrateleira" or here.distance_to(Vector3(2.1, 0, 3.85)) < 0.5:
		via.append(LADO_PRATELEIRA)
		if target != "PontoPrateleira":
			via.reverse()
	for v: Vector3 in via:
		if v.distance_to(here) > 0.3 and v.distance_to(there) > 0.3:
			_path.append(padaria.to_global(v))
	_path.append(marker.global_position)
	_set_anim(ANDAR)
	_pending = target


var _pending: String = ""


func _arrive() -> void:
	_arrive_at(_pending)


func _arrive_at(target: String) -> void:
	_at = target
	_wait = float(rota[_step]["tempo"])
	_turning = 0.35
	_set_anim(String(TRABALHO.get(target, "Unarmed_Idle")))
	if target == "PontoBalcao" and _path.is_empty():
		var marker := _marker(target)
		if marker:
			_baker.global_basis = Basis(Vector3.UP, atan2(marker.global_basis.z.x, marker.global_basis.z.z))


func _turn_towards(dir: Vector3, weight: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var yaw := atan2(-dir.x, -dir.z)
	var rot := _baker.rotation
	rot.y = lerp_angle(rot.y, yaw, clampf(weight, 0.0, 1.0))
	_baker.rotation = rot


func _set_anim(anim: String) -> void:
	if _figure and String(_figure.get("animacao")) != anim:
		_figure.set("animacao", anim)


func _marker(point: String) -> Node3D:
	return padaria.get_node_or_null(point) as Node3D if padaria else null
