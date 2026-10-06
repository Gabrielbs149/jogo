extends Control
## Tela inicial: começar (vai para a escolha de personagem) ou sair.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	%Start.pressed.connect(Game.go_to_select)
	%Quit.pressed.connect(get_tree().quit)
	%Start.grab_focus()
