class_name CutscenePlayer
extends CanvasLayer
## Toca um Roteiro (story/roteiro.gd tem o formato): tela preta, narração, falas com letra a letra,
## cortes e movimentos de câmera, sons, mostrar/esconder coisas e prender personagens em animações.
## Espaço, F ou clique passam; Esc pula a cena inteira.

signal finished

const SFX_DIR := "res://assets/sfx/"
const LETTERS_PER_SECOND := 42.0

## Onde os nós citados no roteiro são procurados (a fase).
var stage: Node
## O seu personagem ("Tico", "jogador" no roteiro).
var hero: Node3D
## Passa sozinho, sem esperar ninguém (testes).
var auto: bool = false

var _advance: bool = false
var _skip: bool = false
var _page_open: bool = false
var _speaker: String = ""
var _camera: Camera3D
var _previous_camera: Camera3D
var _sound: AudioStreamPlayer
var _held: Array[Node] = []

@onready var _black: ColorRect = %Black
@onready var _bars: Array[ColorRect] = [%BarTop, %BarBottom]
@onready var _narration: VBoxContainer = %Narration
@onready var _caption: Label = %Caption
@onready var _dialogue: Control = %Dialogue
@onready var _name: Label = %SpeakerName
@onready var _line: Label = %Line
@onready var _hint: Label = %Hint


func _ready() -> void:
	auto = auto or DisplayServer.get_name() == "headless"
	_dialogue.hide()
	_caption.text = ""
	_black.modulate.a = 0.0
	for bar: ColorRect in _bars:
		bar.custom_minimum_size.y = 0.0


func play(roteiro: Roteiro) -> void:
	_previous_camera = get_viewport().get_camera_3d()
	create_tween().set_parallel().tween_method(_set_bars, 0.0, 64.0, 0.6)
	var lines := roteiro.texto.split("\n")
	for raw: String in lines:
		if _skip:
			break
		if await _run(raw.strip_edges()) == false:
			break
	await _close_page()
	await _end()


func _set_bars(h: float) -> void:
	for bar: ColorRect in _bars:
		bar.custom_minimum_size.y = h


# --- uma linha do roteiro ----------------------------------------------------------------------

## Devolve false para terminar a cena.
func _run(line: String) -> bool:
	if line.begins_with(">"):
		await _narrate(line.trim_prefix(">").strip_edges())
		return true
	if line == "":
		await _close_page()
		return true
	if line.begins_with("#"):
		return true
	if line.begins_with("[") and line.ends_with("]"):
		await _close_page()
		return await _command(line.substr(1, line.length() - 2).strip_edges())
	var said := _dialogue_of(line)
	if not said.is_empty():
		await _close_page()
		await _say(said[0], said[1])
	return true


## ["Nome", "fala"] ou [] se a linha é só anotação.
func _dialogue_of(line: String) -> Array:
	var quoted := line.begins_with("\"") or line.begins_with("“")
	if quoted and _speaker != "":
		var who := _speaker
		_speaker = ""
		return [who, _unquote(line)]
	_speaker = ""
	var colon := line.find(":")
	if colon <= 0 or colon > 24:
		return []
	var who := line.substr(0, colon).strip_edges()
	var text := line.substr(colon + 1).strip_edges()
	if who.split(" ").size() > 3:
		return []
	if text == "":
		_speaker = who  # a fala vem na linha de baixo, entre aspas
		return []
	return [who, _unquote(text)]


func _unquote(text: String) -> String:
	for mark: String in ["\"", "“", "”"]:
		text = text.trim_prefix(mark).trim_suffix(mark)
	return text.strip_edges()


func _command(body: String) -> bool:
	var name := body
	var arg := ""
	var colon := body.find(":")
	if colon >= 0:
		name = body.substr(0, colon)
		arg = body.substr(colon + 1).strip_edges()
	else:
		var space := body.rfind(" ")  # [tela preta 0.8], [pausa 1.5]: o número no fim é o tempo
		if space >= 0 and body.substr(space + 1).strip_edges().is_valid_float():
			name = body.substr(0, space)
			arg = body.substr(space + 1).strip_edges()
	name = _plain(name.strip_edges())
	var words := arg.split(" ", false)
	match name:
		"tela preta":
			await _fade_black(1.0, float(arg) if arg.is_valid_float() else 0.8)
		"abre", "tela volta":
			await _fade_black(0.0, float(arg) if arg.is_valid_float() else 0.8)
		"corta":
			_cut(_find(arg))
		"camera":
			var seconds := float(words[-1]) if words.size() > 1 and words[-1].is_valid_float() else 2.0
			var target := arg.trim_suffix(words[-1]).strip_edges() if words.size() > 1 and words[-1].is_valid_float() else arg
			await _glide(_find(target), seconds)
		"som":
			_play_sound(arg)
		"para som":
			if _sound:
				_sound.stop()
			_caption.text = ""
		"legenda":
			_caption.text = arg
		"pausa":
			await _wait(float(arg) if arg.is_valid_float() else 1.0)
		"mostra", "esconde":
			var node := _find(arg) as Node3D
			if node:
				node.visible = name == "mostra"
		"anima":
			if words.size() >= 2:
				_animate(_find(" ".join(words.slice(0, words.size() - 1))), StringName(words[-1]))
		"solta":
			var node := _find(arg)
			var animator := node.get_node_or_null("Animator") if node else null
			if animator and animator.has_method("release"):
				animator.call("release")
		"coloca":
			if words.size() >= 2:
				var node := _find(words[0]) as Node3D
				var mark := _find(words[1]) as Node3D
				if node and mark:
					node.global_transform = mark.global_transform
		"olha":
			if words.size() >= 2:
				var node := _find(words[0]) as Node3D
				var other := _find(words[1]) as Node3D
				if node and other:
					var at := other.global_position
					at.y = node.global_position.y
					if at.distance_to(node.global_position) > 0.01:
						node.look_at(at, Vector3.UP)
		"na mao":
			_attach_to_hand(_find(words[0]) as Node3D if words.size() > 0 else null, _find(words[1]) as Node3D if words.size() > 1 else hero)
		"fim":
			return false
		_:
			push_warning("Roteiro: comando desconhecido [%s]" % body)
	return true


# --- o que aparece na tela ----------------------------------------------------------------------

func _narrate(text: String) -> void:
	if text == "":
		await _close_page()
		return
	if _black.modulate.a < 0.99:
		await _fade_black(1.0, 0.5)
	_page_open = true
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 23)
	label.modulate.a = 0.0
	_narration.add_child(label)
	if auto:
		label.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 1.0)
	await tween.finished
	await _wait(0.35)


func _close_page() -> void:
	if not _page_open:
		return
	_page_open = false
	await _wait_input()
	if not auto:
		var tween := create_tween()
		tween.tween_property(_narration, "modulate:a", 0.0, 0.6)
		await tween.finished
	for child: Node in _narration.get_children():
		child.queue_free()
	_narration.modulate.a = 1.0


func _say(who: String, text: String) -> void:
	_dialogue.show()
	_name.text = who
	_line.text = text
	Audio.play("fala", -12.0, 0.1)
	_hint.modulate.a = 0.0
	_line.visible_ratio = 0.0
	if not auto:
		var tween := create_tween()
		tween.tween_property(_line, "visible_ratio", 1.0, maxf(text.length() / LETTERS_PER_SECOND, 0.2))
		_advance = false
		while tween.is_running() and not _advance and not _skip:
			await get_tree().process_frame
		tween.kill()
	_line.visible_ratio = 1.0
	_hint.modulate.a = 1.0
	await _wait_input()
	_dialogue.hide()


func _fade_black(to: float, seconds: float) -> void:
	if auto or seconds <= 0.0 or _skip:
		_black.modulate.a = to
		return
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", to, seconds)
	await tween.finished


func _wait(seconds: float) -> void:
	if auto or _skip or seconds <= 0.0:
		return
	var left := seconds
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _wait_input() -> void:
	if auto or _skip:
		return
	_advance = false
	while not _advance and not _skip:
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_skip = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("dodge") \
			or (event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		_advance = true
	else:
		return
	get_viewport().set_input_as_handled()


# --- câmera, som, personagens -----------------------------------------------------------------------

func _cut(target: Node) -> void:
	var mark := target as Node3D
	if mark == null:
		return
	_ensure_camera()
	_camera.global_transform = mark.global_transform
	if mark is Camera3D:
		_camera.fov = (mark as Camera3D).fov
	_camera.make_current()


func _glide(target: Node, seconds: float) -> void:
	var mark := target as Node3D
	if mark == null:
		return
	_ensure_camera()
	_camera.make_current()
	if auto or _skip:
		_camera.global_transform = mark.global_transform
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "global_transform", mark.global_transform, seconds)
	if mark is Camera3D:
		tween.parallel().tween_property(_camera, "fov", (mark as Camera3D).fov, seconds)
	while tween.is_running() and not _skip:
		await get_tree().process_frame
	tween.kill()


func _ensure_camera() -> void:
	if _camera:
		return
	_camera = Camera3D.new()
	_camera.name = "CutsceneCamera"
	_camera.fov = 50.0
	(stage if stage else get_tree().current_scene).add_child(_camera)


func _play_sound(arg: String) -> void:
	var parts := arg.split("|")
	var file := parts[0].strip_edges()
	for ext: String in [".ogg", ".wav", ".mp3"]:
		var path := ""
		for dir: String in [SFX_DIR, "res://assets/audio/ambiente/", "res://assets/audio/musica/", "res://assets/audio/sfx/"]:
			if ResourceLoader.exists(dir + file + ext):
				path = dir + file + ext
				break
		if path != "":
			var stream := load(path) as AudioStream
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			elif stream is AudioStreamWAV:
				(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			elif stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			if _sound == null:
				_sound = AudioStreamPlayer.new()
				add_child(_sound)
			_sound.stream = stream
			_sound.play()
			return
	if parts.size() > 1:
		_caption.text = parts[1].strip_edges()  # sem o arquivo de som: a legenda conta o que se ouviria


func _animate(target: Node, anim: StringName) -> void:
	if target == null:
		return
	var animator := target.get_node_or_null("Animator")
	if animator and animator.has_method("hold"):
		if animator.call("hold", anim):
			_held.append(animator)
		return
	var found := target.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty() and (found[0] as AnimationPlayer).has_animation(anim):
		(found[0] as AnimationPlayer).play(anim)


func _attach_to_hand(thing: Node3D, who: Node3D) -> void:
	if thing == null or who == null:
		return
	var skeletons := who.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var hand := "RightHand" if skeleton.find_bone("RightHand") >= 0 else "hand_r"  # esqueleto humanoide (D028) ou o antigo
	if skeleton.find_bone(hand) < 0:
		return
	var holder := BoneAttachment3D.new()
	holder.name = "Mao_" + thing.name
	skeleton.add_child(holder)
	holder.bone_name = hand
	thing.reparent(holder, false)
	if thing.has_meta("pega"):
		# segurado por um ponto (a ponta do espeto), apontando para a frente de quem segura e um pouco para cima
		var forward := -who.global_basis.z.normalized()
		var tilt := float(thing.get_meta("inclinacao", 0.4))
		var axis := (forward * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
		var side := axis.cross(Vector3.UP).normalized()
		var basis := Basis(axis, side.cross(axis), -side)
		var grip: Vector3 = thing.get_meta("pega")
		var palm_at := holder.global_transform * Vector3(0.0, 0.06, 0.02)
		thing.global_transform = Transform3D(basis, palm_at - basis * grip)
		return
	var size := holder.global_basis.get_scale()
	# na palma, não no pulso: um pouco para a ponta do osso da mão (eixo Y do osso) e para dentro
	var palm := Vector3(0.0, 0.075, 0.025) if hand == "RightHand" else Vector3.ZERO
	thing.transform = Transform3D(Basis().scaled(Vector3(1.0 / size.x, 1.0 / size.y, 1.0 / size.z)).rotated(Vector3.FORWARD, PI / 2.0), palm / size)


func _find(path: String) -> Node:
	path = path.strip_edges()
	if path == "":
		return null
	var key := _plain(path)
	if hero and (key == "jogador" or key == _plain(String(hero.get("hero_id"))) or _plain(String(hero.get("display_name"))).begins_with(key)):
		return hero
	var root: Node = stage if stage else get_tree().current_scene
	var parts := path.split("/")
	var found := root.find_child(parts[0], true, false)
	if found and parts.size() > 1:
		found = found.get_node_or_null("/".join(parts.slice(1)))
	if found == null:
		push_warning("Roteiro: não achei '%s' na fase" % path)
	return found


func _plain(text: String) -> String:
	text = text.to_lower()
	var from := "áàâãéêíóôõúüç"
	var to := "aaaaeeiooouuc"
	for i: int in from.length():
		text = text.replace(from[i], to[i])
	return text


func _end() -> void:
	for animator: Node in _held:
		if is_instance_valid(animator):
			animator.call("release")
	_dialogue.hide()
	_caption.text = ""
	if _sound:
		_sound.stop()
	if _previous_camera and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	if _camera:
		_camera.queue_free()
	if not auto and _black.modulate.a > 0.0:
		var tween := create_tween()
		tween.tween_property(_black, "modulate:a", 0.0, 0.8)
		tween.parallel().tween_method(_set_bars, 64.0, 0.0, 0.8)
		await tween.finished
	finished.emit()
