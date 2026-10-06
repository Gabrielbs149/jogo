extends Node
## Estado da partida entre as cenas (autoload "Game"): qual herói você escolheu seguir e quem
## você já chamou para o grupo no caminho.

const TITLE_SCENE := "res://ui/title/title_screen.tscn"
const SELECT_SCENE := "res://ui/character_select/character_select.tscn"
const ARANDU := "res://levels/arandu/arandu.tscn"
const ETHERA := "res://levels/ethera/ethera.tscn"
## Onde cada herói começa a história. Quem ainda não tem começo próprio começa em Ethera.
const START_LEVELS: Dictionary[String, String] = {
	"tico": ARANDU,
}

## Os cinco heróis da história, na ordem da tela de escolha. id -> cena do herói.
const HEROES: Dictionary[String, String] = {
	"tico": "res://actors/heroes/tico_lirou.tscn",
	"naumfode": "res://actors/heroes/naumfode.tscn",
	"chumasso": "res://actors/heroes/chumasso.tscn",
	"jose_maria": "res://actors/heroes/jose_maria.tscn",
	"bahamut": "res://actors/heroes/bahamut.tscn",
}

## Quem você controla.
var chosen: String = "tico"
## Quem já entrou no grupo (sem contar você), na ordem em que entrou.
var party: Array[String] = []


func hero_scene(id: String) -> PackedScene:
	return load(HEROES[id]) as PackedScene


func start_level(hero_id: String) -> String:
	return START_LEVELS.get(hero_id, ETHERA)


func new_game(hero_id: String) -> void:
	chosen = hero_id
	party.clear()
	get_tree().change_scene_to_file(start_level(hero_id))


## Vai para outra fase levando você e o grupo.
func travel(scene_path: String) -> void:
	if scene_path == "":
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


func recruit(hero_id: String) -> void:
	if hero_id != chosen and not party.has(hero_id):
		party.append(hero_id)


func go_to_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func go_to_select() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)
