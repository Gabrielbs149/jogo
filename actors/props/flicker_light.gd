extends OmniLight3D
## Luz de fogo: tremula sozinha (fogueira, braseiro).

@export var base_energy: float = 3.0
@export var flicker: float = 0.35
@export var speed: float = 9.0

var _time: float


func _ready() -> void:
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = base_energy * (1.0 + (sin(_time) * 0.5 + sin(_time * 2.7) * 0.3 + sin(_time * 5.3) * 0.2) * flicker)
