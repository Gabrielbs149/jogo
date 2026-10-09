class_name ConversaMendigo
extends Missao
## Seu Brás *(proposta)*, o mendigo que conhece o Tico (D059): sentado na esquina da rua do portão, perto do beco.
## Conta do bico no celeiro (o carregador torceu o pé) e solta a novidade da gente nova perto da muralha.
## Marcas: "bras.conversou", "bico.sabe".

## "Falar com o Seu Brás" (filho dele).
@export var falar: Interactable

const BRAS := "Seu Brás"


func _setup() -> void:
	falar.used.connect(func(_by: Combatant, _w: Interactable) -> void: _talk(_conversa, falar.get_parent() as Node3D))


func _conversa() -> void:
	var d := _hud.dialogue
	if Game.has_item("comida"):
		await d.say(BRAS, "Hm... cheiro de comida. Vai dividir com a pequena, né? Faz bem. Vai logo, antes que esfrie.")
		return
	if not Game.flag("bras.conversou", false):
		Game.set_flag("bras.conversou", true)
		await d.say(BRAS, "Ô, Tico! Ainda vivo? Achei que o frio de ontem tinha te levado.")
		await d.say("Tico", "O frio tentou. Eu sou ruim de levar.")
	else:
		await d.say(BRAS, "Voltou, é? A esquina é sua também, senta aí.")
	while true:
		var pick: int = await d.choose(BRAS, "Fala, menino.", [
			"Sabe onde eu arrumo comida?",
			"Alguma novidade por aí?",
			"Até mais, Brás.",
		])
		match pick:
			0:
				await d.say(BRAS, "Comida eu não sei. Trabalho eu sei.")
				await d.say(BRAS, "O carregador do celeiro da cidade torceu o pé. Do outro lado da rua, subindo pelo caminho de terra.")
				await d.say(BRAS, "Tem caixa pra levar da carroça pro galpão. Ele paga em comida, que é a única moeda que importa.")
				Game.set_flag("bico.sabe", true)
				if not Game.flag("padaria.comecou", false) or Game.flag("padaria.estado", "") == "":
					await d.say(BRAS, "Ou tenta o padeiro. Ele late, mas às vezes morde um pão pra fora do balcão.")
			1:
				await d.say(BRAS, "Tem gente nova acampando do lado de fora da muralha, perto do portão do leste.")
				await d.say(BRAS, "Carroça coberta. Roupa limpa demais pra quem vem de estrada.")
				await d.say(BRAS, "Ficam olhando pra gente igual o padeiro olha pra farinha. Contando.")
			2:
				await d.say(BRAS, "Vai com cuidado, menino. E dá um beijo na pequena por mim.")
				return
