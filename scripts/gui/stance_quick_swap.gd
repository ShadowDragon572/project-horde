## Hold the stance menu key (Tab) to see every stance.
## While it's held, press a stance key (1, 2, 3...) or scroll to pick one, and let go to switch to it.
## The game keeps running in slow motion. Editing happens elsewhere, between waves.
extends Control

## How fast the game runs while this is open. 1.0 = no slow motion.
@export_range(0.05, 1.0) var slow_motion : float = 0.35

var _manager : StanceManager
var _picked : int = 0

@onready var cards : HBoxContainer = %Cards
@onready var swap_hint_label : Label = %SwapHintLabel


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(manager: StanceManager) -> void:
	_manager = manager


func _unhandled_input(event: InputEvent) -> void:
	if _manager == null:
		return

	if event.is_action_pressed("stance_menu") and not _manager.ui_open:
		_open()
	elif visible and event.is_action_released("stance_menu"):
		_close()
	elif visible:
		var key_index := _pressed_stance_key(event)
		if key_index >= 0:
			_pick(key_index)
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_pick(_picked + 1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_pick(_picked - 1)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


## Which stance key was just pressed: 0 for "stance_1", 1 for "stance_2", and so on.
## -1 if none. Checks one action per stance, so a new stance only needs a new
## "stance_N" action in the Input Map, not a code change here.
func _pressed_stance_key(event: InputEvent) -> int:
	for i in _manager.stances.size():
		var action := "stance_%d" % (i + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return i
	return -1


func _open() -> void:
	_picked = _manager.active
	_manager.ui_open = true
	Engine.time_scale = slow_motion
	# Tell new players how this menu works, using their actual keys.
	swap_hint_label.text = "Release %s to switch   ·   Scroll or %s-%s to pick" % [
		UIKit.key_text("stance_menu"), UIKit.key_text("stance_1"),
		UIKit.key_text("stance_%d" % _manager.stances.size())]
	_rebuild()
	show()


func _close() -> void:
	hide()
	Engine.time_scale = 1.0
	_manager.ui_open = false
	_manager.set_active(_picked)


func _pick(index: int) -> void:
	_picked = wrapi(index, 0, _manager.stances.size())
	_rebuild()


func _rebuild() -> void:
	UIKit.clear_children(cards)
	for i in _manager.stances.size():
		var card := _make_card(i)
		# Every card stays fully readable; the picked one gets the amber border from the theme.
		# (Fading the others made them hard to read over the bright fog.)
		if i == _picked:
			card.theme_type_variation = &"PickedPanel"
		cards.add_child(card)


## One stance card: name, then what's in each hand, then a dim key hint
## ("Press 2", plus "equipped" on the stance you're using right now).
## Same panel style and text sizes as the hand panels (from the theme).
func _make_card(index: int) -> PanelContainer:
	var s := _manager.stances[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	# Ignore the mouse so the cards can't eat the scroll wheel used to pick.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var hint := "Press %s" % UIKit.key_text("stance_%d" % (index + 1))
	if index == _manager.active:
		hint += "  ·  equipped"
	box.add_child(UIKit.make_label(s.display_name, &"WeaponNameLabel"))
	box.add_child(UIKit.make_label(_describe(s)))
	box.add_child(UIKit.make_label(hint, &"KeyHintLabel"))
	for label in box.get_children():
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return card


func _describe(s: Stance) -> String:
	if s.is_two_handed():
		return "Both hands: %s" % s.right.display_name
	return "L: %s\nR: %s" % [UIKit.weapon_name(s.left), UIKit.weapon_name(s.right)]
