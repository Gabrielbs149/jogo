extends SceneTree
## Põe o capítulo de Arandu (D086) na fase, depois do montar_prologo.gd: os dois capangas da Forja e o mendigo que eles
## arrastam (perto da carroça do celeiro, escondidos até a noite do celeiro), a pista no chão do celeiro, onde o Brás
## senta no beco na cena dos meses, o "Pegar as suas coisas" no barraco e o nó do capítulo (Missoes/CapituloArandu).
## Pode rodar de novo: refaz só essas peças. Uso: godot --headless --path . -s tools/art/montar_capitulo_arandu.gd

const LEVEL := "res://levels/arandu/arandu.tscn"

var level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	var cena := level.get_node("CenaTico") as Node3D
	var people := level.get_node("People") as Node3D
	var bras := people.get_node("Bras") as Node3D
	# o Brás: o lugar dele na esquina, e onde ele senta no beco (onde a Tika sentava, do outro lado da fogueirinha)
	_mark(people, "BrasEsquina", bras.global_transform)
	_mark(cena, "BrasNoBeco", (cena.get_node("TikaSentada") as Node3D).global_transform)
	# a noite do celeiro: o mendigo sentado no chão perto da carroça, um capanga de cada lado
	var cart := level.get_node("Props/BicoCeleiro/Carroca") as Node3D
	var c := cart.global_position
	var street := Vector3(-1, 0, 0)  # o Tico chega pela rua, do lado oeste
	var held := c + Vector3(-2.2, 0, 1.4)
	var levado := _person("Levado", Transform3D(_facing(street), held), "Rogue_Hooded", "Sit_Floor_Idle", 0.55)
	var talk := levado.get_node("Talk") as Node3D
	talk.set("action", 4)
	talk.set("prompt_text", "Falar com o mendigo")
	talk.set("text", "")
	talk.position = Vector3(0, 0.6, 0)
	var thug := _person("CapangaDaForja", Transform3D(_facing(held - (held + Vector3(-0.9, 0, -0.9))), held + Vector3(-0.9, 0, -0.9)),
		"Barbarian", "Idle", 0.62)
	var roper := _person("LacadorDaForja", Transform3D(_facing(held - (held + Vector3(0.6, 0, 1.0))), held + Vector3(0.6, 0, 1.0)),
		"Rogue_Hooded", "Idle", 0.62)
	# a pista no chão do celeiro, entre a carroça e o caminho: um laço roxo (a fita) quando ela estava com a Tika
	var spot := level.get_node("Props/BicoCeleiro") as Node3D
	var clue := _child(spot, "PistaCeleiro") as Node3D
	clue.set_script(load("res://world/interactable.gd"))
	clue.set("action", 4)
	clue.set("prompt_text", "Olhar o chão")
	clue.set("text", "")
	clue.global_position = c + Vector3(-1.4, 0.05, 2.2)
	var bow := _bow(clue)
	# pegar as coisas no barraco, em cima da cama
	var corner := level.get_node("TicoCorner")
	var bag := _child(corner, "PegarCoisas") as Node3D
	bag.set_script(load("res://world/interactable.gd"))
	bag.set("action", 4)
	bag.set("prompt_text", "Pegar as suas coisas")
	bag.set("text", "")
	bag.global_position = (cena.get_node("TicoDeitado") as Node3D).global_position + Vector3(0, 0.5, 0)
	# o capítulo
	var quest := _child(level.get_node("Missoes"), "CapituloArandu", false)
	quest.set_script(load("res://world/quests/capitulo_arandu.gd"))
	quest.set("tika", cena.get_node("Tika"))
	quest.set("falar_tika", cena.get_node("Tika/FalarTika"))
	quest.set("bras", bras)
	quest.set("bras_esquina", people.get_node("BrasEsquina"))
	quest.set("capangas", [thug, roper] as Array[Node3D])
	quest.set("levado", levado)
	quest.set("falar_levado", talk)
	quest.set("carroca", cart)
	quest.set("pista", clue)
	quest.set("pista_laco", bow)
	quest.set("mochila", bag)
	quest.set("portao", level.get_node("Gate"))
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


## O laço roxo (igual ao da fita do beco lateral).
func _bow(parent: Node3D) -> Node3D:
	var bow := parent.get_node_or_null("Laco") as Node3D
	if bow:
		return bow
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.2, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.12, 0.55)
	mat.emission_energy_multiplier = 0.6
	bow = Node3D.new()
	bow.name = "Laco"
	parent.add_child(bow)
	bow.owner = level
	for k: int in 3:
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.11, 0.015, 0.05) if k < 2 else Vector3(0.03, 0.02, 0.03)
		box.material = mat
		part.mesh = box
		part.name = "Parte%d" % k
		bow.add_child(part)
		part.owner = level
		part.position = Vector3([-0.055, 0.055, 0.0][k], 0.0, 0.0)
		part.rotation.y = [0.35, -0.35, 0.0][k]
	return bow


## Uma pessoa nova (world/props/morador.tscn) em People, com o personagem e a animação dados.
func _person(person_name: String, at: Transform3D, model: String, anim: String, size: float) -> Node3D:
	var people := level.get_node("People")
	var person := people.get_node_or_null(person_name) as Node3D
	if person == null:
		person = (load("res://world/props/morador.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		person.name = person_name
		people.add_child(person)
		person.owner = level
	person.global_transform = at
	var figure := person.get_node("Figure") as Node3D
	figure.set("personagem", model)
	figure.set("animacao", anim)
	figure.set("na_mao", "")
	figure.scale = Vector3.ONE * size
	level.set_editable_instance(person, true)
	return person


func _facing(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-dir.x, -dir.z))


func _child(parent: Node, child_name: String, spatial: bool = true) -> Node:
	var node := parent.get_node_or_null(child_name)
	if node == null:
		node = Node3D.new() if spatial else Node.new()
		node.name = child_name
		parent.add_child(node)
		node.owner = level
	return node


func _mark(parent: Node3D, mark_name: String, at: Transform3D) -> Marker3D:
	var mark := parent.get_node_or_null(mark_name) as Marker3D
	if mark == null:
		mark = Marker3D.new()
		mark.name = mark_name
		parent.add_child(mark)
		mark.owner = level
	mark.global_transform = at
	return mark
