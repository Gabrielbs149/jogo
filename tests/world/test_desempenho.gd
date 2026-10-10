extends GutTest
## Desempenho de Arandu (D065): sem luz de fogo com sombra, nada de dentro das casas fazendo sombra do sol, coisa
## miúda que some de longe e animação mais rala para quem está longe.

const ARANDU := "res://levels/arandu/arandu.tscn"

var _level: Level


func before_all() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge({"prologo.etapa": "saiu", "comida.comecou": true})
	Game.hora = 10.0
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 25.0)


func after_all() -> void:
	_level.queue_free()
	Game.flags.clear()


func test_no_point_light_casts_shadows() -> void:
	for found: Node in _level.find_children("*", "Light3D", true, false):
		if not found is DirectionalLight3D:
			assert_false((found as Light3D).shadow_enabled, "%s sem sombra" % found.get_path())


func test_interiors_do_not_cast_sun_shadows() -> void:
	var tavern := _level.get_node("Buildings/Taverna/Interior") as InteriorSobDemanda
	tavern.load_now()
	var checked := 0
	for found: Node in tavern.find_children("*", "GeometryInstance3D", true, false):
		var geo := found as GeometryInstance3D
		if geo is MultiMeshInstance3D or geo is GPUParticles3D or geo is Label3D:
			continue
		assert_eq(geo.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, String(geo.name))
		checked += 1
	assert_gt(checked, 20)


func test_small_props_fade_out_far_away() -> void:
	var with_range := 0
	var total := 0
	for found: Node in _level.get_node("Props").find_children("*", "MeshInstance3D", true, false):
		total += 1
		if (found as MeshInstance3D).visibility_range_end > 0.0:
			with_range += 1
	assert_gt(with_range, total / 2, "a maior parte das coisas miúdas some de longe")
