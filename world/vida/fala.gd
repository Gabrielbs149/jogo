class_name Fala
extends Label3D
## Uma frase solta em cima da cabeça de alguém (D060): o "bom dia" de quem passa, o "licença!" de quem esbarra.
## Pequena, branca, sobe um pouco e some. Para grito de briga use Missao.shout (vermelho, maior).

static func say(who: Node3D, text: String, seconds: float = 2.6) -> Fala:
	if who == null or not who.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var old := who.get_node_or_null("Fala") as Fala
	if old:
		old.name = "FalaVelha"
		old.queue_free()
	var label := Fala.new()
	label.name = "Fala"
	label.text = text
	label.font = load("res://assets/fonts/lato.ttf") if ResourceLoader.exists("res://assets/fonts/lato.ttf") else null
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color(1, 0.97, 0.9)
	label.outline_modulate = Color(0.12, 0.07, 0.04, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.00085
	label.render_priority = 9
	who.add_child(label)
	label.position = Vector3(0, Emote.head_height(who) + 0.25, 0)
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(label, "position:y", label.position.y + 0.25, seconds)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)
	return label
