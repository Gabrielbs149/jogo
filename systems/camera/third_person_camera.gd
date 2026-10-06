class_name ThirdPersonCamera
extends Node3D
## Câmera atrás do ombro. O mouse gira (fica preso na janela; Esc solta), a roda aproxima e afasta.
## A mira é o centro da tela.

@export var target: Node3D
@export var height: float = 1.55
## Desloca a câmera para o lado, por cima do ombro direito.
@export var shoulder: float = 0.55
@export var distance: float = 4.6
@export var min_distance: float = 2.2
@export var max_distance: float = 8.0
@export var sensitivity: float = 0.0025
@export var min_pitch: float = -1.15
@export var max_pitch: float = 0.5

var yaw: float = 0.0
var pitch: float = -0.28

@onready var _arm: SpringArm3D = $Arm
@onready var camera: Camera3D = $Arm/Camera3D


func _ready() -> void:
	top_level = true
	# a câmera anda no _process (segue o mouse); interpolar de novo só atrasaria
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_arm.collision_mask = 1 | 4
	_arm.margin = 0.25
	_arm.spring_length = distance
	_arm.position = Vector3(shoulder, 0.0, 0.0)
	yaw = rotation.y


func capture(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func snap() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * sensitivity
		pitch = clampf(pitch - motion.relative.y * sensitivity, min_pitch, max_pitch)
	elif event is InputEventMouseButton and event.is_pressed():
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance - 0.5, min_distance)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance + 0.5, max_distance)


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		global_position = global_position.lerp(target.global_position + Vector3.UP * height, minf(1.0, delta * 14.0))
	rotation = Vector3(pitch, yaw, 0.0)
	_arm.spring_length = lerpf(_arm.spring_length, distance, minf(1.0, delta * 8.0))


func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func aim_origin() -> Vector3:
	return camera.global_position


func aim_dir() -> Vector3:
	return -camera.global_basis.z


## Onde a mira (centro da tela) encosta no chão ou numa pedra.
func aim_point(reach: float = 80.0) -> Vector3:
	var from := aim_origin()
	var to := from + aim_dir() * reach
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return from + aim_dir() * 30.0
	return hit["position"]
