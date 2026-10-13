extends GutTest
## Arandu arrumada (D071): as bancas da feira com o balcão comprido para a praça e a mercadoria em cima dele; o estoque
## atrás dos vendedores; nada na frente das portas; a tralha solta das ruas não volta.

const ARANDU := "res://levels/arandu/arandu.tscn"
const BANCAS := ["banca_frutas", "banca_verduras", "banca_paes", "banca_peixe"]

var _level: Node3D


func before_all() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	_level = (load(ARANDU) as PackedScene).instantiate() as Node3D
	add_child(_level)
	await wait_process_frames(2)


func after_all() -> void:
	_level.queue_free()
	(load("res://world/level.gd") as GDScript).set("editing", false)


## O balcão comprido (3,6 m) fica de lado para a frente da banca (-Z da peça) e a mercadoria fica em cima dele, na
## metade da frente: antes o modelo estava girado 90° e da praça só se via a ponta do balcão.
func test_stalls_face_the_buyer_with_goods_on_the_counter() -> void:
	for name: String in BANCAS:
		var stall := (load("res://world/props/%s.tscn" % name) as PackedScene).instantiate() as Node3D
		add_child_autofree(stall)
		await wait_process_frames(1)
		var counter := _box_in(stall, stall.get_node("Banca") as Node3D)
		assert_gt(counter.size.x, counter.size.z + 0.3, "%s: o lado comprido do balcão olha para quem compra" % name)
		var goods := 0
		for child: Node in stall.get_children():
			if String(child.name).begins_with("Caixa_") or String(child.name).begins_with("Mercadoria"):
				var at := (child as Node3D).position
				assert_between(at.y, 0.7, 0.85, "%s/%s em cima do balcão" % [name, child.name])
				assert_between(at.x, counter.position.x, counter.end.x, "%s/%s dentro do balcão (x)" % [name, child.name])
				assert_lt(at.z, 0.0, "%s/%s na metade da frente" % [name, child.name])
				goods += 1
			elif String(child.name).begins_with("CaixoteChao"):
				assert_gt((child as Node3D).position.z, 0.6, "%s: caixote de estoque atrás da banca" % name)
		assert_gt(goods, 2, name)


## O estoque da feira fica atrás dos vendedores (x > 17), não entre a barraca e a praça.
func test_market_stock_behind_the_vendors() -> void:
	for name: String in ["Barril", "Caixote", "Caixote_macas", "Barris", "Cesto"]:
		var node := _level.get_node_or_null("Market/" + name) as Node3D
		if node:
			assert_gt(node.global_position.x, 17.0, name)
	for k: int in 4:
		var vendor := _level.get_node_or_null("Crowd/Vendedor%d" % (k + 1) if k > 0 else "People/Vendedor") as Node3D
		if vendor:
			assert_between(vendor.global_position.x, 15.6, 17.0, "%s atrás do balcão" % vendor.name)


## Nada da fachada na frente da porta (o vão e 1,8 m para fora), e a tralha de rua sorteada não volta.
func test_doors_are_free_and_no_stray_clutter() -> void:
	var doors: Array[Rect2] = []
	for b: Node in _level.get_node("Buildings").get_children():
		var house := b as Node3D
		if house == null or not house.has_meta("celulas"):
			continue
		var cells: Vector2i = house.get_meta("celulas")
		var door_x := -cells.x + 1.0 + 2.0 * int(house.get_meta("porta", 0))
		var r := Rect2()
		var first := true
		for local: Vector3 in [Vector3(door_x - 0.7, 0, -cells.y), Vector3(door_x + 0.7, 0, -cells.y - 1.6)]:
			var p := house.global_transform * local
			r = Rect2(p.x, p.z, 0, 0) if first else r.expand(Vector2(p.x, p.z))
			first = false
		doors.append(r)
	for child: Node in _level.get_node("Props").get_children():
		var prop := child as Node3D
		if prop == null:
			continue
		assert_false(String(prop.name).begins_with("Vaso") or String(prop.name).begins_with("Balde") or
			String(prop.name).begins_with("Banquinho"), "tralha de rua voltou: %s" % prop.name)
		if not String(prop.name).begins_with("Fachada_"):
			continue
		var p := prop.global_position
		for door: Rect2 in doors:
			assert_false(door.has_point(Vector2(p.x, p.z)), "%s na frente de uma porta" % prop.name)


func _box_in(root: Node3D, part: Node3D) -> AABB:
	var inv := root.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for v: Node in part.find_children("*", "MeshInstance3D", true, false):
		var b := inv * (v as MeshInstance3D).global_transform * (v as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
