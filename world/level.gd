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
## Cena que abre a fase na primeira vez (story/*.tres, ver story/roteiro.gd). Se tiver, substitui a abertura acima.
@export var cena_de_abertura: Roteiro
## Som da fase (D034): música (assets/audio/musica) e ambiente em laço (assets/audio/ambiente), sem extensão.
@export var musica: String = ""
@export var ambiente: String = ""
## Chão dos passos: grama, pedra, terra ou areia. Com mapa (a máscara do chão pintado), o verde é pedra e o vermelho terra.
@export var piso: String = "grama"
@export var mapa_do_piso: Texture2D
@export var area_do_mapa: float = 220.0
## De noite (D045): céu escuro com estrelas, o sol vira lua e a cidade fica com as luzes dela (postes, lanternas, tochas).
## No jogo, F3 alterna dia e noite (para testar).
@export var noite: bool = false
## Pula a abertura (testes rodam sem janela e também pulam).
@export var skip_intro: bool = false
## Sem inimigo brigando por tantos segundos, quem caiu se levanta com 1 PV (estabilizado).
@export var stabilize_after: float = 4.0

## Ligado pelo editor de mapas: a fase abre parada, só o cenário (sem você, sem luta, sem abertura).
static var editing: bool = false

const CUTSCENE := "res://story/cutscene_player.tscn"

## Depois das cenas de abertura, quando você ganha o controle (as missões começam aqui).
signal play_started

var player: Combatant
var controller: PlayerController
var companions: Array[Combatant] = []
## Heróis encontrados no caminho que ainda não entraram no grupo.
var waiting: Array[Combatant] = []
var ready_to_play: bool = false
## Uma cena (Roteiro) está tocando: o relógio para (D060).
var em_cena: bool = false
## O tempo que passa (D060), se a fase tiver um nó CicloDoDia.
var ciclo: CicloDoDia
## Grupos de inimigos do mapa que ainda não foram vencidos.
var encounters: Array[Encounter] = []
var _calm_time: float = 0.0
var _floor_image: Image
var _finished: bool = false
var _night: bool = false
var _day_env: Environment
var _day_sun: Array = []
var _night_windows: Array = []
var _night_lights: Array = []
var _night_glow: Array = []

@onready var _navigation: NavigationRegion3D = $Navigation
@onready var _camera: ThirdPersonCamera = $CameraRig
@onready var _hud: GameHUD = $HUD
@onready var _spawn: Marker3D = $PlayerSpawn


func _ready() -> void:
	# Terreno feito de malha (dunas) ganha colisão aqui; fase com chão de StaticBody não precisa de "Terrain"
	var terrain := get_node_or_null("Terrain") as MeshInstance3D
	if terrain:
		terrain.create_trimesh_collision()
		# feita aqui a cada vez: não vai para o arquivo quando o editor de mapas salva a fase
		for body: Node in terrain.get_children():
			if body is StaticBody3D:
				body.owner = null
				for part: Node in body.get_children():
					part.owner = null
	_auto_collision()
	if editing:
		return  # o editor mostra a fase de dia (a noite mexe em materiais que não podem ir para o arquivo)
	ciclo = get_node_or_null("CicloDoDia") as CicloDoDia
	if noite and ciclo == null:
		set_night(true)
	_hide_far_details()
	# voltando de uma luta: no mesmo lugar do mapa, com a vida que sobrou
	var start := _spawn.transform
	if Game.returning and Game.return_scene == scene_file_path:
		start = Game.return_transform
	Game.returning = false
	player = _spawn_hero(Game.chosen, start)
	var steps := Footsteps.new()
	steps.name = "Footsteps"
	player.add_child(steps)
	Audio.play_music(musica)
	Audio.play_ambient(ambiente)
	if Game.hero_hp >= 0:
		player.hp = clampi(Game.hero_hp, 1, player.max_hp)
	controller = PlayerController.new()
	controller.name = "PlayerController"
	controller.camera = _camera
	controller.enabled = false
	player.add_child(controller)
	_camera.target = player
	_camera.yaw = start.basis.get_euler().y
	_camera.snap()
	_hud.setup(player, controller)
	_hud.show_clock(ciclo != null)
	_hud.watch(player)
	_hud.continue_pressed.connect(func() -> void: _camera.capture(true))
	for id: String in Game.party.duplicate():
		var side := Vector3(1.5 * (companions.size() + 1), 0.0, 1.5)
		_join(_spawn_hero(id, start.translated(side)))
	for node: Node in get_tree().get_nodes_in_group("hero_spot"):
		var spot := node as HeroSpot
		if spot.hero_id == Game.chosen or Game.party.has(spot.hero_id) or not Game.HEROES.has(spot.hero_id):
			continue
		_wait_here(_spawn_hero(spot.hero_id, spot.global_transform))
	for node: Node in get_tree().get_nodes_in_group("encounter"):
		var encounter := node as Encounter
		if Game.defeated.has(encounter.id()):
			encounter.get_parent().remove_child(encounter)
			encounter.queue_free()
		else:
			encounters.append(encounter)
			encounter.triggered.connect(_on_encounter)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Combatant
		if not enemy.is_inside_tree():
			continue
		_hud.watch(enemy)
		if enemy.is_boss:
			enemy.downed_changed.connect(_on_boss_down)
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		var it := node as Interactable
		if not it.used.is_connected(_on_used):
			it.used.connect(_on_used)
	await _bake_navigation()
	var headless := DisplayServer.get_name() == "headless"
	var first_time := not Game.seen.has(scene_file_path)
	if not (skip_intro or headless):
		if Game.prologue_pending:
			Game.prologue_pending = false
			await play_cutscene(load(Game.PROLOGUE) as Roteiro)
		if first_time and cena_de_abertura:
			await play_cutscene(cena_de_abertura)
		elif first_time and not intro_lines.is_empty():
			await _hud.play_intro(chapter_title, intro_lines)
	Game.prologue_pending = false
	controller.enabled = true
	_camera.capture(true)
	_hud.show_area(chapter_title)
	if first_time:
		_hud.show_tips()
	if Game.pending_story != "":
		_hud.show_story(Game.pending_story)
		Game.pending_story = ""
	elif not Game.seen.has(scene_file_path):
		_hud.show_story(start_story)
	if not Game.seen.has(scene_file_path):
		Game.seen.append(scene_file_path)
	ready_to_play = true
	play_started.emit()
	save_here(false)


## Grava o jogo onde você está (D037): ao entrar na fase, ao voltar de uma luta, ao descansar e ao sair.
## Não grava no meio de uma luta, no editor nem no Testar do editor.
func save_here(show: bool = true) -> bool:
	if editing or player == null or not ready_to_play or _finished or in_combat():
		return false
	if not player.downed:
		Game.hero_hp = -1 if player.hp >= player.max_hp else player.hp
	var ok := Game.save_game(scene_file_path, player.global_transform)
	if ok and show:
		_hud.toast("Jogo salvo")
	return ok


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_here(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_editor") and not editing:
		Game.open_editor(scene_file_path)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F3 and not editing:
		set_night(not _night)
		_hud.toast("Noite" if _night else "Dia")


## Troca o dia pela noite (e volta): céu, luar, neblina e brilho. O dia de antes fica guardado para voltar igual.
func set_night(on: bool) -> void:
	if ciclo:
		# com o tempo passando (D060), "noite" é pular o relógio para 22h (e "dia" para o meio-dia)
		_night = on
		ciclo.jump_to(22.0 if on else 12.0)
		return
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if env_node == null or sun == null or on == _night:
		return
	if _day_env == null:
		_day_env = env_node.environment
		_day_sun = [sun.light_color, sun.light_energy, sun.rotation, sun.light_volumetric_fog_energy]
	_night = on
	_night_details(on)
	if not on:
		env_node.environment = _day_env
		sun.light_color = _day_sun[0]
		sun.light_energy = _day_sun[1]
		sun.rotation = _day_sun[2]
		sun.light_volumetric_fog_energy = _day_sun[3]
		return
	var env := _day_env.duplicate() as Environment
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/ceu_noite.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.6)
	env.ambient_light_energy = 0.32
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_exposure = 1.15
	env.ssil_intensity = 1.0
	env.glow_intensity = 0.6
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.fog_light_color = Color(0.1, 0.13, 0.22)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.35
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.55, 0.6, 0.75)
	env.volumetric_fog_ambient_inject = 0.0
	env.adjustment_saturation = 0.95
	env_node.environment = env
	# a lua: luz fria e fraca, alta no céu do leste, com sombra
	sun.light_color = Color(0.6, 0.7, 1.0)
	sun.light_energy = 0.32
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(40.0), 0.0)
	sun.light_volumetric_fog_energy = 0.4


## Só as janelas (e o brilho da fumaça): o CicloDoDia cuida da luz dos postes sozinho.
func night_windows(on: bool) -> void:
	_night_details(on, false)


## De noite: janelas acesas em 7 de cada 10 casas (as outras já dormem), postes um pouco mais fortes, e fumaça e
## água sem brilho próprio (de dia elas não recebem luz; de noite ficariam brilhando no escuro). O fogo continua aceso.
func _night_details(on: bool, lights: bool = true) -> void:
	if on:
		var lit := StandardMaterial3D.new()
		lit.albedo_color = Color(1.0, 0.78, 0.45)
		lit.emission_enabled = true
		lit.emission = Color(1.0, 0.62, 0.3)
		lit.emission_energy_multiplier = 2.2
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.08, 0.09, 0.13)
		dark.roughness = 0.2
		var buildings := get_node_or_null("Buildings")
		if buildings:
			for house: Node in buildings.get_children():
				var p := (house as Node3D).global_position if house is Node3D else Vector3.ZERO
				var awake := fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0) < 0.7
				for found: Node in house.find_children("*", "MeshInstance3D", true, false):
					var mesh := found as MeshInstance3D
					if mesh.mesh == null:
						continue
					for k: int in mesh.mesh.get_surface_count():
						var mat := mesh.get_active_material(k)
						if mat and mat.resource_name in ["MI_WindowGlass", "Windows"]:
							mesh.set_surface_override_material(k, lit if awake else dark)
							_night_windows.append([mesh, k])
		for found: Node in (find_children("*", "OmniLight3D", true, false) if lights else []):
			var light := found as OmniLight3D
			if light.omni_range < 5.0:
				continue  # fogo e velas já brilham o bastante de perto; o reforço é para postes e lanternas
			_night_lights.append([light, light.light_energy, light.omni_range])
			light.light_energy *= 1.5
			light.omni_range *= 1.25
		for found: Node in find_children("*", "GPUParticles3D", true, false):
			var parts := found as GPUParticles3D
			var mat: Material = parts.material_override
			if mat == null and parts.draw_pass_1:
				mat = parts.draw_pass_1.surface_get_material(0)
			var std := mat as StandardMaterial3D
			if std == null or std.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or std.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
				continue
			if _night_glow.any(func(pair: Array) -> bool: return pair[0] == std):
				continue
			_night_glow.append([std, std.albedo_color])
			std.albedo_color = Color(std.albedo_color.r * 0.22, std.albedo_color.g * 0.24, std.albedo_color.b * 0.3, std.albedo_color.a)
		return
	for pair: Array in _night_windows:
		if is_instance_valid(pair[0]):
			(pair[0] as MeshInstance3D).set_surface_override_material(pair[1], null)
	for item: Array in _night_lights:
		if is_instance_valid(item[0]):
			(item[0] as OmniLight3D).light_energy = item[1]
			(item[0] as OmniLight3D).omni_range = item[2]
	for pair: Array in _night_glow:
		(pair[0] as StandardMaterial3D).albedo_color = pair[1]
	_night_windows.clear()
	_night_lights.clear()
	_night_glow.clear()


## Coisa pequena longe não aparece mesmo: objetos, plantas, bichos, gente de fundo e lápides param de ser desenhados
## a partir de uma distância (casas, muralha e árvores grandes ficam sempre). Só no jogo: o editor mostra tudo.
const DETAIL_GROUPS: Array[String] = ["Props", "Gardens", "Market", "Animals", "Crowd", "Cemetery", "Lights", "Rocks", "Plaza"]


func _hide_far_details() -> void:
	for group: String in DETAIL_GROUPS:
		var holder := get_node_or_null(group)
		if holder == null:
			continue
		for found: Node in holder.find_children("*", "GeometryInstance3D", true, false):
			var mesh := found as GeometryInstance3D
			if mesh.visibility_range_end > 0.0:
				continue
			var size := mesh.get_aabb().size * mesh.global_transform.basis.get_scale()
			var longest := maxf(size.x, maxf(size.y, size.z))
			if longest < 1.5:
				mesh.visibility_range_end = 45.0
			elif longest < 4.0:
				mesh.visibility_range_end = 80.0
			else:
				continue
			mesh.visibility_range_end_margin = 5.0


## Peças do grupo "colisao_auto" (paredes, telhados, rochas e móveis dos kits) ganham colisão do formato da malha.
## Feita a cada vez que a fase abre: não vai para o arquivo. Malha com o metadado "sem_colisao" fica de fora.
func _auto_collision() -> void:
	for node: Node in get_tree().get_nodes_in_group("colisao_auto"):
		if not is_ancestor_of(node):
			continue
		for found: Node in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := found as MeshInstance3D
			if mesh.get_meta("sem_colisao", false) or mesh.mesh == null:
				continue
			mesh.create_trimesh_collision()
			for body: Node in mesh.get_children():
				if body is StaticBody3D and String(body.name).ends_with("_col"):
					(body as StaticBody3D).collision_mask = 0
					body.owner = null
					for part: Node in body.get_children():
						part.owner = null


## Toca uma cena (Roteiro) com você parado; o painel do jogo some enquanto isso.
func play_cutscene(roteiro: Roteiro) -> void:
	if roteiro == null:
		return
	if controller:
		controller.enabled = false
	_hud.visible = false
	_camera.capture(false)
	em_cena = true
	var cutscene := (load(CUTSCENE) as PackedScene).instantiate() as CutscenePlayer
	cutscene.stage = self
	cutscene.hero = player
	add_child(cutscene)
	await cutscene.play(roteiro)
	em_cena = false
	cutscene.queue_free()
	_hud.visible = true


## Conversa (D059): o herói e quem fala se viram um para o outro e a câmera chega um pouco mais perto, mirando entre
## os dois. null = acabou a conversa (a câmera volta). from_other: a câmera fica do lado de quem fala, olhando o herói
## (para quando é o herói que está fazendo alguma coisa, como acordar).
func focus_talk(with_who: Node3D, from_other: bool = false) -> void:
	if with_who == null or player == null:
		_camera.focus_off()
		return
	var me := player.global_position
	var other := with_who.global_position
	turn_toward(player, other)
	# quem fala só vira se for gente (os nós de conversa ficam dentro da pessoa)
	if with_who.has_method("face") or with_who.get_node_or_null("Figure") != null:
		turn_toward(with_who, me)
	var mid := (me + other) / 2.0 + Vector3.UP * (_camera.height - 0.25)
	var to_other := (me - other) if from_other else (other - me)
	var look_yaw: Variant = atan2(-to_other.x, -to_other.z) if Vector2(to_other.x, to_other.z).length() > 0.3 else null
	_camera.focus_on(mid, clampf(me.distance_to(other) + 1.6, 2.4, 3.6), look_yaw)


## Vira alguém (só no giro) para olhar um ponto, num instante curto.
func turn_toward(who: Node3D, point: Vector3) -> void:
	if who == null:
		return
	if who.has_method("face"):
		who.call("face", point)
		return
	var flat := point - who.global_position
	flat.y = 0.0
	if flat.length() < 0.05:
		return
	if who is Combatant:
		# o personagem vira sozinho para face_dir (Combatant._physics_process); depois solta
		var hero := who as Combatant
		var dir := flat.normalized()
		hero.desired_velocity = Vector3.ZERO
		hero.face_dir = dir
		# o tween é do próprio herói: some junto com ele (nada fica apontando para um herói que já saiu da fase)
		var release := hero.create_tween()
		release.tween_interval(0.6)
		release.tween_callback(func() -> void:
			if hero.face_dir == dir:
				hero.face_dir = Vector3.ZERO)
		return
	var yaw := atan2(-flat.x, -flat.z)  # a frente é -Z
	var tween := who.create_tween()
	tween.tween_property(who, "rotation:y", who.rotation.y + wrapf(yaw - who.global_rotation.y, -PI, PI), 0.25)


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


## Encostou num grupo de inimigos (ou acertou um antes): vai para a arena.
func _on_encounter(encounter: Encounter, first_strike: bool) -> void:
	if not ready_to_play or _finished:
		return
	_finished = true
	controller.enabled = false
	Game.start_battle(encounter.data(first_strike), scene_file_path, player.global_transform, player.hp)


func _spawn_hero(id: String, where: Transform3D) -> Combatant:
	var hero := Game.hero_scene(id).instantiate() as Combatant
	hero.transform = where
	add_child(hero)
	if id == "tico":
		AdagaPsiquica.equip_for_field(hero)  # D057: ataca com as adagas também fora da luta
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


## Tipo de chão neste ponto, para os passos.
func surface_at(point: Vector3) -> String:
	if mapa_do_piso == null:
		return piso
	if _floor_image == null:
		_floor_image = mapa_do_piso.get_image()
	var size := _floor_image.get_size()
	var px := clampi(int((point.x / area_do_mapa + 0.5) * size.x), 0, size.x - 1)
	var pz := clampi(int((point.z / area_do_mapa + 0.5) * size.y), 0, size.y - 1)
	var c := _floor_image.get_pixel(px, pz)
	if c.g > 0.5:
		return "pedra"
	if c.r > 0.5:
		return "terra"
	return piso


func _on_used(_by: Combatant, what: Interactable) -> void:
	var sound: String = ["ler", "descansar", "conversar", "viajar", "conversar"][what.action]
	Audio.play(sound, -4.0)
	match what.action:
		Interactable.Action.READ:
			turn_toward(player, what.global_position)  # examinar: o herói vira para a coisa (D059)
			_hud.show_story(what.text)
		Interactable.Action.REST:
			if in_combat():
				_hud.toast("Não dá para descansar com inimigos por perto")
				return
			player.rest()
			Game.hero_hp = -1
			for c: Combatant in companions:
				c.rest()
			_hud.show_story(what.text)
			save_here()
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
	for encounter: Encounter in encounters:
		if is_instance_valid(encounter):
			encounter.check(player)
		if _finished:
			return  # foi para a arena: a troca de cena já tirou a fase da árvore
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
