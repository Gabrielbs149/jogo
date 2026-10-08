class_name BattleArena
extends Node3D
## Luta por turnos no estilo Clair Obscur: só você contra o grupo do encontro, numa arena separada.
## Seu turno: ataque (1, ganha 1 PA) ou habilidade (Q/E/R, gasta PA). O d20 aparece rolando e diz se acertou (D&D);
## se acertou, o golpe com tempo diz quanto do dano entra (D048): anel, barra, sequência, martelar ou segurar.
## Turno do inimigo: ele rola contra a sua CA; se acertou, você se defende (anel, direção, combo ou finta).
## Ritmo: PERFEITO em seguida dá +10% de dano (até 5). Postura: golpes bons quebram o inimigo (perde a vez, +50%).
## Fúria: o chefe com metade da vida ataca duas vezes.
## Monta tudo a partir de Game.battle; no fim, Game.end_battle() volta para o mapa.
## Visual (D047, do Look Outside): em primeira pessoa. A câmera fica nos olhos do herói (que aparece só pela sombra),
## o inimigo grande na frente, e quem fala aparece na caixa de texto. As regras não mudam.

signal finished(victory: bool)

@export var start_ap: int = 2
@export var max_ap: int = 9
## Tempo (s) do anel no seu golpe.
@export var attack_qte_time: float = 0.62
## Janelas (s) do seu golpe: perfeito e bom (D048: mais apertadas).
@export var perfect_window: float = 0.055
@export var good_window: float = 0.14
## Janelas (s) da defesa: esquivar é folgado, aparar é apertado.
@export var dodge_window: float = 0.12
@export var parry_window: float = 0.065
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
var ap: int = 0
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
## Ritmo (D048): PERFEITO em seguida; dá +10% de dano por ponto (até 5).
var ritmo: int = 0
var _last_grade: String = ""
var _fury: Dictionary = {}
## Poções por luta (D050).
var potions: int = 2
var _fled: bool = false
## Câmera da ação (D050): mostra o herói atacando; null = primeira pessoa.
var _action_target: Combatant
var _action_on: bool = false
var _cam_eye := Vector3.ZERO
var _cam_look := Vector3.ZERO
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
	for c: Combatant in [player] + enemies:
		_face(c, enemies[0] if c == player else player)
		_homes[c] = c.transform
	target = enemies[0]
	_camera = get_node_or_null("Camera3D") as Camera3D
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
	_fx.hitstop_enabled = not auto_play
	var model := player.get_node_or_null("Model") as Node3D
	if model:
		_hud.setup_portrait(model)  # antes de sumir com o herói (o retrato é uma cópia dele)
	if player.hero_id == "tico":
		_daggers = AdagaPsiquica.attach_to(player)
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
	return index >= 0 and index < player.abilities.size() and player.abilities[index].ap_cost <= ap


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
	ap = start_ap + (1 if _first_strike else 0)
	Audio.play_music("batalha", 0.6)
	Audio.play_ambient("")
	_hud.banner("Primeiro golpe!  +1 PA" if _first_strike else "Luta!")
	for dagger: AdagaPsiquica in _daggers + _view_daggers:
		dagger.materialize()
	if not auto_play:
		if not _view_daggers.is_empty():
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
	await _hud.show_result(victory, text)
	Game.end_battle(victory, player.hp)


# ---------- seu turno

func _player_turn() -> void:
	Audio.play("turno", -8.0, 0.0)
	player.sneak_ready_at = 0.0
	if target == null or not is_instance_valid(target) or target.hp <= 0:
		cycle_target(1)
	var index: int
	if auto_play:
		index = _auto_choice()
		await get_tree().process_frame
	else:
		_hud.say(player.display_name, "O que %s vai fazer?" % player.display_name)
		index = await _hud.choose_action()
	if index >= EXTRA_BASE:
		await _extra_action(index)
		return
	var ability := player.abilities[index]
	ap -= ability.ap_cost
	_hud.refresh()
	await _player_action(index)
	if ability.ap_cost == 0:
		ap = mini(ap + 1, max_ap)


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
		var mult := float(outcome["mult"]) * (1.0 + ritmo * 0.1)
		var why := String(outcome["grade"]) + (" · ritmo %d" % ritmo if ritmo > 0 else "")
		CombatRules.scale_damage(results, mult, why)
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
		if r["kind"] in ["miss", "save"] and is_instance_valid(t) and t != player and not fumble:
			t.dodged.emit()  # o inimigo desvia
		if r["kind"] == "crit":
			_shake = 0.3
			_hud.flash(Color(1.0, 0.82, 0.35), 0.35)
	CombatRules.apply(player, ability, results, _fx)
	for r: Dictionary in results:
		_add_posture(r["target"] as Combatant, int(r["amount"]) + (8 if _last_grade == "perfeito" else 0))
	if ability.is_offensive():
		player.remove_flag("invisible")
	await _wait(0.6)
	for dagger: AdagaPsiquica in _daggers:
		dagger.trail(false)
	if melee and player.is_active():
		await _return_home(player)
	_action_cam(null)
	await _wait(0.2)


## O anel do dano (D050: um desafio só, claro e bonito). Rajada (vários golpes, investida) = um anel por golpe,
## cada um mais rápido; habilidade grande (4+ PA) = anel mais rápido, mas o perfeito vale ×1,8.
## Devolve {"grade": "perfeito"|"bom"|"fraco", "mult"}.
func _damage_qte(ability: Ability, hits: int, on: Combatant) -> Dictionary:
	var kind := ability.damage_qte()
	if kind == Ability.Golpe.NENHUM:
		return {"grade": "bom", "mult": 1.0}
	var big := ability.ap_cost >= 4
	var best := 1.8 if big else 1.5
	if auto_play:
		var r := randf()
		return _grade("perfeito" if r < auto_perfect else ("bom" if r < auto_perfect + auto_good else "fraco"), best)
	var count := (hits if hits > 1 else 3) if kind == Ability.Golpe.RAJADA else 1
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


## As ações que não são habilidade, para o menu: {"id", "key", "title", "info"}.
func extra_actions() -> Array[Dictionary]:
	return [
		{"id": DEFEND, "key": "2", "title": "Defender", "info": "+2 CA e defesa mais folgada · +1 PA"},
		{"id": POTION, "key": "3", "title": "Poção", "info": "cura 2d4+2 · restam %d" % potions},
		{"id": ANALYZE, "key": "4", "title": "Analisar", "info": "mostra o próximo golpe · alvo exposto"},
		{"id": FLEE, "key": "5", "title": "Fugir", "info": "d20 + DES contra CD %d" % flee_dc() if not _boss_alive() else "não dá para fugir do chefe"},
	]


func can_use_extra(id: int) -> bool:
	match id:
		POTION:
			return potions > 0 and player.hp < player.max_hp
		FLEE:
			return not _boss_alive()
	return true


func flee_dc() -> int:
	return 10 + 2 * alive_enemies().size()


func _boss_alive() -> bool:
	return alive_enemies().any(func(e: Combatant) -> bool: return e.is_boss)


func _extra_action(id: int) -> void:
	match id:
		DEFEND:
			player.add_status(_status("Defendendo", {"ac": 2}))
			ap = mini(ap + 1, max_ap)
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
			player.ability_used.emit(3)  # mesma animação de usar item
			_fx.rising_glow(player.global_position, Color(0.5, 1.0, 0.6))
			_fx.floating_text(player.global_position, "+%d" % amount, Color(0.6, 1.0, 0.65))
			player.rolled.emit("%s bebe uma poção: 2d4+2 = %d" % [player.display_name, amount])
			await _hud.say(player.display_name, "%s bebe uma poção e recupera %d PV." % [player.display_name, amount], 0.4)
			_action_cam(null)
		ANALYZE:
			if target and is_instance_valid(target):
				target.add_status(_status("Exposto", {"expose": true}))
				ap = mini(ap + 1, max_ap)
				await _hud.say(player.display_name, _analysis(target), 1.1)
		FLEE:
			var roll := Dice.d20()
			var total := roll + player.dex_save
			var ok := roll != 1 and (roll == 20 or total >= flee_dc())
			await _hud.roll_dice([{"by": player, "rolls": [roll], "kept": roll, "mod": player.dex_save, "total": total, "vs": flee_dc(),
				"vs_name": "CD", "target": player, "verdict": "FUGIU!" if ok else "NÃO DEU"}] as Array[Dictionary])
			if ok:
				_fled = true
				await _hud.say(player.display_name, "%s some no meio da poeira." % player.display_name, 0.5)
			else:
				await _hud.say(player.display_name, "%s tenta fugir, mas não acha saída." % player.display_name, 0.4)
	_hud.refresh()


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


## Ritmo (D048): PERFEITO em seguida (no golpe ou na defesa) soma; qualquer erro zera.
func _after_grade(grade: String) -> void:
	_last_grade = grade
	var text := {"perfeito": "PERFEITO!", "bom": "Bom", "fraco": "Fraco", "falhou": "Falhou"}.get(grade, grade) as String
	var color := {"perfeito": Color(1, 0.85, 0.3), "bom": Color(0.9, 0.9, 0.9)}.get(grade, Color(0.85, 0.55, 0.5)) as Color
	if grade == "perfeito":
		ritmo = mini(ritmo + 1, 5)
		text += "  Ritmo %d" % ritmo
	elif grade in ["fraco", "falhou"]:
		if ritmo > 0:
			text += "  (ritmo perdido)"
		ritmo = 0
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
		await _approach(enemy, player.global_position, 2.6 if enemy.is_boss else 1.6)
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
	_fx.lunge(enemy)
	Audio.play_at("golpe", enemy.global_position, -3.0)
	var on_me := results.filter(func(r: Dictionary) -> bool: return r["target"] == player and int(r["amount"]) > 0)
	var countered := false
	if not on_me.is_empty():
		var defense := await _defense(ability, enemy)
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
		if countered or keep <= 0.0:
			_view_pose("cross" if countered else "dodge")
		elif keep < 1.0:
			_view_pose("dodge")
		if keep <= 0.0:
			player.dodged.emit()
			_fx.floating_text(player.global_position, defense["text"], Color(0.8, 0.95, 1.0))
			_hop(player)
	if ability.projectile:
		await _fx.projectile(enemy.global_position, player.global_position, ability.vfx_color, ability.projectile_scene)
	elif ability.shape == Ability.Shape.ENEMIES_AROUND:
		_fx.ring(enemy.global_position, ability.radius_m, ability.vfx_color)
	CombatRules.apply(enemy, ability, results, _fx)
	if countered and player.is_active() and enemy.is_active():
		Audio.play_at("aparar", player.global_position + Vector3.UP, 0.0)
		_fx.floating_text(player.global_position, "APAROU!", Color(1, 0.85, 0.3), true)
		player.rolled.emit("%s aparou e contra-ataca (+1 PA)" % player.display_name)
		ap = mini(ap + 1, max_ap)
		player.ability_used.emit(0)
		var counter := CombatRules.resolve(player, player.abilities[0], enemy, enemy.global_position, CombatRules.everyone(get_tree()), 1)
		CombatRules.apply(player, player.abilities[0], counter, _fx)
		for r: Dictionary in counter:
			_add_posture(enemy, int(r["amount"]) + 10)
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
func _defense(ability: Ability, enemy: Combatant) -> Dictionary:
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
	# Defendendo (D050): as janelas ficam 50% maiores
	var easy := 1.5 if player.statuses.any(func(st: Dictionary) -> bool: return st["title"] == "Defendendo") else 1.0
	var dodge_w := dodge_window * easy
	var parry_w := parry_window * easy
	match kind:
		Ability.Defesa.DIRECAO:
			var side := -1 if randf() < 0.5 else 1
			var res := await q.ring(at, windup + 0.15, [], "Pule para o lado da seta", false, side)
			var right_key := &"move_right" if side > 0 else &"move_left"
			var error := absf(float(res["error"]))
			q.pop("bom" if res["key"] == right_key and error <= dodge_w else "falhou")
			if res["key"] == right_key and error <= dodge_w:
				return {"keep": 0.0, "counter": false, "grade": "perfeito" if error <= parry_w else "bom", "text": "desviou"}
			return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}
		Ability.Defesa.COMBO:
			var parried := 0
			var avoided := 0
			for i: int in 3:
				var res := await q.ring(at, randf_range(0.32, 0.62), [&"dodge", &"parry"], "F apara · Espaço esquiva", false, 0, i, 3)
				var error := absf(float(res["error"]))
				if res["key"] == &"parry" and error <= parry_w:
					parried += 1
					q.pop("perfeito")
					Audio.play("aparar", -6.0, 0.0)
				elif res["key"] == &"dodge" and error <= dodge_w:
					avoided += 1
					q.pop("bom")
				else:
					q.pop("falhou")
			var keep := 1.0 - (parried + avoided) / 3.0
			return {"keep": keep, "counter": parried == 3, "grade": "perfeito" if parried == 3 else ("bom" if keep < 0.5 else "falhou"),
				"text": "aparou os três" if parried == 3 else "segurou %d de 3" % (parried + avoided)}
		Ability.Defesa.FINTA:
			var res := await q.ring(at, windup, [&"dodge"], "Cuidado com a finta", true)
			var error := absf(float(res["error"]))
			q.pop("perfeito" if res["key"] == &"dodge" and error <= parry_w else ("bom" if res["key"] == &"dodge" and error <= dodge_w else "falhou"))
			if res["key"] == &"dodge" and error <= dodge_w:
				return {"keep": 0.0, "counter": false, "grade": "perfeito" if error <= parry_w else "bom", "text": "pulou a onda"}
			return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}
	# anel
	var res := await q.ring(at, windup, [&"dodge", &"parry"], "F apara · Espaço esquiva")
	var error := absf(float(res["error"]))
	q.pop("perfeito" if res["key"] == &"parry" and error <= parry_w else ("bom" if res["key"] == &"dodge" and error <= dodge_w else "falhou"))
	if res["key"] == &"parry" and error <= parry_w:
		return {"keep": 0.0, "counter": true, "grade": "perfeito", "text": "aparou"}
	if res["key"] == &"dodge" and error <= dodge_w:
		return {"keep": 0.5, "counter": false, "grade": "bom", "text": "esquivou (½)"}
	return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}


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
		# câmera da ação: atrás e ao lado do herói, olhando para ele e o alvo
		var focus_other := _action_target != null and is_instance_valid(_action_target) and _action_target != player
		var other: Vector3 = _action_target.global_position if focus_other else _look
		var to := other - player.global_position
		to.y = 0.0
		var f := to.normalized() if to.length() > 0.1 else Vector3.FORWARD
		var side := f.cross(Vector3.UP)
		var boss := focus_other and _action_target.is_boss
		if focus_other:
			# de lado, os dois de perfil: o herói à esquerda, o alvo à direita
			var mid := player.global_position.lerp(other, 0.5)
			var spread := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(other.x, other.z))
			eye = mid + side * (2.2 + spread * 0.55 + (2.0 if boss else 0.0)) - f * 0.9 + Vector3.UP * (1.0 if not boss else 1.9)
			look = mid + Vector3.UP * (1.2 if boss else 0.5)
		else:
			# o herói sozinho (defender, poção): de frente, meio de lado
			eye = player.global_position + f * 2.2 + side * 1.0 + Vector3.UP * 0.9
			look = player.global_position + Vector3.UP * 0.55
	else:
		var ahead := _look - player.global_position
		ahead.y = 0.0
		var forward := ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
		eye = player.global_position + Vector3.UP * eye_height - forward * eye_back
		look = _look
	var k := clampf(delta * 7.0, 0.0, 1.0)
	_cam_eye = _cam_eye.lerp(eye, k)
	_cam_look = _cam_look.lerp(look, k)
	var shaken := _cam_eye
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		shaken += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.35
	_camera.look_at_from_position(shaken, _cam_look)


## Liga a câmera da ação mostrando o herói (on = alvo do golpe, ou o próprio herói) ou volta para os olhos dele (null).
func _action_cam(on: Combatant) -> void:
	if not first_person or _camera == null:
		return
	_action_on = on != null
	_action_target = on
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
