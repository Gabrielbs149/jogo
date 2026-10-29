class_name BattleArena
extends Node3D
## Luta por turnos no estilo Clair Obscur: só você contra o grupo do encontro, numa arena separada.
## Seu turno: ataque (1, sempre livre) ou habilidade (Q/E/R), que depois fica alguns turnos recarregando (D052).
## O d20 aparece rolando e diz se acertou (D&D);
## se acertou, o golpe com tempo diz quanto do dano entra (D048): anel, barra, sequência, martelar ou segurar.
## Turno do inimigo: ele rola contra a sua CA; se acertou, você se defende (anel, direção, combo ou finta).
## Postura: golpes bons quebram o inimigo (perde a vez, +50%).
## Fúria: o chefe com metade da vida ataca duas vezes.
## Monta tudo a partir de Game.battle; no fim, Game.end_battle() volta para o mapa.
## Visual (D047, do Look Outside): em primeira pessoa. A câmera fica nos olhos do herói (que aparece só pela sombra),
## o inimigo grande na frente, e quem fala aparece na caixa de texto. As regras não mudam.

signal finished(victory: bool)

## Tempo (s) do anel no seu golpe.
@export var attack_qte_time: float = 0.62
## Janelas (s) do seu golpe: perfeito e bom (D048: mais apertadas).
@export var perfect_window: float = 0.055
@export var good_window: float = 0.14
## Janelas (s) da defesa: quanto a defesa fica de pé depois de apertar (D084, os números do Expedition 33 no normal).
@export var dodge_window: float = 0.22
@export var parry_window: float = 0.15
@export_group("Visual")
## Primeira pessoa (D047). Desligado: a câmera da cena, de longe, como antes.
@export var first_person: bool = true
@export var eye_height: float = 0.6
## Quanto a câmera fica atrás do herói (ele está invisível; só a sombra aparece).
@export var eye_back: float = 0.5
@export var view_fov: float = 50.0
@export_group("Teste e simulador")
## A IA joga por você e "aperta" os QTE com estas chances.
@export var auto_play: bool = false
@export var auto_perfect: float = 0.5
@export var auto_good: float = 0.3
@export var auto_dodge: float = 0.4
@export var auto_parry: float = 0.2

var player: Combatant
var enemies: Array[Combatant] = []
var target: Combatant
## Recarga das habilidades (D052): índice -> turnos que faltam (0 ou ausente = pronta).
var recharge: Dictionary = {}
var round_number: int = 0
var order: Array[Combatant] = []
var _first_strike: bool = false
var _homes: Dictionary = {}
var _marker: Label3D
var _camera: Camera3D
var _look: Vector3 = Vector3.ZERO
var _shake: float = 0.0
## Quem a câmera olha agora (o inimigo que está atacando); vazio = o grupo todo.
var _focus: Combatant
var _last_grade: String = ""
## Luta tutorial (D086, a primeira do Tico, no celeiro de Arandu): dicas na hora de cada coisa, o anel da defesa
## aparece e as janelas são as do fácil. As dicas já dadas ficam aqui.
var _tutorial: bool = false
var _taught: Dictionary = {}
## Falas do começo no lugar de "as adagas acendem" (Game.battle["intro"]: [[quem, fala], ...]).
var _intro_lines: Array = []
var _fury: Dictionary = {}
## Poções por luta (D050).
var potions: int = 2
var _fled: bool = false
## Câmera da ação (D050): mostra o herói atacando; null = primeira pessoa.
var _action_target: Combatant
var _action_on: bool = false
var _cam_eye := Vector3.ZERO
var _cam_look := Vector3.ZERO
## Plano fixo da cena do golpe (D053): calculado uma vez, com corte seco (a câmera não passeia em volta do herói).
var _shot_eye := Vector3.ZERO
var _shot_look := Vector3.ZERO
## Adagas psíquicas do Tico (D051): uma em cada mão, e um par na frente da câmera na primeira pessoa.
var _daggers: Array[AdagaPsiquica] = []
var _view_rig: Node3D
var _view_daggers: Array[AdagaPsiquica] = []
var _view_time: float = 0.0

@onready var _hud: BattleHUD = $BattleHUD
@onready var _fx: CombatFX = $FX
@onready var _player_slot: Marker3D = $PlayerSlot
@onready var _enemy_slots: Node3D = $EnemySlots
@onready var _boss_slot: Marker3D = $BossSlot


func _ready() -> void:
	CombatRules.turn_mode = true
	var data := Game.battle
	if data.is_empty():
		data = {"id": "teste", "enemies": PackedStringArray(["res://actors/enemies/escaravelho_de_cinza.tscn"]), "first_strike": false}
	_first_strike = bool(data.get("first_strike", false))
	_tutorial = bool(data.get("tutorial", false))
	_intro_lines.assign(data.get("intro", []))
	player = _spawn(Game.hero_scene(Game.chosen), _player_slot.transform)
	if Game.hero_hp >= 0:
		player.hp = clampi(Game.hero_hp, 1, player.max_hp)
	var slots := _enemy_slots.get_children()
	var slot := 0
	for path: String in data["enemies"]:
		var scene := load(path) as PackedScene
		var probe := scene.instantiate() as Combatant
		var boss := probe.is_boss
		probe.free()
		var where: Transform3D = _boss_slot.transform if boss else (slots[slot % slots.size()] as Node3D).transform
		if not boss:
			slot += 1
		enemies.append(_spawn(scene, where))
	var hp_mult: float = ENEMY_HP[difficulty()]
	if not is_equal_approx(hp_mult, 1.0):
		for e: Combatant in enemies:
			e.max_hp = ceili(e.max_hp * hp_mult)
			e.hp = e.max_hp
	for c: Combatant in [player] + enemies:
		_face(c, enemies[0] if c == player else player)
		_homes[c] = c.transform
	target = enemies[0]
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera:
		# a câmera da arena é posta a cada quadro (_process): sem suavização de física (o motor avisava, D082)
		_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_marker = Label3D.new()
	_marker.text = "▼"
	_marker.font_size = 96
	_marker.pixel_size = 0.0022 if first_person else 0.004
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.modulate = Color(1, 0.85, 0.4)
	add_child(_marker)
	_hud.setup(self)
	_hud.dice().landed.connect(_on_dice_landed)
	for enemy: Combatant in enemies:
		enemy.downed_changed.connect(func(down: bool) -> void:
			if down and alive_enemies().is_empty() and not auto_play:
				_final_blow())
	_fx.hitstop_enabled = not auto_play
	var model := player.get_node_or_null("Model") as Node3D
	if model:
		_hud.setup_portrait(model)  # antes de sumir com o herói (o retrato é uma cópia dele)
	if player.hero_id == "tico":
		_daggers = AdagaPsiquica.attach_to(player)
		_dagger_animations()
	if first_person and _camera:
		_first_person_view()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i: int in 3:
		await get_tree().physics_frame
	_run()


func _process(delta: float) -> void:
	if _view_rig:
		# as adagas da tela respiram (sobe e desce devagar, balança um pouco)
		_view_time += delta
		_view_rig.position = Vector3(sin(_view_time * 1.3) * 0.006, sin(_view_time * 2.6) * 0.008, 0.0)
	if first_person and _camera and is_instance_valid(player):
		_update_view(delta)
	if _marker and target and is_instance_valid(target) and target.hp > 0 and not _action_on:
		_marker.visible = true
		var above := (3.6 if target.is_boss else 1.35) if first_person else (3.8 if target.is_boss else 2.3)
		_marker.global_position = target.global_position + Vector3.UP * above
	elif _marker:
		_marker.visible = false


func can_afford(index: int) -> bool:
	return index >= 0 and index < player.abilities.size() and int(recharge.get(index, 0)) <= 0


func alive_enemies() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for e: Variant in enemies:
		if is_instance_valid(e) and (e as Combatant).hp > 0:
			result.append(e as Combatant)
	return result


func cycle_target(direction: int) -> void:
	var alive := alive_enemies()
	if alive.is_empty():
		target = null
		return
	var i := alive.find(target) if is_instance_valid(target) else -1
	target = alive[(i + direction + alive.size()) % alive.size()] if i >= 0 else alive[0]


func is_over() -> bool:
	return _fled or not player.is_active() or alive_enemies().is_empty()


func _run() -> void:
	var rolls := {}
	for c: Combatant in [player] + enemies:
		rolls[c] = Dice.d20() + c.dex_save
	order.assign([player] + enemies)
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return rolls[a] > rolls[b])
	if _first_strike:
		order.erase(player)
		order.push_front(player)
	Audio.play_music("batalha", 0.6)
	Audio.play_ambient("")
	_hud.banner("Primeiro golpe!" if _first_strike else "Luta!")
	for dagger: AdagaPsiquica in _daggers + _view_daggers:
		dagger.materialize()
	if not auto_play:
		if not _intro_lines.is_empty():
			Audio.play("aparar", -6.0, 0.0)
			for line: Variant in _intro_lines:
				await _hud.say(String(line[0]), String(line[1]), 0.3)
				await _teach_wait(String(line[1]).length() / 25.0 + 1.2)
		elif not _view_daggers.is_empty():
			Audio.play("aparar", -6.0, 0.0)
			await _hud.say(player.display_name, "As adagas psíquicas acendem nas mãos de %s." % player.display_name, 0.3)
		await _hud.say("", _intro_text(), 0.5)
		var line := _battle_line(enemies[0])
		if line != "":
			await _hud.say(enemies[0].display_name, line, 0.7)
	else:
		await _wait(0.8)
	while not is_over():
		round_number += 1
		for entry: Variant in order.duplicate():
			if is_over():
				break
			if not is_instance_valid(entry) or not (entry as Combatant).is_active():
				continue
			var actor := entry as Combatant
			_hud.set_order(order, actor)
			if actor == player:
				await _player_turn()
			elif actor.quebrado:
				# quebrado: perde esta vez e volta ao normal (D048)
				actor.quebrado = false
				actor.postura = 0
				if not auto_play:
					await _hud.say(actor.display_name, "%s ainda está zonzo e não consegue atacar." % actor.display_name, 0.4)
			else:
				await _enemy_turn(actor)
				# Fúria (D048): o chefe com metade da vida ou menos ataca duas vezes
				if actor.is_boss and actor.is_active() and player.is_active() and actor.hp * 2 <= actor.max_hp:
					if not _fury.has(actor):
						_fury[actor] = true
						_hud.banner("FÚRIA!", Color(1, 0.35, 0.3))
						if not auto_play:
							await _hud.say(actor.display_name, "**%s entra em fúria!** Agora ataca duas vezes." % actor.display_name, 0.6)
					await _enemy_turn(actor, true)
			if is_instance_valid(actor):
				actor.end_turn()
			_hud.refresh()
	if _fled:
		CombatRules.turn_mode = false
		Audio.stop_music(0.8)
		finished.emit(false)
		if not auto_play:
			Game.flee_battle(player.hp)
		return
	var victory := player.is_active()
	CombatRules.turn_mode = false
	Audio.stop_music(0.8)
	Audio.play("vitoria" if victory else "derrota", -2.0, 0.0)
	finished.emit(victory)
	if auto_play:
		return
	await _wait(1.6 if victory else 1.8)
	var text := ("Sobrou %d de %d PV." % [player.hp, player.max_hp]) if victory else "Você volta para o começo da fase, com a vida cheia."
	if not victory and Game.battle.has("texto_derrota"):
		text = String(Game.battle["texto_derrota"])
	await _hud.show_result(victory, text)
	Game.end_battle(victory, player.hp)


# ---------- seu turno

func _player_turn() -> void:
	Audio.play("turno", -8.0, 0.0)
	player.sneak_ready_at = 0.0
	for k: Variant in recharge.keys():
		recharge[k] = maxi(0, int(recharge[k]) - 1)
	if target == null or not is_instance_valid(target) or target.hp <= 0:
		cycle_target(1)
	var index: int
	if auto_play:
		index = _auto_choice()
		await get_tree().process_frame
	else:
		await _teach_turn()
		_hud.say(player.display_name, "O que %s vai fazer?" % player.display_name)
		index = await _hud.choose_action()
	if index >= EXTRA_BASE:
		await _extra_action(index)
		return
	var ability := player.abilities[index]
	if ability.recharge_turns() > 0:
		recharge[index] = ability.recharge_turns() + 1  # o +1 é este turno (desconta no começo do próximo)
	_hud.refresh()
	await _player_action(index)


## D048/D050: o d20 diz se acerta (aparece rolando); se acertou, o anel diz quanto do dano entra; aí a câmera
## sai dos seus olhos e mostra o herói atacando (animação dele, rastro do golpe, o inimigo apanhando).
func _player_action(index: int) -> void:
	var ability := player.abilities[index]
	var tgt: Combatant = target if ability.is_offensive() else player
	var melee := ability.is_offensive() and (ability.shape == Ability.Shape.DASH or (ability.shape == Ability.Shape.TARGET and not ability.projectile))
	if tgt != player:
		_face(player, tgt)
	var point := tgt.global_position
	var results := CombatRules.resolve(player, ability, tgt if ability.needs_target() else null, point, CombatRules.everyone(get_tree()))
	await _show_dice(results)
	var fumble := _natural(results) == 1
	var landed := results.filter(func(r: Dictionary) -> bool: return int(r["amount"]) > 0)
	if not landed.is_empty():
		var outcome := await _damage_qte(ability, landed.size(), tgt)
		_after_grade(String(outcome["grade"]))
		CombatRules.scale_damage(results, float(outcome["mult"]), String(outcome["grade"]))
		var bonus := ritmo_level()
		if bonus > 0:
			for r: Dictionary in results:
				if int(r["amount"]) > 0:
					r["amount"] = int(r["amount"]) + bonus
					r["text"] = "%s +%d ritmo %s = %d" % [r["text"], bonus, ritmo_letter(), r["amount"]]
		ritmo_gain(2 if String(outcome["grade"]) in ["perfeito", "bom"] else 1)
		for r: Dictionary in results:
			var t := r["target"] as Combatant
			if is_instance_valid(t) and t.quebrado and int(r["amount"]) > 0:
				CombatRules.scale_damage([r] as Array[Dictionary], 1.5, "quebrado")
	# a cena do golpe
	if ability.is_offensive() and not fumble:
		_view_pose("thrust")
		await _wait(0.18)
	_action_cam(tgt)
	await _wait(0.3)
	var rush := melee and not _daggers.is_empty() and not fumble
	if rush:
		await _dagger_rush(tgt, ability)
	else:
		if melee:
			await _approach(player, tgt.global_position, 1.3 if not tgt.is_boss else 2.2)
		for dagger: AdagaPsiquica in _daggers:
			dagger.trail(true)
			dagger.flare(0.6)
		player.ability_used.emit(index)
		Audio.play_at("golpe", player.global_position, -3.0)
		await _wait(0.22)  # o golpe chega
	if fumble:
		# 1 natural: tropeça (e diz isso)
		player.dodged.emit()
		_shake = 0.2
		if not auto_play:
			_hud.say(player.display_name, "%s tropeça no próprio rabo!" % player.display_name)
	elif ability.projectile and tgt != player:
		await _fx.projectile(player.global_position, point, ability.vfx_color, ability.projectile_scene)
	elif ability.shape in [Ability.Shape.AREA, Ability.Shape.ALLIES_AROUND, Ability.Shape.ENEMIES_AROUND, Ability.Shape.CONE, Ability.Shape.LINE]:
		_fx.ring(point if ability.shape == Ability.Shape.AREA else player.global_position, maxf(ability.radius_m, 2.0), ability.vfx_color)
	if ability.is_offensive() and not fumble and not ability.projectile:
		for r: Dictionary in results:
			var t := r["target"] as Combatant
			if is_instance_valid(t):
				var high := 1.6 if t.is_boss else 0.55
				var crit: bool = r["kind"] == "crit"
				var color := Color(1.0, 0.85, 0.45) if crit else (AdagaPsiquica.PINK if not _daggers.is_empty() else ability.vfx_color)
				var size := 1.6 if t.is_boss else 1.0
				if _daggers.is_empty():
					_fx.slash(t.global_position + Vector3.UP * high, t.global_position - player.global_position, color, size)
				else:
					# as duas adagas: um corte em X, roxo (dourado no crítico), e faíscas roxas
					_fx.slash(t.global_position + Vector3.UP * high, t.global_position - player.global_position, color, size, 0.75)
					_fx.slash(t.global_position + Vector3.UP * high, t.global_position - player.global_position, color, size, -0.75)
					_fx.sparks(t.global_position + Vector3.UP * high, AdagaPsiquica.PURPLE, 20 if crit else 12)
	for r: Dictionary in results:
		var t := r["target"] as Combatant
		if r["kind"] in ["miss", "save"] and is_instance_valid(t) and t != player and not fumble and not t.is_boss:
			t.dodged.emit()  # o inimigo desvia (o chefe não: a esquiva dele salta para fora do plano)
		if r["kind"] == "crit":
			_shake = 0.3
			_hud.flash(Color(1.0, 0.82, 0.35), 0.35)
	if ability.is_offensive() and not fumble and not landed.is_empty():
		hitstop("pesado" if results.any(func(r: Dictionary) -> bool: return r["kind"] == "crit") else "leve")
	CombatRules.apply(player, ability, results, _fx)
	for r: Dictionary in results:
		_add_posture(r["target"] as Combatant, int(r["amount"]) + (8 if _last_grade == "perfeito" else 0))
	if rush and player.is_active() and is_instance_valid(tgt) and tgt.is_active():
		await _offhand_strike(tgt, "Mão de trás")
	if ability.is_offensive():
		player.remove_flag("invisible")
	await _wait(0.3 if rush else 0.6)
	if rush and player.is_active():
		await _dagger_recoil(tgt)
	for dagger: AdagaPsiquica in _daggers:
		dagger.trail(false)
	if rush and player.is_active():
		player.transform = _homes[player]  # no corte ele já está no lugar (ninguém vê ele voltando de costas)
		player.reset_physics_interpolation()
	_action_cam(null)
	if melee and player.is_active() and not rush:
		await _return_home(player)
	await _wait(0.1)


## O anel do dano (D050: um desafio só, claro e bonito). Rajada (vários golpes, investida) = um anel por golpe,
## cada um mais rápido; habilidade grande (recarga de 4 turnos) = anel mais rápido, mas o perfeito vale ×1,8.
## Devolve {"grade": "perfeito"|"bom"|"fraco", "mult"}.
func _damage_qte(ability: Ability, hits: int, on: Combatant) -> Dictionary:
	var kind := ability.damage_qte()
	if kind == Ability.Golpe.NENHUM:
		return {"grade": "bom", "mult": 1.0}
	var big := ability.recharge_turns() >= 4
	var best := 1.8 if big else 1.5
	if auto_play:
		var r := randf()
		return _grade("perfeito" if r < auto_perfect else ("bom" if r < auto_perfect + auto_good else "fraco"), best)
	var count := (hits if hits > 1 else 3) if kind == Ability.Golpe.RAJADA else 1
	await _teach("golpe", "Acertou! Agora o anel diz QUANTO entra: aperte a tecla que aparece na hora em que o anel fechar. No tempo certo é PERFEITO (mais dano).")
	var q := _hud.golpe()
	var at := _screen_of(on)
	var total := 0.0
	var grade := "bom"
	for i: int in count:
		var duration := attack_qte_time * (0.8 if big else 1.0) * pow(0.82, i)
		var res := await q.ring(at, duration, [&"dodge"], "Golpe %d de %d" % [i + 1, count] if count > 1 else "Na hora!", false, 0,
			i, count if count > 1 else 0)
		var error := absf(float(res["error"])) if res["key"] != &"" else 9.0
		grade = "perfeito" if error <= perfect_window * (0.8 if big else 1.0) else ("bom" if error <= good_window else "fraco")
		q.pop(grade)
		total += {"perfeito": best, "bom": 1.0, "fraco": 0.6}[grade]
		if count > 1:
			Audio.play("qte_" + ("errou" if grade == "fraco" else grade), -8.0, 0.0)
			await _wait(0.08)
	var avg := total / count
	if count > 1:
		grade = "perfeito" if avg >= best - 0.01 else ("bom" if avg >= 0.95 else "fraco")
	return {"grade": grade, "mult": avg}


func _grade(grade: String, perfect_mult: float = 1.5) -> Dictionary:
	return {"grade": grade, "mult": {"perfeito": perfect_mult, "bom": 1.0, "fraco": 0.6}[grade]}


## Onde fica alguém na tela (para o anel aparecer em cima dele).
func _screen_of(c: Combatant) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if c and is_instance_valid(c) and cam:
		var p := c.global_position + Vector3.UP * (1.4 if c.is_boss else 0.35)
		if not cam.is_position_behind(p):
			var s := cam.unproject_position(p)
			var size := get_viewport().get_visible_rect().size
			return Vector2(clampf(s.x, 120.0, size.x - 120.0), clampf(s.y, 120.0, size.y * 0.62))
	return _hud.scene_center() + Vector2(0, 40)


## O número natural do d20 que valeu (o primeiro resultado com dado); 0 = ninguém rolou.
func _natural(results: Array[Dictionary]) -> int:
	for r: Dictionary in results:
		if r.has("die"):
			return int((r["die"] as Dictionary)["kept"])
	return 0


# ---------- ações do meio da luta (D050): Defender, Poção, Analisar, Fugir

const EXTRA_BASE := 100
const DEFEND := 100
const POTION := 101
const ANALYZE := 102
const FLEE := 103
## D083 (do Baldur's Gate 3): empurrão.
const SHOVE := 104
## Empurrão: quanto o alvo voa para trás (m).
const SHOVE_DISTANCE := 1.8


## As ações que não são habilidade, para o menu: {"id", "key", "title", "info"}.
func extra_actions() -> Array[Dictionary]:
	return [
		{"id": DEFEND, "key": "2", "title": "Defender", "info": "+2 de armadura e a defesa fica mais fácil até a sua vez"},
		{"id": POTION, "key": "3", "title": "Poção", "info": "recupera vida (restam %d)" % potions},
		{"id": ANALYZE, "key": "4", "title": "Analisar", "info": "mostra o próximo golpe do alvo; o seu próximo ataque tem vantagem"},
		{"id": FLEE, "key": "5", "title": "Fugir", "info": "tenta escapar da luta" if not _boss_alive() else "não dá para fugir do chefe"},
		{"id": SHOVE, "key": "6", "title": "Empurrar", "info": "disputa de força: joga o alvo para trás e ele fica desequilibrado (o próximo ataque contra ele tem vantagem)"
			if not (target and is_instance_valid(target) and target.is_boss) else "o chefe é grande demais para empurrar"},
	]


func can_use_extra(id: int) -> bool:
	match id:
		POTION:
			return potions > 0 and player.hp < player.max_hp
		FLEE:
			return not _boss_alive()
		SHOVE:
			return target != null and is_instance_valid(target) and target.is_active() and not target.is_boss
	return true


func flee_dc() -> int:
	return 10 + 2 * alive_enemies().size()


func _boss_alive() -> bool:
	return alive_enemies().any(func(e: Combatant) -> bool: return e.is_boss)


func _extra_action(id: int) -> void:
	match id:
		DEFEND:
			player.add_status(_status("Defendendo", {"ac": 2}))
			ritmo_gain()
			_action_cam(player)
			player.dodged.emit()
			_fx.ring(player.global_position, 1.2, Color(0.6, 0.85, 1.0))
			await _hud.say(player.display_name, "%s se prepara: +2 CA e a defesa fica mais folgada até a vez dele." % player.display_name, 0.4)
			_action_cam(null)
		POTION:
			potions -= 1
			var amount := Dice.roll(2, 4) + 2
			player.heal(amount)
			_action_cam(player)
			var drinker := player.get_node_or_null("Animator")
			if drinker and player.find_children("*", "AnimationPlayer", true, false)[0].has_animation(&"ual/Consume"):
				drinker.call("act", &"ual/Consume", 1.2)  # D075: leva a poção à boca
			else:
				player.ability_used.emit(3)
			_fx.rising_glow(player.global_position, Color(0.5, 1.0, 0.6))
			_fx.floating_text(player.global_position, "+%d" % amount, Color(0.6, 1.0, 0.65))
			player.rolled.emit("%s bebe uma poção: 2d4+2 = %d" % [player.display_name, amount])
			await _hud.say(player.display_name, "%s bebe uma poção e recupera %d PV." % [player.display_name, amount], 0.4)
			_action_cam(null)
		ANALYZE:
			if target and is_instance_valid(target):
				target.add_status(_status("Exposto", {"expose": true}))
				await _hud.say(player.display_name, _analysis(target), 1.1)
		SHOVE:
			await _shove(target)
		FLEE:
			var roll := Dice.d20()
			var total := roll + player.dex_save
			var ok := roll != 1 and (roll == 20 or total >= flee_dc())
			await _hud.roll_dice([{"by": player, "rolls": [roll], "kept": roll, "mod": player.dex_save, "total": total, "vs": flee_dc(),
				"vs_name": "CD", "target": player, "skill": true, "verdict": "ACERTOU" if ok else "ERROU"}] as Array[Dictionary])
			if ok:
				_fled = true
				await _hud.say(player.display_name, "%s some no meio da poeira." % player.display_name, 0.5)
			else:
				await _hud.say(player.display_name, "%s tenta fugir, mas não acha saída." % player.display_name, 0.4)
	_hud.refresh()


## Golpe da mão de trás (D083, do Baldur's Gate 3): quem luta com duas armas golpeia com a segunda como ação bônus.
## Rola o acerto normal, mas o dano não soma o modificador (só o dado da arma). "Riposte" é o mesmo golpe como reação.
func _offhand_strike(tgt: Combatant, title: String) -> void:
	var off := offhand_ability(title)
	_face(player, tgt)
	var results := CombatRules.resolve(player, off, tgt, tgt.global_position, CombatRules.everyone(get_tree()))
	await _show_dice(results)
	var animator := player.get_node_or_null("Animator")
	if animator:
		animator.call("act", &"tico/Golpe_2", 1.4)  # o revés da mão esquerda (a de trás)
	await _wait(0.16)
	Audio.play_at("golpe", player.global_position, -5.0)
	for r: Dictionary in results:
		var t := r["target"] as Combatant
		if int(r["amount"]) > 0 and is_instance_valid(t):
			var high := 1.6 if t.is_boss else 0.55
			_fx.slash(t.global_position + Vector3.UP * high, t.global_position - player.global_position, AdagaPsiquica.PINK,
				1.4 if t.is_boss else 0.8, 0.9)
		elif r["kind"] == "miss" and is_instance_valid(t) and not t.is_boss:
			t.dodged.emit()
	if results.any(func(r: Dictionary) -> bool: return int(r["amount"]) > 0):
		ritmo_gain()
		hitstop("muito_leve")
	CombatRules.apply(player, off, results, _fx)
	for r: Dictionary in results:
		_add_posture(r["target"] as Combatant, int(r["amount"]))
	await _wait(0.35)


## A habilidade da mão de trás: o ataque básico do herói sem o bônus no dano.
func offhand_ability(title: String = "Mão de trás") -> Ability:
	var off := player.abilities[0].duplicate() as Ability
	off.title = title
	off.bonus = 0
	off.hits = 1
	off.dnd_note = "Ação bônus · segunda arma (sem o modificador no dano)"
	return off


## Empurrão (D083, do Baldur's Gate 3): você rola d20 + ataque contra d20 + o melhor salvamento físico do alvo. Ganhou:
## ele voa para trás e fica Desequilibrado (o próximo ataque contra ele tem vantagem, e vantagem liga o ataque furtivo).
## O chefe é grande demais.
func _shove(tgt: Combatant) -> void:
	if tgt == null or not is_instance_valid(tgt) or tgt.is_boss:
		return
	_face(player, tgt)
	var mine := Dice.d20()
	var theirs := Dice.d20()
	var my_total := mine + player.attack_bonus
	var resist := maxi(tgt.dex_save, tgt.con_save)
	var their_total := theirs + resist
	var won := mine != 1 and (mine == 20 or my_total > their_total)
	await _hud.roll_dice([{"by": player, "rolls": [mine], "kept": mine, "mod": player.attack_bonus, "total": my_total,
		"vs": their_total, "vs_name": "%s (%d+%d)" % [tgt.display_name, theirs, resist], "target": tgt,
		"skill": true, "verdict": "ACERTOU" if won else "ERROU"}] as Array[Dictionary])
	_action_cam(tgt)
	await _approach(player, tgt.global_position, 1.2)
	var animator := player.get_node_or_null("Animator")
	if animator:
		animator.call("act", &"atk/Punch_Cross", 1.5)
	await _wait(0.2)
	if won:
		Audio.play_at("golpe", tgt.global_position, 0.0)
		var away := tgt.global_position - player.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else -tgt.global_basis.z
		var fly := create_tween()
		fly.tween_property(tgt, "global_position", tgt.global_position + away * SHOVE_DISTANCE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_fx.shake(tgt)
		_add_posture(tgt, 10)
		tgt.add_status(_status("Desequilibrado", {"expose": true}))
		_fx.floating_text(tgt.global_position, "Desequilibrado", Color(1.0, 0.75, 0.4))
		player.rolled.emit("%s empurra %s: %d contra %d" % [player.display_name, tgt.display_name, my_total, their_total])
		await fly.finished
		await _wait(0.5)
		if _homes.has(tgt) and tgt.is_active():
			await _return_home(tgt)  # volta cambaleando para o lugar (empurrões seguidos o tirariam da arena)
	else:
		tgt.dodged.emit()
		player.rolled.emit("%s tenta empurrar %s e não consegue: %d contra %d" % [player.display_name, tgt.display_name, my_total, their_total])
	await _wait(0.4)
	_action_cam(null)
	await _return_home(player)


func _status(title: String, extra: Dictionary) -> Dictionary:
	var s := {"title": title, "time": 2.0, "ac": 0, "bless": 0, "invisible": false, "frighten": false, "expose": false, "mark": 0, "mark_by": null}
	s.merge(extra, true)
	return s


## O que o Analisar mostra: vida, o próximo golpe e como se defender dele.
func _analysis(enemy: Combatant) -> String:
	var next_round := round_number + (1 if order.find(enemy) < order.find(player) else 0)
	var index := 1 if enemy.abilities.size() > 1 and next_round % 3 == 0 else 0
	var ability := enemy.abilities[index]
	var how := {Ability.Defesa.ANEL: "F apara, Espaço esquiva", Ability.Defesa.DIRECAO: "pule para o lado da seta",
		Ability.Defesa.COMBO: "três golpes seguidos, apare um por um", Ability.Defesa.FINTA: "o anel engana: espere a hora de verdade"}
	return "%s: %d/%d PV, CA %d. Próximo golpe: **%s** (%s). Fica exposto: o próximo ataque tem vantagem." % [
		enemy.display_name, enemy.hp, enemy.max_hp, enemy.current_ac(), ability.title, how.get(ability.defense_qte(), "")]


## O 20 e o 1 na hora em que o dado para (D050): brilho dourado ou piscada, e a câmera treme.
func _on_dice_landed(special: String) -> void:
	if special == "20":
		_hud.flash(Color(1.0, 0.85, 0.35), 0.16)
		_shake = 0.25
	elif special == "1":
		_hud.flash(Color(0.6, 0.1, 0.1), 0.3)
		_shake = 0.15


## O aviso do resultado do tempo (PERFEITO, Bom, Fraco) e o som dele.
func _after_grade(grade: String) -> void:
	_last_grade = grade
	var text := {"perfeito": "PERFEITO!", "bom": "Bom", "fraco": "Fraco", "falhou": "Falhou"}.get(grade, grade) as String
	var color := {"perfeito": Color(1, 0.85, 0.3), "bom": Color(0.9, 0.9, 0.9)}.get(grade, Color(0.85, 0.55, 0.5)) as Color
	Audio.play("qte_perfeito" if grade == "perfeito" else ("qte_bom" if grade == "bom" else "qte_errou"), -4.0, 0.0)
	_hud.banner(text, color)
	_hud.refresh()


## Postura (D048): enche com dano e com golpes bons; cheia, o inimigo quebra.
func _add_posture(t: Combatant, amount: int) -> void:
	if t == null or not is_instance_valid(t) or t == player or t.hp <= 0 or t.quebrado or amount <= 0:
		return
	t.postura += amount
	if t.postura >= t.posture_limit():
		t.postura = t.posture_limit()
		t.quebrado = true
		hitstop("muito_pesado")
		_hud.banner("QUEBROU!  %s perde a vez" % t.display_name, Color(0.7, 0.85, 1.0))
		_fx.floating_text(t.global_position, "QUEBROU!", Color(0.7, 0.85, 1.0), true)
		t.rolled.emit("%s quebrou: perde a próxima vez e leva +50%% de dano até lá" % t.display_name)
	_hud.refresh()


## Os d20 de quem rolou aparecem na tela antes do efeito (D048).
func _show_dice(results: Array[Dictionary]) -> void:
	if auto_play:
		return
	var dice: Array[Dictionary] = []
	for r: Dictionary in results:
		if r.has("die"):
			dice.append(r["die"])
	if not dice.is_empty():
		await _hud.roll_dice(dice.slice(0, 4))


## Simulador: a habilidade mais cara que dá para pagar e faz sentido agora.
func _auto_choice() -> int:
	var best := 0
	for i: int in range(player.abilities.size() - 1, 0, -1):
		var ability := player.abilities[i]
		if not can_afford(i):
			continue
		match ability.kind:
			Ability.Kind.HEAL:
				if player.hp < player.max_hp * 0.5:
					return i
			Ability.Kind.BUFF:
				if not player.statuses.any(func(s: Dictionary) -> bool: return s["title"] == ability.status_title):
					return i
			_:
				return i
	return best


# ---------- turno do inimigo

## O inimigo rola o d20 contra a sua CA (aparece na tela); se acertou, você se defende do jeito que o golpe pede.
## extra: a segunda ação da Fúria (usa a outra habilidade).
func _enemy_turn(enemy: Combatant, extra: bool = false) -> void:
	var index := 1 if enemy.abilities.size() > 1 and (round_number % 3 == 0) != extra else 0
	var ability := enemy.abilities[index]
	await _wait(randf_range(0.35, 0.9))  # pausa variável: não dá para decorar o ritmo
	if not enemy.is_active():
		return
	_face(enemy, player)
	_focus = enemy
	if not auto_play and not extra and randf() < 0.3:
		var line := _battle_line(enemy)
		if line != "":
			await _hud.say(enemy.display_name, line, 0.4)
	var melee := ability.shape == Ability.Shape.ENEMIES_AROUND or (ability.shape == Ability.Shape.TARGET and not ability.projectile)
	if melee:
		await _approach(enemy, player.global_position, 2.9 if enemy.is_boss else 2.3)
	if auto_play:
		_hud.banner(ability.title, Color(1, 0.6, 0.5))
	else:
		await _hud.say(enemy.display_name, "%s usa **%s**!" % [enemy.display_name, ability.title])
	var results := CombatRules.resolve(enemy, ability, player if ability.needs_target() else null, player.global_position,
		CombatRules.everyone(get_tree()))
	if ability.shape == Ability.Shape.ENEMIES_AROUND and results.is_empty():
		results = CombatRules.resolve(enemy, ability, null, player.global_position, [player] as Array[Combatant])
	await _show_dice(results)
	var nat := _natural(results)
	if nat == 1:
		# 1 natural do inimigo: tropeça e erra feio
		enemy.dodged.emit()
		_fx.shake(enemy)
		if not auto_play:
			await _hud.say(enemy.display_name, "%s tropeça e erra feio!" % enemy.display_name, 0.3)
	elif nat == 20:
		_hud.banner("GOLPE CRÍTICO!", Color(1, 0.35, 0.3))
	var on_me := results.filter(func(r: Dictionary) -> bool: return r["target"] == player and int(r["amount"]) > 0)
	var level := difficulty()
	if level != 1:
		for r: Dictionary in on_me:
			CombatRules.scale_damage([r] as Array[Dictionary], ENEMY_DAMAGE[level], "fácil" if level == 0 else "difícil")
	var missed_me := melee and not _daggers.is_empty() and results.any(
		func(r: Dictionary) -> bool: return r["target"] == player and r["kind"] == "miss")
	if on_me.is_empty() or auto_play:
		# errou (ou o simulador joga): o golpe sai de uma vez; quando tem defesa, ele sai na hora dela (D082)
		_strike(enemy, index, 0.5)
		await _wait(0.5)
	var countered := false
	var held_all := false  # aparou/esquivou tudo: a tela já respondeu golpe a golpe, nada de "errou" flutuando
	if not on_me.is_empty():
		await _teach("defesa", "Ele vai atacar, e são VÁRIOS golpes seguidos. Aperte F logo ANTES de cada golpe chegar para APARAR (o anel mostra a hora). Espaço ESQUIVA, mais fácil, mas não devolve nada.")
		var defense := await _defense(ability, enemy, index)
		var keep := float(defense["keep"])
		for r: Dictionary in on_me:
			if keep <= 0.0:
				r["amount"] = 0
				r["kind"] = "miss"
				r["text"] = "%s, %s" % [r["text"], defense["text"]]
			elif keep < 1.0:
				CombatRules.scale_damage([r] as Array[Dictionary], keep, defense["text"])
		countered = bool(defense["counter"])
		_after_grade(String(defense["grade"]))
		var held := int(defense.get("parried", 0)) + int(defense.get("avoided", 0))
		if held > 0:
			ritmo_gain(held)
		elif keep < 1.0:
			ritmo_gain()
		if keep <= 0.0:
			held_all = true
			player.dodged.emit()
			if not countered:
				_fx.floating_text(player.global_position, defense["text"], Color(0.8, 0.95, 1.0))
	if ability.projectile:
		await _fx.projectile(enemy.global_position, player.global_position, ability.vfx_color, ability.projectile_scene)
	elif ability.shape == Ability.Shape.ENEMIES_AROUND:
		_fx.ring(enemy.global_position, ability.radius_m, ability.vfx_color)
	CombatRules.apply(enemy, ability, results, null if held_all else _fx)
	if on_me.any(func(r: Dictionary) -> bool: return int(r["amount"]) > 0):
		ritmo_hit()
	if countered and player.is_active() and enemy.is_active():
		await _counter_scene(enemy)
		await _teach("contra", "Aparou TODOS os golpes: CONTRA-ATAQUE. Sempre que você apara a sequência inteira, o Tico devolve na hora.")
	if missed_me and player.is_active() and is_instance_valid(enemy) and enemy.is_active():
		# D083 (Riposte, do Baldur's Gate 3): errou o golpe corpo a corpo em você? A mão de trás revida na hora
		Audio.play_at("aparar", player.global_position + Vector3.UP, 0.0)
		_fx.floating_text(player.global_position, "RIPOSTE!", Color(1, 0.85, 0.3), true)
		await _offhand_strike(enemy, "Riposte")
		await _teach("riposte", "Ele errou o golpe em você: a outra adaga revida sozinha (RIPOSTE).")
	_hud.refresh()
	await _wait(0.4)
	if melee and is_instance_valid(enemy) and enemy.is_active():
		await _return_home(enemy)
	_focus = null


## A defesa (D048), conforme o golpe do inimigo. Devolve {"keep": quanto do dano entra (0 a 1), "counter", "grade", "text"}.
## - Anel: F na hora certa APARA (nada de dano, contra-ataque); Espaço na hora ESQUIVA (metade).
## - Direção: uma seta mostra para onde pular; A ou D na hora = nada de dano. Lado errado = tudo.
## - Combo: três golpes seguidos em ritmo torto; cada um aparado/esquivado tira um terço. Os três aparados = contra-ataque.
## - Finta: o anel engana (para e abre); só vale a hora de verdade. Espaço = nada de dano.
func _defense(ability: Ability, enemy: Combatant, index: int = 0) -> Dictionary:
	var kind := ability.defense_qte()
	if auto_play:
		var r := randf()
		if r < auto_parry and kind in [Ability.Defesa.ANEL, Ability.Defesa.COMBO]:
			return {"keep": 0.0, "counter": true, "grade": "perfeito", "text": "aparou"}
		if r < auto_parry + auto_dodge:
			return {"keep": 0.5 if kind == Ability.Defesa.ANEL else 0.0, "counter": false, "grade": "bom", "text": "esquivou"}
		return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}
	var q := _hud.golpe()
	var at := _screen_of(enemy)
	var windup := 0.5 + ability.windup
	# D084 (os números do Expedition 33): apertar levanta a defesa por um instante e o golpe tem de chegar dentro dele
	var windows := defense_windows(difficulty(), parry_window, dodge_window)
	# Defendendo (D050): as janelas ficam 50% maiores
	if player.statuses.any(func(st: Dictionary) -> bool: return st["title"] == "Defendendo"):
		windows *= 1.5
	if _tutorial:
		windows = windows.max(Vector2(EASY_PARRY, EASY_DODGE))
	var parry_w := windows.x
	var dodge_w := windows.y
	# D082 (Clair Obscur): sem o anel, você lê o golpe (o anel é opção de acessibilidade); no tutorial ele aparece
	var hidden := not bool(Settings.value("anel_defesa")) and not _tutorial
	match kind:
		Ability.Defesa.DIRECAO:
			var side := -1 if randf() < 0.5 else 1
			_strike(enemy, index, GolpeQte.duration_for(windup + 0.15))
			var res := await q.ring(at, windup + 0.15, [], "Pule para o lado da seta", false, side, 0, 0, 0.1, hidden)
			var right_key := &"move_right" if side > 0 else &"move_left"
			var error := float(res["error"])
			var ok: bool = res["key"] == right_key and defense_hit(error, dodge_w)
			q.pop("bom" if ok else "falhou")
			if ok:
				_dodge_fx()
				return {"keep": 0.0, "counter": false, "grade": "perfeito" if defense_hit(error, parry_w) else "bom", "text": "desviou"}
			_struck_fx(enemy)
			return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}
		Ability.Defesa.FINTA:
			_strike(enemy, index, GolpeQte.duration_for(windup, true), true)
			var res := await q.ring(at, windup, [&"dodge"], "Cuidado com a finta", true, 0, 0, 0, 0.1, hidden)
			var error := float(res["error"])
			var ok: bool = res["key"] == &"dodge" and defense_hit(error, dodge_w)
			var grade := ("perfeito" if defense_hit(error, parry_w) else "bom") if ok else "falhou"
			q.pop(grade)
			if ok:
				_dodge_fx()
				return {"keep": 0.0, "counter": false, "grade": grade, "text": "pulou a onda"}
			_struck_fx(enemy)
			return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}
	# anel e combo: a sequência de golpes (D085)
	return await _sequence(enemy, ability, index, at, windup, parry_w, dodge_w, hidden)


## D085 (como no Expedition 33): o inimigo ataca em SEQUÊNCIA. Os comuns dão 2 ou 3 golpes, o chefe 4 a 6 (mais um na
## habilidade forte e na fúria). Cada golpe se defende sozinho: aparar ou esquivar tira aquele golpe; aparar TODOS =
## contra-ataque. No meio vem a pegadinha: ele segura o golpe (para no meio) e só então bate.
func _sequence(enemy: Combatant, ability: Ability, index: int, at: Vector2, windup: float, parry_w: float,
		dodge_w: float, hidden: bool) -> Dictionary:
	var q := _hud.golpe()
	var count := strikes_in(enemy, ability, index)
	var parried := 0
	var avoided := 0
	for i: int in count:
		var delayed := i > 0 and randf() < 0.28
		var beat := windup if i == 0 else randf_range(0.36, 0.56)
		var duration := GolpeQte.duration_for(beat, delayed)
		var outcome := {"kind": "", "done": false}
		_strike(enemy, index, duration, delayed)
		_impact_watch(enemy, duration, outcome)
		var res := await q.ring(at, beat, [&"dodge", &"parry"], "F apara · Espaço esquiva", delayed, 0, i, count, 0.1, hidden)
		var error := float(res["error"])
		if res["key"] == &"parry" and defense_hit(error, parry_w):
			outcome["kind"] = "parry"
			parried += 1
			q.pop("perfeito")
			_view_pose("cross")
		elif res["key"] == &"dodge" and defense_hit(error, dodge_w):
			outcome["kind"] = "dodge"
			avoided += 1
			q.pop("bom")
			_dodge_fx()
		else:
			outcome["kind"] = "hit"
			q.pop("falhou")
		# apertou cedo: o anel fecha antes da batida; o próximo golpe só vem depois que este chegou
		while not bool(outcome["done"]) and is_inside_tree():
			await get_tree().process_frame
		await _wait(0.08)
	var keep := 1.0 - (parried + avoided) / float(count)
	var all_parried := parried == count
	return {"keep": keep, "counter": all_parried, "grade": "perfeito" if all_parried else ("bom" if keep < 0.5 else "falhou"),
		"text": ("aparou os %d" % count) if all_parried else ("segurou %d de %d" % [parried + avoided, count]),
		"parried": parried, "avoided": avoided}


## Quantos golpes vêm na sequência (D085).
func strikes_in(enemy: Combatant, ability: Ability, index: int) -> int:
	var count := randi_range(4, 6) if enemy.is_boss else randi_range(2, 3)
	if index > 0:
		count += 1
	if _fury.has(enemy):
		count += 1
	if ability.defense_qte() == Ability.Defesa.COMBO:
		count = maxi(count, 3)
	return count


## Na hora em que o golpe chega, a tela responde ao que você fez (e não ao aperto): aparou, esquivou ou levou.
## Espera a folga da tela depois da batida para quem apertou em cima da hora.
func _impact_watch(enemy: Combatant, duration: float, outcome: Dictionary) -> void:
	await _elapsed(duration)
	var t := 0.0
	while String(outcome["kind"]) == "" and t < DEFENSE_GRACE + 0.02:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not is_instance_valid(enemy) or not is_inside_tree():
		outcome["done"] = true
		return
	match String(outcome["kind"]):
		"parry":
			_parry_fx(enemy)
		"dodge":
			Audio.play_at("esquiva", enemy.global_position, -2.0)  # o golpe passa assobiando
		_:
			_struck_fx(enemy)
	outcome["done"] = true


## Aparou (D085): o tempo para um instante, as lâminas batem com um estalo, faíscas douradas no meio, a tela pisca, a
## câmera dá um tranco e ele é jogado para trás.
func _parry_fx(enemy: Combatant) -> void:
	# o choque é onde as adagas cruzadas estão: na frente dos olhos (de longe, a câmera da cena)
	var clash := player.global_position.lerp(enemy.global_position, 0.6) + Vector3.UP * (1.1 if enemy.is_boss else 0.55)
	if _camera and first_person and not _action_on:
		clash = _camera.global_position - _camera.global_basis.z * 1.3 + _camera.global_basis.y * -0.12
	hitstop("medio")
	Audio.play_at("aparar", clash, 3.0)
	Audio.play_at("golpe", clash, -4.0)
	_hud.flash(Color(1.0, 0.93, 0.7), 0.22)
	_fx.sparks(clash, Color(1.0, 0.82, 0.35), 48)
	_fx.sparks(clash, Color(1.0, 1.0, 1.0), 22)
	_shake = maxf(_shake, 0.25)
	_fov_kick(-8.0)
	for dagger: AdagaPsiquica in _view_daggers:
		dagger.flare(0.9)
	if enemy.model:
		var push := create_tween()
		push.tween_interval(0.04)
		push.tween_property(enemy.model, "position:z", 0.55, 0.09).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		push.parallel().tween_property(enemy.model, "rotation:x", -0.18, 0.09)
		push.tween_property(enemy.model, "position:z", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		push.parallel().tween_property(enemy.model, "rotation:x", 0.0, 0.3)


## Esquivou: o Tico pula para o lado (a câmera vai junto), as adagas saem do caminho e o golpe passa assobiando.
func _dodge_fx() -> void:
	Audio.play_at("esquiva", player.global_position, 0.0)
	_view_pose("dodge")
	_hop(player)
	_shake = maxf(_shake, 0.08)


## Levou o golpe: a tela pisca vermelho, treme forte e o golpe pesa.
func _struck_fx(enemy: Combatant) -> void:
	Audio.play_at("golpe", player.global_position, 2.0)
	_hud.flash(Color(0.9, 0.05, 0.08), 0.5)
	_shake = maxf(_shake, 0.4)
	_fov_kick(5.0)
	hitstop("leve")
	_fx.sparks(player.global_position + Vector3.UP * 0.6 + (enemy.global_position - player.global_position).normalized() * 0.4,
		Color(1.0, 0.5, 0.4), 18)


## A câmera "respira" com o impacto: fecha (ou abre) o campo de visão e volta.
func _fov_kick(amount: float) -> void:
	if _camera == null or not first_person or _action_on:
		return
	var kick := create_tween()
	kick.tween_property(_camera, "fov", view_fov + amount, 0.05).set_ease(Tween.EASE_OUT)
	kick.tween_property(_camera, "fov", view_fov, 0.35).set_trans(Tween.TRANS_SINE)


## Aparou a sequência inteira (D085): o contra-ataque vira cena. A câmera mostra o Tico, ele salta no inimigo e corta
## em X; o tempo para no impacto.
func _counter_scene(enemy: Combatant) -> void:
	_hud.banner("CONTRA-ATAQUE!", Color(1.0, 0.85, 0.3))
	player.rolled.emit("%s aparou tudo e contra-ataca" % player.display_name)
	var counter := CombatRules.resolve(player, player.abilities[0], enemy, enemy.global_position, CombatRules.everyone(get_tree()), 1)
	var dagger_scene := not _daggers.is_empty() and not auto_play
	if dagger_scene:
		_action_cam(enemy)
		await _wait(0.12)
		await _dagger_rush(enemy, player.abilities[0])
	else:
		player.ability_used.emit(0)
	ritmo_gain()
	if counter.any(func(r: Dictionary) -> bool: return int(r["amount"]) > 0):
		var high := 1.6 if enemy.is_boss else 0.55
		var at := enemy.global_position + Vector3.UP * high
		var facing := enemy.global_position - player.global_position
		var size := 1.6 if enemy.is_boss else 1.05
		_fx.slash(at, facing, Color(1.0, 0.85, 0.4), size, 0.75)
		_fx.slash(at, facing, Color(1.0, 0.85, 0.4), size, -0.75)
		_fx.sparks(at, Color(1.0, 0.85, 0.4), 40)
		_hud.flash(Color(1.0, 0.85, 0.35), 0.18)
		_shake = maxf(_shake, 0.35)
		hitstop("muito_pesado")
	CombatRules.apply(player, player.abilities[0], counter, _fx)
	for r: Dictionary in counter:
		_add_posture(enemy, int(r["amount"]) + 10)
	if dagger_scene:
		await _wait(0.4)
		if player.is_active():
			await _dagger_recoil(enemy)
		_action_cam(null)
		await _return_home(player)


## D084 (a tabela de dificuldade do Expedition 33): apertar levanta a defesa por "window" segundos e o golpe tem de
## chegar dentro dela. error = hora do aperto - hora do impacto: antes do golpe vale até "window"; depois dele, só a
## folga da tela (DEFENSE_GRACE). Martelar não ajuda: só o primeiro aperto conta.
const DEFENSE_GRACE := 0.03
## No fácil (Expedition 33): aparar 0,35 s e esquivar 0,5 s; no normal e no difícil, parry_window e dodge_window.
const EASY_PARRY := 0.35
const EASY_DODGE := 0.5
## Fácil, normal e difícil: o dano dos inimigos e a vida deles (Expedition 33: ataque ×0,25 no fácil; ×2 e vida
## ×1,25 no difícil).
const ENEMY_DAMAGE: Array[float] = [0.25, 1.0, 2.0]
const ENEMY_HP: Array[float] = [1.0, 1.0, 1.25]


static func defense_hit(error: float, window: float) -> bool:
	return error >= -window and error <= DEFENSE_GRACE


## 0 fácil, 1 normal, 2 difícil (a opção "dificuldade").
static func difficulty() -> int:
	return clampi(int(Settings.value("dificuldade")), 0, 2)


## As janelas da defesa (aparar, esquivar) na dificuldade.
static func defense_windows(level: int, parry: float, dodge: float) -> Vector2:
	return Vector2(EASY_PARRY, EASY_DODGE) if level == 0 else Vector2(parry, dodge)


## D084 (a tabela DT_FreezeFrame do Expedition 33): no golpe que entra o tempo quase para por um instante (s, tempo
## real). O peso diz quanto: o golpe comum é leve, o crítico pesado, a quebra de postura muito pesada.
const HITSTOP := {"muito_leve": 0.04, "leve": 0.07, "medio": 0.11, "pesado": 0.14, "muito_pesado": 0.2}
var _hitstop_end: int = 0


func hitstop(weight: String) -> void:
	var seconds: float = HITSTOP.get(weight, 0.0)
	if auto_play or seconds <= 0.0 or not is_inside_tree():
		return
	_hitstop_end = maxi(_hitstop_end, Time.get_ticks_msec() + int(seconds * 1000.0))
	Engine.time_scale = 0.001
	# o timer de tempo real chega uns ms antes; espera até o fim de verdade (de todos os congelamentos juntos)
	while Time.get_ticks_msec() < _hitstop_end and is_inside_tree():
		await get_tree().create_timer(maxf((_hitstop_end - Time.get_ticks_msec()) / 1000.0, 0.005), true, false, true).timeout
	# só volta quem ainda está congelado (a câmera lenta do golpe final pode ter entrado no meio)
	if Engine.time_scale < 0.01:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	if Engine.time_scale < 0.01:
		Engine.time_scale = 1.0


## Dica da luta tutorial (D086): uma vez por luta, na caixa de texto; espera a pessoa ler (Enter, F ou 1 passam).
func _teach(key: String, text: String) -> void:
	if not _tutorial or auto_play or _taught.has(key):
		return
	_taught[key] = true
	await _hud.say("Dica", text)
	await _teach_wait(text.length() / 22.0 + 2.0)


## Espera a pessoa ler: Enter, F, Espaço ou 1 passam antes do tempo.
func _teach_wait(seconds: float) -> void:
	var t := 0.0
	await get_tree().process_frame
	while t < seconds and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		for action: StringName in [&"ui_accept", &"interact", &"battle_attack"]:
			if InputMap.has_action(action) and Input.is_action_just_pressed(action):
				return


## As dicas do começo da sua vez: atacar, os golpes especiais, o Ritmo e a postura (cada uma quando aparece).
func _teach_turn() -> void:
	if not _tutorial:
		return
	if not _taught.has("atacar"):
		await _teach("atacar", "Sua vez. Aperte 1 para atacar com as adagas. O d20 decide se acerta a CA dele; as setas trocam de alvo.")
		return
	await _teach("especiais", "Q, E e R são golpes especiais: mais fortes, mas depois ficam alguns turnos recarregando. 2 DEFENDE (a defesa fica mais folgada), 6 EMPURRA.")
	if ritmo_level() > 0:
		await _teach("ritmo", "O RITMO (a letra no canto) sobe com cada coisa bem feita: golpe no tempo, aparar, esquivar. Cada letra soma dano. Apanhar derruba uma letra.")
	if enemies.any(func(e: Combatant) -> bool: return is_instance_valid(e) and e.quebrado):
		await _teach("quebra", "A barrinha azul embaixo da vida dele é a POSTURA. Cheia, ele QUEBRA: perde a vez e leva mais dano.")


## D084 (a Perfeição do Verso, Expedition 33): cada coisa bem feita na luta soma 1 no Ritmo (golpe, golpe no tempo,
## aparar, esquivar, contra-atacar, defender); levar dano derruba um nível. Níveis D, C, B, A e S aos 0, 3, 8, 15 e 30
## pontos; cada nível acima do D soma +1 no dano dos seus golpes.
const RITMO_LEVELS: Array[int] = [0, 3, 8, 15, 30]
const RITMO_LETTERS := ["D", "C", "B", "A", "S"]
var ritmo: int = 0


func ritmo_level() -> int:
	var level := 0
	for i: int in RITMO_LEVELS.size():
		if ritmo >= RITMO_LEVELS[i]:
			level = i
	return level


func ritmo_letter() -> String:
	return RITMO_LETTERS[ritmo_level()]


## Quanto do caminho até o próximo nível (0 a 1; no S, cheio).
func ritmo_progress() -> float:
	var level := ritmo_level()
	if level >= RITMO_LEVELS.size() - 1:
		return 1.0
	return float(ritmo - RITMO_LEVELS[level]) / float(RITMO_LEVELS[level + 1] - RITMO_LEVELS[level])


func ritmo_gain(amount: int = 1) -> void:
	var before := ritmo_level()
	ritmo = mini(ritmo + amount, 99)
	if ritmo_level() > before and is_instance_valid(player):
		Audio.play("qte_perfeito", -2.0, 0.0)
		if _hud and ritmo_level() >= 3:
			_hud.banner("RITMO %s!" % ritmo_letter(), Color(1.0, 0.8, 0.35))
	if _hud:
		_hud.refresh()


func ritmo_hit() -> void:
	if ritmo_level() > 0:
		Audio.play("qte_errou", -4.0, 0.0)
	ritmo = RITMO_LEVELS[maxi(ritmo_level() - 1, 0)]
	if _hud:
		_hud.refresh()


## Onde, na animação de golpe do inimigo, a arma chega (fração do tempo dela; as do KayKit batem por volta da metade).
const IMPACT_AT := 0.45
## Quanto antes do impacto vem o aviso (brilho na arma e o assobio).
const CUE_BEFORE := 0.3
## O bote leva este tempo até a batida (CombatFX.lunge vai do recuo até a frente).
const LUNGE_LEAD := 0.06


## O golpe do inimigo com o impacto em "at" segundos (D082, como no Clair Obscur): a animação de golpe dele toca no
## ritmo certo para a arma chegar nessa hora; um pouco antes a arma brilha e assobia (o aviso, o principal no Clair
## Obscur); no impacto, o bote e o som do golpe. feint: o golpe para no meio (segura) e só então vem, na hora da finta.
func _strike(enemy: Combatant, index: int, at: float, feint: bool = false) -> void:
	var animator := enemy.get_node_or_null("Animator")
	var anims: Array = animator.get("ability_animations") if animator else []
	var anim: StringName = anims[index] if index < anims.size() else &""
	var found := enemy.find_children("*", "AnimationPlayer", true, false)
	var anim_player := found[0] as AnimationPlayer if not found.is_empty() else null
	var hold := at * (GolpeQte.FEINT_GO - GolpeQte.FEINT_STOP) if feint else 0.0
	if animator and anim_player and anim != &"" and anim_player.has_animation(anim):
		var impact := anim_player.get_animation(anim).length * IMPACT_AT
		var active := maxf(at - hold, 0.15)
		# perto do ritmo dele: se sobra tempo, ele espera e então ataca (câmera lenta parecia golpe boiando)
		var speed := clampf(impact / active, 0.85, 1.8)
		var start := active - impact / speed  # > 0: começa depois; < 0: já começa adiantado
		_strike_anim(animator, anim_player, anim, speed, start, at * GolpeQte.FEINT_STOP if feint else -1.0, hold)
	_strike_cue(enemy, maxf(at - CUE_BEFORE, 0.0), at)


func _strike_anim(animator: Node, anim_player: AnimationPlayer, anim: StringName, speed: float, start: float,
		hold_at: float, hold: float) -> void:
	if start > 0.0:
		await _elapsed(start)
	animator.call("act", anim, speed)
	if start < 0.0:
		anim_player.seek(-start * speed, true)
	if hold > 0.0:
		await _elapsed(maxf(hold_at - maxf(start, 0.0), 0.0))
		anim_player.speed_scale = 0.0
		await _elapsed(hold)
		anim_player.speed_scale = speed


func _strike_cue(enemy: Combatant, cue: float, at: float) -> void:
	# o preparo se vê no corpo: recua e se ergue até o aviso (carregando o golpe), e aí vem o bote
	if enemy.model:
		var windup := create_tween().set_parallel()
		windup.tween_property(enemy.model, "position:z", 0.3, maxf(cue, 0.05)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		windup.tween_property(enemy.model, "position:y", 0.08, maxf(cue, 0.05)).set_ease(Tween.EASE_OUT)
	await _elapsed(cue)
	if not is_instance_valid(enemy):
		return
	# o aviso: um clarão na frente dele e o assobio (no Clair Obscur o som é o principal)
	var height := 1.8 if enemy.is_boss else 0.8
	var front := enemy.global_position + Vector3.UP * height + (player.global_position - enemy.global_position).normalized() * 0.7
	_fx.sparks(front, Color(1.0, 0.95, 0.75), 28)
	_fx.rising_glow(front, Color(1.0, 0.9, 0.6))
	Audio.play_at("esquiva", enemy.global_position, -2.0)
	# o bote sai um pouco antes, para a batida (o ponto mais à frente) cair na hora de defender
	await _elapsed(maxf(at - cue - LUNGE_LEAD, 0.0))
	if not is_instance_valid(enemy):
		return
	if enemy.model:
		create_tween().tween_property(enemy.model, "position:y", 0.0, 0.12)
	_fx.lunge(enemy)
	Audio.play_at("golpe", enemy.global_position, -3.0)


## Espera somando o tempo de cada quadro, como o anel (com timers, o bote chegava ~80 ms depois da hora).
func _elapsed(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.008:
		await get_tree().process_frame
		t += get_process_delta_time()


# ---------- movimento na arena

func _spawn(scene: PackedScene, where: Transform3D) -> Combatant:
	var c := scene.instantiate() as Combatant
	for node_name: String in ["AIBrain", "PlayerController"]:
		var node := c.get_node_or_null(node_name)
		if node:
			c.remove_child(node)
			node.free()
	c.transform = where
	add_child(c)
	c.real_time = false
	return c


func _face(who: Combatant, at: Combatant) -> void:
	var d := at.global_position - who.global_position
	who.rotation.y = atan2(-d.x, -d.z)


func _approach(who: Combatant, to: Vector3, stop: float) -> void:
	var from := who.global_position
	var dir := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if dir.length() <= stop:
		return
	var goal := Vector3(to.x, from.y, to.z) - dir.normalized() * stop
	var tween := create_tween()
	tween.tween_property(who, "global_position", goal, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func _return_home(who: Combatant) -> void:
	var home: Transform3D = _homes[who]
	var tween := create_tween()
	tween.tween_property(who, "position", Vector3(home.origin.x, who.position.y, home.origin.z), 0.3)
	await tween.finished
	who.transform.basis = home.basis


func _hop(who: Combatant) -> void:
	var side := who.global_basis.x * 0.8
	var tween := create_tween()
	tween.tween_property(who, "global_position", who.global_position + side, 0.12)
	tween.tween_property(who, "global_position", who.global_position, 0.2)


# ---------- primeira pessoa (D047)

func _first_person_view() -> void:
	_camera.fov = view_fov
	_camera.current = true
	# o herói some, mas deixa a sombra no chão (dá para ver que você está ali)
	for found: Node in player.find_children("*", "GeometryInstance3D", true, false):
		(found as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_fx.first_person_target = player
	if not _daggers.is_empty():
		_make_view_daggers()
	player.hurt.connect(func(_by: Combatant) -> void:
		_hud.hurt_flash()
		_shake = 0.22)
	_look = _group_center()
	_cam_eye = player.global_position + Vector3.UP * eye_height
	_cam_look = _look
	_update_view(1.0)


## Para onde olhar: quem está atacando, ou o meio dos inimigos vivos, na altura do corpo deles (o chefe é mais alto).
func _group_center() -> Vector3:
	if _focus and is_instance_valid(_focus) and _focus.hp > 0:
		return _focus.global_position + Vector3.UP * (1.5 if _focus.is_boss else 0.1)
	var alive := alive_enemies()
	if alive.is_empty():
		return _look
	var sum := Vector3.ZERO
	var tall := 0.1
	for e: Combatant in alive:
		sum += e.global_position
		if e.is_boss:
			tall = 1.5
	return sum / alive.size() + Vector3.UP * tall


func _update_view(delta: float) -> void:
	_look = _look.lerp(_group_center(), clampf(delta * 3.0, 0.0, 1.0))
	var eye: Vector3
	var look: Vector3
	if _action_on:
		eye = _shot_eye
		look = _shot_look
	else:
		var ahead := _look - player.global_position
		ahead.y = 0.0
		var forward := ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
		eye = player.global_position + Vector3.UP * eye_height - forward * eye_back
		look = _look
	var k := 1.0 if _action_on else clampf(delta * 7.0, 0.0, 1.0)
	_cam_eye = _cam_eye.lerp(eye, k)
	_cam_look = _cam_look.lerp(look, k)
	var shaken := _cam_eye
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		shaken += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.35 * float(Settings.value("tremor"))
	_camera.look_at_from_position(shaken, _cam_look)


## O plano da cena do golpe, fixo: de lado e um pouco à frente do herói (vê o rosto e as adagas, não as costas),
## enquadrando o lugar do impacto. O herói sozinho (defender, poção): de frente, meio de lado.
func _frame_shot(on: Combatant) -> void:
	var home := player.global_position
	var other := on != player and is_instance_valid(on)
	var to := (on.global_position - home) if other else (_look - home)
	to.y = 0.0
	var f := to.normalized() if to.length() > 0.1 else Vector3.FORWARD
	var side := f.cross(Vector3.UP)
	if not other:
		_shot_eye = home + f * 2.2 + side * 1.0 + Vector3.UP * 0.9
		_shot_look = home + Vector3.UP * 0.55
		return
	var boss := on.is_boss
	var impact := on.global_position - f * (2.2 if boss else 1.3)  # onde o herói para e golpeia
	_shot_eye = impact + side * (3.8 if boss else 2.2) + f * (1.6 if boss else 1.25) + Vector3.UP * (2.0 if boss else 0.9)
	_shot_look = impact.lerp(on.global_position, 0.3) + Vector3.UP * (1.2 if boss else 0.45)


## Liga a câmera da ação mostrando o herói (on = alvo do golpe, ou o próprio herói) ou volta para os olhos dele (null).
func _action_cam(on: Combatant) -> void:
	if not first_person or _camera == null:
		return
	_action_on = on != null
	_action_target = on
	if _action_on:
		_frame_shot(on)
	# corte seco nos dois sentidos (nada de a câmera dar a volta)
	var eye := _shot_eye if _action_on else player.global_position + Vector3.UP * eye_height
	_cam_eye = eye
	_cam_look = _shot_look if _action_on else _look
	_camera.look_at_from_position(_cam_eye, _cam_look)  # já neste quadro (senão aparece um quadro de dentro do herói)
	_camera.reset_physics_interpolation()
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _action_on else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for found: Node in player.find_children("*", "GeometryInstance3D", true, false):
		(found as GeometryInstance3D).cast_shadow = mode
	if _view_rig:
		_view_rig.visible = not _action_on


func _intro_text() -> String:
	var names: PackedStringArray = []
	for e: Combatant in enemies:
		names.append(e.display_name)
	if names.size() == 1:
		return "%s aparece!" % names[0]
	return "%s e %s aparecem!" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


func _battle_line(enemy: Combatant) -> String:
	if enemy == null or not is_instance_valid(enemy) or enemy.battle_lines.is_empty():
		return ""
	return enemy.battle_lines[randi() % enemy.battle_lines.size()]


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# ---------- adagas na tela (D051)

## As adagas na frente da câmera, nos cantos de baixo, com as lâminas para cima e para dentro (como no desenho).
func _make_view_daggers() -> void:
	_view_rig = Node3D.new()
	_view_rig.name = "AdagasNaTela"
	_camera.add_child(_view_rig)
	for side: float in [-1.0, 1.0]:
		var dagger := AdagaPsiquica.new()
		dagger.glow = 0.9
		dagger.name = "Adaga" + ("Esquerda" if side < 0 else "Direita")
		_view_rig.add_child(dagger)
		dagger.transform = _view_rest(side)
		_view_daggers.append(dagger)


func _view_rest(side: float) -> Transform3D:
	# a janela da cena acaba a 70% da altura: o cabo fica logo acima dela e a lâmina sobe para dentro da cena
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-12), deg_to_rad(side * -8), deg_to_rad(side * -22))),
		Vector3(side * 0.36, -0.27, -0.85))


## Movimentos das adagas da tela: "thrust" (estocada para a frente, as duas se fechando), "cross" (cruzam em X na
## frente: aparou) e "dodge" (vão para o lado: esquivou).
func _view_pose(kind: String) -> void:
	for i: int in _view_daggers.size():
		var dagger := _view_daggers[i]
		var side := -1.0 if i == 0 else 1.0
		var rest := _view_rest(side)
		var tween := create_tween()
		match kind:
			"thrust":
				var back := rest.translated(Vector3(0, -0.04, 0.12))
				var hit := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-78), 0, deg_to_rad(side * -30))), Vector3(side * 0.12, -0.15, -1.15))
				tween.tween_property(dagger, "transform", back, 0.07).set_ease(Tween.EASE_OUT)
				tween.tween_property(dagger, "transform", hit, 0.08).set_ease(Tween.EASE_IN)
				tween.tween_interval(0.15)
				tween.tween_property(dagger, "transform", rest, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			"cross":
				var crossed := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-6), 0, deg_to_rad(side * 38))), Vector3(side * 0.08, -0.2, -0.95))
				tween.tween_property(dagger, "transform", crossed, 0.06)
				tween.tween_interval(0.3)
				tween.tween_property(dagger, "transform", rest, 0.3).set_trans(Tween.TRANS_SINE)
			"dodge":
				var moved := rest.translated(Vector3(-0.22, -0.05, 0.05))
				tween.tween_property(dagger, "transform", moved, 0.08)
				tween.tween_property(dagger, "transform", rest, 0.35).set_trans(Tween.TRANS_SINE)
		dagger.flare(0.4)


## Com as adagas (D075): a guarda do Tico (D080, a mesma do mapa; a "Sword_Idle" da UAL era de espada numa mão só e
## deixava a outra adaga solta), corte duplo e estocada longa. As peças do corpo ficam (a
## ArmRest só age nas animações do KayKit; o corpo vivo e o pé no chão se desligam sozinhos na luta por turnos).
func _dagger_animations() -> void:
	var animator := player.get_node_or_null("Animator")
	if animator:
		animator.set("idle", &"tico/Guarda")
		var list: Array[StringName] = []
		list.assign(animator.get("ability_animations"))
		if list.size() >= 2:
			list[0] = &"atk/Dualwield_Melee_Attack_Chop"
			list[1] = &"tico/Estocada"  # D080: a Sword_Dash é de espada numa mão; a outra adaga entrava na barriga
		animator.set("ability_animations", list)
		animator.set("combo", [] as Array[StringName])  # na luta por turnos o golpe é montado pela arena
		var anim_player := player.find_children("*", "AnimationPlayer", true, false)
		if not anim_player.is_empty():
			var ap := anim_player[0] as AnimationPlayer
			# os golpes do Mixamo (D081): só no PC de quem baixou (não vão para o Git); sem eles, só os de sempre
			if ResourceLoader.exists(MIXAMO_LIB) and not ap.has_animation_library(&"mix"):
				ap.add_animation_library(&"mix", load(MIXAMO_LIB))
			ap.play(&"tico/Guarda", 0.2)
	# só a ArmRest fica (ela já não age nas animações da UAL); o corpo vivo e o pé no chão saem na arena
	for modifier: Node in player.find_children("*", "SkeletonModifier3D", true, false):
		(modifier as SkeletonModifier3D).active = modifier is ArmRest


## O último inimigo caiu: câmera lenta por um instante (o golpe final pesa).
func _final_blow() -> void:
	Engine.time_scale = 0.3
	_shake = 0.25
	await get_tree().create_timer(0.7, true, false, true).timeout
	Engine.time_scale = 1.0


# ---------- o golpe completo do Tico (D056)

const MIXAMO_LIB := "res://actors/tico_lirou/mixamo_tico.res"
## Os golpes da arena: [animação, quando a lâmina chega (s)]. Os do Mixamo entram só se estiverem no PC (D081/D082).
const STRIKES := {
	"corte": [[&"atk/Dualwield_Melee_Attack_Chop", 0.56]],
	# D082: com a lâmina na linha do braço o corte para fora e a estocada da mão da frente raspavam o chão; ficaram fora
	"estocada": [[&"tico/Estocada", 0.25], [&"mix/stab_rear", 1.1]],
}


## Sorteia o golpe (variedade), entre os que o Tico tem.
func _pick_strike(ability: Ability) -> Array:
	var found := player.find_children("*", "AnimationPlayer", true, false)
	var ap := found[0] as AnimationPlayer if not found.is_empty() else null
	var options: Array = (STRIKES["estocada"] if ability.shape == Ability.Shape.DASH else STRIKES["corte"]).filter(
		func(o: Array) -> bool: return ap != null and ap.has_animation(o[0]))
	if options.is_empty():
		return STRIKES["corte"][0]
	return options[randi() % options.size()]


## Agacha para tomar impulso, corre até perto do alvo, salta e cai cortando (Corte em X ou estocada); poeira na queda.
## Volta quando o golpe chega (o resto do _player_action aplica o dano e o efeito).
func _dagger_rush(tgt: Combatant, ability: Ability) -> void:
	var animator := player.get_node_or_null("Animator")
	var strike: Array = _pick_strike(ability)
	# 1) agacha e toma impulso (D075: o salto ninja da UAL)
	if animator:
		animator.call("act", &"atk/NinjaJump_Start", 1.6)
	Audio.play_at("esquiva", player.global_position, -10.0)
	await _wait(0.2)
	# 2) corre
	var from := player.global_position
	var to := tgt.global_position
	var dir := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var reach := 2.2 if tgt.is_boss else 1.3
	var total := maxf(0.0, dir.length() - reach)
	var flat := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var leap := minf(1.2, total)
	var run_to := from + flat * (total - leap)
	if animator and total - leap > 0.2:
		animator.call("hold", &"atk/Sprint")
		var run := create_tween()
		run.tween_property(player, "global_position", run_to, clampf((total - leap) / 9.0, 0.12, 0.35))
		await run.finished
	# 3) salta e já começa o corte no ar
	if animator:
		animator.call("act", strike[0], 1.25)
		# o corte acerta quando ele cai (~0,25 s depois de saltar): começa a animação adiantada até lá
		var found := player.find_children("*", "AnimationPlayer", true, false)
		var skip := float(strike[1]) - 0.25 * 1.25
		if skip > 0.0 and not found.is_empty():
			(found[0] as AnimationPlayer).seek(skip, true)
	for dagger: AdagaPsiquica in _daggers:
		dagger.trail(true)
		dagger.flare(0.7)
	Audio.play_at("golpe", player.global_position, -3.0)
	var land := run_to + flat * leap
	var jump := create_tween().set_parallel()
	var air := 0.19
	jump.tween_property(player, "global_position:x", land.x, air)
	jump.tween_property(player, "global_position:z", land.z, air)
	jump.tween_property(player, "global_position:y", from.y + 0.45, air * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	jump.chain().tween_property(player, "global_position:y", from.y, air * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await jump.finished
	# 4) caiu: poeira e o golpe chega
	_fx.sparks(player.global_position + Vector3.UP * 0.05, Color(0.75, 0.62, 0.48), 16)
	_shake = maxf(_shake, 0.12)
	await _wait(0.06)


## Depois do golpe: salta para trás com a esquiva (cambalhota de volta), e a câmera corta.
func _dagger_recoil(tgt: Combatant) -> void:
	var animator := player.get_node_or_null("Animator")
	if animator:
		animator.call("act", &"Dodge_Backward", 1.3)
	var back := player.global_position - (tgt.global_position - player.global_position).normalized() * 1.1
	back.y = player.global_position.y
	var hop := create_tween().set_parallel()
	hop.tween_property(player, "global_position:x", back.x, 0.3).set_ease(Tween.EASE_OUT)
	hop.tween_property(player, "global_position:z", back.z, 0.3).set_ease(Tween.EASE_OUT)
	await hop.finished
	await _wait(0.12)
	if animator:
		animator.call("release")
