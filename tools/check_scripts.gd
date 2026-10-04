extends SceneTree
## Compila todo .gd do projeto e sai com código 1 se algum tiver erro.
## Uso: godot --headless --path . -s res://tools/check_scripts.gd
## Fica de fora: addons/ (terceiros), tests/ (o GUT compila) e pastas com .gdignore.

const SKIPPED_DIRS: PackedStringArray = ["res://addons", "res://tests"]


func _initialize() -> void:
	var scripts: PackedStringArray = []
	_collect_scripts("res://", scripts)

	# Recompilar o próprio script enquanto ele roda derruba o Godot (signal 11).
	var own_path: String = (get_script() as Script).resource_path
	var failed: PackedStringArray = []
	for path: String in scripts:
		if path == own_path:
			continue
		var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		# load() devolve o script mesmo com erro de parse; reload() é quem diz se compila.
		if script == null or script.reload() != OK:
			failed.append(path)

	if failed.is_empty():
		print("check_scripts: %d scripts OK" % scripts.size())
		quit(0)
		return

	printerr("check_scripts: %d de %d scripts com erro:" % [failed.size(), scripts.size()])
	for path: String in failed:
		printerr("  " + path)
	quit(1)


func _collect_scripts(dir: String, out: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		var full := dir.path_join(sub)
		if sub.begins_with(".") or full in SKIPPED_DIRS:
			continue
		if FileAccess.file_exists(full.path_join(".gdignore")):
			continue
		_collect_scripts(full, out)
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			out.append(dir.path_join(file))
