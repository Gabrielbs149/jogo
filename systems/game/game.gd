extends Node
## Estado da partida entre as cenas (autoload "Game"): qual herói você escolheu seguir e quem
## você já chamou para o grupo no caminho. Também grava e carrega o jogo (D037): um arquivo só, salvo sozinho.

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
## Versão do arquivo de jogo salvo (sobe quando o formato mudar).
const SAVE_VERSION := 1
## Nome de cada fase para mostrar (jogo salvo).
const LEVEL_NAMES: Dictionary[String, String] = {
	ARANDU: "Arandu",
	ETHERA: "Ruínas de Ethera",
}
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
## Arquivo do jogo salvo (os testes trocam por outro).
var save_path: String = "user://save.json"
## Jogando uma fase pelo Testar do editor: não grava por cima do jogo de verdade.
var testing: bool = false


func _ready() -> void:
	# rodando os testes (GUT): grava em outro arquivo, para não estragar o jogo salvo de verdade
	for arg: String in OS.get_cmdline_args():
		if arg.contains("gut_cmdln"):
			save_path = "user://save_testes.json"


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
	testing = false
	Transition.go(start_level(hero_id))


# --- jogo salvo (D037) ---------------------------------------------------------------------------

func has_save() -> bool:
	return not read_save().is_empty()


## Uma linha para mostrar o jogo salvo: "Tico-Lirou · Arandu · 07/10 às 08:12".
func save_summary(data: Dictionary) -> String:
	var parts: PackedStringArray = []
	var hero := hero_scene(String(data["heroi"])).instantiate() as Combatant
	parts.append(hero.display_name)
	hero.free()
	parts.append(String(LEVEL_NAMES.get(String(data["fase"]), String(data["fase"]).get_file().get_basename().capitalize())))
	var when := String(data.get("quando", ""))
	if when.length() >= 16:
		parts.append("%s/%s às %s" % [when.substr(8, 2), when.substr(5, 2), when.substr(11, 5)])
	return "  ·  ".join(parts)


## Grava a partida: herói, grupo, lutas vencidas, vida, fases já vistas e onde você está no mapa.
func save_game(level_path: String, where: Transform3D) -> bool:
	if testing or level_path == "" or not HEROES.has(chosen):
		return false
	var data := {
		"versao": SAVE_VERSION,
		"heroi": chosen,
		"grupo": party,
		"vencidos": defeated,
		"vida": hero_hp,
		"vistas": seen,
		"fase": level_path,
		"posicao": [where.origin.x, where.origin.y, where.origin.z],
		"giro": where.basis.get_euler().y,
		"quando": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Game: não deu para gravar em %s" % save_path)
		return false
	file.store_string(JSON.stringify(data, "	"))
	return true


## Lê o jogo salvo. Vazio se não tem, está estragado ou aponta para algo que não existe mais.
func read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK or not json.data is Dictionary:
		return {}
	var data := json.data as Dictionary
	for key: String in ["heroi", "fase", "posicao"]:
		if not data.has(key):
			return {}
	if not HEROES.has(String(data["heroi"])) or not ResourceLoader.exists(String(data["fase"])):
		return {}
	if not data["posicao"] is Array or (data["posicao"] as Array).size() != 3:
		return {}
	return data


## Continua o jogo salvo: volta para a fase e o lugar onde estava. false se não tem jogo salvo.
func continue_game(change: bool = true) -> bool:
	var data := read_save()
	if data.is_empty():
		return false
	chosen = String(data["heroi"])
	party.clear()
	for id: Variant in data.get("grupo", []):
		if HEROES.has(String(id)) and String(id) != chosen:
			party.append(String(id))
	defeated.assign((data.get("vencidos", []) as Array).map(func(v: Variant) -> String: return String(v)))
	seen.assign((data.get("vistas", []) as Array).map(func(v: Variant) -> String: return String(v)))
	hero_hp = int(data.get("vida", -1))
	battle = {}
	pending_story = ""
	prologue_pending = false
	testing = false
	var p: Array = data["posicao"]
	return_scene = String(data["fase"])
	return_transform = Transform3D(Basis(Vector3.UP, float(data.get("giro", 0.0))), Vector3(float(p[0]), float(p[1]), float(p[2])))
	returning = true
	if change:
		get_tree().paused = false
		Transition.go(return_scene)
	return true


## Vai para outra fase levando você e o grupo.
func travel(scene_path: String) -> void:
	if scene_path == "":
		return
	get_tree().paused = false
	returning = false
	Transition.go(scene_path)


## Leva você para a arena. change = false só guarda os dados (testes).
func start_battle(data: Dictionary, from_scene: String, from: Transform3D, hp: int, change: bool = true) -> void:
	battle = data
	return_scene = from_scene
	return_transform = from
	hero_hp = hp
	if change:
		Transition.go(String(data.get("arena", ARENA_ETHERA)))


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
	Transition.go(return_scene)


func recruit(hero_id: String) -> void:
	if hero_id != chosen and not party.has(hero_id):
		party.append(hero_id)


func go_to_title() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("save_here"):
		scene.call("save_here", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Transition.go(TITLE_SCENE)


func go_to_select() -> void:
	Transition.go(SELECT_SCENE)


## Abre o editor de mapas nesta fase (F2 numa fase, ou o botão da tela inicial).
func open_editor(level_path: String = "") -> void:
	if level_path == EDITOR_DRAFT:
		edit_draft = EDITOR_DRAFT  # voltando do Testar: continua de onde parou
	elif level_path != "":
		edit_level = level_path
		edit_draft = ""
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Transition.go(EDITOR_SCENE)


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
	testing = true
	seen.assign([scene_path])
	Transition.go(scene_path)
