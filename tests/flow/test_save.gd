extends GutTest
## Jogo salvo (D037): grava herói, grupo, lutas vencidas, vida, fases vistas e onde você está; "Continuar" volta
## para a mesma fase e o mesmo lugar. O Testar do editor não grava por cima.

const LEVEL := "res://levels/ethera/ethera.tscn"
const PATH := "user://save_teste_unidade.json"

var _old_path: String


func before_each() -> void:
	_old_path = Game.save_path
	Game.save_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Game.testing = false


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Game.save_path = _old_path
	Game.returning = false


func test_save_and_continue_bring_everything_back() -> void:
	Game.chosen = "naumfode"
	Game.party.assign(["tico"])
	Game.defeated.assign(["grupo_1"])
	Game.hero_hp = 17
	Game.seen.assign([LEVEL])
	var where := Transform3D(Basis(Vector3.UP, 1.2), Vector3(3, 0.5, -7))
	assert_true(Game.save_game(LEVEL, where))
	assert_true(Game.has_save())
	# mexe em tudo; o continuar tem que trazer de volta
	Game.chosen = "tico"
	Game.party.clear()
	Game.defeated.clear()
	Game.hero_hp = -1
	assert_true(Game.continue_game(false))
	assert_eq(Game.chosen, "naumfode")
	assert_eq(Game.party, ["tico"] as Array[String])
	assert_eq(Game.defeated, ["grupo_1"] as Array[String])
	assert_eq(Game.hero_hp, 17)
	assert_true(Game.returning)
	assert_eq(Game.return_scene, LEVEL)
	assert_almost_eq(Game.return_transform.origin, where.origin, Vector3.ONE * 0.001)
	assert_almost_eq(Game.return_transform.basis.get_euler().y, 1.2, 0.001)
	Game.returning = false


func test_no_save_or_broken_save_means_no_continue() -> void:
	assert_false(Game.has_save())
	assert_false(Game.continue_game(false))
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{isso não é json")
	file.close()
	assert_false(Game.has_save(), "arquivo estragado não conta")
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"heroi": "ninguem", "fase": LEVEL, "posicao": [0, 0, 0]}))
	file.close()
	assert_false(Game.has_save(), "herói que não existe não conta")


func test_editor_test_run_does_not_overwrite_the_save() -> void:
	Game.chosen = "tico"
	Game.testing = true
	assert_false(Game.save_game(LEVEL, Transform3D.IDENTITY))
	assert_false(FileAccess.file_exists(PATH))
	Game.testing = false


func test_level_saves_on_entry_and_continue_puts_you_back_there() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.defeated.clear()
	Game.hero_hp = -1
	var level := (load(LEVEL) as PackedScene).instantiate() as Node3D
	level.set("skip_intro", true)
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.get("ready_to_play"), 15.0)
	assert_true(Game.has_save(), "entrar na fase grava")
	assert_eq(String(Game.read_save()["fase"]), LEVEL)
	# anda até outro lugar, grava de novo, e o continuar põe você lá
	var player := level.get("player") as Combatant
	player.global_position += Vector3(4, 0, -3)
	var spot := player.global_position
	assert_true(level.call("save_here", false))
	level.queue_free()
	await wait_physics_frames(2)
	assert_true(Game.continue_game(false))
	var again := (load(LEVEL) as PackedScene).instantiate() as Node3D
	again.set("skip_intro", true)
	add_child_autofree(again)
	await wait_until(func() -> bool: return again.get("ready_to_play"), 15.0)
	var back := again.get("player") as Combatant
	assert_lt(Vector2(back.global_position.x, back.global_position.z).distance_to(Vector2(spot.x, spot.z)), 0.5)
