class_name Encounter
extends Node3D
## Lugar de luta: quando o líder do grupo chega a menos de `radius` metros, começa o combate por turnos
## com os inimigos que são filhos deste nó. A grade da batalha é centralizada aqui.

## Distância (m) em que os inimigos percebem o grupo.
@export var radius: float = 13.0
@export var grid_size: Vector2i = Vector2i(18, 14)

var done: bool = false


func _ready() -> void:
	add_to_group("encounter")


func enemies() -> Array[Unit]:
	var result: Array[Unit] = []
	for child: Node in get_children():
		var unit := child as Unit
		if unit and unit.is_alive():
			result.append(unit)
	return result
