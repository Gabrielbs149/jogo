class_name BarraInimigo
extends Control
## Vida em cima do inimigo (D052, como nos jogos de luta por turnos): nome, barra de vida com o pedaço perdido que
## some devagar (dá para sentir o dano), barrinha de postura embaixo e o número. Treme quando ele apanha.
## A tela de luta põe uma por inimigo e move para cima da cabeça dele a cada quadro.

var enemy: Combatant
## Altura (m) acima do pé onde a barra fica.
var head: float = 1.2
var targeted: bool = false

var _shown: float = 1.0  # fração de vida que a barra mostra (cai na hora)
var _lag: float = 1.0  # o pedaço que some devagar
var _lag_wait: float = 0.0
var _shake: float = 0.0
var _fade: float = 1.0

const W := 150.0
const H := 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W + 20, 54)


func follow(at: Vector2) -> void:
	position = at - Vector2(size.x / 2.0, size.y)


func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var frac := clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0.0, 1.0)
	if frac < _shown - 0.001:
		_shake = 0.25
		_lag_wait = 0.45
	_shown = frac
	if _lag_wait > 0.0:
		_lag_wait -= delta
	else:
		_lag = move_toward(_lag, _shown, delta * 0.8)
	_lag = maxf(_lag, _shown)
	_shake = maxf(0.0, _shake - delta)
	_fade = move_toward(_fade, 0.0 if enemy.hp <= 0 else 1.0, delta * 2.5)
	queue_redraw()


func _draw() -> void:
	if enemy == null or not is_instance_valid(enemy) or _fade <= 0.0:
		return
	var font := get_theme_default_font()
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
	var x0 := (size.x - W) / 2.0
	var top := 22.0
	var a := _fade
	# nome (dourado e com seta quando é o alvo)
	var label := ("▸ " if targeted else "") + enemy.display_name + ("  ✶ QUEBRADO" if enemy.quebrado else "")
	var fs := 15
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var name_color := Color(1, 0.86, 0.45, a) if targeted else Color(1, 1, 1, 0.9 * a)
	draw_string_outline(font, Vector2(size.x / 2.0 - tw / 2.0, 16) + jitter, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.85 * a))
	draw_string(font, Vector2(size.x / 2.0 - tw / 2.0, 16) + jitter, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_color)
	# moldura e fundo
	var frame := Rect2(Vector2(x0, top) + jitter, Vector2(W, H))
	_box(frame.grow(2.0), Color(0.05, 0.03, 0.05, 0.9 * a), Color(1, 0.86, 0.45, a) if targeted else Color(0.6, 0.45, 0.4, 0.8 * a))
	# o pedaço perdido (claro) e a vida
	if _lag > _shown:
		_box(Rect2(frame.position + Vector2(W * _shown, 0), Vector2(W * (_lag - _shown), H)), Color(1.0, 0.95, 0.8, 0.95 * a), Color(0, 0, 0, 0))
	var life := Color(0.92, 0.3, 0.25).lerp(Color(0.95, 0.65, 0.25), _shown)
	if _shown > 0.0:
		_box(Rect2(frame.position, Vector2(W * _shown, H)), Color(life, a), Color(0, 0, 0, 0))
		draw_rect(Rect2(frame.position + Vector2(2, 2), Vector2(maxf(0.0, W * _shown - 4), 2)), Color(1, 1, 1, 0.3 * a))  # brilho
	# número
	var num := "%d / %d" % [maxi(0, enemy.hp), enemy.max_hp]
	var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, frame.position + Vector2(W / 2.0 - nw / 2.0, 10), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0, 0, 0, 0.9 * a))
	draw_string(font, frame.position + Vector2(W / 2.0 - nw / 2.0, 10), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, a))
	# postura (fina, azulada)
	var p := clampf(float(enemy.postura) / maxf(1.0, float(enemy.posture_limit())), 0.0, 1.0)
	var prect := Rect2(frame.position + Vector2(0, H + 4), Vector2(W, 4))
	draw_rect(prect, Color(0.1, 0.1, 0.16, 0.85 * a))
	draw_rect(Rect2(prect.position, Vector2(W * p, 4)), Color(0.75, 0.88, 1.0, a) if not enemy.quebrado else Color(1, 1, 1, a))


func _box(r: Rect2, fill: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(3)
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(1)
	draw_style_box(box, r)
