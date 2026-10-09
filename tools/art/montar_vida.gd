extends SceneTree
## Põe a vida em Arandu (D060), depois dos outros montadores (montar_arandu, montar_cena_tico, montar_missao_padaria,
## montar_prologo): o relógio do dia (CicloDoDia), a gente que anda (Vida + os pontos para onde vão), os moradores
## fixos com horário e gestos (Morador), vendedores nas bancas vazias, bichos que passeiam (Bicho), pombos (Pombos) e
## tira o gato que tinha ficado dentro da padaria. Pode rodar de novo: refaz só essas peças.
## Uso: godot --headless --path . -s tools/art/montar_vida.gd

const LEVEL := "res://levels/arandu/arandu.tscn"
const PP := "res://assets/kits/polypizza/"
const INNER := 52.0  # até onde a gente da cidade anda (o anel fica em 45)
const PLAZA := 17.5

var level: Node3D
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 60
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	for i: int in 3:
		await process_frame
	# o tempo passa: o relógio manda no dia e na noite (Level.noite fica desligado)
	level.set("noite", false)
	# gente passa por portas e becos: o mapa de navegação usa o tamanho de uma pessoa (o padrão, 0,5 m, fecha as portas)
	var nav := (level.get_node("Navigation") as NavigationRegion3D).navigation_mesh
	nav.agent_radius = 0.25  # exatamente 1 célula de 0,25 m (0,3 viraria 2 células e fecharia as portas)
	nav.agent_height = 1.5
	var cycle := _child(level, "CicloDoDia", false)
	cycle.set_script(load("res://world/ciclo_do_dia.gd"))
	_remove("Animals/Gato")  # tinha ficado dentro da padaria
	_remove("Animals/Cachorro")  # o de enfeite vira um cachorro de verdade (abaixo)
	var vida := _child(level, "Vida") as Node3D
	vida.set_script(load("res://world/vida/vida.gd"))
	vida.global_position = Vector3.ZERO
	_spots(vida)
	_residents()
	_vendors()
	_animals()
	_pigeons()
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


# --- pontos para onde a gente vai ---------------------------------------------------------------------

func _spots(vida: Node3D) -> void:
	var old := vida.get_node_or_null("Pontos")
	if old:
		vida.remove_child(old)
		old.free()
	var holder := Node3D.new()
	holder.name = "Pontos"
	vida.add_child(holder)
	holder.owner = level
	var n: Array[int] = [0]  # a lambda copia variáveis simples: o contador vai num Array
	var add := func(kind: String, at: Vector3, meta: Dictionary = {}) -> void:
		var mark := Marker3D.new()
		mark.name = "%s%d" % [kind.capitalize(), n[0]]
		n[0] += 1
		holder.add_child(mark)
		mark.owner = level
		mark.global_position = at
		mark.set_meta("tipo", kind)
		for key: String in meta:
			mark.set_meta(key, meta[key])
	# ruas: as duas avenidas e o anel (passagem: param pouco)
	var street := {"anims": ["Idle"], "min": 0.5, "max": 2.5, "peso": 0.6}
	for z: int in range(-70, 71, 9):
		if absf(z) < PLAZA + 1.5:
			continue
		for x: float in [-2.8, 2.8]:
			add.call("rua", Vector3(x, 0, z), street)
			add.call("rua", Vector3(z, 0, x), street)
	for t: int in range(-40, 41, 10):
		for side: float in [-45.0, 45.0]:
			add.call("rua", Vector3(t, 0, side), street)
			add.call("rua", Vector3(side, 0, t), street)
	# praça: em volta da fonte (olhando para ela), na beira dela e para conversar
	var fountain := Vector3.ZERO
	for k: int in 10:
		var a := k * TAU / 10.0
		add.call("praca", Vector3(cos(a), 0, sin(a)) * 10.5, {"olhar": fountain, "anims": ["Idle", "Cheer", "Interact", "Idle"],
			"min": 4.0, "max": 11.0, "emotes": ["nota", "...", "?"], "emote_chance": 0.2})
	for k: int in 6:
		var a := k * TAU / 6.0 + 0.3
		add.call("olhar", Vector3(cos(a), 0, sin(a)) * 6.4, {"olhar": fountain, "anims": ["Idle", "Idle", "PickUp"], "min": 5.0,
			"max": 12.0, "emotes": ["nota", "..."], "emote_chance": 0.25})
	var talk := {"anims": ["Idle"], "min": 6.0, "max": 14.0, "peso": 1.4}
	for k: int in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		add.call("conversa", Vector3(cos(a), 0, sin(a)) * 13.5, talk)
		add.call("conversa", Vector3(cos(a), 0, sin(a)) * 14.6, talk)
	for at: Vector3 in [Vector3(6, 0, -26), Vector3(-6, 0, 26), Vector3(26, 0, 6), Vector3(-26, 0, -6), Vector3(3, 0, -40), Vector3(-40, 0, 3)]:
		add.call("conversa", at, talk)
		add.call("conversa", at + Vector3(1.2, 0, 0.4), talk)
	# crianças: correm pela praça (fora da fonte)
	for k: int in 9:
		var a := rng.randf() * TAU
		add.call("brincar", Vector3(cos(a), 0, sin(a)) * rng.randf_range(7.5, 15.0), {"anims": ["Cheer", "Idle", "Jump_Full_Short"], "min": 0.6, "max": 3.0})
	# bancas da feira: na frente de cada uma, olhando a mercadoria
	var market := level.get_node_or_null("Market")
	if market:
		for stall: Node in market.get_children():
			if not String(stall.name).begins_with("Banca"):
				continue
			var s := stall as Node3D
			var front := -s.global_basis.z
			var side := s.global_basis.x
			for k: float in [-0.9, 0.9]:
				add.call("banca", s.global_position + front * 1.9 + side * k, {"olhar": s.global_position, "anims": ["Interact", "PickUp", "Use_Item", "Idle"],
					"min": 6.0, "max": 15.0, "emotes": ["?", "nota", "...", "coracao"], "emote_chance": 0.3, "peso": 1.5})
	# portas: lojas (entram e saem) e casas (onde dormem)
	var shops := ["Padaria", "Ferreiro", "Sapateiro", "Estalagem", "Taverna", "Capela", "CasaDoMercador", "CasaDoConselho", "Alfaiate"]
	for building: Node in level.get_node("Buildings").get_children():
		var b := building as Node3D
		if b == null or absf(b.global_position.x) > INNER or absf(b.global_position.z) > INNER:
			continue
		var door := _door(b)
		if door == Vector3.INF:
			continue
		if String(b.name) in shops:
			add.call("loja", door, {"peso": 1.3})
		elif not String(b.name) in ["Guarita", "Campanario"]:
			add.call("casa", door)
		if String(b.name) == "Taverna":
			var out := door - b.global_position
			out.y = 0.0
			out = out.normalized()
			var across := out.cross(Vector3.UP)
			for k: int in 4:
				add.call("taverna", door + out * (1.6 + (k % 2) * 1.1) + across * (k - 1.5) * 1.3, {"anims": ["Cheer", "Idle", "Interact", "Cheer"],
					"min": 8.0, "max": 20.0, "emotes": ["nota", "nota", "...", "coracao"], "emote_chance": 0.4, "horas": [15.0, 24.0], "peso": 1.2})
	print("pontos: ", n[0])


## A porta de um prédio: o meio da frente (−Z do prédio), um passo para fora. INF se não tem nada visível.
func _door(b: Node3D) -> Vector3:
	var inv := b.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for found: Node in b.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local := (inv * mesh.global_transform) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first:
		return Vector3.INF
	var center_x := box.get_center().x
	if String(b.name) == "Padaria":
		center_x = 1.0  # a porta da padaria não fica no meio (D058)
	var p := b.global_transform * Vector3(center_x, 0, box.position.z - 0.9)
	p.y = 0.0
	return p


# --- moradores fixos ----------------------------------------------------------------------------------

func _residents() -> void:
	var config := {
		"Crowd/GuardaPortao": [0.0, 0.0, ["2H_Melee_Idle", "Idle", "2H_Melee_Idle"], []],
		"People/Guarda": [0.0, 0.0, ["2H_Melee_Idle", "Idle", "2H_Melee_Idle"], []],
		"Crowd/Freguês": [7.0, 18.0, ["Idle", "Use_Item", "Interact", "PickUp"], ["?", "...", "nota"]],
		"Crowd/Freguês2": [7.5, 17.5, ["Unarmed_Idle", "Interact", "PickUp", "Cheer"], ["?", "coracao"]],
		"Crowd/Freguês3": [8.0, 18.0, ["Use_Item", "Idle", "Interact"], ["...", "?"]],
		"Crowd/Sentado": [8.0, 20.0, ["Sit_Chair_Idle"], ["zz", "nota", "..."]],
		"Crowd/Sentado2": [9.0, 19.0, ["Sit_Chair_Idle"], ["...", "nota"]],
		"Crowd/Hospede": [7.0, 22.0, ["Idle", "Interact", "Idle"], ["...", "?"]],
		"Crowd/NaTaverna": [15.0, 1.0, ["Cheer", "Idle", "Interact", "Cheer"], ["nota", "nota", "coracao"]],
		"Crowd/NaTaverna2": [15.0, 1.0, ["Idle", "Cheer", "Idle"], ["nota", "..."]],
		"Crowd/Crianca2": [8.0, 18.0, ["Cheer", "Idle", "Jump_Full_Short", "Cheer"], ["nota", "!"]],
		"Crowd/Crianca3": [8.0, 18.0, ["Idle", "Cheer", "Interact"], ["nota", "?"]],
		"People/Crianca": [8.0, 18.5, ["Cheer", "Idle", "Cheer"], ["nota", "!"]],
		"Crowd/Leitora": [8.0, 19.0, ["Sit_Floor_Idle"], ["...", "..."]],
		"Crowd/NoCemiterio": [8.0, 18.0, ["Idle"], ["gota", "..."]],
		"Crowd/Lavrador": [6.0, 18.0, ["Interact", "PickUp", "Use_Item"], ["gota", "nota"]],
		"Crowd/Lavradora": [6.0, 18.0, ["PickUp", "Interact", "Use_Item"], ["gota", "nota"]],
		"Crowd/Fazendeiro": [6.0, 18.5, ["Idle", "Interact", "Cheer"], ["...", "nota"]],
		"Crowd/Moleiro": [6.0, 19.0, ["Idle", "Interact", "Use_Item"], ["..."]],
		"Crowd/Cavalarico": [6.0, 19.0, ["Interact", "Use_Item", "Idle"], ["nota"]],
		"Crowd/Carregador": [0.0, 0.0, ["Sit_Floor_Idle"], ["gota"]],
	}
	for path: String in config:
		var person := level.get_node_or_null(path) as Node3D
		if person == null:
			continue
		var c: Array = config[path]
		person.set_script(load("res://world/vida/morador.gd"))
		person.set("de", c[0])
		person.set("ate", c[1])
		person.set("gestos", _strings(c[2]))
		person.set("emotes", _strings(c[3]))
	# o ferreiro martela de verdade (com som)
	var smith := level.get_node_or_null("Crowd/FerreiroTrabalhando") as Node3D
	if smith:
		smith.set_script(load("res://world/vida/morador.gd"))
		smith.set("de", 7.0)
		smith.set("ate", 19.0)
		smith.set("gestos", _strings(["1H_Melee_Attack_Chop", "1H_Melee_Attack_Chop", "Use_Item", "1H_Melee_Attack_Chop"]))
		smith.set("troca", Vector2(4.0, 9.0))
		smith.set("som", "aparar")
		smith.set("gesto_do_som", "1H_Melee_Attack_Chop")
		smith.set("emotes", _strings(["gota", "nota"]))


func _strings(list: Array) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in list:
		out.append(String(item))
	return out


## As bancas 2, 3 e 4 estavam sem vendedor: cada uma ganha um, atrás do balcão, gritando o pregão.
func _vendors() -> void:
	var market := level.get_node_or_null("Market")
	if market == null:
		return
	var who := {
		"Banca2": ["Rogue_Hooded", 0.3, ["Olha a couve fresquinha!", "Cenoura, batata, cebola!", "Verdura colhida hoje cedo!"]],
		"Banca3": ["Mage", 0.08, ["Pão de ontem pela metade!", "Broa de milho! Broa!", "Mais barato que na padaria!"]],
		"Banca4": ["Barbarian", 0.55, ["Peixe! Peixe fresco!", "Chegou do rio agora!", "Olha o tamanho desse!"]],
	}
	var crowd := level.get_node("Crowd")
	for stall_name: String in who:
		var stall := market.get_node_or_null(stall_name) as Node3D
		if stall == null:
			continue
		var data: Array = who[stall_name]
		var vendor_name := "Vendedor" + stall_name.trim_prefix("Banca")
		var old := crowd.get_node_or_null(vendor_name)
		if old:
			crowd.remove_child(old)
			old.free()
		var person := (load("res://world/props/morador.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		person.name = vendor_name
		crowd.add_child(person)
		person.owner = level
		var behind := stall.global_basis.z * 1.25
		var at := stall.global_position + behind
		person.global_transform = Transform3D(Basis(Vector3.UP, atan2(behind.x, behind.z)), at)
		var fig := person.get_node("Figure")
		fig.set("personagem", data[0])
		fig.set("cor_roupa", data[1])
		fig.set("sem_chapeu", data[0] == "Barbarian")
		fig.set("animacao", "Unarmed_Idle")
		var talk := person.get_node("Talk")
		talk.set("action", 0)
		talk.set("prompt_text", "Falar com o vendedor")
		talk.set("text", "— " + String(data[2][0]) + " ...Comprar? Com o quê, pequeno?")
		person.set_script(load("res://world/vida/morador.gd"))
		person.set("de", 7.0)
		person.set("ate", 18.0)
		person.set("gestos", _strings(["Unarmed_Idle", "Interact", "Cheer", "Unarmed_Idle", "Use_Item"]))
		person.set("pregao", _strings(data[2]))
		person.set("emotes", _strings(["nota", "!"]))
		level.set_editable_instance(person, true)


# --- bichos -------------------------------------------------------------------------------------------

func _animals() -> void:
	var animals := level.get_node("Animals")
	for child: Node in animals.get_children():
		var a := child as Node3D
		if a == null or a.get_script() != null and not (a.get_script() as Script).resource_path.ends_with("bicho.gd"):
			continue
		var file := a.scene_file_path.get_file()
		if file == "":
			continue
		a.set_script(load("res://world/vida/bicho.gd"))
		if file.begins_with("galinha"):
			a.set("jeito", 1)  # MEDROSO
			a.set("bica", true)
			a.set("raio", 3.0)
			a.set("velocidade", 0.7)
		else:
			# vaca, cavalo, porco de enfeite (sem esqueleto): andam pouco e devagar, sem pular
			a.set("raio", 1.6)
			a.set("velocidade", 0.25)
			a.set("pula", false)
	_animal(animals, "Shiba", PP + "Animated-Animal-Pack/Shiba_Inu.glb", 0.17, Vector3(3.0, 0, 6.0), 2, 12.0, 1.2)
	_animal(animals, "Husky", PP + "Animated-Animal-Pack/Husky.glb", 0.17, Vector3(7.0, 0, -22.0), 2, 10.0, 1.3)
	_animal(animals, "Burro", PP + "Animated-Animal-Pack/Donkey.glb", 0.3, Vector3(60.0, 0, -22.0), 0, 3.0, 0.6)
	var rat := _animal(animals, "Rato", PP + "Animated-Enemies/Rat.glb", 0.22, Vector3(-9.6, 0, -48.7), 1, 2.0, 1.4)
	rat.set("velocidade", 1.4)
	var cat := _animal(animals, "GatoPreguica", "res://world/props/gato.tscn", 1.0, Vector3(5.0, 0, -15.6), 3, 1.5, 0.35)
	cat.set("dorme", true)
	var alley_cat := level.get_node_or_null("BecoLateral/Gato") as Node3D
	if alley_cat:
		alley_cat.set_script(load("res://world/vida/bicho.gd"))
		alley_cat.set("jeito", 3)
		alley_cat.set("raio", 0.05)
		alley_cat.set("dorme", true)


func _animal(parent: Node3D, node_name: String, model: String, size: float, at: Vector3, kind: int, radius: float, speed: float) -> Node3D:
	_remove("Animals/" + node_name)
	var holder := Node3D.new()
	holder.name = node_name
	parent.add_child(holder)
	holder.owner = level
	var body := (load(model) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	body.name = "Modelo"
	holder.add_child(body)
	body.owner = level
	body.scale = Vector3.ONE * size
	if not model.ends_with(".tscn"):
		body.rotation.y = PI  # os bichos do pacote olham para +Z
	holder.global_position = at
	holder.rotation.y = rng.randf() * TAU
	holder.set_script(load("res://world/vida/bicho.gd"))
	holder.set("jeito", kind)
	holder.set("raio", radius)
	holder.set("velocidade", speed)
	return holder


func _pigeons() -> void:
	var parent := _child(level, "Pombos") as Node3D
	parent.global_position = Vector3.ZERO
	for spec: Array in [["Praca", Vector3(0, 0, -11.5), 4.0, 10], ["Feira", Vector3(10.8, 0, -6.0), 2.6, 6],
			["PortaDaPadaria", Vector3(19.4, 0, -3.6), 2.0, 5], ["PracaSul", Vector3(-3, 0, 12), 3.5, 8]]:
		var flock := _child(parent, "Bando" + String(spec[0])) as Node3D
		flock.set_script(load("res://world/vida/pombos.gd"))
		flock.global_position = spec[1]
		flock.set("raio", spec[2])
		flock.set("quantidade", spec[3])


# --- ajudantes ----------------------------------------------------------------------------------------

func _child(parent: Node, child_name: String, spatial: bool = true) -> Node:
	var node := parent.get_node_or_null(child_name)
	if node == null:
		node = Node3D.new() if spatial else Node.new()
		node.name = child_name
		parent.add_child(node)
		node.owner = level
	return node


func _remove(path: String) -> void:
	var node := level.get_node_or_null(path)
	if node:
		node.get_parent().remove_child(node)
		node.free()
