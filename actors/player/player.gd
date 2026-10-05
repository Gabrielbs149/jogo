class_name Player
extends CharacterBody2D
## Personagem visto de lado. Anda devagar, examina coisas (E), fotografa (F) e abre o álbum (Tab).
## Fica parado durante diálogo, foto, álbum e troca de fase.

## Velocidade andando (pixels por segundo; o personagem tem 20 px de largura).
@export var walk_speed: float = 34.0
## Quanto rápido chega na velocidade (px/s²). Baixo = corpo com peso.
@export var acceleration: float = 200.0
## Quanto rápido para quando solta a direção (px/s²).
@export var deceleration: float = 320.0

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _focused: Interactable

@onready var _sprite: AnimatedSprite2D = %Sprite
@onready var _camera: Camera2D = %Camera
@onready var _interaction_area: Area2D = %InteractionArea


func _ready() -> void:
	Screen.light_target = self
	Dialogue.finished.connect(_on_dialogue_finished)


## Algo está acontecendo e o jogador não deve andar nem interagir.
func is_busy() -> bool:
	return Dialogue.is_open() or Photo.is_busy() or Game.is_changing()


## 1 = olhando para a direita, -1 = esquerda.
func face(direction: int) -> void:
	_sprite.flip_h = direction < 0


func set_camera_limits(left: int, right: int) -> void:
	_camera.limit_left = left
	_camera.limit_right = right
	_camera.limit_top = 0
	_camera.limit_bottom = 180
	_camera.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if is_busy():
		return
	if event.is_action_pressed("interact") and _focused:
		get_viewport().set_input_as_handled()
		_focused.interact()
	elif event.is_action_pressed("photo"):
		get_viewport().set_input_as_handled()
		Photo.take()
	elif event.is_action_pressed("album"):
		get_viewport().set_input_as_handled()
		Photo.open_album()


func _physics_process(delta: float) -> void:
	var direction := 0.0 if is_busy() else Input.get_axis("move_left", "move_right")
	var rate := acceleration if direction != 0.0 else deceleration
	velocity.x = move_toward(velocity.x, direction * walk_speed, rate * delta)
	if not is_on_floor():
		velocity.y += _gravity * delta
	move_and_slide()

	if direction != 0.0:
		face(int(signf(direction)))
	_update_animation()
	_update_focus()


func _update_animation() -> void:
	if Photo.is_shooting():
		_sprite.play("photo")
	elif absf(velocity.x) > 4.0:
		_sprite.play("walk")
	else:
		_sprite.play("idle")


## Escolhe o Interactable mais perto dentro da área e mostra o aviso dele.
func _update_focus() -> void:
	if is_busy():
		return
	var best: Interactable = null
	var best_distance := INF
	for area: Area2D in _interaction_area.get_overlapping_areas():
		var candidate := area as Interactable
		if candidate == null or not candidate.enabled:
			continue
		var distance := absf(global_position.x - candidate.global_position.x)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best == _focused:
		return
	_focused = best
	if _focused:
		Dialogue.show_prompt(_focused.prompt)
	else:
		Dialogue.hide_prompt()


func _on_dialogue_finished() -> void:
	# Força reavaliar: o aviso volta se ainda estiver perto
	_focused = null
