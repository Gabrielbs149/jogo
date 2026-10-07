class_name Ability
extends Resource
## Uma habilidade em tempo real, adaptada de D&D 5.5. Cada uma é um .tres em data/abilities/.
## Na ficha do herói a ordem vale tecla: 1ª = botão esquerdo (ataque), 2ª = Q, 3ª = E, 4ª = R.

enum Kind { ATTACK, HEAL, BUFF, DEBUFF }
## TARGET: um alvo no alcance. DASH: avança até o alvo e golpeia. LINE: linha reta até o alcance.
## AREA: círculo no ponto mirado. CONE: leque à frente. SELF: só em si.
## ALLIES_AROUND / ENEMIES_AROUND: todos os aliados / inimigos num raio em volta de quem usa.
enum Shape { TARGET, DASH, LINE, AREA, CONE, SELF, ALLIES_AROUND, ENEMIES_AROUND }
## ATTACK: d20 + bônus contra a CA. SAVE: o alvo rola salvamento contra a CD. AUTO: sempre acerta.
enum Roll { ATTACK, SAVE, AUTO }
enum Save { DEX, CON, WIS }

@export var title: String = "Golpe"
@export_multiline var description: String = ""
## De onde vem no D&D 5.5 (aparece na ficha): "Ação · ataque com arma", "Magia de 1º círculo"...
@export var dnd_note: String = ""
@export var kind: Kind = Kind.ATTACK
@export var shape: Shape = Shape.TARGET
@export var roll: Roll = Roll.ATTACK
@export var save: Save = Save.DEX
## Alcance em metros (1,5 m ≈ 5 pés, corpo a corpo).
@export var range_m: float = 2.2
## Raio da área em metros (AREA, *_AROUND) ou largura da LINE.
@export var radius_m: float = 0.0
## Segundos até poder usar de novo. Ataque básico ≈ 1 s; "por descanso curto" ≈ 30 s.
@export var cooldown: float = 1.0
## Luta por turnos: Pontos de Ação que custa (0 = ataque básico, que ganha 1 PA).
@export var ap_cost: int = 0
## Preparo antes do efeito, em segundos (o golpe "carrega" e dá para desviar).
@export var windup: float = 0.2
@export var dice_count: int = 1
@export var dice_sides: int = 6
@export var bonus: int = 0
## Golpes por uso (Tiro duplo = 2).
@export var hits: int = 1
## Passar no salvamento corta o dano pela metade (senão, nada).
@export var half_on_save: bool = true
## O golpe já vem com vantagem (rola 2d20 e fica com o maior).
@export var advantage: bool = false

@export_group("Ataque furtivo")
## d6 extras uma vez a cada 2,5 s quando tem vantagem ou um aliado a 2 m do alvo.
@export var sneak_dice: int = 0

@export_group("Efeito")
## Nome do efeito que fica no alvo (Bênção, Marca do caçador...). Vazio = sem efeito.
@export var status_title: String = ""
@export var status_time: float = 0.0
## Luta por turnos: quantos turnos de quem recebeu o efeito ele dura.
@export var status_turns: int = 2
@export var buff_ac: int = 0
## Bênção: +1dN nos ataques e salvamentos.
@export var bless_die: int = 0
## Some da vista dos inimigos; o próximo ataque tem vantagem e acaba com o efeito.
@export var invisible: bool = false
## Marca do caçador: quem marcou causa +Nd6 no alvo.
@export var mark_dice: int = 0
## Amedrontado: o alvo ataca com desvantagem.
@export var frighten: bool = false
## Exposto: o próximo ataque contra o alvo tem vantagem.
@export var expose: bool = false

@export_group("Visual")
@export var projectile: bool = false
## Em vez da bola de luz, esta cena corre pelo chão até o alvo (os burros do Namfoodle).
@export var projectile_scene: PackedScene
@export var vfx_color: Color = Color(1.0, 0.85, 0.55)


func is_offensive() -> bool:
	return kind == Kind.ATTACK or kind == Kind.DEBUFF


func needs_target() -> bool:
	return shape == Shape.TARGET or shape == Shape.DASH


func dice_text() -> String:
	if dice_count <= 0:
		return ""
	var text := "%dd%d" % [dice_count, dice_sides]
	if bonus > 0:
		text += "+%d" % bonus
	if hits > 1:
		text = "%dx %s" % [hits, text]
	if sneak_dice > 0:
		text += " (+%dd6 furtivo)" % sneak_dice
	return text


func average() -> float:
	if dice_count <= 0:
		return 0.0
	return (dice_count * (dice_sides + 1) / 2.0 + bonus) * hits
