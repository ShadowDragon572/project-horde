## The XP bar at the very bottom, with "LV N" written on it.
## Built in code. The health and stamina bars in main.tscn sit above it at the same width,
## so if you change bar_width or bar_height here, move HealthBox and StaminaBar to match.
extends Control

## Fill color of the XP bar.
@export var bar_color : Color = Color(0.35, 0.85, 1.0)
@export var bar_width : float = 400.0
## Tall enough to fit the "LV N" text on the bar.
@export var bar_height : float = 22.0
@export var bottom_margin : float = 14.0

var last_level : int = 0
var bar_tween : Tween
var pulse_tween : Tween

var bar : ProgressBar
var level_label : Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("XPHUD: no node in group 'player'")
		return
	player.xp_changed.connect(_on_xp_changed)
	_on_xp_changed(player.xp, player.xp_needed, player.level)

func _build_ui() -> void:
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	# The track comes from the theme (same as the health bar). Only the fill color is ours,
	# so copy the theme's fill (keeps its rounded corners) and recolor the copy.
	var fill := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", fill)
	_place_bottom_center(bar, bar_height + bottom_margin, bottom_margin)
	bar.pivot_offset = Vector2(bar_width, bar_height) / 2.0

	# "LV N" sits on top of the bar, the same way "85 / 100" sits on the health bar.
	level_label = UIKit.make_label("", &"BarValueLabel")
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(level_label)
	# 4 px taller than the bar on each side, so the text (outline included) never gets squeezed.
	_place_bottom_center(level_label, bar_height + bottom_margin + 4.0, bottom_margin - 4.0)
	level_label.pivot_offset = Vector2(bar_width, bar_height + 8.0) / 2.0


func _place_bottom_center(control: Control, top_from_bottom: float, bottom_from_bottom: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	control.offset_left = -bar_width / 2.0
	control.offset_right = bar_width / 2.0
	control.offset_top = -top_from_bottom
	control.offset_bottom = -bottom_from_bottom


func _on_xp_changed(current: int, needed: int, level: int) -> void:
	level_label.text = "LV %d" % level

	if last_level == 0:
		last_level = level
		bar.max_value = needed
		bar.value = current
		return

	var leveled_up := level > last_level
	last_level = level

	if bar_tween:
		bar_tween.kill()
	bar_tween = create_tween()

	if leveled_up:
		bar_tween.tween_property(bar, "value", bar.max_value, 0.15)
		bar_tween.tween_callback(_roll_over.bind(needed))
	else:
		bar.max_value = needed

	bar_tween.tween_property(bar, "value", float(current), 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_pulse(leveled_up)


func _roll_over(needed: int) -> void:
	bar.max_value = needed
	bar.value = 0.0


func _pulse(strong: bool) -> void:
	if pulse_tween:
		pulse_tween.kill()

	bar.scale = Vector2(1.03, 1.9 if strong else 1.5)
	bar.modulate = Color(2.0, 2.0, 2.0) if strong else Color(1.5, 1.5, 1.5)
	if strong:
		level_label.scale = Vector2(1.6, 1.6)

	pulse_tween = create_tween().set_parallel(true)
	pulse_tween.tween_property(bar, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(bar, "modulate", Color.WHITE, 0.25)
	pulse_tween.tween_property(level_label, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
