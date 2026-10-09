extends SceneTree
## Arena de rua de Arandu (D060): onde acontecem as brigas na cidade (o padeiro que pega o Tico roubando). Parte da
## arena de Ethera (mesmo jogo: posições, câmera, HUD, efeitos) e troca o cenário: rua de pedra entre duas fileiras
## de casas, a padaria no fundo, barris, sacos de farinha, postes, e os vizinhos em volta torcendo.
## Uso: godot --headless --path . -s tools/art/montar_arena_arandu.gd

const FROM := "res://levels/arenas/ethera_arena.tscn"
const ARENA := "res://levels/arenas/arandu_rua.tscn"
const ARANDU := "res://levels/arandu/arandu.tscn"
const PROPS := "res://world/props/"

var arena: Node3D
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 2060
	(load("res://world/level.gd") as GDScript).set("editing", true)
	var town := (load(ARANDU) as PackedScene).instantiate() as Node3D
	root.add_child(town)
	var town_env := (town.get_node("WorldEnvironment") as WorldEnvironment).environment.duplicate(true) as Environment
	var town_sun := town.get_node("Sun") as DirectionalLight3D
	var ground_mat := (town.get_node("Ground/Dirt") as MeshInstance3D).material_override.duplicate() as ShaderMaterial
	var sun_xform := town_sun.transform
	var sun_color := town_sun.light_color
	var sun_energy := town_sun.light_energy
	town.free()
	arena = (ResourceLoader.load(FROM, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(arena)
	arena.name = "ArenaArandu"
	var old := arena.get_node_or_null("Cenario")
	if old:
		arena.remove_child(old)
		old.free()
	(arena.get_node("WorldEnvironment") as WorldEnvironment).environment = town_env
	var sun := arena.get_node("Sun") as DirectionalLight3D
	sun.transform = sun_xform
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	# chão: o mesmo da cidade, com uma máscara própria (rua de pedra no meio, terra e grama nas beiradas)
	var mask := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y: int in 64:
		for x: int in 64:
			var wx := (x + 0.5) / 64.0 * 60.0 - 30.0
			var c := Color(0, 1, 0) if absf(wx) < 6.2 else (Color(1, 0, 0) if absf(wx) < 7.4 else Color(0, 0, 0))
			mask.set_pixel(x, y, c)
	ground_mat.set_shader_parameter("mask", ImageTexture.create_from_image(mask))
	ground_mat.set_shader_parameter("area_center", Vector2.ZERO)
	ground_mat.set_shader_parameter("area_size", Vector2(60, 60))
	var ground := arena.get_node("Ground") as MeshInstance3D
	ground.material_override = ground_mat
	var set := Node3D.new()
	set.name = "Cenario"
	arena.add_child(set)
	set.owner = arena
	arena.move_child(set, arena.get_node("GroundBody").get_index() + 1)
	_street(set)
	var packed := PackedScene.new()
	print("pack ", packed.pack(arena), " save ", ResourceSaver.save(packed, ARENA))
	quit()


func _place(key: String, parent: Node, at: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	var node := (load(PROPS + key + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	parent.add_child(node, true)
	node.owner = arena
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	return node


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local := (inv * mesh.global_transform) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


## A rua (de norte a sul), com as casas de frente para ela dos dois lados e a padaria no fundo (norte).
func _street(set: Node3D) -> void:
	var houses: Array[String] = ["casa", "casa_estreita", "casa_barro", "casa_enxaimel", "casa_enxaimel2", "casa_pedra", "casa_estreita_pedra"]
	for side: float in [-1.0, 1.0]:
		var z := -15.0
		while z < 16.0:
			var key := houses[rng.randi() % houses.size()]
			# a frente da casa (−Z dela) olha para a rua
			var yaw := PI / 2.0 if side < 0 else -PI / 2.0
			var house := _place(key, set, Vector3.ZERO, yaw)
			var box := _aabb(house)
			var width := box.size.x
			var depth := box.size.z
			house.position = Vector3(side * (6.6 + depth / 2.0), 0, z + width / 2.0)
			z += width + rng.randf_range(0.2, 1.2)
	var bakery := _place("padaria", set, Vector3(0, 0, -21.5), PI)
	bakery.name = "Padaria"
	# coisas da rua: barris, caixotes, sacos de farinha, postes acesos
	var bits: Array[String] = ["barril", "caixote", "sacos", "barris", "cesto", "caixote_macas", "balde"]
	for k: int in 14:
		var side := -1.0 if k % 2 == 0 else 1.0
		_place(bits[rng.randi() % bits.size()], set, Vector3(side * rng.randf_range(5.0, 5.9), 0, rng.randf_range(-13.0, 13.0)), rng.randf() * TAU)
	for z: float in [-9.0, 0.5, 10.0]:
		for side: float in [-1.0, 1.0]:
			_place("poste", set, Vector3(side * 5.6, 0, z + side * 2.0), 0.0)
	# os vizinhos que pararam para ver a briga
	var watchers := [["Barbarian", -4.4, -5.0, 0.3], ["Rogue_Hooded", -4.8, -1.0, 0.65], ["Mage", 4.6, -4.0, 0.12], ["Rogue", 4.9, 0.5, -1.0],
		["Knight", -4.6, 3.5, 0.5], ["Rogue_Hooded", 4.4, 4.0, 0.8], ["Mage", -3.6, 7.0, -1.0], ["Barbarian", 3.8, 7.5, 0.45]]
	for w: Array in watchers:
		var holder := Node3D.new()
		holder.name = "Vizinho"
		set.add_child(holder, true)
		holder.owner = arena
		holder.position = Vector3(float(w[1]), 0, float(w[2]))
		holder.rotation.y = atan2(float(w[1]), float(w[2]) + 0.5)  # olham para o meio da rua
		var fig := Node3D.new()
		fig.name = "Figure"
		fig.set_script(load("res://world/figurante.gd"))
		fig.scale = Vector3.ONE * 0.6
		holder.add_child(fig)
		fig.owner = arena
		fig.set("personagem", w[0])
		fig.set("cor_roupa", w[3])
		fig.set("sem_chapeu", rng.randf() < 0.5)
		fig.set("animacao", "Cheer" if rng.randf() < 0.6 else "Idle")
