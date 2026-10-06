extends Node
## Estado da partida entre as cenas (autoload "Game"): qual herói você escolheu seguir e quem
## você já chamou para o grupo no caminho.

const TITLE_SCENE := "res://ui/title/title_screen.tscn"
const SELECT_SCENE := "res://ui/character_select/character_select.tscn"
const ARANDU := "res://levels/arandu/arandu.tscn"
const ETHERA := "res://levels/ethera/ethera.tscn"
const ARENA_ETHERA := "res://levels/arenas/ethera_arena.tscn"
const EDITOR_SCENE := "res://editor/map_editor.tscn"
## Texto de abertura da campanha, mostrado uma vez em todo jogo novo, antes da cena do herói.
const PROLOGUE := "res://story/prologo.tres"
## Onde o editor guarda a fase para o botão Testar (sem mexer no arquivo de verdade).
const EDITOR_DRAFT := "user://editor_rascunho.tscn"
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
## Luta marcada para a arena: {"id", "enemies": PackedStringArray (cenas), "first_strike", "after_text", "arena"}.
var battle: Dictionary = {}
## De onde a luta saiu, para voltar ao mesmo lugar do mapa depois.
var return_scene: String = ""
var return_transform: Transform3D = Transform3D.IDENTITY
var returning: bool = false
## Encontros já vencidos: somem do mapa.
var defeated: Array[String] = []
## Sua vida entre uma luta e outra (-1 = cheia). A fogueira enche.
var hero_hp: int = -1
## Texto da história para mostrar quando voltar ao mapa (depois do chefe, por exemplo).
var pending_story: String = ""
## Fases cuja abertura você já viu (voltar da luta não repete).
var seen: Array[String] = []
## Jogo novo: a primeira fase mostra o prólogo da campanha.
var prologue_pending: bool = false
## Editor de mapas: a fase aberta (arquivo de verdade) e, voltando do Testar, o rascunho com o que não foi salvo.
var edit_level: String = ARANDU
var edit_draft: String = ""


func hero_scene(id: String) -> PackedScene:
	return load(HEROES[id]) as PackedScene


func start_level(hero_id: String) -> String:
	return START_LEVELS.get(hero_id, ETHERA)


func new_game(hero_id: String) -> void:
	chosen = hero_id
	party.clear()
	defeated.clear()
	battle = {}
	hero_hp = -1
	returning = false
	pending_story = ""
	seen.clear()
	prologue_pending = true
	get_tree().change_scene_to_file(start_level(hero_id))


## Vai para outra fase levando você e o grupo.
func travel(scene_path: String) -> void:
	if scene_path == "":
		return
	get_tree().paused = false
	returning = false
	get_tree().change_scene_to_file(scene_path)


## Leva você para a arena. change = false só guarda os dados (testes).
func start_battle(data: Dictionary, from_scene: String, from: Transform3D, hp: int, change: bool = true) -> void:
	battle = data
	return_scene = from_scene
	return_transform = from
	hero_hp = hp
	if change:
		get_tree().change_scene_to_file(String(data.get("arena", ARENA_ETHERA)))


## Volta da arena para o mapa. Venceu: no mesmo lugar, com a vida que sobrou. Perdeu: do começo da fase, vida cheia.
func end_battle(victory: bool, hp: int) -> void:
	if victory:
		defeated.append(String(battle.get("id", "")))
		hero_hp = hp
		pending_story = String(battle.get("after_text", ""))
		returning = true
	else:
		hero_hp = -1
		returning = false
	battle = {}
	get_tree().paused = false
	get_tree().change_scene_to_file(return_scene)


func recruit(hero_id: String) -> void:
	if hero_id != chosen and not party.has(hero_id):
		party.append(hero_id)


func go_to_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func go_to_select() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)


## Abre o editor de mapas nesta fase (F2 numa fase, ou o botão da tela inicial).
func open_editor(level_path: String = "") -> void:
	if level_path == EDITOR_DRAFT:
		edit_draft = EDITOR_DRAFT  # voltando do Testar: continua de onde parou
	elif level_path != "":
		edit_level = level_path
		edit_draft = ""
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(EDITOR_SCENE)


## Joga uma fase do editor do começo, com o herói escolhido (Tico se ninguém foi escolhido), sem abertura.
func test_level(scene_path: String) -> void:
	if not HEROES.has(chosen):
		chosen = "tico"
	party.clear()
	defeated.clear()
	battle = {}
	hero_hp = -1
	returning = false
	pending_story = ""
	seen.assign([scene_path])
	get_tree().change_scene_to_file(scene_path)
