class_name CombatFX
extends Node3D
## Efeitos visuais do combate: número flutuante, projétil de luz, anel de área, cura, queda.
## Todos devolvem quando terminam (use com await). Os personagens acham este nó pelo grupo "combat_fx".

@export var font: Font
## Primeira pessoa (D047): o número de quem está na câmera aparece na frente dela, e não em cima da cabeça.
var first_person_target: Node3D


func _ready() -> void:
	add_to_group("combat_fx")


func floating_text(at: Vector3, text: String, color: Color, big: bool = false) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = 96 if big else 72
	label.pixel_size = 0.0026
	label.modulate = color
	label.outline_modulate = Color(0.25, 0.1, 0.05, 0.9)
	label.outline_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.top_level = true
	add_child(label)
	label.global_position = at + Vector3.UP * 2.0
	var cam := get_viewport().get_camera_3d()
	if first_person_target and cam and at.distance_to(first_person_target.global_position) < 0.05:
		label.global_position = cam.global_position - cam.global_basis.z * 2.2 + Vector3.DOWN * 0.45
		label.pixel_size = 0.0016
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 1.2, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tween.chain().tween_callback(label.queue_free)


func projectile(from: Vector3, to: Vector3, color: Color, scene: PackedScene = null) -> void:
	if scene:
		await _charge(from, to, scene)
		return
	var orb := _glow_sphere(0.14, color, 6.0)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 3.0
	orb.add_child(light)
	var start := from + Vector3.UP * 1.3
	var target := to + Vector3.UP * 1.0
	var mid := (start + target) / 2.0 + Vector3.UP * 1.2
	orb.global_position = start
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: orb.global_position = _arc(start, mid, target, t), 0.0, 1.0, 0.4)
	await tween.finished
	orb.queue_free()


func ring(at: Vector3, radius: float, color: Color) -> void:
	var ring_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring_mesh.mesh = torus
	ring_mesh.material_override = _emissive(color, 5.0)
	ring_mesh.top_level = true
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mesh)
	ring_mesh.global_position = at + Vector3.UP * 0.15
	ring_mesh.scale = Vector3.ONE * 0.2
	var tween := create_tween().set_parallel()
	tween.tween_property(ring_mesh, "scale", Vector3(radius, 1.0, radius), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring_mesh.material_override, "albedo_color:a", 0.0, 0.3).set_delay(0.3)
	await tween.finished
	ring_mesh.queue_free()


func rising_glow(at: Vector3, color: Color) -> void:
	var orb := _glow_sphere(0.5, color, 3.0)
	orb.global_position = at + Vector3.UP * 0.4
	(orb.material_override as StandardMaterial3D).albedo_color.a = 0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(orb, "global_position:y", orb.global_position.y + 1.8, 0.8)
	tween.tween_property(orb, "scale", Vector3.ONE * 0.2, 0.8)
	await tween.finished
	orb.queue_free()


## O modelo dá um bote para a frente e volta (o corpo fica no lugar).
func lunge(unit: Combatant) -> void:
	if unit.model == null:
		return
	var tween := create_tween()
	tween.tween_property(unit.model, "position:z", -0.5, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit.model, "position:z", 0.0, 0.2).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Quem apanha (D050): pisca branco, é jogado para trás e inclina, solta faíscas, e o jogo trava um instante
## no impacto (mais no crítico). Vale para heróis e inimigos.
var hitstop_enabled: bool = true
var _flash_mat: StandardMaterial3D


func hit(unit: Combatant, crit: bool = false) -> void:
	if unit == null or not is_instance_valid(unit) or unit.model == null:
		return
	var center := unit.global_position + Vector3.UP * (1.6 if unit.is_boss else 0.6)
	sparks(center, Color(1.0, 0.85, 0.4) if crit else Color(1.0, 0.95, 0.8), 26 if crit else 14)
	if hitstop_enabled:
		_hitstop(0.13 if crit else 0.06)
	# pisca: uma camada branca por cima do modelo, que some
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mat := _flash_mat.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(1, 0.95, 0.85, 0.9) if not crit else Color(1, 0.8, 0.3, 1.0)
	var meshes := unit.model.find_children("*", "GeometryInstance3D", true, false)
	for m: Node in meshes:
		(m as GeometryInstance3D).material_overlay = mat
	var fade := create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_delay(0.04)
	fade.tween_callback(func() -> void:
		for m: Node in meshes:
			if is_instance_valid(m) and (m as GeometryInstance3D).material_overlay == mat:
				(m as GeometryInstance3D).material_overlay = null)
	# empurrão para trás (o modelo olha para -Z: para trás é +Z) e inclinação
	var push := 0.45 if crit else 0.22
	var tween := create_tween()
	tween.tween_property(unit.model, "position:z", push, 0.07).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(unit.model, "rotation:x", -0.25 if crit else -0.12, 0.07)
	tween.parallel().tween_property(unit.model, "scale", Vector3(1.08, 0.9, 1.08), 0.07)
	tween.tween_property(unit.model, "position:z", 0.0, 0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(unit.model, "rotation:x", 0.0, 0.3)
	tween.parallel().tween_property(unit.model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


## Faíscas que saem do ponto em todas as direções e caem.
func sparks(at: Vector3, color: Color, amount: int = 14) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var dot := SphereMesh.new()
	dot.radius = 0.022
	dot.height = 0.044
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = _emissive(color, 4.0)
	p.mesh = dot
	p.top_level = true
	add_child(p)
	p.global_position = at
	p.emitting = true
	await get_tree().create_timer(0.8).timeout
	p.queue_free()


## O rastro do golpe (D050): um arco de luz que varre na frente do alvo e some.
func slash(at: Vector3, facing: Vector3, color: Color, size: float = 1.0) -> void:
	var mesh := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh.mesh = im
	var mat := _emissive(color, 5.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.top_level = true
	add_child(mesh)
	mesh.global_position = at
	# virado para a câmera (sempre se vê o arco inteiro), cada golpe num ângulo
	var cam := get_viewport().get_camera_3d()
	if cam:
		mesh.global_basis = cam.global_basis
	elif facing.length() > 0.01:
		mesh.global_basis = Basis.looking_at(Vector3(facing.x, 0, facing.z).normalized(), Vector3.UP)
	mesh.rotate_object_local(Vector3.BACK, randf_range(-0.9, 0.9))
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _draw_slash(im, t, size), 0.0, 1.0, 0.24)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	await tween.finished
	mesh.queue_free()


func _draw_slash(im: ImmediateMesh, t: float, size: float) -> void:
	im.clear_surfaces()
	var head := lerpf(-1.3, 1.3, t)
	var tail := maxf(-1.3, head - 1.2)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps := 14
	for i: int in steps + 1:
		var a := lerpf(tail, head, float(i) / steps)
		var k := float(i) / steps  # 0 na cauda, 1 na ponta
		var r := 0.8 * size
		var w := 0.16 * size * k
		var dir := Vector3(sin(a), cos(a) - 0.4, 0.0)
		im.surface_set_color(Color(1, 1, 1, k))
		im.surface_add_vertex(dir * (r - w))
		im.surface_set_color(Color(1, 1, 1, k * 0.2))
		im.surface_add_vertex(dir * (r + w))
	im.surface_end()


func _hitstop(seconds: float) -> void:
	var before := Engine.time_scale
	if before < 0.5:
		return  # já travado
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = before


func shake(unit: Combatant) -> void:
	if unit.model == null:
		return
	var tween := create_tween()
	for i: int in 4:
		tween.tween_property(unit.model, "position:x", 0.08 * (1 if i % 2 == 0 else -1), 0.04)
	tween.tween_property(unit.model, "position:x", 0.0, 0.04)
	await tween.finished


func fall(unit: Combatant) -> void:
	if unit.get_node_or_null("Animator"):  # deixa a animação de morte terminar antes de afundar
		await get_tree().create_timer(1.5).timeout
	var tween := create_tween().set_parallel()
	tween.tween_property(unit, "global_position:y", unit.global_position.y - 1.6, 1.4).set_ease(Tween.EASE_IN)
	tween.tween_property(unit, "scale", Vector3.ONE * 0.5, 1.4)
	await tween.finished
	unit.visible = false


## Algo que corre pelo chão do atacante até o alvo, dá um pulinho no impacto e some (burro de guerra).
func _charge(from: Vector3, to: Vector3, scene: PackedScene) -> void:
	var runner := scene.instantiate() as Node3D
	runner.top_level = true
	add_child(runner)
	var dir := to - from
	dir.y = 0.0
	runner.global_position = from + dir.normalized() * 0.8
	runner.rotation.y = atan2(-dir.x, -dir.z)
	var stop := to - dir.normalized() * 0.6
	var tween := create_tween()
	tween.tween_property(runner, "global_position", stop, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(runner, "global_position:y", stop.y + 0.6, 0.12)
	tween.tween_property(runner, "scale", Vector3.ONE * 0.01, 0.25)
	await tween.finished
	runner.queue_free()


func _arc(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


func _glow_sphere(radius: float, color: Color, energy: float) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	orb.mesh = sphere
	orb.material_override = _emissive(color, energy)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.top_level = true
	add_child(orb)
	return orb


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
