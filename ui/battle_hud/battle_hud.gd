class_name BattleHUD
extends CanvasLayer
## Interface da arena: ordem dos turnos, sua vida e Pontos de Ação, botões das ações (1 = ataque, Q/E/R),
## inimigos com vida, registro das rolagens, anel do QTE, avisos ("PERFEITO!") e o resultado.

signal action_chosen(index: int)
signal result_closed

const KEYS: Array[String] = ["1", "Q", "E", "R"]
const KEY_ACTIONS: Array[StringName] = [&"battle_attack", &"skill_q", &"skill_e", &"skill_r"]

@export var log_lines: int = 5

var _arena: BattleArena
var _buttons: Array[Button] = []
var _enemy_rows: Dictionary = {}
var _choosing: bool = false
var _log: PackedStringArray = []
var _banner_tween: Tween

@onready var _order: HBoxContainer = %Order
@onready var _player_name: Label = %PlayerName
@onready var _player_hp: ProgressBar = %PlayerHp
@onready var _player_hp_text: Label = %PlayerHpText
@onready var _ap: Label = %AP
@onready var _statuses: Label = %Statuses
@onready var _actions: HBoxContainer = %Actions
@onready var _hint: Label = %Hint
@onready var _enemies: VBoxContainer = %Enemies
@onready var _log_label: RichTextLabel = %Log
@onready var _banner: Label = %Banner
@onready var _qte: QuickTime = %Qte
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText


func _ready() -> void:
	_result.hide()
	_banner.modulate.a = 0.0
	_actions.hide()
	_hint.hide()
	%LogPanel.hide()  # aparece na primeira rolagem (sem caixa vazia na tela)
	%ResultButton.pressed.connect(func() -> void: result_closed.emit())


func setup(arena: BattleArena) -> void:
	_arena = arena
	var player := arena.player
	_player_name.text = "%s  ·  %s" % [player.display_name, player.class_title]
	player.rolled.connect(log_line)
	for i: int in player.abilities.size():
		var ability := player.abilities[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 64)
		button.focus_mode = Control.FOCUS_NONE
		var cost := "+1 PA" if ability.ap_cost == 0 else "%d PA" % ability.ap_cost
		button.text = "[%s] %s\n%s · %s" % [KEYS[i] if i < KEYS.size() else "", ability.title, cost, ability.dice_text() if ability.dice_text() != "" else ability.status_title]
		button.pressed.connect(_choose.bind(i))
		_actions.add_child(button)
		_buttons.append(button)
	for enemy: Combatant in arena.enemies:
		enemy.rolled.connect(log_line)
		var row := VBoxContainer.new()
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 17)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(260, 12)
		bar.show_percentage = false
		row.add_child(label)
		row.add_child(bar)
		_enemies.add_child(row)
		_enemy_rows[enemy] = {"label": label, "bar": bar}
	refresh()


func refresh() -> void:
	if _arena == null:
		return
	var player := _arena.player
	_player_hp.max_value = player.max_hp
	_player_hp.value = player.hp
	_player_hp_text.text = "%d / %d PV   CA %d" % [player.hp, player.max_hp, player.current_ac()]
	_ap.text = "PA  " + "●".repeat(_arena.ap) + "○".repeat(maxi(0, _arena.max_ap - _arena.ap))
	var names: PackedStringArray = []
	for status: Dictionary in player.statuses:
		if status["title"] != "":
			names.append("%s (%d)" % [status["title"], ceili(float(status["time"]))])
	_statuses.text = "   ".join(names)
	for i: int in _buttons.size():
		_buttons[i].disabled = not _arena.can_afford(i)
	for key: Variant in _enemy_rows.keys():
		var row: Dictionary = _enemy_rows[key]
		var enemy := key as Combatant if is_instance_valid(key) else null
		var alive := enemy != null and enemy.hp > 0
		(row["label"] as Label).text = "%s%s   CA %d" % ["▶ " if alive and enemy == _arena.target else "", enemy.display_name if enemy else "", enemy.current_ac() if alive else 0]
		(row["bar"] as ProgressBar).max_value = enemy.max_hp if enemy else 1
		(row["bar"] as ProgressBar).value = enemy.hp if alive else 0
		(row["label"] as Label).modulate.a = 1.0 if alive else 0.4


func set_order(order: Array[Combatant], current: Combatant) -> void:
	for child: Node in _order.get_children():
		child.queue_free()
	for entry: Variant in order:
		if not is_instance_valid(entry) or (entry as Combatant).hp <= 0:
			continue
		var c := entry as Combatant
		var label := Label.new()
		label.text = c.display_name
		label.add_theme_font_size_override("font_size", 18 if c == current else 15)
		label.modulate = Color(1, 0.85, 0.5) if c == current else Color(1, 1, 1, 0.7)
		_order.add_child(label)
	refresh()


## Espera você escolher a ação (clique no botão ou 1/Q/E/R). A/D ou setas trocam o alvo.
func choose_action() -> int:
	refresh()
	_choosing = true
	_actions.show()
	_hint.show()
	var index: int = await action_chosen
	_choosing = false
	_actions.hide()
	_hint.hide()
	return index


func qte(world_pos: Vector3, duration: float, keys: Array[StringName], label: String) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	var point := cam.unproject_position(world_pos) if cam else get_viewport().get_visible_rect().size / 2.0
	return await _qte.run(point, duration, keys, label)


func banner(text: String, color: Color = Color(1, 0.9, 0.6)) -> void:
	_banner.text = text
	_banner.modulate = color
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.7)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


func log_line(line: String) -> void:
	_log.append(line)
	while _log.size() > log_lines:
		_log.remove_at(0)
	_log_label.text = "\n".join(_log)
	%LogPanel.show()


func show_result(victory: bool, text: String) -> void:
	_result_title.text = "Vitória" if victory else "Você caiu"
	_result_text.text = text
	_result.show()
	await result_closed
	_result.hide()


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
