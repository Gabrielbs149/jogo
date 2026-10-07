extends Control
## Tela inicial: continuar o jogo salvo (D037), começar (vai para a escolha de personagem), editor de mapas ou sair.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	%Start.pressed.connect(Game.go_to_select)
	%Continue.visible = Game.has_save()
	%Continue.pressed.connect(func() -> void: Game.continue_game())
	%Editor.pressed.connect(func() -> void: Game.open_editor())
	%Quit.pressed.connect(get_tree().quit)
	if %Continue.visible:
		%Continue.grab_focus()
	else:
		%Start.grab_focus()
