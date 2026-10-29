extends GutTest
## O truque das folhas (D089): a criança da praça pede, o Tico escolhe se faz.

const ARANDU := "res://levels/arandu/arandu.tscn"

var _level: Level
var _dialogue: DialogueBox
var _truque: TruqueFolhas


func _open() -> void:
	Game.chosen = "tico"
	Game.party.clear()
	Game.flags.clear()
	Game.flags.merge({"prologo.etapa": "fim"})
	Game.items.clear()
	Game.seen.assign([ARANDU])
	_level = (load(ARANDU) as PackedScene).instantiate() as Level
	_level.skip_intro = true
	add_child_autofree(_level)
	await wait_until(func() -> bool: return _level.ready_to_play, 20.0)
	_dialogue = (_level.get_node("HUD") as GameHUD).dialogue
	_dialogue.instant = true
	_truque = _level.get_node("Missoes/TruqueFolhas") as TruqueFolhas
	await wait_physics_frames(2)


func _said(text: String) -> bool:
	return "\n".join(_dialogue.history).contains(text)


func test_the_kid_talk_belongs_to_the_quest() -> void:
	await _open()
	assert_eq(_truque.falar.action, Interactable.Action.QUEST, "quem responde é o script, não um texto solto")


func test_doing_the_trick() -> void:
	await _open()
	_dialogue.auto_answers.assign([0])
	await _truque._talk(_truque._conversa, _truque._kid)
	assert_true(_said("> Fazer o truque das folhas"), "primeiro pergunta se faz")
	assert_eq(int(Game.flag("truque.vezes", 0)), 1)
	assert_true(_said("De novo"))
	assert_true(_level.controller.enabled, "depois do truque dá para andar")
	_dialogue.auto_answers.assign([0])
	await _truque._talk(_truque._conversa, _truque._kid)
	assert_true(_said("Só mais uma"), "da segunda vez ela pede diferente")
	assert_eq(int(Game.flag("truque.vezes", 0)), 2)


func test_saying_no() -> void:
	await _open()
	_dialogue.auto_answers.assign([1])
	await _truque._talk(_truque._conversa, _truque._kid)
	assert_true(_said("Hoje não"))
	assert_eq(int(Game.flag("truque.vezes", 0)), 0, "não fez")
	assert_true(_level.controller.enabled)
