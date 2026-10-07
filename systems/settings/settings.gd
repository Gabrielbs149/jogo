extends Node
## Opções do jogador (autoload "Settings", D038): volumes, tela, câmera e dicas na tela.
## Ficam em user://opcoes.cfg e valem na hora em que mudam. A tela de Opções é ui/options/options_menu.tscn.

signal changed

const SECTION := "opcoes"
const DEFAULTS := {
	"volume_geral": 1.0,
	"volume_musica": 0.8,
	"volume_efeitos": 1.0,
	"volume_ambiente": 0.8,
	"tela_cheia": false,
	"vsync": true,
	"sensibilidade": 1.0,
	"inverter_y": false,
	"dicas": true,
}
## Canal de áudio de cada volume.
const BUSES := {"volume_geral": &"Master", "volume_musica": &"Musica", "volume_efeitos": &"Efeitos", "volume_ambiente": &"Ambiente"}

## Arquivo das opções (os testes trocam por outro).
var path: String = "user://opcoes.cfg"
var _values: Dictionary = DEFAULTS.duplicate()
## Volume de cada canal no default_bus_layout (o 100% de cada barra).
var _base_db: Dictionary = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg.contains("gut_cmdln"):
			path = "user://opcoes_testes.cfg"
	for key: String in BUSES:
		var bus := AudioServer.get_bus_index(BUSES[key])
		_base_db[key] = AudioServer.get_bus_volume_db(bus) if bus >= 0 else 0.0
	load_file()


func value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


## Muda uma opção, aplica e grava.
func set_value(key: String, v: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: opção desconhecida %s" % key)
		return
	_values[key] = v
	_apply(key)
	save_file()
	changed.emit()


func reset_defaults() -> void:
	_values = DEFAULTS.duplicate()
	for key: String in _values:
		_apply(key)
	save_file()
	changed.emit()


## Quanto o mouse gira a câmera (multiplica a sensibilidade da câmera).
func mouse_factor() -> float:
	return float(value("sensibilidade"))


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for key: String in DEFAULTS:
			var v: Variant = cfg.get_value(SECTION, key, DEFAULTS[key])
			if typeof(v) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and v is int):
				_values[key] = v
	for key: String in _values:
		_apply(key)


func save_file() -> void:
	var cfg := ConfigFile.new()
	for key: String in _values:
		cfg.set_value(SECTION, key, _values[key])
	cfg.save(path)


func _apply(key: String) -> void:
	if BUSES.has(key):
		var bus := AudioServer.get_bus_index(BUSES[key])
		if bus < 0:
			return
		var v := clampf(float(_values[key]), 0.0, 1.0)
		AudioServer.set_bus_mute(bus, v <= 0.001)
		AudioServer.set_bus_volume_db(bus, float(_base_db.get(key, 0.0)) + linear_to_db(maxf(v, 0.001)))
		return
	if DisplayServer.get_name() == "headless":
		return
	match key:
		"tela_cheia":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _values[key] else DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _values[key] else DisplayServer.VSYNC_DISABLED)
