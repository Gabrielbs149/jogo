class_name GameHUD
extends CanvasLayer
## Interface do modo ação: vida e habilidades (com recarga) do seu herói, o grupo, o alvo na mira,
## o registro de rolagens, avisos, "F · interagir", textos da história, abertura do capítulo,
## convite para o grupo, resultado e pausa (Esc).

signal intro_closed
signal recruit_answered(yes: bool)
signal continue_pressed

const KEYS: Array[String] = ["Botão esq.", "Q", "E", "R"]
## Quanto tempo o painel de história fica na tela (segundos).
@export var story_time: float = 9.0
@export var log_lines: int = 7

var _player: Combatant
var _controller: PlayerController
var _slots: Array[Dictionary] = []
var _party_rows: Dictionary = {}
var _story_tween: Tween
var _toast_tween: Tween
var _log: PackedStringArray = []
var _intro_ready: bool = false
var _modal: bool = false

@onready var _reticle: Control = %Reticle
@onready var _target_frame: Control = %TargetFrame
@onready var _target_name: Label = %TargetName
@onready var _target_hp: ProgressBar = %TargetHp
@onready var _target_info: Label = %TargetInfo
@onready var _area: Label = %AreaName
@onready var _toast: Label = %Toast
@onready var _prompt: Label = %Prompt
@onready var _player_name: Label = %PlayerName
@onready var _player_hp_text: Label = %PlayerHpText
@onready var _player_hp: ProgressBar = %PlayerHp
@onready var _statuses: Label = %Statuses
@onready var _skill_bar: HBoxContainer = %SkillBar
@onready var _party_panel: Control = %PartyPanel
@onready var _party: VBoxContainer = %Party
@onready var _log_label: RichTextLabel = %Log
@onready var _log_panel: Control = %LogPanel
@onready var _story: PanelContainer = %Story
@onready var _story_text: Label = %StoryText
@onready var _recruit: Control = %Recruit
@onready var _recruit_name: Label = %RecruitName
@onready var _recruit_class: Label = %RecruitClass
@onready var _recruit_text: Label = %RecruitText
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText
@onready var _result_continue: Button = %ResultContinue
@onready var _pause: Control = %Pause
@onready var _intro: Control = %Intro
@onready var _intro_title: Label = %IntroTitle
@onready var _intro_lines: VBoxContainer = %IntroLines
@onready var _intro_hint: Label = %IntroHint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node: Control in [_story, _recruit, _result, _pause, _intro, _target_frame, _party_panel]:
		node.hide()
	_area.modulate.a = 0.0
	_toast.modulate.a = 0.0
	_prompt.text = ""
	_log_label.text = ""
	_log_panel.hide()  # aparece na primeira rolagem
	%RecruitYes.pressed.connect(func() -> void: _answer_recruit(true))
	%RecruitNo.pressed.connect(func() -> void: _answer_recruit(false))
	_result_continue.pressed.connect(_on_result_continue)
	%ResultRetry.pressed.connect(_on_retry)
	%ResultMenu.pressed.connect(func() -> void: Game.go_to_title())
	%PauseResume.pressed.connect(func() -> void: set_paused(false))
	%PauseMenu.pressed.connect(func() -> void: Game.go_to_title())


func setup(player: Combatant, controller: PlayerController) -> void:
	_player = player
	_controller = controller
	_player_name.text = "%s  ·  %s" % [player.display_name, player.class_title]
	for child: Node in _skill_bar.get_children():
		child.queue_free()
	_slots.clear()
	if controller.field_mode:
		# no mapa: só o golpe que começa a luta e a esquiva; as habilidades ficam para a arena
		_slots.append(_make_slot(KEYS[0], "Golpe", 0))
	else:
		for i: int in player.abilities.size():
			_slots.append(_make_slot(KEYS[i] if i < KEYS.size() else "", player.abilities[i].title, i))
	_slots.append(_make_slot("Espaço", player.dodge_name, -1))
	controller.message.connect(toast)
	controller.interactable_changed.connect(_on_interactable)


## Mostra a linha de rolagens deste personagem no registro.
func watch(c: Combatant) -> void:
	if not c.rolled.is_connected(log_line):
		c.rolled.connect(log_line)


func add_party_member(c: Combatant) -> void:
	if _party_rows.has(c):
		return
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 12)
	bar.show_percentage = false
	row.add_child(label)
	row.add_child(bar)
	_party.add_child(row)
	_party_rows[c] = {"label": label, "bar": bar}
	_party_panel.show()
	watch(c)


func log_line(line: String) -> void:
	_log.append(line)
	while _log.size() > log_lines:
		_log.remove_at(0)
	_log_label.text = "\n".join(_log)
	_log_panel.show()


func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func show_area(area_name: String) -> void:
	_area.text = area_name
	_area.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_area, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.5)
	tween.tween_property(_area, "modulate:a", 0.0, 1.2)


func show_story(text: String) -> void:
	if text == "":
		return
	_story_text.text = text
	_story.show()
	_story.modulate.a = 0.0
	if _story_tween:
		_story_tween.kill()
	_story_tween = create_tween()
	_story_tween.tween_property(_story, "modulate:a", 1.0, 0.3)
	_story_tween.tween_interval(story_time)
	_story_tween.tween_property(_story, "modulate:a", 0.0, 0.6)
	_story_tween.tween_callback(_story.hide)


func play_intro(title: String, lines: PackedStringArray) -> void:
	_modal = true
	_intro.show()
	_intro.modulate.a = 1.0
	_intro_title.text = title
	_intro_hint.modulate.a = 0.0
	for child: Node in _intro_lines.get_children():
		child.queue_free()
	_intro_ready = false
	for line: String in lines:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 21)
		label.modulate.a = 0.0
		_intro_lines.add_child(label)
		await create_tween().tween_property(label, "modulate:a", 1.0, 0.9).finished
	_intro_ready = true
	create_tween().tween_property(_intro_hint, "modulate:a", 1.0, 0.6)
	await intro_closed
	await create_tween().tween_property(_intro, "modulate:a", 0.0, 0.8).finished
	_intro.hide()
	_modal = false


## Convite para o grupo. Devolve true se você chamou.
func ask_recruit(hero: Combatant) -> bool:
	_modal = true
	_recruit_name.text = hero.display_name
	_recruit_class.text = hero.class_title
	_recruit_text.text = hero.greeting
	_recruit.show()
	_set_mouse(true)
	var yes: bool = await recruit_answered
	_recruit.hide()
	_set_mouse(false)
	_modal = false
	return yes


func show_result(victory: bool, text: String) -> void:
	_modal = true
	_result_title.text = "Vitória" if victory else "O grupo caiu"
	_result_text.text = text
	_result_continue.visible = victory
	_result.show()
	_set_mouse(true)
	if not victory:
		get_tree().paused = true


func set_paused(on: bool) -> void:
	get_tree().paused = on
	_pause.visible = on
	_set_mouse(on)


func _unhandled_input(event: InputEvent) -> void:
	if _intro.visible and _intro_ready and (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		get_viewport().set_input_as_handled()
		intro_closed.emit()
		return
	if event.is_action_pressed(&"pause") and not _modal:
		set_paused(not _pause.visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player_hp.max_value = _player.max_hp
	_player_hp.value = _player.hp
	_player_hp_text.text = "%d / %d PV   CA %d" % [_player.hp, _player.max_hp, _player.current_ac()]
	var names: PackedStringArray = []
	for status: Dictionary in _player.statuses:
		if status["title"] != "":
			names.append("%s %.0fs" % [status["title"], ceilf(float(status["time"]))])
	_statuses.text = "Caído — o grupo precisa vencer a luta ou te curar" if _player.downed else "   ".join(names)
	for slot: Dictionary in _slots:
		var i: int = slot["index"]
		var ratio := _player.cooldown_ratio(i) if i >= 0 else _player.dodge_left / maxf(_player.dodge_cooldown, 0.01)
		var left := _player.cooldowns[i] if i >= 0 else _player.dodge_left
		_update_slot(slot, ratio, left)
	for c: Combatant in _party_rows.keys():
		if not is_instance_valid(c):
			continue
		var row: Dictionary = _party_rows[c]
		(row["label"] as Label).text = "%s%s" % [c.display_name, "  (caído)" if c.downed else ""]
		(row["bar"] as ProgressBar).max_value = c.max_hp
		(row["bar"] as ProgressBar).value = c.hp
	var target: Combatant = _controller.looked_at() if _controller else null
	_target_frame.visible = target != null
	if target:
		_target_name.text = target.display_name
		_target_hp.max_value = target.max_hp
		_target_hp.value = target.hp
		_target_info.text = "CA %d   ·   %d / %d PV%s" % [target.current_ac(), target.hp, target.max_hp, "   ·   " + _status_names(target) if not target.statuses.is_empty() else ""]
	_reticle.visible = not _modal and not _pause.visible


func _make_slot(key: String, title: String, index: int) -> Dictionary:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(118, 88)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(box)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(shade)
	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.modulate = Color(1, 0.86, 0.6)
	key_label.position = Vector2(4, 0)
	box.add_child(key_label)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.offset_top = 16
	box.add_child(title_label)
	var cd := Label.new()
	cd.add_theme_font_size_override("font_size", 26)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(cd)
	_skill_bar.add_child(slot)
	return {"shade": shade, "cd": cd, "title": title_label, "index": index}


func _update_slot(slot: Dictionary, ratio: float, left: float) -> void:
	var shade := slot["shade"] as ColorRect
	shade.anchor_top = 1.0 - clampf(ratio, 0.0, 1.0)
	shade.offset_top = 0.0
	(slot["cd"] as Label).text = ("%.0f" % ceilf(left)) if left > 0.95 else ""
	(slot["title"] as Label).modulate.a = 0.45 if left > 0.0 else 1.0


func _status_names(c: Combatant) -> String:
	var names: PackedStringArray = []
	for status: Dictionary in c.statuses:
		if status["title"] != "":
			names.append(status["title"])
	return ", ".join(names)


func _on_interactable(node: Interactable) -> void:
	_prompt.text = ("F  ·  %s" % node.prompt_text) if node else ""


func _answer_recruit(yes: bool) -> void:
	recruit_answered.emit(yes)


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_result_continue() -> void:
	_result.hide()
	_set_mouse(false)
	_modal = false
	continue_pressed.emit()


func _set_mouse(free: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED
