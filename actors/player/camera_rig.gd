class_name CameraRig
extends Node3D
## Câmera em terceira pessoa. Segue o alvo com suavidade, gira com o mouse ou o analógico
## direito, e o SpringArm3D aproxima a câmera quando tem parede no caminho.
## Fica com top_level = true na cena: não herda a rotação do personagem.

## Radianos por pixel de mouse.
@export var mouse_sensitivity: float = 0.0018
## Radianos por segundo com o analógico no máximo.
@export var stick_sensitivity: float = 2.0
## Inverte o eixo vertical (mouse e analógico).
@export var invert_y: bool = false
## Limite olhando de cima (negativo = câmera acima do personagem).
@export_range(-89.0, 0.0) var min_pitch_degrees: float = -55.0
## Limite olhando de baixo.
@export_range(0.0, 89.0) var max_pitch_degrees: float = 25.0
## Altura do ponto que a câmera orbita, a partir do pé do personagem.
@export var pivot_height: float = 1.55
## Desloca a órbita para o lado (positivo = câmera sobre o ombro direito).
@export var shoulder_offset: float = 0.45
## Quanto mais alto, mais grudada no personagem (sem atraso).
@export var follow_sharpness: float = 7.0

var _target: Node3D
var _pitch: float = deg_to_rad(-12.0)

@onready var _spring_arm: SpringArm3D = $SpringArm3D


## Chamado pelo dono (o Player) no _ready: passa a seguir e ignorar o corpo dele.
func follow(target: CollisionObject3D) -> void:
	_target = target
	_spring_arm.add_excluded_object(target.get_rid())
	global_position = _pivot_position()
	rotation.y = target.global_rotation.y
	_apply_pitch()


func get_yaw() -> float:
	return rotation.y


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := (event as InputEventMouseMotion).screen_relative
		_rotate(motion.x * mouse_sensitivity, motion.y * mouse_sensitivity)


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		_rotate(stick.x * stick_sensitivity * delta, stick.y * stick_sensitivity * delta)

	if _target:
		var weight := 1.0 - exp(-follow_sharpness * delta)
		global_position = global_position.lerp(_pivot_position(), weight)


## Positivo em x gira para a direita; positivo em y olha para baixo.
func _rotate(yaw_amount: float, pitch_amount: float) -> void:
	rotation.y -= yaw_amount
	_pitch -= -pitch_amount if invert_y else pitch_amount
	_apply_pitch()


func _apply_pitch() -> void:
	_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	_spring_arm.rotation.x = _pitch


func _pivot_position() -> Vector3:
	# Posição interpolada: o personagem anda no tick de física e a câmera no frame; sem isso treme.
	return _target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height + global_basis.x * shoulder_offset
