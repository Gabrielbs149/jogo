class_name CameraConversa
extends Camera3D
## Câmera das conversas (D064), no jeito dos RPGs de conversa: campo e contracampo.
## - Quando o outro fala: por cima do ombro do herói, com o rosto de quem fala no terço da tela.
## - Quando o herói fala: por cima do ombro do outro, olhando o herói.
## - Narração e escolhas: os dois de lado (plano dos dois).
## A câmera fica sempre do mesmo lado da linha entre os dois (a regra dos 180°: ninguém troca de lado na tela), passa
## de um plano para o outro numa curva curta, desvia de parede e deixa o fundo um pouco desfocado.
## O Level cria esta câmera na primeira conversa (focus_talk) e a caixa de diálogo diz quem está falando (line_started).

## Tempo (s) da passagem de um plano para o outro; a primeira vem da câmera do jogo, um pouco mais devagar.
@export var passagem: float = 0.45
@export var entrada: float = 0.7
## Distância (m) atrás do ombro de quem ouve e para o lado.
@export var atras: float = 1.55
@export var lado: float = 0.9
## Quanto (m) a câmera fica acima da cabeça de quem ouve.
@export var acima: float = 0.32
## Abertura da lente: mais fechada no ombro (rosto maior), mais aberta no plano dos dois.
@export var lente_ombro: float = 38.0
@export var lente_dois: float = 50.0

var hero: Node3D
var other: Node3D
var hero_names: PackedStringArray = []
## De que lado da linha herói -> outro a câmera fica (+1 direita, -1 esquerda).
var _side: float = 1.0
var _move: Tween
var _shot: String = ""
var _game_view: Transform3D = Transform3D()
## A caixa de texto cobre o terço de baixo da tela: a câmera mira um pouco abaixo do rosto, e o rosto sobe na tela.
const BAIXO := 0.22
var _game_fov: float = 60.0


func _ready() -> void:
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_transition = 4.0
	attributes.dof_blur_amount = 0.06
	self.attributes = attributes


## Começa a conversa: escolhe o lado (o mais perto de onde a câmera do jogo está) e entra no plano dos dois.
func start(who_hero: Node3D, who_other: Node3D, names: PackedStringArray, from: Camera3D) -> void:
	hero = who_hero
	other = who_other
	hero_names = names
	var line := _flat(other.global_position - hero.global_position)
	var right := line.cross(Vector3.UP).normalized()
	_side = 1.0
	if from:
		_side = 1.0 if (from.global_position - hero.global_position).dot(right) >= 0.0 else -1.0
		global_transform = from.global_transform
		fov = from.fov
		_game_view = from.global_transform
		_game_fov = from.fov
	_shot = ""
	make_current()
	shot("", false, entrada)


## O plano para quem está falando agora ("" = narração; choosing = escolha do herói).
func shot(speaker: String, choosing: bool, duration: float = -1.0) -> void:
	if hero == null or other == null or not is_instance_valid(hero) or not is_instance_valid(other):
		return
	var kind := "dois"
	if speaker != "" and not choosing:
		kind = "heroi" if _is_hero(speaker) else "outro"
	if kind == _shot:
		return
	_shot = kind
	_show_hidden()  # o plano novo é escolhido com tudo à vista
	var plan := _plan(kind)
	var faces: Array[Vector3] = []
	match kind:
		"outro":
			faces = [_head(other), _head(hero)]
		"heroi":
			faces = [_head(hero), _head(other)]
		_:
			faces = [plan[1], _head(hero), _head(other)]
	_hide_between(plan[0], faces)
	_go(plan[0], plan[1], float(plan[2]), passagem if duration < 0.0 else duration)


func stop() -> void:
	_show_hidden()
	if _move:
		_move.kill()
	hero = null
	other = null
	_shot = ""


func _is_hero(speaker: String) -> bool:
	var key := speaker.to_lower()
	for n: String in hero_names:
		if n != "" and (key == n.to_lower() or key.begins_with(n.to_lower())):
			return true
	return false


## [posição, ponto que olha, lente] do plano. Nos planos de ombro, tenta alguns jeitos até enxergar o rosto de quem
## fala (sem parede, banca ou a cabeça de quem ouve na frente); se nenhum serve, fica no plano dos dois.
func _plan(kind: String) -> Array:
	var a := _head(hero)
	var b := _head(other)
	var line := _flat(b - a)
	var right := line.cross(Vector3.UP).normalized() * _side
	if kind == "outro" or kind == "heroi":
		var listener := a if kind == "outro" else b
		var speaker := b if kind == "outro" else a
		var away := -line if kind == "outro" else line  # para trás de quem ouve
		var top := maxf(a.y, b.y)
		for tries: Array in [[atras, lado, acima], [atras, lado, acima + 0.45], [atras * 0.7, lado * 1.15, acima + 0.2],
				[atras * 1.3, lado * 0.8, acima + 0.8]]:
			var pos := listener + away * float(tries[0]) + right * float(tries[1])
			pos.y = top + float(tries[2])
			var look := speaker - right * 0.15 + Vector3.DOWN * BAIXO
			if _sees(pos, speaker, listener):
				return [pos, look, lente_ombro]
		# nenhum ombro serve (quem fala está dentro da banca, atrás do balcão): um plano só de quem fala, pela frente
		var single: Variant = _alone(speaker, listener, other if kind == "outro" else hero)
		if single != null:
			return single
	# plano dos dois: de lado, mais longe ou mais alto até ver os dois rostos
	var mid := (a + b) / 2.0
	var gap := _flat_len(b - a)
	var look := mid + Vector3.DOWN * (BAIXO + 0.1)
	var first := Vector3.ZERO
	for tries: Array in [[1.6, 0.35, -0.2], [1.2, 0.9, -0.2], [2.0, 0.6, 0.4], [1.0, 1.3, -0.6], [1.6, 0.5, 0.9]]:
		var pos := mid + right * maxf(2.0, gap * float(tries[0])) + Vector3.UP * float(tries[1]) + line * float(tries[2])
		if first == Vector3.ZERO:
			first = pos
		if _clear_view(pos, a) and _clear_view(pos, b) and _roomy(pos) and _framed(pos, look, lente_dois):
			return [pos, look, lente_dois]
	# nada do lado de sempre: procura em volta dos dois (mais longe, de outro ângulo, mais alto)
	# (primeiro exigindo a frente da lente livre; depois só os dois rostos à vista)
	for strict: bool in [true, false]:
		for radius: float in [2.6, 3.4, 4.3]:
			for height: float in [0.6, 1.4]:
				for degrees: float in [0.0, 30.0, -30.0, 60.0, -60.0, 95.0, -95.0, 130.0, -130.0]:
					var around := right.rotated(Vector3.UP, deg_to_rad(degrees))
					var pos := mid + around * radius + Vector3.UP * height
					if not (_clear_view(pos, a) and _clear_view(pos, b)):
						continue
					if not strict or (_roomy(pos) and _framed(pos, look, lente_dois)):
						return [pos, look, lente_dois]
	# nem assim (dentro de banca, beco apertado): fica a vista do jogo, que o jogador já via
	if _game_view != Transform3D():
		return [_game_view.origin, _game_view.origin - _game_view.basis.z, _game_fov]
	return [_clear(look, first), look, lente_dois]


## Plano só de quem fala: em volta dele, do lado de quem ouve (até 75° para cada lado), com o rosto limpo na tela.
func _alone(face: Vector3, listener: Vector3, who: Node3D) -> Variant:
	# pela frente de quem fala (o padeiro que não virou para o Tico continua de frente para a câmera)
	var toward := _flat(listener - face)
	if who:
		var ahead := _flat(-who.global_basis.z)
		if who.get_node_or_null("Figure") != null:
			ahead = _flat(-(who.get_node("Figure") as Node3D).global_basis.z)
		toward = ahead
	for limit: int in [2, 4]:
		for radius: float in [2.3, 3.0, 1.7]:
			for height: float in [0.15, 0.5, 0.9]:
				for degrees: float in [0.0, 25.0, -25.0, 50.0, -50.0, 75.0, -75.0]:
					var pos := face + toward.rotated(Vector3.UP, deg_to_rad(degrees)) * radius + Vector3.UP * height
					if _covered(pos, face, listener):
						continue  # quem ouve na frente da lente
					if _clear_view(pos, face) and _roomy(pos) and _framed(pos, face, lente_ombro, limit):
						return [pos, face + Vector3.DOWN * BAIXO, lente_ombro]
	return null


## Da posição dá para ver o rosto de quem fala? Sem nada no meio (colisão) e sem a cabeça de quem ouve na frente.
func _sees(pos: Vector3, face: Vector3, listener: Vector3) -> bool:
	if _covered(pos, face, listener):
		return false
	if not _clear_view(pos, face) or not _roomy(pos) or not _framed(pos, face, lente_ombro):
		return false
	var space := get_world_3d().direct_space_state
	# a câmera não pode nascer dentro de parede: um raio curto de quem ouve até ela
	var back := PhysicsRayQueryParameters3D.create(listener, pos, 1)
	back.exclude = _bodies()
	return space.intersect_ray(back).is_empty()


## Nada entre a câmera e o ponto: nem colisão, nem desenho (o poste da banca e o pão do balcão não têm colisão).
## O renderizador diz quem cruza o raio pela caixa; aí confere nos triângulos.
func _clear_view(pos: Vector3, point: Vector3) -> bool:
	return _free(pos, point - (point - pos).normalized() * 0.25)  # o próprio rosto não conta


## A frente da lente livre: uma grade de raios (5 x 3) cobrindo o miolo da tela, do olho até perto de quem está no
## plano. Se mais que um pouco dela bate em alguma coisa antes (o poste e a armação da banca, que deixam o rosto à
## vista por uma fresta mas tomam a tela), o plano não serve.
func _framed(pos: Vector3, target: Vector3, lens: float = 40.0, limit: int = 2) -> bool:
	var ahead := (target - pos).normalized()
	var side := ahead.cross(Vector3.UP).normalized()
	var up := side.cross(ahead).normalized()
	var reach := pos.distance_to(target) - 0.45
	if reach <= 0.3:
		return true
	var half_v := tan(deg_to_rad(lens) * 0.5)
	var half_h := half_v * 16.0 / 9.0
	var blocked := 0
	for u: float in [-0.6, -0.3, 0.0, 0.3, 0.6]:
		for v: float in [-0.5, 0.0, 0.5]:
			var dir := (ahead + side * (u * half_h) + up * (v * half_v)).normalized()
			if not _free(pos, pos + dir * reach):
				blocked += 1
				if blocked > limit:
					return false
	return true


## Folga em volta da câmera: nada a menos de 0,45 m dos lados e de cima (um poste colado na lente tapa meia tela,
## mesmo sem estar no caminho do rosto).
func _roomy(pos: Vector3) -> bool:
	for dir: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
		if not _free(pos, pos + dir * 0.45):
			return false
	return true


## O segmento de a até b não encosta em colisão nem em desenho (fora quem conversa).
func _free(pos: Vector3, stop: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pos, stop, 1 | 2)
	query.exclude = _bodies()
	if not space.intersect_ray(query).is_empty():
		return false
	for mi: MeshInstance3D in _hits(pos, stop):
		if _hideable(mi):
			continue  # coisa pequena (banca, lona, estaca): some durante o plano
		return false
	return true


## Os desenhos (fora quem conversa) que o segmento atravessa de verdade (pelos triângulos).
func _hits(pos: Vector3, stop: Vector3) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for id: int in RenderingServer.instances_cull_ray(pos, stop, get_world_3d().scenario):
		var mi := instance_from_id(id) as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if hero.is_ancestor_of(mi) or other.is_ancestor_of(mi):
			continue
		var tri: TriangleMesh = _tris.get(mi.mesh)
		if tri == null:
			tri = mi.mesh.generate_triangle_mesh()
			if tri == null:
				continue
			_tris[mi.mesh] = tri
		var inv := mi.global_transform.affine_inverse()
		if not tri.intersect_segment(inv * pos, inv * stop).is_empty():
			found.append(mi)
	return found


## Pode sumir durante o plano: coisa pequena que não é casa, muro nem chão (a armação da banca, a lona do barraco, a
## estaca, o caixote, o lustre). Parede nunca some: aí o plano é outro.
func _hideable(mi: MeshInstance3D) -> bool:
	var path := String(mi.get_path())
	for big: String in ["/Buildings/", "/Walls/", "/Terrain", "/Ground", "/Grama", "/Plaza/"]:
		if path.contains(big):
			return false
	var box := mi.global_transform * mi.get_aabb()
	return box.get_longest_axis_size() < 10.0


## Esconde o que está entre a câmera e os rostos (e na frente da lente), e mostra de volta o do plano anterior.
func _hide_between(pos: Vector3, targets: Array[Vector3]) -> void:
	_show_hidden()
	var seen: Dictionary = {}
	var ends: Array[Vector3] = []
	for target: Vector3 in targets:
		ends.append(target - (target - pos).normalized() * 0.25)
	if not targets.is_empty():
		# a tela toda (9 x 5 raios) até quem está no plano: os postes da banca passam entre raios mais espaçados
		var ahead := (targets[0] - pos).normalized()
		var side := ahead.cross(Vector3.UP).normalized()
		var up := side.cross(ahead).normalized()
		var reach := pos.distance_to(targets[0]) - 0.45
		var half_v := tan(deg_to_rad(lente_dois) * 0.5)
		var half_h := half_v * 16.0 / 9.0
		for i: int in 9:
			for j: int in 5:
				var u := lerpf(-0.95, 0.95, i / 8.0)
				var v := lerpf(-0.9, 0.9, j / 4.0)
				ends.append(pos + (ahead + side * u * half_h + up * v * half_v).normalized() * reach)
	for stop: Vector3 in ends:
		var near := pos + (stop - pos).normalized() * minf(2.0, pos.distance_to(stop) * 0.6)
		var found: Array[MeshInstance3D] = _hits(pos, stop)
		# colado na lente vale pela caixa (a armação da banca escapa do teste fino pelos triângulos)
		for id: int in RenderingServer.instances_cull_ray(pos, near, get_world_3d().scenario):
			var mi := instance_from_id(id) as MeshInstance3D
			if mi and mi.is_visible_in_tree() and not hero.is_ancestor_of(mi) and not other.is_ancestor_of(mi):
				found.append(mi)
		for mi: MeshInstance3D in found:
			if not _hideable(mi):
				continue
			# a peça inteira some (a banca com a mercadoria; senão o pão fica flutuando onde era a banca)
			var piece := _piece_of(mi)
			if piece is Passante or piece is Morador or piece is Combatant or piece is Ator:
				continue  # gente cuida de aparecer e sumir sozinha (vai para casa, volta): não mexe
			if piece and not seen.has(piece):
				seen[piece] = true
				piece.visible = false
				_hidden.append(piece)


func _show_hidden() -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()


## O pedaço que some junto: sobe da malha enquanto o conjunto ainda é pequeno (até 4,5 m) e não é um grupo da fase.
## A banca some com a mercadoria (senão o pão fica flutuando), mas do barraco do Tico some só a lona.
func _piece_of(mi: Node3D) -> Node3D:
	var level := get_parent()
	var current: Node3D = mi
	while current.get_parent() is Node3D and current.get_parent() != level and current.get_parent().get_parent() != level:
		var parent := current.get_parent() as Node3D
		if _size_of(parent) > 4.5:
			break
		current = parent
	return current


func _size_of(node: Node3D) -> float:
	var box := AABB()
	var first := true
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_longest_axis_size()


var _hidden: Array[Node3D] = []


var _tris: Dictionary = {}


## A cabeça (com capuz e orelhas) ou o ombro de quem ouve cobre o rosto de quem fala, visto dali? Também vale quando
## a câmera está quase dentro da cabeça de quem ouve.
func _covered(pos: Vector3, face: Vector3, listener: Vector3) -> bool:
	var to_face := face - pos
	for part: Vector3 in [listener, listener + Vector3.DOWN * 0.35]:
		var to_part := part - pos
		if to_part.length() < 0.7:
			return true
		var apart := to_face.normalized().angle_to(to_part.normalized())
		if apart < atan2(0.75, to_part.length()) and to_part.length() < to_face.length():
			return true
	return false


func _bodies() -> Array[RID]:
	var exclude: Array[RID] = []
	for who: Node3D in [hero, other]:
		for body: Node in who.find_children("*", "CollisionObject3D", true, false):
			exclude.append((body as CollisionObject3D).get_rid())
		if who is CollisionObject3D:
			exclude.append((who as CollisionObject3D).get_rid())
	return exclude


## Altura do rosto: o alto do desenho da pessoa, um pouco abaixo (os olhos).
func _head(who: Node3D) -> Vector3:
	var top := 0.0
	var found_any := false
	# só o corpo: o ícone de emoção, a fala que flutua e a luz não são a pessoa (subiam o "rosto" até o toldo)
	var body: Node = who.get_node_or_null("Figure")
	if body == null:
		body = who
	for found: Node in body.find_children("*", "MeshInstance3D", true, false):
		var vi := found as VisualInstance3D
		var part := String(vi.name)
		if not vi.is_visible_in_tree() or part.begins_with("Oficio_") or part.ends_with("_Hat") or part.ends_with("_Helmet"):
			continue  # chapéu de mago e capacete subiam o "rosto"
		var box := vi.global_transform * vi.get_aabb()
		if box.size.length() > 6.0:
			continue  # algo enorme pendurado na pessoa (luz, área): não é ela
		top = maxf(top, box.end.y - who.global_position.y)
		found_any = true
	if not found_any or top < 0.3:
		top = 1.2
	return who.global_position + Vector3.UP * (top * 0.86)


## A câmera não fica dentro de parede: se tem algo entre o rosto e a câmera, chega mais perto (e sobe um pouco).
func _clear(look: Vector3, pos: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(look, pos, 1)
	query.exclude = _bodies()
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return pos
	var at := hit["position"] as Vector3
	var back := (look - pos).normalized()
	return at + back * 0.2 + Vector3.UP * 0.15


func _go(pos: Vector3, look: Vector3, lens: float, duration: float) -> void:
	if _move:
		_move.kill()
	var target := Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	var far := attributes as CameraAttributesPractical
	if far:
		far.dof_blur_far_distance = pos.distance_to(look) + 2.5
	if duration <= 0.0:
		global_transform = target
		fov = lens
		return
	var start_xf := global_transform
	var start_fov := fov
	_move = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move.tween_method(func(t: float) -> void:
		global_transform = start_xf.interpolate_with(target, t)
		fov = lerpf(start_fov, lens, t), 0.0, 1.0, duration)


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.001 else Vector3.FORWARD


func _flat_len(v: Vector3) -> float:
	v.y = 0.0
	return v.length()
