class_name Emote
extends Sprite3D
## Balão de emoção em cima da cabeça (D060): "!", "?", raiva, coração, gota (nervoso/cansado), nota (cantando,
## contente), sono, reticências (pensando, conversando) e susto. Os ícones são desenhados por código (sem
## arquivo de imagem) e ficam guardados. Aparece com um "pop", balança de leve e some sozinho.
##   Emote.play(padeiro, "raiva")

const SIZE := 96
const KINDS: Array[String] = ["!", "?", "raiva", "coracao", "gota", "nota", "zz", "...", "susto"]
const OUTLINE := Color(0.22, 0.12, 0.06)

static var _cache: Dictionary = {}


## Mostra o balão `kind` em cima de `who` por `seconds`. Um balão novo na mesma pessoa troca o anterior.
static func play(who: Node3D, kind: String, seconds: float = 2.2) -> Emote:
	if who == null or not who.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var old := who.get_node_or_null("Emote") as Emote
	if old:
		old.name = "EmoteVelho"
		old.queue_free()
	var bubble := Emote.new()
	bubble.name = "Emote"
	bubble.texture = texture_for(kind)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.render_priority = 10
	bubble.pixel_size = 0.0055
	bubble.shaded = false
	who.add_child(bubble)
	bubble.position = Vector3(0, head_height(who) + 0.66, 0)
	bubble._pop(seconds)
	return bubble


## Altura da cabeça de alguém (pelo tamanho do que aparece), guardada na pessoa.
static func head_height(who: Node3D) -> float:
	if who.has_meta("altura_cabeca"):
		return float(who.get_meta("altura_cabeca"))
	var top := 0.0
	for found: Node in who.find_children("*", "VisualInstance3D", true, false):
		var vis := found as VisualInstance3D
		if vis is Sprite3D or vis is Label3D or not vis.visible:
			continue
		var box := vis.global_transform * vis.get_aabb()
		top = maxf(top, box.end.y - who.global_position.y)
	top = clampf(top if top > 0.1 else 1.6, 0.6, 3.0)
	who.set_meta("altura_cabeca", top)
	return top


static func texture_for(kind: String) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_bubble(img)
	match kind:
		"!":
			_bar(img, Vector2(48, 22), Vector2(48, 54), 7.0, Color(0.95, 0.55, 0.1))
			_disc(img, Vector2(48, 66), 6.0, Color(0.95, 0.55, 0.1))
		"susto":
			for x: float in [38.0, 58.0]:
				_bar(img, Vector2(x, 22), Vector2(x, 52), 6.0, Color(0.9, 0.2, 0.15))
				_disc(img, Vector2(x, 64), 5.5, Color(0.9, 0.2, 0.15))
		"?":
			_ring_arc(img, Vector2(48, 36), 13.0, 5.5, deg_to_rad(180), deg_to_rad(450), Color(0.25, 0.45, 0.9))
			_bar(img, Vector2(48, 49), Vector2(48, 55), 5.5, Color(0.25, 0.45, 0.9))
			_disc(img, Vector2(48, 66), 5.5, Color(0.25, 0.45, 0.9))
		"raiva":
			var red := Color(0.9, 0.12, 0.1)
			for k: int in 4:
				var a := k * PI / 2.0 + PI / 4.0
				var c := Vector2(48, 45) + Vector2(cos(a), sin(a)) * 21.0
				_ring_arc(img, c, 13.0, 6.0, a + PI - 1.0, a + PI + 1.0, red)
		"coracao":
			_heart(img, Vector2(48, 46), 21.0, Color(0.92, 0.22, 0.35))
		"gota":
			_drop(img, Vector2(48, 50), 15.0, Color(0.35, 0.65, 1.0))
		"nota":
			var ink := Color(0.25, 0.15, 0.4)
			_ellipse(img, Vector2(40, 60), Vector2(10, 7.5), ink)
			_bar(img, Vector2(49, 60), Vector2(49, 22), 3.5, ink)
			_bar(img, Vector2(49, 22), Vector2(62, 32), 4.0, ink)
		"zz":
			var blue := Color(0.35, 0.4, 0.8)
			_zed(img, Vector2(36, 50), 12.0, blue)
			_zed(img, Vector2(58, 34), 9.0, blue)
		"...":
			for x: float in [30.0, 48.0, 66.0]:
				_disc(img, Vector2(x, 47), 6.0, OUTLINE)
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


func _pop(seconds: float) -> void:
	scale = Vector3.ONE * 0.2
	modulate.a = 1.0
	var base_y := position.y
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)
	tween.parallel().tween_property(self, "position:y", base_y + 0.08, maxf(seconds - 0.5, 0.2)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


# --- desenho ------------------------------------------------------------------------------------------

static func _paint(img: Image, x: int, y: int, color: Color, cover: float) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE or cover <= 0.0:
		return
	var under := img.get_pixel(x, y)
	var a := clampf(cover, 0.0, 1.0) * color.a
	var out := Color(lerpf(under.r, color.r, a), lerpf(under.g, color.g, a), lerpf(under.b, color.b, a), maxf(under.a, a))
	img.set_pixel(x, y, out)


## Pinta onde dist(p) < 0 (borda macia de 1 px).
static func _shape(img: Image, box: Rect2, color: Color, dist: Callable) -> void:
	for y: int in range(int(box.position.y) - 1, int(box.end.y) + 2):
		for x: int in range(int(box.position.x) - 1, int(box.end.x) + 2):
			var d: float = dist.call(Vector2(x + 0.5, y + 0.5))
			_paint(img, x, y, color, clampf(0.5 - d, 0.0, 1.0))


static func _bubble(img: Image) -> void:
	var c := Vector2(48, 44)
	var tail := func(p: Vector2) -> float:
		# triângulo da ponta, embaixo à esquerda
		var a := Vector2(34, 70)
		var b := Vector2(50, 72)
		var t := Vector2(30, 90)
		var e1 := (b - a).orthogonal().normalized().dot(p - a)
		var e2 := (t - b).orthogonal().normalized().dot(p - b)
		var e3 := (a - t).orthogonal().normalized().dot(p - t)
		return maxf(maxf(e1, e2), e3)
	_shape(img, Rect2(4, 0, 88, 94), OUTLINE, func(p: Vector2) -> float: return minf(p.distance_to(c) - 40.0, tail.call(p) - 3.5))
	_shape(img, Rect2(4, 0, 88, 94), Color(1, 0.98, 0.93), func(p: Vector2) -> float: return minf(p.distance_to(c) - 36.0, tail.call(p) + 0.5))


static func _disc(img: Image, c: Vector2, r: float, color: Color) -> void:
	_shape(img, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), color, func(p: Vector2) -> float: return p.distance_to(c) - r)


static func _ellipse(img: Image, c: Vector2, r: Vector2, color: Color) -> void:
	_shape(img, Rect2(c - r, r * 2.0), color, func(p: Vector2) -> float:
		var q := (p - c) / r
		return (q.length() - 1.0) * minf(r.x, r.y))


static func _bar(img: Image, a: Vector2, b: Vector2, w: float, color: Color) -> void:
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(w)
	_shape(img, box, color, func(p: Vector2) -> float:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		return p.distance_to(a + ab * t) - w / 2.0)


static func _ring_arc(img: Image, c: Vector2, r: float, w: float, from: float, to: float, color: Color) -> void:
	_shape(img, Rect2(c - Vector2(r + w, r + w), Vector2(r + w, r + w) * 2.0), color, func(p: Vector2) -> float:
		var v := p - c
		var a := fposmod(atan2(v.y, v.x) - from, TAU)
		if a > to - from:
			return 99.0
		return absf(v.length() - r) - w / 2.0)


static func _heart(img: Image, c: Vector2, r: float, color: Color) -> void:
	_shape(img, Rect2(c - Vector2(r, r) * 1.3, Vector2(r, r) * 2.6), color, func(p: Vector2) -> float:
		var q := (p - c) / r * 1.25
		q.y = -q.y + 0.25
		var v := pow(q.x * q.x + q.y * q.y - 1.0, 3.0) - q.x * q.x * pow(q.y, 3.0)
		return v * 45.0)


static func _drop(img: Image, c: Vector2, r: float, color: Color) -> void:
	_shape(img, Rect2(c - Vector2(r, r * 2.2), Vector2(r * 2.0, r * 3.2)), color, func(p: Vector2) -> float:
		var ball := p.distance_to(c) - r
		var tip := c + Vector2(0, -r * 2.0)
		var side := absf(p.x - c.x) - (p.y - tip.y) / (r * 2.0) * r
		return minf(ball, maxf(side, maxf(tip.y - p.y, p.y - c.y))))


static func _zed(img: Image, at: Vector2, s: float, color: Color) -> void:
	_bar(img, at + Vector2(-s, -s), at + Vector2(s, -s), 4.0, color)
	_bar(img, at + Vector2(s, -s), at + Vector2(-s, s), 4.0, color)
	_bar(img, at + Vector2(-s, s), at + Vector2(s, s), 4.0, color)
