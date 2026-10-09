class_name PrologoTico
extends Missao
## O primeiro dia jogável do Tico com a Tika em Arandu (D059), depois da cena do rato (D029):
##   A. a fome acorda os dois no meio da noite; a Tika chama o Tico e vai esperar na boca do beco;
##   B. na saída do beco ela conversa (3–4 respostas curtas, guardadas em "prologo.tika_resposta") e fica guardando o
##      papelão; saindo do beco aparece a rua e o objetivo "Conseguir comida para os dois";
##   C/D. a comida sai da padaria (MissaoPadaria), do bico do carregador (BicoCaixas) ou de onde der; no caminho tem a
##        briga da feira (BrigaFeira);
##   E. de volta ao barraco, os dois dividem a comida (cena curta, montada conforme o que você fez) e dormem.
## A Tika ainda não some aqui: isso fica para depois (D059). Estado em Game.flags ("prologo.etapa": "", "acordou",
## "conversou", "saiu", "fim"), então vale com o jogo salvo. Falas *(proposta)* em docs/gdd/01-historia.md.

## A Tika (CenaTico/Tika, com o script Ator).
@export var tika: Ator
## "Falar com a Tika" (filho da Tika).
@export var falar_tika: Interactable
## Seta em cima da Tika quando é com ela.
@export var marca_tika: Node3D
## Onde o Tico dorme (no papelão) e onde a Tika acorda ele.
@export var cama: Node3D
@export var tika_acordando: Node3D
## Boca do beco: a Tika espera aqui (B).
@export var tika_saida: Node3D
## No barraco, perto da fogueirinha: onde ela fica guardando o papelão (e onde senta para comer).
@export var tika_sentada: Node3D
## A fogueirinha do barraco (de dia de hoje só brasa; acesa no jantar).
@export var fogueira: Node3D
## Detalhe opcional do beco lateral: a fita roxa que a Tika perdeu ("Pegar a fita").
@export var fita: Interactable
## Plano fixo do barraco para o acordar (o beco é estreito demais para a câmera por cima do ombro).
@export var plano_acordar: Camera3D
## Saiu do beco: o Tico está a mais que isso (m) do papelão.
@export var raio_beco: float = 7.5
## A Tika puxa conversa quando o Tico chega a essa distância dela na boca do beco.
@export var raio_conversa: float = 2.6

const TIKA := "Tika"
const RESPOSTAS: Array[String] = ["banquete", "juntos", "rato", "duvida"]
const CENA_FIM := "res://story/tico_fim_do_dia.tres"


func _setup() -> void:
	if Game.chosen != "tico":
		# só o Tico tem esse começo; para os outros a Tika não está em Arandu
		tika.visible = false
		falar_tika.enabled = false
		set_process(false)
		return
	falar_tika.used.connect(func(_by: Combatant, _w: Interactable) -> void: _on_tika())
	if fita:
		fita.visible = not Game.flag("prologo.fita_achada", false)
		fita.used.connect(func(_by: Combatant, _w: Interactable) -> void: _take_ribbon())
	_level.play_started.connect(_start)
	_place_tika()


func etapa() -> String:
	return String(Game.flag("prologo.etapa", ""))


func _set_etapa(value: String) -> void:
	Game.set_flag("prologo.etapa", value)
	_update_marks()


func _process(_delta: float) -> void:
	if _level == null or _level.player == null or not _level.ready_to_play or _busy:
		return
	var me := _level.player.global_position
	match etapa():
		"acordou":
			# B: a Tika está na boca do beco; chegando perto, ela puxa conversa
			var waiting := not tika.is_walking() and tika.global_position.distance_to(tika_saida.global_position) < 0.6
			if waiting and me.distance_to(tika.global_position) < raio_conversa:
				_talk(_conversa_saida, tika)
		"conversou":
			if me.distance_to(cama.global_position) > raio_beco:
				_left_alley()
	falar_tika.enabled = etapa() in ["acordou", "saiu", "fim"] and not tika.is_walking()
	_update_marks()


## Começa (ou continua, com o jogo salvo) do ponto em que parou.
func _start() -> void:
	_place_tika()
	_update_marks()
	if etapa() == "":
		await _wake_up()


## Põe a Tika onde ela deve estar nesta etapa (abrir o jogo salvo no meio do prólogo).
func _place_tika() -> void:
	tika.visible = true
	if fogueira:
		fogueira.visible = true
		var flame := fogueira.get_node_or_null("Fogo") as Node3D
		if flame:
			flame.visible = etapa() == "fim"
	match etapa():
		"":
			tika.place_at(tika_acordando)
			tika.play(&"Idle")
		"acordou":
			tika.place_at(tika_saida)
			tika.play(&"Idle")
		"fim":
			tika.place_at(tika_sentada)
			tika.play(&"Lie_Idle")
		_:
			tika.place_at(tika_sentada)
			tika.play(&"Sit_Floor_Idle")


# --- A. acordar -----------------------------------------------------------------------------------

func _wake_up() -> void:
	_busy = true
	var hero := _level.player
	var animator := hero.get_node_or_null("Animator") as CombatantAnimator
	hero.global_transform = cama.global_transform
	hero.reset_physics_interpolation()
	if animator:
		animator.hold(&"Lie_Idle")
	_hud.begin_talk()
	_hud.hide_hints()
	var game_camera := get_viewport().get_camera_3d()
	if plano_acordar:
		plano_acordar.make_current()
	await _wait(1.0)
	var d := _hud.dialogue
	await d.say(TIKA, "Tico. Tico! Acorda.")
	await d.say("Tico", "Mmmf... já é de manhã?")
	await d.say(TIKA, "Não. Ainda é noite. Mas a minha barriga não sabe disso.")
	d.close()
	if animator:
		animator.act(&"Lie_StandUp")
		await _wait(2.0)
		animator.release()
	_level.turn_toward(hero, tika.global_position)
	if plano_acordar and game_camera:
		game_camera.make_current()
	_level.focus_talk(tika)
	await d.say("Tico", "...A minha também não. Ela tá cantando.")
	await d.say(TIKA, "A minha tá gritando. Vem, te espero lá na boca do beco. Pensa em alguma coisa no caminho.")
	_level.focus_talk(null)
	_hud.end_talk()
	_set_etapa("acordou")
	Game.set_objective("Falar com a Tika na saída do beco.", "Um dia em Arandu")
	_hud.show_tips()
	_hud.show_story(_level.start_story)
	_busy = false
	_level.save_here(false)
	await tika.walk_to(tika_saida.global_position, cama.global_position)


# --- B. a conversa na saída do beco ---------------------------------------------------------------

func _conversa_saida() -> void:
	var d := _hud.dialogue
	await d.say(TIKA, "Sabia que a minha barriga tá fazendo um barulho que eu nunca ouvi? Acho que ela tá aprendendo a falar.")
	await d.say(TIKA, "E a primeira palavra dela é \"comida\".")
	var pick: int = await d.choose(TIKA, "O rato de ontem já virou lembrança. Bora arrumar alguma coisa?", [
		"Deixa comigo. Eu volto com um banquete.",
		"Vamos juntos?",
		"Ontem a gente comeu um rato inteiro.",
		"E se não tiver nada pra arrumar?",
	])
	Game.set_flag("prologo.tika_resposta", RESPOSTAS[pick])
	match pick:
		0:
			await d.say(TIKA, "Um banquete. Tá bom. Eu aceito qualquer coisa que não tenha rabo.")
		1:
			await d.say(TIKA, "E deixar o barraco sozinho? Da última vez levaram até a nossa porta.")
			await d.say("Tico", "A gente nunca teve porta.")
			await d.say(TIKA, "Pois é. Levaram.")
		2:
			await d.say(TIKA, "Ontem a gente comeu MEIO rato cada. E a minha metade era o bumbum.")
			await d.say("Tico", "A melhor parte.")
			await d.say(TIKA, "Tico.")
		3:
			await d.say(TIKA, "Sempre tem. A cidade é grande e você é pequeno. Você passa onde ninguém passa.")
	await d.say(TIKA, "Eu fico guardando o nosso papelão. Alguém tem que proteger o patrimônio da família.")
	await d.say(TIKA, "Vai. E volta com comida pros dois, hein. DOIS.")
	_set_etapa("conversou")
	Game.set_objective("")
	# ela volta para o barraco (depois que a conversa fecha)
	_back_home.call_deferred()


func _back_home() -> void:
	await tika.walk_to(tika_sentada.global_position, cama.global_position)
	tika.face(tika_sentada.global_position - tika_sentada.global_basis.z)
	await tika.play_once(&"Sit_Floor_Down")
	tika.play(&"Sit_Floor_Idle")


## Saiu do beco: aparece a rua e o primeiro objetivo de verdade.
func _left_alley() -> void:
	_set_etapa("saiu")
	Game.set_flag("comida.comecou", true)
	Game.set_objective("Conseguir comida para os dois.", "Fome")
	_hud.show_area("Rua do Portão")
	_hud.show_story("A rua desce até a praça da fonte. A padaria fica do lado de lá da praça; o celeiro da cidade, aqui perto, do outro lado da rua.")
	_level.save_here(false)


# --- falar com a Tika (e E. o fim do dia) ---------------------------------------------------------

func _on_tika() -> void:
	match etapa():
		"acordou":
			_talk(_conversa_saida, tika)
		"saiu":
			if Game.has_item("comida"):
				_end_of_day()
			else:
				_talk(_still_hungry, tika)
		"fim":
			_hud.show_story("A Tika ronca baixinho, enrolada no papelão. Melhor não acordar.")


## A fita roxa no beco lateral: o Tico guarda para devolver no jantar.
func _take_ribbon() -> void:
	Game.set_flag("prologo.fita_achada", true)
	Game.add_item("fita")
	fita.visible = false
	Audio.play("pegar_comida", -10.0, 0.2)
	_hud.toast("Achou: uma fita roxa, meio desbotada")
	_hud.show_story("É a fita da Tika. Ela jurou que o vento levou. O vento, pelo jeito, mora no beco do lado.")


func _still_hungry() -> void:
	var d := _hud.dialogue
	await d.say(TIKA, String(["Voltou de mão vazia? A minha barriga tá fazendo bico.",
		"Ainda nada? O papelão continua seguro, pelo menos.",
		"Tô vendo comida nenhuma nessas mãos, Tico."][randi() % 3]))


## E. Os dois dividem a comida no barraco e dormem. A cena (story/tico_fim_do_dia.tres) é montada com o que você fez.
func _end_of_day() -> void:
	if _busy:
		return
	_busy = true
	falar_tika.enabled = false
	var scene := Roteiro.new()
	scene.texto = end_of_day_script()
	Game.remove_item("comida")
	_set_etapa("fim")
	Game.set_flag("comida.entregue", true)
	Game.set_objective("")
	await _level.play_cutscene(scene)
	tika.place_at(tika_sentada)
	tika.play(&"Lie_Idle")
	Audio.play("vitoria", -10.0)
	_hud.toast("Fim do primeiro dia")
	if _level.player:
		_level.player.rest()
		Game.hero_hp = -1
	_busy = false
	_update_marks()
	_level.save_here(false)


## O roteiro do fim do dia (Roteiro, story/roteiro.gd), com as falas que mudam conforme o que aconteceu.
func end_of_day_script() -> String:
	var base := (load(CENA_FIM) as Roteiro).texto
	var food := _food_lines()
	var extras: PackedStringArray = []
	extras.append_array(_answer_lines())
	extras.append_array(_street_lines())
	extras.append_array(_ribbon_lines())
	return base.replace("{comida}", "\n".join(food)).replace("{extras}", "\n".join(extras))


func _food_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var what := String(Game.flag("comida.o_que", "comida"))
	lines.append("Tico: \"Pronto. %s.\"" % (what.left(1).to_upper() + what.substr(1)))
	match String(Game.flag("comida.de", "")) + "/" + String(Game.flag("padaria.jeito", "")):
		"padaria/favor":
			lines.append("Tika: \"Quentinho? Você roubou o forno junto?\"")
			lines.append("Tico: \"Fiz uma entrega. Trabalho honesto.\"")
			lines.append("Tika: \"Você tá com febre?\"")
		"padaria/convenceu":
			lines.append("Tika: \"Isso é pão ou é telha?\"")
			lines.append("Tico: \"É pão de quem sabe conversar.\"")
		"padaria/intimidou":
			lines.append("Tika: \"Por que o padeiro tava gritando o seu nome da porta?\"")
			lines.append("Tico: \"Ele gosta de mim.\"")
		"padaria/roubou":
			lines.append("Tika: \"Você tá com farinha no capuz.\"")
			lines.append("[pausa 0.8]")
			lines.append("Tico: \"...É moda.\"")
		_:
			if Game.flag("comida.de", "") == "bico":
				lines.append("Tika: \"Linguiça?! Tico, o que foi que você fez?\"")
				lines.append("Tico: \"Carreguei caixa. Muita caixa. Agora eu sou praticamente um burro de carga.\"")
				lines.append("Tika: \"O meu burro de carga.\"")
			else:
				lines.append("Tika: \"Nem vou perguntar de onde veio.\"")
	if Game.flag("comida.extra", "") != "":
		lines.append("Tika: \"E ainda tem mais? A gente tá rico?\"")
		lines.append("Tico: \"Por uma noite.\"")
	return lines


func _answer_lines() -> PackedStringArray:
	match String(Game.flag("prologo.tika_resposta", "")):
		"banquete":
			return ["Tika: \"Então esse é o banquete.\"", "Tico: \"Entrada, prato principal e sobremesa. Tudo no mesmo pedaço.\""]
		"juntos":
			return ["Tika: \"E o barraco continua de pé. Viu? Eu protegi.\"", "Tico: \"Heroína do papelão.\""]
		"rato":
			return ["Tico: \"E dessa vez não tem bumbum.\"", "Tika: \"Graças aos céus.\""]
		"duvida":
			return ["Tika: \"Viu? Eu falei que sempre tem.\"", "Tico: \"Você fala muita coisa.\"", "Tika: \"E acerto todas.\""]
	return []


func _street_lines() -> PackedStringArray:
	match String(Game.flag("feira.jeito", "")):
		"ajudou":
			return ["Tico: \"Hoje eu livrei um moleque de levar uma surra por causa de uma maçã.\"",
				"Tika: \"Olha só. Tico-Lirou, protetor dos famintos.\"",
				"Tico: \"Dos famintos pequenos. Os grandes que se virem.\""]
		"entregou":
			return ["Tico: \"E ainda tem uma maçã. Batida, mas é fruta.\"",
				"Tika: \"E de onde veio a maçã?\"", "Tico: \"De lugar nenhum. Um moleque, uma banca... nada.\"",
				"[pausa 1.2]", "Tika: \"Hm.\""]
	return []


func _ribbon_lines() -> PackedStringArray:
	if not Game.has_item("fita"):
		return []
	Game.remove_item("fita")
	return ["Tico: \"Ah. E achei isso no beco do lado.\"",
		"Tika: \"A minha fita! Eu procurei isso a semana inteira!\"",
		"[pausa 0.8]",
		"Tika: \"...Tá. Você ganhou o bumbum do próximo rato.\""]


func _update_marks() -> void:
	if marca_tika:
		marca_tika.visible = etapa() == "acordou" or (etapa() == "saiu" and Game.has_item("comida"))
