extends SceneTree
## Põe o primeiro dia do Tico com a Tika (D059) em Arandu, depois do montar_cena_tico.gd e do montar_missao_padaria.gd:
## marcas da cena (onde ele dorme, onde ela acorda ele, a boca do beco, onde ela senta), a Tika com o script Ator e a
## conversa, o pão do jantar, as coisas para examinar no barraco e o nó do prólogo (Missoes/PrologoTico).
## Pode rodar de novo: refaz só essas peças. Uso: godot --headless --path . -s tools/art/montar_prologo.gd

const LEVEL := "res://levels/arandu/arandu.tscn"

var level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	var cena := level.get_node("CenaTico") as Node3D
	var bed := (level.get_node("TicoCorner/Blanket") as Node3D).global_position
	bed.y = 0.0
	var exit_at := Vector3(-6.9, 0.0, -56.7)  # boca do beco, do lado da rua do portão
	var tika := cena.get_node("Tika") as Node3D
	var tika_seat := tika.global_transform
	# deitado no papelão, ao comprido do beco (a cabeça para o fundo, perto da parede)
	_mark(cena, "TicoDeitado", Transform3D(_facing(Vector3.RIGHT), bed))
	var wake_at := bed + Vector3(0.95, 0, 0.95)
	_mark(cena, "TikaAcordando", Transform3D(_facing(bed - wake_at), wake_at))
	_mark(cena, "TikaNaSaida", Transform3D(_facing(bed - exit_at), exit_at))
	_mark(cena, "TikaSentada", tika_seat)
	# a Tika anda e conversa (Ator); "Falar com a Tika" e a seta em cima dela
	tika.set_script(load("res://world/ator.gd"))
	tika.global_transform = Transform3D(_facing(bed - wake_at), wake_at)
	tika.visible = true
	var talk := _child(tika, "FalarTika") as Node3D
	talk.set_script(load("res://world/interactable.gd"))
	talk.set("action", 4)  # QUEST
	talk.set("prompt_text", "Falar com a Tika")
	talk.set("text", "")
	talk.position = Vector3(0, 0.8, 0)
	var arrow := _label(tika, "MarcaTika", "▼", 1.55)
	# o pão do jantar (fim do dia): inteiro na mão do Tico, depois uma metade para cada um
	_prop(cena, "PaoDoTico", "res://world/props/pao.tscn", 1.5)
	_prop(cena, "MeioPaoTico", "res://world/props/meio_pao.tscn", 1.4)
	_prop(cena, "MeioPaoTika", "res://world/props/meio_pao.tscn", 1.4)
	# coisas para examinar no barraco (F): o herói vira para a coisa e lê um pensamento curto
	var corner := level.get_node("TicoCorner")
	var look := corner.get_node("Look")
	look.set("prompt_text", "Examinar a cama")
	look.set("text", "Palha, saco de farinha e papelão. É dura, mas é nossa.")
	var fire := cena.get_node("Fogueirinha") as Node3D
	# a brasa da fogueirinha apagada: um pouco de luz quente no barraco (de noite o beco é um breu)
	var ember := fire.get_node_or_null("Brasa") as OmniLight3D
	if ember == null:
		ember = OmniLight3D.new()
		ember.name = "Brasa"
		fire.add_child(ember)
		ember.owner = level
	ember.position = Vector3(0, 0.25, 0)
	ember.light_color = Color(1.0, 0.45, 0.18)
	ember.light_energy = 0.55
	ember.omni_range = 3.2
	ember.shadow_enabled = false
	_examine(corner, "OlharFogueira", fire.global_position + Vector3(0, 0.4, 0), "Examinar a fogueirinha",
		"Cinza fria. Do rato, só sobrou o rabo.")
	_examine(corner, "OlharCaixote", (corner.get_node("Crate1") as Node3D).global_position + Vector3(0, 0.6, 0), "Examinar o caixote",
		"Nosso cofre: uma colher torta, um botão e um toco de vela.")
	_examine(corner, "OlharCaneca", (corner.get_node("Cup") as Node3D).global_position + Vector3(0, 0.3, 0), "Examinar a caneca",
		"A caneca da Tika. Ninguém bebe nela: ela diz que é enfeite.")
	# o prólogo
	var holder := level.get_node("Missoes")
	var quest := _child(holder, "PrologoTico", false)
	quest.set_script(load("res://world/quests/prologo_tico.gd"))
	quest.set("tika", tika)
	quest.set("falar_tika", talk)
	quest.set("marca_tika", arrow)
	quest.set("cama", cena.get_node("TicoDeitado"))
	quest.set("tika_acordando", cena.get_node("TikaAcordando"))
	quest.set("tika_saida", cena.get_node("TikaNaSaida"))
	quest.set("tika_sentada", cena.get_node("TikaSentada"))
	quest.set("fogueira", fire)
	quest.set("plano_acordar", cena.get_node("Plano1"))
	quest.set("fita", _side_alley())
	_bras()
	_bico()
	_briga()
	# som do dia a dia (D059): violão calmo baixinho, o laço da cidade e as camadas de sons soltos
	level.set("musica", "rotina")
	level.set("ambiente", "cidade")
	var layers := level.get_node_or_null("AmbienteCamadas")
	if layers == null:
		layers = Node3D.new()
		layers.name = "AmbienteCamadas"
		level.add_child(layers)
		layers.owner = level
	layers.set_script(load("res://world/ambiente_camadas.gd"))
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


## Seu Brás, o mendigo conhecido: sentado na esquina da rua do portão, logo ao sul da boca do beco.
func _bras() -> void:
	var person := _person("Bras", Transform3D(_facing(Vector3.RIGHT), Vector3(-5.1, 0, -53.4)), "Rogue_Hooded", "Sit_Floor_Idle", 0.62)
	var talk := person.get_node("Talk") as Node3D
	talk.set("action", 4)
	talk.set("prompt_text", "Falar com o Seu Brás")
	talk.set("text", "")
	talk.position = Vector3(0, 0.6, 0)
	var quest := _child(level.get_node("Missoes"), "MendigoBras", false)
	quest.set_script(load("res://world/quests/conversa_mendigo.gd"))
	quest.set("falar", talk)


## O bico do celeiro: o carregador (da multidão) sentado com o pé torcido, a carroça e os caixotes ao lado
## (na ponta do caminho de terra), e a pilha na porta do galpão.
func _bico() -> void:
	var carrier := level.get_node("Crowd/Carregador") as Node3D
	carrier.global_transform = Transform3D(_facing(Vector3.LEFT), Vector3(28.1, 0, -55.4))
	var figure := carrier.get_node("Figure")
	figure.set("animacao", "Sit_Floor_Idle")
	var talk := _child(carrier, "Talk") as Node3D
	talk.set_script(load("res://world/interactable.gd"))
	talk.set("action", 4)
	talk.set("prompt_text", "Falar com o carregador")
	talk.set("text", "")
	talk.position = Vector3(0, 0.7, 0)
	var mark := _label(carrier, "MarcaBico", "!", 1.7)
	var spot := _child(level.get_node("Props"), "BicoCeleiro") as Node3D
	spot.global_position = Vector3.ZERO
	_scene_at(spot, "Carroca", "res://world/props/carroca.tscn", Transform3D(Basis(), Vector3(26.4, 0, -50.6)))
	# luz para o bico aparecer de noite: um poste com lanterna perto da carroça e uma lanterna na parede do galpão
	_scene_at(spot, "PosteCarroca", "res://world/props/poste_lanterna.tscn", Transform3D(Basis(), Vector3(23.4, 0, -52.0)))
	_scene_at(spot, "LanternaGalpao", "res://world/props/lanterna.tscn", Transform3D(Basis(Vector3.UP, PI), Vector3(31.4, 1.9, -58.3)))
	var crate := "res://assets/kits/quaternius/objetos/Crate_Wooden.gltf"
	var on_cart: Array[Node3D] = []
	var piled: Array[Node3D] = []
	for i: int in 3:
		on_cart.append(_scene_at(spot, "CaixoteCarroca%d" % i, crate,
			Transform3D(Basis(Vector3.UP, 0.25 * i).scaled(Vector3.ONE * 0.5), Vector3(24.9, 0.47 * (i / 2), -50.0 + 0.55 * (i % 2)))))
		piled.append(_scene_at(spot, "CaixoteGalpao%d" % i, crate,
			Transform3D(Basis(Vector3.UP, -0.2 * i).scaled(Vector3.ONE * 0.5), Vector3(31.2 + 0.55 * (i % 2), 0.47 * (i / 2), -57.7))))
	var take := _child(spot, "PegarCaixote") as Node3D
	take.set_script(load("res://world/interactable.gd"))
	take.set("action", 4)
	take.set("prompt_text", "Pegar um caixote")
	take.set("text", "")
	take.global_position = Vector3(24.9, 0.8, -49.7)
	var drop := _child(spot, "LargarCaixote") as Node3D
	drop.set_script(load("res://world/interactable.gd"))
	drop.set("action", 4)
	drop.set("prompt_text", "Largar o caixote")
	drop.set("text", "")
	drop.global_position = Vector3(31.4, 0.8, -57.1)
	var quest := _child(level.get_node("Missoes"), "BicoCaixas", false)
	quest.set_script(load("res://world/quests/bico_caixas.gd"))
	quest.set("carregador", talk)
	quest.set("na_carroca", on_cart)
	quest.set("na_pilha", piled)
	quest.set("pegar", take)
	quest.set("largar", drop)
	quest.set("marca", mark)


## A briga na banca de frutas: o garoto na frente da banca, o vendedor atrás; depois o garoto vai para perto da fonte.
func _briga() -> void:
	var seller := level.get_node("People/Vendedor") as Node3D
	var seller_talk := seller.get_node("Talk")
	seller_talk.set("action", 4)
	seller_talk.set("prompt_text", "Falar com o vendedor")
	seller_talk.set("text", "")
	var boy_at := Vector3(12.3, 0, -9.0)
	var boy := _person("Garoto", Transform3D(_facing(seller.global_position - boy_at), boy_at), "Rogue", "Idle", 0.45)
	var boy_talk := boy.get_node("Talk") as Node3D
	boy_talk.set("action", 4)
	boy_talk.set("prompt_text", "Falar com o garoto")
	boy_talk.set("text", "")
	boy_talk.position = Vector3(0, 0.6, 0)
	var step_in := _child(boy, "Intervir") as Node3D
	step_in.set_script(load("res://world/interactable.gd"))
	step_in.set("action", 4)
	step_in.set("prompt_text", "Intervir")
	step_in.set("text", "")
	step_in.position = Vector3(0, 0.7, 0)
	var after_at := Vector3(6.2, 0, -5.2)
	var after := _mark(level.get_node("People") as Node3D, "GarotoDepois", Transform3D(_facing(-after_at), after_at))
	var quest := _child(level.get_node("Missoes"), "BrigaFeira", false)
	quest.set_script(load("res://world/quests/briga_feira.gd"))
	quest.set("vendedor", seller)
	quest.set("falar_vendedor", seller_talk)
	quest.set("garoto", boy)
	quest.set("intervir", step_in)
	quest.set("falar_garoto", boy_talk)
	quest.set("lugar_depois", after)


## O beco lateral (a faixa entre a casa vizinha do barraco e a rua de baixo, fechada por um muro): caixotes, barril,
## um gato e a fita roxa da Tika escondida perto da parede (detalhe opcional). Devolve o "Pegar a fita".
func _side_alley() -> Node3D:
	var alley := _child(level, "BecoLateral") as Node3D
	alley.add_to_group("nav_source", true)
	alley.global_position = Vector3.ZERO
	var wall := "res://assets/kits/quaternius/vila/Wall_UnevenBrick_Straight.gltf"
	for i: int in 3:
		var piece := _scene_at(alley, "Muro%d" % i, wall, Transform3D(Basis(), Vector3(-12.3 + 2.0 * i, 0, -47.75)))
		piece.add_to_group("colisao_auto", true)
	_scene_at(alley, "Barril", "res://world/props/barril.tscn", Transform3D(Basis(), Vector3(-7.9, 0, -48.45)))
	_scene_at(alley, "Balde", "res://world/props/balde.tscn", Transform3D(Basis(Vector3.UP, 0.6), Vector3(-9.3, 0, -48.35)))
	_scene_at(alley, "Caixote", "res://world/props/caixote.tscn", Transform3D(Basis(Vector3.UP, 0.3), Vector3(-11.5, 0, -48.45)))
	_scene_at(alley, "CaixoteAlto", "res://world/props/caixote_alto.tscn", Transform3D(Basis(Vector3.UP, -0.2), Vector3(-12.6, 0, -48.5)))
	_scene_at(alley, "Gato", "res://world/props/gato.tscn", Transform3D(Basis(Vector3.UP, 2.2), Vector3(-11.5, 0.66, -48.45)))
	var lamp := alley.get_node_or_null("Luz") as OmniLight3D
	if lamp == null:
		lamp = OmniLight3D.new()
		lamp.name = "Luz"
		alley.add_child(lamp)
		lamp.owner = level
	lamp.global_position = Vector3(-10.0, 2.3, -49.4)
	lamp.light_color = Color(1.0, 0.7, 0.42)
	lamp.light_energy = 0.7
	lamp.omni_range = 4.5
	_examine(alley, "OlharBarril", Vector3(-7.9, 0.9, -48.45), "Examinar o barril",
		"Água de chuva. Tem gosto de telhado.")
	_examine(alley, "OlharCaixotes", Vector3(-12.0, 0.9, -48.5), "Examinar os caixotes",
		"Vazios. Alguém chegou antes.")
	_examine(alley, "OlharGato", Vector3(-11.5, 1.0, -48.45), "Examinar o gato",
		"Ele abre um olho, me mede e volta a dormir.")
	# a fita: um laço roxo pequeno no chão, entre o caixote alto e a parede da casa
	var ribbon := _child(alley, "Fita") as Node3D
	ribbon.set_script(load("res://world/interactable.gd"))
	ribbon.set("action", 4)
	ribbon.set("prompt_text", "Pegar a fita")
	ribbon.set("text", "")
	ribbon.global_position = Vector3(-12.5, 0.03, -49.6)
	if ribbon.get_node_or_null("Laco") == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.2, 0.75)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.12, 0.55)
		mat.emission_energy_multiplier = 0.6
		var bow := Node3D.new()
		bow.name = "Laco"
		ribbon.add_child(bow)
		bow.owner = level
		for k: int in 3:
			var part := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.11, 0.015, 0.05) if k < 2 else Vector3(0.03, 0.02, 0.03)
			box.material = mat
			part.mesh = box
			part.name = "Parte%d" % k
			bow.add_child(part)
			part.owner = level
			part.position = Vector3([-0.055, 0.055, 0.0][k], 0.0, 0.0)
			part.rotation.y = [0.35, -0.35, 0.0][k]
	return ribbon


## Uma pessoa nova (world/props/morador.tscn) em People, com o personagem e a animação dados.
func _person(person_name: String, at: Transform3D, model: String, anim: String, size: float) -> Node3D:
	var people := level.get_node("People")
	var person := people.get_node_or_null(person_name) as Node3D
	if person == null:
		person = (load("res://world/props/morador.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		person.name = person_name
		people.add_child(person)
		person.owner = level
	person.global_transform = at
	var figure := person.get_node("Figure") as Node3D
	figure.set("personagem", model)
	figure.set("animacao", anim)
	figure.set("na_mao", "")
	figure.scale = Vector3.ONE * size
	level.set_editable_instance(person, true)
	return person


func _scene_at(parent: Node3D, node_name: String, path: String, at: Transform3D) -> Node3D:
	var old := parent.get_node_or_null(node_name)
	if old:
		parent.remove_child(old)
		old.free()
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = node_name
	parent.add_child(node)
	node.owner = level
	node.global_transform = at
	return node


## Giro que olha na direção dada (só no plano; a frente é -Z).
func _facing(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-dir.x, -dir.z))


func _child(parent: Node, child_name: String, spatial: bool = true) -> Node:
	var node := parent.get_node_or_null(child_name)
	if node == null:
		node = Node3D.new() if spatial else Node.new()
		node.name = child_name
		parent.add_child(node)
		node.owner = level
	return node


func _mark(parent: Node3D, mark_name: String, at: Transform3D) -> Marker3D:
	var mark := parent.get_node_or_null(mark_name) as Marker3D
	if mark == null:
		mark = Marker3D.new()
		mark.name = mark_name
		parent.add_child(mark)
		mark.owner = level
	mark.global_transform = at
	return mark


func _prop(parent: Node3D, prop_name: String, path: String, size: float) -> void:
	var old := parent.get_node_or_null(prop_name)
	if old:
		parent.remove_child(old)
		old.free()
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = prop_name
	parent.add_child(node)
	node.owner = level
	node.scale = Vector3.ONE * size
	node.global_position = parent.global_position + Vector3(0, 0.3, 0)
	node.visible = false


func _examine(parent: Node, node_name: String, at: Vector3, prompt: String, text: String) -> void:
	var node := _child(parent, node_name) as Node3D
	node.set_script(load("res://world/interactable.gd"))
	node.set("action", 0)  # READ
	node.set("prompt_text", prompt)
	node.set("text", text)
	node.global_position = at


## Marca em cima da cabeça (igual às da padaria): através das paredes, sempre do mesmo tamanho.
func _label(person: Node3D, mark_name: String, symbol: String, height: float) -> Label3D:
	var mark := person.get_node_or_null(mark_name) as Label3D
	if mark == null:
		mark = Label3D.new()
		mark.name = mark_name
		person.add_child(mark)
		mark.owner = level
	mark.position = Vector3(0, height, 0)
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
