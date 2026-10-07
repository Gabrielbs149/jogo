extends GutTest
## Editor de mapas: abre a fase parada, coloca peças do catálogo, move, duplica, apaga, desfaz e salva
## uma .tscn que abre de novo igual.

const OUT := "user://teste_editor_mapa.tscn"


func _open(level_path: String) -> MapEditor:
	Game.edit_level = level_path
	Game.edit_draft = ""
	var editor := (load("res://editor/map_editor.tscn") as PackedScene).instantiate() as MapEditor
	add_child_autofree(editor)
	await wait_physics_frames(3)
	return editor


func after_each() -> void:
	Level.editing = false
	if FileAccess.file_exists(OUT):
		DirAccess.remove_absolute(OUT)


func test_level_opens_still_without_hero() -> void:
	var editor := await _open(Game.ETHERA)
	assert_true(Level.editing)
	assert_null(editor.level.get("player"), "no editor ninguém nasce na fase")
	assert_gt(editor.items().size(), 20, "pedras, pilares, grupos, começo...")
	var names: Array[String] = []
	for item: Node3D in editor.items():
		names.append(String(item.name))
	assert_true(names.has("EscaravelhosOeste"), "o grupo de inimigos é uma peça só")
	assert_true(names.has("PlayerSpawn"))
	assert_false(names.has("Terrain"), "o chão não se clica")


func test_well_is_one_piece_and_walls_carry_their_collision() -> void:
	var editor := await _open(Game.ARANDU)
	var names: Array[String] = []
	for item: Node3D in editor.items():
		names.append(String(item.name))
	assert_true(names.has("Well"), "o poço é uma peça")
	assert_false(names.has("Ring"))
	var wall := editor.level.get_node("Walls/North1_0") as Node3D
	assert_true(names.has("North1_0"), "a muralha é feita de pedaços de muro do kit")
	assert_true(wall.is_in_group("colisao_auto"))
	assert_false(wall.find_children("*", "CollisionObject3D", true, false).is_empty(), "o muro ganha colisão e ela anda junto")


func test_place_move_undo_redo() -> void:
	var editor := await _open(Game.ARANDU)
	var before := editor.items().size()
	var tree := editor.place("arvore", Vector3(3, 0, 3))
	assert_eq(tree.owner, editor.level, "a peça é da fase (vai para o arquivo)")
	assert_eq(tree.get_parent().name, &"Trees")
	assert_eq(editor.items().size(), before + 1)
	editor.select_nodes([tree])
	editor.move_selection(Vector3(2, 0, 0))
	assert_almost_eq(tree.position.x, 5.0, 0.001)
	editor.rotate_selection(PI / 2.0)
	editor.undo()
	editor.undo()
	assert_almost_eq(tree.position.x, 3.0, 0.001, "desfaz o movimento")
	editor.undo()
	assert_false(tree.is_inside_tree(), "desfaz a colocação")
	editor.redo()
	assert_true(tree.is_inside_tree())
	assert_eq(tree.owner, editor.level, "volta a ser da fase")


func test_delete_and_duplicate_keep_ownership() -> void:
	var editor := await _open(Game.ETHERA)
	var group := editor.level.get_node("Encounters/SentinelaOeste") as Node3D
	editor.select_nodes([group])
	editor.duplicate_selection()
	var copy := editor.selection[0]
	assert_ne(copy, group)
	assert_eq(copy.owner, editor.level)
	assert_ne((copy as Encounter).id(), (group as Encounter).id(), "vencer um grupo não some com a cópia")
	for member: Node in copy.get_children():
		assert_eq(member.owner, editor.level, "os inimigos da cópia também vão para o arquivo")
	editor.select_nodes([group])
	editor.delete_selection()
	assert_false(group.is_inside_tree())
	editor.undo()
	assert_true(group.is_inside_tree())
	assert_eq(group.get_child(0).owner, editor.level)


func test_editing_inside_a_piece_and_saving_round_trip() -> void:
	var editor := await _open(Game.ARANDU)
	var person := editor.place("morador", Vector3(-4, 0, 2), 0.5)
	var talk := person.get_node("Talk") as Interactable
	editor.set_prop(talk, "text", "— Bom dia, Tico.")
	var exit := editor.place("saida", Vector3(0, 0, -20))
	editor.set_prop(exit, "target_scene", Game.ETHERA)
	editor.set_prop(editor.level, "chapter_title", "Arandu (editada)")
	assert_eq(editor.save(OUT), OK)
	var again := (ResourceLoader.load(OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as Node3D
	add_child_autofree(again)
	assert_eq(again.get("chapter_title"), "Arandu (editada)")
	var saved_person := again.get_node("People/" + String(person.name))
	assert_not_null(saved_person)
	assert_eq((saved_person.get_node("Talk") as Interactable).text, "— Bom dia, Tico.", "a fala nova foi salva")
	var saved_exit := again.get_node("Places/" + String(exit.name)) as Interactable
	assert_eq(saved_exit.target_scene, Game.ETHERA)
	assert_almost_eq((saved_exit as Node3D).position.z, -20.0, 0.01)
	assert_not_null(again.get_node_or_null("HUD"), "a fase salva continua completa")
	assert_true((again.get_node("HUD") as CanvasLayer).visible, "o painel do jogo volta visível no arquivo")


func test_saved_ethera_keeps_every_group() -> void:
	var editor := await _open(Game.ETHERA)
	assert_eq(editor.save(OUT), OK)
	var again := (ResourceLoader.load(OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as Node3D
	add_child_autofree(again)
	var groups := again.get_node("Encounters").get_children()
	assert_eq(groups.size(), 5)
	assert_eq(again.get_node("Encounters/EscaravelhosOeste").get_child_count(), 2)
	assert_eq(again.get_node("Rocks").get_child_count(), editor.level.get_node("Rocks").get_child_count())
