extends Node3D
## Ethera: abertura do capítulo → exploração (o grupo anda livre) → combate por turnos ao chegar num
## Encounter → volta à exploração. Os textos da história ficam no Inspector deste nó.

@export var chapter_title: String = "Ruínas de Ethera"
## Frases da abertura, uma por item.
@export var intro_lines: PackedStringArray = []
@export_multiline var victory_text: String = ""
@export_multiline var defeat_text: String = ""
## Pula a abertura (testes e simulação também pulam, por rodarem sem janela).
@export var skip_intro: bool = false

var in_combat: bool = false
var _encounter: Encounter

@onready var _terrain: MeshInstance3D = $Terrain
@onready var _navigation: NavigationRegion3D = $Navigation
@onready var _grid: CombatGrid = $Grid
@onready var _combat: CombatManager = $Combat
@onready var _party: PartyController = $Party
@onready var _combat_hud: CombatHUD = $CombatHUD
@onready var _explore_hud: ExplorationHUD = $ExplorationHUD


func _ready() -> void:
	_terrain.create_trimesh_collision()
	_combat_hud.set_result_texts(victory_text, defeat_text)
	_combat_hud.set_combat_visible(false)
	_combat.combat_ended.connect(_on_combat_ended)
	_party.setup()
	_explore_hud.setup(_party)
	_party.inspected.connect(_explore_hud.show_story)
	# A colisão precisa existir antes de montar o mapa de navegação
	await get_tree().physics_frame
	_navigation.bake_navigation_mesh(false)
	# O mapa montado precisa ser enviado ao servidor de navegação (sozinho ele não sincroniza),
	# e o grupo só anda depois que o servidor terminar (antes disso as consultas voltam vazias)
	var map := get_world_3d().navigation_map
	var probe := _party.heroes[0].global_position
	for i: int in 240:
		if i % 20 == 0:
			NavigationServer3D.region_set_navigation_mesh(_navigation.get_rid(), _navigation.navigation_mesh)
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue  # consultar antes da primeira sincronização dá erro
		if NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 3.0:
			break
	var headless := DisplayServer.get_name() == "headless"
	if not (skip_intro or headless or intro_lines.is_empty()):
		_explore_hud.visible = false
		await _combat_hud.play_intro(chapter_title, intro_lines)
		_explore_hud.visible = true
	_party.set_enabled(true)
	_explore_hud.show_area(chapter_title)


func _physics_process(_delta: float) -> void:
	if in_combat or not _party.enabled or _party.leader == null:
		return
	for node: Node in get_tree().get_nodes_in_group("encounter"):
		var encounter := node as Encounter
		if not encounter.done and _party.leader.global_position.distance_to(encounter.global_position) < encounter.radius:
			start_encounter(encounter)
			return


func start_encounter(encounter: Encounter) -> void:
	in_combat = true
	_encounter = encounter
	_party.set_enabled(false)
	_explore_hud.visible = false
	_grid.size = encounter.grid_size
	var half := Vector3(encounter.grid_size.x * _grid.cell_size / 2.0, 0.0, encounter.grid_size.y * _grid.cell_size / 2.0)
	_grid.global_position = Vector3(encounter.global_position.x, 0.0, encounter.global_position.z) - half
	_combat_hud.set_combat_visible(true)
	var participants: Array[Unit] = []
	for hero: Unit in _party.heroes:
		if hero.is_alive():
			participants.append(hero)
	participants.append_array(encounter.enemies())
	_combat.start(participants)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_combat_ended(victory: bool) -> void:
	if not victory:
		return  # tela de derrota fica; R recomeça
	if _combat.animate:
		await get_tree().create_timer(3.0).timeout
	_combat.finish_and_reset()
	_encounter.done = true
	_combat_hud.set_combat_visible(false)
	_explore_hud.visible = true
	in_combat = false
	_party.set_enabled(true)
	_explore_hud.show_story(victory_text)
