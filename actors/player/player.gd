class_name Player
extends CharacterBody3D
## Personagem em terceira pessoa: anda relativo à câmera, vira o modelo para onde anda
## e pula com altura variável, coyote time e buffer de pulo.

@export_group("Chão")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
## Quanto rápido chega na velocidade máxima (m/s²).
@export var acceleration: float = 40.0
## Quanto rápido para quando solta o direcional (m/s²).
@export var deceleration: float = 50.0
## Quanto rápido o modelo vira para a direção do movimento.
@export var turn_speed: float = 12.0

@export_group("Pulo")
## Altura do pulo segurando o botão até o topo (metros).
@export var jump_height: float = 1.6
## Soltar o botão no meio da subida multiplica a velocidade vertical por isto (pulo curto).
@export_range(0.0, 1.0) var jump_cut: float = 0.45
## Gravidade extra na descida: queda mais firme, menos "flutuante".
@export var fall_gravity_multiplier: float = 1.8
## Fração da aceleração que vale no ar.
@export_range(0.0, 1.0) var air_control: float = 0.35
## Tempo depois de sair da beirada em que ainda dá para pular (segundos).
@export var coyote_time: float = 0.12
## Tempo em que um pulo apertado antes de tocar o chão fica guardado (segundos).
@export var jump_buffer_time: float = 0.12

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0

@onready var _model: Node3D = %Model
@onready var _camera_rig: CameraRig = %CameraRig


## Converte o direcional (x = lado, y = frente/trás como no Input.get_vector) numa direção
## no chão, girada pelo yaw da câmera. "Frente" é sempre para onde a câmera olha.
static func direction_from_input(input_dir: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, camera_yaw)


func _ready() -> void:
	_camera_rig.follow(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_buffer_left = jump_buffer_time
	elif event.is_action_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Player.direction_from_input(input_dir, _camera_rig.get_yaw())

	_update_horizontal(direction, delta)
	_update_vertical(delta)
	move_and_slide()
	_turn_model(direction, delta)


func _update_horizontal(direction: Vector3, delta: float) -> void:
	var max_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := direction * max_speed
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	if not is_on_floor():
		rate *= air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _update_vertical(delta: float) -> void:
	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left -= delta
		var multiplier := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= _gravity * multiplier * delta

	_jump_buffer_left -= delta
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = sqrt(2.0 * _gravity * jump_height)
		_jump_buffer_left = 0.0
		_coyote_left = 0.0


func _turn_model(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	# O modelo olha para -Z; atan2 dá o ângulo de -Z até a direção.
	var target_yaw := atan2(-direction.x, -direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
