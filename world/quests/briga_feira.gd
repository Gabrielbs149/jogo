class_name BrigaFeira
extends Missao
## Uma situação no caminho (D059): na banca de frutas da praça, o vendedor acusa um garoto de ter pegado uma maçã.
## O Tico pode intervir (perguntar, defender o garoto, ficar do lado do vendedor) ou seguir andando. Ninguém está
## totalmente certo: o garoto pegou mesmo (para a irmã com febre) e o vendedor já perdeu três frutas na semana.
## Quem foi ajudado lembra do Tico depois; quem foi entregue também. Nada disso muda a história principal.
## Estado em Game.flags: "feira.estado" ("", "brigando", "resolvido") e "feira.jeito" ("ajudou", "entregou", "ignorou").

## O vendedor (People/Vendedor) e a conversa com ele (o Talk dele).
@export var vendedor: Node3D
@export var falar_vendedor: Interactable
## O garoto (People/Garoto): um Figurante dentro (Figure); "Intervir" e, depois, "Falar com o garoto".
@export var garoto: Node3D
@export var intervir: Interactable
@export var falar_garoto: Interactable
## Para onde o garoto vai depois (perto da fonte).
@export var lugar_depois: Node3D
## A briga começa quando o Tico chega a essa distância (m) da banca; longe disso de novo, ele seguiu andando.
@export var raio: float = 11.0
@export var raio_ignorar: float = 26.0

const VENDEDOR := "Vendedor"
const GAROTO := "Garoto"
const CD_INTUICAO := 12
const CD_DEFENDER := 15
const CD_DEFENDER_SABENDO := 11
const GRITOS: Array = [
	[true, "Eu vi! A maçã tava aqui e agora não tá!"],
	[false, "Eu não peguei nada!"],
	[true, "E esse bolso redondo aí, é o quê?"],
	[false, "É o meu bolso! Me larga!"],
	[true, "Alguém chama a guarda!"],
	[false, "Ninguém chama ninguém!"],
]

var _shout_time: float = 0.0
var _shout_index: int = 0


func _setup() -> void:
	intervir.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_intervir, vendedor))
	falar_garoto.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_garoto_depois, garoto))
	falar_vendedor.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_vendedor_depois, vendedor))
	if estado() == "resolvido" and lugar_depois:
		garoto.global_transform = lugar_depois.global_transform
		_figure_anim(&"Sit_Floor_Idle" if Game.flag("feira.jeito", "") != "ajudou" else &"Idle")


func estado() -> String:
	return String(Game.flag("feira.estado", ""))


func _process(delta: float) -> void:
	if _level == null or _level.player == null or not _level.ready_to_play:
		return
	var e := estado()
	intervir.enabled = e == "brigando"
	falar_garoto.enabled = e == "resolvido"
	falar_vendedor.enabled = e != "brigando"
	if not Game.flag("comida.comecou", false) or _busy:
		return
	var dist := _level.player.global_position.distance_to(vendedor.global_position)
	if e == "" and dist < raio:
		Game.set_flag("feira.estado", "brigando")
		_shout_time = 0.0
	elif e == "brigando":
		if dist > raio_ignorar:
			_resolve("ignorou")
			return
		_shout_time -= delta
		if _shout_time <= 0.0:
			_shout_time = 2.6
			var line: Array = GRITOS[_shout_index % GRITOS.size()]
			_shout_index += 1
			Missao.shout(vendedor if line[0] else garoto, String(line[1]), Color(1, 0.6, 0.45) if line[0] else Color(0.8, 0.9, 1.0),
				2.2 if line[0] else 1.4)


# --- intervir -------------------------------------------------------------------------------------

func _intervir() -> void:
	var d := _hud.dialogue
	_figure_anim(&"Idle")
	await d.say(VENDEDOR, "Fica fora disso, kobold. Esse moleque pegou uma maçã e saiu andando como se fosse dono da banca.")
	await d.say(GAROTO, "Eu não peguei nada! Ele que vive implicando comigo!")
	while true:
		var options: Array[String] = []
		var ids: Array[String] = []
		if not Game.flag("feira.perguntou", false):
			options.append("Olhar bem para o garoto  [Intuição]")
			ids.append("intuicao")
		options.append("Perguntar ao vendedor o que houve")
		ids.append("vendedor")
		options.append("Defender o garoto  [Persuasão]")
		ids.append("defender")
		options.append("Ficar do lado do vendedor")
		ids.append("vendedor_certo")
		options.append("Deixar pra lá")
		ids.append("sair")
		var pick: String = ids[await d.choose(VENDEDOR, "E aí? Vai ficar olhando?", options)]
		match pick:
			"intuicao":
				Game.set_flag("feira.perguntou", true)
				if await _check("Intuição", CD_INTUICAO):
					Game.set_flag("feira.sabe", true)
					await d.say("", "O bolso do garoto está redondo demais. E ele, magro demais. Ele não tira o olho do bolso.")
					await d.say("Tico", "Pegou, né?")
					await d.say(GAROTO, "...É pra minha irmã. Ela tá com febre e não come outra coisa.")
				else:
					await d.say("", "O garoto encara o Tico de volta, sem piscar. Impossível saber.")
			"vendedor":
				await d.say(VENDEDOR, "Terceira fruta que some essa semana. A guarda não faz nada e o aluguel da banca dobrou.")
				await d.say(VENDEDOR, "Se eu deixar um levar, amanhã vêm dez.")
			"defender":
				await d.say("Tico", "É uma maçã batida, moço. Essa aí nem você ia conseguir vender.")
				var dc := CD_DEFENDER_SABENDO if Game.flag("feira.sabe", false) else CD_DEFENDER
				if Game.flag("feira.sabe", false):
					await d.say("Tico", "E é pra irmã dele, que tá doente. Uma maçã não vai quebrar a banca.")
				if await _check("Persuasão", dc):
					await d.say(VENDEDOR, "...Tá. Leva. Mas se eu te pegar de novo, eu chamo a guarda. De verdade.")
					await d.say(GAROTO, "Valeu, moço!")
				else:
					await d.say(VENDEDOR, "Defende ele porque é igual a ele. Os dois, pra longe da minha banca!")
					await d.say("", "Na confusão, o garoto escapa correndo, com a maçã e tudo.")
					Game.set_flag("feira.vendedor_bravo", true)
				_resolve("ajudou")
				return
			"vendedor_certo":
				await d.say("Tico", "Devolve a maçã, moleque.")
				await d.say(GAROTO, "...")
				await d.say("", "O garoto tira a maçã do bolso, larga em cima da banca e vai embora sem olhar pra trás.")
				await d.say(VENDEDOR, "Finalmente alguém com juízo nessa cidade. Toma, pela ajuda. Tá batida, mas é fruta.")
				Game.set_flag("feira.maca", true)
				_hud.toast("Conseguiu: uma maçã batida")
				_resolve("entregou")
				return
			"sair":
				await d.say(VENDEDOR, "Isso, vai. Ninguém nunca faz nada mesmo.")
				return


func _resolve(how: String) -> void:
	Game.set_flag("feira.estado", "resolvido")
	Game.set_flag("feira.jeito", how)
	match how:
		"ignorou":
			Missao.shout(vendedor, "Devolve, moleque!", Color(1, 0.6, 0.45))
			Missao.shout(garoto, "Tá bom, tá bom!", Color(0.8, 0.9, 1.0), 1.4)
	_go_away.call_deferred(how)
	_level.save_here(false)


## O garoto sai da banca andando (ou correndo, se escapou) até perto da fonte, sem teleporte.
func _go_away(how: String) -> void:
	if lugar_depois == null:
		return
	var to := lugar_depois.global_position
	var from := garoto.global_position
	var dir := to - from
	dir.y = 0.0
	if dir.length() > 0.1:
		garoto.global_rotation.y = atan2(-dir.x, -dir.z)
	var run := how == "ajudou"
	_figure_anim(&"Running_A" if run else &"Walking_A")
	var tween := create_tween()
	tween.tween_property(garoto, "global_position", to, dir.length() / (3.2 if run else 1.2))
	await tween.finished
	garoto.global_transform = lugar_depois.global_transform
	_figure_anim(&"Idle" if run else &"Sit_Floor_Idle")


func _figure_anim(anim: StringName) -> void:
	var figure := garoto.get_node_or_null("Figure")
	if figure:
		figure.set("animacao", String(anim))


# --- depois ---------------------------------------------------------------------------------------

func _garoto_depois() -> void:
	var d := _hud.dialogue
	match String(Game.flag("feira.jeito", "")):
		"ajudou":
			if not Game.flag("feira.garoto_contou", false):
				Game.set_flag("feira.garoto_contou", true)
				await d.say(GAROTO, "Ei, moço! Valeu por aquela. Eu sou o Pipo.")
				await d.say(GAROTO, "A maçã era pra minha irmã. Ela comeu inteirinha, até o caroço.")
				await d.say(GAROTO, "Ó, uma dica: o padeiro vira de costas pra olhar o forno toda hora. Mas eu não te falei nada.")
			else:
				await d.say(GAROTO, "Valeu de novo, moço! Se precisar, eu conheço todo mundo nessa praça.")
		"entregou":
			await d.say(GAROTO, "Dedo-duro.")
		_:
			await d.say(GAROTO, "...Me deixa.")


func _vendedor_depois() -> void:
	var d := _hud.dialogue
	if Game.flag("feira.vendedor_bravo", false):
		await d.say(VENDEDOR, "Some daqui, kobold. Você e os seus amiguinhos.")
		return
	match String(Game.flag("feira.jeito", "")):
		"ajudou":
			await d.say(VENDEDOR, "Hmpf. Fica de olho naquele moleque, já que gosta tanto dele.")
		"entregou":
			await d.say(VENDEDOR, "Precisando de alguém de olho na banca, eu te chamo.")
		"ignorou":
			await d.say(VENDEDOR, "Viu aquilo? Ninguém faz nada nessa cidade. Nem você.")
		_:
			await d.say(VENDEDOR, "Fruta é pra quem paga, pequeno.")
