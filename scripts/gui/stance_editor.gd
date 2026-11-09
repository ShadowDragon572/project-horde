## The full stance editor, titled "Loadout" on screen. Opens between waves and pauses the game.
## Click a weapon in the Weapons list (the ArmoryList node), then click a hand slot to put it there.
## Click a slot with nothing selected to empty it.
extends Control

signal opened
signal closed

## The hint's color while a weapon is picked (the same amber as the highlighted slots).
const PICKED_HINT_COLOR := Color(0.98, 0.78, 0.4)

var _manager : StanceManager
var _selected : WeaponData

@onready var armory_list : VBoxContainer = %ArmoryList
@onready var stance_columns : HBoxContainer = %StanceColumns
@onready var hint_label : Label = %HintLabel
@onready var done_button : Button = %DoneButton


func _ready() -> void:
	# Keep working while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	done_button.pressed.connect(close)


func bind(manager: StanceManager) -> void:
	_manager = manager
	_manager.stances_edited.connect(_rebuild)


## Opened from the break prompt (wave_banner.gd, "open_loadout") through the "stance_editor" group.
func open() -> void:
	if _manager == null or visible:
		return
	_selected = null
	_manager.ui_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_rebuild()
	opened.emit()


func close() -> void:
	hide()
	get_tree().paused = false
	_manager.ui_open = false
	_manager.apply_active()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Debug shortcut (F2) so you can open the editor at any time, even mid-wave. Debug builds only.
	if OS.is_debug_build() and event.is_action_pressed("debug_stance_editor"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		# Esc works like "Back to the fight". The pause menu leaves Esc to us while we're open.
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	if not visible:
		return
	UIKit.clear_children(armory_list)
	UIKit.clear_children(stance_columns)

	for weapon in _manager.owned:
		var b := _make_button(weapon.display_name)
		var where := _manager.where_is(weapon)
		if weapon.two_handed:
			b.text += "  [2H]"
		if where != "":
			b.text += "   (%s)" % where
		b.icon = weapon.icon
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = weapon == _selected
		b.pressed.connect(_on_weapon_pressed.bind(weapon))
		armory_list.add_child(b)

	for i in _manager.stances.size():
		stance_columns.add_child(_make_column(i))

	# The hint sits under the title, so it's the first thing you read.
	# It turns amber once a weapon is picked, matching the highlighted slots.
	if _selected:
		hint_label.text = "Now click a highlighted hand slot to equip %s." % _selected.display_name
		hint_label.add_theme_color_override("font_color", PICKED_HINT_COLOR)
	else:
		hint_label.text = "Pick a weapon, then click a hand slot to equip it. Click a filled slot with nothing picked to empty it."
		hint_label.remove_theme_color_override("font_color")


## One stance as a card, styled like the Weapons panel next to it.
func _make_column(index: int) -> PanelContainer:
	var s := _manager.stances[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(340, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)

	column.add_child(UIKit.make_label(s.display_name, &"HeaderLabel"))

	var left_weapon := s.right if s.is_two_handed() else s.left
	column.add_child(_make_slot(index, Hand.Slot.LEFT, "Left hand", left_weapon))
	column.add_child(_make_slot(index, Hand.Slot.RIGHT, "Right hand", s.right))

	var swap := _make_button("Swap hands")
	swap.disabled = s.is_two_handed()
	swap.pressed.connect(_manager.swap_hands.bind(index))
	column.add_child(swap)
	return card


func _make_slot(index: int, side: Hand.Slot, label: String, weapon: WeaponData) -> Button:
	var b := _make_button("%s:  %s" % [label, UIKit.weapon_name(weapon)])
	b.custom_minimum_size = Vector2(0, 56)
	if weapon:
		b.icon = weapon.icon
	# With a weapon picked, every slot is a place it can go: show that with the amber style.
	if _selected:
		b.theme_type_variation = &"SlotTarget"
	b.pressed.connect(_on_slot_pressed.bind(index, side))
	return b


## Every button in the editor starts here. Its look comes from the theme.
func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE # A focused button would swallow Tab.
	return b


func _on_weapon_pressed(weapon: WeaponData) -> void:
	_selected = null if _selected == weapon else weapon
	_rebuild()


func _on_slot_pressed(index: int, side: Hand.Slot) -> void:
	_manager.assign(index, side, _selected) # Also triggers _rebuild via stances_edited.
	_selected = null
	_rebuild()
