class_name Oficios
## A cara de cada ofício (D063): os moradores são os 5 bonecos do KayKit, e o que diz quem é cada um é a roupa (cor,
## sem chapéu, sem capa) e o que ele carrega: o padeiro de avental branco, chapéu de padeiro e rolo de massa; o ferreiro
## de avental de couro e martelo; o lavrador de chapéu de palha e forcado... O Figurante chama `vestir()` quando monta
## o boneco (Figurante.oficio). Os objetos ficam presos nos ossos (mão, cabeça, quadril, costas) e não vão para o
## arquivo: são refeitos ao abrir.

const PP := "res://assets/kits/polypizza/"
const AV := PP + "_avulsos/"

## Objetos: caminho, comprimento (maior lado, na escala do boneco do KayKit, que tem ~2,2 de altura), ponta para cima?,
## e a pegada na mão: "em_pe" (a ferramenta fica de pé, como quem descansa apoiado) ou "arma" (como as armas do KayKit,
## que acompanham os golpes: o martelo do ferreiro bate na bigorna com o golpe de cima para baixo).
const OBJETOS := {
	"martelo": [AV + "Hammer_Zl38SHi7P9.glb", 0.95, true, "arma"],
	"martelinho": [AV + "Hammer_66FnMJl5fs.glb", 0.7, true],
	"rolo": [PP + "Cooking-Assets/Rolling_Pin.glb", 0.9, true, "arma"],
	"enxada": [PP + "Survival-Kit/Tool_Hoe.glb", 1.5, true],
	"forcado": [AV + "Pitchfork_edEe1ygZiHf.glb", 2.3, false],
	"foice": [PP + "Gorrila-Outlaws/Sickle.glb", 0.8, true],
	"pa": [PP + "Survival-Kit/Shovel.glb", 1.8, true],
	"vassoura": [AV + "Broom_cOMoz6gJFN.glb", 1.8, false],
	"cesto": [AV + "Basket_a0umk-CRRwo.glb", 0.65, true, "pendura"],
	"cesto_macas": [AV + "Basket_of_Apples_-_Game_Asset_62TkD0sShx0.glb", 0.6, true, "pendura"],
	"alaude": [PP + "Pirate-kit/Lute.glb", 1.05, true],
	"tesoura": [PP + "Ultimate-Interior-Props-Pack/Scissors.glb", 0.6, true, "segura"],
	"pocao": [PP + "Fantasy-bundle/Potion_Red.glb", 0.5, true, "segura"],
	"caneca": [AV + "Simple_Wooden_Tankard_b3qGuE7F56q.glb", 0.55, true, "segura"],
	"cajado": [AV + "Shepherd_s_Staff_4OziPMQV37E.glb", 2.0, true],
	"saco": [AV + "Gunny_Sack_fcE0hQK7uEt.glb", 0.95, true],
	"pergaminho": [PP + "Ultimate-RPG-Items-Bundle/Scroll.glb", 0.55, true, "segura"],
	"bolsa": [PP + "Ultimate-RPG-Items-Bundle/Coin_Pouch.glb", 0.35, true, "pendura"],
	"baguete": [PP + "Baked-Goods/Baguette.glb", 0.75, true, "segura"],
	"balde": [PP + "Pirate-kit/Bucket.glb", 0.5, true, "pendura"],
	"livro": [PP + "Fantasy-bundle/Book_Red.glb", 0.55, true, "segura"],
	"chapeu": [PP + "Cosmetic-Pack-Two/Cowboy_Hat.glb", 1.55, true],
}

## Cada ofício: modelo, cor (giro de matiz; -1 = original), sat e val (multiplicam a saturação e o brilho da roupa),
## sem_chapeu, sem_capa, na_mao (objeto do próprio KayKit), e "veste": lista de [coisa, onde, ajuste]. "coisa" é um
## OBJETOS ou um feito aqui: "avental:#cor", "toque" (chapéu de padeiro), "palha" (chapéu de palha).
## "onde": mao, mao_e, cabeca, quadril, costas, ombro. "ajuste": Vector3 extra de posição (opcional).
const LISTA := {
	"padeiro": {"modelo": "Barbarian", "sat": 0.1, "val": 1.4, "sem_chapeu": true, "sem_capa": true,
		"veste": [["toque", "cabeca"], ["avental:#f2ede2", "quadril"], ["rolo", "mao"]]},
	"ferreiro": {"modelo": "Barbarian", "sat": 0.4, "val": 0.5, "sem_chapeu": true, "sem_capa": true,
		"veste": [["avental:#4a3324", "quadril"], ["martelo", "mao"]]},
	"sapateiro": {"modelo": "Rogue", "cor": 0.08, "sat": 0.5, "val": 0.75, "sem_capa": true,
		"veste": [["avental:#6b4a30", "quadril"], ["martelinho", "mao"]]},
	"taverneiro": {"modelo": "Barbarian", "cor": 0.08, "sem_chapeu": true, "sem_capa": true,
		"veste": [["avental:#e8dcc0", "quadril"], ["caneca", "mao"]]},
	"freguês_taverna": {"modelo": "Barbarian", "cor": 0.3, "sem_chapeu": true, "veste": [["caneca", "mao"]]},
	"feirante": {"modelo": "Rogue_Hooded", "cor": 0.55, "sem_capa": true, "veste": [["avental:#4f7a4a", "quadril"]]},
	"feirante2": {"modelo": "Barbarian", "cor": 0.55, "sem_chapeu": true, "sem_capa": true,
		"veste": [["palha", "cabeca"], ["avental:#5a6f9a", "quadril"]]},
	"feirante3": {"modelo": "Rogue_Hooded", "cor": 0.78, "sem_capa": true,
		"veste": [["avental:#8a5a3a", "quadril"], ["cesto_macas", "mao_e"]]},
	"lavrador": {"modelo": "Barbarian", "cor": 0.16, "sat": 0.6, "val": 0.85, "sem_chapeu": true, "sem_capa": true,
		"veste": [["palha", "cabeca"], ["forcado", "mao"]]},
	"lavradora": {"modelo": "Rogue_Hooded", "cor": 0.16, "sat": 0.6, "sem_capa": true, "veste": [["enxada", "mao"]]},
	"fazendeiro": {"modelo": "Rogue", "cor": 0.08, "sat": 0.6, "sem_capa": true, "veste": [["palha", "cabeca"], ["foice", "mao"]]},
	"moleiro": {"modelo": "Barbarian", "sat": 0.1, "val": 1.35, "sem_chapeu": true, "sem_capa": true,
		"veste": [["avental:#efe9da", "quadril"], ["saco", "ombro"]]},
	"carregador": {"modelo": "Barbarian", "cor": 0.08, "sat": 0.5, "sem_chapeu": true, "sem_capa": true, "veste": [["saco", "costas"]]},
	"cavalarico": {"modelo": "Rogue", "cor": 0.45, "sem_capa": true, "veste": [["palha", "cabeca"], ["balde", "mao"]]},
	"guarda": {"modelo": "Knight", "na_mao": "2H_Sword"},
	"padre": {"modelo": "Mage", "sat": 0.2, "val": 0.35, "sem_chapeu": true, "veste": [["livro", "mao"]]},
	"fiel": {"modelo": "Rogue_Hooded", "sat": 0.35, "val": 0.75, "sem_capa": true},
	"viuva": {"modelo": "Rogue_Hooded", "sat": 0.1, "val": 0.3},
	"conselheiro": {"modelo": "Mage", "cor": 0.9, "sem_chapeu": true, "veste": [["pergaminho", "mao"]]},
	"estalajadeira": {"modelo": "Rogue_Hooded", "cor": 0.65, "sem_capa": true, "veste": [["avental:#ece3cf", "quadril"], ["vassoura", "mao"]]},
	"alfaiate": {"modelo": "Rogue", "cor": 0.78, "sat": 1.2, "sem_capa": true, "veste": [["tesoura", "mao"]]},
	"boticaria": {"modelo": "Rogue_Hooded", "cor": 0.3, "veste": [["avental:#dfe6d2", "quadril"], ["pocao", "mao"]]},
	"bardo": {"modelo": "Rogue_Hooded", "cor": 0.9, "sat": 1.2, "veste": [["alaude", "peito"]]},
	"mercador": {"modelo": "Barbarian", "cor": 0.78, "sat": 1.1, "sem_chapeu": true, "veste": [["bolsa", "mao"]]},
	"coveiro": {"modelo": "Rogue_Hooded", "sat": 0.25, "val": 0.55, "veste": [["pa", "mao"]]},
	"leitora": {"modelo": "Mage", "cor": 0.45, "sem_chapeu": true, "na_mao": "Spellbook_open"},
	"mendigo": {"modelo": "Rogue_Hooded", "sat": 0.3, "val": 0.6},
	"viajante": {"modelo": "Rogue_Hooded", "cor": 0.08, "sat": 0.5, "veste": [["cajado", "mao"], ["saco", "costas"]]},
	"velho": {"modelo": "Mage", "sat": 0.35, "val": 0.8, "sem_chapeu": true, "veste": [["cajado", "mao"]]},
	"dona_de_casa": {"modelo": "Rogue_Hooded", "cor": 0.95, "sem_capa": true, "veste": [["avental:#efe6d4", "quadril"], ["cesto", "mao_e"]]},
	"comprador_pao": {"modelo": "Rogue", "cor": 0.3, "sem_capa": true, "veste": [["baguete", "mao_e"]]},
	"aldeao": {"modelo": "Barbarian", "cor": 0.45, "sem_chapeu": true, "sem_capa": true},
	"aldea": {"modelo": "Rogue_Hooded", "cor": 0.65, "sem_capa": true},
	"crianca": {"modelo": "Rogue", "cor": 0.16},
}
## Ofícios de quem anda pela rua sem lugar fixo (Vida): sorteados.
const RUA: Array[String] = ["dona_de_casa", "aldeao", "aldea", "lavrador", "lavradora", "velho", "carregador", "comprador_pao",
	"mercador", "viajante", "fiel", "dona_de_casa", "aldeao", "comprador_pao"]
## Quem mora nas casas (de dia na mesa, de noite na cama): roupa variada, sem nada na mão.
const CASA: Array[String] = ["aldeao", "aldea", "fiel", "viuva", "mendigo", "aldea", "aldeao"]

static var _cache: Dictionary = {}


## Veste o boneco (modelo do KayKit já montado) com as coisas do ofício.
static func vestir(model: Node3D, oficio: String) -> void:
	var spec: Dictionary = LISTA.get(oficio, {})
	if spec.is_empty() or model == null:
		return
	var skeleton := model.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var sk := skeleton[0] as Skeleton3D
	for entry: Array in spec.get("veste", []):
		var what := String(entry[0])
		var where := String(entry[1])
		var extra: Vector3 = entry[2] if entry.size() > 2 else Vector3.ZERO
		var holder := _slot(sk, where)
		if holder == null:
			continue
		var item := _make(what, where)
		if item == null:
			continue
		item.name = "Oficio_" + what.get_slice(":", 0)
		holder.add_child(item)
		item.position += extra


## O lugar no esqueleto: as mãos já têm um anexo no KayKit; cabeça, quadril e peito ganham um.
static func _slot(sk: Skeleton3D, where: String) -> Node3D:
	match where:
		"mao":
			return sk.get_node_or_null("handslot_r") as Node3D
		"mao_e":
			return sk.get_node_or_null("handslot_l") as Node3D
	var bone := {"cabeca": "head", "quadril": "hips", "costas": "chest", "peito": "chest", "ombro": "chest"}.get(where, "") as String
	if bone == "":
		return null
	var key := "Anexo_" + bone
	var found := sk.get_node_or_null(key) as BoneAttachment3D
	if found == null:
		found = BoneAttachment3D.new()
		found.name = key
		found.bone_name = bone
		sk.add_child(found)
	return found


static func _make(what: String, where: String) -> Node3D:
	if what.begins_with("avental:"):
		return _apron(Color(what.get_slice(":", 1)))
	if what == "toque":
		return _chef_hat()
	var key := "chapeu" if what == "palha" else what
	if not OBJETOS.has(key):
		return null
	var spec: Array = OBJETOS[key]
	var hold := String(spec[3]) if spec.size() > 3 else "em_pe"
	if hold in ["segura", "pendura"] and where in ["mao", "mao_e"]:
		return _held(spec, hold)
	var scene := load(String(spec[0])) as PackedScene
	if scene == null:
		return null
	var inner := scene.instantiate() as Node3D
	var holder := Node3D.new()
	holder.add_child(inner)
	var box := _box(inner)
	if box.size == Vector3.ZERO:
		return holder
	if what == "palha":
		_paint(inner, Color("#d6b45e"))
		# chapéu de palha: a copa bem mais baixa que a do chapéu de vaqueiro, aba larga
		var size := float(spec[1]) / maxf(box.size.x, box.size.z)
		var squash := Vector3(size, size * 0.5, size)
		inner.scale = squash
		inner.position = -box.get_center() * squash + Vector3(0, box.size.y * squash.y * 0.5, 0)
		holder.position = Vector3(0, 0.8, -0.02)
		return holder
	# o maior lado vira o eixo Y do anexo (a mão do KayKit segura o cabo ao longo do Y)
	var axis := 0
	if box.size.y >= box.size.x and box.size.y >= box.size.z:
		axis = 1
	elif box.size.z >= box.size.x:
		axis = 2
	var length := box.size[axis]
	var scale := float(spec[1]) / length
	var turn := Basis()
	if axis == 0:
		turn = Basis(Vector3.FORWARD, PI / 2.0)  # x -> y
	elif axis == 2:
		turn = Basis(Vector3.RIGHT, -PI / 2.0)  # z -> y
	if not bool(spec[2]):
		turn = Basis(Vector3.FORWARD, PI) * turn  # a ponta que trabalha fica para cima
	inner.transform = Transform3D(turn.scaled(Vector3.ONE * scale), Vector3.ZERO)
	var placed := _box(inner)
	match where:
		"mao", "mao_e":
			# segura a 25% do comprimento, de baixo para cima (coisa pequena: pelo meio)
			var grip := 0.25 if float(spec[1]) > 0.6 else 0.5
			inner.position = Vector3(-placed.get_center().x, -(placed.position.y + placed.size.y * grip), -placed.get_center().z)
			if hold != "arma":
				holder.rotation_degrees = Vector3(0, 0, 90 if where == "mao" else -90)
		"costas":
			inner.position = -placed.get_center() + Vector3(0, 0.25, -0.55)
		"ombro":
			inner.scale *= 0.62
			inner.position = -_box(inner).get_center() + Vector3(0.42, 0.55, -0.05)
		"peito":
			holder.rotation = Vector3(0.0, 0.0, -0.9)
			inner.position = -placed.get_center() + Vector3(0, 0.0, 0.45)
		_:
			inner.position = -placed.get_center()
	return holder


## Coisa de segurar em pé (caneca, poção, livro) ou pendurada pela alça (cesto, balde, bolsa): fica do jeito que o
## modelo é (em pé), como a caneca do próprio KayKit na mão.
static func _held(spec: Array, hold: String) -> Node3D:
	var inner := (load(String(spec[0])) as PackedScene).instantiate() as Node3D
	var holder := Node3D.new()
	holder.add_child(inner)
	var box := _box(inner)
	var size := float(spec[1]) / maxf(box.size.x, maxf(box.size.y, box.size.z))
	inner.scale = Vector3.ONE * size
	var placed := _box(inner)
	if hold == "pendura":
		inner.position = Vector3(-placed.get_center().x, -placed.end.y + 0.12, -placed.get_center().z)
	else:
		inner.position = -placed.get_center()
		holder.rotation_degrees = Vector3(90, 0, 0)  # a mão do KayKit deitaria a caneca: assim fica em pé
	return holder


static func _box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		var t := mi.transform
		var parent := mi.get_parent() as Node3D
		while parent and parent != node:
			t = parent.transform * t
			parent = parent.get_parent() as Node3D
		t = node.transform * t
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _flat(color: Color) -> StandardMaterial3D:
	var key := "liso|" + color.to_html()
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		_cache[key] = mat
	return _cache[key]


static func _paint(node: Node3D, color: Color) -> void:
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		(found as MeshInstance3D).material_override = _flat(color)


## Avental: um pano curvo que abraça a barriga e desce até o joelho (no quadril do boneco), um pouco mais aberto
## embaixo, com o cós (a faixa da cintura) mais escuro.
static func _apron(color: Color) -> Node3D:
	var holder := Node3D.new()
	holder.add_child(_arc_band(color, -0.24, 0.36, 0.43, 0.49, 1.05))
	holder.add_child(_arc_band(color.darkened(0.3), 0.33, 0.41, 0.43, 0.43, 1.2))
	return holder


## Faixa curva em volta do quadril: de y0 (raio r0) até y1 (raio r1), abrindo `spread` radianos para cada lado.
static func _arc_band(color: Color, y0: float, y1: float, r1: float, r0: float, spread: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 14
	var rows := 6
	var verts: Array[Vector3] = []
	for j: int in rows + 1:
		var t := float(j) / rows
		var y := lerpf(y0, y1, t)
		var r := lerpf(r0, r1, t)
		for i: int in cols + 1:
			var a := lerpf(-spread, spread, float(i) / cols)
			var wave := 0.012 * sin(a * 9.0) * (1.0 - t)  # pregas do pano, mais embaixo
			verts.append(Vector3(sin(a) * (r + wave), y, cos(a) * (r + wave) - 0.02))
	for j: int in rows:
		for i: int in cols:
			var a := j * (cols + 1) + i
			for k: int in [a, a + cols + 1, a + 1, a + 1, a + cols + 1, a + cols + 2]:
				st.add_vertex(verts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := _flat(color).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


## Chapéu de padeiro: a faixa e o "cogumelo" fofo em cima.
static func _chef_hat() -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(0, 0.8, -0.03)
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.42
	cyl.height = 0.32
	band.mesh = cyl
	band.material_override = _flat(Color("#f7f4ec"))
	band.position = Vector3(0, 0.16, 0)
	holder.add_child(band)
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.62
	puff.mesh = sphere
	puff.material_override = _flat(Color("#fbfaf6"))
	puff.position = Vector3(0, 0.48, 0)
	holder.add_child(puff)
	return holder
