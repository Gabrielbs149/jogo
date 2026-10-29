class_name MarcaObjetivo
extends Label3D
## Onde fica o objetivo (D091): um losango dourado em cima do lugar, visto de longe e através das casas, com a
## distância embaixo. Some quando você chega perto, nas cenas e nas conversas. Quem põe é a missão, pela fase
## (Level.marcar_objetivo); sem alvo, não aparece.

## A marca fica esta altura (m) acima do alvo.
const ALTURA := 1.7
## Mais perto que isso (m), a marca some: você chegou.
const PERTO := 3.5

var alvo: Node3D
var _level: Level
var _dist: Label3D
var _clock: float = 0.0


func _init() -> void:
	name = "MarcaObjetivo"
	_style(self, 72)
	text = "◆"
	_dist = Label3D.new()
	_style(_dist, 34)
	_dist.offset = Vector2(0, -78)  # embaixo do losango (em pixels da marca, que tem tamanho fixo na tela)
	add_child(_dist)
	visible = false


func _ready() -> void:
	_level = get_parent() as Level


func _process(delta: float) -> void:
	var me: Node3D = _level.player if _level else null
	if alvo == null or not is_instance_valid(alvo) or not alvo.is_inside_tree() or me == null \
			or _level.em_cena or _level.camera_de_cena() != null:
		visible = false
		return
	_clock += delta
	global_position = alvo.global_position + Vector3.UP * (ALTURA + 0.12 * sin(_clock * 2.6))  # balança devagar
	var d := me.global_position.distance_to(alvo.global_position)
	visible = d > PERTO
	_dist.text = "%d m" % roundi(d)


static func _style(label: Label3D, size: int) -> void:
	label.font = load("res://assets/fonts/cinzel.ttf")
	label.font_size = size
	label.outline_size = 12
	label.modulate = Color(1, 0.82, 0.3)
	label.outline_modulate = Color(0.2, 0.08, 0.02)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0014
	label.render_priority = 8
