class_name Unit
extends Node3D
## Personagem ou inimigo no combate. Atributos no Inspector; o visual é o filho "Model".

signal changed
signal died

enum Team { HEROES, ENEMIES }

@export var display_name: String = "Herói"
@export var team: Team = Team.HEROES
@export var max_hp: int = 20
@export var armor_class: int = 12
## Casas que anda por turno.
@export var speed: int = 5
@export var initiative_bonus: int = 0
@export var attack_bonus: int = 4
## Voa por cima de ruínas e obstáculos.
@export var flying: bool = false
## Cor do manto/da pedra (usada na interface).
@export var color: Color = Color(0.85, 0.2, 0.15)
@export var abilities: Array[Ability] = []

var hp: int = 0
var cell: Vector2i = Vector2i.ZERO
var initiative: int = 0
var moves_left: int = 0
var has_action: bool = false
## Reforços ativos: {"title": String, "ac": int, "hit": int, "turns": int}
var statuses: Array[Dictionary] = []

@onready var model: Node3D = get_node_or_null("Model") as Node3D


func _ready() -> void:
	add_to_group("unit")
	hp = max_hp


func is_alive() -> bool:
	return hp > 0


func current_ac() -> int:
	var total := armor_class
	for status: Dictionary in statuses:
		total += int(status["ac"])
	return total


func hit_bonus() -> int:
	var total := attack_bonus
	for status: Dictionary in statuses:
		total += int(status["hit"])
	return total


func start_turn() -> void:
	moves_left = speed
	has_action = true
	for status: Dictionary in statuses:
		status["turns"] = int(status["turns"]) - 1
	statuses = statuses.filter(func(s: Dictionary) -> bool: return int(s["turns"]) > 0)
	changed.emit()


func take_damage(amount: int) -> void:
	if not is_alive():
		return
	hp = maxi(hp - amount, 0)
	changed.emit()
	if hp == 0:
		died.emit()


func heal(amount: int) -> void:
	if not is_alive():
		return
	hp = mini(hp + amount, max_hp)
	changed.emit()


func add_status(title: String, ac: int, hit: int, turns: int) -> void:
	statuses = statuses.filter(func(s: Dictionary) -> bool: return s["title"] != title)
	statuses.append({"title": title, "ac": ac, "hit": hit, "turns": turns})
	changed.emit()


func is_opponent(other: Unit) -> bool:
	return other.team != team
