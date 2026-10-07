extends Node
## Som do jogo (autoload "Audio", D034): música com troca suave, ambiente em laço e efeitos por nome.
## Arquivos em assets/audio/{musica,ambiente,sfx}/. Efeito com variações: play("passo_grama") sorteia um dos
## passo_grama_0..4.ogg e varia um pouco o tom, para não soar repetido. Botões de toda tela fazem clique sozinhos.

const DIR := "res://assets/audio/"
const FOLDERS: Array[String] = ["sfx", "musica", "ambiente"]
const BUS_MUSIC := &"Musica"
const BUS_SFX := &"Efeitos"
const BUS_AMBIENT := &"Ambiente"
const FADE := 1.2

## nome -> lista de streams ("passo_grama" -> [passo_grama_0, ...])
var _banks: Dictionary[String, Array] = {}
var _music: Array[AudioStreamPlayer] = []
var _music_on: int = 0
var _music_name: String = ""
var _ambient: AudioStreamPlayer
var _ambient_name: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_banks()
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = _bus(BUS_MUSIC)
		add_child(player)
		_music.append(player)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = _bus(BUS_AMBIENT)
	add_child(_ambient)
	for i: int in 10:
		var player := AudioStreamPlayer.new()
		player.bus = _bus(BUS_SFX)
		add_child(player)
		_pool.append(player)
	get_tree().node_added.connect(_on_node_added)


## Toca a música (nome do arquivo em assets/audio/musica, sem extensão). Vazio = silêncio. A mesma não reinicia.
func play_music(music_name: String, fade: float = FADE) -> void:
	if music_name == _music_name:
		return
	_music_name = music_name
	var old := _music[_music_on]
	_fade_out(old, fade)
	if music_name == "":
		return
	var stream := _stream("musica", music_name)
	if stream == null:
		return
	_music_on = 1 - _music_on
	var player := _music[_music_on]
	player.stream = stream
	player.volume_db = -40.0
	player.play()
	create_tween().tween_property(player, "volume_db", 0.0, fade)


func stop_music(fade: float = FADE) -> void:
	play_music("", fade)


## Som de ambiente em laço (vento, fogo...). Vazio = desliga.
func play_ambient(ambient_name: String) -> void:
	if ambient_name == _ambient_name:
		return
	_ambient_name = ambient_name
	_fade_out(_ambient, FADE)
	if ambient_name == "":
		return
	var stream := _stream("ambiente", ambient_name)
	if stream:
		await get_tree().create_timer(FADE * 0.5).timeout
		_ambient.stream = stream
		_ambient.volume_db = 0.0
		_ambient.play()


## Efeito sem posição (interface, QTE, vinheta).
func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	var stream := _pick(sound)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Efeito no mundo (passos, golpes): soa de onde aconteceu.
func play_at(sound: String, position: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var stream := _pick(sound)
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.is_inside_tree():
		scene = get_tree().root
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = _bus(BUS_SFX)
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.unit_size = 4.0
	player.max_distance = 40.0
	scene.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()


func has_sound(sound: String) -> bool:
	return _banks.has(sound)


func _load_banks() -> void:
	for folder: String in FOLDERS:
		for file: String in DirAccess.get_files_at(DIR + folder):
			file = file.trim_suffix(".import").trim_suffix(".remap")
			if not (file.ends_with(".ogg") or file.ends_with(".mp3") or file.ends_with(".wav")):
				continue
			var base := file.get_basename()
			var key := base
			var parts := base.rsplit("_", true, 1)
			if parts.size() == 2 and parts[1].is_valid_int():
				key = parts[0]  # passo_grama_3 -> passo_grama
			if not _banks.has(key):
				_banks[key] = []
			var path := DIR + folder + "/" + file
			if not _banks[key].has(path):
				_banks[key].append(path)


func _pick(sound: String) -> AudioStream:
	var options: Array = _banks.get(sound, [])
	if options.is_empty():
		return null
	return load(options[randi() % options.size()]) as AudioStream


func _stream(folder: String, sound: String) -> AudioStream:
	for ext: String in [".ogg", ".mp3", ".wav"]:
		var path := DIR + folder + "/" + sound + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	push_warning("Audio: não achei %s/%s" % [folder, sound])
	return null


func _fade_out(player: AudioStreamPlayer, fade: float) -> void:
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -40.0, fade)
	tween.tween_callback(player.stop)


func _bus(bus_name: StringName) -> StringName:
	return bus_name if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("sem_som"):
		var button := node as BaseButton
		button.pressed.connect(func() -> void: play("clique", -6.0, 0.03))
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				play("passar_mouse", -18.0, 0.04))
