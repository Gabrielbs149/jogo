extends Node
## Troca de fase com fade (autoload "Game"). Uma porta chama Game.change_level(cena, "NomeDoSpawn").

signal level_changed

## Nome do Marker2D (dentro de "Spawns") onde o jogador aparece na próxima fase. Vazio = spawn padrão.
var pending_spawn: String = ""

var _changing: bool = false


func is_changing() -> bool:
	return _changing


func change_level(scene_path: String, spawn: String = "") -> void:
	if _changing:
		return
	_changing = true
	pending_spawn = spawn
	Dialogue.hide_prompt()
	await Screen.fade_out(0.6)
	get_tree().change_scene_to_file(scene_path)
	# A troca acontece no fim do frame; espera a fase nova entrar
	await get_tree().process_frame
	await get_tree().process_frame
	level_changed.emit()
	await Screen.fade_in(0.6)
	_changing = false
