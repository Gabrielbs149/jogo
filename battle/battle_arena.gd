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
	var model := player.get_node_or_null("Model") as Node3D
	if model:
		_hud.setup_portrait(model)  # antes de sumir com o herói (o retrato é uma cópia dele)
	if first_person and _camera:
		_first_person_view()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i: int in 3:
		await get_tree().physics_frame
	_run()


func _process(delta: float) -> void:
	if first_person and _camera and is_instance_valid(player):
		_update_view(delta)
	if _marker and target and is_instance_valid(target) and target.hp > 0:
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
	return not player.is_active() or alive_enemies().is_empty()


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
	if not auto_play:
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
	var ability := player.abilities[index]
	ap -= ability.ap_cost
	_hud.refresh()
	await _player_action(index)
	if ability.ap_cost == 0:
		ap = mini(ap + 1, max_ap)


## D048: primeiro o d20 diz se acerta (aparece rolando); se acertou, o golpe com tempo diz quanto do dano entra.
func _player_action(index: int) -> void:
	var ability := player.abilities[index]
	var tgt: Combatant = target if ability.is_offensive() else player
	var melee := ability.is_offensive() and (ability.shape == Ability.Shape.DASH or (ability.shape == Ability.Shape.TARGET and not ability.projectile))
	if tgt != player:
		_face(player, tgt)
	player.ability_used.emit(index)
	var point := tgt.global_position
	var results := CombatRules.resolve(player, ability, tgt if ability.needs_target() else null, point, CombatRules.everyone(get_tree()))
	await _show_dice(results)
	var landed := results.filter(func(r: Dictionary) -> bool: return int(r["amount"]) > 0)
	if not landed.is_empty():
		var outcome := await _damage_qte(ability, landed.size())
		_after_grade(String(outcome["grade"]))
		var mult := float(outcome["mult"]) * (1.0 + ritmo * 0.1)
		var why := String(outcome["grade"]) + (" · ritmo %d" % ritmo if ritmo > 0 else "")
		CombatRules.scale_damage(results, mult, why)
		for r: Dictionary in results:
			var t := r["target"] as Combatant
			if is_instance_valid(t) and t.quebrado and int(r["amount"]) > 0:
				CombatRules.scale_damage([r] as Array[Dictionary], 1.5, "quebrado")
	if melee:
		await _approach(player, tgt.global_position, 1.4)
	Audio.play_at("golpe", player.global_position, -3.0)
	if ability.projectile and tgt != player:
		await _fx.projectile(player.global_position, point, ability.vfx_color, ability.projectile_scene)
	elif ability.shape in [Ability.Shape.AREA, Ability.Shape.ALLIES_AROUND, Ability.Shape.ENEMIES_AROUND, Ability.Shape.CONE, Ability.Shape.LINE]:
		_fx.ring(point if ability.shape == Ability.Shape.AREA else player.global_position, maxf(ability.radius_m, 2.0), ability.vfx_color)
	elif melee:
		_fx.lunge(player)
	CombatRules.apply(player, ability, results, _fx)
	for r: Dictionary in results:
		_add_posture(r["target"] as Combatant, int(r["amount"]) + (8 if _last_grade == "perfeito" else 0))
	if ability.is_offensive():
		player.remove_flag("invisible")
	await _wait(0.45)
	if melee and player.is_active():
		await _return_home(player)


## O golpe com tempo do dano (D048). Devolve {"grade": "perfeito"|"bom"|"fraco", "mult"}.
## Bem difícil de propósito: as janelas são curtas, e cada tipo pede uma coisa diferente.
func _damage_qte(ability: Ability, hits: int) -> Dictionary:
	var kind := ability.damage_qte()
	if kind == Ability.Golpe.NENHUM:
		return {"grade": "bom", "mult": 1.0}
	if auto_play:
		var r := randf()
		return _grade("perfeito" if r < auto_perfect else ("bom" if r < auto_perfect + auto_good else "fraco"))
	var q := _hud.golpe()
	var at := _hud.scene_center() + Vector2(0, 40)
	match kind:
		Ability.Golpe.ANEL:
			var res := await q.ring(at, attack_qte_time, [&"dodge"], "Espaço no tempo")
			var error := absf(float(res["error"])) if res["key"] != &"" else 9.0
			return _grade("perfeito" if error <= perfect_window else ("bom" if error <= good_window else "fraco"))
		Ability.Golpe.BARRA:
			# vários golpes: uma barra por golpe, cada uma mais rápida; vale a média
			var total := 0.0
			for h: int in hits:
				var res := await q.bar(at, 0.75 - h * 0.15, 0.07, 0.24, "Golpe %d de %d: Espaço no dourado" % [h + 1, hits])
				var off := float(res["offset"])
				total += 1.6 if off <= 0.07 else (1.1 if off <= 0.24 else 0.5)
			var avg := total / hits
			return {"grade": "perfeito" if avg >= 1.55 else ("bom" if avg >= 1.0 else "fraco"), "mult": avg}
		Ability.Golpe.SEQUENCIA:
			var res := await q.sequence(at, 5, 0.62)
			var right := int(res["correct"])
			var mult := 0.5 + right * 0.25  # 5 certas = ×1,75
			return {"grade": "perfeito" if right >= 5 else ("bom" if right >= 3 else "fraco"), "mult": mult}
		Ability.Golpe.MARTELAR:
			var res := await q.mash(at, 1.6)
			var n := int(res["presses"])
			return {"grade": "perfeito" if n >= 18 else ("bom" if n >= 11 else "fraco"), "mult": clampf(0.5 + n * 0.06, 0.5, 1.6)}
		Ability.Golpe.SEGURAR:
			var res := await q.hold(at, 1.25)
			var lv := float(res["level"])
			if bool(res["over"]):
				return {"grade": "fraco", "mult": 0.3}
			return _grade("perfeito" if lv >= 0.85 and lv <= 0.93 else ("bom" if lv >= 0.7 else "fraco"), 1.8)
	return {"grade": "bom", "mult": 1.0}


func _grade(grade: String, perfect_mult: float = 1.5) -> Dictionary:
	return {"grade": grade, "mult": {"perfeito": perfect_mult, "bom": 1.0, "fraco": 0.6}[grade]}


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
	var at := _hud.scene_center() + Vector2(0, 40)
	if first_person and enemy and is_instance_valid(enemy):
		var cam := get_viewport().get_camera_3d()
		var p := enemy.global_position + Vector3.UP * (1.2 if enemy.is_boss else 0.3)
		if cam and not cam.is_position_behind(p):
			at = cam.unproject_position(p)
	var windup := 0.5 + ability.windup
	match kind:
		Ability.Defesa.DIRECAO:
			var side := -1 if randf() < 0.5 else 1
			var res := await q.ring(at, windup + 0.15, [], "Pule para o lado da seta", false, side)
			var right_key := &"move_right" if side > 0 else &"move_left"
			var error := absf(float(res["error"]))
			if res["key"] == right_key and error <= dodge_window:
				return {"keep": 0.0, "counter": false, "grade": "perfeito" if error <= parry_window else "bom", "text": "desviou"}
			return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}
		Ability.Defesa.COMBO:
			var parried := 0
			var avoided := 0
			for i: int in 3:
				var res := await q.ring(at, randf_range(0.32, 0.62), [&"dodge", &"parry"], "Golpe %d de 3: F apara · Espaço esquiva" % (i + 1))
				var error := absf(float(res["error"]))
				if res["key"] == &"parry" and error <= parry_window:
					parried += 1
					Audio.play("aparar", -6.0, 0.0)
				elif res["key"] == &"dodge" and error <= dodge_window:
					avoided += 1
			var keep := 1.0 - (parried + avoided) / 3.0
			return {"keep": keep, "counter": parried == 3, "grade": "perfeito" if parried == 3 else ("bom" if keep < 0.5 else "falhou"),
				"text": "aparou os três" if parried == 3 else "segurou %d de 3" % (parried + avoided)}
		Ability.Defesa.FINTA:
			var res := await q.ring(at, windup, [&"dodge"], "Cuidado com a finta: Espaço", true)
			var error := absf(float(res["error"]))
			if res["key"] == &"dodge" and error <= dodge_window:
				return {"keep": 0.0, "counter": false, "grade": "perfeito" if error <= parry_window else "bom", "text": "pulou a onda"}
			return {"keep": 1.0, "counter": false, "grade": "falhou", "text": ""}
	# anel
	var res := await q.ring(at, windup, [&"dodge", &"parry"], "F apara · Espaço esquiva")
	var error := absf(float(res["error"]))
	if res["key"] == &"parry" and error <= parry_window:
		return {"keep": 0.0, "counter": true, "grade": "perfeito", "text": "aparou"}
	if res["key"] == &"dodge" and error <= dodge_window:
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
	player.hurt.connect(func(_by: Combatant) -> void:
		_hud.hurt_flash()
		_shake = 0.22)
	_look = _group_center()
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
	var ahead := _look - player.global_position
	ahead.y = 0.0
	var forward := ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
	var eye := player.global_position + Vector3.UP * eye_height - forward * eye_back
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		eye += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.35
	_camera.look_at_from_position(eye, _look)


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
