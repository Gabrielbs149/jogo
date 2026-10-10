extends SceneTree
## Dá um ofício (D063, world/oficios.gd) a cada pessoa de Arandu e dos interiores: o padeiro com cara de padeiro, o
## ferreiro de martelo batendo na bigorna, o lavrador de chapéu de palha e forcado, a viúva de capuz preto... Quem mora
## nas casas ganha roupa variada (sorteada pelo nome da casa, rodar de novo dá o mesmo). Roda DEPOIS dos outros
## montadores (montar_vida e montar_interiores refazem gente). Uso: godot --headless --path . -s tools/art/montar_oficios.gd

const LEVEL := "res://levels/arandu/arandu.tscn"
const INTERIORES := "res://levels/arandu/interiores/"

## Na fase: caminho -> ofício (e a animação, quando muda).
const FASE := {
	"People/Viuva": "viuva", "People/Vendedor": "feirante2", "People/Guarda": "guarda", "People/Padeiro": "padeiro",
	"People/Bras": "mendigo", "People/Crianca": "crianca", "People/Garoto": "crianca",
	"Crowd/GuardaPortao": "guarda", "Crowd/Freguês": "dona_de_casa", "Crowd/Freguês2": "comprador_pao",
	"Crowd/Freguês3": "mercador", "Crowd/Sentado": "velho", "Crowd/Sentado2": "aldea", "Crowd/Hospede": "viajante",
	"Crowd/NaTaverna": "freguês_taverna", "Crowd/NaTaverna2": "freguês_taverna", "Crowd/FerreiroTrabalhando": "ferreiro",
	"Crowd/Crianca2": "crianca", "Crowd/Crianca3": "crianca", "Crowd/Leitora": "leitora", "Crowd/NoCemiterio": "coveiro",
	"Crowd/Lavrador": "lavrador", "Crowd/Lavradora": "lavradora", "Crowd/Fazendeiro": "fazendeiro",
	"Crowd/Carregador": "carregador", "Crowd/Moleiro": "moleiro", "Crowd/Cavalarico": "cavalarico",
	"Crowd/Vendedor2": "feirante", "Crowd/Vendedor3": "feirante3", "Crowd/Vendedor4": "feirante2",
	"Atracoes/Musico": "bardo",
}
## Animação própria de quem trabalha (o ferreiro martela; o malabarista e o resto seguem como estão).
const ANIMACAO := {"Crowd/FerreiroTrabalhando": "1H_Melee_Attack_Chop"}
## Nas lojas: arquivo do interior -> {nó: ofício}. As outras casas: sorteio de Oficios.CASA.
const LOJAS := {
	"Taverna": {"Morador": "taverneiro", "Morador2": "freguês_taverna", "Morador3": "freguês_taverna",
		"Morador4": "freguês_taverna", "Morador5": "bardo"},
	"Capela": {"Morador": "padre", "Morador2": "fiel", "Morador3": "fiel"},
	"CasaDoConselho": {"Morador": "guarda", "Morador2": "conselheiro"},
	"CasaDoMercador": {"Morador": "mercador"},
	"Casa_estreita": {"Morador": "alfaiate"},
	"Casa_estreita_pedra2": {"Morador": "boticaria"},
	"Estalagem": {"Morador": "estalajadeira"},
	"Sapateiro": {"Morador": "sapateiro"},
}


func _initialize() -> void:
	_run.call_deferred()


func _figure(holder: Node) -> Figurante:
	if holder == null:
		return null
	if holder is Figurante:
		return holder
	return holder.get_node_or_null("Figure") as Figurante


func _run() -> void:
	(load("res://world/level.gd") as GDScript).set("editing", true)
	var level := (ResourceLoader.load(LEVEL, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	root.add_child(level)
	await process_frame
	var done := 0
	for path: String in FASE:
		var fig := _figure(level.get_node_or_null(path))
		if fig == null:
			print("não achei ", path)
			continue
		fig.oficio = String(FASE[path])
		if ANIMACAO.has(path):
			fig.animacao = String(ANIMACAO[path])
		done += 1
	var packed := PackedScene.new()
	print("fase: ", done, " pessoas | pack ", packed.pack(level), " save ", ResourceSaver.save(packed, LEVEL))
	level.queue_free()
	# os interiores (cada um é uma cena)
	var rooms := 0
	for file: String in DirAccess.get_files_at(INTERIORES):
		if not file.ends_with(".tscn"):
			continue
		var path := INTERIORES + file
		var scene := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var shop: Dictionary = LOJAS.get(file.get_basename(), {})
		var roll := RandomNumberGenerator.new()
		roll.seed = hash(file)
		var changed := false
		for holder: Node in scene.get_children():
			if not String(holder.name).begins_with("Morador"):
				continue
			var fig := _figure(holder)
			if fig == null:
				continue
			fig.oficio = String(shop.get(String(holder.name), Oficios.CASA[roll.randi() % Oficios.CASA.size()]))
			changed = true
		if changed:
			var out := PackedScene.new()
			out.pack(scene)
			ResourceSaver.save(out, path)
			rooms += 1
		scene.free()
	print("interiores: ", rooms)
	quit()
