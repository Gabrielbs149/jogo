@tool
class_name RobedFigure
extends Node3D
## Personagem de manto estilo Journey: manto em cone, capuz, rosto escuro com olhos brilhando, cachecol.
## Cores e proporções no Inspector (aparecem no editor). Acessórios de cada herói são nós filhos extras na fase.

@export var cloth_color: Color = Color(0.75, 0.12, 0.08):
	set(value):
		cloth_color = value
		_apply()
@export var trim_color: Color = Color(1.0, 0.78, 0.38):
	set(value):
		trim_color = value
		_apply()
@export var eye_color: Color = Color(1.0, 0.95, 0.85):
	set(value):
		eye_color = value
		_apply()
## Cor do rosto (escuro no Journey; outra cor para quem tem pele aparecendo).
@export var face_color: Color = Color(0.06, 0.04, 0.04):
	set(value):
		face_color = value
		_apply()
## Tamanho geral (Chumasso é grande, Tico é pequeno).
@export var body_scale: float = 1.0:
	set(value):
		body_scale = value
		_apply()
## Largura do manto em relação à altura.
@export var robe_width: float = 1.0:
	set(value):
		robe_width = value
		_apply()
## Quanto de perna aparece embaixo do manto (0 = manto até o chão, como no Journey).
@export var leg_height: float = 0.0:
	set(value):
		leg_height = value
		_apply()
## Perna direita de pau (José Maria).
@export var peg_leg: bool = false:
	set(value):
		peg_leg = value
		_apply()

var _breath: float = 0.0


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_breath += delta
	var hood := get_node_or_null("Body/Hood") as Node3D
	if hood:
		hood.position.y = 1.3 + sin(_breath * 1.8) * 0.012


func _apply() -> void:
	if not is_inside_tree():
		return
	scale = Vector3.ONE * body_scale
	var body := get_node_or_null("Body") as Node3D
	if body:
		body.position.y = leg_height
	var robe := get_node_or_null("Body/Robe") as Node3D
	if robe:
		robe.scale = Vector3(robe_width, 1.0, robe_width)
	var hem := get_node_or_null("Body/Hem") as Node3D
	if hem:
		hem.scale = Vector3(robe_width, 1.0, robe_width)
	var cloth := _material(cloth_color, 0.0)
	for path: String in ["Body/Robe", "Body/Hood"]:
		_set_material(path, cloth)
	_set_material("Body/Hem", _material(trim_color, 1.6))
	_set_material("Body/Face", _material(face_color, 0.0))
	var eyes := _material(eye_color, 5.0)
	_set_material("Body/EyeLeft", eyes)
	_set_material("Body/EyeRight", eyes)
	# Pernas: só aparecem se o manto estiver levantado
	var leg_mat := _material(cloth_color.darkened(0.6), 0.0)
	var wood := _material(Color(0.45, 0.28, 0.14), 0.0)
	for side: String in ["LegLeft", "LegRight"]:
		var leg := get_node_or_null(side) as MeshInstance3D
		if leg:
			leg.visible = leg_height > 0.0
			var is_peg := peg_leg and side == "LegRight"
			var h := leg_height + 0.12
			leg.scale = Vector3(0.6 if is_peg else 1.0, h, 0.6 if is_peg else 1.0)
			leg.position.y = h / 2.0
			leg.material_override = wood if is_peg else leg_mat
	var scarf := get_node_or_null("Body/Scarf") as Scarf
	if scarf:
		scarf.color = cloth_color
		scarf.glyph_color = trim_color
		if not Engine.is_editor_hint():
			scarf.refresh_colors()  # no editor o cachecol não roda (não é @tool)


func _set_material(path: String, mat: Material) -> void:
	var mesh := get_node_or_null(path) as MeshInstance3D
	if mesh:
		mesh.material_override = mat


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.rim_enabled = true
	mat.rim = 0.45
	mat.rim_tint = 0.6
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat
