class_name CapituloArandu
extends Missao
## O capítulo de Arandu depois do primeiro dia (D086): a Tika some e o Tico descobre para onde levaram ela.
##   1. "sumiu": a manhã do papelão vazio; procurar a Tika (o Seu Brás viu uma carroça coberta indo para o celeiro;
##      o vendedor e o Pipo também falam); no celeiro, a pista.
##   2. "celeiro": meses depois, o Seu Brás conta da organização de Cindralight que leva gente para alimentar uma forja;
##      de noite, no celeiro, dois capangas arrastam um mendigo: a primeira luta do Tico (tutorial, as adagas acendem).
##   3. "lutou": um capanga deixou cair a ordem de carga ("Forja de Cindralight, estrada do norte"); pegar as coisas
##      no barraco ("pronto") e sair pelo portão do norte: fim do capítulo ("saiu"), e a estrada leva a Ethera.
## Estado em Game.flags ("capitulo.etapa"), então vale com o jogo salvo. Falas *(proposta)*.

## A Tika (some neste capítulo) e o "Falar com a Tika".
@export var tika: Node3D
@export var falar_tika: Interactable
## O Seu Brás e o lugar dele na esquina (ele vai até o beco na cena dos meses e volta).
@export var bras: Node3D
@export var bras_esquina: Node3D
## Os dois capangas da Forja e o mendigo que eles arrastam (pessoas da fase, escondidas até a noite do celeiro).
@export var capangas: Array[Node3D] = []
@export var levado: Node3D
@export var falar_levado: Interactable
## A carroça do celeiro (o meio da cena dos capangas).
@export var carroca: Node3D
## A pista no celeiro (a fita, se ela estava com a Tika; senão, a marca de roda) e o laço que aparece no chão.
@export var pista: Interactable
@export var pista_laco: Node3D
## Pegar as coisas no barraco antes de sair.
@export var mochila: Interactable
## O portão do norte (no capítulo, quem cuida dele é este script).
@export var portao: Interactable
## A luta começa quando o Tico chega a essa distância (m) da carroça.
@export var raio_celeiro: float = 7.0

const CENA_VAZIO := "res://story/tico_papelao_vazio.tres"
const CENA_MESES := "res://story/tico_meses_depois.tres"
const CENA_SAIDA := "res://story/tico_saida.tres"
const CENA_FIM := "res://story/tico_fim_capitulo.tres"
const BRAS := "Seu Brás"
const LUTA := {
	"id": "capangas_forja",
	"enemies": ["res://actors/enemies/capanga_da_forja.tscn", "res://actors/enemies/lacador_da_forja.tscn"],
	"first_strike": true,
	"arena": "res://levels/arenas/arandu_rua.tscn",
	"nao_letal": true,
	"tutorial": true,
	"intro": [
		["", "Alguma coisa esquenta nas mãos do Tico. Duas lâminas de luz roxa, finas e gastas, do jeito exato das asas da Tika."],
		["Tico", "...Tá. Isso é novo."],
		["Capanga da Forja", "Pega ele!"],
	],
	"after_text": "Os dois largam a corrente e fogem pro escuro. Um deles deixa cair um papel dobrado.",
	"texto_derrota": "O Tico cai na lama. Os capangas riem e voltam pro mendigo, sem pressa nenhuma.",
}

## O capítulo em andamento (as conversas do Brás, do vendedor e do Pipo perguntam aqui).
static var atual: CapituloArandu

var _wait_start: float = 0.0
var _indo_pra_luta: bool = false


static func ativo() -> bool:
	return Game.chosen == "tico" and etapa() != ""


static func etapa() -> String:
	return String(Game.flag("capitulo.etapa", ""))


func _setup() -> void:
	if Game.chosen != "tico":
		set_process(false)
		_show_people("")
		return
	atual = self
	pista.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_pista, null))
	mochila.used.connect(func(_by: Combatant, _w: Interactable) -> void: _pegar_coisas())
	portao.used.connect(func(_by: Combatant, _w: Interactable) -> void: _no_portao())
	if falar_levado:
		falar_levado.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_conversa_levado, levado))
	_level.play_started.connect(_start)
	_arrumar()


func _exit_tree() -> void:
	if atual == self:
		atual = null


func _set_etapa(value: String) -> void:
	Game.set_flag("capitulo.etapa", value)
	_arrumar()


## Põe cada coisa onde ela deve estar nesta etapa (abrir o jogo salvo no meio do capítulo).
func _arrumar() -> void:
	var e := etapa()
	if e != "":
		tika.visible = false
		falar_tika.enabled = false
	_show_people(e)
	pista.enabled = e == "sumiu"
	pista.visible = e == "sumiu"
	if pista_laco:
		pista_laco.visible = e == "sumiu" and _tika_tinha_fita()
	mochila.enabled = e == "lutou"
	mochila.visible = e == "lutou"
	# no capítulo o portão é do capítulo (só sai depois de pegar as coisas); fora dele, a saída de sempre
	portao.action = Interactable.Action.QUEST if e in ["sumiu", "celeiro", "lutou", "pronto"] else Interactable.Action.TRAVEL


func _show_people(e: String) -> void:
	for c: Node3D in capangas:
		c.visible = e == "celeiro"
		var talk := c.get_node_or_null("Talk") as Interactable
		if talk:
			talk.enabled = false
	if levado:
		levado.visible = e in ["celeiro", "lutou", "pronto"]
	if falar_levado:
		falar_levado.enabled = e in ["lutou", "pronto"]


func _start() -> void:
	_arrumar()
	if etapa() == "celeiro":
		await _depois_da_luta()
	_objetivo()


## O objetivo na tela e a marca dourada em cima do lugar (D091: sem ela, o celeiro não se achava).
func _objetivo() -> void:
	var alvo: Node3D = null
	match etapa():
		"sumiu":
			if Game.flag("capitulo.bras", false):
				Game.set_objective("Ir até o celeiro da cidade, a leste da esquina do Seu Brás. Olhar o chão perto da carroça.",
					"A Tika sumiu")
				alvo = pista
			else:
				Game.set_objective("Procurar a Tika. O Seu Brás, na esquina perto do beco, vê tudo que passa na rua.",
					"A Tika sumiu")
				alvo = bras
		"celeiro":
			Game.set_objective("Ir até a carroça do celeiro, de noite. Os capangas da Forja estão lá.", "A Forja")
			alvo = carroca
		"lutou":
			Game.set_objective("Pegar as suas coisas no barraco.", "A Forja")
			alvo = mochila
		"pronto":
			Game.set_objective("Sair de Arandu pelo portão do norte.", "A Forja")
			alvo = portao
	if _level:
		_level.marcar_objetivo(alvo)


func _process(delta: float) -> void:
	if _level == null or _level.player == null or not _level.ready_to_play or _busy or _level.em_cena:
		return
	match etapa():
		"":
			# o primeiro dia acabou (o jantar): um instante depois, a manhã do papelão vazio
			if String(Game.flag("prologo.etapa", "")) == "fim":
				_wait_start += delta
				if _wait_start > 2.5:
					_papelao_vazio()
		"celeiro":
			if not _indo_pra_luta and _level.player.global_position.distance_to(carroca.global_position) < raio_celeiro:
				_ir_pra_luta()


# --- 1. o papelão vazio ---------------------------------------------------------------------------

func _papelao_vazio() -> void:
	_busy = true
	if String(Game.flag("feira.estado", "")) != "resolvido":
		# a briga da feira não começa no meio da procura
		Game.set_flag("feira.estado", "resolvido")
		if String(Game.flag("feira.jeito", "")) == "":
			Game.set_flag("feira.jeito", "ignorou")
	_set_etapa("sumiu")
	await _level.play_cutscene(load(CENA_VAZIO) as Roteiro)
	_busy = false
	_objetivo()
	_hud.show_area("O barraco")
	_hud.show_story("O papelão dela está vazio. O Seu Brás passa a noite inteira na esquina, logo ali: se alguém viu alguma coisa, foi ele.")
	_level.save_here(false)


## O Seu Brás no capítulo (a conversa dele chama aqui).
func fala_bras() -> void:
	var d := _hud.dialogue
	match etapa():
		"sumiu":
			if not Game.flag("capitulo.bras", false):
				await d.say(BRAS, "Tico? Que cara é essa, menino?")
				await d.say("Tico", "A Tika sumiu. Eu acordei e ela não tava.")
				await d.say(BRAS, "...")
				await d.say(BRAS, "Ontem, de madrugada, passou uma carroça coberta aqui na rua. Sem lanterna.")
				await d.say(BRAS, "Carroça boa não anda no escuro. Achei estranho e fiquei olhando.")
				await d.say(BRAS, "Ela parou no celeiro, do outro lado da rua. Depois não ouvi mais nada.")
				Game.set_flag("capitulo.bras", true)
				_objetivo()
			else:
				await d.say(BRAS, "O celeiro, menino. A carroça parou lá. Vai.")
		"celeiro":
			await d.say(BRAS, "Hoje à noite, no celeiro. Toma cuidado, menino.")
		_:
			await d.say(BRAS, "Vai atrás dela, Tico. Eu fico aqui, cuidando da esquina. Ela vai querer voltar pra cá.")


## O vendedor de frutas no capítulo.
func fala_vendedor() -> void:
	var d := _hud.dialogue
	if etapa() == "sumiu":
		await d.say("Vendedor", "Kobold? Não vi kobold nenhum.")
		if String(Game.flag("feira.jeito", "")) == "entregou":
			await d.say("Vendedor", "E olha, você me ajudou ontem com aquele moleque. Se eu visse, te contava.")
		else:
			await d.say("Vendedor", "E se visse, contava as frutas antes de contar pra você.")
	else:
		await d.say("Vendedor", "Fruta? Não? Então circulando.")


## O Pipo, o garoto da maçã, no capítulo.
func fala_pipo() -> void:
	var d := _hud.dialogue
	if etapa() != "sumiu":
		await d.say("Garoto", "Moço-planta! Você tá diferente. Mais sério.")
		return
	match String(Game.flag("feira.jeito", "")):
		"ajudou":
			await d.say("Garoto", "A moça kobold? A de roxo?")
			await d.say("Garoto", "Eu vi ela ontem de noite, sozinha, indo pro lado do celeiro. Achei que tava com você.")
			await d.say("Tico", "...Ela queria ver a gente nova.")
		"entregou":
			await d.say("Garoto", "Pergunta pro vendedor, dedo-duro. Ele vê tudo.")
		_:
			await d.say("Garoto", "Não vi não, moço-planta.")


## A pista no celeiro: a fita (se ela estava com a Tika) ou a marca de roda; e então os meses passam.
func _pista() -> void:
	var d := _hud.dialogue
	if _tika_tinha_fita():
		Game.add_item("fita")
		Audio.play("pegar_comida", -10.0, 0.2)
		await d.say("Tico", "A fita dela. A que eu achei ontem no beco.")
		await d.say("Tico", "Ela não largava isso por nada.")
	else:
		await d.say("Tico", "Marca de roda, funda, na lama. Uma carroça pesada.")
		await d.say("Tico", "E aqui, no chão... um pedaço de papelão. Do nosso.")
	await d.say("Tico", "Tika...")
	d.close()
	_meses_depois.call_deferred()


func _tika_tinha_fita() -> bool:
	# ela ganhou a fita de volta no jantar (o Tico achou no beco lateral e entregou)
	return bool(Game.flag("prologo.fita_achada", false)) and String(Game.flag("prologo.etapa", "")) == "fim" \
		and not Game.has_item("fita") and not Game.flag("capitulo.fita_pega", false)


# --- 2. meses depois: o Brás conta, e a noite no celeiro -------------------------------------------

func _meses_depois() -> void:
	_busy = true
	if Game.has_item("fita"):
		Game.set_flag("capitulo.fita_pega", true)
	_set_etapa("celeiro")
	await _level.play_cutscene(load(CENA_MESES) as Roteiro)
	bras.global_transform = bras_esquina.global_transform
	var figure := bras.get_node_or_null("Figure")
	if figure:
		figure.set("animacao", "Sit_Floor_Idle")
	_busy = false
	_objetivo()
	_level.save_here(false)


## Chegou no celeiro: os capangas, e a primeira luta (tutorial).
func _confronto() -> void:
	var d := _hud.dialogue
	var capanga := capangas[0]
	for c: Node3D in capangas:
		_level.turn_toward(c, _level.player.global_position)
	if not Game.flag("capitulo.ja_brigou", false):
		Missao.shout(levado, "Me larga! Eu não fiz nada!")
		await d.say("Capanga da Forja", "Olha só. Um lagarto.")
		await d.say("Laçador da Forja", "Mais um pra carroça. Esse é pequeno, vai queimar rápido.")
		await d.say("Tico", "Uma kobold roxa. Pequena, brava. Vocês levaram ela daqui, meses atrás. Cadê ela?")
		await d.say("Capanga da Forja", "A gente não pergunta o nome da lenha.")
	else:
		await d.say("Capanga da Forja", "Ainda não aprendeu, lagarto?")
	d.close()


## A conversa no celeiro e, depois dela, a arena (fora da conversa: ela salva o jogo quando fecha).
func _ir_pra_luta() -> void:
	_indo_pra_luta = true
	await _talk(_confronto, capangas[0])
	Game.set_flag("capitulo.ja_brigou", true)
	var me := _level.player
	Game.start_battle(LUTA.duplicate(true), _level.scene_file_path, me.global_transform, me.hp)


## Voltando da luta: ganhou, os capangas fugiram e deixaram a ordem de carga; perdeu, eles continuam lá.
func _depois_da_luta() -> void:
	var result := String(Game.flag("luta.capangas_forja", ""))
	if result == "":
		return
	Game.set_flag("luta.capangas_forja", "")
	if result != "venceu":
		Game.set_objective("Os capangas continuam no celeiro. Tentar de novo.", "A Forja")
		_level.player.global_position = carroca.global_position + (_level.player.global_position - carroca.global_position).normalized() * (raio_celeiro + 2.5)
		return
	_set_etapa("lutou")
	Game.add_item("ordem_de_carga")
	Audio.play("pegar_comida", -10.0, 0.2)
	_hud.toast("Achou: uma ordem de carga, dobrada em quatro")
	var d := _hud.dialogue
	_hud.begin_talk()
	await d.say("Ordem de carga", "ARANDU. Três cabeças. De rua, sem família, ninguém procura.")
	await d.say("Ordem de carga", "Entregar na FORJA DE CINDRALIGHT. Pela estrada do norte. Não parar em cidade nenhuma.")
	await d.say("Tico", "Cindralight. Pela estrada do norte.")
	await d.say("Tico", "...Aguenta mais um pouco, Tika.")
	d.close()
	_hud.end_talk()
	_level.save_here(false)


func _conversa_levado() -> void:
	var d := _hud.dialogue
	await d.say("Mendigo", "Obrigado, menino. Eu achei que era o fim.")
	if not Game.flag("capitulo.levado", false):
		Game.set_flag("capitulo.levado", true)
		var pick: int = await d.choose("Mendigo", "Você... você tá procurando alguém, né? Dá pra ver na cara.", [
			"Uma kobold roxa. Levaram ela daqui.",
			"Não é da sua conta.",
		])
		if pick == 0:
			await d.say("Mendigo", "Na carroça eles falavam de uma pequena. Roxa. Que mordeu um deles na viagem.")
			await d.say("Mendigo", "Diziam que ela não parava de brigar. Que ia dar trabalho na Forja.")
			await d.say("Tico", "...É ela.")
		else:
			await d.say("Mendigo", "Tá certo. Vai com cuidado, então.")
	else:
		await d.say("Mendigo", "Eu vou ficar com o Brás, na esquina. Lá ninguém mexe com a gente.")


# --- 3. a saída -----------------------------------------------------------------------------------

func _pegar_coisas() -> void:
	if _busy or etapa() != "lutou":
		return
	_busy = true
	var scene := Roteiro.new()
	var text := (load(CENA_SAIDA) as Roteiro).texto
	var ribbon := "Amarra a fita roxa dela no pulso, bem apertado." if Game.has_item("fita") else "Fica olhando um tempo pro canto dela."
	scene.texto = text.replace("{fita}", ribbon)
	await _level.play_cutscene(scene)
	_set_etapa("pronto")
	_busy = false
	_objetivo()
	_level.save_here(false)


func _no_portao() -> void:
	if _busy:
		return
	match etapa():
		"sumiu":
			_hud.show_thought("Não. Não sem a Tika.")
		"celeiro":
			_hud.show_thought("O Brás disse: hoje à noite, no celeiro.")
		"lutou":
			_hud.show_thought("Primeiro as minhas coisas, no barraco.")
		"pronto":
			_busy = true
			await _level.play_cutscene(load(CENA_FIM) as Roteiro)
			_set_etapa("saiu")
			Game.set_objective("")
			_busy = false
			_level.save_here(false)
			Game.travel(portao.target_scene)
