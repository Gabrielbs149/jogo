extends Control
## Tela inicial (D038): acampamento em 3D ao fundo e o menu à esquerda. Continuar (só com jogo salvo, mostra onde
## parou), Novo jogo (pergunta antes de apagar o salvo), Opções, Editor de mapas, Créditos e Sair.

const CREDITS := """[b]Feito por[/b]
Gabriel e John

[b]Personagens e cenários[/b]
Quaternius (Medieval Village, Fantasy Props, Stylized Nature) · KayKit Adventurers e animações (Kay Lousberg) · Modelos dos heróis e inimigos feitos para o jogo

[b]Música e sons[/b]
Kenney (RPG Audio, Impact, Interface, UI Audio, Music Jingles) · RandomMind, "Medieval: The Old Tower Inn" · OpenGameArt: "Desert Loop", "Heartfelt Battle", "Wind Whoosh Loop", "Fire Crackling"

[b]Céu[/b]
Poly Haven

[b]Fontes[/b]
Cinzel (Natanael Gama) · Lato (Łukasz Dziedzic)

[b]Motor[/b]
Godot Engine

Todos os pacotes de terceiros são de domínio público (CC0) ou de licença livre. Lista completa em assets/CREDITOS.md."""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Audio.play_music("arandu")
	%Start.pressed.connect(_on_new_game)
	%Continue.pressed.connect(func() -> void: Game.continue_game())
	%Options.pressed.connect(func() -> void: %OptionsMenu.open())
	%OptionsMenu.closed.connect(func() -> void: %Options.grab_focus())
	%Editor.pressed.connect(func() -> void: Game.open_editor())
	%Credits.pressed.connect(_show_credits.bind(true))
	%CreditsBack.pressed.connect(_show_credits.bind(false))
	%Quit.pressed.connect(get_tree().quit)
	%ConfirmNo.pressed.connect(_confirm.bind(false))
	%ConfirmYes.pressed.connect(func() -> void:
		_confirm(false)
		Game.go_to_select())
	%CreditsText.text = CREDITS
	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	%Version.text = "Versão de teste%s  ·  Godot %s" % [(" " + version) if version != "" else "", Engine.get_version_info()["string"]]
	var save := Game.read_save()
	%Continue.visible = not save.is_empty()
	%SaveInfo.visible = not save.is_empty()
	if not save.is_empty():
		%SaveInfo.text = Game.save_summary(save)
		%Continue.grab_focus()
	else:
		%Start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if %Confirm.visible:
		_confirm(false)
	elif %CreditsPanel.visible:
		_show_credits(false)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_new_game() -> void:
	var save := Game.read_save()
	if save.is_empty():
		Game.go_to_select()
		return
	%ConfirmText.text = "O jogo salvo (%s) vai ser substituído quando você começar." % Game.save_summary(save)
	_confirm(true)


func _confirm(on: bool) -> void:
	%Confirm.visible = on
	if on:
		%ConfirmNo.grab_focus()
	else:
		%Start.grab_focus()


func _show_credits(on: bool) -> void:
	%CreditsPanel.visible = on
	if on:
		%CreditsBack.grab_focus()
	else:
		%Credits.grab_focus()
