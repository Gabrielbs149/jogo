class_name Encounter
extends Node3D
## Um grupo de inimigos no mapa. Os inimigos são os filhos (Combatant) e ficam parados.
## Encostar neles leva para a arena (luta por turnos); acertar um deles antes com o botão esquerdo
## dá a primeira jogada. Vencido, o grupo some do mapa (Game.defeated).

signal triggered(encounter: Encounter, first_strike: bool)

## Nome único na fase (vazio = nome do nó). É por ele que o jogo lembra que já venceu.
@export var encounter_id: String = ""
@export_file("*.tscn") var arena_scene: String = "res://levels/arenas/ethera_arena.tscn"
## Distância (m) de qualquer inimigo do grupo que começa a luta.
@export var trigger_radius: float = 2.4
## Aparece no mapa quando você volta vencedor (fim de capítulo, pista...).
@export_multiline var after_text: String = ""

var _fired: bool = false
## Você acabou de fugir deste grupo (D050): só puxa luta de novo depois que você se afastar.
var _grace: bool = false


func _ready() -> void:
	add_to_group("encounter")
	if Level.editing:
		return  # no editor de mapas nada muda sozinho
	_grace = Game.fled_from != "" and Game.fled_from == id()
	for c: Combatant in members():
		var brain := c.get_node_or_null("AIBrain")
		if brain:
			brain.process_mode = Node.PROCESS_MODE_DISABLED  # no mapa eles só esperam


## O nome pelo qual o jogo lembra que já venceu este grupo.
func id() -> String:
	return encounter_id if encounter_id != "" else String(name)


func members() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for child: Node in get_children():
		if child is Combatant:
			result.append(child as Combatant)
	return result


func data(first_strike: bool) -> Dictionary:
	var scenes: PackedStringArray = []
	for c: Combatant in members():
		scenes.append(c.scene_file_path)
	return {"id": id(), "enemies": scenes, "first_strike": first_strike, "after_text": after_text, "arena": arena_scene}


## Chamado pela fase a cada quadro com a sua posição.
func check(player: Combatant) -> void:
	if _fired or not is_inside_tree() or not player.is_inside_tree():
		return
	if _grace:
		for c: Combatant in members():
			if c.global_position.distance_to(player.global_position) <= trigger_radius + 3.0:
				return
		_grace = false
		Game.fled_from = ""
		return
	for c: Combatant in members():
		if c.global_position.distance_to(player.global_position) <= trigger_radius:
			fire(false)
			return


func fire(first_strike: bool) -> void:
	if _fired:
		return
	_fired = true
	triggered.emit(self, first_strike)
