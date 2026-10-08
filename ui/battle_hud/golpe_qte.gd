class_name GolpeQte
extends Control
## Os desafios de tempo da luta (D048). Cada um mede e devolve o que você fez; quem decide o efeito é a arena.
## - ring: o anel fecha; aperte na hora. Com feint, o anel engana (para e abre um pouco antes de fechar de verdade).
##   Com arrow (-1/+1), aparece uma seta e a tecla certa é A ou D (desvio para o lado).
## - bar: um ponteiro corre de um lado a outro; Espaço para no meio dourado.
## - sequence: setas aparecem uma de cada vez; aperte W A S D (ou as setas) na ordem, sem errar e rápido.
## - mash: aperte Espaço o mais rápido que puder.
## - hold: segure Espaço; a barra enche cada vez mais rápido; solte na faixa dourada (passou do topo, perdeu).

signal _done(result: Dictionary)

const DIRS: Array[StringName] = [&"move_forward", &"move_left", &"move_back", &"move_right"]
const ARROWS: Array[String] = ["↑", "←", "↓", "→"]
const LETTERS: Array[String] = ["W", "A", "S", "D"]

@export var ring_color: Color = Color(1.0, 0.85, 0.5)
@export var target_color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var late_window: float = 0.25
@export var radius: float = 36.0

var _mode: String = ""
var _active: bool = false
var _t: float = 0.0
var _center := Vector2.ZERO
var _label: String = ""
# anel
var _duration: float = 0.7
var _keys: Array[StringName] = []
var _feint: bool = false
var _arrow: int = 0
# barra
var _period: float = 0.9
var _gold: float = 0.06
var _green: float = 0.2
# sequência
var _seq: Array[int] = []
var _seq_i: int = 0
var _per_key: float = 0.6
var _key_t: float = 0.0
var _wrong: bool = false
# martelar
var _presses: int = 0
var _mash_time: float = 1.6
# segurar
var _holding: bool = false
var _level: float = 0.0
var _fill_time: float = 1.3


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


# ---------- quem a arena chama

func ring(center: Vector2, duration: float, keys: Array[StringName], label: String, feint: bool = false, arrow: int = 0) -> Dictionary:
	_duration = maxf(duration, 0.2) + (0.45 if feint else 0.0)
	_keys = keys
	_feint = feint
	_arrow = arrow
	return await _start("ring", center, label)


func bar(center: Vector2, period: float, gold: float, green: float, label: String = "Espaço para no dourado") -> Dictionary:
	_period = period
	_gold = gold
	_green = green
	return await _start("bar", center, label)


func sequence(center: Vector2, count: int, per_key: float) -> Dictionary:
	_seq.clear()
	for i: int in count:
		var next := randi() % 4
		while not _seq.is_empty() and next == _seq[_seq.size() - 1] and randf() < 0.6:
			next = randi() % 4  # repetir pode, mas menos
		_seq.append(next)
	_seq_i = 0
	_per_key = per_key
	_key_t = 0.0
	_wrong = false
	return await _start("sequence", center, "W A S D na ordem")


func mash(center: Vector2, duration: float) -> Dictionary:
	_presses = 0
	_mash_time = duration
	return await _start("mash", center, "ESPAÇO! ESPAÇO! ESPAÇO!")


func hold(center: Vector2, fill_time: float) -> Dictionary:
	_holding = false
	_level = 0.0
	_fill_time = fill_time
	return await _start("hold", center, "Segure Espaço e solte no dourado")


func _start(mode: String, center: Vector2, label: String) -> Dictionary:
	_mode = mode
	_center = center
	_label = label
	_t = 0.0
	_active = true
	show()
	queue_redraw()
	var result: Dictionary = await _done
	hide()
	return result


func _finish(result: Dictionary) -> void:
	if not _active:
		return
	_active = false
	_done.emit(result)


# ---------- tempo

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	queue_redraw()
	match _mode:
		"ring":
			if _t > _duration + late_window:
				_finish({"key": &"", "error": _t - _duration})
		"bar":
			if _t > 4.0:
				_finish({"offset": 1.0})  # não parou: nada
		"sequence":
			_key_t += delta
			if _key_t > _per_key:
				_finish({"correct": _seq_i, "count": _seq.size(), "timeout": true})
		"mash":
			if _t >= _mash_time:
				_finish({"presses": _presses})
		"hold":
			if _holding:
				# enche cada vez mais rápido (curva): fácil começar, difícil parar na hora
				_level += delta / _fill_time * (0.55 + _level * 1.4)
				if _level >= 1.0:
					_finish({"level": _level, "over": true})
			elif _t > 2.5:
				_finish({"level": 0.0, "over": false})


## Onde o anel está agora (1 = no alvo). A finta fecha até 60%, abre de volta e só então fecha de verdade.
func _ring_scale() -> float:
	var t := _t
	if _feint:
		var fake := _duration * 0.42
		if t < fake:
			return 1.0 + 2.4 * (1.0 - t / fake * 0.6)
		var back := _duration * 0.58
		if t < back:
			return 1.0 + 2.4 * (0.4 + (t - fake) / (back - fake) * 0.35)
		return 1.0 + 2.4 * 0.75 * clampf((_duration - t) / (_duration - back), 0.0, 1.0)
	var closing := clampf((_duration - t) / _duration, 0.0, 1.0)
	if t > _duration:
		return 1.0 - 0.5 * (t - _duration) / late_window
	return 1.0 + 2.4 * closing


func _bar_pos() -> float:
	# vai e volta de -1 a 1, acelerando um pouco nas pontas (difícil parar no meio)
	return sin(_t / _period * PI)


# ---------- teclas

func _unhandled_input(event: InputEvent) -> void:
	if not _active or event.is_echo():
		return
	match _mode:
		"ring":
			var keys := _keys.duplicate()
			if _arrow != 0:
				keys.append_array([&"move_left", &"move_right"])
			for key: StringName in keys:
				if event.is_action_pressed(key):
					get_viewport().set_input_as_handled()
					_finish({"key": key, "error": _t - _duration})
					return
		"bar":
			if event.is_action_pressed(&"dodge"):
				get_viewport().set_input_as_handled()
				_finish({"offset": absf(_bar_pos())})
		"sequence":
			for i: int in DIRS.size():
				if event.is_action_pressed(DIRS[i]):
					get_viewport().set_input_as_handled()
					if i != _seq[_seq_i]:
						_wrong = true
						_finish({"correct": _seq_i, "count": _seq.size(), "wrong": true})
						return
					_seq_i += 1
					_key_t = 0.0
					Audio.play("clique", -10.0, 0.0)
					if _seq_i >= _seq.size():
						_finish({"correct": _seq_i, "count": _seq.size()})
					return
		"mash":
			if event.is_action_pressed(&"dodge"):
				get_viewport().set_input_as_handled()
				_presses += 1
		"hold":
			if event.is_action_pressed(&"dodge"):
				get_viewport().set_input_as_handled()
				_holding = true
			elif event.is_action_released(&"dodge") and _holding:
				get_viewport().set_input_as_handled()
				_finish({"level": _level, "over": false})


# ---------- desenho

func _draw() -> void:
	if not _active:
		return
	var font := get_theme_default_font()
	match _mode:
		"ring":
			draw_arc(_center, radius, 0.0, TAU, 48, target_color, 4.0, true)
			draw_arc(_center, radius * _ring_scale(), 0.0, TAU, 48, ring_color, 3.0, true)
			if _arrow != 0:
				_draw_arrow(_center, _arrow)
		"bar":
			var w := 420.0
			var r := Rect2(_center - Vector2(w / 2.0, 12), Vector2(w, 24))
			draw_rect(r, Color(0.08, 0.05, 0.09, 0.9))
			draw_rect(Rect2(_center - Vector2(w * _green / 2.0, 12), Vector2(w * _green, 24)), Color(0.35, 0.75, 0.4, 0.8))
			draw_rect(Rect2(_center - Vector2(w * _gold / 2.0, 12), Vector2(w * _gold, 24)), Color(1.0, 0.82, 0.3))
			draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
			var x := _center.x + _bar_pos() * w / 2.0
			draw_line(Vector2(x, _center.y - 22), Vector2(x, _center.y + 22), Color.WHITE, 4.0)
		"sequence":
			var n := _seq.size()
			var gap := 74.0
			for i: int in n:
				var at := _center + Vector2((i - (n - 1) / 2.0) * gap, 0)
				var done := i < _seq_i
				var now := i == _seq_i
				var c := Color(0.55, 1.0, 0.6) if done else (Color(1, 0.9, 0.55) if now else Color(1, 1, 1, 0.35))
				if _wrong and now:
					c = Color(1, 0.4, 0.4)
				draw_circle(at, 28.0, Color(0.08, 0.05, 0.09, 0.9))
				draw_arc(at, 28.0, 0.0, TAU, 32, c, 3.0 if now else 2.0, true)
				_text(font, at + Vector2(0, 10), ARROWS[_seq[i]], 30, c)
				_text(font, at + Vector2(0, 50), LETTERS[_seq[i]], 15, Color(c, c.a * 0.8))
				if now:
					# o tempo desta tecla acabando
					draw_arc(at, 34.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - _key_t / _per_key), 32, Color(1, 0.6, 0.4), 3.0, true)
		"mash":
			var fill := clampf(_presses / 20.0, 0.0, 1.0)
			var w := 360.0
			draw_rect(Rect2(_center - Vector2(w / 2.0, 14), Vector2(w, 28)), Color(0.08, 0.05, 0.09, 0.9))
			draw_rect(Rect2(_center - Vector2(w / 2.0, 14), Vector2(w * fill, 28)), Color(1.0, 0.6, 0.3).lerp(Color(1, 0.9, 0.4), fill))
			draw_rect(Rect2(_center - Vector2(w / 2.0, 14), Vector2(w, 28)), Color(1, 1, 1, 0.6), false, 2.0)
			_text(font, _center + Vector2(0, -26), "%d" % _presses, 30, Color.WHITE)
			draw_arc(_center + Vector2(w / 2.0 + 30, 0), 16, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - _t / _mash_time), 24, Color(1, 0.6, 0.4), 3.0, true)
		"hold":
			var h := 220.0
			var w := 34.0
			var base := _center + Vector2(0, h / 2.0)
			draw_rect(Rect2(base - Vector2(w / 2.0, h), Vector2(w, h)), Color(0.08, 0.05, 0.09, 0.9))
			draw_rect(Rect2(base - Vector2(w / 2.0, h * 0.85), Vector2(w, h * 0.15)), Color(0.35, 0.75, 0.4, 0.8))
			draw_rect(Rect2(base - Vector2(w / 2.0, h * 0.93), Vector2(w, h * 0.08)), Color(1.0, 0.82, 0.3))
			var lv := clampf(_level, 0.0, 1.0)
			draw_rect(Rect2(base - Vector2(w / 2.0 - 5, h * lv), Vector2(w - 10, h * lv)), Color(1, 1, 1, 0.85))
			draw_rect(Rect2(base - Vector2(w / 2.0, h), Vector2(w, h)), Color(1, 1, 1, 0.6), false, 2.0)
	_text(font, _center + Vector2(0, 118 if _mode == "hold" else 72), _label, 20, ring_color)


func _draw_arrow(at: Vector2, side: int) -> void:
	var dir := Vector2(side, 0)
	var tip := at + dir * 110.0
	var tail := at + dir * 52.0
	draw_line(tail, tip, Color(1, 0.45, 0.4), 8.0, true)
	draw_colored_polygon(PackedVector2Array([tip + dir * 22.0, tip + Vector2(0, -18), tip + Vector2(0, 18)]), Color(1, 0.45, 0.4))
	var font := get_theme_default_font()
	_text(font, tip + dir * 40.0 + Vector2(0, 8), "D" if side > 0 else "A", 24, Color(1, 0.6, 0.55))


func _text(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string_outline(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
