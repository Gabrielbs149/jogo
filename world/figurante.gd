@tool
class_name Figurante
extends Node3D
## Uma pessoa da fase (morador, guarda, vendedor...) feita com os personagens do KayKit (D026) ou, desde a D063, com os
## da Quaternius (gente de proporção normal: fazendeiro, trabalhadora, bruxa...), que têm animações próprias: o nome
## que o jogo pede (Walking_A, Cheer...) é traduzido para o que o modelo tem (Walk, Wave...).
## Fica fazendo uma animação em laço. As armas que o modelo traz ficam escondidas, menos a que você deixar.
## Escolha o personagem e a animação no Inspector (ou no painel do editor de mapas).

const MODELS := "res://assets/kits/kaykit/personagens/%s.glb"
const SLOTS: Array[StringName] = [&"handslot_l", &"handslot_r"]

@export_enum("Knight", "Barbarian", "Mage", "Rogue", "Rogue_Hooded", "Fazendeiro", "Trabalhador", "Rei", "Aventureiro",
		"Aventureira", "Encapuzada", "Bruxa", "Trabalhadora", "Mulher", "Mulher2", "MulherDeVestido", "Anne") var personagem: String = "Rogue_Hooded":
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

## Corpo (D063): mais largo/estreito (x e z) e mais alto/baixo (y), em proporção do tamanho de quem chama.
@export var largura: float = 1.0:
	set(value):
		largura = value
		_shape()
@export var altura: float = 1.0:
	set(value):
		altura = value
		_shape()

const PP := "res://assets/kits/polypizza/"
## Os outros modelos (D063): caminho e o jeito das animações ("q" = Quaternius com CharacterArmature|...,
## "v" = Woman in Dress com HumanArmature|Female_...).
const EXTRA := {
	"Fazendeiro": [PP + "Ultimate-Modular-Men-Pack/Farmer.glb", "q"],
	"Trabalhador": [PP + "Ultimate-Modular-Men-Pack/Worker.glb", "q"],
	"Rei": [PP + "Ultimate-Modular-Men-Pack/King.glb", "q"],
	"Aventureiro": [PP + "Ultimate-Modular-Men-Pack/Adventurer.glb", "q"],
	"Aventureira": [PP + "Ultimate-Modular-Women-Pack/Adventurer.glb", "q"],
	"Encapuzada": [PP + "Ultimate-Modular-Women-Pack/Hooded_Adventurer.glb", "q"],
	"Bruxa": [PP + "Ultimate-Modular-Women-Pack/Witch.glb", "q"],
	"Trabalhadora": [PP + "Ultimate-Modular-Women-Pack/Worker.glb", "q"],
	"Mulher": [PP + "Ultimate-Modular-Women-Pack/Animated_Woman.glb", "q"],
	"Mulher2": [PP + "Ultimate-Modular-Women-Pack/Animated_Woman_2.glb", "q"],
	"MulherDeVestido": [PP + "Animated-Women-Pack/Woman_in_Dress.glb", "v"],
	"Anne": [PP + "Avulsos/Anne.glb", "q"],
}
## Tradução: o nome do KayKit -> os nomes que servem em cada jeito (o primeiro que o modelo tiver).
const ANIMS := {
	"q": {"Idle": ["Idle", "Idle_Neutral"], "Unarmed_Idle": ["Idle_Neutral", "Idle"], "Walking_A": ["Walk"], "Walking_B": ["Walk"],
		"Walking_C": ["Walk"], "Running_A": ["Run"], "Running_B": ["Run"], "Cheer": ["Wave"], "Interact": ["Interact", "Yes"],
		"Use_Item": ["Interact", "Yes"], "PickUp": ["Interact", "PickUp"], "Spellcasting": ["Interact", "Spell1"], "Blocking": ["Idle_Sword"],
		"2H_Melee_Idle": ["Idle_Sword"]},
	"v": {"Idle": ["Female_Idle"], "Unarmed_Idle": ["Female_Standing", "Female_Idle"], "Walking_A": ["Female_Walk"],
		"Walking_B": ["Female_Walk"], "Walking_C": ["Female_Walk"], "Running_A": ["Female_Run"], "Running_B": ["Female_Run"],
		"Cheer": ["Female_Clapping"], "Interact": ["Female_Standing"], "Use_Item": ["Female_Standing"], "Sit_Chair_Idle": ["Female_Sitting"],
		"Sit_Floor_Idle": ["Female_Sitting"]},
}
## Altura de um personagem do KayKit (sem escala): os outros são escalados para ela, e quem chama escolhe o tamanho.
static var _kaykit_height: float = 0.0

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
	var path: String = EXTRA[personagem][0] if EXTRA.has(personagem) else MODELS % personagem
	if not ResourceLoader.exists(path):
		return
	_model = (load(path) as PackedScene).instantiate() as Node3D
	_model.name = "Modelo"
	_model.rotation.y = PI  # os modelos do KayKit e os da Quaternius olham para +Z; no jogo a frente é -Z
	add_child(_model)  # sem dono: é refeito ao abrir, não vai para o arquivo
	_base_scale = 1.0
	if EXTRA.has(personagem):
		# gente de proporção normal fica um pouco mais alta que um boneco do KayKit (gente grande perto dos cabeçudos)
		var height := _height_of(_model)
		if height > 0.0:
			_base_scale = _kaykit_reference() * 1.1 / height
	_shape()
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	_player = found[0] as AnimationPlayer if not found.is_empty() else null
	_hide_props()
	_dress()
	_play()


## Animação que está tocando (para quem anima por fora, como a Rotina e o Passante).
func player() -> AnimationPlayer:
	return _player


## O modelo tem essa animação (com tradução)? Os da Quaternius não sentam nem deitam.
func can_play(anim: String) -> bool:
	return _resolve(anim) != ""


var _base_scale: float = 1.0


func _shape() -> void:
	if _model:
		_model.scale = Vector3(largura, altura, largura) * _base_scale


## O nome de verdade da animação no modelo ("" se ele não tem nada parecido).
func _resolve(anim: String) -> String:
	if _player == null:
		return ""
	if not EXTRA.has(personagem):
		return anim if _player.has_animation(anim) else ""
	var style: Dictionary = ANIMS[EXTRA[personagem][1]]
	var names := _player.get_animation_list()
	for option: String in style.get(anim, []):
		# "CharacterArmature|Walk", "HumanArmature|Female_Walk" ou até "CharacterArmature|...|Walk|CharacterArmature|Walk"
		for found: StringName in names:
			if String(found) == option or (String(found).split("|") as Array).has(option):
				return String(found)
	return ""


static func _height_of(node: Node3D) -> float:
	# só o corpo: mochila, espada e machado esticam a caixa e deixavam a pessoa pequenininha
	var box := AABB()
	var first := true
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		var low := String(mi.name).to_lower()
		if low.contains("weapon") or low.contains("sword") or low.contains("backpack") or low.contains("axe") or low.contains("shield"):
			continue
		var b := node.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb() if node.is_inside_tree() else mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.size.y


static func _kaykit_reference() -> float:
	if _kaykit_height <= 0.0:
		var probe := (load(MODELS % "Rogue") as PackedScene).instantiate() as Node3D
		var holder := Node3D.new()
		holder.add_child(probe)
		_kaykit_height = 0.0
		for found: Node in probe.find_children("*", "MeshInstance3D", true, false):
			var mi := found as MeshInstance3D
			var b := mi.transform * mi.get_aabb()
			var parent := mi.get_parent() as Node3D
			while parent and parent != probe:
				b = parent.transform * b
				parent = parent.get_parent() as Node3D
			_kaykit_height = maxf(_kaykit_height, b.end.y)
		holder.free()
		if _kaykit_height <= 0.0:
			_kaykit_height = 2.0
	return _kaykit_height


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
			for s: int in mesh.get_surface_override_material_count():
				mesh.set_surface_override_material(s, null)
			continue
		if EXTRA.has(personagem):
			_tint_flat(mesh)
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


## Os da Quaternius são de cor lisa por material: a roupa (o que não é pele, cabelo, olho, boca) gira de cor.
func _tint_flat(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	for s: int in mesh.mesh.get_surface_count():
		var base := mesh.mesh.surface_get_material(s) as StandardMaterial3D
		if base == null:
			continue
		var low := String(base.resource_name).to_lower()
		if low.contains("skin") or low.contains("hair") or low.contains("eye") or low.contains("mouth") or low.contains("brow") \
				or low.contains("face") or low.contains("beard") or low.contains("teeth") or low.contains("pele"):
			continue
		var key := "%d|%.2f" % [base.get_instance_id(), cor_roupa]
		if not _tints.has(key):
			var mat := base.duplicate() as StandardMaterial3D
			var c := base.albedo_color
			mat.albedo_color = Color.from_hsv(fposmod(c.h + cor_roupa, 1.0), c.s, c.v, c.a)
			_tints[key] = mat
		mesh.set_surface_override_material(s, _tints[key])


func _hide_props() -> void:
	if _model == null:
		return
	if EXTRA.has(personagem):
		# gente da cidade não anda armada: a espada da encapuzada e o machado da Anne somem
		for found: Node in _model.find_children("*", "MeshInstance3D", true, false):
			var low := String(found.name).to_lower()
			if low.contains("weapon") or low.contains("sword") or low.contains("axe"):
				(found as MeshInstance3D).visible = na_mao != "" and String(found.name) == na_mao
		return
	for slot_name: StringName in SLOTS:
		for slot: Node in _model.find_children(String(slot_name), "", true, false):
			for item: Node in slot.find_children("*", "MeshInstance3D", true, false):
				(item as MeshInstance3D).visible = na_mao != "" and item.name == StringName(na_mao)


func _play() -> void:
	var anim := _resolve(animacao)
	if anim == "":
		anim = _resolve("Idle")  # não tem (sentar, deitar nos da Quaternius): fica parado
	if anim == "":
		return
	_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	# já estava mexendo (troca no meio do jogo, D060): passa de uma animação para a outra devagar, do começo
	var was_playing := _player.is_playing() and not Engine.is_editor_hint()
	_player.play(anim, 0.25 if was_playing else -1.0)
	if was_playing:
		return
	var length := _player.current_animation_length
	if length > 0.0:
		_player.seek(fmod(deslocamento if deslocamento > 0.0 else randf() * length, length), true)
