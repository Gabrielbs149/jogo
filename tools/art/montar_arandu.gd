extends SceneTree
## Monta Arandu (D044, aumenta a D041): cidade murada de 152 m com portão ao norte, duas avenidas em cruz, uma rua em anel
## e uma praça central de verdade (chafariz numa plataforma com degraus, canteiros, bancos, postes, estátuas, feira, pelourinho).
## Entre o anel e a muralha: estábulo com pasto, moinho com plantação, celeiro da cidade, serraria, jardim da capela e
## o cemitério. Fora da muralha, dos dois lados da estrada: fazendas com celeiros, silo, moinho de pás e trigais.
## Prédios do Medieval Village Pack (estalagem, ferreiro, estábulo, moinho, serraria, guarita, torre do sino) e das
## peças do kit; em cada quarteirão de dentro, um lugar com função (moinho com horta, estábulo com cercado, serraria,
## capela com jardim). Cada prédio é MEDIDO e encostado na rua (nada sai torto); se não couber, não entra.
## Árvores só em grama livre longe das casas, nos canteiros e fora da muralha (nunca na calçada).
## Mantém o que é da história (People, Missoes, Gate, TicoCorner/Look, PlayerSpawn). Depois rode:
##   godot --path . -s tools/art/montar_cena_tico.gd        (cena do rato no beco)
##   godot --headless --path . -s tools/art/montar_missao_padaria.gd   (padeiro e viúva)
## ATENÇÃO: rodar de novo APAGA o que foi mudado à mão em prédios, ruas e decoração.
## Uso (COM janela: a grama é MultiMesh e precisa salvar posições): godot --path . -s tools/art/montar_arandu.gd

const PROPS := "res://world/props/"
const KIT := "res://assets/kits/quaternius/"
const LEVEL := "res://levels/arandu/arandu.tscn"
const ART := "res://levels/arandu/art/"
const AREA := 300.0
const MASK_PX := 1536
const HALF := 76.0  # muralha: quadrado de 152 m
const RING := 44.0  # rua do anel (linha do meio): depois do ferreiro e antes do sapateiro, que são da história
const RING_W := 2.6  # meia largura do anel
const AVE := 5.5  # meia largura das avenidas
const PLAZA := 17.5  # meia largura da praça
## Quanto sobe quem senta no banco da praça (assento a 0,58 m; o "sentado" do KayKit na escala 0,6 senta a ~0,3 m).
const SIT_LIFT := 0.35
## Quanto quem senta vai para a frente (medido: com 0,04 m as pernas caem pela beira do assento).
const SIT_FORWARD := 0.04
## Chaminés das casas do kit (ponto de onde sai a fumaça, no espaço da peça).
const CHIMNEY := {
	"casa": Vector3(1.8, 6.6, 1.4), "casa_barro": Vector3(1.8, 6.6, 1.4), "casa_grande": Vector3(2.8, 9.7, 2.4),
	"casa_grande_barro": Vector3(2.8, 9.7, 2.4), "casa_longa": Vector3(1.8, 6.6, 2.4), "sobrado_longo": Vector3(1.8, 9.7, 2.4),
	"padaria": Vector3(-1.85, 6.5, 2.2),
}

var level: Node3D
var rng := RandomNumberGenerator.new()
var mask: Image
var blocks: Array[Rect2] = []  # chão ocupado (casas, muros, bancas): não nasce grama nem árvore, não entra outro prédio
var houses: Array[Dictionary] = []
var groups := {}
var tico_alley := Rect2()
var spots := {}  # lugares da história e da gente: nome -> Transform3D
var garden_at := Vector3.ZERO  # jardim da capela (a leitora fica lá)
var cemetery_at := Vector3.ZERO
var _smoke_mesh: QuadMesh
var _smoke_process: ParticleProcessMaterial


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = 2041
	(load("res://world/level.gd") as GDScript).set("editing", true)
	level = (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	await physics_frame
	_clear()
	mask = Image.create(MASK_PX, MASK_PX, false, Image.FORMAT_RGB8)
	mask.fill(Color(0, 0, 0))
	_streets()
	_walls()
	_plaza()
	_quarters()
	_farms()
	_town()
	_ring_rows()
	_fill_quarters()
	_street_life()
	_story_spots()
	_crowd()
	_animals()
	_smoke()
	_outside()
	_paint_ground()
	await physics_frame
	level.call("_auto_collision")  # para a grama não nascer dentro das casas novas
	await physics_frame
	_yards()
	_grass()
	_light()
	var packed := PackedScene.new()
	print("pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	quit()


# --- ajudas ---------------------------------------------------------------------------------------

func _group(name: String, nav: bool = true) -> Node3D:
	if groups.has(name):
		return groups[name]
	var found := level.get_node_or_null(name) as Node3D
	if found == null:
		found = Node3D.new()
		found.name = name
		level.add_child(found)
		found.owner = level
		if nav:
			found.add_to_group("nav_source", true)
	groups[name] = found
	return found


func _clear() -> void:
	for name: String in ["Buildings", "Walls", "Market", "Trees", "Rocks", "Props", "Lights", "Places", "Well", "CenaTico", "Grama", "Gardens",
			"Crowd", "Plaza", "Animals", "Smoke", "Cemetery"]:
		var node := level.get_node_or_null(name)
		if node:
			level.remove_child(node)
			node.free()
	var ground := level.get_node("Ground")
	for part: String in ["Square", "Road", "Alley"]:
		var node := ground.get_node_or_null(part)
		if node:
			ground.remove_child(node)
			node.free()
	var corner := level.get_node_or_null("TicoCorner")
	if corner:
		for child: Node in corner.get_children():
			if child.name != &"Look":
				corner.remove_child(child)
				child.free()


func _place(key: String, parent: Node, pos: Vector3, yaw: float = 0.0, size: float = 1.0, node_name: String = "") -> Node3D:
	var piece := (load(PROPS + key + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	if node_name != "":
		piece.name = node_name
	parent.add_child(piece, true)
	piece.owner = level
	piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), pos)
	return piece


func _kit(path: String, parent: Node, pos: Vector3, yaw: float = 0.0, size: float = 1.0, collide: bool = true) -> Node3D:
	var piece := (load(KIT + path + ".gltf") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	parent.add_child(piece, true)
	piece.owner = level
	piece.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), pos)
	if collide:
		piece.add_to_group("colisao_auto", true)
	return piece


func _yaw_facing(front: Vector3) -> float:
	return atan2(-front.x, -front.z)


## Caixa (no chão) de tudo que se vê numa peça já colocada.
func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _rect(box: AABB, shrink: float = 0.0) -> Rect2:
	return Rect2(box.position.x + shrink, box.position.z + shrink, box.size.x - shrink * 2.0, box.size.z - shrink * 2.0)


func _overlaps(r: Rect2) -> bool:
	for b: Rect2 in blocks:
		if b.intersects(r):
			return true
	return false


func _block_rect(r: Rect2, margin: float = 0.6) -> void:
	blocks.append(r.grow(margin))


func _block(center: Vector3, size: Vector2, margin: float = 0.6) -> void:
	_block_rect(Rect2(center.x - size.x / 2.0, center.z - size.y / 2.0, size.x, size.y), margin)


func _free_at(p: Vector3, margin: float = 0.0) -> bool:
	for r: Rect2 in blocks:
		if p.x > r.position.x - margin and p.x < r.end.x + margin and p.z > r.position.y - margin and p.z < r.end.y + margin:
			return false
	return true


func _mask_at(p: Vector3) -> Color:
	var px := clampi(int((p.x / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	var pz := clampi(int((p.z / AREA + 0.5) * MASK_PX), 0, MASK_PX - 1)
	return mask.get_pixel(px, pz)


## Pinta a máscara do chão: canal 0 = terra (R), 1 = calçada (G). Retângulo em metros (x, z).
func _paint_rect(r: Rect2, channel: int) -> void:
	var a := Vector2i(int((r.position.x / AREA + 0.5) * MASK_PX), int((r.position.y / AREA + 0.5) * MASK_PX))
	var b := Vector2i(int((r.end.x / AREA + 0.5) * MASK_PX), int((r.end.y / AREA + 0.5) * MASK_PX))
	for x: int in range(maxi(a.x, 0), mini(b.x + 1, MASK_PX)):
		for z: int in range(maxi(a.y, 0), mini(b.y + 1, MASK_PX)):
			var c := mask.get_pixel(x, z)
			c[channel] = 1.0
			mask.set_pixel(x, z, c)


func _paint_disc(center: Vector2, radius: float, channel: int) -> void:
	var px_per_m := MASK_PX / AREA
	var cx := int((center.x / AREA + 0.5) * MASK_PX)
	var cz := int((center.y / AREA + 0.5) * MASK_PX)
	var rp := int(radius * px_per_m) + 1
	for x: int in range(maxi(cx - rp, 0), mini(cx + rp + 1, MASK_PX)):
		for z: int in range(maxi(cz - rp, 0), mini(cz + rp + 1, MASK_PX)):
			var world := Vector2((float(x) / MASK_PX - 0.5) * AREA, (float(z) / MASK_PX - 0.5) * AREA)
			if world.distance_to(center) <= radius:
				var c := mask.get_pixel(x, z)
				c[channel] = 1.0
				mask.set_pixel(x, z, c)


## Caminho de terra de a até b (pontos no chão), largura w.
func _path(a: Vector2, b: Vector2, w: float) -> void:
	var steps := int(a.distance_to(b) / 0.6) + 1
	for i: int in steps + 1:
		_paint_disc(a.lerp(b, float(i) / steps), w / 2.0, 0)


# --- ruas -----------------------------------------------------------------------------------------

func _streets() -> void:
	# avenidas de pedra em cruz, do portão (norte) até a muralha do sul e de leste a oeste; praça de pedra no meio
	_paint_rect(Rect2(-AVE, -HALF - 1, AVE * 2, HALF * 2 + 1), 1)
	_paint_rect(Rect2(-HALF, -AVE, HALF * 2, AVE * 2), 1)
	_paint_rect(Rect2(-PLAZA, -PLAZA, PLAZA * 2, PLAZA * 2), 1)
	# rua do anel: as quatro ruas que ligam as avenidas no meio do caminho até a muralha (nada é construído em cima)
	for sgn: float in [-1.0, 1.0]:
		for r: Rect2 in [Rect2(-RING - RING_W, sgn * RING - RING_W, (RING + RING_W) * 2.0, RING_W * 2.0),
				Rect2(sgn * RING - RING_W, -RING - RING_W, RING_W * 2.0, (RING + RING_W) * 2.0)]:
			_paint_rect(r, 1)
			_block_rect(r, 0.2)
	# estrada de terra que chega ao portão
	_paint_rect(Rect2(-3.4, -AREA / 2.0, 6.8, AREA / 2.0 - HALF), 0)


# --- muralha -------------------------------------------------------------------------------------

func _wall_run(a: Vector3, b: Vector3) -> void:
	# pedaços de muro de 6 m e, no que sobrar, paredes de 2 m do kit (sempre múltiplo de 2)
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var mid := (a + b) / 2.0
	var outward := Vector3(signf(mid.x), 0, 0) if absf(dir.z) > 0.5 else Vector3(0, 0, signf(mid.z))
	var yaw := atan2(outward.x, outward.z)  # a face de pedra do kit (+Z) fica para fora
	var at := 0.0
	while length - at >= 6.0 - 0.01:
		_place("muro", _group("Walls"), a + dir * (at + 3.0), yaw)
		_place("muro", _group("Walls"), a + dir * (at + 3.0) - outward * 0.42, yaw + PI, 1.0, "MuroDentro")
		at += 6.0
	while length - at >= 2.0 - 0.01:
		_kit("vila/Wall_UnevenBrick_Straight", _group("Walls"), a + dir * (at + 1.0), yaw)
		_kit("vila/Wall_UnevenBrick_Straight", _group("Walls"), a + dir * (at + 1.0) - outward * 0.42, yaw + PI)
		at += 2.0
	var c := (a + b) / 2.0
	_block(c, Vector2(length, 1.6) if absf(dir.x) > 0.5 else Vector2(1.6, length), 0.6)


func _walls() -> void:
	var h := HALF
	for corner: Vector3 in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]:
		_place("torre", _group("Walls"), corner, 0.0, 1.0, "Torre")
		_block(corner, Vector2(4, 4))
	for x: float in [-3.0, 3.0]:
		_place("torre", _group("Walls"), Vector3(x, 0, -h), 0.0, 1.0, "TorreDoPortao")
	_block(Vector3(0, 0, -h), Vector2(10, 4), 0.2)
	_kit("vila/Wall_Arch", _group("Walls"), Vector3(0, 0, -h))
	_kit("vila/Wall_Arch", _group("Walls"), Vector3(0, 0, -h + 0.35), PI)
	# uma torre a cada quarto de lado (ritmo, e não um muro reto e vazio); no meio do lado norte fica o portão
	var marks: Array[float] = [-h, -h / 2.0, 0.0, h / 2.0, h]
	for side: int in 4:
		for i: int in marks.size() - 1:
			var gate_a := side == 0 and is_zero_approx(marks[i])
			var gate_b := side == 0 and is_zero_approx(marks[i + 1])
			_wall_run(_side_point(side, marks[i] + (5.0 if gate_a else 2.0)), _side_point(side, marks[i + 1] - (5.0 if gate_b else 2.0)))
		for t: float in [-h / 2.0, 0.0, h / 2.0]:
			if side == 0 and is_zero_approx(t):
				continue
			var at := _side_point(side, t)
			_place("torre", _group("Walls"), at, PI / 2.0 if side >= 2 else 0.0, 1.0, "TorreDoMeio")
			_block(at, Vector2(4, 4))
	for x: float in [-5.2, 5.2]:
		_place("estandarte", _group("Walls"), Vector3(x, 0.4, -h + 2.35), 0.0, 1.0, "Estandarte")
		_place("tocha", _group("Lights", false), Vector3(x * 0.42, 2.2, -h + 0.6), 0.0, 1.0, "TochaDoPortao")
		# postes de lanterna dos dois lados do portão, por dentro e por fora (de noite o portão é escuro)
		for z: float in [-h + 3.4, -h - 3.0]:
			_place("poste_lanterna", _group("Lights", false), Vector3(x * 0.85, 0, z), _yaw_facing(Vector3(-signf(x), 0, 0)), 1.0, "PosteDoPortao")


## Ponto da muralha: lado 0 = norte (portão), 1 = sul, 2 = oeste, 3 = leste; t = posição ao longo do lado.
func _side_point(side: int, t: float) -> Vector3:
	match side:
		0:
			return Vector3(t, 0, -HALF)
		1:
			return Vector3(t, 0, HALF)
		2:
			return Vector3(-HALF, 0, t)
	return Vector3(HALF, 0, t)


# --- praça: o centro da cidade -------------------------------------------------------------------------

func _plaza() -> void:
	var plaza := _group("Plaza")
	_place("chafariz", plaza, Vector3.ZERO, 0.0, 1.0, "Chafariz")
	_block(Vector3.ZERO, Vector2(13, 13), 0.4)
	# quatro canteiros com árvore nas diagonais, bancos virados para o chafariz entre eles
	for i: int in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var at := Vector3(cos(a), 0, sin(a)) * 11.5
		_place("canteiro", plaza, at, rng.randf() * TAU, 1.0, "Canteiro")
		_block(at, Vector2(3.6, 3.6), 0.2)
		for side: float in [-1.0, 1.0]:
			var b := a + side * 0.42
			var bench := Vector3(cos(b), 0, sin(b)) * 9.2
			_place("banco_praca", plaza, bench, _yaw_facing(-bench.normalized()) + PI, 1.0, "Banco")
			_block(bench, Vector2(2.2, 2.2), 0.0)
			spots["banco_%d_%d" % [i, int(side)]] = Transform3D(Basis(Vector3.UP, _yaw_facing(-bench.normalized())), bench + Vector3.UP * SIT_LIFT - bench.normalized() * SIT_FORWARD)
	# postes de luz em volta (8) e nas entradas da praça
	for i: int in 8:
		var a := PI / 8.0 + i * PI / 4.0
		var at := Vector3(cos(a), 0, sin(a)) * 14.2
		_place("poste", _group("Lights", false), at, 0.0, 1.0, "PostePraca")
		_block(at, Vector2(0.6, 0.6), 0.0)
	# estátuas guardando as entradas do norte e do sul
	for spot: Array in [[Vector3(-7.0, 0, -PLAZA + 1.2), 0.0], [Vector3(7.0, 0, -PLAZA + 1.2), 0.0], [Vector3(-7.0, 0, PLAZA - 1.2), PI],
			[Vector3(7.0, 0, PLAZA - 1.2), PI]]:
		_place("estatua", plaza, spot[0], spot[1] + PI, 1.0, "Estatua")
		_block(spot[0], Vector2(1.8, 1.8), 0.2)
	# feira no lado leste da praça, bancas viradas para o chafariz
	var stalls: Array[String] = ["banca_frutas", "banca_verduras", "banca_paes", "banca_peixe"]
	for k: int in stalls.size():
		var at := Vector3(PLAZA - 2.6, 0, -9.0 + k * 6.0)
		_place(stalls[k], _group("Market"), at, _yaw_facing(Vector3.LEFT), 1.0, "Banca")
		_block(at, Vector2(3.6, 5.0), 0.2)
		spots["feira_%d" % k] = Transform3D(Basis(Vector3.UP, _yaw_facing(Vector3.RIGHT)), at + Vector3(-2.6, 0, 0.6))
	_place("carroca_feira", _group("Market"), Vector3(PLAZA - 2.4, 0, 12.6), _yaw_facing(Vector3.LEFT) + 0.3, 1.0, "Carroca")
	_block(Vector3(PLAZA - 2.4, 0, 12.6), Vector2(3.4, 3.4), 0.2)
	for k: int in 5:
		var at := Vector3(PLAZA - 0.9, 0, -12.2 + k * 5.5)
		_place(["barril", "caixote", "caixote_macas", "barris", "cesto"][k], _group("Market"), at, rng.randf() * TAU)
	# do lado oeste: pelourinho e o mural de avisos; a torre do sino fica na esquina sudoeste
	_place("pelourinho", plaza, Vector3(-PLAZA + 3.0, 0, -9.5), 0.6, 1.0, "Pelourinho")
	_block(Vector3(-PLAZA + 3.0, 0, -9.5), Vector2(2, 2), 0.2)
	_place("placa_rua1", plaza, Vector3(-PLAZA + 2.4, 0, 9.0), PI / 2.0, 1.0, "Placa")
	# placas de direção nas entradas
	for spot: Array in [[Vector3(9.4, 0, -PLAZA + 1.0), PI], [Vector3(-9.4, 0, PLAZA - 1.0), 0.0]]:
		_place("placa_rua1", plaza, spot[0], spot[1], 1.0, "PlacaDirecao")
	_block_rect(Rect2(-PLAZA, -PLAZA, PLAZA * 2.0, PLAZA * 2.0), 0.0)


# --- casas nas ruas --------------------------------------------------------------------------------------

## Uma fileira de prédios com a frente na beira da rua. Cada um é medido e encostado: a frente fica a `setback`
## da linha `start` (beira da rua), um do lado do outro ao longo de `along`. lots: ["chave", "Nome"] ou ["vão", m].
## Prédio que bateria em outro é deixado de fora.
func _row(start: Vector3, along: Vector3, front: Vector3, lots: Array, setback: float = 0.3) -> void:
	var cursor := 0.0
	var yaw := _yaw_facing(front)
	for lot: Array in lots:
		if lot[0] == "vão":
			var gap: float = lot[1]
			if lot.size() > 2 and lot[2] == "beco_tico":
				var a := start + along * cursor
				var b := start + along * (cursor + gap) - front * 7.0
				tico_alley = Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))
			cursor += gap
			continue
		var key: String = lot[0]
		var house := _place(key, _group("Buildings"), Vector3.ZERO, yaw, 1.0, lot[1] if lot.size() > 1 else "")
		var box := _aabb(house)
		var width := absf(box.size.dot(along.abs()))
		var depth := absf(box.size.dot(front.abs()))
		var target := start + along * (cursor + width / 2.0) - front * (depth / 2.0 + setback)
		var shift := target - box.get_center()
		shift.y = 0.0
		house.position += shift
		var rect := _rect(AABB(box.position + shift, box.size), 0.1)
		if _overlaps(rect):
			print("não coube: ", key, " ", lot[1] if lot.size() > 1 else "", " em ", target.snapped(Vector3.ONE * 0.1))
			house.get_parent().remove_child(house)
			house.free()
			cursor += width + 0.4
			continue
		_block_rect(rect, 0.4)
		houses.append({"node": house, "key": key, "center": house.position, "front": front, "along": along, "size": Vector2(width, depth),
			"door": start + along * (cursor + width / 2.0) - front * setback})
		cursor += width + 0.4


func _town() -> void:
	var n := Vector3.FORWARD  # -Z: norte
	var s := Vector3.BACK
	var e := Vector3.RIGHT
	var w := Vector3.LEFT
	# Cada esquina da praça tem um dono só (as fileiras não disputam o mesmo chão):
	# avenida do portão, lado oeste: do portão até a praça (casa da viúva, beco do Tico, sapateiro, alfaiate)
	_row(Vector3(-AVE, 0, -HALF + 2.4), s, e, [["casa_estreita", "CasaDoPortao"], ["casa", "CasaDaViuva"], ["vão", 3.2, "beco_tico"],
		["casa_estreita_pedra", "Sapateiro"]])
	# avenida do portão, lado leste: guarita e uma casa; a esquina com a praça é da estalagem
	_row(Vector3(AVE, 0, -HALF + 2.4), s, w, [["guarita", "Guarita"], ["casa_estreita_pedra", ""]])
	_row(Vector3(AVE + 0.6, 0, -PLAZA), e, s, [["estalagem", "Estalagem"]])
	# lado oeste da praça: casa do conselho (norte) e do mercador (sul)
	_row(Vector3(-PLAZA, 0, -PLAZA + 0.4), s, e, [["sobrado_longo", "CasaDoConselho"], ["casa_estreita", ""]])
	_row(Vector3(-PLAZA, 0, AVE + 1.0), s, e, [["casa_grande", "CasaDoMercador"]])
	# lado sul da praça: capela (oeste) e taverna (leste)
	_row(Vector3(-PLAZA, 0, PLAZA), e, n, [["casa_longa", "Capela"], ["casa_estreita_pedra", ""]])
	_row(Vector3(AVE + 0.6, 0, PLAZA), e, n, [["casa_grande_barro", "Taverna"], ["casa_estreita", ""]])
	# avenida do leste: padaria (missão da fome) e ferreiro do lado norte, casas do lado sul
	_row(Vector3(PLAZA + 0.6, 0, -AVE), e, s, [["padaria", "Padaria"], ["ferreiro", "Ferreiro"]])
	_row(Vector3(PLAZA + 0.6, 0, AVE), e, n, [["casa_enxaimel2", ""], ["casa_barro", ""], ["casa_estreita_pedra", ""]])
	# avenida do oeste: depois das casas da beira da praça
	_row(Vector3(-PLAZA - 11.0, 0, -AVE), w, s, [["casa", ""], ["casa_estreita", ""]])
	_row(Vector3(-PLAZA - 11.0, 0, AVE), w, n, [["casa_barro", ""]])
	# avenida do sul: depois da capela e da taverna
	_row(Vector3(-AVE, 0, PLAZA + 11.0), s, e, [["casa", ""], ["casa_estreita", ""]])
	_row(Vector3(AVE, 0, PLAZA + 11.0), s, w, [["casa_enxaimel2", ""], ["casa_estreita_pedra", ""]])
	# torre do sino na esquina sudoeste da praça
	var bell := _place("torre_sino", _group("Buildings"), Vector3(-PLAZA - 3.8, 0, PLAZA + 3.8), _yaw_facing(Vector3(1, 0, -1).normalized()), 1.0, "Campanario")
	var bb := _aabb(bell)
	if _overlaps(_rect(bb, 0.2)):
		bell.get_parent().remove_child(bell)
		bell.free()
	else:
		_block_rect(_rect(bb), 0.3)
	# 2ª passada: as mesmas fileiras seguem até a muralha (os lotes de antes batem neles mesmos e ficam de fora;
	# o resto entra depois deles, desviando do anel e dos lugares grandes)
	_row(Vector3(-AVE, 0, -HALF + 2.4), s, e, [["casa_estreita", ""], ["casa", ""], ["vão", 3.2], ["casa_estreita_pedra", ""], ["casa_barro", ""],
		["vão", 1.2], ["casa_longa", ""], ["casa_estreita", ""], ["casa", ""], ["casa_enxaimel2", ""], ["vão", 1.6], ["casa_estreita_pedra", ""]])
	_row(Vector3(AVE, 0, -HALF + 2.4), s, w, [["guarita", ""], ["casa_estreita_pedra", ""], ["casa_pedra", ""], ["vão", 1.4], ["casa", ""],
		["casa_estreita", ""], ["sobrado_longo", ""], ["casa_barro", ""]])
	_row(Vector3(PLAZA + 0.6, 0, -AVE), e, s, [["padaria", ""], ["ferreiro", ""], ["casa_estreita", ""], ["casa_grande", ""],
		["casa_estreita_pedra", ""], ["casa", ""]])
	_row(Vector3(PLAZA + 0.6, 0, AVE), e, n, [["casa_enxaimel2", ""], ["casa_barro", ""], ["casa_estreita_pedra", ""], ["casa_pedra", ""],
		["vão", 1.4], ["casa_longa", ""], ["casa_estreita", ""], ["casa_enxaimel", ""]])
	_row(Vector3(-PLAZA - 11.0, 0, -AVE), w, s, [["casa", ""], ["casa_estreita", ""], ["casa_grande_barro", ""], ["vão", 1.2],
		["casa_estreita_pedra", ""], ["casa", ""], ["casa_pedra", ""]])
	_row(Vector3(-PLAZA - 11.0, 0, AVE), w, n, [["casa_barro", ""], ["casa_enxaimel2", ""], ["casa_estreita", ""], ["sobrado_longo", ""],
		["casa_estreita_pedra", ""]])
	_row(Vector3(-AVE, 0, PLAZA + 11.0), s, e, [["casa", ""], ["casa_estreita", ""], ["casa_grande", ""], ["casa_estreita_pedra", ""],
		["vão", 1.4], ["casa_barro", ""], ["casa_enxaimel", ""]])
	_row(Vector3(AVE, 0, PLAZA + 11.0), s, w, [["casa_enxaimel2", ""], ["casa_estreita_pedra", ""], ["casa_longa", ""], ["casa_pedra", ""],
		["casa_estreita", ""], ["casa", ""]])
	# coisas na frente das casas: barris, caixotes, flores, lanternas e placas
	var small: Array[String] = ["barril", "caixote", "cesto", "balde", "vaso", "caixote_macas", "banquinho", "barril_vinho"]
	for h: Dictionary in houses:
		var f: Vector3 = h["front"]
		var a: Vector3 = h["along"]
		var size: Vector2 = h["size"]
		var door: Vector3 = h["door"]
		var key: String = h["key"]
		if key in ["estalagem", "ferreiro", "estabulo", "guarita"]:
			continue  # já vêm com as coisas deles
		if rng.randf() < 0.7:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			_place(small[rng.randi() % small.size()], _group("Props"), door + f * 0.55 + a * side * (size.x / 2.0 - 0.6), rng.randf() * TAU)
		if rng.randf() < 0.5:
			_place("lanterna", _group("Lights", false), door - f * 0.25 + a * 1.25 + Vector3.UP * 2.75, _yaw_facing(f))
		if rng.randf() < 0.35:
			_place("flores", _group("Gardens", false), door + f * 0.6 - a * (size.x / 2.0 - 0.4), rng.randf() * TAU, 0.45)


## Casas dos dois lados da rua do anel, de frente para ela; cada trecho entre uma avenida e a esquina tem a sua fileira.
func _ring_rows() -> void:
	var kinds: Array[String] = ["casa", "casa_estreita", "casa_barro", "casa_estreita_pedra", "casa_enxaimel", "casa_enxaimel2", "casa_longa",
		"casa_pedra", "sobrado_longo", "casa_grande"]
	for sgn: float in [-1.0, 1.0]:
		for half: float in [-1.0, 1.0]:
			var along_x := Vector3(half, 0, 0)
			var along_z := Vector3(0, 0, half)
			# trechos norte e sul (z = ±RING): lado de fora e lado de dentro
			_row(Vector3(half * (AVE + 0.6), 0, sgn * (RING + RING_W)), along_x, Vector3(0, 0, -sgn), _lots(kinds, 6))
			_row(Vector3(half * (AVE + 0.6), 0, sgn * (RING - RING_W)), along_x, Vector3(0, 0, sgn), _lots(kinds, 5))
			# trechos oeste e leste (x = ±RING)
			_row(Vector3(sgn * (RING + RING_W), 0, half * (AVE + 0.6)), along_z, Vector3(-sgn, 0, 0), _lots(kinds, 6))
			_row(Vector3(sgn * (RING - RING_W), 0, half * (AVE + 0.6)), along_z, Vector3(sgn, 0, 0), _lots(kinds, 5))


## Lista de lotes sorteados (com um beco de vez em quando).
func _lots(kinds: Array[String], count: int) -> Array:
	var lots: Array = []
	for k: int in count:
		lots.append([kinds[rng.randi() % kinds.size()], ""])
		if rng.randf() < 0.25:
			lots.append(["vão", rng.randf_range(1.2, 2.6)])
	return lots


# --- lugares grandes entre o anel e a muralha ------------------------------------------------------------

## Põe um prédio grande centrado em `center`, de frente para `front`; devolve o nó (ou null se não couber).
func _landmark(key: String, center: Vector3, front: Vector3, label: String) -> Node3D:
	var piece := _place(key, _group("Buildings"), Vector3.ZERO, _yaw_facing(front), 1.0, label)
	var box := _aabb(piece)
	var shift := center - box.get_center()
	shift.y = 0.0
	piece.position += shift
	var rect := _rect(AABB(box.position + shift, box.size), 0.2)
	if _overlaps(rect):
		print("não coube: ", label)
		piece.get_parent().remove_child(piece)
		piece.free()
		return null
	_block_rect(rect, 0.5)
	return piece


## Caminho de terra reto (de a até b) que fica reservado: casa nenhuma nasce em cima dele.
func _lane(a: Vector2, b: Vector2, w: float) -> void:
	_path(a, b, w)
	_block_rect(Rect2(minf(a.x, b.x) - w / 2.0, minf(a.y, b.y) - w / 2.0, absf(a.x - b.x) + w, absf(a.y - b.y) + w), 0.2)


func _quarters() -> void:
	var far := (HALF + RING + RING_W) / 2.0  # ~51,4: meio da faixa entre o anel e a muralha
	var mid := (RING + AVE) / 2.0 + 1.0  # ~21,8: meio do trecho entre a avenida e o anel
	var edge := RING + RING_W  # beira de fora do anel
	# leste, metade norte: estábulo de frente para o anel; no canto nordeste, o pasto cercado
	var stable := _landmark("estabulo", Vector3(far, 0, -mid), Vector3.LEFT, "Estabulo")
	if stable:
		_lane(Vector2(edge, -mid), Vector2(far - 7.0, -mid), 3.4)
	_pasture(Vector3(far + 1.0, 0, -far - 1.0), [["cavalo", 2], ["vaca", 2], ["porco", 1]])
	# norte, metade oeste: moinho de frente para o anel; plantação no canto noroeste
	var mill := _landmark("moinho", Vector3(-mid, 0, -far), Vector3.BACK, "Moinho")
	if mill:
		_lane(Vector2(-mid, -edge), Vector2(-mid, -far + 6.0), 3.0)
	_crops(Vector3(-far - 7.0, 0, -far - 7.0), 5, 6)
	_wheat_field(Rect2(-far - 8.0, -far + 3.0, 14.0, 7.0), "TrigoDoMoinho")
	# norte, metade leste: celeiro da cidade (silo com depósito e galpão aberto), com feno e sacos
	var granary := _landmark("silo_casa", Vector3(mid - 3.0, 0, -far), Vector3.BACK, "CeleiroDaCidade")
	if granary:
		_lane(Vector2(mid - 3.0, -edge), Vector2(mid - 3.0, -far + 3.0), 3.0)
		var shed := _landmark("celeiro_aberto", Vector3(mid + 8.0, 0, -far - 0.5), Vector3.BACK, "Galpao")
		if shed:
			for k: int in 3:
				_place(["feno", "sacos", "fardos"][k], _group("Props"), Vector3(mid + 5.0 + k * 2.6, 0, -far + 5.6), rng.randf() * TAU)
	# leste, metade sul: serraria de frente para o anel, com toras e caixotes
	var saw := _landmark("serraria", Vector3(far, 0, mid), Vector3.LEFT, "Serraria")
	if saw:
		_lane(Vector2(edge, mid), Vector2(far - 6.0, mid), 3.2)
		_kit("objetos/Barrel", _group("Props"), Vector3(far - 6.5, 0, mid - 5.0), 0.0)
		_place("caixote_alto", _group("Props"), Vector3(far - 6.8, 0, mid - 3.6), 0.3)
	# canto sudeste: torre de vigia e uma carroça velha
	var watch := Vector3(far + 3.0, 0, far + 3.0)
	_place("torre_vigia", _group("Buildings"), watch, PI / 4.0, 1.0, "TorreDeVigia")
	_block(watch, Vector2(4.4, 4.4), 0.4)
	_place("carroca_quebrada", _group("Props"), watch + Vector3(-6.0, 0, -2.0), 0.7, 1.0, "CarrocaVelha")
	_block(watch + Vector3(-6.0, 0, -2.0), Vector2(4, 4), 0.2)
	# sul, metade oeste: jardim da capela (poço com telhado, canteiros, coreto e a estátua do cervo)
	garden_at = Vector3(-mid, 0, far)
	_lane(Vector2(-mid, edge), Vector2(-mid, far - 4.0), 3.0)
	_paint_disc(Vector2(garden_at.x, garden_at.z), 4.2, 1)
	_place("poco_telhado", _group("Plaza"), garden_at, 0.4, 1.0, "PocoDoJardim")
	_block(garden_at, Vector2(3.4, 3.4), 0.2)
	for k: int in 4:
		var a := k * PI / 2.0 + PI / 4.0
		var at := garden_at + Vector3(cos(a), 0, sin(a)) * 6.4
		if _free_at(at, 1.4):
			_place("canteiro", _group("Plaza"), at, rng.randf() * TAU, 0.9, "CanteiroJardim")
			_block(at, Vector2(3.4, 3.4), 0.2)
	var gazebo_at := garden_at + Vector3(9.5, 0, 2.0)
	_place("gazebo", _group("Plaza"), gazebo_at, _yaw_facing(Vector3.LEFT), 1.0, "Coreto")
	_block(gazebo_at, Vector2(5.0, 5.0), 0.3)
	_place("estatua_cervo", _group("Plaza"), garden_at + Vector3(0, 0, 8.0), PI, 1.0, "EstatuaDoCervo")
	_block(garden_at + Vector3(0, 0, 8.0), Vector2(2.6, 2.0), 0.3)
	# canto sudoeste: o cemitério, com a entrada virada para o jardim
	cemetery_at = Vector3(-far - 1.0, 0, far + 1.0)
	_cemetery(cemetery_at)


## Pasto cercado (cerca de 6 m, abertura no lado oeste) com bichos soltos dentro.
func _pasture(center: Vector3, animals: Array) -> void:
	var half := 8.85  # 3 tábuas de 5,9 m por lado
	for side: int in 4:
		for k: int in 3:
			if side == 2 and k == 1:
				continue  # porteira
			var t := -half + 2.95 + k * 5.9
			var at: Vector3
			var yaw := 0.0
			match side:
				0:
					at = center + Vector3(t, 0, -half)
				1:
					at = center + Vector3(t, 0, half)
				2:
					at = center + Vector3(-half, 0, t)
					yaw = PI / 2.0
				_:
					at = center + Vector3(half, 0, t)
					yaw = PI / 2.0
			_place("cerca_fazenda", _group("Props"), at, yaw, 1.0, "CercaDoPasto")
	_block(center, Vector2(half * 2.0, half * 2.0), 0.4)
	var holder := _group("Animals", false)
	for pair: Array in animals:
		for n: int in int(pair[1]):
			_place(String(pair[0]), holder, center + Vector3(rng.randf_range(-half + 2.0, half - 2.0), 0, rng.randf_range(-half + 2.0, half - 2.0)),
				rng.randf() * TAU)


## Cemitério: grade de ferro em volta, portão no lado leste, caminho de pedras até a cripta (lado oeste),
## fileiras de lápides, pinheiros de outono nos cantos, santuários e lanternas.
func _cemetery(center: Vector3) -> void:
	var holder := _group("Cemetery")
	var half := 9.0
	var front := Vector3.RIGHT
	for side: int in 4:
		for k: int in 6:
			var t := -half + 1.5 + k * 3.0
			if side == 3 and (k == 2 or k == 3):
				continue  # vão do portão
			var at: Vector3
			var yaw := 0.0
			match side:
				0:
					at = center + Vector3(t, 0, -half)
				1:
					at = center + Vector3(t, 0, half)
				2:
					at = center + Vector3(-half, 0, t)
					yaw = PI / 2.0
				_:
					at = center + Vector3(half, 0, t)
					yaw = PI / 2.0
			var piece := "grade_cemiterio_quebrada" if rng.randf() < 0.15 else "grade_cemiterio"
			_place(piece, holder, at, yaw, 1.0, "Grade")
	for corner: Vector3 in [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(-half, 0, half), Vector3(half, 0, half)]:
		_place("pilar_grade", holder, center + corner, 0.0, 1.0, "Pilar")
	_place("portao_cemiterio", holder, center + Vector3(half, 0, 0), PI / 2.0, 1.0, "Portao")
	for z: float in [-2.6, 2.6]:
		_place("poste_lanterna", _group("Lights", false), center + Vector3(half + 1.2, 0, z), _yaw_facing(front), 1.0, "LanternaDoCemiterio")
	# caminho de pedras do portão até a cripta
	var crypt_at := center + Vector3(-half + 4.2, 0, 0)
	_place("cripta", holder, crypt_at, _yaw_facing(front), 1.0, "Cripta")
	var x := half - 1.0
	while x > -half + 7.0:
		_place("caminho_pedras", holder, center + Vector3(x, 0.01, rng.randf_range(-0.15, 0.15)), rng.randf() * TAU, 1.0, "Pedras")
		x -= 1.9
	_place("santuario_velas", holder, crypt_at + Vector3(3.8, 0, -3.0), 0.0, 1.0, "Santuario")
	_place("santuario", holder, crypt_at + Vector3(3.8, 0, 3.0), 0.0, 1.0, "Santuario")
	# lápides em fileiras dos dois lados do caminho, viradas para o caminho
	var stones: Array[String] = ["lapide", "lapide", "lapide2", "tumulo", "tumulo_rachado", "cruz", "cruz2"]
	for row_z: float in [-6.4, -3.6, 3.6, 6.4]:
		var gx := -half + 8.6
		while gx < half - 1.6:
			if rng.randf() < 0.85:
				var face := Vector3(0, 0, -signf(row_z))
				_place(stones[rng.randi() % stones.size()], holder, center + Vector3(gx + rng.randf_range(-0.2, 0.2), 0, row_z),
					_yaw_facing(face) + rng.randf_range(-0.12, 0.12), 1.0, "Lapide")
			gx += 2.4
	for corner: Vector3 in [Vector3(-half + 1.8, 0, -half + 1.8), Vector3(-half + 1.8, 0, half - 1.8)]:
		_place(["pinheiro_outono", "pinheiro_outono2"][rng.randi() % 2], _group("Trees"), center + corner, rng.randf() * TAU, 0.9, "PinheiroDoCemiterio")
	_place("arvore_seca_galhos", _group("Trees"), center + Vector3(half - 2.0, 0, half - 2.0), 0.8, 1.0, "ArvoreSeca")
	_place("velas", holder, crypt_at + Vector3(3.0, 0, 0.9), 0.0, 1.0, "Velas")
	_block(center, Vector2(half * 2.0 + 1.0, half * 2.0 + 1.0), 0.6)
	_lane(Vector2(center.x + half + 1.0, center.z), Vector2(garden_at.x - 4.0, center.z), 2.4)


## Trigal: uma MultiMesh só (milhares de pés de trigo com um desenho só), em fileiras com terra entre elas.
func _wheat_field(r: Rect2, label: String) -> void:
	var path := ART + "trigo_malha.res"
	# a malha do modelo vem em centímetros e deitada: a escala e o giro estão nos nós do .glb (vão junto em cada pé)
	var scene := (load("res://assets/kits/polypizza/Avulsos/Wheat_lPspzfC8Pu.glb") as PackedScene).instantiate()
	var source := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var base := Transform3D()
	var node: Node = source
	while node != scene and node is Node3D:
		base = (node as Node3D).transform * base
		node = node.get_parent()
	if not ResourceLoader.exists(path):
		DirAccess.make_dir_recursive_absolute(ART)
		ResourceSaver.save(source.mesh, path)
	scene.free()
	var list: Array[Transform3D] = []
	var z := r.position.y + 0.4
	while z < r.end.y - 0.3:
		_paint_rect(Rect2(r.position.x, z - 0.35, r.size.x, 0.7), 0)
		var x := r.position.x + 0.3
		while x < r.end.x - 0.3:
			for k: int in 3:
				var p := Vector3(x + rng.randf_range(-0.12, 0.12), 0, z + rng.randf_range(-0.22, 0.22))
				var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.12))
				list.append(Transform3D(tilt * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.35)), p) * base)
			x += 0.42
		z += 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = load(path)
	mm.instance_count = list.size()
	for k: int in list.size():
		mm.set_instance_transform(k, list[k])
	DirAccess.make_dir_recursive_absolute(ART + "trigo")
	var file := ART + "trigo/%s.res" % label.to_lower()
	ResourceSaver.save(mm, file)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = load(file)
	mmi.visibility_range_end = 140.0
	_group("Gardens", false).add_child(mmi)
	mmi.owner = level
	_block_rect(r, 0.3)
	print("trigo ", label, ": ", list.size(), " pés")


# --- fazendas fora da muralha, dos dois lados da estrada --------------------------------------------------

func _farms() -> void:
	var z0 := -HALF - 10.0  # começo das roças (a 10 m da muralha)
	# oeste: celeiro grande de frente para a estrada, moinho de pás, trigal e aboboral cercados
	var barn := _landmark("celeiro_grande", Vector3(-17.0, 0, z0 - 12.0), Vector3.RIGHT, "CeleiroGrande")
	if barn:
		_lane(Vector2(-4.0, z0 - 12.0), Vector2(-11.0, z0 - 12.0), 3.0)
		_place("feno", _group("Props"), Vector3(-11.6, 0, z0 - 6.8), 0.3)
		_place("feno", _group("Props"), Vector3(-12.6, 0, z0 - 5.9), 1.1)
		_place("carroca", _group("Props"), Vector3(-10.6, 0, z0 - 18.5), 0.4)
	var mill := _landmark("moinho_torre", Vector3(-46.0, 0, z0 - 36.0), Vector3(1, 0, 1).normalized(), "MoinhoDePas")
	if mill:
		_lane(Vector2(-4.0, z0 - 30.0), Vector2(-40.0, z0 - 30.0), 2.6)
	_wheat_field(Rect2(-56.0, z0 - 16.0, 28.0, 14.0), "TrigalOeste")
	_fence_rect(Rect2(-57.0, z0 - 17.0, 30.0, 16.0))
	_patch("aboboral", Rect2(-34.0, z0 - 26.0, 10.0, 6.0), 2.0)
	# leste: celeiro, silo, galinheiro, horta e trigal; vacas e porcos no pasto
	var barn2 := _landmark("celeiro", Vector3(17.0, 0, z0 - 12.0), Vector3.LEFT, "Celeiro")
	if barn2:
		_lane(Vector2(4.0, z0 - 12.0), Vector2(11.0, z0 - 12.0), 3.0)
	var silo := _landmark("silo", Vector3(17.5, 0, z0 - 2.5), Vector3.LEFT, "Silo")
	if silo == null:
		print("silo ficou de fora")
	var coop := _landmark("galinheiro", Vector3(11.5, 0, z0 - 24.0), Vector3.LEFT, "Galinheiro")
	if coop:
		for k: int in 5:
			_place("galinha", _group("Animals", false), Vector3(rng.randf_range(7.5, 10.0), 0, z0 - 24.0 + rng.randf_range(-3, 3)), rng.randf() * TAU)
	_wheat_field(Rect2(28.0, z0 - 15.0, 26.0, 13.0), "TrigalLeste")
	_fence_rect(Rect2(27.0, z0 - 16.0, 28.0, 15.0))
	_patch("horta", Rect2(28.0, z0 - 26.0, 14.0, 8.0), 1.6)
	_patch("aboboral", Rect2(44.0, z0 - 26.0, 10.0, 8.0), 2.2)
	_pasture(Vector3(40.0, 0, z0 - 44.0), [["vaca", 3], ["porco", 2], ["cavalo", 1]])
	# torre de vigia de madeira na beira das roças, olhando a estrada
	_place("torre_vigia", _group("Buildings"), Vector3(8.0, 0, z0 - 40.0), 0.3, 1.0, "TorreDaEstrada")
	_block(Vector3(8.0, 0, z0 - 40.0), Vector2(4.4, 4.4), 0.4)


## Cerca baixa em volta de um retângulo (tábuas de 5,9 m), com uma abertura no meio do lado da estrada.
func _fence_rect(r: Rect2) -> void:
	var road_side := 1 if r.get_center().x < 0.0 else 3  # 1 = leste (x máx), 3 = oeste (x mín)
	for side: int in 4:
		var horizontal := side == 0 or side == 2
		var length := r.size.x if horizontal else r.size.y
		var n := maxi(1, int(length / 5.9))
		var step := length / n
		for k: int in n:
			if side == road_side and k == n / 2:
				continue
			var t := (k + 0.5) * step
			var at: Vector3
			match side:
				0:
					at = Vector3(r.position.x + t, 0, r.position.y)
				2:
					at = Vector3(r.position.x + t, 0, r.end.y)
				1:
					at = Vector3(r.end.x, 0, r.position.y + t)
				_:
					at = Vector3(r.position.x, 0, r.position.y + t)
			_place("cerca_fazenda2", _group("Props"), at, 0.0 if horizontal else PI / 2.0, step / 5.9, "Cerca")
	_block_rect(r, 0.4)


## Canteiro de roça: a peça repetida em grade dentro do retângulo, com a terra pintada embaixo.
func _patch(piece: String, r: Rect2, step: float) -> void:
	_paint_rect(r, 0)
	var z := r.position.y + step / 2.0
	while z < r.end.y:
		var x := r.position.x + step / 2.0
		while x < r.end.x:
			_place(piece, _group("Gardens", false), Vector3(x + rng.randf_range(-0.2, 0.2), 0, z), rng.randf() * TAU, 1.0, piece.capitalize())
			x += step
		z += step
	_block_rect(r, 0.3)


## Miolo dos quarteirões: casas espalhadas na grama livre, cada uma virada para a rua mais perto, com um caminho de
## terra da porta até a rua e um quintal na frente. Só entra onde couber com folga (nada torto, nada encostado).
func _fill_quarters() -> void:
	var kinds: Array[String] = ["casa", "casa_estreita", "casa_barro", "casa_estreita_pedra", "casa_enxaimel", "casa_enxaimel2", "casa_longa"]
	var placed := 0
	var tries := 0
	var lim := HALF - 4.0
	while placed < 46 and tries < 4000:
		tries += 1
		var p := Vector3(snappedf(rng.randf_range(-lim, lim), 1.0), 0, snappedf(rng.randf_range(-lim, lim), 1.0))
		if absf(p.x) < PLAZA + 6.0 and absf(p.z) < PLAZA + 6.0:
			continue
		if _mask_at(p).g > 0.05:
			continue
		# de frente para a avenida mais perto (as avenidas são x = 0 e z = 0)
		var front := Vector3(-signf(p.x), 0, 0) if absf(p.x) < absf(p.z) else Vector3(0, 0, -signf(p.z))
		var key := kinds[rng.randi() % kinds.size()]
		var house := _place(key, _group("Buildings"), Vector3.ZERO, _yaw_facing(front), 1.0)
		var box := _aabb(house)
		var shift := p - box.get_center()
		shift.y = 0.0
		house.position += shift
		var rect := _rect(AABB(box.position + shift, box.size), 0.0)
		var inside := rect.position.x > -HALF + 2.5 and rect.end.x < HALF - 2.5 and rect.position.y > -HALF + 2.5 and rect.end.y < HALF - 2.5
		if not inside or _overlaps(rect.grow(1.6)):
			house.get_parent().remove_child(house)
			house.free()
			continue
		_block_rect(rect, 0.6)
		var depth := absf(box.size.dot(front.abs()))
		var door := p + front * (depth / 2.0 + 0.3)
		# caminho de terra da porta até a calçada
		var walk := door
		for k: int in 40:
			if _mask_at(walk).g > 0.5:
				break
			walk += front
		_path(Vector2(door.x, door.z), Vector2(walk.x, walk.z), 1.8)
		var along := front.cross(Vector3.UP)
		houses.append({"node": house, "key": key, "center": house.position, "front": front, "along": along,
			"size": Vector2(absf(box.size.dot(along.abs())), depth), "door": door})
		placed += 1
	print("casas no miolo: ", placed)


## Plantação: fileiras de terra com verduras (peça "horta") e um espantalho no canto.
func _crops(corner: Vector3, rows: int, cols: int) -> void:
	for r: int in rows:
		var z := corner.z + r * 1.6
		_paint_rect(Rect2(corner.x - 0.8, z - 0.5, cols * 1.6 + 1.0, 1.0), 0)
		for c: int in cols:
			_place("horta", _group("Gardens", false), Vector3(corner.x + c * 1.6 + 0.4, 0, z), 0.0, 1.0, "Horta")
	_place("boneco_treino", _group("Props"), corner + Vector3(cols * 1.6 + 0.8, 0, rows * 0.8), 0.6, 0.9, "Espantalho")
	_block(corner + Vector3(cols * 0.8, 0, rows * 0.8 - 0.8), Vector2(cols * 1.6 + 2.6, rows * 1.6 + 1.2), 0.0)


# --- vida da rua: postes, placas, bancos ----------------------------------------------------------------

func _street_life() -> void:
	# postes acesos ao longo das avenidas, alternando os lados, a 1,2 m da beira
	for spec: Array in [[Vector3(0, 0, -1), -PLAZA - 4.0, -HALF + 6.0], [Vector3(0, 0, 1), PLAZA + 4.0, HALF - 4.0],
			[Vector3(1, 0, 0), PLAZA + 4.0, HALF - 4.0], [Vector3(-1, 0, 0), -PLAZA - 4.0, -HALF + 4.0]]:
		var dir: Vector3 = spec[0]
		var side := Vector3(-dir.z, 0, dir.x)
		var t: float = absf(spec[1])
		var k := 0
		while t < absf(spec[2]):
			var at := dir * t + side * (AVE - 1.2) * (1.0 if k % 2 == 0 else -1.0)
			if _free_at(at, 0.3):
				_place("poste", _group("Lights", false), at, 0.0, 1.0, "Poste")
				_block(at, Vector2(0.5, 0.5), 0.0)
			t += 8.0
			k += 1
	# rua do anel: um poste a cada 10 m na beira de dentro (menos nos cruzamentos com as avenidas)
	for side: int in 4:
		var t2 := -RING + 4.0
		while t2 < RING - 3.0:
			if absf(t2) > AVE + 2.5:
				var inset := RING - RING_W + 0.7
				var at: Vector3 = [Vector3(t2, 0, -inset), Vector3(t2, 0, inset), Vector3(-inset, 0, t2), Vector3(inset, 0, t2)][side]
				_place("poste", _group("Lights", false), at, 0.0, 1.0, "PosteDoAnel")
			t2 += 10.0


# --- lugares da história: moradores, portão, beco do Tico ------------------------------------------

func _story_spots() -> void:
	var people := level.get_node("People")
	# dá nome aos moradores com fala (no arquivo eles são "@Node3D@n")
	for person: Node in people.get_children():
		var talk := person.get_node_or_null("Talk")
		if talk == null:
			continue
		var prompt := String(talk.get("prompt_text"))
		for pair: Array in [["vendedor", "Vendedor"], ["guarda", "Guarda"], ["criança", "Crianca"]]:
			if prompt.contains(pair[0]):
				person.name = pair[1]
	var place := {
		"Vendedor": spots.get("feira_0", Transform3D()).translated(Vector3(1.0, 0, 0)),
		"Guarda": Transform3D(Basis(Vector3.UP, _yaw_facing(Vector3.BACK)), Vector3(2.4, 0, -HALF + 4.0)),
		"Crianca": Transform3D(Basis(Vector3.UP, _yaw_facing(Vector3(-1, 0, -1).normalized())), Vector3(5.6, 0, 6.4)),
	}
	# o vendedor fica atrás da banca de frutas (do lado de dentro, olhando para a praça)
	var stall: Transform3D = spots.get("feira_0", Transform3D())
	place["Vendedor"] = Transform3D(Basis(Vector3.UP, _yaw_facing(Vector3.LEFT)), stall.origin + Vector3(3.8, 0, -0.6))
	for name: String in place:
		var person := people.get_node_or_null(name) as Node3D
		if person:
			person.global_transform = place[name]
	var gate := level.get_node_or_null("Gate") as Node3D
	if gate:
		gate.global_position = Vector3(0, 1, -HALF + 0.2)
	# beco do Tico: papelão no fundo, encostado na parede da casa do lado norte
	var corner := level.get_node("TicoCorner") as Node3D
	corner.global_transform = Transform3D.IDENTITY
	var spot := Vector3(tico_alley.position.x + 1.6, 0, tico_alley.position.y + 0.65)
	var cardboard := MeshInstance3D.new()
	cardboard.name = "Blanket"
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.04, 0.9)
	cardboard.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.56, 0.43, 0.28)
	mat.roughness = 1.0
	cardboard.material_override = mat
	corner.add_child(cardboard)
	cardboard.owner = level
	cardboard.position = spot + Vector3(0, 0.02, 0.15)
	var cup := _kit("objetos/Mug", corner, spot + Vector3(0.9, 0, 0.9), 0.4, 1.0, false)
	cup.name = "Cup"
	# caixote e barril no fundo do beco, longe da boca (de onde as câmeras da cena olham)
	_place("caixote", corner, Vector3(tico_alley.position.x + 0.55, 0, tico_alley.end.y - 0.5), 0.3, 0.8, "Crate1")
	for k: int in 2:
		_kit("vila/Wall_UnevenBrick_Straight", corner, Vector3(tico_alley.position.x - 0.2, 0, tico_alley.position.y + 0.6 + k * 2.0), PI / 2.0)
	var look := corner.get_node_or_null("Look") as Node3D
	if look:
		look.position = spot + Vector3(0.4, 0.6, 0.4)
	var spawn := level.get_node("PlayerSpawn") as Node3D
	spawn.global_transform = Transform3D(Basis(Vector3.UP, _yaw_facing(Vector3.RIGHT)), Vector3(tico_alley.end.x - 1.0, 1.0, tico_alley.get_center().y))
	_block_rect(tico_alley, 0.0)
	_paint_rect(tico_alley, 0)


# --- gente de fundo: quem vive na cidade (sem fala; os moradores com fala ficam em People) -------------

func _figurante(pos: Vector3, look: Vector3, who: String, anim: String, hand: String = "", size: float = 0.62, label: String = "") -> void:
	var person := Node3D.new()
	person.name = label if label != "" else who
	_group("Crowd", false).add_child(person, true)
	person.owner = level
	var dir := look - pos
	dir.y = 0.0
	person.transform = Transform3D(Basis(Vector3.UP, _yaw_facing(dir.normalized()) if dir.length() > 0.01 else 0.0), pos)
	var figure := Figurante.new()
	figure.name = "Figure"
	figure.personagem = who
	figure.animacao = anim
	figure.na_mao = hand
	person.add_child(figure)
	figure.owner = level
	figure.scale = Vector3.ONE * size
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 4
	body.collision_mask = 0
	person.add_child(body)
	body.owner = level
	body.position = Vector3(0, 0.9, 0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	shape.owner = level
	_block(pos, Vector2(1.0, 1.0), 0.3)  # planta nenhuma nasce em cima de quem está parado ali


func _crowd() -> void:
	# guardas no portão, por dentro
	_figurante(Vector3(-2.6, 0, -HALF + 4.0), Vector3(0, 0, 0), "Knight", "2H_Melee_Idle", "2H_Sword", 0.66, "GuardaPortao")
	# feira: fregueses na frente das bancas
	var looks := ["Rogue_Hooded", "Mage", "Barbarian", "Rogue_Hooded"]
	var anims := ["Interact", "Idle", "Unarmed_Idle", "Use_Item"]
	for k: int in 4:
		if k == 0:
			continue  # o vendedor de frutas (com fala) já está ali
		var stall: Transform3D = spots["feira_%d" % k]
		_figurante(stall.origin + Vector3(-0.4, 0, -0.4 * k), stall.origin + Vector3(3, 0, 0), looks[k], anims[k], "", 0.6, "Freguês")
	# bancos da praça: gente sentada em dois deles
	for key: String in ["banco_0_-1", "banco_2_1"]:
		if spots.has(key):
			var t: Transform3D = spots[key]
			_figurante(t.origin, t.origin - t.basis.z * 3.0 + Vector3.DOWN * SIT_LIFT, ["Mage", "Rogue_Hooded"][int(key == "banco_2_1")], "Sit_Chair_Idle", "", 0.6, "Sentado")
	# conversa na porta da taverna e da estalagem
	for h: Dictionary in houses:
		var node: Node3D = h["node"]
		var door: Vector3 = h["door"]
		var f: Vector3 = h["front"]
		var a: Vector3 = h["along"]
		match String(node.name):
			"Taverna":
				_figurante(door + f * 1.4 - a * 0.7, door + f * 1.4 + a, "Barbarian", "Cheer", "Mug", 0.64, "NaTaverna")
				_figurante(door + f * 1.6 + a * 0.6, door + f * 1.4 - a, "Knight", "Idle", "", 0.64, "NaTaverna")
			"Estalagem":
				_figurante(door + f * 1.2 + a * 2.5, door + f * 3.0, "Mage", "Idle", "", 0.62, "Hospede")
			"Ferreiro":
				var anvil := node.global_transform * Vector3(-2.2, 0, -6.3)
				_figurante(anvil, node.global_transform * Vector3(-2.2, 0, -5.2), "Barbarian", "Use_Item", "1H_Axe", 0.66, "FerreiroTrabalhando")
	# crianças correndo perto do chafariz, alguém lendo no jardim da capela
	_figurante(Vector3(-6.4, 0, 6.8), Vector3(-3, 0, 4), "Rogue", "Cheer", "", 0.45, "Crianca2")
	_figurante(Vector3(-4.6, 0, 8.4), Vector3(-6.4, 0, 6.8), "Rogue_Hooded", "Idle", "", 0.43, "Crianca3")
	_figurante(garden_at + Vector3(2.4, 0, -2.6), garden_at, "Mage", "Sit_Floor_Idle", "Spellbook_open", 0.6, "Leitora")
	# no cemitério, alguém de capuz parado numa lápide
	_figurante(cemetery_at + Vector3(1.0, 0, -2.2), cemetery_at + Vector3(1.0, 0, -3.6), "Rogue_Hooded", "Idle", "", 0.6, "NoCemiterio")
	# fazendas: gente trabalhando nas roças e no celeiro da cidade
	var z0 := -HALF - 10.0
	_figurante(Vector3(-25.2, 0, z0 - 8.0), Vector3(-30.0, 0, z0 - 8.0), "Barbarian", "Interact", "", 0.62, "Lavrador")
	_figurante(Vector3(30.5, 0, z0 - 22.0), Vector3(34.0, 0, z0 - 22.0), "Rogue", "PickUp", "", 0.6, "Lavradora")
	_figurante(Vector3(8.6, 0, z0 - 15.0), Vector3(4.0, 0, z0 - 12.0), "Knight", "Idle", "", 0.62, "Fazendeiro")
	var granary := level.get_node_or_null("Buildings/CeleiroDaCidade") as Node3D
	if granary:
		_figurante(granary.global_position + Vector3(4.0, 0, 6.5), granary.global_position + Vector3(4.0, 0, 9.0), "Barbarian", "Use_Item", "", 0.62, "Carregador")
	# moleiro na porta do moinho e cavalariço no estábulo
	var mill := level.get_node_or_null("Buildings/Moinho") as Node3D
	if mill:
		_figurante(mill.global_transform * Vector3(2.5, 0, -5.0), mill.global_transform * Vector3(0, 0, -9.0), "Barbarian", "Idle", "", 0.62, "Moleiro")
	var stable := level.get_node_or_null("Buildings/Estabulo") as Node3D
	if stable:
		_figurante(stable.global_transform * Vector3(-4.5, 0, -6.6), stable.global_transform * Vector3(-6.0, 0, -5.4), "Rogue_Hooded", "Interact", "", 0.6, "Cavalarico")


func _animals() -> void:
	var holder := _group("Animals", false)
	# galinhas soltas perto do moinho e do estábulo, cachorro na praça, gato na porta da padaria
	var mill := level.get_node_or_null("Buildings/Moinho") as Node3D
	if mill:
		for k: int in 5:
			_place("galinha", holder, mill.global_transform * Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-8, -6)), rng.randf() * TAU)
		_place("porco", holder, mill.global_transform * Vector3(-5.5, 0, -2.0), rng.randf() * TAU)
		_place("vaca", holder, mill.global_transform * Vector3(-6.5, 0, 1.5), rng.randf() * TAU)
	var stable := level.get_node_or_null("Buildings/Estabulo") as Node3D
	if stable:
		for k: int in 3:
			_place("galinha", holder, stable.global_transform * Vector3(rng.randf_range(1, 5), 0, rng.randf_range(-9, -8)), rng.randf() * TAU)
	_place("cachorro", holder, Vector3(4.2, 0, 7.6), 2.4)
	var bakery := level.get_node_or_null("Buildings/Padaria") as Node3D
	if bakery:
		_place("gato", holder, bakery.global_transform * Vector3(2.4, 0, -3.6), 0.8)


# --- fumaça nas chaminés -----------------------------------------------------------------------------------

func _smoke() -> void:
	var holder := _group("Smoke", false)
	_smoke_process = ParticleProcessMaterial.new()
	_smoke_process.direction = Vector3(0, 1, 0)
	_smoke_process.spread = 12.0
	_smoke_process.initial_velocity_min = 0.5
	_smoke_process.initial_velocity_max = 0.9
	_smoke_process.gravity = Vector3(0.25, 0.12, 0.1)
	_smoke_process.scale_min = 0.6
	_smoke_process.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.8))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	_smoke_process.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.78, 0.75, 0.45))
	fade.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	_smoke_process.color_ramp = fade_tex
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2(1.1, 1.1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = g
	mat.albedo_texture = puff
	_smoke_mesh.material = mat
	for h: Dictionary in houses:
		var key: String = h["key"]
		if not CHIMNEY.has(key) or rng.randf() > 0.6:
			continue
		var node: Node3D = h["node"]
		var at: Vector3 = node.global_transform * (CHIMNEY[key] as Vector3)
		var smoke := GPUParticles3D.new()
		smoke.name = "Fumaca"
		smoke.amount = 10
		smoke.lifetime = 6.0
		smoke.preprocess = 6.0
		smoke.process_material = _smoke_process
		smoke.draw_pass_1 = _smoke_mesh
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
		holder.add_child(smoke, true)
		smoke.owner = level
		smoke.global_position = at


# --- fora da muralha: estrada, floresta, pedras ---------------------------------------------------

func _outside() -> void:
	var tries := 0
	var placed := 0
	var reach := AREA / 2.0 - 8.0
	while placed < 560 and tries < 20000:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(HALF + 8.0, reach * 1.35)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < 7.0 and p.z < -HALF:
			continue  # estrada livre
		if absf(p.x) > reach or absf(p.z) > reach or (absf(p.x) < HALF + 6.0 and absf(p.z) < HALF + 6.0):
			continue
		if not _free_at(p, 2.0):
			continue  # roças, celeiros e pastos
		var roll := rng.randf()
		if roll < 0.55:
			_place(["pinheiro", "arvore", "pinheiro", "arvore", "arvore_pequena"][rng.randi() % 5], _group("Trees"), p, rng.randf() * TAU, rng.randf_range(0.9, 1.5))
		elif roll < 0.85:
			_place(["arbusto", "arbusto_baixo"][rng.randi() % 2], _group("Gardens", false), p, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		else:
			_place(["rocha", "rocha_grande", "pedregulhos"][rng.randi() % 3], _group("Rocks"), p, rng.randf() * TAU, rng.randf_range(0.7, 1.3))
		_block(p, Vector2(1.5, 1.5), 0.0)
		placed += 1
	# cerca dos dois lados da estrada que chega ao portão, com postes
	for k: int in 6:
		for x: float in [-4.8, 4.8]:
			_place("cerca", _group("Props"), Vector3(x, 0, -HALF - 6.0 - k * 2.06), PI / 2.0)
	for z: float in [-HALF - 7.0, -HALF - 15.0]:
		_place("poste", _group("Lights", false), Vector3(3.6, 0, z), 0.0, 1.0, "PosteEstrada")


# --- quintais: árvores e hortas só em grama livre, longe das casas (nunca na calçada) -----------------------

func _yards() -> void:
	var inner := HALF - 2.5
	var tries := 0
	var placed := 0
	while placed < 90 and tries < 9000:
		tries += 1
		var p := Vector3(rng.randf_range(-inner, inner), 0, rng.randf_range(-inner, inner))
		var m := _mask_at(p)
		if not _free_at(p, 2.2) or m.r > 0.05 or m.g > 0.05:
			continue
		# também longe da beira das ruas (o desfoque da máscara é ~0,7 m)
		if _mask_at(p + Vector3(2.5, 0, 0)).g > 0.05 or _mask_at(p - Vector3(2.5, 0, 0)).g > 0.05 \
				or _mask_at(p + Vector3(0, 0, 2.5)).g > 0.05 or _mask_at(p - Vector3(0, 0, 2.5)).g > 0.05:
			continue
		var roll := rng.randf()
		if roll < 0.5:
			_place(["arvore", "arvore_pequena", "pinheiro"][rng.randi() % 3], _group("Trees"), p, rng.randf() * TAU, rng.randf_range(0.75, 1.05))
			_block(p, Vector2(2.4, 2.4), 0.0)
		elif roll < 0.85:
			_place(["arbusto", "arbusto_baixo", "flores"][rng.randi() % 3], _group("Gardens", false), p, rng.randf() * TAU, rng.randf_range(0.6, 1.0))
			_block(p, Vector2(1.2, 1.2), 0.0)
		else:
			_place(["carroca", "barris", "caixote_alto", "mesa"][rng.randi() % 4], _group("Props"), p, rng.randf() * TAU)
			_block(p, Vector2(2.4, 2.4), 0.0)
		placed += 1


# --- chão -----------------------------------------------------------------------------------------

func _paint_ground() -> void:
	var soft := mask.duplicate() as Image
	soft.resize(MASK_PX / 3, MASK_PX / 3, Image.INTERPOLATE_LANCZOS)
	soft.resize(MASK_PX, MASK_PX, Image.INTERPOLATE_CUBIC)
	DirAccess.make_dir_recursive_absolute(ART)
	soft.save_png(ART + "chao_mascara.png")
	ResourceSaver.save(ImageTexture.create_from_image(soft), ART + "chao_mascara.res")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/chao_pintado.gdshader")
	var vila := "res://assets/kits/quaternius/vila/"
	mat.set_shader_parameter("noise", load(vila + "T_Noise_Terrain.png"))
	mat.set_shader_parameter("cobble_albedo", load(vila + "T_UnevenBrick_BaseColor.png"))
	mat.set_shader_parameter("cobble_normal", load(vila + "T_UnevenBrick_Normal.png"))
	mat.set_shader_parameter("cobble_meters", 2.4)
	mat.set_shader_parameter("cobble_tint", Color(0.98, 0.93, 0.86))
	mat.set_shader_parameter("area_size", Vector2(AREA, AREA))
	var ground := level.get_node("Ground")
	var dirt := ground.get_node("Dirt") as MeshInstance3D
	var box := BoxMesh.new()
	box.size = Vector3(AREA, 1.0, AREA)
	dirt.mesh = box
	dirt.material_override = mat
	var shape := ground.get_node("Body/Shape") as CollisionShape3D
	var bs := BoxShape3D.new()
	bs.size = Vector3(AREA, 1.0, AREA)
	shape.shape = bs
	mat.set_shader_parameter("mask", load(ART + "chao_mascara.res"))
	level.set("mapa_do_piso", load(ART + "chao_mascara.res"))
	level.set("area_do_mapa", AREA)  # os passos leem a máscara com o mesmo tamanho
	level.set("noite", true)  # D045: Arandu começa de noite (F3 troca no jogo)
	var nav := level.get_node("Navigation") as NavigationRegion3D
	nav.navigation_mesh.filter_baking_aabb = AABB(Vector3(-HALF - 3, -2, -HALF - 3), Vector3(HALF * 2 + 6, 22, HALF * 2 + 6))


# --- grama ----------------------------------------------------------------------------------------

func _grass_mesh(name: String) -> Mesh:
	var path := KIT + "natureza/malhas/" + name + ".res"
	if ResourceLoader.exists(path):
		return load(path)
	var scene := (load(KIT + "natureza/" + name + ".gltf") as PackedScene).instantiate()
	var mesh: Mesh = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	DirAccess.make_dir_recursive_absolute(KIT + "natureza/malhas")
	ResourceSaver.save(mesh, path)
	return load(path)


func _grass() -> void:
	var kinds := {"Grass_Common_Short": [0.42, 0.7], "Grass_Wispy_Short": [0.4, 0.6], "Clover_1": [0.35, 0.55], "Plant_7": [0.8, 1.2],
		"Flower_3_Single": [0.3, 0.45]}
	var weights := {"Grass_Common_Short": 0.5, "Grass_Wispy_Short": 0.2, "Clover_1": 0.15, "Plant_7": 0.1, "Flower_3_Single": 0.05}
	var chunks := {}
	var space := level.get_world_3d().direct_space_state
	var count := 0
	var step := 1.25
	var reach := AREA / 2.0 - 8.0
	var x := -reach
	while x < reach:
		var z := -reach
		while z < reach:
			var p := Vector3(x + rng.randf_range(-0.55, 0.55), 0, z + rng.randf_range(-0.55, 0.55))
			z += step
			var m := _mask_at(p)
			var keep := 0.85 if Vector2(p.x, p.z).length() < reach * 1.3 else 0.0
			keep *= (1.0 - clampf(m.g * 3.0, 0.0, 1.0)) * (1.0 - m.r * 0.7)
			if rng.randf() > keep or not _free_at(p, -0.55):
				continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 14.0, p + Vector3.DOWN, 1 | 4))
			if hit.is_empty() or (hit["position"] as Vector3).y > 0.15:
				continue
			var kind := _pick_weighted(weights)
			var range_s: Array = kinds[kind]
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(range_s[0], range_s[1])), p)
			var key := "%s|%d|%d" % [kind, floori(p.x / 30.0), floori(p.z / 30.0)]
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(t)
			count += 1
		x += step
	var holder := _group("Grama", false)
	DirAccess.make_dir_recursive_absolute(ART + "grama")
	for f: String in DirAccess.get_files_at(ART + "grama"):
		DirAccess.remove_absolute(ART + "grama/" + f)
	var i := 0
	for key: String in chunks:
		var parts := key.split("|")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _grass_mesh(parts[0])
		var list: Array = chunks[key]
		mm.instance_count = list.size()
		for k: int in list.size():
			mm.set_instance_transform(k, list[k])
		var path := ART + "grama/g%03d.res" % i
		ResourceSaver.save(mm, path)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "G%03d" % i
		mmi.multimesh = load(path)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 75.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		holder.add_child(mmi)
		mmi.owner = level
		i += 1
	print("grama: ", count, " tufos em ", i, " pedaços")


func _pick_weighted(weights: Dictionary) -> String:
	var r := rng.randf()
	for k: String in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


# --- luz: fim de tarde dourado ----------------------------------------------------------------------------

func _light() -> void:
	var env := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.background_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssil_enabled = true
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.82, 0.7)
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0032
	env.volumetric_fog_albedo = Color(0.95, 0.88, 0.78)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 80.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var sun := level.get_node("Sun") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-30, -132, 0)  # sol baixo vindo do oeste/sudoeste: sombras longas e quentes
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 2.3
	sun.light_volumetric_fog_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	var rig := level.get_node("CameraRig")
	rig.set("distance", 5.8)
	rig.set("height", 1.9)
