class_name CombatManager
extends Node
## Conduz a batalha por turnos (estilo Baldur's Gate): iniciativa, em cada turno andar + 1 ação.
## O jogador controla os heróis com o mouse; inimigos (e heróis, se auto_heroes) usam a CombatAI.
## A interface (CombatHUD) só ouve os sinais e chama select_ability() / end_turn_pressed().

signal combat_started(order: Array[Unit])
signal turn_started(unit: Unit)
signal unit_changed(unit: Unit)
signal ability_selected(index: int)
signal message(text: String)
signal hover_changed(text: String)
signal combat_ended(victory: bool)

enum State { IDLE, PLAYER_MOVE, PLAYER_TARGET, BUSY, ENDED }

@export var grid: CombatGrid
@export var highlighter: CellHighlighter
@export var fx: CombatFX
@export var camera: TacticsCamera
## Heróis jogam sozinhos (testes e demonstração).
@export var auto_heroes: bool = false
## Desligado: tudo instantâneo, sem animação (testes).
@export var animate: bool = true
@export var autostart: bool = true
## Tempo para andar uma casa (segundos). Lento de propósito: os personagens deslizam na areia.
@export var step_time: float = 0.24

var units: Array[Unit] = []
var order: Array[Unit] = []
var active: Unit
var state: State = State.IDLE
var round_number: int = 1

var _turn_index: int = -1
var _selected: Ability
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _move_parents: Dictionary = {}
var _move_cells: Array[Vector2i] = []
var _target_cells: Array[Vector2i] = []
var _ring: MeshInstance3D


func _ready() -> void:
	if autostart:
		start.call_deferred()


## Começa a luta. participants vazio = todo mundo do grupo "unit" (testes e arena isolada).
## Quem estiver fora da grade ou em cima de ruína vai para a casa livre mais próxima.
func start(participants: Array[Unit] = []) -> void:
	# A colisão do terreno precisa existir antes da grade medir as alturas
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.build()
	state = State.IDLE
	round_number = 1
	_turn_index = -1
	units.clear()
	if participants.is_empty():
		for node: Node in get_tree().get_nodes_in_group("unit"):
			participants.append(node as Unit)
	var taken := {}
	for unit: Unit in participants:
		if not unit.is_alive():
			continue
		units.append(unit)
		unit.cell = _free_cell_near(grid.world_to_cell(unit.global_position), taken)
		taken[unit.cell] = true
		unit.statuses.clear()
		if animate:
			var tween := create_tween()
			tween.tween_property(unit, "global_position", grid.cell_to_world(unit.cell), 0.35)
		else:
			unit.global_position = grid.cell_to_world(unit.cell)
		if not unit.changed.is_connected(_on_unit_changed):
			unit.changed.connect(_on_unit_changed.bind(unit))
			unit.died.connect(_on_unit_died.bind(unit))
		unit.initiative = Dice.d20() + unit.initiative_bonus
	if animate:
		await get_tree().create_timer(0.4).timeout
	order = units.duplicate()
	order.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.initiative > b.initiative or (a.initiative == b.initiative and a.initiative_bonus > b.initiative_bonus))
	_make_ring()
	combat_started.emit(order)
	var names: PackedStringArray = []
	for unit: Unit in order:
		names.append("%s %d" % [unit.display_name, unit.initiative])
	message.emit("[b]Iniciativa:[/b] " + ", ".join(names))
	_next_turn()


## Chamado pelo botão da interface ou pelas teclas 1-4.
func select_ability(index: int) -> void:
	if state != State.PLAYER_MOVE and state != State.PLAYER_TARGET:
		return
	if index >= active.abilities.size():
		return
	if not active.has_action:
		message.emit("%s já usou a ação neste turno." % active.display_name)
		return
	var ability: Ability = active.abilities[index]
	if ability.target == Ability.Target.SELF:
		state = State.BUSY
		highlighter.clear_all()
		await use_ability(active, ability, active.cell)
		_after_action()
		return
	_selected = ability
	state = State.PLAYER_TARGET
	ability_selected.emit(index)
	_target_cells = CombatRules.target_cells(active, ability, active.cell, grid, units)
	highlighter.clear(CellHighlighter.Style.MOVE)
	highlighter.clear(CellHighlighter.Style.PATH)
	highlighter.show_cells(CellHighlighter.Style.TARGET, _target_cells)
	if _target_cells.is_empty():
		message.emit("Nenhum alvo ao alcance de %s." % ability.title)
	_refresh_preview()


## Depois da vitória: limpa a grade e levanta quem caiu com 1 de vida (como no Baldur's Gate).
func finish_and_reset() -> void:
	highlighter.clear_all()
	if _ring:
		_ring.visible = false
	for unit: Unit in units:
		if unit.team == Unit.Team.HEROES and not unit.is_alive():
			unit.hp = 1
			unit.visible = true
			unit.scale = Vector3.ONE
			unit.global_position = grid.cell_to_world(unit.cell)
			unit.changed.emit()
		unit.statuses.clear()
	active = null
	state = State.IDLE


func end_turn_pressed() -> void:
	if state == State.PLAYER_MOVE or state == State.PLAYER_TARGET:
		_end_turn()


func unit_at(c: Vector2i) -> Unit:
	return CombatRules.unit_at(units, c)


# ---------- ações (usadas pelo jogador e pela IA) ----------

func move_unit(unit: Unit, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	unit.moves_left -= path.size()
	unit.cell = path[-1]
	if animate:
		for c: Vector2i in path:
			var p := grid.cell_to_world(c)
			_face(unit, p)
			var tween := create_tween()
			tween.tween_property(unit, "global_position", p, step_time).set_trans(Tween.TRANS_SINE)
			await tween.finished
			_place_ring(unit)
	else:
		unit.global_position = grid.cell_to_world(unit.cell)
	unit.changed.emit()


func use_ability(unit: Unit, ability: Ability, target_cell: Vector2i) -> void:
	unit.has_action = false
	var results := CombatRules.resolve(unit, ability, target_cell, grid, units)
	var target_pos := grid.cell_to_world(target_cell)
	message.emit("[color=#ffd9a0]%s[/color] usa [b]%s[/b]." % [unit.display_name, ability.title])
	if animate:
		_face(unit, target_pos)
		if ability.projectile:
			await fx.projectile(unit.global_position, target_pos, ability.vfx_color, ability.projectile_scene)
		elif ability.kind == Ability.Kind.ATTACK and ability.radius == 0:
			await fx.lunge(unit, target_pos)
		if ability.radius > 0:
			fx.ring(target_pos, (ability.radius + 0.5) * grid.cell_size, ability.vfx_color)
	for result: Dictionary in results:
		_apply(unit, ability, result)
	if animate:
		await get_tree().create_timer(0.55).timeout
	unit.changed.emit()


# ---------- turnos ----------

func _next_turn() -> void:
	if _check_end():
		return
	for i: int in order.size():
		_turn_index += 1
		if _turn_index >= order.size():
			_turn_index = 0
			round_number += 1
		if order[_turn_index].is_alive():
			break
	active = order[_turn_index]
	active.start_turn()
	_place_ring(active)
	if camera and animate:
		camera.focus_on(active.global_position)
	turn_started.emit(active)
	if active.team == Unit.Team.ENEMIES or auto_heroes:
		state = State.BUSY
		await _ai_turn(active)
		if state != State.ENDED:
			_end_turn()
	else:
		_enter_move_mode()


func _ai_turn(unit: Unit) -> void:
	if animate:
		await get_tree().create_timer(0.5).timeout
	var plan := CombatAI.plan(unit, grid, units)
	var destination: Vector2i = plan["move_to"]
	if destination != unit.cell:
		await move_unit(unit, _path_for(unit, destination))
	var ability: Ability = plan["ability"]
	if ability != null and unit.is_alive():
		await use_ability(unit, ability, plan["target"])


func _end_turn() -> void:
	highlighter.clear_all()
	hover_changed.emit("")
	state = State.BUSY
	# Diferido: sem animação os turnos encadeariam numa recursão enorme
	_next_turn.call_deferred()


func _after_action() -> void:
	if _check_end():
		return
	if active.moves_left <= 0 and not active.has_action:
		_end_turn()
	else:
		_enter_move_mode()


func _check_end() -> bool:
	if state == State.ENDED:
		return true
	var heroes_alive := units.any(func(u: Unit) -> bool: return u.is_alive() and u.team == Unit.Team.HEROES)
	var enemies_alive := units.any(func(u: Unit) -> bool: return u.is_alive() and u.team == Unit.Team.ENEMIES)
	if heroes_alive and enemies_alive:
		return false
	state = State.ENDED
	highlighter.clear_all()
	hover_changed.emit("")
	if _ring:
		_ring.visible = false
	combat_ended.emit(heroes_alive)
	return true


func _apply(unit: Unit, ability: Ability, result: Dictionary) -> void:
	var target: Unit = result["unit"]
	var amount: int = result["amount"]
	var at := target.global_position
	match result["kind"]:
		"miss":
			message.emit("  %s errou %s (d20: %d)." % [unit.display_name, target.display_name, result["roll"]])
			if animate:
				fx.floating_text(at, "Errou", Color(0.95, 0.9, 0.82))
		"hit", "crit":
			if not target.is_alive():
				return
			var crit: bool = result["kind"] == "crit"
			message.emit("  %s%s: [color=#ff9a6a]%d de dano[/color]%s." % [
				"[b]CRÍTICO![/b] " if crit else "", target.display_name, amount,
				" (d20: %d)" % result["roll"] if ability.needs_roll else ""])
			target.take_damage(amount)
			if animate:
				fx.floating_text(at, ("%d!" if crit else "%d") % amount, Color(1.0, 0.55, 0.35), crit)
				fx.shake(target)
		"heal":
			target.heal(amount)
			message.emit("  %s recupera [color=#ffe9a0]%d de vida[/color]." % [target.display_name, amount])
			if animate:
				fx.floating_text(at, "+%d" % amount, Color(1.0, 0.92, 0.6))
				fx.rising_glow(at, ability.vfx_color)
		"buff":
			target.add_status(ability.title, ability.buff_ac, ability.buff_hit, ability.buff_turns)
			message.emit("  %s recebe %s." % [target.display_name, ability.title])
			if animate:
				fx.floating_text(at, ability.title, Color(1.0, 0.9, 0.7))
				fx.rising_glow(at, ability.vfx_color)


func _on_unit_changed(unit: Unit) -> void:
	unit_changed.emit(unit)


## Casa livre mais perto de c (dentro da grade, fora de ruína, sem ninguém).
func _free_cell_near(c: Vector2i, taken: Dictionary) -> Vector2i:
	var start := Vector2i(clampi(c.x, 0, grid.size.x - 1), clampi(c.y, 0, grid.size.y - 1))
	var frontier: Array[Vector2i] = [start]
	var seen := {start: true}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if not grid.is_blocked(current) and not taken.has(current):
			return current
		for d: Vector2i in CombatGrid.DIRECTIONS:
			var n := current + d
			if grid.in_bounds(n) and not seen.has(n):
				seen[n] = true
				frontier.append(n)
	return start


func _on_unit_died(unit: Unit) -> void:
	message.emit("[color=#c9b8a6]%s caiu.[/color]" % unit.display_name)
	if animate:
		fx.fall(unit)
	else:
		unit.visible = false


# ---------- entrada do jogador ----------

func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYER_MOVE and state != State.PLAYER_TARGET:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and event.is_pressed():
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_click()
		elif button == MOUSE_BUTTON_RIGHT and state == State.PLAYER_TARGET:
			get_viewport().set_input_as_handled()
			_enter_move_mode()
	elif event.is_action_pressed("ui_cancel") and state == State.PLAYER_TARGET:
		_enter_move_mode()
	elif event.is_action_pressed("end_turn"):
		end_turn_pressed()
	else:
		for i: int in 4:
			if event.is_action_pressed("ability_%d" % (i + 1)):
				select_ability(i)


func _enter_move_mode() -> void:
	state = State.PLAYER_MOVE
	_selected = null
	ability_selected.emit(-1)
	highlighter.clear(CellHighlighter.Style.TARGET)
	highlighter.clear(CellHighlighter.Style.AREA)
	_move_parents = _reachable_for(active)
	_move_cells = []
	for c: Vector2i in _move_parents:
		if unit_at(c) == null and not grid.is_blocked(c):
			_move_cells.append(c)
	highlighter.show_cells(CellHighlighter.Style.MOVE, _move_cells)
	_refresh_preview()


func _click() -> void:
	if state == State.PLAYER_MOVE and _move_cells.has(_hover_cell):
		var path := CombatGrid.path_to(_move_parents, active.cell, _hover_cell)
		state = State.BUSY
		highlighter.clear_all()
		hover_changed.emit("")
		await move_unit(active, path)
		_after_action()
	elif state == State.PLAYER_TARGET and _target_cells.has(_hover_cell):
		var ability := _selected
		state = State.BUSY
		highlighter.clear_all()
		hover_changed.emit("")
		await use_ability(active, ability, _hover_cell)
		_after_action()


func _update_hover(screen_pos: Vector2) -> void:
	var cell := _mouse_cell(screen_pos)
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_refresh_preview()


func _refresh_preview() -> void:
	highlighter.clear(CellHighlighter.Style.PATH)
	highlighter.clear(CellHighlighter.Style.AREA)
	var lines: PackedStringArray = []
	var hovered := unit_at(_hover_cell)
	if state == State.PLAYER_MOVE:
		if _move_cells.has(_hover_cell):
			var path := CombatGrid.path_to(_move_parents, active.cell, _hover_cell)
			highlighter.show_cells(CellHighlighter.Style.PATH, path)
			lines.append("Andar %d casa%s" % [path.size(), "" if path.size() == 1 else "s"])
		if hovered:
			lines.append(_unit_summary(hovered))
		var stone := grid.obstacle_at(_hover_cell)
		if stone and stone.inscription != "":
			lines.append(stone.inscription)
	elif state == State.PLAYER_TARGET and _target_cells.has(_hover_cell):
		var area := grid.cells_in_radius(_hover_cell, _selected.radius)
		highlighter.show_cells(CellHighlighter.Style.AREA, area)
		lines.append("[%s] %s" % [_selected.title, _selected.dice_text()])
		for u: Unit in CombatRules.affected(active, _selected, _hover_cell, grid, units):
			if _selected.kind == Ability.Kind.ATTACK and _selected.needs_roll:
				lines.append("%s: %d%% de acerto" % [u.display_name, roundi(CombatRules.hit_chance(active, u) * 100)])
			else:
				lines.append(u.display_name)
	hover_changed.emit("\n".join(lines))


func _unit_summary(u: Unit) -> String:
	return "%s  ·  %d/%d vida  ·  CA %d" % [u.display_name, u.hp, u.max_hp, u.current_ac()]


func _mouse_cell(screen_pos: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2i(-1, -1)
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 400.0
	var query := PhysicsRayQueryParameters3D.create(from, to, grid.terrain_mask)
	var hit := grid.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	var c := grid.world_to_cell(hit["position"])
	return c if grid.in_bounds(c) else Vector2i(-1, -1)


# ---------- auxiliares ----------

func _reachable_for(unit: Unit) -> Dictionary:
	var pass_blocked := {}
	for u: Unit in units:
		if u.is_alive() and u.is_opponent(unit):
			pass_blocked[u.cell] = true
	return grid.reachable(unit.cell, unit.moves_left, unit.flying, pass_blocked)


func _path_for(unit: Unit, destination: Vector2i) -> Array[Vector2i]:
	return CombatGrid.path_to(_reachable_for(unit), unit.cell, destination)


func _face(unit: Unit, toward: Vector3) -> void:
	var dir := toward - unit.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	unit.rotation.y = atan2(-dir.x, -dir.z)


func _make_ring() -> void:
	if not animate:
		return
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.7
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.45)
	mat.emission_energy_multiplier = 4.0
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	add_child(_ring)


func _place_ring(unit: Unit) -> void:
	if _ring:
		_ring.visible = true
		_ring.global_position = unit.global_position + Vector3.UP * 0.08


func _process(_delta: float) -> void:
	if _ring and _ring.visible:
		var pulse := 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.06
		_ring.scale = Vector3(pulse, 1.0, pulse)
