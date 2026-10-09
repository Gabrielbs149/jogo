class_name Missao
extends Node
## Base das missões e conversas da fase (D040, D059): acha a fase e o painel, abre e fecha a conversa (trava o herói,
## vira um para o outro e aproxima a câmera de leve), rola os testes de perícia com o d20 na tela e mostra gritos em
## cima da cabeça de alguém. Cada missão (padaria, bico, briga na feira, prólogo) estende esta.

## Perícias de cada herói *(proposta)*: Tico é ladino 3 kobold (DES alta, Furtividade com especialização).
const PERICIAS := {
	"tico": {"Persuasão": 2, "Intimidação": 0, "Furtividade": 7, "Intuição": 3, "Atletismo": 0},
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
	_hud = _level.get_node_or_null("HUD") as GameHUD
	_setup()


## Chamado no _ready, já com a fase achada (fora do editor). As missões ligam os sinais aqui.
func _setup() -> void:
	pass


## Conversa: trava o herói, vira os dois um para o outro, aproxima a câmera e roda `fn` (as falas).
func _talk(fn: Callable, with_who: Node3D = null) -> void:
	if _busy:
		return
	_busy = true
	if _hud == null:
		_hud = _level.get_node("HUD") as GameHUD
	_hud.begin_talk()
	_before_talk()
	_level.focus_talk(with_who)
	await fn.call()
	_level.focus_talk(null)
	_hud.end_talk()
	_busy = false
	_after_talk()
	_level.save_here(false)


## Antes e depois de cada conversa (segurar quem fala, atualizar marcas...).
func _before_talk() -> void:
	pass


func _after_talk() -> void:
	pass


## Conseguiu comida (D059): o Tico guarda para dividir com a Tika no barraco. Quem não é o Tico come na hora.
func _got_food(source: String, what: String) -> void:
	Audio.play("pegar_comida", -4.0)
	if Game.chosen != "tico":
		_hud.toast("Comeu %s" % what)
		Game.set_objective("")
		Audio.play("vitoria", -8.0)
		if _level.player:
			_level.player.rest()
			Game.hero_hp = -1
		return
	if Game.has_item("comida"):
		Game.set_flag("comida.extra", what)
	else:
		Game.add_item("comida")
		Game.set_flag("comida.de", source)
		Game.set_flag("comida.o_que", what)
	Game.set_objective("Voltar para o barraco e dividir a comida com a Tika.", "Fome")
	_hud.toast("Conseguiu: %s" % what)


## Teste de perícia (D&D 5.5): d20 + bônus contra a CD, com o dado rolando na tela (D058).
func _check(skill: String, dc: int) -> bool:
	var bonus: int = PERICIAS.get(Game.chosen, {}).get(skill, 0)
	var roll := Dice.d20()
	var total := roll + bonus
	var ok := roll == 20 or (roll != 1 and total >= dc)
	Game.set_flag("ultimo_teste", {"pericia": skill, "d20": roll, "total": total, "cd": dc})
	await _hud.roll_check(_level.player, skill, roll, bonus, dc, ok)
	Audio.play("qte_perfeito" if ok else "qte_errou", -6.0)
	return ok


## Uma frase em cima da cabeça de alguém (grito, resmungo), sem caixa de conversa. Some sozinha.
static func shout(who: Node3D, text: String, color: Color = Color(1, 0.45, 0.35), height: float = 2.3) -> void:
	if who == null or not who.is_inside_tree():
		return
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/cinzel.ttf")
	label.font_size = 56
	label.outline_size = 14
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	who.add_child(label)
	label.position = Vector3(0, height, 0)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", height + 0.3, 2.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(1.8)
	tween.tween_callback(label.queue_free)


func _wait(seconds: float) -> void:
	if DisplayServer.get_name() == "headless" or (_hud and _hud.dialogue.instant):
		return
	await get_tree().create_timer(seconds).timeout
