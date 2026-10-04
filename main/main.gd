extends Node
## Cena de entrada: carrega a primeira fase. Qual fase é se escolhe no Inspector (first_level).

@export var first_level: PackedScene


func _ready() -> void:
	if first_level == null:
		push_error("Main: escolha a first_level no Inspector.")
		return
	add_child(first_level.instantiate())
