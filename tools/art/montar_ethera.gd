extends SceneTree
## Veste as Ruínas de Ethera (D035) no nível de Arandu: chão pintado de areia (trilha batida e piso das ruínas),
## ruínas de verdade em volta do altar (muros partidos, arco caído, colunas, entulho), vegetação seca e capim.
## Mantém o que é de jogo: acampamento/fogueira, heróis esperando, grupos de inimigos, pilares com inscrição e altar.
## Rodar de novo APAGA o que foi ajustado à mão na decoração (grupos Trees, Rocks, Ruinas, Grama).
## Uso (COM janela: o capim é MultiMesh e precisa salvar posições): godot --path . -s tools/art/montar_ethera.gd

const PROPS := "res://world/props/"
const KIT := "res://assets/kits/quaternius/"
const LEVEL := "res://levels/ethera/ethera.tscn"
const ART := "res://levels/ethera/art/"
const AREA := 200.0
const MASK_PX := 1024
const PLAZA := Vector2(0.5, 0.0)  # centro das ruínas (o altar)
const CAMP := Vector2(1.0, 34.0)

var level: Node3D
var rng := RandomNumberGenerator.new()
var mask: Image
var blocks: Array[Rect2] = []
var groups := {}
var space: PhysicsDirectSpaceState3D
var _tinted := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 2035
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	for i: int in 3:
		await physics_frame
	space = level.get_world_3d().direct_space_state
	_clear()
	_keep_story_spots()
	mask = Image.create(MASK_PX, MASK_PX, false, Image.FORMAT_RGB8)
	mask.fill(Color(0, 0, 0))
	_paths()
	_ruins()
	_edges()
	_ground()
	level.call("_auto_collision")
	await physics_frame
	_grass()
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


# --- ajudas -----------------------------------------------------------------------------------------

func _group(name: String, nav: bool = true) -> Node3D:
	if groups.has(name):
		return groups[name]
	var found := level.get_node_or_null(name) as Node3D
	if found == null:
		found = Node3D.new()
		found.name = name
		level.add_child(found)
		found.owner = level
		if nav:
			found.add_to_group("nav_source", true)
	groups[name] = found
	return found


func _clear() -> void:
	for name: String in ["Trees", "Rocks", "Ruinas", "Grama"]:
		var node := level.get_node_or_null(name)
		if node:
			level.remove_child(node)
			node.free()


## Onde há coisa de jogo, nada de árvore/rocha em cima.
func _keep_story_spots() -> void:
	for path: String in ["Camp", "HeroSpots", "Encounters", "Ruins", "PlayerSpawn"]:
		var node := level.get_node_or_null(path) as Node3D
		if node == null:
			continue
		var spots: Array[Node] = [node]
		spots.append_array(node.find_children("*", "Node3D", true, false))
		for n: Node in spots:
			var p := (n as Node3D).global_position
			blocks.append(Rect2(p.x - 2.2, p.z - 2.2, 4.4, 4.4))


func _ground_y(x: float, z: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -30, z), 1))
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0


func _free_at(p: Vector3, margin: float = 0.0) -> bool:
	for r: Rect2 in blocks:
		if p.x > r.position.x - margin and p.x < r.end.x + margin and p.z > r.position.y - margin and p.z < r.end.y + margin:
			return false
	return true


func _place(key: String, parent: Node, at: Vector3, yaw: float = 0.0, size: float = 1.0, sink: float = 0.0) -> Node3D:
	var piece := (load(PROPS + key + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	parent.add_child(piece, true)
	piece.owner = level
	piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), Vector3(at.x, _ground_y(at.x, at.z) - sink, at.z))
	return piece


func _kit(path: String, parent: Node, at: Vector3, basis: Basis, sink: float = 0.0, collide: bool = true) -> Node3D:
	var piece := (load(KIT + path + ".gltf") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	parent.add_child(piece, true)
	piece.owner = level
	piece.transform = Transform3D(basis, Vector3(at.x, _ground_y(at.x, at.z) - sink, at.z))
	if collide:
		piece.add_to_group("colisao_auto", true)
	return piece


func _mask_at(p: Vector3) -> Color:
	var px := clampi(int((p.x / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	var pz := clampi(int((p.z / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	return mask.get_pixel(px, pz)


func _paint(center: Vector2, radius: float, channel: int) -> void:
	var cx := int((center.x / AREA + 0.5) * MASK_PX)
	var cz := int((center.y / AREA + 0.5) * MASK_PX)
	var rp := int(radius / AREA * MASK_PX) + 1
	for x: int in range(maxi(cx - rp, 0), mini(cx + rp + 1, MASK_PX)):
		for z: int in range(maxi(cz - rp, 0), mini(cz + rp + 1, MASK_PX)):
			var w := Vector2((float(x) / MASK_PX - 0.5) * AREA, (float(z) / MASK_PX - 0.5) * AREA)
			if w.distance_to(center) <= radius:
				var c := mask.get_pixel(x, z)
				c[channel] = 1.0
				mask.set_pixel(x, z, c)


## Trilha batida (terra) entre dois pontos, um pouco sinuosa.
func _trail(a: Vector2, b: Vector2, width: float) -> void:
	var steps := int(a.distance_to(b) / 0.5)
	var side := (b - a).orthogonal().normalized()
	for i: int in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t) + side * sin(t * PI * 2.2) * 2.2
		_paint(p, width * (0.85 + 0.3 * sin(t * 17.0)), 0)


# --- caminhos e piso -------------------------------------------------------------------------------

func _paths() -> void:
	_paint(CAMP, 6.5, 0)  # chão batido do acampamento
	_trail(CAMP + Vector2(0, -4), PLAZA + Vector2(0, 11), 1.6)  # acampamento → ruínas
	for side: float in [-1.0, 1.0]:
		_trail(PLAZA + Vector2(side * 10, 2), PLAZA + Vector2(side * 24, -14), 1.1)  # trilhas laterais para os grupos
	# piso das ruínas: lajes de pedra em volta do altar, com falhas
	for i: int in 260:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 10.5
		var p := PLAZA + Vector2(cos(a), sin(a)) * r
		if rng.randf() < 0.85:
			_paint(p, rng.randf_range(0.8, 1.8), 1)
	_paint(PLAZA, 12.5, 0)


# --- ruínas --------------------------------------------------------------------------------------

func _ruins() -> void:
	var ruins := _group("Ruinas")
	# anel de muros partidos em volta do altar, com vãos e pedaços caídos
	var count := 14
	for i: int in count:
		var a := TAU * i / count + rng.randf_range(-0.08, 0.08)
		if i in [3, 4, 10]:
			continue  # vãos: entradas para a praça (sul é a trilha do acampamento)
		var at := Vector3(PLAZA.x + cos(a) * 13.0, 0, PLAZA.y + sin(a) * 13.0)
		var face := Basis(Vector3.UP, -a + PI / 2.0)
		var roll := rng.randf()
		if roll < 0.45:
			_kit("vila/Wall_UnevenBrick_Straight", ruins, at, face.scaled(Vector3(1, rng.randf_range(0.45, 0.95), 1)), 0.1)
		elif roll < 0.65:
			_kit("vila/Wall_UnevenBrick_Window_Wide_Round", ruins, at, face.scaled(Vector3(1, rng.randf_range(0.7, 1.0), 1)), 0.15)
		elif roll < 0.85:
			# muro caído: deitado e meio enterrado
			_kit("vila/Wall_UnevenBrick_Straight", ruins, at, face * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(75, 88))), 0.25)
		else:
			_kit("vila/Wall_UnevenBrick_Door_Round", ruins, at, face.scaled(Vector3(1, 0.8, 1)), 0.1)
		blocks.append(Rect2(at.x - 1.5, at.z - 1.5, 3, 3))
		for k: int in rng.randi_range(1, 3):
			var rub := at + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
			_kit("vila/Prop_Brick%d" % rng.randi_range(1, 4), ruins, rub, Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), 0.05, false)
	# portal da entrada sul: duas colunas e uma verga de pedra (uma ponta caída); do outro lado, a verga no chão
	for x: float in [-2.6, 2.6]:
		_place("pilar", ruins, Vector3(PLAZA.x + x, 0, PLAZA.y + 13.2), 0.0, 1.0)
	_stone_beam(ruins, Vector3(PLAZA.x, 4.5, PLAZA.y + 13.2), Vector3(6.6, 0.7, 1.2), Vector3(0, 0, deg_to_rad(4)))
	_stone_beam(ruins, Vector3(PLAZA.x - 3.0, 0.3, PLAZA.y - 14.5), Vector3(5.5, 0.7, 1.1), Vector3(0, 0.5, deg_to_rad(8)), true)
	# colunas soltas pela praça (algumas quebradas, uma deitada)
	for spec: Array in [[Vector3(-8, 0, -4), 1.0, false], [Vector3(8.5, 0, -3), 0.55, false], [Vector3(-6, 0, -9), 0.7, false],
			[Vector3(9, 0, 6.5), 1.0, true], [Vector3(-9.5, 0, 3.5), 0.4, false]]:
		var col := _place("pilar", ruins, spec[0], rng.randf() * TAU, 1.0)
		col.scale = Vector3(1, spec[1], 1)
		if spec[2]:
			col.rotate_object_local(Vector3.FORWARD, deg_to_rad(86))
			col.position.y += 0.5
		blocks.append(Rect2(spec[0].x - 1.2, spec[0].z - 1.2, 2.4, 2.4))
	# entulho e restos da cidade
	for i: int in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, 15.0)
		var at := Vector3(PLAZA.x + cos(a) * r, 0, PLAZA.y + sin(a) * r)
		if not _free_at(at, 0.4):
			continue
		var roll := rng.randf()
		if roll < 0.45:
			_kit("vila/Prop_Brick%d" % rng.randi_range(1, 4), ruins, at, Basis(Vector3.UP, rng.randf() * TAU), 0.05, false)
		elif roll < 0.65:
			_kit("objetos/Vase_Rubble_Medium", ruins, at, Basis(Vector3.UP, rng.randf() * TAU), 0.0, false)
		elif roll < 0.85:
			_place(["pedregulhos", "pedras", "pedrinhas"][rng.randi() % 3], ruins, at, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		else:
			_kit("objetos/Vase_2", ruins, at, Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.FORWARD, 1.4), 0.1, false)
	# estandartes rasgados nas entradas
	for at: Vector3 in [Vector3(PLAZA.x - 3.4, 0, PLAZA.y + 12.5), Vector3(PLAZA.x + 3.4, 0, PLAZA.y + 12.5)]:
		_place("estandarte", ruins, at, 0.0, 1.0)


func _stone_beam(parent: Node, at: Vector3, size: Vector3, rot: Vector3, on_ground: bool = false) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "Verga"
	var box := BoxMesh.new()
	box.size = size
	beam.mesh = box
	beam.material_override = load("res://assets/materials/arenito.tres")
	parent.add_child(beam, true)
	beam.owner = level
	var y := (_ground_y(at.x, at.z) + size.y * 0.4) if on_ground else at.y
	beam.transform = Transform3D(Basis.from_euler(rot), Vector3(at.x, y, at.z))
	beam.add_to_group("colisao_auto", true)


## Rochas do kit têm musgo verde: no deserto, tinge de ocre (a peça vira "editável" para a cor ir pro arquivo).
func _desert_tint(piece: Node3D) -> void:
	for found: Node in piece.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		var mat := mi.get_active_material(0) as BaseMaterial3D
		if mat == null:
			continue
		if not _tinted.has(mat):
			var copy := mat.duplicate() as BaseMaterial3D
			copy.albedo_color = Color(1.0, 0.72, 0.56)
			_tinted[mat] = copy
		mi.material_override = _tinted[mat]
		var outer := mi.owner
		while outer and outer != level:
			level.set_editable_instance(outer, true)
			outer = outer.owner


# --- bordas: penhascos, rochas, árvores secas -----------------------------------------------------

func _edges() -> void:
	var trees := _group("Trees")
	var rocks := _group("Rocks")
	var placed: Array[Vector3] = []
	for i: int in 900:
		var at := Vector3(rng.randf_range(-40.0, 40.0), 0, rng.randf_range(-32.0, 52.0))
		if not _free_at(at, 1.0) or _mask_at(at).g > 0.3 or _mask_at(at).r > 0.4:
			continue
		var near := false
		for o: Vector3 in placed:
			if Vector2(o.x, o.z).distance_to(Vector2(at.x, at.z)) < 3.2:
				near = true
				break
		if near:
			continue
		var edge := absf(at.x) > 25.0 or at.z < -22.0 or at.z > 44.0
		var plaza := Vector2(at.x, at.z).distance_to(PLAZA) < 17.0
		placed.append(at)
		var roll := rng.randf()
		if edge and roll < 0.35:
			_desert_tint(_place(["penhasco", "rocha_grande"][rng.randi() % 2], rocks, at, rng.randf() * TAU, rng.randf_range(0.8, 1.4), 0.6))
		elif roll < 0.25 and not plaza:
			_place(["arvore_morta", "tronco_seco", "arvore_torta"][rng.randi() % 3], trees, at, rng.randf() * TAU, rng.randf_range(0.7, 1.15), 0.1)
		elif roll < 0.55:
			_desert_tint(_place(["rocha", "pedregulhos", "pedras"][rng.randi() % 3], rocks, at, rng.randf() * TAU, rng.randf_range(0.7, 1.3), 0.15))
		elif roll < 0.75:
			_place("arbusto", trees, at, rng.randf() * TAU, rng.randf_range(0.6, 1.0))
		if placed.size() > 140:
			break
	print("bordas: ", placed.size())


# --- chão ---------------------------------------------------------------------------------------

func _ground() -> void:
	var soft := mask.duplicate() as Image
	soft.resize(MASK_PX / 3, MASK_PX / 3, Image.INTERPOLATE_LANCZOS)
	soft.resize(MASK_PX, MASK_PX, Image.INTERPOLATE_CUBIC)
	DirAccess.make_dir_recursive_absolute(ART)
	soft.save_png(ART + "chao_mascara.png")
	ResourceSaver.save(ImageTexture.create_from_image(soft), ART + "chao_mascara.res")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/chao_pintado.gdshader")
	var vila := KIT + "vila/"
	mat.set_shader_parameter("mask", load(ART + "chao_mascara.res"))
	mat.set_shader_parameter("area_size", Vector2(AREA, AREA))
	mat.set_shader_parameter("noise", load(vila + "T_Noise_Terrain.png"))
	mat.set_shader_parameter("cobble_albedo", load(vila + "T_UnevenBrick_BaseColor.png"))
	mat.set_shader_parameter("cobble_normal", load(vila + "T_UnevenBrick_Normal.png"))
	mat.set_shader_parameter("cobble_meters", 2.6)
	mat.set_shader_parameter("cobble_tint", Color(1.0, 0.82, 0.66))
	# areia no lugar da grama, terra batida avermelhada nas trilhas
	mat.set_shader_parameter("grass_light", Color(0.86, 0.6, 0.42))
	mat.set_shader_parameter("grass_dark", Color(0.7, 0.44, 0.3))
	mat.set_shader_parameter("grass_dry", Color(0.9, 0.7, 0.5))
	mat.set_shader_parameter("dirt_light", Color(0.62, 0.38, 0.26))
	mat.set_shader_parameter("dirt_dark", Color(0.45, 0.26, 0.18))
	mat.set_shader_parameter("pebble_color", Color(0.75, 0.6, 0.5))
	(level.get_node("Terrain") as MeshInstance3D).material_override = mat
	level.set("mapa_do_piso", load(ART + "chao_mascara.res"))
	level.set("area_do_mapa", AREA)
	level.set("piso", "areia")


# --- capim seco ----------------------------------------------------------------------------------

func _grass_mesh(name: String) -> Mesh:
	var path := KIT + "natureza/malhas/" + name + ".res"
	if ResourceLoader.exists(path):
		return load(path)
	var scene := (load(KIT + "natureza/" + name + ".gltf") as PackedScene).instantiate()
	var mesh: Mesh = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	DirAccess.make_dir_recursive_absolute(KIT + "natureza/malhas")
	ResourceSaver.save(mesh, path)
	return load(path)


func _grass() -> void:
	var dry := StandardMaterial3D.new()
	var src := _grass_mesh("Grass_Wispy_Short").surface_get_material(0) as BaseMaterial3D
	if src:
		dry = src.duplicate() as StandardMaterial3D
	dry.albedo_color = Color(1.0, 0.78, 0.5)
	var kinds := {"Grass_Wispy_Short": [0.35, 0.65], "Grass_Wispy_Tall": [0.3, 0.55]}
	var weights := {"Grass_Wispy_Short": 0.7, "Grass_Wispy_Tall": 0.3}
	var chunks := {}
	var count := 0
	var x := -60.0
	while x < 60.0:
		var z := -40.0
		while z < 60.0:
			var p := Vector3(x + rng.randf_range(-0.8, 0.8), 0, z + rng.randf_range(-0.8, 0.8))
			z += 1.35
			var m := _mask_at(p)
			var keep := 0.7 * (1.0 - clampf(m.g * 2.5, 0.0, 1.0)) * (1.0 - m.r * 0.8)
			if rng.randf() > keep or not _free_at(p, -1.2):
				continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 40.0, p + Vector3.DOWN * 30.0, 1 | 4))
			if hit.is_empty() or (hit["collider"] as Node).get_parent() != level.get_node("Terrain"):
				continue  # só na areia (não em cima de pedra/muro)
			var kind := "Grass_Wispy_Short"
			var r := rng.randf()
			for k: String in weights:
				r -= float(weights[k])
				if r <= 0.0:
					kind = k
					break
			var s: Array = kinds[kind]
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(s[0], s[1])), hit["position"])
			var key := "%s|%d|%d" % [kind, floori(p.x / 30.0), floori(p.z / 30.0)]
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(t)
			count += 1
		x += 1.35
	var holder := _group("Grama", false)
	DirAccess.make_dir_recursive_absolute(ART + "grama")
	for f: String in DirAccess.get_files_at(ART + "grama"):
		DirAccess.remove_absolute(ART + "grama/" + f)
	var i := 0
	for key: String in chunks:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _grass_mesh(key.split("|")[0])
		var list: Array = chunks[key]
		mm.instance_count = list.size()
		for k: int in list.size():
			mm.set_instance_transform(k, list[k])
		var path := ART + "grama/g%03d.res" % i
		ResourceSaver.save(mm, path)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "G%03d" % i
		mmi.multimesh = load(path)
		mmi.material_override = dry
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 70.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		holder.add_child(mmi)
		mmi.owner = level
		i += 1
	print("capim: ", count, " tufos em ", i, " pedaços")
