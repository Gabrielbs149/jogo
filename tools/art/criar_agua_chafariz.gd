extends SceneTree
## Cria a água do chafariz da praça (D041): espelho d'água na bacia e nas duas tigelas, a água caindo da borda de
## cada tigela para a de baixo, o jato no topo e os respingos onde a água bate. As medidas são as do chafariz de
## world/props/chafariz.tscn (Water_Fountain x2,4 em cima da bacia). Salva assets/vfx/agua_chafariz.tscn.
## Uso: godot --headless --path . -s tools/art/criar_agua_chafariz.gd

const OUT := "res://assets/vfx/agua_chafariz.tscn"
## [altura da água, raio da água, raio da borda de onde cai, altura onde a água cai]
const BACIA := [0.98, 3.68]
const TIGELAS := [[4.12, 2.02, 2.2, 1.0], [5.24, 1.04, 1.16, 4.14]]
const TOPO := 6.7

var root_node: Node3D
var _drop_mesh: QuadMesh
var _foam_mesh: QuadMesh


func _initialize() -> void:
	root_node = Node3D.new()
	root_node.name = "AguaChafariz"
	_meshes()
	_surface("Bacia", BACIA[0], BACIA[1])
	for k: int in TIGELAS.size():
		var t: Array = TIGELAS[k]
		_surface("Tigela%d" % (k + 1), t[0], t[1])
		_curtain("Queda%d" % (k + 1), t[0] + 0.06, t[2], t[3], 650 if k == 0 else 340)
		_splash("Respingo%d" % (k + 1), t[3] + 0.02, t[2] + 0.25)
	_jet()
	var packed := PackedScene.new()
	print("pack ", packed.pack(root_node), " save ", ResourceSaver.save(packed, OUT))
	root_node.free()
	quit()


func _own(node: Node) -> void:
	root_node.add_child(node, true)
	node.owner = root_node


func _meshes() -> void:
	var drop_mat := StandardMaterial3D.new()
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	drop_mat.albedo_color = Color(0.8, 0.93, 1.0, 0.6)
	drop_mat.albedo_texture = _soft_dot()
	_drop_mesh = QuadMesh.new()
	_drop_mesh.size = Vector2(0.08, 0.26)
	_drop_mesh.material = drop_mat
	var foam_mat := drop_mat.duplicate() as StandardMaterial3D
	foam_mat.albedo_color = Color(1, 1, 1, 0.55)
	_foam_mesh = QuadMesh.new()
	_foam_mesh.size = Vector2(0.14, 0.14)
	_foam_mesh.material = foam_mat


func _soft_dot() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	return tex


## Espelho d'água redondo.
func _surface(name: String, y: float, radius: float) -> void:
	var water := MeshInstance3D.new()
	water.name = name
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 40
	disc.rings = 1
	water.mesh = disc
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/agua.gdshader")
	var waves := NoiseTexture2D.new()
	waves.seamless = true
	waves.as_normal_map = true
	waves.bump_strength = 6.0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	waves.noise = noise
	mat.set_shader_parameter("ondas", waves)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(water)
	water.position = Vector3(0, y, 0)


## Cortina de gotas caindo da borda (anel) até a água de baixo.
func _curtain(name: String, y: float, radius: float, lands: float, amount: int) -> void:
	var p := GPUParticles3D.new()
	p.name = name
	p.amount = amount
	var fall := y - lands
	p.lifetime = sqrt(2.0 * fall / 9.8) + 0.05
	p.preprocess = 2.0
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc.emission_ring_axis = Vector3.UP
	proc.emission_ring_radius = radius
	proc.emission_ring_inner_radius = radius - 0.04
	proc.emission_ring_height = 0.0
	proc.direction = Vector3(0, -1, 0)
	proc.spread = 4.0
	proc.radial_velocity_min = 0.25
	proc.radial_velocity_max = 0.4
	proc.initial_velocity_min = 0.1
	proc.initial_velocity_max = 0.3
	proc.gravity = Vector3(0, -9.8, 0)
	proc.scale_min = 0.8
	proc.scale_max = 1.3
	p.process_material = proc
	p.draw_pass_1 = _drop_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -6, -4), Vector3(8, 8, 8))
	_own(p)
	p.position = Vector3(0, y, 0)


## Respingos brancos onde a água bate.
func _splash(name: String, y: float, radius: float) -> void:
	var p := GPUParticles3D.new()
	p.name = name
	p.amount = 90
	p.lifetime = 0.45
	p.preprocess = 1.0
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc.emission_ring_axis = Vector3.UP
	proc.emission_ring_radius = radius
	proc.emission_ring_inner_radius = radius - 0.2
	proc.emission_ring_height = 0.0
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 35.0
	proc.initial_velocity_min = 0.5
	proc.initial_velocity_max = 1.1
	proc.gravity = Vector3(0, -6.0, 0)
	p.process_material = proc
	p.draw_pass_1 = _foam_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(p)
	p.position = Vector3(0, y, 0)


## Jato no topo, que cai na tigela de cima.
func _jet() -> void:
	var p := GPUParticles3D.new()
	p.name = "Jato"
	p.amount = 80
	p.lifetime = 0.95
	p.preprocess = 1.0
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 14.0
	proc.initial_velocity_min = 2.0
	proc.initial_velocity_max = 2.6
	proc.gravity = Vector3(0, -9.8, 0)
	p.process_material = proc
	p.draw_pass_1 = _drop_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -3, -2), Vector3(4, 5, 4))
	_own(p)
	p.position = Vector3(0, TOPO, 0)
