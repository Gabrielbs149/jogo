class_name Malabarista
extends Node3D
## As bolinhas do malabarista da praça (D061): três bolas coloridas em cascata (cada uma sobe de uma mão, desenha um
## arco e cai na outra). Ponha na altura das mãos, na frente da pessoa. Some quando a pessoa sai (Morador escondido).

@export var largura: float = 0.42
@export var altura: float = 0.75
## Segundos de cada arco.
@export var tempo: float = 0.62

const CORES: Array[Color] = [Color(0.9, 0.2, 0.15), Color(0.95, 0.8, 0.2), Color(0.2, 0.45, 0.9)]

var _balls: Array[MeshInstance3D] = []
var _t: float = 0.0


func _ready() -> void:
	for k: int in 3:
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.055
		mesh.height = 0.11
		mesh.radial_segments = 10
		mesh.rings = 6
		ball.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CORES[k]
		mat.roughness = 0.4
		ball.material_override = mat
		add_child(ball)
		_balls.append(ball)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for k: int in _balls.size():
		# cada bola atrasada um terço do ciclo; o ciclo inteiro são dois arcos (ida e volta)
		var phase := fposmod(_t / tempo + k * 2.0 / 3.0, 2.0)
		var going := phase < 1.0
		var u := phase if going else phase - 1.0
		var x := lerpf(-largura, largura, u) if going else lerpf(largura, -largura, u)
		var y := 4.0 * altura * u * (1.0 - u)
		_balls[k].position = Vector3(x, y, 0.0)
