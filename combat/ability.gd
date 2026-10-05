class_name Ability
extends Resource
## Uma habilidade (ataque, cura ou reforço). Cada uma é um .tres em data/abilities/, editável no Inspector.

enum Kind { ATTACK, HEAL, BUFF }
enum Target { ENEMY, ALLY, SELF, AREA }

@export var title: String = "Golpe"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ATTACK
@export var target: Target = Target.ENEMY
## Alcance em casas (1 = corpo a corpo, inclusive na diagonal).
@export var reach: int = 1
## Área: 0 = um alvo; 1 = 3x3 em volta do ponto escolhido.
@export var radius: int = 0
@export var dice_count: int = 1
@export var dice_sides: int = 6
@export var bonus: int = 0
## Quantos golpes por uso (Tiro duplo = 2).
@export var hits: int = 1
## Ataque rola d20 contra a CA do alvo. Área não rola: sempre atinge.
@export var needs_roll: bool = true
@export_group("Reforço")
@export var buff_ac: int = 0
@export var buff_hit: int = 0
## Dura até o começo do N-ésimo próximo turno de quem recebeu.
@export var buff_turns: int = 0
@export_group("Visual")
@export var projectile: bool = false
## Em vez da bola de luz, esta cena corre pelo chão até o alvo (os burros do Naumfode).
@export var projectile_scene: PackedScene
@export var vfx_color: Color = Color(1.0, 0.85, 0.55)


func dice_text() -> String:
	if kind == Kind.BUFF:
		return ""
	var text := "%dd%d" % [dice_count, dice_sides]
	if bonus > 0:
		text += "+%d" % bonus
	if hits > 1:
		text = "%dx %s" % [hits, text]
	return text


func average() -> float:
	return (dice_count * (dice_sides + 1) / 2.0 + bonus) * hits
