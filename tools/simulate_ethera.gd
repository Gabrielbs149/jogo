extends SceneTree
## Joga Ethera sozinho, com a IA no lugar de quem joga, para medir a dificuldade.
## Para cada herói: sozinho e com o grupo inteiro. Imprime quem venceu, em quanto tempo de jogo e a vida no fim.
## Uso: godot --headless --path . -s res://tools/simulate_ethera.gd [-- vezes]

const LEVEL := "res://levels/ethera/ethera.tscn"
const SPEED := 4.0
## Tempo máximo de jogo por partida (segundos).
const LIMIT := 300.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	var runs := 1
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		runs = maxi(1, int(args[0]))
	Engine.time_scale = SPEED
	var only := args[1] if args.size() > 1 else ""
	for id: String in game.HEROES:
		if only != "" and id != only:
			continue
		for full: bool in [false, true]:
			var wins := 0
			for r: int in runs:
				Dice.rng.seed = 1000 + r
				var result := await _play(game, id, full)
				if result["win"]:
					wins += 1
				print("%-11s %-6s vitória=%s  tempo=%3.0fs  PV=%s" % [id, "grupo" if full else "só", result["win"], result["time"], result["hp"]])
			if runs > 1:
				print("    -> %d/%d vitórias" % [wins, runs])
	quit()


func _play(game: Node, id: String, full: bool) -> Dictionary:
	paused = false  # a tela de derrota da partida anterior pausa o jogo
	game.chosen = id
	game.party.clear()
	var level := (load(LEVEL) as PackedScene).instantiate() as Node3D
	level.set("skip_intro", true)
	root.add_child(level)
	while not level.get("ready_to_play"):
		await physics_frame
	var player := level.get("player") as Combatant
	if OS.has_environment("SIM_DEBUG"):
		print("  pausado=%s  física do jogador=%s" % [paused, player.is_physics_processing()])
	if full:
		for hero: Combatant in (level.get("waiting") as Array).duplicate():
			level.call("join", hero)
	player.get_node("PlayerController").queue_free()
	var brain := AIBrain.new()
	brain.name = "AIBrain"
	brain.mode = AIBrain.Mode.COMPANION
	brain.hunt = true
	player.add_child(brain)
	var boss: Combatant = null
	for node: Node in get_nodes_in_group("enemies"):
		if (node as Combatant).is_boss:
			boss = node as Combatant
	var time := 0.0
	var win := false
	while time < LIMIT:
		await physics_frame
		time += 1.0 / Engine.physics_ticks_per_second * SPEED
		if not is_instance_valid(boss) or boss.hp <= 0:
			win = true
			break
		var standing := player.is_active()
		for c: Combatant in level.get("companions"):
			standing = standing or c.is_active()
		if not standing:
			break
		if OS.has_environment("SIM_DEBUG") and int(time * 10) % 100 == 0:
			print("  t=%3.0f %s em %s vel %s alvo-chefe a %.1f m" % [time, player.display_name, player.global_position.snapped(Vector3.ONE * 0.1), player.velocity.snapped(Vector3.ONE * 0.1), player.global_position.distance_to(boss.global_position)])
	var hp: PackedStringArray = []
	for c: Combatant in [player] + (level.get("companions") as Array):
		hp.append("%s %d/%d" % [c.display_name, c.hp, c.max_hp])
	level.queue_free()
	await process_frame
	return {"win": win, "time": time, "hp": ", ".join(hp)}
