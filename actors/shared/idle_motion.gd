extends Node3D
## Movimento parado: flutua para cima e para baixo e/ou gira devagar (sentinelas, pedras vivas, burros).

@export var bob_height: float = 0.12
@export var bob_speed: float = 1.4
@export var spin_speed: float = 0.0

var _base_y: float
var _time: float


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height
	rotation.y += spin_speed * delta
