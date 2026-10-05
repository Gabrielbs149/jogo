class_name PartyController
extends Node
## Exploração em tempo real (estilo Baldur's Gate): clique no chão move o grupo; quem está selecionado
## vai na frente e os outros seguem em formação, desviando das ruínas pelo mapa de navegação.
## Clique numa pedra com inscrição para ler. F1-F5 (ou o retrato) escolhem quem lidera.

signal leader_changed(leader: Unit)
signal inspected(text: String)

@export var heroes_root: Node3D
@export var camera: TacticsCamera
## Velocidade andando (m/s).
@export var walk_speed: float = 4.2
@export_flags_3d_physics var ground_mask: int = 1
@export_flags_3d_physics var props_mask: int = 4

## Formação atrás do líder: (lado, para trás) em metros.
const FORMATION: Array[Vector2] = [Vector2(0, 0), Vector2(-1.2, 1.4), Vector2(1.2, 1.4), Vector2(-1.2, 2.8), Vector2(1.2, 2.8)]

var heroes: Array[Unit] = []
var leader: Unit
var enabled: bool = false

var _agents: Dictionary = {}  # Unit -> NavigationAgent3D


func setup() -> void:
	heroes.clear()
	for child: Node in heroes_root.get_children():
		var unit := child as Unit
		if unit == null:
			continue
		heroes.append(unit)
		var agent := NavigationAgent3D.new()
		agent.path_desired_distance = 0.35
		agent.target_desired_distance = 0.45
		agent.radius = 0.45
		agent.height = 1.5
		unit.add_child(agent)
		_agents[unit] = agent
	select(0)


func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		for unit: Unit in heroes:
			_agents[unit].target_position = unit.global_position


func select(index: int) -> void:
	if index < 0 or index >= heroes.size() or not heroes[index].is_alive():
		return
	leader = heroes[index]
	leader_changed.emit(leader)


## Manda o grupo para um ponto: o líder vai no ponto, os outros atrás dele em formação.
func move_to(point: Vector3) -> void:
	var map := heroes_root.get_world_3d().navigation_map
	var direction := point - leader.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var right := direction.cross(Vector3.UP)
	var others := heroes.filter(func(u: Unit) -> bool: return u != leader and u.is_alive())
	var order: Array[Unit] = [leader]
	order.append_array(others)
	for i: int in order.size():
		var slot := FORMATION[mini(i, FORMATION.size() - 1)]
		var target := point + right * slot.x - direction * slot.y
		_agents[order[i]].target_position = NavigationServer3D.map_get_closest_point(map, target)


func is_moving() -> bool:
	for unit: Unit in heroes:
		if not _agents[unit].is_navigation_finished():
			return true
	return false


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	for unit: Unit in heroes:
		var agent: NavigationAgent3D = _agents[unit]
		if not unit.is_alive() or agent.is_navigation_finished():
			continue
		var next := agent.get_next_path_position()
		var to_next := next - unit.global_position
		var flat := Vector3(to_next.x, 0.0, to_next.z)
		if flat.length() > 0.01:
			var step := minf(walk_speed * delta, flat.length())
			unit.global_position += flat.normalized() * step
			unit.rotation.y = lerp_angle(unit.rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-12.0 * delta))
		# Altura acompanha o caminho (o mapa de navegação já segue o terreno)
		unit.global_position.y = lerpf(unit.global_position.y, next.y, 1.0 - exp(-15.0 * delta))
	if leader and camera:
		camera.focus_on(leader.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	for i: int in 5:
		if event.is_action_pressed("select_hero_%d" % (i + 1)):
			select(i)
			return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var cam := heroes_root.get_viewport().get_camera_3d()
	var from := cam.project_ray_origin(click.position)
	var to := from + cam.project_ray_normal(click.position) * 400.0
	var space := heroes_root.get_world_3d().direct_space_state
	var prop_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, props_mask))
	if prop_hit:
		var obstacle := _obstacle_of(prop_hit["collider"] as Node)
		if obstacle and obstacle.inscription != "":
			get_viewport().set_input_as_handled()
			inspected.emit(obstacle.inscription)
			move_to(prop_hit["position"])
			return
	var ground_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, ground_mask))
	if ground_hit:
		get_viewport().set_input_as_handled()
		move_to(ground_hit["position"])


func _obstacle_of(node: Node) -> GridObstacle:
	while node:
		if node is GridObstacle:
			return node
		node = node.get_parent()
	return null
