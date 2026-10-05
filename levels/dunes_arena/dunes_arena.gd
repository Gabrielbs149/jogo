extends Node3D
## Arena nas dunas: cria a colisão do terreno, mostra a abertura do capítulo, começa a batalha e
## reinicia com R. Os textos da história ficam no Inspector deste nó.

@export var chapter_title: String = "Ruínas de Ethera"
## Frases da abertura, uma por item.
@export var intro_lines: PackedStringArray = []
@export_multiline var victory_text: String = ""
@export_multiline var defeat_text: String = ""
## Pula a abertura (testes e simulação também pulam, por rodarem sem janela).
@export var skip_intro: bool = false

@onready var _terrain: MeshInstance3D = $Terrain
@onready var _combat: CombatManager = $Combat
@onready var _hud: CombatHUD = $HUD


func _ready() -> void:
	_terrain.create_trimesh_collision()
	_hud.set_result_texts(victory_text, defeat_text)
	if skip_intro or DisplayServer.get_name() == "headless" or intro_lines.is_empty():
		_combat.start()
		return
	await _hud.play_intro(chapter_title, intro_lines)
	_combat.start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
