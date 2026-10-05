class_name Door
extends Interactable
## Porta: leva para outra fase. Trancada (ou sem destino) só mostra as falas.

## Fase de destino (.tscn).
@export_file("*.tscn") var target_scene: String = ""
## Nome do Marker2D em "Spawns" da fase de destino.
@export var target_spawn: String = ""
@export var locked: bool = false


func interact() -> void:
	if locked or target_scene == "":
		super()
		return
	interacted.emit()
	Game.change_level(target_scene, target_spawn)
