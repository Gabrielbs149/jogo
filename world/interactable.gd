class_name Interactable
extends Node3D
## Algo que se usa de perto com F: inscrição na pedra (lê um pedaço da história), fogueira (descansa),
## herói encontrado no caminho (conversa e chama para o grupo). A fase escuta o sinal "used".

signal used(by: Combatant, what: Interactable)

enum Action { READ, REST, TALK }

@export var action: Action = Action.READ
## O que aparece na tela: "F · Ler a inscrição".
@export var prompt_text: String = "Ler a inscrição"
## Texto da inscrição (READ) ou do descanso (REST).
@export_multiline var text: String = ""

var enabled: bool = true


func _ready() -> void:
	add_to_group("interactable")


func is_available() -> bool:
	return enabled and is_visible_in_tree()


func interact(by: Combatant) -> void:
	used.emit(by, self)
