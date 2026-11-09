## Small helpers shared by the HUD scripts (hand panels, quick swap, stance editor).
## Everything here is static, so call it straight from the class: UIKit.key_text("reload_left").
## Looks (fonts, sizes, colors) live in res://assets/theme/main_theme.tres, not here.
class_name UIKit
extends RefCounted


## The name of the first key bound to an action, like "Q" or "LMB". "?" if nothing is bound.
static func key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	# Godot adds a physical-key suffix ("Q - Physical", or "Q (Physical)" in older
	# versions). Short mouse names keep hints on one line so panels don't stretch.
	return events[0].as_text().replace(" - Physical", "").replace(" (Physical)", "") \
		.replace("Left Mouse Button", "LMB").replace("Right Mouse Button", "RMB")


## A weapon's name, or "Empty" for an empty slot.
static func weapon_name(weapon: WeaponData) -> String:
	return weapon.display_name if weapon else "Empty"


## Frees every child. They disappear at the end of the frame (queue_free), which is
## safe even when called from one of those children's own pressed signal.
static func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


## A label that uses one of the theme's label styles, like "WeaponNameLabel" or "KeyHintLabel".
## It ignores the mouse so it never blocks clicks or the scroll wheel.
static func make_label(text: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
