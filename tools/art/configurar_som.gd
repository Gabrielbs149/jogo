extends SceneTree
## Configura o som do projeto (D034): canais de volume (default_bus_layout.tres), música/ambiente/chão de cada
## fase e o estalo do fogo em assets/vfx/fogo.tscn. Uso: godot --headless --path . -s tools/art/configurar_som.gd


func _initialize() -> void:
	_buses()
	_fire()
	(load("res://world/level.gd") as GDScript).set("editing", true)
	_level("res://levels/arandu/arandu.tscn", {"musica": "arandu", "ambiente": "", "piso": "grama",
		"mapa_do_piso": load("res://levels/arandu/art/chao_mascara.res")})
	_level("res://levels/ethera/ethera.tscn", {"musica": "ethera", "ambiente": "vento", "piso": "areia"})
	quit()


func _buses() -> void:
	for spec: Array in [["Musica", -4.0], ["Efeitos", -2.0], ["Ambiente", -10.0]]:
		if AudioServer.get_bus_index(spec[0]) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, spec[0])
			AudioServer.set_bus_send(i, &"Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(spec[0]), spec[1])
	print("canais: ", ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres"))


func _fire() -> void:
	var path := "res://assets/vfx/fogo.tscn"
	var fire := (load(path) as PackedScene).instantiate()
	var old := fire.get_node_or_null("Estalo")
	if old:
		fire.remove_child(old)
		old.free()
	var sound := AudioStreamPlayer3D.new()
	sound.name = "Estalo"
	sound.stream = load("res://assets/audio/ambiente/fogo.ogg")
	sound.autoplay = true
	sound.bus = &"Ambiente"
	sound.volume_db = 4.0
	sound.unit_size = 2.5
	sound.max_distance = 14.0
	fire.add_child(sound)
	sound.owner = fire
	var packed := PackedScene.new()
	packed.pack(fire)
	print("fogo: ", ResourceSaver.save(packed, path))
	fire.free()


func _level(path: String, props: Dictionary) -> void:
	var level := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	root.add_child(level)
	for key: String in props:
		level.set(key, props[key])
	var packed := PackedScene.new()
	print(path, ": ", packed.pack(level), " ", ResourceSaver.save(packed, path))
	level.free()
