extends SceneTree
## Mede a dificuldade da arena: a IA joga por você e acerta os QTE com a taxa de cada perfil de jogador.
## Para cada herói, cada grupo de Ethera e cada perfil: quantas vitórias e quanta vida sobra (começando cheio).
## Uso: godot --headless --path . -s res://tools/simulate_arena.gd [-- vezes [heroi]]

const ARENA := "res://levels/arenas/ethera_arena.tscn"
const SPEED := 8.0
const BEETLE := "res://actors/enemies/escaravelho_de_cinza.tscn"
const SENTINEL := "res://actors/enemies/sentinela_estelar.tscn"
const BOSS := "res://actors/enemies/ultimo_guardiao.tscn"
const GROUPS := {
	"2 escaravelhos": [BEETLE, BEETLE],
	"sentinela": [SENTINEL],
	"Último Guardião": [BOSS],
}
## perfil: [perfeito, bom, esquiva, aparar]
const PROFILES := {
	"bom": [0.6, 0.25, 0.45, 0.25],
	"médio": [0.3, 0.35, 0.3, 0.1],
	"fraco": [0.1, 0.3, 0.15, 0.03],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 4
	var only := args[1] if args.size() > 1 else ""
	Engine.time_scale = SPEED
	for id: String in game.HEROES:
		if only != "" and id != only:
			continue
		for group: String in GROUPS:
			var line := "%-11s %-16s" % [id, group]
			for profile: String in PROFILES:
				var wins := 0
				var hp_left := 0.0
				for r: int in runs:
					seed(100 + r)
					Dice.rng.seed = 100 + r
					var res := await _fight(game, id, GROUPS[group], PROFILES[profile])
					if res["win"]:
						wins += 1
						hp_left += res["hp"]
				line += "  %s %d/%d (PV %2.0f%%)" % [profile, wins, runs, 100.0 * hp_left / maxf(1.0, wins)]
			print(line)
	quit()


func _fight(game: Node, id: String, enemies: Array, profile: Array) -> Dictionary:
	paused = false
	game.chosen = id
	game.hero_hp = -1
	game.battle = {"id": "sim", "enemies": PackedStringArray(enemies), "first_strike": false}
	# sem tipo: este script compila antes do autoload Game existir, e BattleArena depende dele
	var arena: Node = (load(ARENA) as PackedScene).instantiate()
	arena.set("auto_play", true)
	arena.set("auto_perfect", profile[0])
	arena.set("auto_good", profile[1])
	arena.set("auto_dodge", profile[2])
	arena.set("auto_parry", profile[3])
	root.add_child(arena)
	var result := []
	arena.connect("finished", func(victory: bool) -> void: result.append(victory))
	var frames := 0
	while result.is_empty() and frames < 60 * 300:
		await process_frame
		frames += 1
	var win: bool = not result.is_empty() and result[0]
	var player: Node = arena.get("player")
	var hp := float(player.get("hp")) / float(player.get("max_hp"))
	arena.queue_free()
	await process_frame
	return {"win": win, "hp": hp}
