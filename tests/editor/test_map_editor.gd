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


func test_fountain_is_one_piece_and_walls_carry_their_collision() -> void:
	var editor := await _open(Game.ARANDU)
	var names: Array[String] = []
	for item: Node3D in editor.items():
		names.append(String(item.name))
	assert_true(names.has("Chafariz"), "o chafariz do centro (D041) é uma peça só")
	assert_false(names.has("Ring"))
	var wall := editor.level.get_node("Walls/Muro") as Node3D
	assert_true(names.has("Muro"), "a muralha é feita de pedaços de muro do kit")
	assert_true(wall.is_in_group("colisao_auto"))
	assert_false(wall.find_children("*", "CollisionObject3D", true, false).is_empty(), "o muro ganha colisão e ela anda junto")


func _click(editor: MapEditor, at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = at
		editor.call("_on_mouse_button", event)


func test_clicking_again_picks_the_piece_underneath() -> void:
	var editor := await _open(Game.ARANDU)
	var spot := Vector3(150, 0, 150)
	var house := editor.place("casa", spot)
	var crate := editor.place("caixa_maca", spot + Vector3(0, 0.2, 0))
	editor.select_nodes([])
	(editor.get("_camera") as EditorCamera).focus(spot, 30.0)
	await wait_physics_frames(4)
	var cam: Camera3D = editor.get("_camera").camera
	var screen := cam.unproject_position(spot + Vector3(0, 0.4, 0))
	var under := editor.pieces_under(screen)
	assert_true(under.has(house), "a casa está embaixo do mouse")
	assert_true(under.has(crate), "o caixote dentro da casa também")
	_click(editor, screen)
	assert_eq(editor.selection.size(), 1)
	var first := editor.selection[0]
	_click(editor, screen)
	assert_eq(editor.selection.size(), 1)
	assert_ne(editor.selection[0], first, "clicar de novo passa para a de baixo")
	var seen: Array = [first, editor.selection[0]]
	for i: int in under.size():
		_click(editor, screen)
		seen.append(editor.selection[0])
	assert_true(seen.has(house) and seen.has(crate), "dá a volta por todas")
	_click(editor, screen + Vector2(40, 0))
	_click(editor, screen)
	assert_eq(editor.selection[0], first, "clicou em outro lugar: começa pela de cima")


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
	assert_true((again.get_node("CameraRig/Arm/Camera3D") as Camera3D).current, "a câmera do jogo continua a atual no arquivo")
	await wait_physics_frames(2)
	assert_eq(editor.get_viewport().get_camera_3d(), editor._camera.camera, "e no editor quem manda é a câmera do editor")


func test_saved_ethera_keeps_every_group() -> void:
	var editor := await _open(Game.ETHERA)
	assert_eq(editor.save(OUT), OK)
	var again := (ResourceLoader.load(OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as Node3D
	add_child_autofree(again)
	var groups := again.get_node("Encounters").get_children()
	assert_eq(groups.size(), 5)
	assert_eq(again.get_node("Encounters/EscaravelhosOeste").get_child_count(), 2)
	assert_eq(again.get_node("Rocks").get_child_count(), editor.level.get_node("Rocks").get_child_count())


## Biblioteca (D042): todas as peças prontas e todos os kits, organizados, com nome em português.
func test_library_has_everything_organized() -> void:
	var lib := EditorLibrary.new()
	for c: String in ["Prédios", "Praça e feira", "Natureza", "Objetos", "Animais", "Inimigos", "Peças de casa (kit)", "Masmorra"]:
		assert_true(lib.categories.has(c), c)
	var props := 0
	for file: String in DirAccess.get_files_at("res://world/props/"):
		if file.ends_with(".tscn"):
			props += 1
			assert_true(lib.by_key.has("res://world/props/" + file), "%s está na biblioteca" % file)
	assert_gt(lib.by_key.size(), props + 300, "mais as peças soltas dos kits")
	assert_eq(EditorLibrary.pretty("Wall_Plaster_Door_Round"), "Parede reboco porta redonda")
	assert_true(lib.search("padaria").size() >= 1)
	assert_eq(float(lib.by_key["res://assets/kits/polypizza/Medieval-Village-Pack/Fantasy_Inn.glb"]["escala"]), 3.0)


## Grade (D042): a pegada da peça encaixa nas linhas (borda na linha, centro no meio das células).
func test_grid_snaps_by_footprint() -> void:
	var editor := await _open(Game.ARANDU)
	editor.set_grid(1.0)
	var house := editor.place("casa", Vector3(10.3, 0, 30.7))
	await wait_physics_frames(1)
	editor.select_nodes([house])
	editor.center_selection()
	# casa de 6 m (6,25 com o beiral): número par de células, o centro cai numa linha e as paredes também
	var center := editor._bounds(house).get_center()
	assert_almost_eq(fposmod(center.x + 0.5, 1.0), 0.5, 0.02, "centro na linha da grade")
	assert_almost_eq(fposmod(center.z + 0.5, 1.0), 0.5, 0.02)
	var before := editor._bounds(house).get_center()
	editor.rotate_selection(PI / 2.0)
	assert_almost_eq(editor._bounds(house).get_center().x, before.x, 0.05, "gira no lugar, sem andar")
	assert_almost_eq(editor._bounds(house).get_center().z, before.z, 0.05)


func test_kit_piece_comes_in_the_right_size() -> void:
	var editor := await _open(Game.ARANDU)
	var inn := editor.place("res://assets/kits/polypizza/Medieval-Village-Pack/Fantasy_Inn.glb", Vector3(0, 0, 30))
	await wait_physics_frames(1)
	assert_gt(editor._bounds(inn).size.x, 9.0, "a estalagem do pacote vem 3x maior (tamanho de prédio)")
	assert_eq(inn.get_parent().name, &"Buildings")


## Acervo (D043): fora do Git. Nenhuma fase do repositório pode apontar para ele (quebraria no PC dos outros).
func test_no_level_points_to_the_local_acervo() -> void:
	for dir: String in DirAccess.get_directories_at("res://levels/"):
		for file: String in DirAccess.get_files_at("res://levels/" + dir):
			if file.ends_with(".tscn"):
				var text := FileAccess.get_file_as_string("res://levels/%s/%s" % [dir, file])
				assert_false(text.contains("res://assets/acervo/"), "%s usa modelo do acervo sem copiar" % file)


## Salvar copia o modelo usado do acervo para assets/kits/polypizza e troca o caminho no arquivo.
func test_saving_promotes_acervo_models() -> void:
	var editor := await _open(Game.ARANDU)
	var src_dir := "res://assets/acervo/_teste/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(src_dir))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/kits/polypizza/Food-Kit/Apple.glb"), ProjectSettings.globalize_path(src_dir + "Maca.glb"))
	var scene := "user://teste_acervo.tscn"
	var f := FileAccess.open(scene, FileAccess.WRITE)
	f.store_string('[gd_scene format=3]\n\n[ext_resource type="PackedScene" uid="uid://abc" path="res://assets/acervo/_teste/Maca.glb" id="1_m"]\n\n[node name="X" type="Node3D"]\n\n[node name="Maca" parent="." instance=ExtResource("1_m")]\n')
	f.close()
	assert_eq(editor.promote_acervo(scene), 1)
	var text := FileAccess.get_file_as_string(scene)
	assert_false(text.contains("assets/acervo"))
	assert_true(text.contains('path="res://assets/kits/polypizza/_teste/Maca.glb"'))
	assert_false(text.contains("uid://abc"), "o uid antigo sai (o arquivo copiado ganha outro)")
	assert_true(FileAccess.file_exists("res://assets/kits/polypizza/_teste/Maca.glb"))
	for path: String in ["res://assets/kits/polypizza/_teste/Maca.glb", src_dir + "Maca.glb", scene]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for dir: String in ["res://assets/kits/polypizza/_teste", src_dir]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


## D049: Separar (X) desmonta a peça nas partes dela (a banca, cada caixote cheio), salva assim e o Ctrl+Z junta de novo.
func test_separate_splits_a_stall_into_its_parts() -> void:
	var editor := await _open(Game.ARANDU)
	var stall := editor.place("res://world/props/banca_frutas.tscn", Vector3(60, 0, 60))
	var before := editor.items().size()
	editor.select_nodes([stall])
	editor.separate_selection()
	assert_false(stall.is_inside_tree(), "a banca inteira saiu")
	var names: Array[String] = []
	for piece: Node3D in editor.selection:
		names.append(String(piece.name))
	assert_true(names.has("Caixa_maca"), "o caixote de maçã é uma peça própria: %s" % [names])
	assert_true(names.any(func(n: String) -> bool: return n.begins_with("Banca")), "a barraca vazia também (o nome ganha número se já tiver outra)")
	assert_eq(editor.items().size(), before - 1 + editor.selection.size())
	var crate: Node3D = editor.selection[names.find("Caixa_maca")]
	assert_almost_eq(crate.global_position.y, 0.765, 0.01, "o caixote fica no balcão")
	assert_eq(editor.save(OUT), OK)
	var again := (load(OUT) as PackedScene).instantiate() as Node3D
	assert_not_null(again.find_child("Caixa_maca", true, false), "salvo separado")
	again.free()
	editor.undo()
	assert_true(stall.is_inside_tree(), "Ctrl+Z junta de novo")
	assert_false(crate.is_inside_tree())
