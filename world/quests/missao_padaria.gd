class_name MissaoPadaria
extends Node
## Primeira missão do Tico em Arandu (D040), "Caminho 1 — Pedir" do Gabriel: o Tico acorda com fome; o dono da
## padaria não dá comida de graça. Dá para conversar, convencer (Persuasão), fazer um favor (levar uma encomenda
## até a casa da viúva), intimidar (Intimidação) ou roubar (Furtividade). Os testes rolam o d20 na tela (D&D 5.5).
## D058: o padeiro anda pela padaria (PadeiroIA). Só dá para falar com ele quando está atendendo no balcão; só dá
## para roubar (pegar um pão do balcão, sem conversa) quando ele está de costas, trabalhando.
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
	if roubo:
		roubo.used.connect(func(by: Combatant, _w: Interactable) -> void: _steal_at_counter(by))
	_level.play_started.connect(_start)
	_update_marks()


func _process(_delta: float) -> void:
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
	if ia:
		ia.hold(true)
	await fn.call()
	if ia:
		ia.hold(false)
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
				Game.set_objective("Arrumar o que comer. O padeiro te expulsou; ainda dá para pegar um pão quando ele virar as costas.")
				return
			"sair":
				await d.say(PADEIRO, "Isso. Vai.")
				return


func _expelled() -> void:
	await _hud.dialogue.say(PADEIRO, "Já falei: FORA!")


## Roubar do balcão (D058): sem conversa. O d20 rola na tela; deu certo, o Tico come; deu errado, o padeiro vira, grita
## e expulsa. Depois de expulso dá para tentar de novo, mais difícil.
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
		_hud.toast("Um pão some do balcão sem fazer barulho")
		await get_tree().create_timer(1.6).timeout
		await _eat_quiet("O Tico come o pão escondido debaixo do capuz")
	else:
		if ia:
			ia.look_at_thief(by.global_position, 3.5)
		_shout("EI! LADRÃO! FORA!")
		Audio.play("qte_errou", -2.0)
		_set_estado("expulso")
		Game.set_objective("Arrumar o que comer. O padeiro te pegou no flagra; espera ele virar as costas de novo.")
	_busy = false
	_update_marks()
	_level.save_here(false)


## O grito do padeiro em cima da cabeça dele (sem caixa de conversa).
func _shout(text: String) -> void:
	var baker := padeiro.get_parent() as Node3D
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/cinzel.ttf")
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color(1, 0.45, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	baker.add_child(label)
	label.position = Vector3(0, 2.3, 0)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", 2.6, 2.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(1.6)
	tween.tween_callback(label.queue_free)


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


## Come sem conversa (roubo): só avisos na tela.
func _eat_quiet(text: String) -> void:
	_set_estado("feito")
	_hud.toast(text)
	Game.set_objective("")
	await get_tree().create_timer(1.8).timeout
	Audio.play("vitoria", -8.0)
	_hud.toast("Missão concluída: Fome")
	if _level.player:
		_level.player.rest()
		Game.hero_hp = -1


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
	# o d20 rolando na tela, como na luta (D058)
	await _hud.roll_check(_level.player, skill, roll, bonus, dc, ok)
	Audio.play("qte_perfeito" if ok else "qte_errou", -6.0)
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
