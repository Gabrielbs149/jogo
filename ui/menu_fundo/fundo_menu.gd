extends Node3D
## Fundo 3D dos menus (D038): acampamento nas ruínas de Ethera ao entardecer. Na tela inicial, o Tico e o
## Namfoodle descansam na fogueira e a câmera passeia devagar; na escolha de herói, o escolhido fica no Palco.
## Montado por tools/art/montar_fundo_menu.gd; ajustes à mão (posições, câmeras) podem ser feitos no editor.

@export_enum("titulo", "escolha") var modo: String = "titulo"
## Quanto a câmera da tela inicial balança (metros).
@export var balanco: float = 0.5

var _time: float = 0.0
var _base: Vector3
var _focus: Vector3

@onready var _camera_title: Camera3D = $CameraTitulo
@onready var _camera_pick: Camera3D = $CameraEscolha


func _ready() -> void:
	_camera_title.current = modo == "titulo"
	_camera_pick.current = modo == "escolha"
	_base = _camera_title.position
	_focus = (get_node("Foco") as Node3D).position
	for who: String in ["TicoSentado", "Namfoodle"]:
		var node := get_node_or_null(who) as Node3D
		if node == null:
			continue
		node.visible = modo == "titulo"
		var anim := String(node.get_meta("animacao", ""))
		for found: Node in node.find_children("*", "AnimationPlayer", true, false):
			var player := found as AnimationPlayer
			if player.has_animation(anim):
				player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
				player.play(anim)


func _process(delta: float) -> void:
	if modo != "titulo":
		return
	_time += delta
	_camera_title.position = _base + Vector3(sin(_time * 0.08) * balanco, sin(_time * 0.13) * balanco * 0.15, cos(_time * 0.06) * balanco * 0.4)
	_camera_title.look_at(_focus)
