extends GutTest
## Ofícios (D063): cada um veste o boneco do KayKit com as coisas dele, e a roupa tinge sem pintar rosto nem mão.


func test_every_profession_dresses_up() -> void:
	for oficio: String in Oficios.LISTA:
		var fig := Figurante.new()
		add_child_autofree(fig)
		fig.oficio = oficio
		var spec: Dictionary = Oficios.LISTA[oficio]
		assert_eq(fig.personagem, String(spec["modelo"]), oficio)
		var worn := fig.find_children("Oficio_*", "", true, false)
		assert_eq(worn.size(), (spec.get("veste", []) as Array).size(), "%s veste tudo" % oficio)


func test_every_object_file_exists() -> void:
	for key: String in Oficios.OBJETOS:
		assert_true(ResourceLoader.exists(String(Oficios.OBJETOS[key][0])), key)


func test_clothes_tint_uses_the_mask() -> void:
	# a máscara (tools/art/mascaras_kaykit.py) é o que impede o rosto azul e o cabelo verde
	var fig := Figurante.new()
	add_child_autofree(fig)
	fig.oficio = "dona_de_casa"
	var body: MeshInstance3D = null
	for found: Node in fig.find_children("*_Body", "MeshInstance3D", true, false):
		body = found as MeshInstance3D
	assert_not_null(body)
	var mat := body.material_override as ShaderMaterial
	assert_not_null(mat, "a roupa foi tingida")
	assert_true(bool(mat.get_shader_parameter("use_mask")), "com a máscara da roupa")


func test_the_baker_and_the_smith_look_the_part() -> void:
	var baker := Figurante.new()
	add_child_autofree(baker)
	baker.oficio = "padeiro"
	assert_not_null(baker.find_child("Oficio_toque", true, false), "chapéu de padeiro")
	assert_not_null(baker.find_child("Oficio_rolo", true, false), "rolo de massa")
	var smith := Figurante.new()
	add_child_autofree(smith)
	smith.oficio = "ferreiro"
	assert_not_null(smith.find_child("Oficio_martelo", true, false), "martelo (não machado)")
	assert_eq(smith.na_mao, "", "o machado do KayKit fica escondido")
