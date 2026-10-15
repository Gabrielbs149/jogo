extends GutTest
## Arena por turnos (D022): você sozinho contra o grupo, QTE no golpe, esquivar/aparar na defesa.

const ARENA := "res://levels/arenas/ethera_arena.tscn"
const BEETLE := "res://actors/enemies/escaravelho_de_cinza.tscn"


func after_each() -> void:
	Engine.time_scale = 1.0
	Game.battle = {}
	CombatRules.turn_mode = false


func _arena(enemies: PackedStringArray, first_strike: bool = false) -> BattleArena:
	Game.chosen = "tico"
	Game.hero_hp = -1
	Game.battle = {"id": "teste", "enemies": enemies, "first_strike": first_strike}
	var arena := (load(ARENA) as PackedScene).instantiate() as BattleArena
	arena.auto_play = true
	add_child_autofree(arena)
	return arena


func test_a_good_player_beats_two_beetles() -> void:
	Dice.rng.seed = 7
	seed(7)
	Engine.time_scale = 6.0
	var arena := _arena(PackedStringArray([BEETLE, BEETLE]))
	arena.auto_perfect = 0.8
	arena.auto_dodge = 0.5
	arena.auto_parry = 0.3
	var result := []
	arena.finished.connect(func(victory: bool) -> void: result.append(victory))
	await wait_until(func() -> bool: return not result.is_empty(), 40.0)
	assert_eq(result, [true], "venceu")
	assert_eq(arena.alive_enemies().size(), 0)


func test_first_strike_goes_first() -> void:
	var arena := _arena(PackedStringArray([BEETLE, BEETLE, BEETLE]), true)
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	assert_eq(arena.order[0], arena.player, "você começa")


## D052: o ataque é sempre livre; a habilidade usada fica alguns turnos recarregando.
func test_abilities_recharge_after_use() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	arena.recharge.clear()
	assert_true(arena.can_afford(0), "ataque sempre livre")
	assert_eq(arena.player.abilities[0].recharge_turns(), 0)
	assert_eq(arena.player.abilities[2].recharge_turns(), 3, "Espinhos: 3 turnos")
	arena.recharge[2] = 2
	assert_false(arena.can_afford(2), "recarregando")
	assert_true(arena.can_afford(1))


## D048: o d20 vem com as faces para aparecer na tela, e o golpe com tempo multiplica o dano já rolado.
func test_attack_roll_carries_the_die_to_show() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	var results := CombatRules.resolve(arena.player, arena.player.abilities[0], arena.enemies[0], arena.enemies[0].global_position,
		CombatRules.everyone(get_tree()), 1)
	var die: Dictionary = results[0]["die"]
	assert_eq((die["rolls"] as Array).size(), 2, "com vantagem rola dois d20")
	assert_true(int(die["kept"]) == maxi(int(die["rolls"][0]), int(die["rolls"][1])), "fica com o maior")
	assert_eq(int(die["total"]), int(die["kept"]) + int(die["mod"]))
	assert_true(String(die["verdict"]) in ["ACERTOU", "CRÍTICO!", "ERROU", "FALHA"])


func test_damage_timing_scales_the_damage() -> void:
	var results: Array[Dictionary] = [{"amount": 10, "text": "x"}, {"amount": 0, "text": "errou"}, {"amount": 1, "text": "y"}]
	CombatRules.scale_damage(results, 1.5, "perfeito")
	assert_eq(int(results[0]["amount"]), 15)
	assert_eq(int(results[1]["amount"]), 0, "errou continua sem dano")
	CombatRules.scale_damage(results, 0.3)
	assert_eq(int(results[2]["amount"]), 1, "acertou leva pelo menos 1")


func test_each_ability_picks_its_challenge() -> void:
	assert_eq((load("res://data/abilities/adaga.tres") as Ability).damage_qte(), Ability.Golpe.ANEL)
	assert_eq((load("res://data/abilities/bote_das_sombras.tres") as Ability).damage_qte(), Ability.Golpe.RAJADA, "investida: anéis seguidos")
	assert_eq((load("res://data/abilities/espinhos.tres") as Ability).damage_qte(), Ability.Golpe.ANEL)
	assert_eq((load("res://data/abilities/tiro_duplo.tres") as Ability).damage_qte(), Ability.Golpe.RAJADA, "um anel por flecha")
	assert_eq((load("res://data/abilities/camuflagem.tres") as Ability).damage_qte(), Ability.Golpe.NENHUM)
	assert_eq((load("res://data/abilities/raio_vigia.tres") as Ability).defense_qte(), Ability.Defesa.DIRECAO)
	assert_eq((load("res://data/abilities/pancada.tres") as Ability).defense_qte(), Ability.Defesa.COMBO)
	assert_eq((load("res://data/abilities/onda_de_cinza.tres") as Ability).defense_qte(), Ability.Defesa.FINTA)


func test_posture_breaks_and_the_enemy_loses_a_turn() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	var beetle := arena.enemies[0]
	arena.call("_add_posture", beetle, beetle.posture_limit())
	assert_true(beetle.quebrado, "postura cheia quebra")


## D050: ações do meio da luta. Defender dá CA; a poção cura e acaba; do chefe não dá para fugir.
func test_extra_actions() -> void:
	# sem o piloto automático: a luta fica parada esperando você escolher (primeiro golpe = você começa)
	Game.chosen = "tico"
	Game.hero_hp = -1
	Game.battle = {"id": "teste", "enemies": PackedStringArray([BEETLE]), "first_strike": true}
	var arena := (load(ARENA) as PackedScene).instantiate() as BattleArena
	add_child_autofree(arena)
	await wait_until(func() -> bool: return arena.get_node("BattleHUD").get("_choosing"), 20.0)
	var ac := arena.player.current_ac()
	await arena.call("_extra_action", BattleArena.DEFEND)
	assert_eq(arena.player.current_ac(), ac + 2, "defendendo: +2 CA")
	arena.player.hp = 5
	assert_true(arena.can_use_extra(BattleArena.POTION))
	await arena.call("_extra_action", BattleArena.POTION)
	assert_gt(arena.player.hp, 5, "a poção cura")
	assert_eq(arena.potions, 1)
	arena.potions = 0
	assert_false(arena.can_use_extra(BattleArena.POTION), "sem poção")
	assert_true(arena.can_use_extra(BattleArena.FLEE), "do escaravelho dá para fugir")
	await arena.call("_extra_action", BattleArena.ANALYZE)
	assert_true(arena.target.has_flag("expose"), "analisar deixa o alvo exposto")


func test_cannot_flee_from_the_boss() -> void:
	var arena := _arena(PackedStringArray(["res://actors/enemies/ultimo_guardiao.tscn"]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	assert_false(arena.can_use_extra(BattleArena.FLEE))


## D051: o Tico luta com as adagas psíquicas, uma em cada mão.
func test_tico_fights_with_psychic_daggers() -> void:
	var arena := _arena(PackedStringArray([BEETLE]))
	await wait_until(func() -> bool: return arena.order.size() > 0, 10.0)
	var daggers := arena.player.find_children("*", "AdagaPsiquica", true, false)
	assert_eq(daggers.size(), 2, "uma em cada mão")
	var dagger := daggers[0] as AdagaPsiquica
	assert_gt(dagger.blade_length, 0.3, "a lâmina tem tamanho de adaga")
	assert_true(dagger.has_node("Lamina"), "a lâmina foi montada")


## D055: o veredito do dado é do ponto de vista de quem joga (verde = bom para você).
func test_dice_verdict_is_from_the_player_view() -> void:
	var view := func(d: Dictionary, enemy: bool) -> Array: return DiceRoller._player_view(d, enemy)
	assert_eq(view.call({"kept": 15, "verdict": "ACERTOU"}, false), ["ACERTOU", true], "você acerta: verde")
	assert_eq(view.call({"kept": 5, "verdict": "ERROU"}, false), ["ERROU", false], "você erra: vermelho")
	assert_eq(view.call({"kept": 4, "verdict": "FALHOU", "save": "DES"}, true), ["ACERTOU", true], "Espinhos: o inimigo não resiste = verde")
	assert_eq(view.call({"kept": 18, "verdict": "PASSOU", "save": "DES"}, true), ["RESISTIU", false], "o inimigo resiste = vermelho")
	assert_eq(view.call({"kept": 15, "verdict": "ACERTOU"}, true), ["TE ACERTOU", false], "o inimigo acerta você = vermelho")
	assert_eq(view.call({"kept": 6, "verdict": "ERROU"}, true), ["ESCAPOU", true], "o inimigo erra = verde")


## D082 (como no Clair Obscur): o golpe do inimigo avisa pelo corpo e bate na hora da defesa. A animação de golpe dele
## toca durante a espera, e o bote (o corpo indo para a frente) acontece perto da hora marcada, não antes.
func test_enemy_strike_lands_on_the_defense_beat() -> void:
	var arena := _arena(PackedStringArray([BEETLE]), true)
	arena.auto_play = false  # o Tico começa e a arena fica esperando ele escolher: o inimigo não age sozinho
	await wait_until(func() -> bool: return arena.get_node("BattleHUD").get("_choosing"), 20.0)
	var enemy: Combatant = arena.enemies[0]
	var anim_player := enemy.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var strike_anim := String((enemy.get_node("Animator").get("ability_animations") as Array)[0])
	var at := 0.8
	arena._strike(enemy, 0, at)
	var played := false
	var forward_at := -1.0
	var start := Time.get_ticks_msec()
	var t := 0.0
	while t < at + 0.4:
		await wait_process_frames(1)
		t = (Time.get_ticks_msec() - start) / 1000.0
		played = played or anim_player.current_animation == strike_anim
		if forward_at < 0.0 and enemy.model.position.z < -0.3:
			forward_at = t
	assert_true(played, "o golpe dele tocou")
	assert_between(forward_at, at - 0.08, at + 0.12, "a batida cai na hora de defender")


func test_defense_ring_is_hidden_by_default() -> void:
	assert_false(bool(Settings.value("anel_defesa")), "sem anel: lê o golpe e o som")
	assert_almost_eq(GolpeQte.duration_for(0.8), 0.8 * clampf(float(Settings.value("tempo_qte")), 1.0, 2.0), 0.001)


## D083 (do Baldur's Gate 3): a mão de trás golpeia com o mesmo acerto, mas o dano não soma o modificador.
func test_offhand_strike_has_no_damage_bonus_and_hurts() -> void:
	var arena := _arena(PackedStringArray([BEETLE]), true)
	arena.auto_play = false
	await wait_until(func() -> bool: return arena.get_node("BattleHUD").get("_choosing"), 20.0)
	var basic: Ability = arena.player.abilities[0]
	var off := arena.offhand_ability()
	assert_eq(off.bonus, 0, "sem o modificador no dano")
	assert_eq(off.dice_sides, basic.dice_sides, "o mesmo dado da arma")
	var enemy: Combatant = arena.enemies[0]
	arena.player.attack_bonus = 60  # acerta (só o 1 natural erra)
	var before := enemy.hp
	for i: int in 3:
		await arena._offhand_strike(enemy, "Mão de trás")
		if enemy.hp < before:
			break
	assert_lt(enemy.hp, before, "a mão de trás tira vida")


## D083: terreno alto dá +2 para acertar de cima e -2 de baixo.
func test_high_ground() -> void:
	var arena := _arena(PackedStringArray([BEETLE]), true)
	arena.auto_play = false
	await wait_until(func() -> bool: return arena.get_node("BattleHUD").get("_choosing"), 20.0)
	var enemy: Combatant = arena.enemies[0]
	assert_eq(CombatRules.high_ground(arena.player, enemy), 0, "no mesmo chão")
	arena.player.global_position.y = enemy.global_position.y + 3.0
	assert_eq(CombatRules.high_ground(arena.player, enemy), 2, "de cima")
	assert_eq(CombatRules.high_ground(enemy, arena.player), -2, "de baixo")


## D083: o empurrão deixa o alvo desequilibrado (ataques contra ele com vantagem); o chefe não dá para empurrar.
func test_shove_unbalances_the_target() -> void:
	var arena := _arena(PackedStringArray([BEETLE]), true)
	arena.auto_play = false
	await wait_until(func() -> bool: return arena.get_node("BattleHUD").get("_choosing"), 20.0)
	var enemy: Combatant = arena.enemies[0]
	arena.target = enemy
	assert_true(arena.can_use_extra(BattleArena.SHOVE))
	arena.player.attack_bonus = 60
	for i: int in 3:
		await arena._shove(enemy)
		if enemy.has_flag("expose"):
			break
	assert_true(enemy.has_flag("expose"), "desequilibrado")
	assert_eq(CombatRules.attack_advantage(arena.player, arena.player.abilities[0], enemy), 1, "vantagem contra ele")


## D083 (Riposte, do Baldur's Gate 3): o inimigo erra o golpe corpo a corpo e a mão de trás revida.
func test_riposte_when_the_enemy_misses() -> void:
	var arena := _arena(PackedStringArray([BEETLE]), true)
	arena.auto_play = false
	await wait_until(func() -> bool: return arena.get_node("BattleHUD").get("_choosing"), 20.0)
	var enemy: Combatant = arena.enemies[0]
	arena.player.armor_class = 99  # ele erra (só o 20 natural acertaria)
	arena.player.attack_bonus = 60
	var before := enemy.hp
	for i: int in 3:
		await arena._enemy_turn(enemy)
		if enemy.hp < before:
			break
	assert_lt(enemy.hp, before, "a riposte tirou vida dele")
