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
