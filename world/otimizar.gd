class_name Otimizar
## Deixa a fase mais leve na hora de jogar (D065), sem mexer no arquivo (o editor de mapas vê tudo como foi feito):
## - luz de fogo e de lanterna sem sombra (cada uma redesenhava os arredores 6 vezes por quadro);
## - dentro das casas nada faz sombra do sol (o sol não entra), e coisa miúda também não;
## - coisa pequena some de longe (o caneco a 40 m, o caixote a 70 m), a partir da distância que dá para ver.
## Level chama apply() ao abrir a fase; InteriorSobDemanda chama para cada interior que carrega.

## Distâncias (m) em que some, pelo tamanho (maior lado, m) do objeto. Maior que o último: não some.
const SUMIR := [[0.6, 35.0], [1.6, 55.0], [3.5, 85.0], [7.0, 130.0]]


static func apply(root: Node, inside: bool = false) -> void:
	if root == null:
		return
	for found: Node in root.find_children("*", "Light3D", true, false):
		if found is DirectionalLight3D:
			continue
		var light := found as Light3D
		if light.shadow_enabled and not light.has_meta("sombra"):
			light.shadow_enabled = false
	for found: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geo := found as GeometryInstance3D
		if geo is MultiMeshInstance3D or geo is GPUParticles3D or geo is Label3D:
			continue
		var size := _size(geo)
		if size <= 0.0:
			continue
		if inside or size < 0.6:
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if geo.visibility_range_end <= 0.0 and not _keep(geo):
			for step: Array in SUMIR:
				if size < float(step[0]):
					geo.visibility_range_end = float(step[1])
					geo.visibility_range_end_margin = 4.0
					break


## Maior lado (m) do desenho, já com a escala.
static func _size(geo: GeometryInstance3D) -> float:
	var box := geo.get_aabb()
	var scale := geo.global_basis.get_scale() if geo.is_inside_tree() else Vector3.ONE
	return (box.size * scale).abs()[(box.size * scale).abs().max_axis_index()]


## O que nunca some de longe: gente (personagem e herói), o céu e quem tem marca de "sempre".
static func _keep(geo: GeometryInstance3D) -> bool:
	if geo.has_meta("sempre"):
		return true
	var current: Node = geo
	for i: int in 8:
		current = current.get_parent()
		if current == null:
			break
		if current is Figurante or current is Combatant or current is Ator:
			return true
	return false
