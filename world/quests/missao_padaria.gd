class_name MissaoPadaria
extends Node
## Primeira missão do Tico em Arandu (D040), "Caminho 1 — Pedir" do Gabriel: o Tico acorda com fome; o dono da
## padaria não dá comida de graça. Dá para conversar, convencer (Persuasão), fazer um favor (levar uma encomenda
## até a casa da viúva), intimidar (Intimidação) ou roubar (Furtividade). Os testes rolam o d20 como no D&D 5.5.
## Tudo fica em Game.flags ("padaria.*"), então vale com o jogo salvo. Falas: *(proposta)* em docs/gdd/01-historia.md.

## Atrás do balcão: conversa com o padeiro.
@export var padeiro: Interactable
## Na porta da casa da viúva: onde a encomenda é entregue.
@export var viuva: Interactable
## Marcas no mundo ("!" sobre o padeiro, seta sobre a viúva).
@export var marca_padeiro: Node3D
@export var marca_viuva: Node3D

const PADEIRO := "Padeiro"
const VIUVA := "Viúva"
## Dificuldade de cada teste (CD).
const CD_CONVENCER := 13
const CD_INTIMIDAR := 14
const CD_ROUBAR := 12
const CD_ROUBAR_EXPULSO := 16
## Perícias de cada herói *(proposta)*: Tico é ladino 3 kobold (DES alta, Furtividade com especialização).
const PERICIAS := {
	"tico": {"Persuasão": 2, "Intimidação": 0, "Furtividade": 7},
}

var _level: Level
var _hud: GameHUD
var _busy: bool = false


func _ready() -> void:
	if Level.editing:
		return
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	_level = node as Level
	if _level == null:
		return
	padeiro.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_padeiro))
	viuva.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_viuva))
	_level.play_started.connect(_start)
	_update_marks()


func estado() -> String:
	return String(Game.flag("padaria.estado", ""))


func _set_estado(value: String) -> void:
	Game.set_flag("padaria.estado", value)
	_update_marks()


## Começo: o Tico está com fome (só na primeira vez).
func _start() -> void:
	_hud = _level.get_node("HUD") as GameHUD
	if Game.flag("padaria.comecou", false):
		_update_marks()
		return
	Game.set_flag("padaria.comecou", true)
	Game.set_objective("Arrumar o que comer. Tem uma padaria na rua do leste.")
	_hud.toast("O Tico está com fome")
	_update_marks()


func _talk(fn: Callable) -> void:
	if _busy:
		return
	_busy = true
	if _hud == null:
		_hud = _level.get_node("HUD") as GameHUD
	_hud.begin_talk()
	await fn.call()
	_hud.end_talk()
	_busy = false
	_update_marks()
	_level.save_here(false)


# --- padeiro --------------------------------------------------------------------------------------

func _padeiro() -> void:
	var d := _hud.dialogue
	match estado():
		"entrega":
			await d.say(PADEIRO, "Ainda aqui? A casa da viúva, lá perto do portão do norte. Anda!")
			return
		"entregue":
			await d.say(PADEIRO, "Entregou? ...Ela pagou direitinho, é?")
			await d.say(PADEIRO, "Toma. Trato é trato: pão quentinho, saiu agora do forno.")
			Game.set_flag("padaria.jeito", "favor")
			await _eat("O Tico ganhou um pão quentinho.")
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
	await d.say(PADEIRO, "Ô, lagartixa. Ou compra, ou sai da frente do balcão.")
	while true:
		var options: Array[String] = ["Conversar", "Fazer um favor em troca"]
		var ids: Array[String] = ["conversar", "favor"]
		if not Game.flag("padaria.tentou_convencer", false):
			options.append("Convencer  [Persuasão]")
			ids.append("convencer")
		options.append("Intimidar  [Intimidação]")
		ids.append("intimidar")
		options.append("Roubar um pão  [Furtividade]")
		ids.append("roubar")
		options.append("Ir embora")
		ids.append("sair")
		var index: int = await d.choose(PADEIRO, "E então?", options)
		var pick := ids[index]
		match pick:
			"conversar":
				await d.say("Tico", "Tô com fome. Sobrou pão de ontem?")
				await d.say(PADEIRO, "Pão de ontem eu vendo pela metade do preço. Metade de nada continua sendo nada.")
				await d.say(PADEIRO, "...Se bem que hoje eu tô sem ajudante.")
			"favor":
				await d.say("Tico", "E se eu fizer alguma coisa em troca?")
				await d.say(PADEIRO, "Hm. Tem uma entrega que preciso fazer. Leva isso até aquela casa.")
				await d.say(PADEIRO, "A da viúva, lá perto do portão do norte. Volta aqui depois que eu te pago em pão.")
				Game.add_item("encomenda")
				_set_estado("entrega")
				Game.set_objective("Levar a encomenda do padeiro até a casa da viúva, perto do portão do norte.")
				_hud.toast("Recebeu: encomenda do padeiro")
				return
			"convencer":
				await d.say("Tico", "Um pão velho não vai te fazer falta. E eu falo bem da padaria pra cidade inteira.")
				Game.set_flag("padaria.tentou_convencer", true)
				if await _check("Persuasão", CD_CONVENCER):
					await d.say(PADEIRO, "Pra cidade inteira, é? ...Tá. Pega esse, tá meio duro. E fala bem mesmo, hein.")
					Game.set_flag("padaria.jeito", "convenceu")
					await _eat("O Tico ganhou um pão meio duro. Ainda é pão.")
					return
				await d.say(PADEIRO, "Ninguém escuta mendigo, kobold. Não.")
			"intimidar":
				await d.say("Tico", "Me dá um pão, ou eu conto pra cidade toda o que tem nessa massa.")
				if await _check("Intimidação", CD_INTIMIDAR):
					await d.say(PADEIRO, "Que... que história é essa? ...Pega. Pega e some daqui.")
					Game.set_flag("padaria.jeito", "intimidou")
					await _eat("O Tico saiu com um pão. O padeiro não vai esquecer.")
					return
				await d.say(PADEIRO, "Um lagartinho me ameaçando? FORA da minha padaria!")
				_set_estado("expulso")
				Game.set_objective("Arrumar o que comer. O padeiro te expulsou; ainda dá para tentar a sorte no balcão.")
				return
			"roubar":
				await _steal(CD_ROUBAR)
				return
			"sair":
				await d.say(PADEIRO, "Isso. Vai.")
				return


func _expelled() -> void:
	var d := _hud.dialogue
	var pick := await d.choose(PADEIRO, "Já falei: FORA!", ["Ir embora", "Esperar ele se distrair e pegar um pão  [Furtividade, mais difícil]"])
	if pick == 1:
		await _steal(CD_ROUBAR_EXPULSO)


## Roubar do balcão. Devolve true se conseguiu.
func _steal(dc: int) -> bool:
	var d := _hud.dialogue
	await d.say("", "O Tico espera o padeiro se virar para o forno...")
	if await _check("Furtividade", dc):
		await d.say("", "...e um pão some do balcão sem fazer barulho.")
		Game.set_flag("padaria.jeito", "roubou")
		await _eat("O Tico sai da padaria com o pão escondido debaixo do capuz.")
		return true
	await d.say(PADEIRO, "EI! Larga isso, ladrão! FORA!")
	_set_estado("expulso")
	Game.set_objective("Arrumar o que comer. O padeiro te pegou no flagra e te expulsou.")
	return false


# --- viúva --------------------------------------------------------------------------------------

func _viuva() -> void:
	var d := _hud.dialogue
	if estado() == "entrega" and Game.has_item("encomenda"):
		await d.say(VIUVA, "Ah, a encomenda do padeiro! Achei que ele tinha esquecido de mim.")
		await d.say(VIUVA, "Obrigada, menino. Diz pra ele que tá pago.")
		Game.remove_item("encomenda")
		_set_estado("entregue")
		Game.set_objective("Voltar à padaria e pegar o pão com o padeiro.")
		_hud.toast("Entregou a encomenda")
		return
	if estado() in ["entregue", "feito"] and Game.flag("padaria.jeito", "favor") == "favor":
		await d.say(VIUVA, "Obrigada pela entrega, menino.")
		return
	await d.say(VIUVA, "Bom dia, menino. Tá com uma cara de fome...")


# --- regras ---------------------------------------------------------------------------------------

## Teste de perícia (D&D 5.5): d20 + bônus contra a CD. Mostra a rolagem na conversa.
func _check(skill: String, dc: int) -> bool:
	var hero := Game.chosen
	var bonus: int = PERICIAS.get(hero, {}).get(skill, 0)
	var roll := Dice.d20()
	var total := roll + bonus
	var ok := roll == 20 or (roll != 1 and total >= dc)
	Game.set_flag("padaria.ultimo_teste", {"pericia": skill, "d20": roll, "total": total, "cd": dc})
	Audio.play("qte_perfeito" if ok else "qte_errou", -6.0)
	await _hud.dialogue.say("", "[color=#ffd9a0]%s[/color]   d20 [b]%d[/b] %+d = [b]%d[/b]   contra CD %d   %s" % [
		skill, roll, bonus, total, dc, "[color=#9be37a]conseguiu[/color]" if ok else "[color=#ff8a70]falhou[/color]"])
	return ok


## Fim da fome: o Tico come o pão na hora.
func _eat(text: String) -> void:
	_set_estado("feito")
	await _hud.dialogue.say("", text)
	await _hud.dialogue.say("", "Ele come ali mesmo, quase sem mastigar. A barriga, enfim, para de reclamar.")
	Game.set_objective("")
	Audio.play("vitoria", -8.0)
	_hud.toast("Missão concluída: Fome")
	if _level.player:
		_level.player.rest()
		Game.hero_hp = -1


func _update_marks() -> void:
	var e := estado()
	var started: bool = Game.flag("padaria.comecou", false)
	if marca_padeiro:
		marca_padeiro.visible = started and e in ["", "entregue"]
		if marca_padeiro is Label3D:
			(marca_padeiro as Label3D).text = "?" if e == "entregue" else "!"
	if marca_viuva:
		marca_viuva.visible = e == "entrega"
