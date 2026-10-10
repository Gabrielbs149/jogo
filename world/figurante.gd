@tool
class_name Figurante
extends Node3D
## Uma pessoa da fase (morador, guarda, vendedor...) feita com os personagens do KayKit (D026).
## Fica fazendo uma animação em laço. As armas que o modelo traz ficam escondidas, menos a que você deixar.
## Ofício (D063): escolha um (padeiro, ferreiro, lavrador...) e o boneco ganha a roupa e as coisas dele (world/oficios.gd).
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
## Brilho e saturação da roupa (1 = como é): a viúva de preto, o padeiro de branco, o lavrador de roupa gasta.
@export var brilho_roupa: float = 1.0:
	set(value):
		brilho_roupa = value
		_dress()
@export var saturacao_roupa: float = 1.0:
	set(value):
		saturacao_roupa = value
		_dress()
## Ofício (D063): veste o boneco com a cara do trabalho. Vazio = como está.
@export_enum("nenhum", "padeiro", "ferreiro", "sapateiro", "taverneiro", "freguês_taverna", "feirante", "feirante2", "feirante3",
		"lavrador", "lavradora", "fazendeiro", "moleiro", "carregador", "cavalarico", "guarda", "padre", "fiel", "viuva",
		"conselheiro", "estalajadeira", "alfaiate", "boticaria", "bardo", "mercador", "coveiro", "leitora", "mendigo",
		"viajante", "velho", "dona_de_casa", "comprador_pao", "aldeao", "aldea", "crianca") var oficio: String = "":
	set(value):
		oficio = "" if value == "nenhum" else value
		_apply_oficio()

const TINT_SHADER := "res://assets/shaders/roupa_tingida.gdshader"
## Material tingido por (textura, cor): várias pessoas da mesma cor dividem o mesmo.
static var _tints: Dictionary = {}

var _model: Node3D
var _player: AnimationPlayer
## Animação por distância (D065): de perto todo quadro; longe ou fora da tela, poucas vezes por segundo.
var _anim_acc: float = 0.0
var _anim_step: float = 0.0
var _anim_check: float = randf() * 0.3
var _applying: bool = false


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() or _applying:
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
	if _player and not Engine.is_editor_hint():
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_hide_props()
	_dress()
	Oficios.vestir(_model, oficio)
	_play()


## Põe a roupa e o modelo do ofício (de uma vez só, sem refazer o boneco a cada campo).
func _apply_oficio() -> void:
	var spec: Dictionary = Oficios.LISTA.get(oficio, {})
	if spec.is_empty():
		_rebuild()
		return
	_applying = true
	personagem = String(spec.get("modelo", personagem))
	cor_roupa = float(spec.get("cor", -1.0))
	saturacao_roupa = float(spec.get("sat", 1.0))
	brilho_roupa = float(spec.get("val", 1.0))
	sem_chapeu = bool(spec.get("sem_chapeu", false))
	sem_capa = bool(spec.get("sem_capa", false))
	na_mao = String(spec.get("na_mao", ""))
	_applying = false
	_rebuild()


func _process(delta: float) -> void:
	if _player == null or Engine.is_editor_hint():
		return
	_anim_check -= delta
	if _anim_check <= 0.0:
		_anim_check = 0.3
		_anim_step = _step_for_distance()
	_anim_acc += delta
	if _anim_acc >= _anim_step:
		_player.advance(_anim_acc)
		_anim_acc = 0.0


func _step_for_distance() -> float:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return 0.0
	var at := global_position + Vector3.UP * 0.6
	var d := camera.global_position.distance_to(at)
	if not camera.is_position_in_frustum(at):
		return 0.0 if d < 3.0 else 0.25
	if d < 14.0:
		return 0.0
	if d < 30.0:
		return 1.0 / 24.0
	if d < 60.0:
		return 1.0 / 12.0
	return 0.2


## Animação que está tocando (para quem anima por fora, como a Rotina e o Passante).
func player() -> AnimationPlayer:
	return _player


func _dress() -> void:
	if _model == null:
		return
	for found: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if _is_oficio(mesh):
			continue  # as coisas do ofício têm a cor delas
		var part := String(mesh.name)
		if part.ends_with("_Hat") or part.ends_with("_Helmet"):
			mesh.visible = not sem_chapeu
		elif part.ends_with("_Cape"):
			mesh.visible = not sem_capa
		if cor_roupa < 0.0 and is_equal_approx(brilho_roupa, 1.0) and is_equal_approx(saturacao_roupa, 1.0):
			mesh.material_override = null
			continue
		var base := mesh.mesh.surface_get_material(0) as StandardMaterial3D if mesh.mesh and mesh.mesh.get_surface_count() > 0 else null
		if base == null or base.albedo_texture == null:
			continue
		var key := "%s|%.2f|%.2f|%.2f" % [base.albedo_texture.resource_path, cor_roupa, saturacao_roupa, brilho_roupa]
		if not _tints.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = load(TINT_SHADER)
			mat.set_shader_parameter("albedo_tex", base.albedo_texture)
			mat.set_shader_parameter("hue_shift", maxf(cor_roupa, 0.0))
			mat.set_shader_parameter("sat_mul", saturacao_roupa)
			mat.set_shader_parameter("val_mul", brilho_roupa)
			# a máscara da roupa (D063): rosto, mão, cabelo e couro nunca mudam de cor
			var mask_path := base.albedo_texture.resource_path.get_basename() + "_mascara.png"
			if ResourceLoader.exists(mask_path):
				mat.set_shader_parameter("mask_tex", load(mask_path))
				mat.set_shader_parameter("use_mask", true)
			_tints[key] = mat
		mesh.material_override = _tints[key]


func _hide_props() -> void:
	if _model == null:
		return
	for slot_name: StringName in SLOTS:
		for slot: Node in _model.find_children(String(slot_name), "", true, false):
			for item: Node in slot.find_children("*", "MeshInstance3D", true, false):
				if not _is_oficio(item):
					(item as MeshInstance3D).visible = na_mao != "" and item.name == StringName(na_mao)


func _is_oficio(node: Node) -> bool:
	var current := node
	while current and current != _model:
		if String(current.name).begins_with("Oficio_"):
			return true
		current = current.get_parent()
	return false


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
