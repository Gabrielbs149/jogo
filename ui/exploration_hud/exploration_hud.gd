class_name ExplorationHUD
extends CanvasLayer
## Interface da exploração: retratos do grupo (clique ou F1-F5 escolhe o líder), painel de história
## (inscrições lidas, mensagens) e dicas de controle.

## Quanto tempo o painel de história fica na tela (segundos).
@export var story_time: float = 9.0

var _party: PartyController
var _buttons: Array[Button] = []
var _story_tween: Tween

@onready var _portraits: VBoxContainer = %Portraits
@onready var _story: PanelContainer = %Story
@onready var _story_text: Label = %StoryText
@onready var _area: Label = %AreaName


func setup(party: PartyController) -> void:
	_party = party
	party.leader_changed.connect(func(_u: Unit) -> void: _refresh())
	for i: int in party.heroes.size():
		var unit := party.heroes[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(230, 46)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(party.select.bind(i))
		unit.changed.connect(_refresh)
		_portraits.add_child(button)
		_buttons.append(button)
	_refresh()


func show_area(area_name: String) -> void:
	_area.text = area_name
	_area.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_area, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.5)
	tween.tween_property(_area, "modulate:a", 0.0, 1.2)


func show_story(text: String) -> void:
	if text == "":
		return
	_story_text.text = text
	_story.show()
	_story.modulate.a = 0.0
	if _story_tween:
		_story_tween.kill()
	_story_tween = create_tween()
	_story_tween.tween_property(_story, "modulate:a", 1.0, 0.3)
	_story_tween.tween_interval(story_time)
	_story_tween.tween_property(_story, "modulate:a", 0.0, 0.6)
	_story_tween.tween_callback(_story.hide)


func _ready() -> void:
	_story.hide()
	_area.modulate.a = 0.0


func _refresh() -> void:
	if _party == null:
		return
	for i: int in _buttons.size():
		var unit := _party.heroes[i]
		var mark := "▸ " if unit == _party.leader else "   "
		_buttons[i].text = "%sF%d  %s   %d/%d" % [mark, i + 1, unit.display_name, unit.hp, unit.max_hp]
		_buttons[i].set_pressed_no_signal(unit == _party.leader)
		_buttons[i].toggle_mode = true
		_buttons[i].button_pressed = unit == _party.leader
