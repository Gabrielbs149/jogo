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
	_play()


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
	_player.play(animacao)
	var length := _player.current_animation_length
	if length > 0.0:
		_player.seek(fmod(deslocamento if deslocamento > 0.0 else randf() * length, length), true)
