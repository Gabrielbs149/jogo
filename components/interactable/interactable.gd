class_name Interactable
extends Area2D
## Algo que o jogador pode examinar ou com quem pode conversar.
## Arraste interactable.tscn para a fase, ajuste a área e escreva as falas no Inspector.

signal interacted

## Texto do aviso que aparece perto ("E  examinar").
@export var prompt: String = "examinar"
## Nome de quem fala. Vazio = pensamento do personagem, sem nome em cima.
@export var speaker: String = ""
## Retrato na caixa de diálogo (32x32). Vazio = sem retrato.
@export var portrait: Texture2D
## Uma fala por item; avança com E.
@export var lines: PackedStringArray = []
## Desligado = o jogador passa e não aparece nada.
@export var enabled: bool = true


func interact() -> void:
	interacted.emit()
	Dialogue.start(speaker, lines, portrait)
