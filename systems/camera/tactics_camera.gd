class_name TacticsCamera
extends Node3D
## Câmera tática vista de cima (estilo Baldur's Gate). Este nó é o ponto que a câmera olha.
## WASD/setas movem, Q/E giram, roda do mouse aproxima, botão do meio arrastado gira.

@export var distance: float = 13.0
@export var min_distance: float = 7.0
@export var max_distance: float = 34.0
@export_range(-85.0, -20.0) var pitch_degrees: float = -50.0
@export var pan_speed: float = 14.0
## Radianos por segundo com Q/E.
@export var rotate_speed: float = 1.8
## Até onde o ponto de foco pode ir (x, z).
@export var bounds: Rect2 = Rect2(-18, -14, 36, 28)
@export var smoothing: float = 6.0

var _yaw: float = 0.0
var _target: Vector3
var _target_distance: float

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_yaw = rotation.y
	_target = global_position
	_target_distance = distance
	_apply()


func focus_on(point: Vector3) -> void:
	_target = Vector3(point.x, point.y, point.z)
	_clamp_target()


func _process(delta: float) -> void:
	var input := Input.get_vector("cam_left", "cam_right", "cam_forward", "cam_back")
	if input != Vector2.ZERO:
		_target += Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw) * pan_speed * delta * (distance / 13.0)
		_clamp_target()
	_yaw += Input.get_axis("cam_rotate_right", "cam_rotate_left") * rotate_speed * delta
	var weight := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(_target, weight)
	distance = lerpf(distance, _target_distance, weight)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance - 1.5, min_distance, max_distance)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance + 1.5, min_distance, max_distance)
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_yaw -= motion.relative.x * 0.006


func _apply() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(pitch_degrees))
	_camera.transform = Transform3D(tilt, tilt * Vector3(0.0, 0.0, distance))


func _clamp_target() -> void:
	_target.x = clampf(_target.x, bounds.position.x, bounds.end.x)
	_target.z = clampf(_target.z, bounds.position.y, bounds.end.y)
