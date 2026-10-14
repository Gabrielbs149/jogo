class_name AdagaPsiquica
extends Node3D
## Adaga psíquica do Tico (D051, do desenho do Gabriel): lâmina de cristal roxo ondulada e translúcida, uma espiral de
## luz rosa girando em volta, brilhinhos subindo, guarda roxa com pontas, cabo escuro amarrado e anel prateado no pomo.
## Feita aqui mesmo (malhas simples), sem modelo de fora. O cabo fica na origem; a lâmina sai para +Y.
## materialize(): aparece num estouro. flare(): a lâmina acende forte (golpe). trail(): liga o rastro de luz da lâmina.
## AdagaPsiquica.attach_to(heroi): uma em cada mão (D051, só na luta).

const PURPLE := Color(0.72, 0.38, 1.0)
const PINK := Color(1.0, 0.62, 0.95)

@export var blade_length: float = 0.42
@export var blade_width: float = 0.05
## Brilho da lâmina (as adagas na frente da câmera brilham menos: estão perto demais).
@export var glow: float = 2.2

var _blade_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _wisp: Node3D
var _light: OmniLight3D
var _base_energy: float = 2.2
# rastro: as últimas posições da base e da ponta da lâmina, desenhadas como uma fita que some
## Quanto tempo cada pedaço do rastro dura (s).
## D079: 0,2 s e da base à ponta: o rastro desenha o arco do corte (só liga na hora do corte, não no preparo).
const TRAIL_TIME := 0.2

var _trail_on: bool = false
var _trail: Array[PackedVector3Array] = []
var _trail_mesh: MeshInstance3D
var _trail_im: ImmediateMesh

## Giro e lugar da adaga dentro da mão ESQUERDA. A lâmina sai do lado do polegar, de través com o antebraço (punho
## fechado). A mão direita do esqueleto é o espelho da esquerda: giro e lugar espelhados (grip_rotation, grip_offset).
## Com o mesmo giro nas duas, a lâmina da direita saía para trás e, nos golpes, o pulso torcia meia volta (D080).
const GRIP_ROTATION := Vector3(25, 0, 90)
## O meio do cabo (0,055 abaixo da guarda) no meio do punho: as mãos do Tico são pequenas e o meio delas fica no osso
## da mão (medido na malha). Antes a adaga ficava 5 cm à frente do pulso e o cabo inteiro fora da mão (D080).
const GRIP_OFFSET := Vector3(-0.055, 0.0, 0.0)


## Giro da adaga na mão (osso LeftHand ou RightHand), em graus.
static func grip_rotation(bone: String) -> Vector3:
	if bone.begins_with("Right"):
		return Vector3(GRIP_ROTATION.x, -GRIP_ROTATION.y, -GRIP_ROTATION.z)
	return GRIP_ROTATION


## Lugar da adaga (da guarda dela) no osso da mão.
static func grip_offset(bone: String) -> Vector3:
	if bone.begins_with("Right"):
		return Vector3(-GRIP_OFFSET.x, GRIP_OFFSET.y, GRIP_OFFSET.z)
	return GRIP_OFFSET


## Uma adaga em cada mão do herói (osso LeftHand/RightHand). Devolve as duas.
static func attach_to(hero: Node3D) -> Array[AdagaPsiquica]:
	var made: Array[AdagaPsiquica] = []
	var found := hero.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return made
	var skeleton := found[0] as Skeleton3D
	for bone: String in ["LeftHand", "RightHand"]:
		if skeleton.find_bone(bone) < 0:
			continue
		var holder := BoneAttachment3D.new()
		holder.name = "Mao" + bone
		holder.bone_name = bone
		skeleton.add_child(holder)
		var dagger := AdagaPsiquica.new()
		dagger.name = "AdagaPsiquica"
		holder.add_child(dagger)
		dagger.rotation_degrees = grip_rotation(bone)
		dagger.position = grip_offset(bone)
		made.append(dagger)
	# caído (D080): na queda a lâmina atravessava a cabeça; some e volta quando ele levanta
	if hero.has_signal("downed_changed"):
		hero.connect("downed_changed", func(is_down: bool) -> void:
			for d: AdagaPsiquica in made:
				if is_instance_valid(d) and d.visible:
					d._fold(is_down))
	if hero.has_signal("dodged"):
		hero.connect("dodged", func() -> void:
			for d: AdagaPsiquica in made:
				if is_instance_valid(d) and d.visible:
					d._tuck(hero))
	return made


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if _wisp:
		_wisp.rotate_y(delta * 3.2)  # a espiral gira em volta da lâmina
	if _trail_mesh == null:
		return
	# D070: o rastro é só da metade de fora da lâmina e dura um tempo fixo (não um número de quadros): com golpes
	# largos, a lâmina inteira somando luz virava um lençol branco
	var now := Time.get_ticks_msec() / 1000.0
	if _trail_on:
		var root := global_transform * Vector3(0, blade_length * 0.2, 0)
		_trail.push_front(PackedVector3Array([root, tip(), Vector3(now, 0, 0)]))
	while not _trail.is_empty() and now - _trail[_trail.size() - 1][2].x > TRAIL_TIME:
		_trail.pop_back()
	_trail_im.clear_surfaces()
	if _trail.size() < 2:
		return
	_trail_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in _trail.size():
		var k := clampf(1.0 - (now - _trail[i][2].x) / TRAIL_TIME, 0.0, 1.0)
		_trail_im.surface_set_color(Color(PURPLE, 0.0))
		_trail_im.surface_add_vertex(_trail[i][0])
		_trail_im.surface_set_color(Color(PINK, 0.75 * k))
		_trail_im.surface_add_vertex(_trail[i][1])
	_trail_im.surface_end()


## Liga/desliga o rastro de luz que a lâmina deixa ao se mexer (golpe).
func trail(on: bool) -> void:
	_trail_on = on
	if on and _trail_mesh == null:
		_trail_im = ImmediateMesh.new()
		_trail_mesh = MeshInstance3D.new()
		_trail_mesh.name = "Rastro"
		_trail_mesh.mesh = _trail_im
		_trail_mesh.top_level = true
		_trail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_trail_mesh.material_override = mat
		add_child(_trail_mesh)
		_trail_mesh.global_transform = Transform3D.IDENTITY


## Onde está a ponta da lâmina agora (mundo).
func tip() -> Vector3:
	return global_transform * Vector3(0, blade_length, 0)


func base() -> Vector3:
	return global_transform * Vector3(0, 0.03, 0)


## Aparece: cresce do nada, pisca forte e solta faíscas roxas.
func materialize() -> void:
	scale = Vector3.ONE * 0.01
	var burst := _sparkles(40, 1.0, true)
	burst.emitting = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.15)
	flare(0.6)
	await tween.finished
	await get_tree().create_timer(1.0).timeout
	burst.queue_free()


## Rolando (D080): a lâmina é do tamanho do Tico e atravessava a cabeça dele na cambalhota. Ela se recolhe num lampejo
## (é psíquica: aparece e some) e volta quando ele termina de rolar.
func _tuck(hero: Node) -> void:
	var animator := hero.get_node_or_null("Animator")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.07).set_ease(Tween.EASE_IN)
	await tween.finished
	var until := Time.get_ticks_msec() + 1000
	await get_tree().process_frame
	while is_instance_valid(animator) and bool(animator.get("rolling")) and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	if not visible:
		scale = Vector3.ONE
		return
	flare(0.25)
	tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.1, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.08)


## Recolhe (encolhe até sumir) ou volta, num lampejo.
func _fold(away: bool) -> void:
	var tween := create_tween()
	if away:
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.12).set_ease(Tween.EASE_IN)
	else:
		flare(0.25)
		tween.tween_property(self, "scale", Vector3.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector3.ONE, 0.08)


## A lâmina acende (golpe): mais brilho e luz por um instante.
func flare(seconds: float = 0.35) -> void:
	if _blade_mat == null:
		return
	var tween := create_tween().set_parallel()
	_blade_mat.emission_energy_multiplier = _base_energy * 3.0
	_light.light_energy = 2.5
	tween.tween_property(_blade_mat, "emission_energy_multiplier", _base_energy, seconds)
	tween.tween_property(_light, "light_energy", 0.7, seconds)


# ---------- construção

func _build() -> void:
	_base_energy = glow
	_blade_mat = StandardMaterial3D.new()
	_blade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blade_mat.albedo_color = Color(0.86, 0.66, 1.0, 0.5)
	_blade_mat.emission_enabled = true
	_blade_mat.emission = PURPLE
	_blade_mat.emission_energy_multiplier = _base_energy
	_blade_mat.roughness = 0.05
	_blade_mat.metallic_specular = 1.0
	_blade_mat.rim_enabled = true
	_blade_mat.rim = 1.0
	_blade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_core_mat.albedo_color = Color(1.0, 0.85, 1.0, 0.55)
	_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh("Lamina", _blade_mesh(blade_width, 0.011), _blade_mat)
	_add_mesh("Nucleo", _blade_mesh(blade_width * 0.35, 0.004), _core_mat)
	# espiral de luz rosa
	_wisp = Node3D.new()
	_wisp.name = "Espiral"
	add_child(_wisp)
	var wisp_mat := StandardMaterial3D.new()
	wisp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wisp_mat.vertex_color_use_as_albedo = true
	wisp_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wisp := MeshInstance3D.new()
	wisp.mesh = _helix_mesh()
	wisp.material_override = wisp_mat
	wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisp.add_child(wisp)
	# guarda: um nó central com pontas que se abrem como galhos, roxo metálico
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.42, 0.22, 0.62)
	guard_mat.metallic = 0.7
	guard_mat.roughness = 0.3
	guard_mat.emission_enabled = true
	guard_mat.emission = Color(0.45, 0.2, 0.75)
	guard_mat.emission_energy_multiplier = 0.4
	var center := SphereMesh.new()
	center.radius = 0.016
	center.height = 0.026
	_add_mesh("Guarda", center, guard_mat)
	for side: float in [-1.0, 1.0]:
		for k: int in 3:
			var prong := CylinderMesh.new()
			prong.top_radius = 0.0025
			prong.bottom_radius = 0.007
			prong.height = 0.05 - k * 0.012
			prong.radial_segments = 6
			var node := _add_mesh("Ponta", prong, guard_mat)
			var angle := side * (0.75 + k * 0.35)
			node.transform = Transform3D(Basis(Vector3.BACK, -angle), Vector3(side * 0.014, 0.004 + k * 0.006, 0)).translated_local(Vector3(0, prong.height / 2.0, 0))
	# cabo amarrado e anel no pomo
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.2, 0.12, 0.24)
	grip_mat.roughness = 0.8
	var grip := CylinderMesh.new()
	grip.top_radius = 0.012
	grip.bottom_radius = 0.014
	grip.height = 0.1
	grip.radial_segments = 10
	_add_mesh("Cabo", grip, grip_mat).position = Vector3(0, -0.055, 0)
	var wrap_mat := StandardMaterial3D.new()
	wrap_mat.albedo_color = Color(0.48, 0.38, 0.5)
	for k: int in 4:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.012
		ring.outer_radius = 0.0155
		ring.rings = 12
		ring.ring_segments = 6
		_add_mesh("Amarra", ring, wrap_mat).position = Vector3(0, -0.02 - k * 0.022, 0)
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.78, 0.78, 0.82)
	silver.metallic = 0.9
	silver.roughness = 0.25
	var pommel := TorusMesh.new()
	pommel.inner_radius = 0.012
	pommel.outer_radius = 0.022
	pommel.rings = 16
	pommel.ring_segments = 8
	_add_mesh("Pomo", pommel, silver).transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -0.118, 0))
	# brilhinhos subindo e luz roxa
	_sparkles(10, 1.4, false).emitting = true
	_light = OmniLight3D.new()
	_light.light_color = PURPLE
	_light.light_energy = 0.7
	_light.omni_range = 1.4
	_light.position = Vector3(0, blade_length * 0.5, 0)
	add_child(_light)


func _add_mesh(label: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	add_child(node, true)
	return node


## Lâmina ondulada (como um kris): seção em losango, larga na base e afinando até a ponta.
func _blade_mesh(width: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24
	var rings: Array[PackedVector3Array] = []
	for i: int in steps + 1:
		var t := float(i) / steps
		var y := 0.012 + t * blade_length
		var wave := sin(t * PI * 2.6) * width * 0.35 * (1.0 - t * 0.4)
		var w := width * (1.0 - pow(t, 1.7)) * (1.0 + 0.12 * sin(t * PI * 5.2)) * 0.5 + 0.001
		var th := thick * (1.0 - t * 0.85)
		rings.append(PackedVector3Array([Vector3(wave - w, y, 0), Vector3(wave, y, th), Vector3(wave + w, y, 0), Vector3(wave, y, -th)]))
	for i: int in steps:
		var a := rings[i]
		var b := rings[i + 1]
		for k: int in 4:
			var k2 := (k + 1) % 4
			st.add_vertex(a[k])
			st.add_vertex(b[k])
			st.add_vertex(b[k2])
			st.add_vertex(a[k])
			st.add_vertex(b[k2])
			st.add_vertex(a[k2])
	var tip_point := Vector3(rings[steps][0].x + width * 0.001, 0.012 + blade_length + 0.03, 0)
	for k: int in 4:
		st.add_vertex(rings[steps][k])
		st.add_vertex(tip_point)
		st.add_vertex(rings[steps][(k + 1) % 4])
	st.generate_normals()
	return st.commit()


## Fita em espiral em volta da lâmina, mais forte no meio, sumindo nas pontas.
func _helix_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps := 90
	for i: int in steps + 1:
		var t := float(i) / steps
		var a := t * TAU * 2.4
		var r := blade_width * (0.85 - t * 0.35)
		var y := 0.02 + t * blade_length * 1.02
		var alpha := sin(t * PI) * 0.9
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		st.set_color(Color(PINK, alpha))
		st.add_vertex(p + Vector3(0, -0.006, 0))
		st.set_color(Color(PINK, alpha * 0.25))
		st.add_vertex(p + Vector3(0, 0.012, 0))
	return st.commit()


func _sparkles(amount: int, life: float, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(blade_width, blade_length * 0.5, blade_width)
	p.position = Vector3(0, blade_length * 0.5, 0)
	p.direction = Vector3.UP
	p.spread = 180.0 if burst else 25.0
	p.initial_velocity_min = 0.6 if burst else 0.05
	p.initial_velocity_max = 1.6 if burst else 0.2
	p.gravity = Vector3.ZERO if not burst else Vector3(0, -1.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var dot := SphereMesh.new()
	dot.radius = 0.006 if not burst else 0.01
	dot.height = dot.radius * 2.0
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = PINK
	dot.material = mat
	p.mesh = dot
	add_child(p)
	return p


## Fora da luta (D057): as adagas ficam guardadas e aparecem quando o herói ataca (botão esquerdo no mapa). Ele corta em
## X com elas (rastro e brilho) e, alguns segundos depois do último golpe, elas somem de novo.
static func equip_for_field(hero: Combatant) -> void:
	var daggers := attach_to(hero)
	if daggers.is_empty():
		return
	for d: AdagaPsiquica in daggers:
		d.visible = false
	var animator := hero.get_node_or_null("Animator")
	if animator:
		var list: Array[StringName] = []
		list.assign(animator.get("ability_animations"))
		if not list.is_empty():
			list[0] = &"tico/Golpe_1"
		animator.set("ability_animations", list)
	var state := {"last": 0.0}
	if animator and animator.has_signal("combo_strike") and not (animator.get("combo") as Array).is_empty():
		animator.connect("combo_strike", func(step: int) -> void:
			state["last"] = Time.get_ticks_msec() / 1000.0
			_field_strike(hero, daggers, state, step))
		return
	hero.ability_used.connect(func(index: int) -> void:
		if index != 0:
			return
		state["last"] = Time.get_ticks_msec() / 1000.0
		_field_strike(hero, daggers, state))


## Quando o corte de cada golpe do combo acontece (s depois do começo): [liga o rastro, desliga] (D079: o rastro e o som
## só no corte, não no preparo).
const CUT_WINDOWS := [[0.12, 0.3], [0.12, 0.3], [0.2, 0.4]]


static func _field_strike(hero: Combatant, daggers: Array[AdagaPsiquica], state: Dictionary, step: int = 0) -> void:
	for d: AdagaPsiquica in daggers:
		if not d.visible:
			d.visible = true
			d.materialize()
	_set_armed(hero, true)
	var window: Array = CUT_WINDOWS[clampi(step, 0, CUT_WINDOWS.size() - 1)]
	await hero.get_tree().create_timer(float(window[0])).timeout
	if not is_instance_valid(hero):
		return
	Audio.play_at("golpe", hero.global_position + Vector3.UP * 0.6, -3.0 if step < 2 else 0.0)
	for d: AdagaPsiquica in daggers:
		if is_instance_valid(d):
			d.flare(0.6 if step < 2 else 0.9)
			d.trail(true)
	await hero.get_tree().create_timer(float(window[1]) - float(window[0])).timeout
	for d: AdagaPsiquica in daggers:
		if is_instance_valid(d):
			d.trail(false)
	await hero.get_tree().create_timer(0.3).timeout
	# guarda depois de um tempo sem atacar
	var mine: float = state["last"]
	await hero.get_tree().create_timer(2.5).timeout
	if not is_instance_valid(hero) or float(state["last"]) != mine:
		return
	for d: AdagaPsiquica in daggers:
		if is_instance_valid(d) and d.visible:
			d.vanish()
	_set_armed(hero, false)


## Avisa o animador que está (ou não) de adagas na mão: parado fica em guarda e andando os braços seguram as lâminas
## (D080; com os braços soltos do andar as lâminas iam para todo lado).
static func _set_armed(hero: Node, on: bool) -> void:
	var animator := hero.get_node_or_null("Animator")
	if animator and animator.get("armed") != null:
		animator.set("armed", on)


## Some: encolhe e solta brilhinhos.
func vanish() -> void:
	flare(0.3)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	scale = Vector3.ONE
