extends SceneTree
## Monta o fundo 3D dos menus (D038) em ui/menu_fundo/fundo_menu.tscn: chão pintado de Ethera, fogueira acesa,
## Tico sentado e Namfoodle de pé junto ao fogo, colunas e muros partidos, penhascos e capim seco.
## Rodar de novo APAGA ajustes à mão. Uso (COM janela, por causa do capim): godot --path . -s tools/art/montar_fundo_menu.gd

const PROPS := "res://world/props/"
const KIT := "res://assets/kits/quaternius/"
const OUT := "res://ui/menu_fundo/fundo_menu.tscn"
const FIRE := Vector3(1.6, 0, -2.2)

var scene: Node3D
var rng := RandomNumberGenerator.new()
var _tinted := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 2038
	scene = Node3D.new()
	scene.name = "FundoMenu"
	root.add_child(scene)
	_sky()
	_ground()
	_camp()
	_ruins()
	_horizon()
	_grass()
	_cameras()
	scene.set_script(load("res://ui/menu_fundo/fundo_menu.gd"))
	var packed := PackedScene.new()
	print("pack ", packed.pack(scene), " save ", ResourceSaver.save(packed, OUT))
	quit()


func _own(node: Node) -> Node:
	scene.add_child(node, true)
	node.owner = scene
	return node


func _place(key: String, at: Vector3, yaw: float = 0.0, size: float = 1.0, sink: float = 0.0) -> Node3D:
	var piece := (load(PROPS + key + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	_own(piece)
	piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), at - Vector3(0, sink, 0))
	return piece


func _kit(path: String, at: Vector3, basis: Basis, sink: float = 0.0) -> Node3D:
	var piece := (load(KIT + path + ".gltf") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	_own(piece)
	piece.transform = Transform3D(basis, at - Vector3(0, sink, 0))
	return piece


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
		while outer and outer != scene:
			scene.set_editable_instance(outer, true)
			outer = outer.owner


func _facing(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _sky() -> void:
	var env := WorldEnvironment.new()
	env.name = "Ceu"
	env.environment = load("res://assets/environment/fire_sky.tres")
	_own(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sol"
	sun.light_color = Color(1, 0.66, 0.45)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_own(sun)
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(-140), 0)), Vector3(0, 20, 0))


func _ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Chao"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	# mesmo chão pintado da arena de Ethera (lajes no meio, terra batida, areia)
	var arena := (load("res://levels/arenas/ethera_arena.tscn") as PackedScene).instantiate()
	ground.material_override = (arena.get_node("Ground") as MeshInstance3D).material_override
	arena.free()
	_own(ground)


func _camp() -> void:
	var fire := _place("fogueira", FIRE)
	fire.name = "Fogueira"
	var palco := Marker3D.new()
	palco.name = "Palco"
	_own(palco)
	var foco := Marker3D.new()
	foco.name = "Foco"
	_own(foco)
	foco.position = FIRE + Vector3(-0.9, 0.85, 0.3)
	var tico := (load("res://actors/tico_lirou/tico_lirou.tscn") as PackedScene).instantiate() as Node3D
	tico.name = "TicoSentado"
	_own(tico)
	var at := FIRE + Vector3(0.95, 0, 0.55)
	tico.transform = Transform3D(Basis(Vector3.UP, _facing(at, FIRE)), at)
	tico.set_meta("animacao", "Sit_Floor_Idle")
	var naum := (load("res://actors/naumfode/naumfode.tscn") as PackedScene).instantiate() as Node3D
	naum.name = "Namfoodle"
	_own(naum)
	at = FIRE + Vector3(-0.85, 0, -0.75)
	naum.transform = Transform3D(Basis(Vector3.UP, _facing(at, FIRE)), at)
	naum.set_meta("animacao", "Parado")
	_place("barril", FIRE + Vector3(2.0, 0, -0.9), 0.0, 0.8)
	_place("estandarte", Vector3(-2.6, 0, -3.6), 0.4, 1.0)


func _ruins() -> void:
	for spec: Array in [[Vector3(-3.6, 0, -5.0), 1.0, false], [Vector3(0.6, 0, -6.6), 0.55, false], [Vector3(5.8, 0, -5.2), 1.0, false],
			[Vector3(-6.2, 0, -1.4), 0.7, false], [Vector3(6.8, 0, -3.4), 1.0, true]]:
		var col := _place("pilar", spec[0], rng.randf() * TAU, 1.0)
		col.scale = Vector3(1, spec[1], 1)
		if spec[2]:
			col.rotate_object_local(Vector3.FORWARD, deg_to_rad(86))
			col.position.y += 0.5
	for x: float in [-7.5, -3.5, 4.0, 8.0]:
		var face := Basis(Vector3.UP, PI + rng.randf_range(-0.15, 0.15))
		var piece := "vila/Wall_UnevenBrick_Window_Wide_Round" if x == 4.0 else "vila/Wall_UnevenBrick_Straight"
		_kit(piece, Vector3(x, 0, -9.5 + rng.randf_range(-0.6, 0.6)), face.scaled(Vector3(1, rng.randf_range(0.55, 1.0), 1)), 0.1)
	for i: int in 16:
		var at := Vector3(rng.randf_range(-8, 9), 0, rng.randf_range(-9, 3))
		if at.distance_to(FIRE) < 2.4 or (at.z > -4.0 and at.x > -4.5):
			continue  # nada entre a câmera e a fogueira
		if rng.randf() < 0.6:
			_kit("vila/Prop_Brick%d" % rng.randi_range(1, 4), at, Basis(Vector3.UP, rng.randf() * TAU), 0.05)
		else:
			_desert_tint(_place(["pedras", "pedrinhas"][rng.randi() % 2], at, rng.randf() * TAU, rng.randf_range(0.8, 1.2)))


func _horizon() -> void:
	var placed: Array[Vector3] = []
	for i: int in 300:
		var a := rng.randf_range(-PI, 0.15)  # só atrás e dos lados (as câmeras olham para -Z)
		var r := rng.randf_range(15.0, 32.0)
		var at := Vector3(cos(a) * r, 0, sin(a) * r)
		var near := false
		for o: Vector3 in placed:
			if o.distance_to(at) < 4.5:
				near = true
				break
		if near:
			continue
		placed.append(at)
		if rng.randf() < 0.65:
			_desert_tint(_place(["penhasco", "rocha_grande"][rng.randi() % 2], at, rng.randf() * TAU, rng.randf_range(1.0, 1.7), 0.6))
		else:
			_place(["arvore_morta", "tronco_seco"][rng.randi() % 2], at, rng.randf() * TAU, rng.randf_range(0.8, 1.2), 0.1)
		if placed.size() > 30:
			break


func _grass() -> void:
	var mesh: Mesh = load(KIT + "natureza/malhas/Grass_Wispy_Short.res")
	var dry := (mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as StandardMaterial3D
	dry.albedo_color = Color(1.0, 0.78, 0.5)
	var list: Array[Transform3D] = []
	for i: int in 900:
		var p := Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(-20, 8))
		if Vector2(p.x, p.z).length() < 7.5 or p.distance_to(FIRE) < 2.0:
			continue
		list.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.35, 0.7)), p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for k: int in list.size():
		mm.set_instance_transform(k, list[k])
	ResourceSaver.save(mm, "res://ui/menu_fundo/capim.res")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Capim"
	mmi.multimesh = load("res://ui/menu_fundo/capim.res")
	mmi.material_override = dry
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(mmi)


func _cameras() -> void:
	var title := Camera3D.new()
	title.name = "CameraTitulo"
	title.fov = 50.0
	_own(title)
	title.look_at_from_position(Vector3(-1.4, 1.25, 2.9), (scene.get_node("Foco") as Node3D).position)
	var pick := Camera3D.new()
	pick.name = "CameraEscolha"
	pick.fov = 38.0
	_own(pick)
	pick.look_at_from_position(Vector3(0, 1.35, 4.0), Vector3(0, 0.85, 0))
