extends SceneTree
## Desenha os ícones de emoção (Emote, D060) e salva como imagem em world/vida/emotes/<tipo>.png (D067): desenhar
## pixel a pixel na hora travava o jogo uns 40 ms na primeira vez de cada tipo.
## Uso: godot --headless --path . -s tools/art/gerar_emotes.gd


func _initialize() -> void:
	for kind: String in Emote.KINDS:
		var img := Emote.draw(kind)
		print(kind, " ", img.save_png(Emote.file_for(kind)))
	quit()
