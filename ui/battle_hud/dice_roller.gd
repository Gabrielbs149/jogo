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
## 20 ou 1 natural no dado que valeu (D050): fica mais tempo na tela, com explosão ou rachadura.
var _special: String = ""
var _hold: float = 0.65

## Avisa a tela de luta (piscada dourada no 20, tremida no 1) na hora em que o dado para.
signal landed(special: String)

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
	_special = ""
	for d: Dictionary in dice:
		if int(d["kept"]) == 20:
			_special = "20"
		elif int(d["kept"]) == 1 and _special == "":
			_special = "1"
	_hold = hold_time + (0.7 if _special != "" else 0.0)
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
		if _special == "20":
			Audio.play("qte_perfeito", -2.0, 0.0)
		elif _special == "1":
			Audio.play("qte_errou", -2.0, 0.0)
		landed.emit(_special)
	queue_redraw()
	if _t > spin_time + _hold:
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
			var nat := int(rolls[j]) if not spinning else 0
			if kept and nat == 20:
				_burst(pos, settle)
			if kept and nat == 1:
				pos.x += sin(_t * 70.0) * 7.0 * clampf(1.0 - (_t - spin_time) / 0.5, 0.0, 1.0)
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
			if kept and nat == 1:
				_cracks(pos, size_px * scale)
		if not spinning:
			var view := _player_view(d, enemy_roll)
			var verdict: String = view[0]
			var good: bool = view[1]
			var sum := "%d + %d = %d   contra %s %d" % [int(d["kept"]), int(d["mod"]), int(d["total"]), d["vs_name"], int(d["vs"])]
			var who := ("%s · salv. %s" % [by.display_name, d["save"]]) if d.has("save") else by.display_name
			if d.has("skill"):
				who = "%s · %s" % [by.display_name, d["skill"]]
			var cx := x0 + i * column
			_text(font, Vector2(cx, _center.y - size_px - 26), who, 17, Color(1, 1, 1, 0.75 * settle))
			# placa escura atrás da conta e do veredito (lê em cima de qualquer fundo, até na piscada dourada)
			var plate := StyleBoxFlat.new()
			plate.bg_color = Color(0.05, 0.03, 0.06, 0.78 * settle)
			plate.set_corner_radius_all(8)
			draw_style_box(plate, Rect2(cx - 170, _center.y + size_px + 12, 340, 74))
			_text(font, Vector2(cx, _center.y + size_px + 34), sum, 19, Color(1, 0.95, 0.88, settle))
			var big := 44 if int(d["kept"]) in [1, 20] and not d.has("save") else 32
			var verdict_color := Color(1.0, 0.85, 0.3) if verdict == "CRÍTICO!" else (Color(0.55, 1.0, 0.6) if good else Color(1.0, 0.55, 0.5))
			_text(font, Vector2(cx, _center.y + size_px + 70 + (big - 32) * 0.5), verdict, big,
				Color(verdict_color, settle))


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


## O 20: raios dourados girando, um anel que estoura e faíscas saindo.
func _burst(at: Vector2, settle: float) -> void:
	var k := clampf((_t - spin_time) / 0.6, 0.0, 1.0)
	var gold := Color(1.0, 0.85, 0.35)
	for i: int in 12:
		var a := i * TAU / 12.0 + _t * 0.8
		var inner := size_px * 1.05
		var outer := size_px * (1.6 + 0.5 * sin(_t * 6.0 + i))
		draw_line(at + Vector2(cos(a), sin(a)) * inner, at + Vector2(cos(a), sin(a)) * outer, Color(gold, 0.55 * settle), 4.0, true)
	draw_arc(at, size_px * (1.0 + k * 1.6), 0.0, TAU, 48, Color(gold, 1.0 - k), 6.0 * (1.0 - k) + 1.0, true)
	for i: int in 10:
		var a := i * 2.4 + 0.3
		var r := size_px * (1.1 + k * 1.8) * (0.7 + 0.3 * sin(i * 3.1))
		draw_circle(at + Vector2(cos(a), sin(a)) * r, 3.0 * (1.0 - k) + 1.0, Color(1, 0.95, 0.6, 1.0 - k))


## O 1: rachaduras atravessando o dado.
func _cracks(at: Vector2, r: float) -> void:
	var red := Color(1.0, 0.25, 0.2)
	var lines := [[Vector2(-0.1, -0.95), Vector2(0.05, -0.4), Vector2(-0.15, 0.05), Vector2(0.1, 0.5)],
		[Vector2(0.05, -0.4), Vector2(0.45, -0.2), Vector2(0.7, 0.15)], [Vector2(-0.15, 0.05), Vector2(-0.55, 0.3)]]
	for line: Array in lines:
		var pts: PackedVector2Array = []
		for p: Vector2 in line:
			pts.append(at + p * r)
		draw_polyline(pts, red, 3.0, true)


## O veredito sempre do ponto de vista de quem joga (D055): verde = bom para você, vermelho = ruim, e o texto diz o que
## aconteceu com você ou com o seu golpe. Devolve [texto, bom].
## - seu ataque: ACERTOU / CRÍTICO! / ERROU / FALHA CRÍTICA!
## - sua habilidade que o inimigo resiste (salvamento): ACERTOU (ele falhou) / RESISTIU (ele passou)
## - ataque do inimigo em você: TE ACERTOU / GOLPE CRÍTICO! / ESCAPOU / ELE TROPEÇOU
static func _player_view(d: Dictionary, enemy_roll: bool) -> Array:
	var kept := int(d["kept"])
	var verdict := String(d.get("verdict", ""))
	if d.has("save"):
		# quem rola é quem resiste: se ele é inimigo, falhar é bom para você
		var failed := verdict in ["FALHOU", "FALHA"]
		if enemy_roll:
			return ["ACERTOU" if failed else "RESISTIU", failed]
		return ["NÃO RESISTIU" if failed else "RESISTIU", not failed]
	var hit := verdict in ["ACERTOU", "CRÍTICO!"]
	if d.has("skill"):
		return ["CONSEGUIU!" if kept == 20 else ("FALHOU" if kept == 1 or not hit else "CONSEGUIU"), hit]
	if not enemy_roll:
		if kept == 20:
			return ["CRÍTICO!", true]
		if kept == 1:
			return ["FALHA CRÍTICA!", false]
		return ["ACERTOU" if hit else "ERROU", hit]
	if kept == 20:
		return ["GOLPE CRÍTICO!", false]
	if kept == 1:
		return ["ELE TROPEÇOU", true]
	return ["TE ACERTOU" if hit else "ESCAPOU", not hit]
