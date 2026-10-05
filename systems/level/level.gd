class_name Level
extends Node2D
## Raiz de toda fase. Diz se é escura e até onde a câmera vai, e põe o jogador no spawn certo.
## Spawns são Marker2D dentro de um nó "Spawns"; scale.x = -1 no marcador = começa olhando para a esquerda.

## Escura = só contornos, luz fraca em volta do personagem. Clara = névoa.
@export var dark: bool = false
@export var camera_left: int = 0
@export var camera_right: int = 320
## Spawn usado quando a fase é aberta direto (F5/F6) ou sem destino.
@export var default_spawn: String = "Start"

@onready var _player: Player = $Player


func _ready() -> void:
	Screen.set_dark(dark, true)
	var spawn_name := Game.pending_spawn if Game.pending_spawn != "" else default_spawn
	Game.pending_spawn = ""
	var spawn := get_node_or_null("Spawns/" + spawn_name) as Node2D
	if spawn:
		_player.global_position = spawn.global_position
		_player.face(-1 if spawn.scale.x < 0.0 else 1)
		_player.reset_physics_interpolation()
	_player.set_camera_limits(camera_left, camera_right)
