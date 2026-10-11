class_name InteriorSobDemanda
extends Node3D
## O interior de uma casa ou loja (D061) carrega só quando você chega perto e some quando você vai embora: a cidade
## tem quase cem casas mobiliadas, com moradores; com tudo carregado de uma vez a fase demorava muito para abrir.
## O interior de cada prédio é uma cena própria (levels/arandu/interiores/<prédio>.tscn, feita pelo
## tools/art/montar_interiores.gd), que dá para abrir e ajustar no editor do Godot.

## A cena do interior.
@export_file("*.tscn") var cena: String = ""
## Carrega a menos dessa distância (m) da câmera; descarrega a mais de `longe`. (D065: de 30/44 para 20/28, menos casas
## mobiliadas carregadas ao mesmo tempo.)
@export var perto: float = 20.0
@export var longe: float = 28.0

var _inside: Node
var _loading: bool = false
var _check: float = 0.0
## Um interior entra na cena por quadro (D065): várias casas entrando juntas davam um engasgo.
static var _frame_used: int = -1


func _ready() -> void:
	if Level.editing or cena == "":
		set_process(false)
		return
	_check = randf() * 0.4  # cada casa confere numa hora diferente


func _process(delta: float) -> void:
	if _loading:
		var status := ResourceLoader.load_threaded_get_status(cena)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			if Engine.get_process_frames() == _frame_used:
				return  # outra casa já entrou neste quadro: fica para o próximo
			_frame_used = Engine.get_process_frames()
			_loading = false
			var scene := ResourceLoader.load_threaded_get(cena) as PackedScene
			if scene and _inside == null:
				_inside = scene.instantiate()
				add_child(_inside)
				Otimizar.apply(_inside, true)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_loading = false
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.4
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := camera.global_position.distance_to(global_position)
	if _inside == null and distance < perto:
		if ResourceLoader.load_threaded_request(cena) == OK:
			_loading = true
	elif _inside != null and distance > longe:
		_inside.queue_free()
		_inside = null


## Carregado agora (para testes e fotos).
func loaded() -> bool:
	return _inside != null


## Carrega na hora, sem esperar chegar perto.
func load_now() -> void:
	if _inside == null and cena != "":
		_inside = (load(cena) as PackedScene).instantiate()
		add_child(_inside)
		Otimizar.apply(_inside, true)
