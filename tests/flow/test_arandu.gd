extends GutTest
## Arandu grande (D044): o construtor da cidade pula o prédio que não cabe. As casas da história e os lugares
## grandes precisam estar lá depois de remontar.


func test_story_buildings_and_places_are_in_arandu() -> void:
	var level := (load(Game.ARANDU) as PackedScene).instantiate() as Node3D
	for name: String in ["CasaDaViuva", "Sapateiro", "Padaria", "Ferreiro", "Estalagem", "Guarita", "Estabulo", "Moinho", "Serraria",
			"CeleiroDaCidade", "CeleiroGrande", "Celeiro"]:
		assert_not_null(level.get_node_or_null("Buildings/" + name), "%s está na cidade" % name)
	assert_not_null(level.get_node_or_null("Cemetery/Cripta"), "o cemitério tem a cripta")
	assert_not_null(level.get_node_or_null("TicoCorner/Look"), "o beco do Tico está lá")
	level.free()


func test_wheat_fields_have_wheat() -> void:
	var level := (load(Game.ARANDU) as PackedScene).instantiate() as Node3D
	for name: String in ["TrigalOeste", "TrigalLeste", "TrigoDoMoinho"]:
		var field := level.get_node_or_null("Gardens/" + name) as MultiMeshInstance3D
		assert_not_null(field, "%s existe" % name)
		if field:
			assert_gt(field.multimesh.instance_count, 500, "%s tem trigo" % name)
	level.free()


## D060: o tempo passa. Às 22h é noite (lua fraca, janelas acesas, postes acesos); ao meio-dia, dia (sol forte,
## janelas apagadas, postes apagados). F3 (set_night) pula o relógio.
func test_the_clock_makes_day_and_night() -> void:
	Game.flags.clear()
	Game.flags["prologo.etapa"] = "saiu"
	Game.seen.assign([Game.ARANDU])
	var level := (load(Game.ARANDU) as PackedScene).instantiate() as Level
	level.skip_intro = true
	add_child_autofree(level)
	await wait_until(func() -> bool: return level.ready_to_play, 20.0)
	assert_not_null(level.ciclo, "Arandu tem o relógio do dia")
	var sun := level.get_node("Sun") as DirectionalLight3D
	level.ciclo.jump_to(12.0)
	var noon := sun.light_energy
	assert_lt(level.ciclo.noite, 0.05, "meio-dia é dia")
	level.set_night(true)
	assert_almost_eq(Game.hora, 22.0, 0.01)
	assert_gt(level.ciclo.noite, 0.95, "22h é noite")
	assert_lt(sun.light_energy, noon, "a lua é mais fraca que o sol")
	var lit := 0
	for found: Node in level.get_node("Buildings").find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		for k: int in mesh.get_surface_override_material_count():
			var mat := mesh.get_surface_override_material(k) as StandardMaterial3D
			if mat and mat.emission_enabled:
				lit += 1
	assert_gt(lit, 50, "janelas acesas de noite")
	level.set_night(false)
	assert_almost_eq(Game.hora, 12.0, 0.01)
	assert_almost_eq(sun.light_energy, noon, 0.01, "o dia volta igual")


func test_midnight_turns_the_day() -> void:
	Game.hora = 23.9
	Game.dia = 1
	Game.advance_time(0.2)
	assert_eq(Game.dia, 2)
	assert_almost_eq(Game.hora, 0.1, 0.001)
	assert_eq(Game.clock_text(), "00:06")
