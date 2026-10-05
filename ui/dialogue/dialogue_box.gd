class_name DialogueBox
extends CanvasLayer
## Caixa de diálogo + aviso de interação (autoload "Dialogue").
## Qualquer coisa chama Dialogue.start(speaker, lines, portrait). O Player fica parado enquanto is_open().

signal started
signal finished

## Velocidade do texto aparecendo (letras por segundo).
@export var characters_per_second: float = 30.0

var _lines: PackedStringArray = []
var _index: int = 0
var _open: bool = false
var _typing: bool = false
var _shown_characters: float = 0.0
var _blink: float = 0.0

@onready var _panel: Control = %Panel
@onready var _portrait: TextureRect = %Portrait
@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _continue: Label = %Continue
@onready var _prompt: Control = %Prompt
@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	_panel.hide()
	_prompt.hide()


func is_open() -> bool:
	return _open


func start(speaker: String, lines: PackedStringArray, portrait: Texture2D = null) -> void:
	if _open or lines.is_empty():
		return
	_open = true
	_lines = lines
	_index = 0
	hide_prompt()
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_portrait.texture = portrait
	_portrait.get_parent().visible = portrait != null
	_panel.show()
	_show_line()
	started.emit()


func show_prompt(text: String) -> void:
	if _open:
		return
	_prompt_label.text = "E  %s" % text
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
	if not _open:
		return
	if _typing:
		_shown_characters += characters_per_second * delta
		_text.visible_characters = int(_shown_characters)
		if _text.visible_characters >= _text.get_total_character_count():
			_finish_typing()
	else:
		# Indicador de "continua" pisca devagar
		_blink += delta
		_continue.visible = fmod(_blink, 1.0) < 0.6


func _show_line() -> void:
	_text.text = _lines[_index]
	_text.visible_characters = 0
	_shown_characters = 0.0
	_typing = true
	_continue.hide()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_blink = 0.0
	_continue.show()


func _next_line() -> void:
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	_open = false
	_panel.hide()
	finished.emit()
