class_name Revealable
extends Node2D
## Só existe na foto: invisível no jogo, aparece no negativo do flash.
## Coloque qualquer arte como filha deste nó. A legenda vai para o álbum quando ele sai na foto.

## Texto no álbum quando isto aparece numa foto. Vazio = aparece, mas sem comentário.
@export_multiline var caption: String = ""


func _ready() -> void:
	add_to_group("revealable")
	visible = false


func set_revealed(on: bool) -> void:
	visible = on


func is_on_screen() -> bool:
	var pos := get_global_transform_with_canvas().origin
	return get_viewport_rect().grow(-4.0).has_point(pos)
