extends SceneTree
## Balanceamento: joga N vezes a luta de Ethera com a IA dos dois lados (sem animação) e mostra quem vence.
## Uso: godot --headless --path . -s res://tools/simulate_battles.gd -- 60

const LEVEL := "res://levels/ethera/ethera.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var total := int(args[0]) if args.size() > 0 else 40
	var hero_wins := 0
	var rounds_sum := 0
	var survivors := {}
	for i: int in total:
		Dice.rng.seed = 1000 + i
		var level := (load(LEVEL) as PackedScene).instantiate()
		var combat := level.get_node("Combat") as CombatManager
		combat.auto_heroes = true
		combat.animate = false
		var result := {"done": false, "victory": false}
		combat.combat_ended.connect(func(victory: bool) -> void:
			result["done"] = true
			result["victory"] = victory)
		root.add_child(level)
		var party := level.get_node("Party") as PartyController
		while not party.enabled:
			await process_frame
		level.start_encounter(level.get_node("EtheraRuins") as Encounter)
		var frames := 0
		while not result["done"] and frames < 20000:
			await process_frame
			frames += 1
		if result["victory"]:
			hero_wins += 1
		rounds_sum += combat.round_number
		for u: Unit in combat.units:
			if u.is_alive() and u.team == Unit.Team.HEROES:
				survivors[u.display_name] = int(survivors.get(u.display_name, 0)) + 1
		level.queue_free()
		await process_frame
	print("Batalhas: %d | heróis venceram: %d (%d%%) | média de rodadas: %.1f" % [total, hero_wins, hero_wins * 100 / total, float(rounds_sum) / total])
	print("Sobreviveu até o fim (vezes): ", survivors)
	quit(0)
