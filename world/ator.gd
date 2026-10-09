class_name Ator
extends Node3D
## Gente das cenas do dia a dia que anda e reage sem IA de luta (D059): a Tika, o garoto da feira.
## Anda em linha reta até um ponto (com a animação de andar, sem teleporte), vira para alguém, senta, deita e toca
## animações simples. Serve para qualquer modelo com AnimationPlayer e a biblioteca humanoide do KayKit.

## Metros por segundo andando.
@export var speed: float = 1.4
@export var walk_animation: StringName = &"Walking_A"
@export var idle_animation: StringName = &"Idle"

var _player: AnimationPlayer
var _walk: Tween


func _ready() -> void:
	var found := find_children("*", "AnimationPlayer", true, false)
	_player = found[0] as AnimationPlayer if not found.is_empty() else null


## Toca uma animação. loop = fica repetindo (parado, sentado, deitado); sem loop, para no último quadro.
func play(anim: StringName, loop: bool = true, blend: float = 0.3) -> void:
	if _player == null or not _player.has_animation(anim):
		return
	_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(anim, blend)


## Toca uma animação uma vez e espera ela acabar.
func play_once(anim: StringName, blend: float = 0.2) -> void:
	if _player == null or not _player.has_animation(anim):
		return
	play(anim, false, blend)
	await get_tree().create_timer(maxf(0.05, _player.get_animation(anim).length - 0.05)).timeout


## Anda até o ponto (no chão, em linha reta) e para virado na direção dada (ou na do caminho).
func walk_to(point: Vector3, end_facing: Variant = null) -> void:
	point.y = global_position.y
	var dist := global_position.distance_to(point)
	if _walk:
		_walk.kill()
	if dist > 0.05:
		face(point, 0.25)
		play(walk_animation)
		_walk = create_tween()
		_walk.tween_property(self, "global_position", point, dist / speed)
		await _walk.finished
	play(idle_animation)
	if end_facing is Vector3:
		face(end_facing as Vector3)


## Vira (só no giro) para olhar o ponto.
func face(point: Vector3, seconds: float = 0.35) -> void:
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() < 0.05:
		return
	var yaw := atan2(-flat.x, -flat.z)  # a frente é -Z
	var target := global_rotation.y + wrapf(yaw - global_rotation.y, -PI, PI)
	if seconds <= 0.0:
		global_rotation.y = target
		return
	create_tween().tween_property(self, "global_rotation:y", target, seconds)


## Põe no lugar e na direção de uma marca (sem andar; para começar uma cena já no lugar).
func place_at(mark: Node3D) -> void:
	if _walk:
		_walk.kill()
	global_transform = mark.global_transform
	reset_physics_interpolation()


func is_walking() -> bool:
	return _walk != null and _walk.is_running()
