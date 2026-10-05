class_name Interactable
extends Area3D
## Algo que o jogador pode examinar ou com quem pode conversar.
## Arraste a cena interactable.tscn para a fase, ajuste o tamanho da área e escreva as falas no Inspector.

signal interacted

## Texto do aviso que aparece perto ("E  Examinar").
@export var prompt: String = "Examinar"
## Nome de quem fala. Vazio = pensamento/narração, sem nome em cima.
@export var speaker: String = ""
## Uma fala por item; avança com a tecla de interagir.
@export var lines: PackedStringArray = []
## Desligado = o jogador passa e não aparece nada.
@export var enabled: bool = true


func interact() -> void:
	interacted.emit()
	Dialogue.start(speaker, lines)
