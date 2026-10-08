class_name DiceRoller
extends Control
## O d20 rolando na tela (D048): o dado gira mostrando números até parar no que saiu de verdade (as regras já
## rolaram; aqui só mostra). Com vantagem/desvantagem são dois dados e o que não vale fica apagado. Depois aparece
## a conta ("17 + 5 = 22 contra CA 13") e o veredito. Vários alvos: um dado ao lado do outro.
## roll(dice) espera terminar. Cada item vem de CombatRules (resultado["die"]).

## Segundos girando e segundos parado mostrando o resultado.
@export var spin_time: float = 0.75
@export var hold_time: float = 0.65
@export var size_px: float = 74.0

var _dice: Array[Dictionary] = []
var _t: float = 0.0
var _active: bool = false
var _flicker: Array[int] = []
var _flicker_at: float = 0.0
var _center := Vector2.ZERO

signal _finished


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func roll(dice: Array[Dictionary], center: Vector2) -> void:
	if dice.is_empty():
		return
	_dice = dice
	_center = center
	_t = 0.0
	_flicker_at = 0.0
	_flicker.clear()
	for d: Dictionary in dice:
		for r: Variant in d["rolls"]:
			_flicker.append(randi_range(1, 20))
	_active = true
	show()
	await _finished
	hide()


func _process(delta: float) -> void:
	if not _active:
		return
	var before := _t
	_t += delta
	if _t < spin_time and _t - _flicker_at > 0.055:
		_flicker_at = _t
		for i: int in _flicker.size():
			_flicker[i] = randi_range(1, 20)
		Audio.play("clique", -18.0, 0.0)  # o dado batendo
	if before < spin_time and _t >= spin_time:
		Audio.play("impacto", -8.0, 0.0)  # parou
	queue_redraw()
	if _t > spin_time + hold_time:
		_active = false
		_finished.emit()


func _draw() -> void:
	if not _active:
		return
	var font := get_theme_default_font()
	var spinning := _t < spin_time
	var settle := clampf((_t - spin_time) / 0.18, 0.0, 1.0)
	# dados lado a lado: cada resultado ocupa uma coluna (alvo diferente)
	var column := 230.0
	var x0 := _center.x - column * (_dice.size() - 1) / 2.0
	var k := 0
	for i: int in _dice.size():
		var d := _dice[i]
		var rolls: Array = d["rolls"]
		var by := d["by"] as Combatant
		var enemy_roll := by != null and is_instance_valid(by) and by.team != Combatant.Team.HEROES
		var tint := Color(0.95, 0.45, 0.45) if enemy_roll else Color(1.0, 0.86, 0.5)
		var spacing := size_px * 2.3
		for j: int in rolls.size():
			var pos := Vector2(x0 + i * column + (j - (rolls.size() - 1) / 2.0) * spacing, _center.y)
			var value: int = _flicker[k] if spinning else int(rolls[j])
			k += 1
			var kept := not spinning and (rolls.size() == 1 or int(rolls[j]) == int(d["kept"]))
			# girando: rola, pula e balança; parado: assenta (um "tum")
			var angle := (1.0 - _t / spin_time) * 9.0 if spinning else 0.0
			var hop := absf(sin(_t * 16.0)) * 14.0 * (1.0 - _t / spin_time) if spinning else 0.0
			var scale := 1.0 + (0.18 * (1.0 - settle) if not spinning else 0.0)
			var color := tint
			if not spinning:
				if int(rolls[j]) == 20:
					color = Color(1.0, 0.92, 0.35)
				elif int(rolls[j]) == 1:
					color = Color(0.85, 0.25, 0.25)
				if not kept:
					color = Color(color, 0.3)
			_draw_d20(pos + Vector2(0, -hop), size_px * scale, angle, color, str(value), font)
		if not spinning:
			var verdict := String(d.get("verdict", ""))
			var good := verdict in ["ACERTOU", "CRÍTICO!", "FALHOU"] if not enemy_roll else verdict in ["ERROU", "FALHA", "PASSOU"]
			if bool(d.has("save")) and enemy_roll == false:
				good = verdict == "FALHOU"
			var sum := "%d + %d = %d   contra %s %d" % [int(d["kept"]), int(d["mod"]), int(d["total"]), d["vs_name"], int(d["vs"])]
			var who := ("%s · salv. %s" % [by.display_name, d["save"]]) if d.has("save") else by.display_name
			var cx := x0 + i * column
			_text(font, Vector2(cx, _center.y - size_px - 26), who, 17, Color(1, 1, 1, 0.75 * settle))
			_text(font, Vector2(cx, _center.y + size_px + 34), sum, 19, Color(1, 0.95, 0.88, settle))
			_text(font, Vector2(cx, _center.y + size_px + 70), verdict, 32,
				Color(Color(0.55, 1.0, 0.6) if good else Color(1.0, 0.55, 0.5), settle))


## Um d20 visto de frente: hexágono com o triângulo da face da frente e as arestas até os cantos.
func _draw_d20(at: Vector2, r: float, angle: float, color: Color, label: String, font: Font) -> void:
	var outer: PackedVector2Array = []
	for i: int in 6:
		var a := angle + PI / 6.0 + i * TAU / 6.0
		outer.append(at + Vector2(cos(a), sin(a)) * r)
	var inner: PackedVector2Array = []
	for i: int in 3:
		var a := angle - PI / 2.0 + i * TAU / 3.0
		inner.append(at + Vector2(cos(a), sin(a)) * r * 0.62)
	draw_colored_polygon(outer, Color(0.1, 0.07, 0.11, 0.92))
	draw_colored_polygon(inner, Color(color.r * 0.35, color.g * 0.3, color.b * 0.3, 0.95 * color.a + 0.05))
	var edge := Color(color, color.a)
	outer.append(outer[0])
	draw_polyline(outer, edge, 3.0, true)
	inner.append(inner[0])
	draw_polyline(inner, edge, 2.0, true)
	for i: int in 3:
		# cada ponta do triângulo liga a dois cantos do hexágono
		draw_line(inner[i], outer[(i * 2 + 4) % 6], Color(edge, edge.a * 0.6), 1.5, true)
		draw_line(inner[i], outer[(i * 2 + 5) % 6], Color(edge, edge.a * 0.6), 1.5, true)
	_text(font, at + Vector2(0, 11), label, int(r * 0.52), Color(1, 1, 1, color.a))


func _text(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string_outline(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
