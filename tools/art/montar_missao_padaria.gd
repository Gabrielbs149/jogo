extends SceneTree
## Põe a 1ª missão do Tico (D040) em Arandu: troca o prédio "Padaria" pela padaria de verdade (world/props/padaria.tscn,
## mesmo lugar), coloca o padeiro atrás do balcão, leva a moça que ficava na praça para a porta da Casa da Viúva
## (ela vira a viúva, quem recebe a encomenda), cria as marcas "!" e a seta e o nó da missão (MissaoPadaria).
## Pode rodar de novo: refaz só essas peças. Uso: godot --headless --path . -s tools/art/montar_missao_padaria.gd

const LEVEL := "res://levels/arandu/arandu.tscn"

var level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	var bakery := _bakery()
	var baker := _baker(bakery)
	var widow := _widow()
	var quest := level.get_node_or_null("Missoes/MissaoPadaria")
	if quest == null:
		var holder := level.get_node_or_null("Missoes")
		if holder == null:
			holder = Node.new()
			holder.name = "Missoes"
			level.add_child(holder)
			holder.owner = level
		quest = Node.new()
		quest.name = "MissaoPadaria"
		holder.add_child(quest)
		quest.owner = level
	quest.set_script(load("res://world/quests/missao_padaria.gd"))
	quest.set("padeiro", baker.get_node("Talk"))
	quest.set("viuva", widow.get_node("Talk"))
	quest.set("marca_padeiro", _mark(baker, "!", "MarcaMissao"))
	quest.set("marca_viuva", _mark(widow, "▼", "MarcaEntrega"))
	quest.set("ia", _brain(baker, bakery))
	quest.set("roubo", _steal_spot(bakery))
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


## A padaria de verdade no lugar do prédio genérico (mesmo lugar e tamanho).
func _bakery() -> Node3D:
	var old := level.get_node("Buildings/Padaria") as Node3D
	var where := old.transform
	if old.scene_file_path == "res://world/props/padaria.tscn":
		return old
	var parent := old.get_parent()
	var index := old.get_index()
	parent.remove_child(old)
	old.free()
	var shop := (load("res://world/props/padaria.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	shop.name = "Padaria"
	parent.add_child(shop)
	parent.move_child(shop, index)
	shop.owner = level
	shop.transform = where
	return shop


## O dono da padaria, atrás do balcão, olhando para a porta.
func _baker(bakery: Node3D) -> Node3D:
	var people := level.get_node("People")
	var baker := people.get_node_or_null("Padeiro") as Node3D
	if baker == null:
		baker = (load("res://world/props/morador.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		baker.name = "Padeiro"
		people.add_child(baker)
		baker.owner = level
	baker.global_transform = (bakery.get_node("PontoBalcao") as Node3D).global_transform
	var figure := baker.get_node("Figure")
	figure.set("personagem", "Barbarian")
	figure.set("animacao", "Unarmed_Idle")
	figure.set("na_mao", "")
	var talk := baker.get_node("Talk")
	talk.set("action", 4)  # Interactable.Action.QUEST
	talk.set("prompt_text", "Falar com o padeiro")
	talk.set("text", "")
	level.set_editable_instance(baker, true)
	return baker


## O jeito de andar do padeiro (D058): anda entre os pontos da padaria.
func _brain(baker: Node3D, bakery: Node3D) -> Node:
	var brain := baker.get_node_or_null("IA")
	if brain == null:
		brain = Node.new()
		brain.name = "IA"
		baker.add_child(brain)
		brain.owner = level
	brain.set_script(load("res://world/quests/padeiro_ia.gd"))
	brain.set("padaria", bakery)
	return brain


## "Pegar um pão" no balcão, do lado dos fregueses (só aparece com o padeiro de costas).
func _steal_spot(bakery: Node3D) -> Node:
	var missions := level.get_node("Missoes")
	var spot := missions.get_node_or_null("RoubarPao") as Node3D
	if spot == null:
		spot = Node3D.new()
		spot.name = "RoubarPao"
		missions.add_child(spot)
		spot.owner = level
	spot.set_script(load("res://world/interactable.gd"))
	spot.set("action", 4)  # QUEST
	spot.set("prompt_text", "Pegar um pão  [Furtividade]")
	spot.set("text", "")
	# Missoes é um Node (sem posição): o lugar vai como transform global gravado no próprio nó
	spot.transform = (bakery.get_node("PontoRoubo") as Node3D).global_transform.translated(Vector3.UP * 1.0)
	return spot


## A moça que ficava na praça vira a viúva, na porta da Casa da Viúva (perto do portão do norte).
func _widow() -> Node3D:
	var people := level.get_node("People")
	var widow := people.get_node_or_null("Viuva") as Node3D
	if widow == null:
		for person: Node in people.get_children():
			var talk := person.get_node_or_null("Talk")
			if talk and String(talk.get("prompt_text")) == "Falar com a padeira":
				widow = person as Node3D
				widow.name = "Viuva"
				break
	var house := level.get_node("Buildings/CasaDaViuva") as Node3D
	# a porta fica no meio da frente (-Z da casa); ela espera um passo para fora, olhando para a rua
	var spot := house.global_transform * Vector3(0, 0, -3.7)
	var out := -house.global_basis.z
	widow.global_transform = Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.z)), spot)  # de costas para a porta, olhando a rua
	var talk := widow.get_node("Talk")
	talk.set("action", 4)  # Interactable.Action.QUEST
	talk.set("prompt_text", "Falar com a viúva")
	talk.set("text", "")
	return widow


## Marca de missão em cima da cabeça: aparece através das paredes e sempre do mesmo tamanho na tela.
func _mark(person: Node3D, symbol: String, mark_name: String) -> Label3D:
	var mark := person.get_node_or_null(mark_name) as Label3D
	if mark == null:
		mark = Label3D.new()
		mark.name = mark_name
		person.add_child(mark)
		mark.owner = level
	mark.position = Vector3(0, 2.15, 0)
	mark.text = symbol
	mark.font = load("res://assets/fonts/cinzel.ttf")
	mark.font_size = 72
	mark.outline_size = 14
	mark.modulate = Color(1, 0.82, 0.3)
	mark.outline_modulate = Color(0.2, 0.08, 0.02)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.fixed_size = true
	mark.pixel_size = 0.0009
	mark.visible = false
	return mark
