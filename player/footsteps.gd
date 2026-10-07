class_name Footsteps
extends Node
## Passos de quem anda (D034): um som a cada passada, do tipo do chão onde a pessoa está.
## O chão vem da fase (`Level.surface_at`: grama, pedra, terra, areia). Vai como filho do Combatant.

## Metros por passada no ritmo normal (corrida encurta um pouco).
@export var stride: float = 0.75
@export var volume_db: float = -5.0

var _me: Combatant
var _travel: float = 0.0
var _level: Node


func _ready() -> void:
	_me = get_parent() as Combatant
	_level = _me.get_parent()
	while _level and not _level.has_method("surface_at"):
		_level = _level.get_parent()


func _physics_process(delta: float) -> void:
	if _me == null or _me.downed or not _me.is_on_floor():
		_travel = 0.0
		return
	var speed := Vector2(_me.velocity.x, _me.velocity.z).length()
	if speed < 0.4:
		_travel = stride * 0.6  # o primeiro passo depois de parado sai logo
		return
	_travel += speed * delta
	var step := stride * (0.85 if speed > _me.move_speed * 1.1 else 1.0)
	if _travel >= step:
		_travel = 0.0
		var surface: String = _level.call("surface_at", _me.global_position) if _level else "grama"
		Audio.play_at("passo_" + surface, _me.global_position, volume_db + (2.0 if speed > _me.move_speed * 1.1 else 0.0))
