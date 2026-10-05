class_name DialogueBox
extends CanvasLayer
## Caixa de diálogo + aviso de interação. Registrado como autoload "Dialogue".
## Qualquer coisa chama Dialogue.start(speaker, lines). O Player fica parado enquanto is_open().

signal started
signal finished

## Velocidade do texto aparecendo (letras por segundo).
@export var characters_per_second: float = 32.0
## Duração do fade da caixa ao abrir/fechar (segundos).
@export var fade_time: float = 0.3

var _lines: PackedStringArray = []
var _index: int = 0
var _open: bool = false
var _typing: bool = false
var _shown_characters: float = 0.0
var _fade: Tween

@onready var _panel: Control = %Panel
@onready var _speaker: Label = %Speaker
@onready var _text: RichTextLabel = %Text
@onready var _continue: Label = %Continue
@onready var _prompt: Label = %Prompt


func _ready() -> void:
	_panel.modulate.a = 0.0
	_panel.hide()
	_prompt.hide()


func is_open() -> bool:
	return _open


func start(speaker: String, lines: PackedStringArray) -> void:
	if _open or lines.is_empty():
		return
	_open = true
	_lines = lines
	_index = 0
	hide_prompt()
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_panel.show()
	_fade_panel(1.0)
	_show_line()
	started.emit()


func show_prompt(text: String) -> void:
	if _open:
		return
	_prompt.text = "E   %s" % text
	_prompt.show()


func hide_prompt() -> void:
	_prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
	else:
		_next_line()


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown_characters += characters_per_second * delta
	_text.visible_characters = int(_shown_characters)
	if _text.visible_characters >= _text.get_total_character_count():
		_finish_typing()


func _show_line() -> void:
	_text.text = _lines[_index]
	_text.visible_characters = 0
	_shown_characters = 0.0
	_typing = true
	_continue.hide()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_continue.show()


func _next_line() -> void:
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	_open = false
	_fade_panel(0.0)
	finished.emit()


func _fade_panel(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_panel, "modulate:a", alpha, fade_time)
	if alpha == 0.0:
		_fade.tween_callback(_panel.hide)
