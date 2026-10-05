class_name ScreenFX
extends CanvasLayer
## Pós-processo da tela (autoload "Screen"): paleta de 6 tons, escuro, negativo, flash, grão, fade.
## A fase diz se é escura (Screen.set_dark); o Player se registra como light_target; o Photo usa flash/negative.

## Grão de filme quando a cena está clara (névoa) e quando está escura.
@export var grain_light: float = 0.25
@export var grain_dark: float = 1.0
## Duração da passagem claro <-> escuro ao entrar numa fase.
@export var dark_transition: float = 0.6

var light_target: Node2D

var darkness: float = 0.0:
	set(value):
		darkness = value
		_set_param("darkness", value)
var negative: float = 0.0:
	set(value):
		negative = value
		_set_param("negative", value)
var flash: float = 0.0:
	set(value):
		flash = value
		_set_param("flash", value)
var fade: float = 0.0:
	set(value):
		fade = value
		_set_param("fade", value)

var _dark_tween: Tween

@onready var _rect: ColorRect = $Post


func set_dark(on: bool, instant: bool = false) -> void:
	if _dark_tween:
		_dark_tween.kill()
	var target := 1.0 if on else 0.0
	if instant:
		darkness = target
		return
	_dark_tween = create_tween()
	_dark_tween.tween_property(self, "darkness", target, dark_transition)


## Escurece a tela inteira (troca de fase). Use com await.
func fade_out(time: float = 0.5) -> void:
	await create_tween().tween_property(self, "fade", 1.0, time).finished


func fade_in(time: float = 0.5) -> void:
	await create_tween().tween_property(self, "fade", 0.0, time).finished


func _process(_delta: float) -> void:
	# Grão troca a 10 quadros por segundo, travado de propósito
	_set_param("grain_seed", floorf(Time.get_ticks_msec() / 100.0))
	_set_param("grain", lerpf(grain_light, grain_dark, darkness))
	if is_instance_valid(light_target):
		var pos := light_target.get_global_transform_with_canvas().origin + Vector2(0, -16)
		_set_param("light_pos", pos)


func _set_param(param: String, value: Variant) -> void:
	if _rect:
		(_rect.material as ShaderMaterial).set_shader_parameter(param, value)
