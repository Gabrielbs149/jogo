extends SceneTree
## Veste a arena de Ethera (D036) com o mesmo visual das Ruínas de Ethera (D035): é o coração das ruínas, onde
## o grupo luta. Chão pintado (lajes no meio, terra batida em volta, areia), anel de muros partidos e colunas atrás
## dos inimigos, altar do selo, braseiros acesos, rochas e árvores secas no horizonte, capim seco.
## Mantém o que é de jogo (posições, câmera, HUD, efeitos). Rodar de novo APAGA o que foi ajustado à mão no "Cenario".
## Uso (COM janela: o capim é MultiMesh e precisa salvar posições): godot --path . -s tools/art/montar_arena_ethera.gd

const PROPS := "res://world/props/"
const KIT := "res://assets/kits/quaternius/"
const ARENA := "res://levels/arenas/ethera_arena.tscn"
const ART := "res://levels/arenas/art/"
const AREA := 80.0
const MASK_PX := 512
## A luta acontece entre z = -4 e z = 5 (jogador no sul, inimigos no norte); a câmera fica no sudeste.
const FIGHT := Vector2(0.0, 0.0)

var arena: Node3D
var rng := RandomNumberGenerator.new()
var mask: Image
var _tinted := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 2036
	arena = (ResourceLoader.load(ARENA, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(arena)
	for name: String in ["Ruins", "Cenario"]:
		var old := arena.get_node_or_null(name)
		if old:
			arena.remove_child(old)
			old.free()
	var set := Node3D.new()
	set.name = "Cenario"
	arena.add_child(set)
	set.owner = arena
	arena.move_child(set, arena.get_node("GroundBody").get_index() + 1)
	mask = Image.create(MASK_PX, MASK_PX, false, Image.FORMAT_RGB8)
	mask.fill(Color(0, 0, 0))
	_floor()
	_ruins(set)
	_horizon(set)
	_ground()
	_grass(set)
	var packed := PackedScene.new()
	print("pack ", packed.pack(arena), " save ", ResourceSaver.save(packed, ARENA))
	quit()


# --- ajudas -----------------------------------------------------------------------------------------

func _place(key: String, parent: Node, at: Vector3, yaw: float = 0.0, size: float = 1.0, sink: float = 0.0) -> Node3D:
	var piece := (load(PROPS + key + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	parent.add_child(piece, true)
	piece.owner = arena
	piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), Vector3(at.x, -sink, at.z))
	return piece


func _kit(path: String, parent: Node, at: Vector3, basis: Basis, sink: float = 0.0) -> Node3D:
	var piece := (load(KIT + path + ".gltf") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	parent.add_child(piece, true)
	piece.owner = arena
	piece.transform = Transform3D(basis, Vector3(at.x, -sink, at.z))
	return piece


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


func _mask_at(p: Vector3) -> Color:
	var px := clampi(int((p.x / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	var pz := clampi(int((p.z / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	return mask.get_pixel(px, pz)


## Rochas do kit têm musgo verde: no deserto, tinge de ocre (igual a Ethera).
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
		while outer and outer != arena:
			arena.set_editable_instance(outer, true)
			outer = outer.owner


func _stone(parent: Node, name: String, at: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var block := MeshInstance3D.new()
	block.name = name
	var box := BoxMesh.new()
	box.size = size
	block.mesh = box
	block.material_override = load("res://assets/materials/arenito.tres")
	parent.add_child(block, true)
	block.owner = arena
	block.transform = Transform3D(Basis.from_euler(rot), at)


# --- chão ----------------------------------------------------------------------------------------

func _floor() -> void:
	# terra batida onde se luta, lajes antigas por cima (com falhas), trilha que chega do sul
	_paint(FIGHT, 9.5, 0)
	for i: int in 160:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 8.0
		if rng.randf() < 0.8:
			_paint(FIGHT + Vector2(cos(a), sin(a)) * r, rng.randf_range(0.7, 1.6), 1)
	for i: int in 30:
		var t := float(i) / 29.0
		_paint(Vector2(sin(t * 5.0) * 1.2, 9.0 + t * 25.0), 1.4, 0)


func _ground() -> void:
	var soft := mask.duplicate() as Image
	soft.resize(MASK_PX / 3, MASK_PX / 3, Image.INTERPOLATE_LANCZOS)
	soft.resize(MASK_PX, MASK_PX, Image.INTERPOLATE_CUBIC)
	DirAccess.make_dir_recursive_absolute(ART)
	soft.save_png(ART + "ethera_chao_mascara.png")
	ResourceSaver.save(ImageTexture.create_from_image(soft), ART + "ethera_chao_mascara.res")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/chao_pintado.gdshader")
	var vila := KIT + "vila/"
	mat.set_shader_parameter("mask", load(ART + "ethera_chao_mascara.res"))
	mat.set_shader_parameter("area_size", Vector2(AREA, AREA))
	mat.set_shader_parameter("noise", load(vila + "T_Noise_Terrain.png"))
	mat.set_shader_parameter("cobble_albedo", load(vila + "T_UnevenBrick_BaseColor.png"))
	mat.set_shader_parameter("cobble_normal", load(vila + "T_UnevenBrick_Normal.png"))
	mat.set_shader_parameter("cobble_meters", 2.6)
	mat.set_shader_parameter("cobble_tint", Color(1.0, 0.82, 0.66))
	mat.set_shader_parameter("grass_light", Color(0.86, 0.6, 0.42))
	mat.set_shader_parameter("grass_dark", Color(0.7, 0.44, 0.3))
	mat.set_shader_parameter("grass_dry", Color(0.9, 0.7, 0.5))
	mat.set_shader_parameter("dirt_light", Color(0.62, 0.38, 0.26))
	mat.set_shader_parameter("dirt_dark", Color(0.45, 0.26, 0.18))
	mat.set_shader_parameter("pebble_color", Color(0.75, 0.6, 0.5))
	var ground := arena.get_node("Ground") as MeshInstance3D
	var plane := PlaneMesh.new()
	plane.size = Vector2(AREA, AREA)
	ground.mesh = plane
	ground.material_override = mat


# --- ruínas: o coração de Ethera --------------------------------------------------------------------

func _ruins(set: Node3D) -> void:
	# anel de muros partidos do lado norte (atrás dos inimigos), aberto no sul para a câmera e a trilha
	var count := 16
	for i: int in count:
		var a := TAU * i / count + rng.randf_range(-0.06, 0.06)
		var at := Vector3(cos(a) * 13.0, 0, sin(a) * 13.0 - 2.0)
		if at.z > 3.0 or i in [6, 13]:
			continue
		var face := Basis(Vector3.UP, -a - PI / 2.0)  # lado de tijolo virado para a luta
		var roll := rng.randf()
		if roll < 0.45:
			_kit("vila/Wall_UnevenBrick_Straight", set, at, face.scaled(Vector3(1, rng.randf_range(0.5, 1.0), 1)), 0.1)
		elif roll < 0.7:
			_kit("vila/Wall_UnevenBrick_Window_Wide_Round", set, at, face.scaled(Vector3(1, rng.randf_range(0.75, 1.0), 1)), 0.15)
		elif roll < 0.85:
			_kit("vila/Wall_UnevenBrick_Straight", set, at, face * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(75, 88))), 0.25)
		else:
			_kit("vila/Wall_UnevenBrick_Door_Round", set, at, face.scaled(Vector3(1, 0.85, 1)), 0.1)
		for k: int in rng.randi_range(1, 3):
			var rub := at + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
			_kit("vila/Prop_Brick%d" % rng.randi_range(1, 4), set, rub, Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), 0.05)
	# colunas em semicírculo atrás da luta (algumas quebradas, uma caída) e as pontas do sul
	for spec: Array in [[Vector3(-9.5, 0, -6.5), 1.0, false], [Vector3(-5.5, 0, -10), 0.6, false], [Vector3(5.5, 0, -10.5), 1.0, false],
			[Vector3(9.5, 0, -6), 0.45, false], [Vector3(-11, 0, 1.5), 0.75, false], [Vector3(11.5, 0, 0.5), 1.0, true]]:
		var col := _place("pilar", set, spec[0], rng.randf() * TAU, 1.0)
		col.scale = Vector3(1, spec[1], 1)
		if spec[2]:
			col.rotate_object_local(Vector3.FORWARD, deg_to_rad(86))
			col.position.y += 0.5
	# altar do selo partido ao norte: degrau, laje rachada em dois, pedaço caído
	_stone(set, "Degrau", Vector3(0, 0.15, -9.0), Vector3(5.6, 0.3, 3.2))
	_stone(set, "AltarEsq", Vector3(-1.05, 0.62, -9.0), Vector3(1.9, 0.65, 1.9), Vector3(0, 0.04, -0.05))
	_stone(set, "AltarDir", Vector3(1.1, 0.55, -9.05), Vector3(1.9, 0.5, 1.9), Vector3(0, -0.06, 0.12))
	_stone(set, "Lasca", Vector3(2.7, 0.35, -7.4), Vector3(0.9, 0.4, 0.7), Vector3(0.2, 0.7, 0.3))
	_place("inscricao", set, Vector3(0, 0, -10.9), 0.0, 1.0)
	# braseiros acesos dos dois lados do altar (luz quente e estalo do fogo)
	for x: float in [-4.2, 4.2]:
		_stone(set, "Pedestal", Vector3(x, 0.45, -7.6), Vector3(0.8, 0.9, 0.8))
		var fire := (load("res://assets/vfx/fogo.tscn") as PackedScene).instantiate() as Node3D
		set.add_child(fire, true)
		fire.owner = arena
		fire.transform = Transform3D(Basis().scaled(Vector3.ONE * 0.45), Vector3(x, 0.92, -7.6))
	# estandartes rasgados na entrada sul (fora do caminho da câmera)
	_place("estandarte", set, Vector3(-6.5, 0, 6.5), 0.3, 1.0)
	_place("estandarte", set, Vector3(-9.0, 0, 4.0), 0.6, 1.0)
	# entulho e vasos quebrados em volta, longe do meio da luta
	for i: int in 34:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.5, 15.0)
		var at := Vector3(cos(a) * r, 0, sin(a) * r - 1.0)
		if at.z > 5.0 and at.x > -2.0:
			continue  # linha da câmera
		var roll := rng.randf()
		if roll < 0.45:
			_kit("vila/Prop_Brick%d" % rng.randi_range(1, 4), set, at, Basis(Vector3.UP, rng.randf() * TAU), 0.05)
		elif roll < 0.65:
			_kit("objetos/Vase_Rubble_Medium", set, at, Basis(Vector3.UP, rng.randf() * TAU))
		else:
			_desert_tint(_place(["pedregulhos", "pedras", "pedrinhas"][rng.randi() % 3], set, at, rng.randf() * TAU, rng.randf_range(0.8, 1.3)))


func _horizon(set: Node3D) -> void:
	# penhascos e rochas grandes fechando o horizonte; árvores secas entre eles
	var placed: Array[Vector3] = []
	for i: int in 400:
		var a := rng.randf() * TAU
		var r := rng.randf_range(17.0, 34.0)
		var at := Vector3(cos(a) * r, 0, sin(a) * r)
		if at.z > 8.0 and at.x > -4.0 and at.x < 18.0 and r < 26.0:
			continue
		var near := false
		for o: Vector3 in placed:
			if o.distance_to(at) < 4.5:
				near = true
				break
		if near:
			continue
		placed.append(at)
		var roll := rng.randf()
		if roll < 0.5:
			_desert_tint(_place(["penhasco", "rocha_grande"][rng.randi() % 2], set, at, rng.randf() * TAU, rng.randf_range(1.0, 1.7), 0.6))
		elif roll < 0.72:
			_place(["arvore_morta", "tronco_seco"][rng.randi() % 2], set, at, rng.randf() * TAU, rng.randf_range(0.8, 1.2), 0.1)
		else:
			_desert_tint(_place(["rocha", "pedregulhos"][rng.randi() % 2], set, at, rng.randf() * TAU, rng.randf_range(1.0, 1.6), 0.2))
		if placed.size() > 46:
			break


# --- capim seco ----------------------------------------------------------------------------------

func _grass(set: Node3D) -> void:
	var mesh: Mesh = load(KIT + "natureza/malhas/Grass_Wispy_Short.res")
	var dry := (mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as StandardMaterial3D
	dry.albedo_color = Color(1.0, 0.78, 0.5)
	var list: Array[Transform3D] = []
	var x := -30.0
	while x < 30.0:
		var z := -26.0
		while z < 30.0:
			var p := Vector3(x + rng.randf_range(-0.6, 0.6), 0, z + rng.randf_range(-0.6, 0.6))
			z += 1.2
			var m := _mask_at(p)
			var keep := 0.65 * (1.0 - clampf(m.g * 2.5, 0.0, 1.0)) * (1.0 - m.r * 0.85)
			if rng.randf() > keep:
				continue
			list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.35, 0.65)), p))
		x += 1.2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for k: int in list.size():
		mm.set_instance_transform(k, list[k])
	ResourceSaver.save(mm, ART + "ethera_capim.res")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Capim"
	mmi.multimesh = load(ART + "ethera_capim.res")
	mmi.material_override = dry
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set.add_child(mmi)
	mmi.owner = arena
	print("capim: ", list.size())
