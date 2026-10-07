extends SceneTree
## Gera as miniaturas da biblioteca do editor de mapas (D042) em editor/icones/: cada peça fotografada em 3/4,
## de frente (o lado -Z, que é a frente das peças do jogo), sobre fundo transparente. Só refaz o que falta,
## a não ser com TUDO=1. Uso (COM janela, para renderizar): godot --path . -s tools/editor/gerar_icones.gd

const SIZE := 160

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	DirAccess.make_dir_recursive_absolute(EditorLibrary.ICONS)
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.9)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 30
	_cam.far = 2000
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	var lib := EditorLibrary.new()
	var all := OS.get_environment("TUDO") == "1"
	var made := 0
	for c: String in lib.categories:
		for entry: Dictionary in lib.entries[c]:
			var out := EditorLibrary.icon_path(entry["key"])
			if not all and FileAccess.file_exists(out):
				continue
			if OS.get_environment("FILTRO") != "" and not String(entry["key"]).contains(OS.get_environment("FILTRO")):
				continue
			if await _shoot(entry, out):
				made += 1
	print("ícones feitos: ", made)
	quit()


func _shoot(entry: Dictionary, out: String) -> bool:
	var scene := load(String(entry["key"])) as PackedScene
	if scene == null:
		return false
	var piece := scene.instantiate() as Node3D
	piece.scale = Vector3.ONE * float(entry["escala"])
	_holder.add_child(piece)
	for p: Node in piece.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).emitting = false
	for l: Node in piece.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = false
	await process_frame
	var box := AABB()
	var first := true
	for m: Node in piece.find_children("*", "VisualInstance3D", true, false):
		var vi := m as VisualInstance3D
		if vi is Light3D or vi is GPUParticles3D or not vi.is_visible_in_tree():
			continue
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		piece.queue_free()
		return false
	var center := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.05)
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.02
	if OS.get_environment("FILTRO") != "":
		print(entry["key"], " caixa ", box, " raio ", radius)
	var dir := Vector3(0.62, 0.55, -0.85).normalized()  # 3/4 pela frente (-Z), um pouco de cima
	_cam.look_at_from_position(center + dir * dist, center)
	_cam.near = maxf(dist - radius * 2.0, 0.01)
	# em sequência a câmera do SubViewport chega um passo atrasada: posiciona, espera, posiciona de novo
	for k in 2:
		_cam.look_at_from_position(center + dir * dist, center)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.save_png(out)
	piece.queue_free()
	await process_frame
	return true
