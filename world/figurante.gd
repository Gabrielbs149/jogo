@tool
class_name Figurante
extends Node3D
## Uma pessoa da fase (morador, guarda, vendedor...) feita com os personagens do KayKit (D026).
## Fica fazendo uma animação em laço. As armas que o modelo traz ficam escondidas, menos a que você deixar.
## Escolha o personagem e a animação no Inspector (ou no painel do editor de mapas).

const MODELS := "res://assets/kits/kaykit/personagens/%s.glb"
const SLOTS: Array[StringName] = [&"handslot_l", &"handslot_r"]

@export_enum("Knight", "Barbarian", "Mage", "Rogue", "Rogue_Hooded") var personagem: String = "Rogue_Hooded":
	set(value):
		personagem = value
		_rebuild()
@export_enum("Idle", "Unarmed_Idle", "Sit_Floor_Idle", "Sit_Chair_Idle", "Lie_Idle", "Cheer", "Interact", "Spellcasting",
		"Blocking", "2H_Melee_Idle", "Walking_A", "Use_Item", "PickUp") var animacao: String = "Idle":
	set(value):
		animacao = value
		_play()
## Nome do objeto na mão que continua aparecendo (ex.: Mug, 1H_Sword, Spellbook). Vazio = mãos livres.
@export var na_mao: String = "":
	set(value):
		na_mao = value
		_hide_props()
## A animação começa num ponto diferente em cada pessoa (ninguém mexe igual ao lado).
@export var deslocamento: float = 0.0
## Variedade (D060): a roupa troca de cor (giro de matiz 0..1; -1 = a cor original), sem chapéu/capacete, sem capa.
@export_range(-1.0, 1.0) var cor_roupa: float = -1.0:
	set(value):
		cor_roupa = value
		_dress()
@export var sem_chapeu: bool = false:
	set(value):
		sem_chapeu = value
		_dress()
@export var sem_capa: bool = false:
	set(value):
		sem_capa = value
		_dress()

const TINT_SHADER := "res://assets/shaders/roupa_tingida.gdshader"
## Material tingido por (textura, cor): várias pessoas da mesma cor dividem o mesmo.
static var _tints: Dictionary = {}

var _model: Node3D
var _player: AnimationPlayer


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _model:
		_model.queue_free()
		_model = null
	var path := MODELS % personagem
	if not ResourceLoader.exists(path):
		return
	_model = (load(path) as PackedScene).instantiate() as Node3D
	_model.name = "Modelo"
	_model.rotation.y = PI  # os modelos do KayKit olham para +Z; no jogo a frente é -Z
	add_child(_model)  # sem dono: é refeito ao abrir, não vai para o arquivo
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	_player = found[0] as AnimationPlayer if not found.is_empty() else null
	_hide_props()
	_dress()
	_play()


## Animação que está tocando (para quem anima por fora, como a Rotina e o Passante).
func player() -> AnimationPlayer:
	return _player


func _dress() -> void:
	if _model == null:
		return
	for found: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		var part := String(mesh.name)
		if part.ends_with("_Hat") or part.ends_with("_Helmet"):
			mesh.visible = not sem_chapeu
		elif part.ends_with("_Cape"):
			mesh.visible = not sem_capa
		if cor_roupa < 0.0:
			mesh.material_override = null
			continue
		var base := mesh.mesh.surface_get_material(0) as StandardMaterial3D if mesh.mesh and mesh.mesh.get_surface_count() > 0 else null
		if base == null or base.albedo_texture == null:
			continue
		var key := "%s|%.2f" % [base.albedo_texture.resource_path, cor_roupa]
		if not _tints.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = load(TINT_SHADER)
			mat.set_shader_parameter("albedo_tex", base.albedo_texture)
			mat.set_shader_parameter("hue_shift", cor_roupa)
			_tints[key] = mat
		mesh.material_override = _tints[key]


func _hide_props() -> void:
	if _model == null:
		return
	for slot_name: StringName in SLOTS:
		for slot: Node in _model.find_children(String(slot_name), "", true, false):
			for item: Node in slot.find_children("*", "MeshInstance3D", true, false):
				(item as MeshInstance3D).visible = na_mao != "" and item.name == StringName(na_mao)


func _play() -> void:
	if _player == null or not _player.has_animation(animacao):
		return
	_player.get_animation(animacao).loop_mode = Animation.LOOP_LINEAR
	# já estava mexendo (troca no meio do jogo, D060): passa de uma animação para a outra devagar, do começo
	var was_playing := _player.is_playing() and not Engine.is_editor_hint()
	_player.play(animacao, 0.25 if was_playing else -1.0)
	if was_playing:
		return
	var length := _player.current_animation_length
	if length > 0.0:
		_player.seek(fmod(deslocamento if deslocamento > 0.0 else randf() * length, length), true)
