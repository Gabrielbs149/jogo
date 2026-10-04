extends Node
## Cena de entrada. Por enquanto só prova que o projeto roda; vira o boot/menu quando o jogo existir.


func _ready() -> void:
	print("Projeto rodando: Godot %s" % Engine.get_version_info().string)
