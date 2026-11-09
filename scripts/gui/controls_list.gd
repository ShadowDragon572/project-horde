## A two-column list of every control: what it does, and which key does it.
## Used by the pause menu and the first-break controls card, so the list lives in one place.
## Keys come from the Input Map (UIKit.key_text), so rebinding updates the list.
extends GridContainer


func _ready() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 32)
	add_theme_constant_override("v_separation", 2) # Tight, so the first-break card fits above the health bar.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()


## Rebuilds the rows. Call again if keys are rebound while the game runs.
func refresh() -> void:
	UIKit.clear_children(self)
	var move := "%s %s %s %s" % [UIKit.key_text("input_forward"), UIKit.key_text("input_left"),
		UIKit.key_text("input_back"), UIKit.key_text("input_right")]
	var rows := [
		["Move", move],
		["Look", "Mouse"],
		# Jump uses Godot's built-in "ui_accept", whose first key is Enter, so name Space directly.
		["Jump", "Space"],
		["Sprint", UIKit.key_text("sprint")],
		["Crouch", UIKit.key_text("crouch")],
		["Fire left / right hand", "%s / %s" % [UIKit.key_text("fire_left"), UIKit.key_text("fire_right")]],
		["Reload left / right hand", "%s / %s" % [UIKit.key_text("reload_left"), UIKit.key_text("reload_right")]],
		["Next stance", UIKit.key_text("stance_swap")],
		["Stance menu (hold)", UIKit.key_text("stance_menu")],
		["Change loadout (between waves)", UIKit.key_text("open_loadout")],
		["Ready for next wave", UIKit.key_text("ready_wave")],
		["Pause", "Esc"],
	]
	for row in rows:
		add_child(UIKit.make_label(row[0], &"KeyHintLabel"))
		var key := UIKit.make_label(row[1])
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(key)
