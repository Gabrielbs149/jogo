class_name Level
extends Node3D
## Raiz de toda fase. Cria você (Game.chosen) no PlayerSpawn e quem já está no grupo ao seu lado;
## os heróis da história que ainda não entraram esperam nos HeroSpot (F conversa e convida).
## A luta é em tempo real e começa quando um inimigo percebe você. Derrotar o chefe (is_boss) fecha o capítulo.
## Também cuida de F nas coisas da fase (ler, descansar, conversar, viajar), cair/levantar e da abertura.
## Os textos da história ficam no Inspector deste nó.

@export var chapter_title: String = "Ruínas de Ethera"
## Frases da abertura, uma por item.
@export var intro_lines: PackedStringArray = []
## Aparece no painel de história logo depois da abertura (dica de começo, por exemplo).
@export_multiline var start_story: String = ""
@export_multiline var victory_text: String = ""
@export_multiline var defeat_text: String = ""
## Pula a abertura (testes rodam sem janela e também pulam).
@export var skip_intro: bool = false
## Sem inimigo brigando por tantos segundos, quem caiu se levanta com 1 PV (estabilizado).
@export var stabilize_after: float = 4.0

var player: Combatant
var controller: PlayerController
var companions: Array[Combatant] = []
## Heróis encontrados no caminho que ainda não entraram no grupo.
var waiting: Array[Combatant] = []
var ready_to_play: bool = false
var _calm_time: float = 0.0
var _finished: bool = false

@onready var _navigation: NavigationRegion3D = $Navigation
@onready var _camera: ThirdPersonCamera = $CameraRig
@onready var _hud: GameHUD = $HUD
@onready var _spawn: Marker3D = $PlayerSpawn


func _ready() -> void:
	# Terreno feito de malha (dunas) ganha colisão aqui; fase com chão de StaticBody não precisa de "Terrain"
	var terrain := get_node_or_null("Terrain") as MeshInstance3D
	if terrain:
		terrain.create_trimesh_collision()
	player = _spawn_hero(Game.chosen, _spawn.transform)
	controller = PlayerController.new()
	controller.name = "PlayerController"
	controller.camera = _camera
	controller.enabled = false
	player.add_child(controller)
	_camera.target = player
	_camera.yaw = _spawn.rotation.y
	_camera.snap()
	_hud.setup(player, controller)
	_hud.watch(player)
	_hud.continue_pressed.connect(func() -> void: _camera.capture(true))
	for id: String in Game.party.duplicate():
		var side := Vector3(1.5 * (companions.size() + 1), 0.0, 1.5)
		_join(_spawn_hero(id, _spawn.transform.translated(side)))
	for node: Node in get_tree().get_nodes_in_group("hero_spot"):
		var spot := node as HeroSpot
		if spot.hero_id == Game.chosen or Game.party.has(spot.hero_id) or not Game.HEROES.has(spot.hero_id):
			continue
		_wait_here(_spawn_hero(spot.hero_id, spot.transform))
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Combatant
		_hud.watch(enemy)
		if enemy.is_boss:
			enemy.downed_changed.connect(_on_boss_down)
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		var it := node as Interactable
		if not it.used.is_connected(_on_used):
			it.used.connect(_on_used)
	await _bake_navigation()
	var headless := DisplayServer.get_name() == "headless"
	if not (skip_intro or headless or intro_lines.is_empty()):
		await _hud.play_intro(chapter_title, intro_lines)
	controller.enabled = true
	_camera.capture(true)
	_hud.show_area(chapter_title)
	_hud.show_story(start_story)
	ready_to_play = true


func in_combat() -> bool:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Combatant
		if enemy == null or not enemy.is_active():
			continue
		var brain := enemy.get_node_or_null("AIBrain") as AIBrain
		if brain and brain.aggro:
			return true
	return false


## Chama o herói para o grupo: vira aliado controlado pela IA e segue você.
func join(hero: Combatant) -> void:
	_join(hero)


func _spawn_hero(id: String, where: Transform3D) -> Combatant:
	var hero := Game.hero_scene(id).instantiate() as Combatant
	hero.transform = where
	add_child(hero)
	return hero


func _wait_here(hero: Combatant) -> void:
	hero.recruitable = true
	waiting.append(hero)
	var brain := AIBrain.new()
	brain.name = "AIBrain"
	brain.mode = AIBrain.Mode.WAITING
	hero.add_child(brain)
	var talk := Interactable.new()
	talk.name = "Talk"
	talk.action = Interactable.Action.TALK
	talk.prompt_text = "Falar com %s" % hero.display_name
	talk.position = Vector3.UP
	hero.add_child(talk)
	talk.used.connect(_on_used)


func _join(hero: Combatant) -> void:
	hero.recruitable = false
	waiting.erase(hero)
	var brain := hero.get_node_or_null("AIBrain") as AIBrain
	if brain == null:
		brain = AIBrain.new()
		brain.name = "AIBrain"
		hero.add_child(brain)
	brain.mode = AIBrain.Mode.COMPANION
	brain.leader = player
	brain.slot = companions.size()
	companions.append(hero)
	Game.recruit(hero.hero_id)
	var talk := hero.get_node_or_null("Talk")
	if talk:
		talk.queue_free()
	_hud.add_party_member(hero)


func _on_used(_by: Combatant, what: Interactable) -> void:
	match what.action:
		Interactable.Action.READ:
			_hud.show_story(what.text)
		Interactable.Action.REST:
			if in_combat():
				_hud.toast("Não dá para descansar com inimigos por perto")
				return
			player.rest()
			for c: Combatant in companions:
				c.rest()
			_hud.show_story(what.text)
		Interactable.Action.TRAVEL:
			if in_combat():
				_hud.toast("Não dá para sair no meio de uma luta")
				return
			Game.travel(what.target_scene)
		Interactable.Action.TALK:
			var hero := what.get_parent() as Combatant
			controller.enabled = false
			var yes := await _hud.ask_recruit(hero)
			controller.enabled = true
			if yes and is_instance_valid(hero):
				_join(hero)
				_hud.toast("%s entrou no grupo" % hero.display_name)


func _physics_process(delta: float) -> void:
	if player == null or _finished or not ready_to_play:
		return
	if in_combat():
		_calm_time = 0.0
	else:
		_calm_time += delta
		if _calm_time > stabilize_after:
			for c: Combatant in [player] + companions:
				if c.downed:
					c.revive(1)
					_hud.toast("%s se levanta (1 PV)" % c.display_name)
	if player.downed:
		for c: Combatant in companions:
			if c.is_active():
				return
		_finished = true
		# deixa a queda aparecer antes da tela de derrota (ela pausa o jogo)
		await get_tree().create_timer(1.6).timeout
		_hud.show_result(false, defeat_text)


func _on_boss_down(is_down: bool) -> void:
	if not is_down or _finished:
		return
	await get_tree().create_timer(2.0).timeout
	_hud.show_result(true, victory_text)


func _bake_navigation() -> void:
	# A colisão precisa existir antes de montar o mapa de navegação
	await get_tree().physics_frame
	_navigation.bake_navigation_mesh(false)
	# O mapa montado precisa ser enviado ao servidor de navegação (sozinho ele não sincroniza);
	# antes da primeira sincronização as consultas voltam vazias
	var map := get_world_3d().navigation_map
	var probe := player.global_position
	for i: int in 240:
		if i % 20 == 0:
			NavigationServer3D.region_set_navigation_mesh(_navigation.get_rid(), _navigation.navigation_mesh)
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		if NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 3.0:
			break
