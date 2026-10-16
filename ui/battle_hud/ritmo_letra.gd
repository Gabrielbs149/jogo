class_name RitmoLetra
extends Control
## D085: o Ritmo grande no canto da cena (como a letra da Perfeição do Verso, no Expedition 33). A letra, uma barra do
## quanto falta para a próxima, um estalo dourado quando sobe e um tremor vermelho quando você apanha e ela cai.

const COLORS: Array[Color] = [Color(0.78, 0.76, 0.82), Color(0.55, 0.9, 1.0), Color(0.55, 1.0, 0.6),
	Color(1.0, 0.78, 0.35), Color(1.0, 0.4, 0.75)]

var letter: String = "D"
var level: int = 0
var progress: float = 0.0
## > 0: acabou de subir (estala); < 0: acabou de cair (treme, vermelho).
var _pop: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 132)


func set_state(new_letter: String, new_level: int, new_progress: float) -> void:
	if new_level > level:
		_pop = 1.0
	elif new_level < level:
		_pop = -1.0
	letter = new_letter
	level = clampi(new_level, 0, COLORS.size() - 1)
	progress = clampf(new_progress, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not is_zero_approx(_pop):
		_pop = move_toward(_pop, 0.0, delta * 2.2)
		queue_redraw()
	elif level >= 3:
		queue_redraw()  # A e S pulsam


func _draw() -> void:
	var font := get_theme_default_font()
	var color: Color = COLORS[level]
	var up := maxf(_pop, 0.0)
	var down := maxf(-_pop, 0.0)
	if level >= 3:
		color = color.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_t * 6.0)))
	color = color.lerp(Color.WHITE, up * 0.7).lerp(Color(1.0, 0.15, 0.15), down)
	draw_string_outline(font, Vector2(0, 18), "RITMO", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 5, Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(0, 18), "RITMO", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 1, 1, 0.8))
	var big := int(78.0 + 34.0 * up)
	var shake := Vector2(sin(_t * 70.0) * 9.0 * down, 0.0)
	var base := Vector2(0, 26.0 + big * 0.78) + shake
	if up > 0.0:
		# o brilho atrás da letra quando sobe
		draw_circle(Vector2(size.x * 0.5, 26.0 + big * 0.45), big * 0.55, Color(color, 0.25 * up))
	draw_string_outline(font, base, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, big, 10, Color(0, 0, 0, 0.85))
	draw_string(font, base, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, big, color)
	var bar := Rect2(size.x * 0.12, size.y - 9.0, size.x * 0.76, 6.0)
	draw_rect(bar.grow(1.5), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), color)
