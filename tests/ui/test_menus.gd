extends GutTest
## Menus no padrão de jogo (D038): Opções gravam e valem na hora; a tela inicial só mostra "Continuar" com jogo
## salvo e pergunta antes do "Novo jogo" passar por cima dele.

const TITLE: PackedScene = preload("res://ui/title/title_screen.tscn")
const OPTIONS: PackedScene = preload("res://ui/options/options_menu.tscn")
const SAVE := "user://save_teste_menus.json"
const CFG := "user://opcoes_teste_menus.cfg"

var _old_save: String
var _old_cfg: String


func before_each() -> void:
	_old_save = Game.save_path
	_old_cfg = Settings.path
	Game.save_path = SAVE
	Settings.path = CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))


func after_each() -> void:
	Settings.reset_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	Game.save_path = _old_save
	Settings.path = _old_cfg


func test_volume_changes_the_bus_and_is_saved() -> void:
	var bus := AudioServer.get_bus_index(&"Musica")
	var full := AudioServer.get_bus_volume_db(bus)
	Settings.set_value("volume_musica", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), full - (linear_to_db(0.8) - linear_to_db(0.5)), 0.01)
	Settings.set_value("volume_musica", 0.0)
	assert_true(AudioServer.is_bus_mute(bus), "zero = mudo")
	Settings.set_value("inverter_y", true)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(CFG), OK)
	assert_eq(cfg.get_value("opcoes", "inverter_y"), true)
	assert_eq(cfg.get_value("opcoes", "volume_musica"), 0.0)


func test_options_menu_slider_changes_the_setting() -> void:
	var menu := OPTIONS.instantiate() as OptionsMenu
	add_child_autofree(menu)
	menu.open()
	var slider: HSlider = null
	for node: Node in menu.find_children("*", "HSlider", true, false):
		if node.get_meta("chave", "") == "volume_efeitos":
			slider = node as HSlider
	assert_not_null(slider)
	slider.value = 0.35
	assert_almost_eq(float(Settings.value("volume_efeitos")), 0.35, 0.001)
	assert_gt(menu.find_children("*", "Label", true, false).filter(func(l: Node) -> bool: return l.theme_type_variation == &"Keycap").size(), 10, "aba Teclas tem as teclas desenhadas")


func test_title_without_save_has_no_continue() -> void:
	var title := TITLE.instantiate() as Control
	add_child_autofree(title)
	await wait_physics_frames(2)
	assert_false(title.get_node("%Continue").visible)


func test_title_with_save_continues_and_asks_before_new_game() -> void:
	Game.chosen = "tico"
	assert_true(Game.save_game(Game.ARANDU, Transform3D.IDENTITY))
	var title := TITLE.instantiate() as Control
	add_child_autofree(title)
	await wait_physics_frames(2)
	assert_true(title.get_node("%Continue").visible)
	assert_string_contains((title.get_node("%SaveInfo") as Label).text, "Arandu")
	(title.get_node("%Start") as Button).pressed.emit()
	assert_true(title.get_node("%Confirm").visible, "pergunta antes de apagar o salvo")
	(title.get_node("%ConfirmNo") as Button).pressed.emit()
	assert_false(title.get_node("%Confirm").visible)
	assert_true(Game.has_save(), "cancelar não mexe no salvo")


## D074: trocar a tecla de uma ação muda o InputMap na hora, aparece nas dicas, fica gravada e o "Restaurar padrão"
## devolve a de fábrica.
func test_rebinding_a_key() -> void:
	var before := Settings.key_name(&"sprint")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	Settings.rebind(&"sprint", key)
	var down := InputEventKey.new()
	down.physical_keycode = KEY_K
	down.pressed = true
	assert_true(InputMap.event_is_action(down, &"sprint"), "K agora corre")
	assert_eq(Settings.key_name(&"sprint"), "K")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(CFG), OK)
	assert_eq(String(cfg.get_value("teclas", "sprint")), "k:%d" % KEY_K)
	Settings.reset_defaults()
	assert_eq(Settings.key_name(&"sprint"), before, "volta a tecla de fábrica")
	assert_false(InputMap.event_is_action(down, &"sprint"))


## D074: trocar para uma tecla que já é de outra ação do mesmo grupo avisa (as duas ficam com ela).
func test_rebinding_warns_about_a_clash() -> void:
	var clash := Settings.rebind(&"sneak", Settings._key_event(&"dodge"))
	assert_eq(clash, "Esquivar")


## D074: a qualidade põe os itens dela; mexer num item vira "personalizada".
func test_quality_presets() -> void:
	Settings.set_value("qualidade", 0)
	assert_eq(int(Settings.value("sombras")), 1)
	assert_false(bool(Settings.value("oclusao")))
	Settings.set_value("qualidade", 3)
	assert_eq(int(Settings.value("antisserrilhado")), 4)
	Settings.set_value("sombras", 0)
	assert_eq(int(Settings.value("qualidade")), 4, "personalizada")
	Settings.set_value("qualidade", 2)
	assert_eq(int(Settings.value("sombras")), 2)


## D074: o controle de videogame anda, gira a câmera e golpeia.
func test_gamepad_is_mapped() -> void:
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	assert_true(InputMap.event_is_action(stick, &"move_forward"))
	var look := InputEventJoypadMotion.new()
	look.axis = JOY_AXIS_RIGHT_X
	look.axis_value = 1.0
	assert_true(InputMap.event_is_action(look, &"look_right"))
	var x := InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	x.pressed = true
	assert_true(InputMap.event_is_action(x, &"attack"))


## D074: opções antigas (só "tela_cheia") viram o modo de tela novo.
func test_old_fullscreen_setting_is_migrated() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("opcoes", "tela_cheia", true)
	cfg.save(CFG)
	Settings.load_file()
	assert_eq(int(Settings.value("modo_tela")), 1)
