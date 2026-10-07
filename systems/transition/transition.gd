extends CanvasLayer
## Troca de tela com escurecimento (autoload "Transition", D038): escurece, troca a cena e clareia.
## Toda mudança de cena do jogo passa por aqui (Game usa go()).

const OUT := 0.35
const IN := 0.45

var busy: bool = false
var _black: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color(0.03, 0.015, 0.01, 1.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)


## Vai para outra cena escurecendo a tela. reload = recomeça a cena atual.
func go(scene_path: String, reload: bool = false) -> void:
	if busy:
		return
	busy = true
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	await create_tween().tween_property(_black, "modulate:a", 1.0, OUT).finished
	get_tree().paused = false
	if reload:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	await create_tween().tween_property(_black, "modulate:a", 0.0, IN).finished
