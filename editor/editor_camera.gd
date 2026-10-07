class_name EditorCamera
extends Node3D
## Câmera do editor de mapas: olha o mapa de cima. WASD anda (as setas movem a peça escolhida) (Shift corre), a roda aproxima,
## o botão direito arrastado gira, o do meio arrastado arrasta o mapa. T alterna "bem de cima".
## O nó fica no chão (o ponto que a câmera olha); a Camera3D fica afastada dele.

@export var distance: float = 40.0
@export var min_distance: float = 3.0
@export var max_distance: float = 180.0
@export var pan_speed: float = 1.1
@export var sensitivity: float = 0.005

var yaw: float = 0.0
var pitch: float = -0.95
## Bem de cima, olhando reto para baixo (planta do mapa).
var top_view: bool = false
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.far = 1500.0
	add_child(camera)
	camera.make_current()
	_apply()


## Olha para este ponto do mapa.
func focus(point: Vector3, dist: float = -1.0) -> void:
	position = point
	if dist > 0.0:
		distance = clampf(dist, min_distance, max_distance)
	_apply()


func toggle_top_view() -> void:
	top_view = not top_view
	_apply()


## Para onde a câmera "anda" no chão quando você aperta W (frente) e D (direita).
func ground_axes() -> Array[Vector3]:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return [forward, right]


func _process(delta: float) -> void:
	if _typing():
		return
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		move.y += 1.0
	if Input.is_key_pressed(KEY_S):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if move == Vector2.ZERO or Input.is_key_pressed(KEY_CTRL):
		return
	var axes := ground_axes()
	var speed := distance * pan_speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	position += (axes[0] * move.y + axes[1] * move.x).normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var button := event as InputEventMouseButton
		if button.ctrl_pressed:
			return  # Ctrl + roda é do editor (tamanho)
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance * 0.88, min_distance)
			_apply()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance / 0.88, max_distance)
			_apply()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= motion.relative.x * sensitivity
			pitch = clampf(pitch - motion.relative.y * sensitivity, -1.53, -0.12)
			top_view = false
			_apply()
		elif motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var axes := ground_axes()
			var k := distance * 0.0017
			position += (-axes[1] * motion.relative.x + axes[0] * motion.relative.y) * k


func _apply() -> void:
	rotation = Vector3(-PI / 2.0 + 0.0001 if top_view else pitch, yaw, 0.0)
	if camera:
		camera.position = Vector3(0.0, 0.0, distance)


func _typing() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit
