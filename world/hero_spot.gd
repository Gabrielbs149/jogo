class_name HeroSpot
extends Marker3D
## Onde um herói da história espera para ser encontrado. Arraste na fase e escolha quem.
## Se for o herói que você escolheu seguir, o lugar fica vazio (você começa no PlayerSpawn).

## Chave em Game.HEROES: "tico", "naumfode", "chumasso", "jose_maria", "bahamut".
@export var hero_id: String = "tico"


func _ready() -> void:
	add_to_group("hero_spot")
