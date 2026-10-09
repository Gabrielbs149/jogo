class_name BicoCaixas
extends Missao
## O bico do celeiro (D059): o carregador torceu o pé e precisa que alguém leve três caixotes da carroça até o
## galpão antes de o patrão chegar. Paga com o próprio almoço (pão de milho e linguiça): outro jeito de conseguir
## comida para o Tico e a Tika, sem a padaria. O caixote vai em cima da cabeça do Tico.
## Estado em Game.flags: "bico.estado" ("", "aceito", "carregou", "pago") e "bico.caixas" (quantos já levou).

## "Falar com o carregador" (filho dele).
@export var carregador: Interactable
## Os caixotes em cima da carroça (somem um a um) e a pilha na porta do galpão (aparece um a um).
@export var na_carroca: Array[Node3D] = []
@export var na_pilha: Array[Node3D] = []
## "Pegar um caixote" (na carroça) e "Largar o caixote" (na porta do galpão).
@export var pegar: Interactable
@export var largar: Interactable
## "!" em cima do carregador.
@export var marca: Node3D
## Altura do caixote em cima da cabeça do herói (m).
@export var altura_na_cabeca: float = 1.05

const CARREGADOR := "Carregador"
const TOTAL := 3

var _carrying: Node3D


func _setup() -> void:
	carregador.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_conversa, carregador.get_parent() as Node3D))
	pegar.used.connect(func(by: Combatant, _w: Interactable) -> void: _pick_up(by))
	largar.used.connect(func(_by: Combatant, _w: Interactable) -> void: _drop())
	_show_crates()


func estado() -> String:
	return String(Game.flag("bico.estado", ""))


func caixas() -> int:
	return int(Game.flag("bico.caixas", 0))


func _process(_delta: float) -> void:
	if _level == null:
		return
	var e := estado()
	pegar.enabled = e == "aceito" and _carrying == null and caixas() < TOTAL
	largar.enabled = _carrying != null
	if marca:
		marca.visible = Game.flag("comida.comecou", false) and (e == "" or e == "carregou") and not Game.has_item("comida")


# --- conversa -------------------------------------------------------------------------------------

func _conversa() -> void:
	var d := _hud.dialogue
	match estado():
		"aceito":
			await d.say(CARREGADOR, "Mais %d. Força, pequeno. E devagar com a de cima, que é louça." % (TOTAL - caixas()))
			return
		"carregou":
			await d.say(CARREGADOR, "Três caixas e nenhuma quebrada. Nem o meu ajudante antigo fazia isso.")
			await d.say(CARREGADOR, "O patrão paga por caixa. Ele não precisa saber quem carregou.")
			await d.say(CARREGADOR, "Mas o meu almoço é meu, e eu divido com quem me ajuda. Toma.")
			Game.set_flag("bico.estado", "pago")
			await _got_food("bico", "um pão de milho e uma linguiça")
			return
		"pago":
			await d.say(CARREGADOR, "Valeu de novo, pequeno. O meu pé agradece. A minha barriga, nem tanto.")
			return
	if not Game.flag("comida.comecou", false):
		await d.say(CARREGADOR, "Ai, o meu pé... Hoje não tô pra conversa, pequeno.")
		return
	await d.say(CARREGADOR, "Ai, ai. Ô, pequeno. Você aí. Tá com braço sobrando?")
	if Game.flag("bico.sabe", false):
		await d.say("Tico", "O Seu Brás disse que você tava precisando de braço.")
		await d.say(CARREGADOR, "O Brás fala demais. ...Mas falou certo.")
	await d.say(CARREGADOR, "Torci o pé descarregando ontem. Se o patrão chegar e essas caixas ainda tiverem na carroça, eu perco o serviço.")
	while true:
		var pick: int = await d.choose(CARREGADOR, "Três caixotes, da carroça até a porta do galpão.", [
			"E o que eu ganho com isso?",
			"Deixa comigo.",
			"Agora não.",
		])
		match pick:
			0:
				await d.say(CARREGADOR, "O meu almoço. Pão de milho e linguiça. É o que eu tenho.")
			1:
				await d.say(CARREGADOR, "Sério? Então vai. Pega na carroça e larga ali na porta do galpão.")
				Game.set_flag("bico.estado", "aceito")
				Game.set_objective("Levar os três caixotes da carroça até a porta do galpão.", "Fome")
				return
			2:
				await d.say(CARREGADOR, "Tá. Eu fico aqui, sentado, perdendo o emprego devagarinho.")
				return


# --- os caixotes ----------------------------------------------------------------------------------

func _pick_up(by: Combatant) -> void:
	if _carrying or caixas() >= TOTAL:
		return
	var crate := na_carroca[caixas()]
	var carried := crate.duplicate() as Node3D
	crate.visible = false
	by.add_child(carried)
	carried.position = Vector3(0, altura_na_cabeca, 0)
	carried.rotation = Vector3.ZERO
	carried.visible = true
	_carrying = carried
	Audio.play("pegar_comida", -8.0, 0.2)
	_hud.toast("Caixote na cabeça. Agora até a porta do galpão.")


func _drop() -> void:
	if _carrying == null:
		return
	_carrying.queue_free()
	_carrying = null
	var done := caixas() + 1
	Game.set_flag("bico.caixas", done)
	_show_crates()
	Audio.play("impacto", -14.0)
	if done >= TOTAL:
		Game.set_flag("bico.estado", "carregou")
		Game.set_objective("Falar com o carregador.", "Fome")
		_hud.toast("Três caixotes no galpão")
	else:
		_hud.toast("%d de %d" % [done, TOTAL])
	_level.save_here(false)


## Os caixotes na carroça e na pilha, conforme quantos já foram levados (vale com o jogo salvo).
func _show_crates() -> void:
	var done := caixas()
	for i: int in na_carroca.size():
		na_carroca[i].visible = i >= done
	for i: int in na_pilha.size():
		na_pilha[i].visible = i < done
