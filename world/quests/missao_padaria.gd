class_name MissaoPadaria
extends Missao
## Primeira missão do Tico em Arandu (D040), "Caminho 1 — Pedir" do Gabriel: o dono da padaria não dá comida de
## graça. Dá para conversar, convencer (Persuasão), fazer um favor (levar uma encomenda até a casa da viúva),
## intimidar (Intimidação) ou roubar (Furtividade). Os testes rolam o d20 na tela (D&D 5.5).
## D058: o padeiro anda pela padaria (PadeiroIA). Só dá para falar com ele quando está atendendo no balcão; só dá
## para roubar (pegar um pão do balcão, sem conversa) quando ele está de costas, trabalhando.
## D059: é um dos jeitos de "conseguir comida para os dois" do prólogo. O pão vai para a Tika (Missao._got_food);
## a missão começa quando o Tico sai do beco (Game.flag "comida.comecou").
## D060: pego roubando (ou depois de ameaçar e se dar mal), o padeiro fica furioso e CORRE atrás do Tico pela rua
## com o rolo de massa; se alcança, vira briga (arena de rua, sem morte); se o Tico escapa, ele desiste ofegante.
## Expulso, entrar na padaria de novo faz ele vir de novo. A cidade reage ("Pega ladrão!").
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
## Perseguição (D060).
const CHASE_SPEED := 4.3
const CHASE_TIME := 14.0
const BRIGA := {
	"id": "briga_padeiro",
	"enemies": ["res://actors/enemies/padeiro_furioso.tscn"],
	"first_strike": false,
	"arena": "res://levels/arenas/arandu_rua.tscn",
	"nao_letal": true,
	"after_text": "O padeiro senta no chão, sem ar, e joga um pão na sua direção: \"Leva. Leva e some!\"",
	"texto_derrota": "O padeiro te arrasta pela gola e te joga no meio da rua. O olho do Tico vai ficar roxo amanhã.",
}

var _chasing: bool = false
var _chase_cool: float = 0.0


func _setup() -> void:
	padeiro.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_padeiro, padeiro.get_parent() as Node3D))
	viuva.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_viuva, viuva.get_parent() as Node3D))
	if roubo:
		roubo.used.connect(func(by: Combatant, _w: Interactable) -> void: _steal_at_counter(by))
	_level.play_started.connect(_start)
	_update_marks()


func _process(delta: float) -> void:
	if _level == null:
		return
	_chase_cool -= delta
	# expulso: pôr o pé na padaria de novo faz ele vir para cima
	if estado() == "expulso" and not _chasing and not _busy and _chase_cool <= 0.0 and _level.ready_to_play and _inside_shop():
		_chase(_level.player, "VOCÊ DE NOVO?! FORA DAQUI!")
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
	_after_fight()


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
				# a conversa fecha e ele vem para cima (D060)
				_chase_cool = 0.0
				(func() -> void: _chase(_level.player, "SAI DAQUI!")).call_deferred()
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
		Audio.play("qte_errou", -2.0)
		_set_estado("expulso")
		Game.set_objective("Arrumar comida. O padeiro te pegou no flagra. Corre!", "Fome")
		_busy = false
		_update_marks()
		_chase(by, "EI! LADRÃO! VOLTA AQUI!")
		return
	_busy = false
	_update_marks()
	_level.save_here(false)


# --- perseguição e briga (D060) -------------------------------------------------------------------

## O padeiro larga tudo e corre atrás de você. Alcançou: briga. Você sumiu: ele desiste e volta para o balcão.
func _chase(by: Combatant, cry: String) -> void:
	if _chasing or by == null or DisplayServer.get_name() == "headless":
		if not _chasing:
			Game.set_flag("padaria.perseguiu", true)
		return
	_chasing = true
	Game.set_flag("padaria.perseguiu", true)
	var baker := padeiro.get_parent() as Node3D
	var fig := baker.get_node_or_null("Figure")
	if ia:
		ia.hold(true)
	padeiro.enabled = false
	Emote.play(baker, "raiva", 3.0)
	Missao.shout(baker, cry)
	_alarm_town(baker)
	if fig:
		fig.set("animacao", "Running_A")
	var map := baker.get_world_3d().navigation_map
	var shop := ia.padaria if ia else baker
	var t := 0.0
	var repath := 0.0
	var route := PackedVector3Array()
	var step := 0
	var shout_again := 4.0
	while t < CHASE_TIME and is_inside_tree():
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		repath -= dt
		shout_again -= dt
		var me := _level.player
		if me == null or not is_instance_valid(me):
			break
		var gap := baker.global_position.distance_to(me.global_position)
		if gap < 1.15:
			await _caught(baker, me)
			return
		if (gap > 11.0 and t > 3.0) or baker.global_position.distance_to(shop.global_position) > 30.0:
			break
		if shout_again <= 0.0:
			shout_again = randf_range(3.0, 5.0)
			Missao.shout(baker, ["PARA AÍ!", "LADRÃO!", "EU TE PEGO, LAGARTIXA!", "SEGURA ESSE KOBOLD!"][randi() % 4])
		if repath <= 0.0:
			repath = 0.3
			route = NavigationServer3D.map_get_path(map, baker.global_position, me.global_position, true)
			step = 1 if route.size() > 1 else 0
		if route.is_empty():
			continue
		var target := route[mini(step, route.size() - 1)]
		target.y = baker.global_position.y
		var to := target - baker.global_position
		if to.length() < 0.2 and step < route.size() - 1:
			step += 1
			continue
		baker.global_position += to.normalized() * minf(CHASE_SPEED * dt, to.length())
		baker.rotation.y = lerp_angle(baker.rotation.y, atan2(-to.x, -to.z), minf(1.0, dt * 10.0))
	# escapou: ele para, sem fôlego, grita e volta para o balcão
	if fig:
		fig.set("animacao", "Idle")
	Emote.play(baker, "gota", 2.5)
	Missao.shout(baker, "E NÃO VOLTA, LADRÃO!")
	Game.set_flag("padaria.fugiu", true)
	await get_tree().create_timer(1.6).timeout
	await _walk_back(baker, fig)
	_chasing = false
	_chase_cool = 20.0
	_level.save_here(false)


## Alcançou o Tico: os dois param, ele grita e vira briga na arena de rua (sem morte, D060).
func _caught(baker: Node3D, me: Combatant) -> void:
	_level.controller.enabled = false
	_level.turn_toward(me, baker.global_position)
	var fig := baker.get_node_or_null("Figure")
	if fig:
		fig.set("animacao", "Cheer")
	Emote.play(baker, "raiva", 2.0)
	Missao.shout(baker, "TE PEGUEI!")
	Audio.play("impacto", -4.0)
	await get_tree().create_timer(1.2).timeout
	Game.set_flag("padaria.briga", "pendente")
	_level.save_here(false)
	Game.start_battle(BRIGA.duplicate(true), _level.scene_file_path, me.global_transform, me.hp)


## Volta andando para o balcão (pelo mapa de navegação) e devolve o padeiro para a IA dele.
func _walk_back(baker: Node3D, fig: Node) -> void:
	var counter := ia.padaria.get_node_or_null("PontoBalcao") as Node3D if ia and ia.padaria else null
	if counter:
		var route := NavigationServer3D.map_get_path(baker.get_world_3d().navigation_map, baker.global_position, counter.global_position, true)
		if fig:
			fig.set("animacao", "Walking_A")
		for p: Vector3 in route:
			var target := Vector3(p.x, baker.global_position.y, p.z)
			while baker.global_position.distance_to(target) > 0.1 and is_inside_tree():
				await get_tree().physics_frame
				var dt := get_physics_process_delta_time()
				var to := target - baker.global_position
				baker.global_position += to.normalized() * minf(1.7 * dt, to.length())
				baker.rotation.y = lerp_angle(baker.rotation.y, atan2(-to.x, -to.z), minf(1.0, dt * 8.0))
	if ia:
		ia.call("_go_to", 0, true)
		ia.hold(false)
	padeiro.enabled = true


## Quem está perto vê a confusão: susto e "Pega ladrão!".
func _alarm_town(near: Node3D) -> void:
	var vida := _level.get_node_or_null("Vida") as Vida
	if vida == null:
		return
	var said := false
	for person: Passante in vida.people:
		if person.visible and person.global_position.distance_to(near.global_position) < 16.0:
			Emote.play(person, "!" if randf() < 0.6 else "susto", 1.8)
			if not said and randf() < 0.6:
				said = true
				Fala.say(person, ["Pega ladrão!", "Olha o kobold!", "De novo esse aí?", "Corre, pequeno!"][randi() % 4])


## Você está dentro da padaria (pelo chão dela).
func _inside_shop() -> bool:
	if ia == null or ia.padaria == null or _level.player == null:
		return false
	var local := ia.padaria.global_transform.affine_inverse() * _level.player.global_position
	return absf(local.x) < 3.8 and local.z > -4.6 and local.z < 4.6


## Voltando da briga na arena (D060): ganhou, ele desiste e joga um pão; perdeu, você foi parar na rua.
func _after_fight() -> void:
	if Game.flag("padaria.briga", "") != "pendente":
		return
	var result := String(Game.flag("luta.briga_padeiro", ""))
	var baker := padeiro.get_parent() as Node3D
	if result == "venceu":
		Game.set_flag("padaria.briga", "venceu")
		Game.set_flag("padaria.jeito", "brigou")
		Emote.play(baker, "gota", 3.0)
		Fala.say(baker, "Tá bom, tá bom... leva e some!", 3.0)
		await _bread("um pão amassado na briga")
	elif result == "perdeu":
		Game.set_flag("padaria.briga", "perdeu")
		Fala.say(baker, "E fica esperto, lagartixa!", 3.0)
		Emote.play(baker, "raiva", 2.0)
		Game.set_objective("Arrumar comida. O padeiro te deu uma surra; melhor tentar outro jeito.", "Fome")
	_chase_cool = 25.0
	_update_marks()


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
