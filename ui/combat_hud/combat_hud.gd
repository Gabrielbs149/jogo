class_name CombatHUD
extends CanvasLayer
## Interface do combate: ordem dos turnos (topo), personagem da vez + habilidades (embaixo),
## registro (direita), dica do mouse, anúncio de turno e tela de fim. Só ouve o CombatManager.

@export var manager: CombatManager

signal intro_closed

const HERO_RING := Color(1.0, 0.85, 0.55)
const ENEMY_RING := Color(1.0, 0.42, 0.25)

var _ability_buttons: Array[Button] = []
var _banner_tween: Tween
var _victory_text: String = "As areias se acalmam."
var _defeat_text: String = "O vento cobre os seus passos."
var _intro_skip: bool = false
var _intro_ready: bool = false

@onready var _initiative: HBoxContainer = %Initiative
@onready var _round: Label = %Round
@onready var _name: Label = %UnitName
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_text: Label = %HpText
@onready var _stats: Label = %Stats
@onready var _abilities: HBoxContainer = %Abilities
@onready var _end_turn: Button = %EndTurn
@onready var _log: RichTextLabel = %Log
@onready var _tooltip: PanelContainer = %Tooltip
@onready var _tooltip_text: Label = %TooltipText
@onready var _banner: Label = %Banner
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText
@onready var _intro: Control = %Intro
@onready var _intro_title: Label = %IntroTitle
@onready var _intro_lines: VBoxContainer = %IntroLines
@onready var _intro_hint: Label = %IntroHint


## Abertura do capítulo: as frases aparecem uma a uma; espera um clique ou tecla. Use com await.
func play_intro(title: String, lines: PackedStringArray) -> void:
	_intro.show()
	_intro.modulate.a = 1.0
	_intro_title.text = title
	_intro_hint.modulate.a = 0.0
	for child: Node in _intro_lines.get_children():
		child.queue_free()
	_intro_skip = false
	_intro_ready = false
	for line: String in lines:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 21)
		label.modulate.a = 0.0
		_intro_lines.add_child(label)
		if _intro_skip:
			label.modulate.a = 1.0
		else:
			await create_tween().tween_property(label, "modulate:a", 1.0, 0.9).finished
	_intro_ready = true
	create_tween().tween_property(_intro_hint, "modulate:a", 1.0, 0.6)
	await intro_closed
	await create_tween().tween_property(_intro, "modulate:a", 0.0, 0.8).finished
	_intro.hide()


## Mostra/esconde tudo do combate (a abertura do capítulo é à parte).
func set_combat_visible(on: bool) -> void:
	for child: Node in $Root.get_children():
		if child != _intro and child is Control:
			(child as Control).visible = on
	if on:
		_tooltip.hide()
		_result.hide()
		_log.text = ""


func set_result_texts(victory: String, defeat: String) -> void:
	_victory_text = victory
	_defeat_text = defeat


func _input(event: InputEvent) -> void:
	if not _intro.visible:
		return
	var pressed := (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if not _intro_ready:
		# Primeiro clique: mostra tudo de uma vez; o próximo fecha
		_intro_skip = true
		for label: Node in _intro_lines.get_children():
			(label as Label).modulate.a = 1.0
		_intro_hint.modulate.a = 1.0
	else:
		intro_closed.emit()


func _ready() -> void:
	_intro.hide()
	_tooltip.hide()
	_result.hide()
	_banner.modulate.a = 0.0
	_log.text = ""
	if manager == null:
		return
	manager.combat_started.connect(_on_combat_started)
	manager.turn_started.connect(_on_turn_started)
	manager.unit_changed.connect(_on_unit_changed)
	manager.ability_selected.connect(_on_ability_selected)
	manager.message.connect(_on_message)
	manager.hover_changed.connect(_on_hover_changed)
	manager.combat_ended.connect(_on_combat_ended)
	_end_turn.pressed.connect(manager.end_turn_pressed)


func _process(_delta: float) -> void:
	if _tooltip.visible:
		var pos := get_viewport().get_mouse_position() + Vector2(22, 22)
		var max_pos := get_viewport().get_visible_rect().size - _tooltip.size - Vector2(8, 8)
		_tooltip.position = pos.min(max_pos)


func _on_combat_started(_order: Array[Unit]) -> void:
	_rebuild_initiative()


func _on_turn_started(unit: Unit) -> void:
	_round.text = "Rodada %d" % manager.round_number
	_rebuild_initiative()
	_show_unit(unit)
	_rebuild_abilities(unit)
	var verb := "Sua vez:" if unit.team == Unit.Team.HEROES and not manager.auto_heroes else "Turno de"
	_show_banner("%s %s" % [verb, unit.display_name])


func _on_unit_changed(unit: Unit) -> void:
	_rebuild_initiative()
	if unit == manager.active:
		_show_unit(unit)
		_refresh_ability_buttons(unit)


func _on_ability_selected(index: int) -> void:
	for i: int in _ability_buttons.size():
		_ability_buttons[i].set_pressed_no_signal(i == index)


func _on_message(text: String) -> void:
	_log.append_text(text + "\n")
	var lines := _log.get_parsed_text().split("\n")
	if lines.size() > 80:
		_log.clear()
		_log.append_text("[i]...[/i]\n")


func _on_hover_changed(text: String) -> void:
	_tooltip.visible = text != ""
	_tooltip_text.text = text
	_tooltip.reset_size()


func _on_combat_ended(victory: bool) -> void:
	_result.show()
	_result_title.text = "Vitória" if victory else "Derrota"
	_result_text.text = _victory_text if victory else _defeat_text
	_show_banner("")


# ---------- montagem ----------

func _rebuild_initiative() -> void:
	for child: Node in _initiative.get_children():
		child.queue_free()
	for unit: Unit in manager.order:
		if not unit.is_alive():
			continue
		_initiative.add_child(_chip(unit, unit == manager.active))


func _chip(unit: Unit, is_active: bool) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle := PanelContainer.new()
	var size := 60.0 if is_active else 46.0
	circle.custom_minimum_size = Vector2(size, size)
	var style := StyleBoxFlat.new()
	style.bg_color = unit.color.darkened(0.15)
	style.set_corner_radius_all(int(size))
	style.set_border_width_all(3 if is_active else 2)
	style.border_color = (HERO_RING if unit.team == Unit.Team.HEROES else ENEMY_RING) if is_active else Color(0.15, 0.07, 0.04, 0.7)
	if is_active:
		style.shadow_color = Color(1.0, 0.8, 0.45, 0.6)
		style.shadow_size = 10
	circle.add_theme_stylebox_override("panel", style)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initial := Label.new()
	initial.theme_type_variation = &"TitleLabel"
	initial.add_theme_font_size_override("font_size", 24 if is_active else 18)
	initial.text = unit.display_name.left(1)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(initial)
	box.add_child(circle)
	var label := Label.new()
	label.text = unit.display_name
	label.add_theme_font_size_override("font_size", 12)
	label.custom_minimum_size = Vector2(74, 0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(size, 5)
	bar.show_percentage = false
	bar.max_value = unit.max_hp
	bar.value = unit.hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.75, 0.42) if unit.team == Unit.Team.HEROES else Color(0.95, 0.4, 0.25)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box


func _show_unit(unit: Unit) -> void:
	_name.text = unit.display_name
	_hp_bar.max_value = unit.max_hp
	_hp_bar.value = unit.hp
	_hp_text.text = "%d / %d" % [unit.hp, unit.max_hp]
	var parts: PackedStringArray = [
		"CA %d" % unit.current_ac(),
		"Movimento %d/%d" % [unit.moves_left, unit.speed],
		"Ação: %s" % ("pronta" if unit.has_action else "usada"),
	]
	if unit.flying:
		parts.append("voa")
	for status: Dictionary in unit.statuses:
		parts.append(str(status["title"]))
	_stats.text = "  ·  ".join(parts)


func _rebuild_abilities(unit: Unit) -> void:
	for child: Node in _abilities.get_children():
		child.queue_free()
	_ability_buttons.clear()
	for i: int in unit.abilities.size():
		var ability := unit.abilities[i]
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(172, 72)
		button.focus_mode = Control.FOCUS_NONE
		var range_text := "si mesmo" if ability.target == Ability.Target.SELF else ("corpo a corpo" if ability.reach <= 1 else "%d casas" % ability.reach)
		var detail := ability.dice_text()
		if ability.kind == Ability.Kind.HEAL:
			detail = "cura " + detail
		elif ability.kind == Ability.Kind.BUFF:
			detail = "reforço"
		button.text = "%d  %s\n%s · %s" % [i + 1, ability.title, detail, range_text]
		button.tooltip_text = ability.description
		button.pressed.connect(manager.select_ability.bind(i))
		_abilities.add_child(button)
		_ability_buttons.append(button)
	_refresh_ability_buttons(unit)


func _refresh_ability_buttons(unit: Unit) -> void:
	var players_turn := unit.team == Unit.Team.HEROES and not manager.auto_heroes
	for button: Button in _ability_buttons:
		button.disabled = not players_turn or not unit.has_action
	_end_turn.disabled = not players_turn


func _show_banner(text: String) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.text = text
	if text == "":
		_banner.modulate.a = 0.0
		return
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(1.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
