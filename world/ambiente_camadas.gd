class_name AmbienteCamadas
extends Node3D
## Camadas de som do dia a dia (D059): por cima do laço de ambiente da fase (vento + conversa distante), sons soltos
## de vez em quando, em volta de você e de lugares diferentes: passos na pedra, madeira rangendo, bichos da cidade.
## Cada camada sorteia o próximo som num intervalo; entre eles fica o silêncio (que também dá ritmo).
## Os sons ficam em assets/audio/sfx (os gerados por tools/audio/gerar_sons.py e os passos que já existiam).

## Cada camada: som (nome no Audio), intervalo mínimo e máximo (s), distância mínima e máxima (m), volume (dB).
@export var camadas: Array[Dictionary] = [
	{"som": "passo_pedra", "min": 5.0, "max": 11.0, "perto": 8.0, "longe": 16.0, "db": -16.0, "rajada": 4},
	{"som": "madeira", "min": 12.0, "max": 28.0, "perto": 5.0, "longe": 12.0, "db": -10.0},
	{"som": "pombo", "min": 25.0, "max": 55.0, "perto": 6.0, "longe": 14.0, "db": -12.0},
	{"som": "cachorro", "min": 40.0, "max": 90.0, "perto": 25.0, "longe": 40.0, "db": -8.0},
	{"som": "gato", "min": 70.0, "max": 140.0, "perto": 6.0, "longe": 14.0, "db": -14.0},
]

var _next: Array[float] = []


func _ready() -> void:
	if Level.editing or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for layer: Dictionary in camadas:
		_next.append(randf_range(float(layer["min"]) * 0.3, float(layer["max"])))


func _process(delta: float) -> void:
	var listener := get_viewport().get_camera_3d()
	if listener == null:
		return
	for i: int in camadas.size():
		_next[i] -= delta
		if _next[i] > 0.0:
			continue
		var layer := camadas[i]
		_next[i] = randf_range(float(layer["min"]), float(layer["max"]))
		_play(layer, listener.global_position)


func _play(layer: Dictionary, around: Vector3) -> void:
	var angle := randf() * TAU
	var dist := randf_range(float(layer["perto"]), float(layer["longe"]))
	var at := around + Vector3(cos(angle), 0.0, sin(angle)) * dist
	at.y = 0.3
	var sound := String(layer["som"])
	var steps := int(layer.get("rajada", 1))
	# passos: alguns em seguida, como alguém passando na rua
	var walk := Vector3(cos(angle + PI / 2.0), 0.0, sin(angle + PI / 2.0)) * 0.7
	for k: int in steps:
		Audio.play_at(sound, at + walk * k, float(layer["db"]))
		if steps > 1:
			await get_tree().create_timer(randf_range(0.42, 0.55)).timeout
