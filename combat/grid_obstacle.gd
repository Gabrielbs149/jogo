class_name GridObstacle
extends Node3D
## Marca as casas da grade que este objeto ocupa (ruína, pilar, rocha). Bloqueia andar e linha de visão.
## Coloque como raiz da ruína na fase; a casa é a da posição do nó, e o footprint cresce a partir dela.

## Tamanho em casas (largura x profundidade), a partir da casa onde o nó está.
@export var footprint: Vector2i = Vector2i(1, 1)
## Texto gravado na pedra. Aparece quando o mouse passa por cima (fragmentos da história).
@export_multiline var inscription: String = ""


func _ready() -> void:
	add_to_group("grid_obstacle")
