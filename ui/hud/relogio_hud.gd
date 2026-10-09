class_name RelogioHUD
extends Control
## O relógio do jogo na tela (D060), pequeno e no canto: um arco do céu com o sol (ou a lua) andando por ele,
## a hora e o dia. Lê Game.hora e Game.dia.

const W := 132.0
const H := 58.0
const SUN := Color(1.0, 0.82, 0.35)
const MOON := Color(0.85, 0.9, 1.0)

var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/cinzel.ttf") as Font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var h := Game.hora
	var day := h >= 6.0 and h < 18.0
	var t := (h - 6.0) / 12.0 if day else fposmod(h - 18.0, 24.0) / 12.0
	var center := Vector2(W / 2.0, H - 18.0)
	var radius := 40.0
	# fundo discreto e o arco do céu
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.08, 0.05, 0.03, 0.55))
	draw_arc(center, radius, PI, TAU, 32, Color(1, 0.92, 0.8, 0.35), 1.5, true)
	draw_line(Vector2(center.x - radius - 6, center.y), Vector2(center.x + radius + 6, center.y), Color(1, 0.92, 0.8, 0.25), 1.0)
	var angle := PI + t * PI
	var at := center + Vector2(cos(angle), sin(angle)) * radius
	if day:
		draw_circle(at, 6.5, SUN)
		for k: int in 8:
			var a := k * TAU / 8.0
			draw_line(at + Vector2(cos(a), sin(a)) * 8.5, at + Vector2(cos(a), sin(a)) * 11.0, SUN, 1.5, true)
	else:
		draw_circle(at, 6.0, MOON)
		draw_circle(at + Vector2(2.8, -2.0), 5.2, Color(0.08, 0.05, 0.03, 1.0))  # a lua crescente
	var text := Game.clock_text()
	var size_txt := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	draw_string(_font, Vector2(center.x - size_txt.x / 2.0, H - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.94, 0.85))
	draw_string(_font, Vector2(4.0, 12.0), "Dia %d" % Game.dia, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.85, 0.6, 0.85))
