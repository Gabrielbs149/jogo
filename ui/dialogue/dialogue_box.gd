class_name DialogueBox
extends Control
## Caixa de conversa das missões (D040): nome de quem fala, o texto aparecendo aos poucos e, quando há escolha,
## as opções numeradas (tecla 1..9 ou clique). F, Espaço, Enter ou clique passam a fala.
##   await dialogue.say("Padeiro", "Ou compra, ou sai da frente.")
##   var i: int = await dialogue.choose("Padeiro", "E aí?", ["Conversar", "Ir embora"])
## Nos testes: instant = true pula as esperas e auto_answers dá as escolhas em ordem.

signal _advanced
signal _picked(index: int)

## Letras por segundo do texto aparecendo.
@export var chars_per_second: float = 55.0

var instant: bool = false
var auto_answers: Array[int] = []
## Tudo que foi dito (para os testes conferirem).
var history: PackedStringArray = []

var _typing: Tween
var _waiting: bool = false
var _choosing: bool = false

@onready var _speaker: Label = %Speaker
@onready var _text: RichTextLabel = %Text
@onready var _choices: VBoxContainer = %Choices
@onready var _hint: Control = %Hint
@onready var _panel: PanelContainer = $Panel


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		instant = true


## Uma fala. speaker vazio = narração. Aceita BBCode ([color=...]).
func say(speaker: String, text: String) -> void:
	history.append(("%s: %s" % [speaker, text]) if speaker != "" else text)
	if instant:
		return
	_show_line(speaker, text)
	_hint.show()
	_waiting = true
	await _advanced
	_waiting = false


## Uma fala com escolhas. Devolve o índice da opção escolhida.
func choose(speaker: String, text: String, options: Array) -> int:
	history.append(("%s: %s" % [speaker, text]) if speaker != "" else text)
	if instant:
		var pick: int = auto_answers.pop_front() if not auto_answers.is_empty() else options.size() - 1
		history.append("> " + String(options[pick]))
		return pick
	_show_line(speaker, text)
	_hint.hide()
	for child: Node in _choices.get_children():
		child.queue_free()
	for i: int in options.size():
		var button := Button.new()
		button.theme_type_variation = &"MenuItem"
		button.add_theme_font_size_override("font_size", 19)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "      " + String(options[i])
		var key := OptionsMenu.keycap(str(i + 1))
		key.position = Vector2(12, 12)
		button.add_child(key)
		button.pressed.connect(func() -> void: _picked.emit(i))
		_choices.add_child(button)
	_choices.show()
	_fit.call_deferred()
	_choosing = true
	if _typing:
		_typing.kill()
	_text.visible_ratio = 1.0
	(_choices.get_child(0) as Button).grab_focus.call_deferred()
	var picked: int = await _picked
	_choosing = false
	_choices.hide()
	_fit.call_deferred()
	history.append("> " + String(options[picked]))
	return picked


func close() -> void:
	hide()


func _show_line(speaker: String, text: String) -> void:
	show()
	_choices.hide()
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_text.text = text
	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	var length := _text.get_total_character_count()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.15, length / chars_per_second))
	Audio.play("fala", -14.0, 0.1)
	_fit.call_deferred()


## A caixa fica do tamanho do que mostra, presa embaixo (sem espaço vazio em cima).
func _fit() -> void:
	# o tamanho mínimo dos filhos (escolhas que somem, texto novo) só atualiza no quadro seguinte
	for i: int in 2:
		_panel.offset_top = _panel.offset_bottom - _panel.get_combined_minimum_size().y
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _choosing and event is InputEventKey and event.is_pressed() and not event.is_echo():
		var n := (event as InputEventKey).keycode - KEY_1
		if n >= 0 and n < _choices.get_child_count():
			get_viewport().set_input_as_handled()
			_picked.emit(n)
		return
	var go := event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") \
		or (event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if _waiting and go:
		get_viewport().set_input_as_handled()
		if _text.visible_ratio < 1.0:
			if _typing:
				_typing.kill()
			_text.visible_ratio = 1.0  # primeiro toque mostra a fala inteira
		else:
			_advanced.emit()
