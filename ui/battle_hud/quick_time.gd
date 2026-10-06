class_name QuickTime
extends Control
## O anel que fecha: aperte a tecla quando o anel de fora encostar no de dentro.
## run() devolve {"key": a ação apertada (vazio = não apertou), "error": segundos (negativo = cedo, positivo = tarde)}.

signal _done(result: Dictionary)

@export var ring_color: Color = Color(1.0, 0.85, 0.5)
@export var target_color: Color = Color(1.0, 1.0, 1.0, 0.85)
## Quanto tempo depois do encontro ainda vale apertar (tarde).
@export var late_window: float = 0.3
@export var radius: float = 34.0

var _active: bool = false
var _t: float = 0.0
var _duration: float = 0.8
var _keys: Array[StringName] = []
var _label: String = ""
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func run(center: Vector2, duration: float, keys: Array[StringName], label: String) -> Dictionary:
	_center = center
	_duration = maxf(duration, 0.2)
	_keys = keys
	_label = label
	_t = 0.0
	_active = true
	show()
	queue_redraw()
	var result: Dictionary = await _done
	hide()
	return result


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	queue_redraw()
	if _t > _duration + late_window:
		_finish(&"", _t - _duration)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	for key: StringName in _keys:
		if event.is_action_pressed(key):
			get_viewport().set_input_as_handled()
			_finish(key, _t - _duration)
			return


func _finish(key: StringName, error: float) -> void:
	if not _active:
		return
	_active = false
	_done.emit({"key": key, "error": error})


func _draw() -> void:
	if not _active:
		return
	draw_arc(_center, radius, 0.0, TAU, 48, target_color, 4.0, true)
	var closing := clampf((_duration - _t) / _duration, 0.0, 1.0)
	var r := radius * (1.0 + 2.4 * closing)
	if _t > _duration:
		r = radius * (1.0 - 0.5 * (_t - _duration) / late_window)
	draw_arc(_center, r, 0.0, TAU, 48, ring_color, 3.0, true)
	var font := get_theme_default_font()
	var size := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(font, _center + Vector2(-size.x / 2.0, radius + 34.0), _label, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, ring_color)
