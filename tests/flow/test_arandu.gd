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


## D045: Arandu começa de noite (janelas acesas) e F3 volta para o dia igual ao de antes.
func test_night_and_back_to_day() -> void:
	var level := (load(Game.ARANDU) as PackedScene).instantiate() as Level
	assert_true(level.noite, "Arandu começa de noite")
	level.noite = false
	level.skip_intro = true
	Level.editing = true  # só o cenário
	add_child_autofree(level)
	var env_node := level.get_node("WorldEnvironment") as WorldEnvironment
	var day_env := env_node.environment
	var sun := level.get_node("Sun") as DirectionalLight3D
	var day_energy := sun.light_energy
	level.set_night(true)
	assert_ne(env_node.environment, day_env, "de noite o céu é outro")
	assert_lt(sun.light_energy, day_energy, "a lua é mais fraca que o sol")
	var lit := 0
	for found: Node in level.get_node("Buildings").find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		for k: int in mesh.get_surface_override_material_count():
			var mat := mesh.get_surface_override_material(k) as StandardMaterial3D
			if mat and mat.emission_enabled:
				lit += 1
	assert_gt(lit, 50, "janelas acesas de noite")
	level.set_night(false)
	assert_eq(env_node.environment, day_env, "o dia volta igual")
	assert_eq(sun.light_energy, day_energy)
	Level.editing = false
