class_name Combatant
extends CharacterBody3D
## Herói ou inimigo em tempo real. A ficha (D&D 5.5 adaptado) fica no Inspector; o visual é o filho "Model".
## Quem decide as ações é um nó filho: PlayerController (você) ou AIBrain (aliados e inimigos).

signal changed
signal downed_changed(is_down: bool)
signal hurt(by: Combatant)
signal ability_used(index: int)
signal dodged
## Uma linha para o registro de rolagens (d20, CA, dano).
signal rolled(line: String)

enum Team { HEROES, ENEMIES }

const GRAVITY := 18.0
## Ataque furtivo: no D&D é uma vez por turno; aqui, uma vez a cada tantos segundos.
const SNEAK_INTERVAL := 2.5
const DASH_SPEED := 16.0

@export var display_name: String = "Herói"
## Heróis: a chave em Game.HEROES ("tico", "naumfode"...). Inimigos: vazio.
@export var hero_id: String = ""
## Classe e espécie, como na ficha: "Ladino 3 · Kobold".
@export var class_title: String = ""
@export_multiline var bio: String = ""
@export var team: Team = Team.HEROES

@export_group("Ficha")
@export var max_hp: int = 20
@export var armor_class: int = 12
@export var attack_bonus: int = 4
## CD das magias e efeitos (8 + proficiência + atributo).
@export var spell_dc: int = 12
@export var dex_save: int = 0
@export var con_save: int = 0
@export var wis_save: int = 0
## Metros por segundo (30 pés de deslocamento ≈ 5 m/s).
@export var move_speed: float = 5.0
## 1ª = botão esquerdo, 2ª = Q, 3ª = E, 4ª = R.
@export var abilities: Array[Ability] = []

@export_group("Esquiva (Espaço)")
@export var dodge_name: String = "Esquiva"
@export var dodge_distance: float = 4.0
@export var dodge_cooldown: float = 3.0

@export_group("Outros")
@export var flying: bool = false
@export var color: Color = Color(0.85, 0.2, 0.15)
## Inimigos: a que distância percebem os heróis.
@export var aggro_radius: float = 10.0
## Derrotar este inimigo encerra o capítulo.
@export var is_boss: bool = false
## Fala ao ser encontrado no caminho (heróis que dá para chamar para o grupo).
@export_multiline var greeting: String = ""

var hp: int = 0
var cooldowns: Array[float] = []
var dodge_left: float = 0.0
## Efeitos ativos: {"title", "time", "ac", "bless", "invisible", "frighten", "expose", "dodging", "mark", "mark_by"}
var statuses: Array[Dictionary] = []
## O controlador escreve aqui para onde quer andar (m/s, no plano).
var desired_velocity: Vector3 = Vector3.ZERO
## Para onde o corpo olha enquanto mira (zero = olha para onde anda).
var face_dir: Vector3 = Vector3.ZERO
var casting: bool = false
var downed: bool = false
## Herói encontrado no caminho que ainda não entrou no grupo.
var recruitable: bool = false
var sneak_ready_at: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _dash_time: float = 0.0

@onready var model: Node3D = get_node_or_null("Model") as Node3D


func _ready() -> void:
	add_to_group("combatant")
	add_to_group("heroes" if team == Team.HEROES else "enemies")
	hp = max_hp
	cooldowns.resize(abilities.size())
	cooldowns.fill(0.0)
	collision_layer = 2
	collision_mask = 1 | 2 | 4


func is_active() -> bool:
	return hp > 0 and not downed


func is_opponent(other: Combatant) -> bool:
	return other.team != team


func is_hidden() -> bool:
	return has_flag("invisible")


func has_flag(flag: String) -> bool:
	for status: Dictionary in statuses:
		if status.get(flag, false):
			return true
	return false


func current_ac() -> int:
	var total := armor_class
	for status: Dictionary in statuses:
		total += int(status.get("ac", 0))
	return total


## Bênção ativa: o maior dado extra (0 = nenhuma).
func bless_die() -> int:
	var best := 0
	for status: Dictionary in statuses:
		best = maxi(best, int(status.get("bless", 0)))
	return best


func save_bonus(save: Ability.Save) -> int:
	match save:
		Ability.Save.DEX:
			return dex_save
		Ability.Save.CON:
			return con_save
		_:
			return wis_save


## Marca do caçador: d6 extras que este atacante causa em mim.
func mark_dice_from(attacker: Combatant) -> int:
	for status: Dictionary in statuses:
		if status.get("mark_by") == attacker:
			return int(status.get("mark", 0))
	return 0


func add_status(status: Dictionary) -> void:
	statuses = statuses.filter(func(s: Dictionary) -> bool: return s["title"] != status["title"])
	statuses.append(status)
	_update_look()
	changed.emit()


func remove_flag(flag: String) -> void:
	var before := statuses.size()
	statuses = statuses.filter(func(s: Dictionary) -> bool: return not s.get(flag, false))
	if statuses.size() != before:
		_update_look()
		changed.emit()


func cooldown_ratio(index: int) -> float:
	if index < 0 or index >= abilities.size() or abilities[index].cooldown <= 0.0:
		return 0.0
	return cooldowns[index] / abilities[index].cooldown


func can_use(index: int) -> bool:
	return is_active() and not casting and index >= 0 and index < abilities.size() and cooldowns[index] <= 0.0


## Usa a habilidade. Para alvo único passe o alvo; para área/linha/cone, o ponto mirado.
## Devolve false se não deu (recarga, sem alvo...). O efeito acontece depois do preparo.
func use_ability(index: int, target: Combatant, point: Vector3) -> bool:
	if not can_use(index):
		return false
	var ability := abilities[index]
	if ability.needs_target() and not _valid_target(ability, target):
		return false
	if target:
		point = target.global_position
	casting = true
	cooldowns[index] = ability.cooldown
	_face(point)
	ability_used.emit(index)
	_perform(ability, target, point)
	return true


## Espaço: um salto rápido; enquanto dura, ataques contra você têm desvantagem (Esquivar do D&D).
func dodge(direction: Vector3) -> bool:
	direction.y = 0.0
	if not is_active() or dodge_left > 0.0 or direction.length_squared() < 0.01:
		return false
	dodge_left = dodge_cooldown
	_dash_velocity = direction.normalized() * dodge_distance / 0.22
	_dash_time = 0.22
	add_status({"title": dodge_name, "time": 0.7, "dodging": true})
	dodged.emit()
	return true


func take_damage(amount: int, by: Combatant) -> void:
	if not is_active():
		return
	hp = maxi(hp - amount, 0)
	hurt.emit(by)
	if hp == 0:
		_go_down()
	changed.emit()


## Cura. Em quem caiu, levanta (no D&D, qualquer cura tira de 0 PV).
func heal(amount: int) -> void:
	if hp <= 0 or downed:
		revive(amount)
		return
	hp = mini(hp + amount, max_hp)
	changed.emit()


func revive(amount: int) -> void:
	if team == Team.ENEMIES:
		return
	downed = false
	hp = clampi(amount, 1, max_hp)
	if model:
		model.rotation = Vector3.ZERO
		model.position.y = 0.0
	downed_changed.emit(false)
	changed.emit()


## Descanso: tudo cheio, recargas zeradas.
func rest() -> void:
	if downed:
		revive(max_hp)
	hp = max_hp
	cooldowns.fill(0.0)
	dodge_left = 0.0
	statuses.clear()
	_update_look()
	changed.emit()


func _physics_process(delta: float) -> void:
	for i: int in cooldowns.size():
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	dodge_left = maxf(dodge_left - delta, 0.0)
	_tick_statuses(delta)
	var move := Vector3.ZERO
	if _dash_time > 0.0:
		_dash_time -= delta
		move = _dash_velocity
	elif is_active():
		move = desired_velocity * (0.35 if casting else 1.0)
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	var look := face_dir if face_dir != Vector3.ZERO else Vector3(move.x, 0.0, move.z)
	if is_active() and look.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), minf(1.0, delta * 12.0))


func _perform(ability: Ability, target: Combatant, point: Vector3) -> void:
	var fx := _fx()
	if ability.shape == Ability.Shape.DASH and target:
		await _dash_to(target)
	elif ability.windup > 0.0:
		await get_tree().create_timer(ability.windup, false).timeout
	if not is_inside_tree() or not is_active() or (ability.needs_target() and not _valid_target(ability, target)):
		_end_cast()
		return
	if target:
		point = target.global_position
	if fx:
		if ability.projectile:
			await fx.projectile(global_position, point, ability.vfx_color, ability.projectile_scene)
			if not is_inside_tree():
				return
		elif ability.shape in [Ability.Shape.AREA, Ability.Shape.ALLIES_AROUND, Ability.Shape.ENEMIES_AROUND]:
			var center := point if ability.shape == Ability.Shape.AREA else global_position
			fx.ring(center, ability.radius_m, ability.vfx_color)
		elif ability.shape == Ability.Shape.CONE or ability.shape == Ability.Shape.LINE:
			fx.ring(global_position + (point - global_position).normalized() * ability.range_m * 0.5, ability.range_m * 0.5, ability.vfx_color)
		else:
			fx.lunge(self)
	var all := CombatRules.everyone(get_tree())
	var results := CombatRules.resolve(self, ability, target, point, all)
	CombatRules.apply(self, ability, results, fx)
	if ability.is_offensive():
		remove_flag("invisible")  # atacar revela quem estava escondido
	_end_cast()


## Alvo vale se está de pé; cura também vale em quem caiu.
func _valid_target(ability: Ability, target: Combatant) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	return target.is_active() or (ability.kind == Ability.Kind.HEAL and target.team == team)


func _end_cast() -> void:
	casting = false
	face_dir = Vector3.ZERO


func _dash_to(target: Combatant) -> void:
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length() - 1.3
	if distance <= 0.1:
		return
	_dash_velocity = offset.normalized() * DASH_SPEED
	_dash_time = distance / DASH_SPEED
	while _dash_time > 0.0 and is_inside_tree():
		await get_tree().physics_frame


func _face(point: Vector3) -> void:
	var aim := point - global_position
	aim.y = 0.0
	if aim.length_squared() > 0.01:
		face_dir = aim.normalized()


func _go_down() -> void:
	downed = true
	casting = false
	desired_velocity = Vector3.ZERO
	statuses.clear()
	_update_look()
	downed_changed.emit(true)
	if team == Team.ENEMIES:
		remove_from_group("combatant")
		set_physics_process(false)
		collision_layer = 0
		var fx := _fx()
		if fx:
			await fx.fall(self)
		queue_free()
	elif model and get_node_or_null("Animator") == null:  # sem animação de queda: tomba o modelo
		var tween := create_tween()
		tween.tween_property(model, "rotation:x", -PI / 2.0, 0.4)
		tween.parallel().tween_property(model, "position:y", 0.25, 0.4)


func _tick_statuses(delta: float) -> void:
	if statuses.is_empty():
		return
	var before := statuses.size()
	for status: Dictionary in statuses:
		status["time"] = float(status["time"]) - delta
	statuses = statuses.filter(func(s: Dictionary) -> bool: return float(s["time"]) > 0.0)
	if statuses.size() != before:
		_update_look()
		changed.emit()


## Escondido fica meio transparente (para você ainda se ver).
func _update_look() -> void:
	if model == null:
		return
	var alpha := 0.65 if is_hidden() else 0.0
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = alpha


func _fx() -> CombatFX:
	return get_tree().get_first_node_in_group("combat_fx") as CombatFX
