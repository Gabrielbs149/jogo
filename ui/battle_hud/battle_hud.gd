class_name BattleHUD
extends CanvasLayer
## Interface da luta (D047, visual do Look Outside): a cena numa moldura escura; embaixo, o menu de comandos
## (1 = ataque, Q/E/R), a caixa de texto com o nome de quem fala (avisos, falas dos inimigos e as rolagens) e o seu
## retrato com vida e Pontos de Ação. Em cima: ordem dos turnos e inimigos com vida. Também o anel do QTE,
## os avisos ("PERFEITO!"), a piscada vermelha quando você apanha e o resultado.

signal action_chosen(index: int)
signal result_closed

const KEYS: Array[String] = ["1", "Q", "E", "R"]
const KEY_ACTIONS: Array[StringName] = [&"battle_attack", &"skill_q", &"skill_e", &"skill_r"]

@export var log_lines: int = 2
## Letras por segundo na caixa de texto.
@export var text_speed: float = 90.0

var _arena: BattleArena
var _buttons: Array[Button] = []
var _enemy_rows: Dictionary = {}
var _choosing: bool = false
var _log: PackedStringArray = []
var _banner_tween: Tween
var _text_tween: Tween
var _flash_tween: Tween

@onready var _order: HBoxContainer = %Order
@onready var _player_name: Label = %PlayerName
@onready var _player_hp: ProgressBar = %PlayerHp
@onready var _player_hp_text: Label = %PlayerHpText
@onready var _ap: Label = %AP
@onready var _statuses: Label = %Statuses
@onready var _actions: VBoxContainer = %Actions
@onready var _hint: Label = %Hint
@onready var _enemies: VBoxContainer = %Enemies
@onready var _speaker: Label = %Speaker
@onready var _says: RichTextLabel = %Says
@onready var _log_label: RichTextLabel = %Log
@onready var _banner: Label = %Banner
@onready var _flash: ColorRect = %Flash
@onready var _qte: QuickTime = %Qte
@onready var _dice: DiceRoller = %Dice
@onready var _golpe: GolpeQte = %Golpe
@onready var _ritmo: Label = %Ritmo
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText


func _ready() -> void:
	_result.hide()
	_banner.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_says.text = ""
	_log_label.text = ""
	%ResultButton.pressed.connect(func() -> void: result_closed.emit())


func setup(arena: BattleArena) -> void:
	_arena = arena
	var player := arena.player
	_player_name.text = player.display_name
	player.rolled.connect(log_line)
	for i: int in player.abilities.size():
		var ability := player.abilities[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		var cost := "+1 PA" if ability.ap_cost == 0 else "%d PA" % ability.ap_cost
		var detail := ability.dice_text() if ability.dice_text() != "" else ability.status_title
		button.text = "%s   %s\n      %s · %s" % [KEYS[i] if i < KEYS.size() else "", ability.title, cost, detail]
		button.tooltip_text = ability.description
		button.pressed.connect(_choose.bind(i))
		_actions.add_child(button)
		_buttons.append(button)
	for enemy: Combatant in arena.enemies:
		enemy.rolled.connect(log_line)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 16)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(280, 8)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("fill", _flat(Color(0.9, 0.62, 0.35)))
		bar.add_theme_stylebox_override("background", _flat(Color(0.16, 0.08, 0.1)))
		# postura (D048): enche com golpes bons; cheia, quebra
		var posture := ProgressBar.new()
		posture.custom_minimum_size = Vector2(280, 4)
		posture.show_percentage = false
		posture.tooltip_text = "Postura: golpes bons e aparadas enchem; cheia, ele QUEBRA (perde a vez e leva +50%)."
		posture.add_theme_stylebox_override("fill", _flat(Color(0.75, 0.85, 1.0)))
		posture.add_theme_stylebox_override("background", _flat(Color(0.1, 0.1, 0.16)))
		row.add_child(label)
		row.add_child(bar)
		row.add_child(posture)
		_enemies.add_child(row)
		_enemy_rows[enemy] = {"label": label, "bar": bar, "posture": posture}
	_set_choosing(false)
	refresh()


## Retrato do herói no canto: uma cópia do modelo dele, parado, num mundo só dele.
func setup_portrait(model: Node3D) -> void:
	var view := %Portrait.get_node("View") as SubViewport
	var copy := model.duplicate() as Node3D
	view.add_child(copy)
	for found: Node in copy.find_children("*", "GeometryInstance3D", true, false):
		(found as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	copy.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)  # o modelo olha para -Z; o retrato olha para ele
	var player_anim := copy.find_children("*", "AnimationPlayer", true, false)
	if not player_anim.is_empty():
		var ap := player_anim[0] as AnimationPlayer
		if ap.has_animation(&"Idle"):
			ap.play(&"Idle")
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 0.8)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 30, 0)
	key.light_color = Color(1, 0.88, 0.75)
	view.add_child(key)
	var cam := Camera3D.new()
	cam.fov = 30
	view.add_child(cam)
	cam.look_at_from_position(Vector3(0.35, 0.95, 1.5), Vector3(0, 0.72, 0))
	cam.current = true


func refresh() -> void:
	if _arena == null:
		return
	var player := _arena.player
	_player_hp.max_value = player.max_hp
	_player_hp.value = player.hp
	_player_hp_text.text = "%d / %d PV    CA %d" % [player.hp, player.max_hp, player.current_ac()]
	_ap.text = "PA  " + "●".repeat(_arena.ap) + "○".repeat(maxi(0, _arena.max_ap - _arena.ap))
	var names: PackedStringArray = []
	for status: Dictionary in player.statuses:
		if status["title"] != "":
			names.append("%s (%d)" % [status["title"], ceili(float(status["time"]))])
	_statuses.text = "   ".join(names)
	_ritmo.text = ("Ritmo  " + "◆".repeat(_arena.ritmo) + "◇".repeat(maxi(0, 5 - _arena.ritmo)) + ("   +%d%%" % (_arena.ritmo * 10) if _arena.ritmo > 0 else ""))
	for i: int in _buttons.size():
		_buttons[i].disabled = not _choosing or not _arena.can_afford(i)
	for key: Variant in _enemy_rows.keys():
		var row: Dictionary = _enemy_rows[key]
		var enemy := key as Combatant if is_instance_valid(key) else null
		var alive := enemy != null and enemy.hp > 0
		(row["label"] as Label).text = "%s%s   CA %d%s" % ["▶ " if alive and enemy == _arena.target else "", enemy.display_name if enemy else "",
			enemy.current_ac() if alive else 0, "   QUEBRADO" if alive and enemy.quebrado else ""]
		(row["posture"] as ProgressBar).max_value = enemy.posture_limit() if enemy else 1
		(row["posture"] as ProgressBar).value = enemy.postura if alive else 0
		(row["bar"] as ProgressBar).max_value = enemy.max_hp if enemy else 1
		(row["bar"] as ProgressBar).value = enemy.hp if alive else 0
		(row["label"] as Label).modulate.a = 1.0 if alive else 0.4


func set_order(order: Array[Combatant], current: Combatant) -> void:
	%OrderPanel.show()
	for child: Node in _order.get_children():
		child.queue_free()
	var first := true
	for entry: Variant in order:
		if not is_instance_valid(entry) or (entry as Combatant).hp <= 0:
			continue
		var c := entry as Combatant
		if not first:
			var sep := Label.new()
			sep.text = "›"
			sep.modulate = Color(1, 1, 1, 0.4)
			_order.add_child(sep)
		first = false
		var label := Label.new()
		label.text = c.display_name
		label.add_theme_font_size_override("font_size", 16 if c == current else 14)
		label.modulate = Color(1, 0.85, 0.5) if c == current else Color(1, 1, 1, 0.65)
		_order.add_child(label)
	refresh()


## Espera você escolher a ação (clique no comando ou 1/Q/E/R). A/D ou setas trocam o alvo.
func choose_action() -> int:
	_set_choosing(true)
	refresh()
	var index: int = await action_chosen
	_set_choosing(false)
	refresh()
	return index


## Escreve na caixa de texto, letra por letra, com o nome de quem fala na plaquinha. Volta quando terminar de escrever
## (e mais `hold` segundos para dar tempo de ler). Texto entre ** fica em vermelho (grito, como no Look Outside).
func say(speaker: String, text: String, hold: float = 0.0) -> void:
	_speaker.text = speaker if speaker != "" else "Luta"
	%SpeakerTag.modulate.a = 1.0 if speaker != "" else 0.55
	var shown := text
	var parts := shown.split("**")
	if parts.size() >= 3:
		shown = ""
		for i: int in parts.size():
			shown += ("[color=#e8505a]%s[/color]" % parts[i]) if i % 2 == 1 else parts[i]
	_says.text = shown
	_says.visible_ratio = 0.0
	if _text_tween:
		_text_tween.kill()
	_text_tween = create_tween()
	var chars := maxf(1.0, float(_says.get_total_character_count()))
	_text_tween.tween_property(_says, "visible_ratio", 1.0, chars / text_speed)
	if hold > 0.0:
		_text_tween.tween_interval(hold)
	await _text_tween.finished


## A tela pisca vermelho (você apanhou).
func hurt_flash(strength: float = 0.35) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.color.a = strength
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)


func qte(world_pos: Vector3, duration: float, keys: Array[StringName], label: String) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	var point := cam.unproject_position(world_pos) if cam and not cam.is_position_behind(world_pos) else get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
	return await _qte.run(point, duration, keys, label)


## Meio da janela da cena (onde aparecem o dado e os desafios).
func scene_center() -> Vector2:
	return get_viewport().get_visible_rect().size * Vector2(0.5, 0.36)


## Mostra o(s) d20 rolando até parar no que saiu (D048).
func roll_dice(dice: Array[Dictionary]) -> void:
	await _dice.roll(dice, scene_center() + Vector2(0, -20))


func golpe() -> GolpeQte:
	return _golpe


func banner(text: String, color: Color = Color(1, 0.9, 0.6)) -> void:
	_banner.text = text
	_banner.modulate = color
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.7)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


## As rolagens (d20, dano) aparecem miúdas embaixo do texto, as duas últimas.
func log_line(line: String) -> void:
	_log.append(line)
	while _log.size() > log_lines:
		_log.remove_at(0)
	_log_label.text = "\n".join(_log)


func show_result(victory: bool, text: String) -> void:
	_result_title.text = "Vitória" if victory else "Você caiu"
	_result_text.text = text
	_result.show()
	await result_closed
	_result.hide()


func _set_choosing(on: bool) -> void:
	_choosing = on
	var tween := create_tween().set_parallel()
	tween.tween_property(_actions, "modulate:a", 1.0 if on else 0.45, 0.15)
	tween.tween_property(_hint, "modulate:a", 1.0 if on else 0.0, 0.15)


func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box


func _choose(index: int) -> void:
	if _choosing and _arena.can_afford(index):
		action_chosen.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if _result.visible and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo():
		if event is InputEventKey:
			result_closed.emit()
		return
	if not _choosing:
		return
	for i: int in KEY_ACTIONS.size():
		if event.is_action_pressed(KEY_ACTIONS[i]) and i < _buttons.size():
			get_viewport().set_input_as_handled()
			_choose(i)
			return
	if event.is_action_pressed(&"move_left"):
		_arena.cycle_target(-1)
		refresh()
	elif event.is_action_pressed(&"move_right"):
		_arena.cycle_target(1)
		refresh()
