extends SceneTree
## Monta o canto do Tico e da Tika no beco (D062), depois do montar_prologo.gd: o barraco de lona remendada, a cama
## de palha em cima do papelão, o cantinho da Tika, o assento do Tico, o varal, a lenha, a fogueirinha com cinza, a
## prateleira com as coisas deles, o chão de terra batida com palha, umidade nas paredes, o desenho de giz e a
## lanterna. As peças sob medida vêm do Blender (tools/blender/gerado/modelar_beco.py, em assets/beco/); as miudezas
## são do acervo (tools/art/trazer_do_acervo.py). Pode rodar de novo: refaz só o nó TicoCorner/Barraco.
## Uso (COM janela: tira a grama de dentro do beco, que é MultiMesh): godot --path . -s tools/art/montar_beco.gd

const LEVEL := "res://levels/arandu/arandu.tscn"
const BECO := "res://assets/beco/"
const PP := "res://assets/kits/polypizza/"
## O chão do beco: do pé da parede do fundo até a boca, entre a parede da casa da viúva (sul) e a do sapateiro (norte).
## (Medido pela colisão das paredes: a caixa das casas engana, porque inclui o beiral do telhado.)
const FUNDO := Vector3(-12.6, 0.0, -60.5)
const COMPRIMENTO := 6.9
const LARGURA := 5.4
## Onde a travessa da lona fica (z a partir da parede da viúva): igual ao FRENTE do modelar_beco.py.
const FRENTE := 2.72

var level: Node3D
var beco: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	for i: int in 4:
		await physics_frame
	var corner := level.get_node("TicoCorner") as Node3D
	var cena := level.get_node("CenaTico") as Node3D
	var old := corner.get_node_or_null("Barraco")
	if old:
		corner.remove_child(old)
		old.free()
	beco = Node3D.new()
	beco.name = "Barraco"
	corner.add_child(beco)
	beco.owner = level
	beco.global_transform = Transform3D.IDENTITY
	# o papelão liso de antes some: a cama nova fica no lugar dele (o nó fica, as cenas medem a partir dele)
	(corner.get_node("Blanket") as Node3D).visible = false
	var bed := (cena.get_node("TicoDeitado") as Node3D).global_position
	var tika_spot := (cena.get_node("TikaSentada") as Node3D).global_transform
	var seat := (cena.get_node("TicoSentado") as Node3D).global_position
	var fire := (cena.get_node("Fogueirinha") as Node3D).global_position

	# --- as peças sob medida
	_piece("Lona", "barraco", Transform3D(Basis(), FUNDO))
	_piece("CamaTico", "cama_tico", Transform3D(Basis(), Vector3(bed.x, 0, bed.z)))
	_piece("CamaTika", "cama_tika", Transform3D(Basis(Vector3.UP, 0.35), Vector3(tika_spot.origin.x, 0, tika_spot.origin.z)))
	_piece("Assento", "assento", Transform3D(Basis(), Vector3(seat.x, 0, seat.z)))
	_piece("Varal", "varal", Transform3D(Basis(), Vector3(FUNDO.x, 0, FUNDO.z + LARGURA - 0.23)))
	_piece("Lenha", "lenha", Transform3D(Basis(Vector3.UP, 0.08), FUNDO + Vector3(0.15, 0, 0.32)))
	_piece("Cinzas", "cinzas", Transform3D(Basis(), Vector3(fire.x, 0, fire.z)))
	_piece("Prateleira", "prateleira", Transform3D(Basis(), FUNDO + Vector3(0, 0, 3.11)))
	# as estacas seguram (o Tico não atravessa)
	_post_body(FUNDO + Vector3(0.23, 1.0, FRENTE + 0.03))
	_close_back(corner)
	_hide_old_stones(cena.get_node("Fogueirinha") as Node3D)

	# --- miudezas do acervo e das peças do jogo
	var shelf_y := 1.165
	var shelf := FUNDO + Vector3(0.1, shelf_y, 3.11)
	_kit("VelaNaPrateleira", PP + "Halloween-Bits/Candle_Melted.glb", shelf + Vector3(0, 0, 0.1), 0.0, 0.12)
	_kit("Garrafa", PP + "Bottles/Old_Bottle.glb", shelf + Vector3(0.02, 0, 0.27), 0.4, 0.24)
	_kit("Florzinha", PP + "Low-Poly-Outdoor-Garden-Decorations/Flower_Pot_2.glb", shelf + Vector3(0, 0, 0.7), 0.0, 0.2)
	_kit("Panela", PP + "Survival-Pack/Pot.glb", fire + Vector3(-0.32, 0, 0.42), 0.6, 0.16)
	_kit("Lata", PP + "Survival-Pack/Can.glb", fire + Vector3(-0.05, 0, 0.52), 0.0, 0.12)
	_kit("PaleteVelho", PP + "Post-Apocolypse-Pack/Pallet_Broken.glb",
		Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, -1.25), FUNDO + Vector3(5.0, 0.0, LARGURA - 0.12)), 0.9)
	_scene("Sacos", "res://world/props/sacos.tscn", Transform3D(Basis(Vector3.UP, 0.4), FUNDO + Vector3(4.2, 0, LARGURA - 0.4)))
	_scene("Balde", "res://world/props/balde.tscn", Transform3D(Basis(Vector3.UP, 1.1), FUNDO + Vector3(3.2, 0, 0.35)))
	var lantern := _kit("Lanterna", PP + "Witch-cottage-pack/Candle_Lantern.glb", FUNDO + Vector3(1.23, 1.38, FRENTE + 0.03), 0.0, 0.28)
	var glow := OmniLight3D.new()
	glow.name = "LuzLanterna"
	beco.add_child(glow)
	glow.owner = level
	glow.global_position = lantern.global_position + Vector3(0, 0.12, 0)
	glow.light_color = Color(1.0, 0.66, 0.34)
	glow.light_energy = 0.55
	glow.omni_range = 3.4
	glow.shadow_enabled = true
	# a caneca da Tika vai para a prateleira (de enfeite, do lado da florzinha); no caixote (o "cofre") fica o toco
	# de vela. Em cima do caixote ela tapava o Plano2 da cena do rato.
	var crate := corner.get_node("Crate1") as Node3D
	var cup := corner.get_node("Cup") as Node3D
	var crate_top := _top(crate)
	cup.global_position = shelf + Vector3(0.0, 0.0, 0.48)
	cup.rotation = Vector3(0, 0.9, 0)
	var look_cup := corner.get_node_or_null("OlharCaneca") as Node3D
	if look_cup:
		look_cup.global_position = cup.global_position + Vector3(0, 0.3, 0)
	_kit("TocoDeVela", PP + "Halloween-Bits/Candle_Melted.glb", Vector3(crate.global_position.x - 0.12, crate_top, crate.global_position.z + 0.1), 0.0, 0.07)

	# --- chão, paredes e luz
	_ground()
	_decal("Giz", "giz.png", FUNDO + Vector3(-0.08, 0.74, 3.2), Vector3(1.0, 0.0, 0.0), Vector2(1.2, 0.6))
	_decal("UmidadeFundo", "umidade.png", FUNDO + Vector3(-0.08, 0.35, 2.7), Vector3(1.0, 0.0, 0.0), Vector2(4.0, 0.7))
	_decal("UmidadeViuva", "umidade.png", FUNDO + Vector3(3.0, 0.35, -0.04), Vector3(0.0, 0.0, 1.0), Vector2(6.0, 0.7))
	_decal("UmidadeSapateiro", "umidade.png", FUNDO + Vector3(3.0, 0.3, LARGURA + 0.02), Vector3(0.0, 0.0, -1.0), Vector2(6.0, 0.6))
	await _clear_grass()

	# --- coisas para examinar (F)
	_examine("OlharDesenho", FUNDO + Vector3(0.25, 0.8, 3.2), "Examinar o desenho",
		"Um desenho de giz da Tika: os dois de mão dada, um sol e uma casa com fumaça saindo da chaminé. A casa ela fez maior que a do sapateiro.")
	_examine("OlharVaral", FUNDO + Vector3(1.6, 1.4, LARGURA - 0.35), "Examinar o varal",
		"A roupa dos dois secando. Secando é jeito de dizer: no beco o sol só entra ao meio-dia, e mesmo assim de passagem.")
	_examine("OlharLanterna", FUNDO + Vector3(1.23, 1.3, FRENTE - 0.2), "Examinar a lanterna",
		"Lanterna de vela achada no lixo do empório, com um vidro rachado. A vela dura uma noite, se ninguém abrir a porta dela para ver se ainda está acesa.")
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


# --- peças -------------------------------------------------------------------------------------------

func _piece(node_name: String, file: String, at: Transform3D) -> Node3D:
	return _scene(node_name, BECO + file + ".gltf", at)


func _scene(node_name: String, path: String, at: Transform3D) -> Node3D:
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = node_name
	beco.add_child(node)
	node.owner = level
	node.global_transform = at
	return node


## Peça do acervo com a altura dada (m), em pé no ponto (ou deitada, se lying). at = posição ou Transform3D.
func _kit(node_name: String, path: String, at: Variant, yaw: float = 0.0, height: float = 0.0, lying: bool = false) -> Node3D:
	var node := _scene(node_name, path, Transform3D.IDENTITY)
	var box := _aabb(node)
	var size := 1.0
	if height > 0.0 and box.size.y > 0.001:
		size = height / (box.size.x if lying else box.size.y)
	var basis := Basis(Vector3.UP, yaw)
	if lying:
		basis = basis * Basis(Vector3.FORWARD, PI / 2.0)
	if at is Transform3D:
		var t := at as Transform3D
		node.global_transform = Transform3D(t.basis.scaled(Vector3.ONE * height if height > 0.0 else Vector3.ONE), t.origin)
		return node
	node.global_transform = Transform3D(basis.scaled(Vector3.ONE * size), at as Vector3)
	# assenta no ponto: a base da caixa fica na altura pedida
	var after := _aabb(node)
	node.global_position.y += (at as Vector3).y - after.position.y
	return node


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _top(node: Node3D) -> float:
	return _aabb(node).end.y


func _post_body(at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Estaca"
	beco.add_child(body, true)
	body.owner = level
	body.global_position = at
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.06
	cyl.height = 2.0
	shape.shape = cyl
	body.add_child(shape)
	shape.owner = level


func _examine(node_name: String, at: Vector3, prompt: String, text: String) -> void:
	var node := Node3D.new()
	node.name = node_name
	beco.add_child(node)
	node.owner = level
	node.set_script(load("res://world/interactable.gd"))
	node.set("action", 0)  # READ
	node.set("prompt_text", prompt)
	node.set("text", text)
	node.global_position = at


## A parede do fundo (2 pedaços de muro de 2 m) deixava dois vãos para o campo, um de cada lado: fecha com pedaços
## mais curtos do mesmo muro.
func _close_back(corner: Node3D) -> void:
	var wall := "res://assets/kits/quaternius/vila/Wall_UnevenBrick_Straight.gltf"
	for spec: Array in [["MuroVaoSul", -60.0, 0.56], ["MuroVaoNorte", -55.24, 0.2]]:
		var node := _scene(String(spec[0]), wall, Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3(float(spec[2]), 1.0, 1.0)),
			Vector3(-12.7, 0.0, float(spec[1]))))
		node.add_to_group("colisao_auto", true)


## As pedrinhas da roda da fogueira eram seixos brancos achatados (de perto pareciam pétalas): a roda nova, de pedra
## escura suja de fuligem, vem junto com a cinza (cinzas.gltf).
func _hide_old_stones(fire: Node3D) -> void:
	for child: Node in fire.get_children():
		if String(child.name).begins_with("Pedra"):
			(child as Node3D).visible = false


# --- chão e paredes ------------------------------------------------------------------------------------

## Terra batida com palha por cima do chão pintado (some aos poucos na boca do beco).
func _ground() -> void:
	var space := level.get_world_3d().direct_space_state
	var top := 0.0
	for k: int in 6:
		var p := FUNDO + Vector3(0.6 + k * 1.1, 3.0, LARGURA / 2.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 6.0, 1))
		if not hit.is_empty():
			top = maxf(top, (hit["position"] as Vector3).y)
	var plane := PlaneMesh.new()
	plane.size = Vector2(COMPRIMENTO, LARGURA)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(BECO + "tex/chao.png")
	mat.roughness_texture = load(BECO + "tex/chao_rugosidade.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	plane.material = mat
	var ground := MeshInstance3D.new()
	ground.name = "Chao"
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beco.add_child(ground)
	ground.owner = level
	ground.global_position = FUNDO + Vector3(COMPRIMENTO / 2.0, top + 0.012, LARGURA / 2.0)


## Decal na parede: normal = para fora da parede; size = (largura, altura).
func _decal(node_name: String, tex: String, at: Vector3, normal: Vector3, size: Vector2) -> void:
	var decal := Decal.new()
	decal.name = node_name
	beco.add_child(decal)
	decal.owner = level
	var y := normal.normalized()
	var z := Vector3.DOWN
	var x := y.cross(z).normalized()
	decal.global_transform = Transform3D(Basis(x, y, z), at)
	decal.size = Vector3(size.x, 0.5, size.y)
	decal.texture_albedo = load(BECO + "tex/" + tex)
	decal.cull_mask = 1


## A grama (MultiMesh) que tinha nascido dentro do beco some: o beco é de terra batida.
func _clear_grass() -> void:
	var rect := Rect2(FUNDO.x - 0.5, FUNDO.z, COMPRIMENTO + 0.3, LARGURA)
	var removed := 0
	var to_save: Array[MultiMesh] = []
	for holder: String in ["Grama", "Gardens"]:
		var group := level.get_node_or_null(holder)
		if group == null:
			continue
		for child: Node in group.get_children():
			var mmi := child as MultiMeshInstance3D
			if mmi == null or mmi.multimesh == null:
				continue
			var mm := mmi.multimesh
			var changed := false
			# mexe direto no buffer (set_instance_transform não chega no arquivo salvo): 12 números por tufo (a
			# base 3x3 e a posição, linha a linha), mais 4 de cor e 4 de dado extra quando a malha usa
			var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var buf := mm.buffer
			for i: int in mm.instance_count:
				var t := mmi.global_transform * mm.get_instance_transform(i)
				if rect.has_point(Vector2(t.origin.x, t.origin.z)) and t.basis.get_scale().length() > 0.001:
					for k: int in [0, 1, 2, 4, 5, 6, 8, 9, 10]:
						buf[i * stride + k] *= 0.0001
					changed = true
					removed += 1
			if changed:
				mm.buffer = buf
				if mm.resource_path != "":
					to_save.append(mm)
	# o buffer passa pelo servidor de desenho: salvar no mesmo quadro grava o buffer antigo
	for i: int in 4:
		await process_frame
	for mm: MultiMesh in to_save:
		print("grama: ", mm.resource_path, " salva ", ResourceSaver.save(mm, mm.resource_path))
	print("grama tirada do beco: ", removed)
