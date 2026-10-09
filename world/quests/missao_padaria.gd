class_name MissaoPadaria
extends Missao
## Primeira missão do Tico em Arandu (D040), "Caminho 1 — Pedir" do Gabriel: o dono da padaria não dá comida de
## graça. Dá para conversar, convencer (Persuasão), fazer um favor (levar uma encomenda até a casa da viúva),
## intimidar (Intimidação) ou roubar (Furtividade). Os testes rolam o d20 na tela (D&D 5.5).
## D058: o padeiro anda pela padaria (PadeiroIA). Só dá para falar com ele quando está atendendo no balcão; só dá
## para roubar (pegar um pão do balcão, sem conversa) quando ele está de costas, trabalhando.
## D059: é um dos jeitos de "conseguir comida para os dois" do prólogo. O pão vai para a Tika (Missao._got_food);
## a missão começa quando o Tico sai do beco (Game.flag "comida.comecou").
## Tudo fica em Game.flags ("padaria.*"), então vale com o jogo salvo. Falas: *(proposta)* em docs/gdd/01-historia.md.

## Atrás do balcão: conversa com o padeiro.
@export var padeiro: Interactable
## Na porta da casa da viúva: onde a encomenda é entregue.
@export var viuva: Interactable
## Marcas no mundo ("!" sobre o padeiro, seta sobre a viúva).
@export var marca_padeiro: Node3D
@export var marca_viuva: Node3D
## O jeito do padeiro andar e atender (D058).
@export var ia: PadeiroIA
## No balcão, do lado dos fregueses: "Pegar um pão" (só com ele de costas).
@export var roubo: Interactable

const PADEIRO := "Padeiro"
const VIUVA := "Viúva"
## Dificuldade de cada teste (CD).
const CD_CONVENCER := 13
const CD_INTIMIDAR := 14
const CD_ROUBAR := 12
const CD_ROUBAR_EXPULSO := 16


func _setup() -> void:
	padeiro.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_padeiro, padeiro.get_parent() as Node3D))
	viuva.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_viuva, viuva.get_parent() as Node3D))
	if roubo:
		roubo.used.connect(func(by: Combatant, _w: Interactable) -> void: _steal_at_counter(by))
	_level.play_started.connect(_start)
	_update_marks()


func _process(_delta: float) -> void:
	if _level == null:
		return
	# o prólogo (D059) solta a missão quando o Tico sai do beco
	if not Game.flag("padaria.comecou", false) and Game.flag("comida.comecou", false):
		Game.set_flag("padaria.comecou", true)
		_update_marks()
	if ia == null:
		return
	# falar só com ele atendendo; roubar só com ele de costas (e enquanto o Tico ainda está com fome)
	padeiro.enabled = ia.attending() or _busy
	if roubo:
		roubo.enabled = not _busy and ia.back_turned() and estado() in ["", "expulso"] and Game.flag("padaria.comecou", false)


func estado() -> String:
	return String(Game.flag("padaria.estado", ""))


func _set_estado(value: String) -> void:
	Game.set_flag("padaria.estado", value)
	_update_marks()


## Quem não é o Tico (sem prólogo) já começa com fome; o Tico espera o prólogo soltar a missão.
func _start() -> void:
	if Game.chosen != "tico" and not Game.flag("comida.comecou", false):
		Game.set_flag("comida.comecou", true)
		Game.set_objective("Arrumar o que comer. Tem uma padaria perto da praça.", "Fome")
	_update_marks()


func _before_talk() -> void:
	if ia:
		ia.hold(true)


func _after_talk() -> void:
	if ia:
		ia.hold(false)
	_update_marks()


# --- padeiro --------------------------------------------------------------------------------------

func _padeiro() -> void:
	var d := _hud.dialogue
	match estado():
		"entrega":
			await d.say(PADEIRO, "Ainda aqui? A casa da viúva, lá perto do portão do norte. Anda!")
			return
		"entregue":
			await d.say(PADEIRO, "Entregou? ...Ela pagou direitinho, é?")
			await d.say(PADEIRO, "Toma. Trato é trato: dois pães quentinhos, saíram agora do forno.")
			Game.set_flag("padaria.jeito", "favor")
			await _bread("dois pães quentinhos")
			return
		"feito":
			await d.say(PADEIRO, String({
				"favor": "Precisando de entrega de novo, já sabe onde me achar.",
				"convenceu": "E aí, tá falando bem da padaria por aí?",
				"intimidou": "...Some daqui.",
				"roubou": "Hm. Juro que tinha mais um pão nesse balcão.",
			}.get(String(Game.flag("padaria.jeito", "")), "Bom dia.")))
			return
		"expulso":
			await _expelled()
			return
	if not Game.flag("padaria.comecou", false):
		await d.say(PADEIRO, "Bom dia. Pão é com moeda. Sem moeda, sem pão.")
		return
	await d.say(PADEIRO, "Ô, lagartixa. Ou compra, ou sai da frente do balcão.")
	while true:
		var options: Array[String] = ["Conversar", "Fazer um favor em troca"]
		var ids: Array[String] = ["conversar", "favor"]
		if not Game.flag("padaria.tentou_convencer", false):
			options.append("Convencer  [Persuasão]")
			ids.append("convencer")
		options.append("Intimidar  [Intimidação]")
		ids.append("intimidar")
		options.append("Ir embora")
		ids.append("sair")
		var index: int = await d.choose(PADEIRO, "E então?", options)
		var pick := ids[index]
		match pick:
			"conversar":
				await d.say("Tico", "A gente tá com fome. Eu e a Tika. Sobrou pão de ontem?")
				await d.say(PADEIRO, "Sabe quanto tá o saco de farinha? O dobro do mês passado.")
				await d.say(PADEIRO, "E semana passada um de vocês levou dois pães e a minha bandeja. A BANDEJA.")
				await d.say(PADEIRO, "...Se bem que hoje eu tô sem ajudante.")
			"favor":
				await d.say("Tico", "E se eu fizer alguma coisa em troca?")
				await d.say(PADEIRO, "Hm. Tem uma entrega que preciso fazer. Leva isso até aquela casa.")
				await d.say(PADEIRO, "A da viúva, lá perto do portão do norte. Volta aqui depois que eu te pago em pão.")
				Game.add_item("encomenda")
				_set_estado("entrega")
				Game.set_objective("Levar a encomenda do padeiro até a casa da viúva, perto do portão do norte.", "Fome")
				_hud.toast("Recebeu: encomenda do padeiro")
				return
			"convencer":
				await d.say("Tico", "Um pão velho não vai te fazer falta. E eu falo bem da padaria pra cidade inteira.")
				Game.set_flag("padaria.tentou_convencer", true)
				if await _check("Persuasão", CD_CONVENCER):
					await d.say(PADEIRO, "Pra cidade inteira, é? ...Tá. Pega esse, tá meio duro. E fala bem mesmo, hein.")
					Game.set_flag("padaria.jeito", "convenceu")
					await _bread("um pão meio duro")
					return
				await d.say(PADEIRO, "Ninguém escuta mendigo, kobold. Não.")
			"intimidar":
				await d.say("Tico", "Me dá um pão, ou eu conto pra cidade toda o que tem nessa massa.")
				if await _check("Intimidação", CD_INTIMIDAR):
					await d.say(PADEIRO, "Que... que história é essa? ...Pega. Pega e some daqui.")
					Game.set_flag("padaria.jeito", "intimidou")
					await _bread("um pão (o padeiro não vai esquecer)")
					return
				await d.say(PADEIRO, "Um lagartinho me ameaçando? FORA da minha padaria!")
				_set_estado("expulso")
				Game.set_objective("Arrumar comida. O padeiro te expulsou; ainda dá para pegar um pão quando ele virar as costas.", "Fome")
				return
			"sair":
				await d.say(PADEIRO, "Isso. Vai.")
				return


func _expelled() -> void:
	await _hud.dialogue.say(PADEIRO, "Já falei: FORA!")


## Roubar do balcão (D058): sem conversa. O d20 rola na tela; deu certo, o Tico esconde o pão; deu errado, o padeiro
## vira, grita e expulsa. Depois de expulso dá para tentar de novo, mais difícil.
func _steal_at_counter(by: Combatant) -> void:
	if _busy or (ia and not ia.back_turned()):
		return
	_busy = true
	if _hud == null:
		_hud = _level.get_node("HUD") as GameHUD
	var dc := CD_ROUBAR_EXPULSO if estado() == "expulso" else CD_ROUBAR
	if await _check("Furtividade", dc):
		Game.set_flag("padaria.jeito", "roubou")
		_hide_one_bread()
		await _bread("um pão escondido debaixo do capuz")
	else:
		if ia:
			ia.look_at_thief(by.global_position, 3.5)
		Missao.shout(padeiro.get_parent() as Node3D, "EI! LADRÃO! FORA!")
		Audio.play("qte_errou", -2.0)
		_set_estado("expulso")
		Game.set_objective("Arrumar comida. O padeiro te pegou no flagra; espera ele virar as costas de novo.", "Fome")
	_busy = false
	_update_marks()
	_level.save_here(false)


## Some um pão do balcão (o mais perto do lugar de pegar).
func _hide_one_bread() -> void:
	var best: Node3D = null
	var best_d := INF
	for found: Node in _level.find_children("PaoBalcao*", "", true, false):
		var bread := found as Node3D
		if bread and bread.visible and roubo:
			var dist := bread.global_position.distance_to(roubo.global_position)
			if dist < best_d:
				best_d = dist
				best = bread
	if best:
		best.visible = false


# --- viúva --------------------------------------------------------------------------------------

func _viuva() -> void:
	var d := _hud.dialogue
	if estado() == "entrega" and Game.has_item("encomenda"):
		await d.say(VIUVA, "Ah, a encomenda do padeiro! Achei que ele tinha esquecido de mim.")
		await d.say(VIUVA, "Com essa perna eu não chego na praça nem até o meio-dia. Obrigada, menino.")
		await d.say(VIUVA, "Diz pra ele que tá pago.")
		Game.remove_item("encomenda")
		_set_estado("entregue")
		Game.set_objective("Voltar à padaria e pegar o pão com o padeiro.", "Fome")
		_hud.toast("Entregou a encomenda")
		return
	if estado() in ["entregue", "feito"] and Game.flag("padaria.jeito", "favor") == "favor":
		await d.say(VIUVA, "Obrigada pela entrega, menino.")
		return
	await d.say(VIUVA, "Bom dia, menino. Tá com uma cara de fome...")
	await d.say(VIUVA, "Eu também. O padeiro ficou de mandar meu pão e até agora nada.")


# --- comida ---------------------------------------------------------------------------------------

## Conseguiu pão: o Tico guarda para dividir com a Tika (D059).
func _bread(what: String) -> void:
	_set_estado("feito")
	await _got_food("padaria", what)


func _update_marks() -> void:
	var e := estado()
	var started: bool = Game.flag("padaria.comecou", false)
	if marca_padeiro:
		marca_padeiro.visible = started and e in ["", "entregue"]
		if marca_padeiro is Label3D:
			(marca_padeiro as Label3D).text = "?" if e == "entregue" else "!"
	if marca_viuva:
		marca_viuva.visible = e == "entrega"
