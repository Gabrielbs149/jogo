extends Control
## Escolha de quem você vai seguir na história. Os outros heróis você encontra pelo caminho
## e decide se chama para o grupo. Mostra o herói no acampamento (fundo 3D dos menus, D038), parado e respirando
## (arraste com o mouse para girar), a ficha (D&D 5.5) e as habilidades.

const KEYS: Array[String] = ["Botão esq.", "Q", "E", "R"]
## Ângulo em que o herói fica virado para a câmera (graus; 0 = de frente).
@export var facing: float = -20.0

var _selected: String = ""
var _preview: Combatant
var _buttons: Dictionary = {}
var _dragging: bool = false

@onready var _list: VBoxContainer = %HeroList
@onready var _pivot: Node3D = %Pivot
@onready var _name: Label = %HeroName
@onready var _class: Label = %HeroClass
@onready var _stats: Label = %HeroStats
@onready var _bio: Label = %HeroBio
@onready var _skills: RichTextLabel = %HeroSkills


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var group := ButtonGroup.new()
	for id: String in Game.HEROES:
		var hero := Game.hero_scene(id).instantiate() as Combatant
		var button := Button.new()
		button.text = "%s\n%s" % [hero.display_name, hero.class_title]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(300, 74)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select.bind(id))
		_list.add_child(button)
		_buttons[id] = button
		hero.free()
	%Start.pressed.connect(func() -> void: Game.new_game(_selected))
	%Back.pressed.connect(func() -> void: Game.go_to_title())
	select(Game.chosen if Game.HEROES.has(Game.chosen) else Game.HEROES.keys()[0])


func select(id: String) -> void:
	_selected = id
	(_buttons[id] as Button).set_pressed_no_signal(true)
	if _preview:
		_preview.queue_free()
	_preview = Game.hero_scene(id).instantiate() as Combatant
	_preview.process_mode = Node.PROCESS_MODE_DISABLED
	_pivot.add_child(_preview)
	_pivot.rotation.y = PI + deg_to_rad(facing)
	# o personagem fica parado, mas respirando (a animação "parado" que o Animator dele usa)
	var animator := _preview.get_node_or_null("Animator") as CombatantAnimator
	var idle_name: StringName = animator.idle if animator else &"idle"
	for node: Node in _preview.find_children("*", "AnimationPlayer", true, false):
		var anim := node as AnimationPlayer
		anim.process_mode = Node.PROCESS_MODE_ALWAYS
		if animator and animator.extra_library and not anim.has_animation_library(animator.extra_library_name):
			anim.add_animation_library(animator.extra_library_name, animator.extra_library)
		if anim.has_animation(idle_name):
			anim.get_animation(idle_name).loop_mode = Animation.LOOP_LINEAR
			anim.play(idle_name)
	_name.text = _preview.display_name
	_class.text = _preview.class_title
	_stats.text = "CA %d   ·   PV %d   ·   Ataque +%d   ·   CD %d   ·   Deslocamento %.1f m/s\nSalvamentos: DES %+d   CON %+d   SAB %+d" % [
		_preview.armor_class, _preview.max_hp, _preview.attack_bonus, _preview.spell_dc, _preview.move_speed,
		_preview.dex_save, _preview.con_save, _preview.wis_save]
	_bio.text = _preview.bio
	var lines: PackedStringArray = []
	for i: int in _preview.abilities.size():
		var ability := _preview.abilities[i]
		var info: PackedStringArray = []
		if ability.dice_text() != "":
			info.append(ability.dice_text())
		info.append("recarga %ss" % ("%.1f" % ability.cooldown).trim_suffix(".0"))
		lines.append("[color=#ffd9a0][b]%s[/b][/color]  [b]%s[/b]   [color=#c8b8a0]%s[/color]\n%s\n[i][color=#b0a090]%s[/color][/i]" % [
			KEYS[i] if i < KEYS.size() else "", ability.title, "  ·  ".join(info), ability.description, ability.dnd_note])
	lines.append("[color=#ffd9a0][b]Espaço[/b][/color]  [b]%s[/b]   [color=#c8b8a0]recarga %ss[/color]\nUm salto rápido; enquanto dura, ataques contra você têm desvantagem." % [
		_preview.dodge_name, ("%.1f" % _preview.dodge_cooldown).trim_suffix(".0")])
	_skills.text = "\n\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.is_pressed()
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y += (event as InputEventMouseMotion).relative.x * 0.01
