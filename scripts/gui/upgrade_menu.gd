extends Control

## hud.gd listens to these to fade the rest of the HUD out behind the cards.
signal opened
signal closed

const CARD_SIZE := Vector2(300, 240)
## Pause before the menu appears, so the bar can finish filling.
const SHOW_DELAY := 0.45
## Clicks are ignored this long after it appears, so you can't misclick while firing.
const INPUT_LOCK := 0.4

var player
var can_pick : bool = false
var title_label : Label
var cards_box : HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	hide()

	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("UpgradeMenu: no node in group 'player'")
		return
	player.upgrade_offered.connect(_on_upgrade_offered)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Esc used to quit the game here. It now does nothing: you have to pick an upgrade.
	if event is InputEventKey and event.pressed and not event.echo:
		var index := int(event.keycode) - KEY_1
		if index >= 0 and index < player.current_choices.size():
			_pick(index)


func _build_layout() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	# Text styles come from the theme (TitleLabel, KeyHintLabel...), like the rest of the HUD.
	title_label = _make_label("", &"TitleLabel")
	column.add_child(title_label)

	cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 20)
	column.add_child(cards_box)

	# Tells new players what this screen wants from them.
	column.add_child(_make_label("Pick an upgrade: click a card or press its number", &"KeyHintLabel"))


func _on_upgrade_offered(choices: Array) -> void:
	await get_tree().create_timer(SHOW_DELAY).timeout
	if player.is_dead:
		return
	_show_cards(choices)


func _show_cards(choices: Array) -> void:
	title_label.text = "Level %d" % player.level

	for old in cards_box.get_children():
		cards_box.remove_child(old)
		old.queue_free()

	for i in choices.size():
		var card := _make_card(i, choices[i])
		cards_box.add_child(card)
		_animate_card_in(card, i)

	show()
	get_tree().paused = true
	player.release_mouse()
	opened.emit()

	can_pick = false
	await get_tree().create_timer(INPUT_LOCK).timeout
	can_pick = true


func _make_card(index: int, upgrade: Dictionary) -> Button:
	var stacks: int = player.upgrade_stacks.get(upgrade["id"], 0)
	var stack_text := "NEW" if stacks == 0 else "Level %d → %d" % [stacks, stacks + 1]

	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.pivot_offset = CARD_SIZE / 2.0
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_pick.bind(index))
	card.mouse_entered.connect(_hover.bind(card, true))
	card.mouse_exited.connect(_hover.bind(card, false))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)

	# Same order as the other cards: name, then details, then a dim key hint.
	box.add_child(_make_label(upgrade["name"], &"WeaponNameLabel"))
	box.add_child(_make_label(upgrade["description"], &"BodyLabel", true))
	box.add_child(_make_label(stack_text, &"TagLabel"))
	box.add_child(_make_label("Press %d" % (index + 1), &"KeyHintLabel"))
	return card


## A centred label using one of the theme's text styles. `wrap` keeps long text inside the card.
func _make_label(content: String, variation: StringName, wrap := false) -> Label:
	var label := UIKit.make_label(content, variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = CARD_SIZE.x - 32.0
	return label


func _animate_card_in(card: Control, index: int) -> void:
	card.scale = Vector2(0.7, 0.7)
	card.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.25) \
		.set_delay(index * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(index * 0.08)


func _hover(card: Control, hovered: bool) -> void:
	var target := Vector2.ONE * (1.06 if hovered else 1.0)
	create_tween().tween_property(card, "scale", target, 0.1)


func _pick(index: int) -> void:
	if not visible or not can_pick:
		return

	hide()
	get_tree().paused = false
	player.capture_mouse()
	closed.emit()
	player.choose_upgrade(index)
