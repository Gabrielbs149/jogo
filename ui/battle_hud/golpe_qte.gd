class_name GolpeQte
extends Control
## O desafio de tempo da luta (D048, simplificado na D050): um anel só, bonito e claro.
## O anel de fora fecha sobre o anel dourado; aperte na hora em que encostam.
## - feint: o anel engana (fecha até a metade, abre de volta e só então fecha de verdade).
## - arrow (-1/+1): aparece uma seta e a tecla certa é A ou D (desvio para o lado).
## - step/steps: "golpe 2 de 3" (bolinhas embaixo).
## Devolve {"key": ação apertada (vazio = não apertou), "error": segundos (negativo = cedo)}.

signal _done(result: Dictionary)

@export var gold: Color = Color(1.0, 0.82, 0.38)
@export var late_window: float = 0.25
@export var radius: float = 42.0

var _active: bool = false
var _t: float = 0.0
var _center := Vector2.ZERO
var _label: String = ""
var _key_text: String = ""
var _duration: float = 0.7
var _keys: Array[StringName] = []
var _feint: bool = false
var _arrow: int = 0
var _step: int = 0
var _steps: int = 0
var _window: float = 0.1
# o "estalo" do resultado (desenhado depois que termina)
var _pop_t: float = -1.0
var _pop_color := Color.WHITE
var _pop_at := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func ring(center: Vector2, duration: float, keys: Array[StringName], label: String, feint: bool = false, arrow: int = 0,
		step: int = 0, steps: int = 0, window: float = 0.1) -> Dictionary:
	_duration = maxf(duration, 0.2) + (0.45 if feint else 0.0)
	_keys = keys
	_feint = feint
	_arrow = arrow
	_step = step
	_steps = steps
	_window = window
	_center = center
	_label = label
	_key_text = "A / D" if arrow != 0 else (" / ".join(PackedStringArray(keys.map(func(k: StringName) -> String: return _key_name(k)))))
	_t = 0.0
	_active = true
	show()
	queue_redraw()
	var result: Dictionary = await _done
	return result


## O estalo do resultado no lugar do anel: dourado (perfeito), branco (bom) ou vermelho (errou).
func pop(grade: String) -> void:
	_pop_t = 0.0
	_pop_at = _center
	_pop_color = {"perfeito": gold, "bom": Color(0.95, 0.95, 0.95)}.get(grade, Color(1.0, 0.4, 0.4)) as Color


func _finish(result: Dictionary) -> void:
	if not _active:
		return
	_active = false
	_done.emit(result)


func _process(delta: float) -> void:
	if _pop_t >= 0.0:
		_pop_t += delta
		if _pop_t > 0.45:
			_pop_t = -1.0
		queue_redraw()
	if not _active:
		return
	_t += delta
	queue_redraw()
	if _t > _duration + late_window:
		_finish({"key": &"", "error": _t - _duration})


## Raio do anel que fecha, em múltiplos do anel dourado (1 = na hora).
func _closing() -> float:
	var t := _t
	if _feint:
		var fake := _duration * 0.42
		var back := _duration * 0.58
		if t < fake:
			return 1.0 + 2.2 * (1.0 - t / fake * 0.6)
		if t < back:
			return 1.0 + 2.2 * (0.4 + (t - fake) / (back - fake) * 0.35)
		return 1.0 + 2.2 * 0.75 * clampf((_duration - t) / (_duration - back), 0.0, 1.0)
	if t > _duration:
		return 1.0 - 0.45 * (t - _duration) / late_window
	return 1.0 + 2.2 * clampf((_duration - t) / _duration, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or event.is_echo():
		return
	var keys := _keys.duplicate()
	if _arrow != 0:
		keys.append_array([&"move_left", &"move_right"])
	for key: StringName in keys:
		if event.is_action_pressed(key):
			get_viewport().set_input_as_handled()
			_finish({"key": key, "error": _t - _duration})
			return


func _draw() -> void:
	var font := get_theme_default_font()
	if _pop_t >= 0.0:
		var k := _pop_t / 0.45
		draw_arc(_pop_at, radius * (1.0 + k * 1.2), 0.0, TAU, 64, Color(_pop_color, 1.0 - k), 6.0 * (1.0 - k) + 1.0, true)
		draw_circle(_pop_at, radius * 0.8 * (1.0 - k), Color(_pop_color, 0.35 * (1.0 - k)))
	if not _active:
		return
	var c := _closing()
	var near := clampf(1.0 - absf(c - 1.0) / 1.2, 0.0, 1.0)  # 1 quando está na hora
	var appear := clampf(_t / 0.12, 0.0, 1.0)
	# fundo: disco escuro suave para ler em cima de qualquer coisa
	draw_circle(_center, radius * 1.55, Color(0.04, 0.02, 0.05, 0.38 * appear))
	# alvo: halo dourado e a faixa da janela (fica mais forte quando o anel chega)
	for i: int in 4:
		draw_arc(_center, radius + i * 2.5, 0.0, TAU, 64, Color(gold, (0.12 + 0.25 * near) * appear / (i + 1)), 6.0, true)
	draw_arc(_center, radius, 0.0, TAU, 64, Color(gold, 0.9 * appear), 3.0, true)
	# anel que fecha: branco longe, dourado perto
	var col := Color(1, 1, 1).lerp(gold, near)
	draw_arc(_center, radius * c, 0.0, TAU, 64, Color(col, appear), 2.0 + 3.0 * near, true)
	# tecla no meio
	_keycap(font, _center, _key_text, appear)
	if _arrow != 0:
		_draw_arrow(_center, _arrow, appear)
	if _steps > 1:
		for i: int in _steps:
			var at := _center + Vector2((i - (_steps - 1) / 2.0) * 16.0, radius * 1.55 + 14.0)
			draw_circle(at, 4.5, Color(gold, 0.95) if i < _step else (Color(1, 1, 1, 0.9) if i == _step else Color(1, 1, 1, 0.3)))
	_text(font, _center + Vector2(0, radius * 1.55 + (40.0 if _steps > 1 else 26.0)), _label, 17, Color(1, 0.95, 0.85, 0.9 * appear))


func _keycap(font: Font, at: Vector2, text: String, alpha: float) -> void:
	var size := 16
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x + 16.0
	var rect := Rect2(at - Vector2(w / 2.0, 13), Vector2(w, 26))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.08, 0.12, 0.92 * alpha)
	box.border_color = Color(gold, alpha)
	box.set_border_width_all(2)
	box.border_width_bottom = 4
	box.set_corner_radius_all(5)
	draw_style_box(box, rect)
	_text(font, at + Vector2(0, 6), text, size, Color(1, 0.95, 0.85, alpha))


func _draw_arrow(at: Vector2, side: int, alpha: float) -> void:
	var dir := Vector2(side, 0)
	var red := Color(1, 0.5, 0.42, alpha)
	for i: int in 3:
		# três chevrons que piscam em sequência, apontando para onde pular
		var base := at + dir * (radius * 1.5 + i * 18.0)
		var pulse := 0.4 + 0.6 * clampf(sin(_t * 10.0 - i * 0.9), 0.0, 1.0)
		var tip := base + dir * 12.0
		draw_polyline(PackedVector2Array([base + Vector2(0, -12), tip, base + Vector2(0, 12)]), Color(red, red.a * pulse), 5.0, true)


func _key_name(action: StringName) -> String:
	return {&"dodge": "Espaço", &"parry": "F"}.get(action, String(action)) as String


func _text(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string_outline(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
