extends Control
## Tela inicial: começar (vai para a escolha de personagem), editor de mapas ou sair.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	%Start.pressed.connect(Game.go_to_select)
	%Editor.pressed.connect(func() -> void: Game.open_editor())
	%Quit.pressed.connect(get_tree().quit)
	%Start.grab_focus()
