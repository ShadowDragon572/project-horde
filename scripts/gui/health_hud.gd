## The health bar at bottom centre, the red screen flash, and the game over screen.
## The bar shows "85 / 100". On a hit it tints and shakes, and a pale "chip" bar
## behind it keeps showing the health you just lost, then catches up.
extends Control

const HEALTHY_COLOR := Color(0.3, 0.85, 0.35)
const LOW_COLOR := Color(0.9, 0.2, 0.2)

@export_group("Hit Effect")
## How far the bar jumps around when you're hit, in pixels.
@export var shake_strength : float = 6.0
## Seconds the shake lasts.
@export var shake_time : float = 0.25
## The bar's tint right after a hit. It fades back to normal over flash_time.
@export var hit_tint : Color = Color(1.0, 0.45, 0.45)
## Seconds for the hit tint to fade.
@export var flash_time : float = 0.3

@export_group("Damage Chip")
## Seconds the chip waits before it starts catching up.
@export var chip_delay : float = 0.5
## How fast the chip catches up, in full bars per second. 1.5 drains a full bar in about 0.7 s.
@export var chip_speed : float = 1.5

@export_group("Healing")
## Seconds for the bar to fill up when you heal.
@export var heal_time : float = 0.35

var last_health : int = -1
var fill_style : StyleBoxFlat
var bar_tween : Tween
var chip_tween : Tween
var hit_tween : Tween
var flash_tween : Tween
var _box_rest_position : Vector2

@onready var health_box : Control = %HealthBox
@onready var health_bar : ProgressBar = %HealthBar
@onready var chip_bar : ProgressBar = %ChipBar
@onready var health_label : Label = %HealthLabel
@onready var damage_flash : ColorRect = %DamageFlash
@onready var game_over : Control = %GameOver
@onready var restart_button : Button = %RestartButton
@onready var quit_button : Button = %QuitButton
@onready var summary_label : Label = %SummaryLabel
@onready var stamina_bar : Control = %StaminaBar

var _player


func _ready() -> void:
	game_over.hide()
	damage_flash.color.a = 0.0
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	quit_button.pressed.connect(func(): get_tree().quit())

	# Our own copy of the fill style, so recoloring it doesn't recolor every bar in the theme.
	fill_style = health_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	health_bar.add_theme_stylebox_override("fill", fill_style)

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("HealthHUD: no node in group 'player'")
		return
	_player = player

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	_on_health_changed(player.health, player.max_health)


## Runs for damage, healing and max health changes (the Vitality upgrade).
func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	chip_bar.max_value = maximum
	health_label.text = "%d / %d" % [current, maximum]
	fill_style.bg_color = LOW_COLOR.lerp(HEALTHY_COLOR, float(current) / maximum)

	if last_health < 0:
		# First update: just show it, no animation.
		health_bar.value = current
		chip_bar.value = current
	elif current < last_health:
		_on_damaged(current)
	else:
		_on_healed(current)
	last_health = current


func _on_damaged(current: int) -> void:
	if bar_tween:
		bar_tween.kill()
	if chip_tween:
		chip_tween.kill()
	# The main bar drops at once, and the chip behind it shows how much was lost.
	health_bar.value = current
	var lost := chip_bar.value - current
	if lost <= 0.0:
		chip_bar.value = current
	else:
		chip_tween = _ui_tween()
		chip_tween.tween_interval(chip_delay)
		chip_tween.tween_property(chip_bar, "value", current, lost / (chip_bar.max_value * chip_speed))
	_play_hit_effect()
	_flash_damage()


func _on_healed(current: int) -> void:
	if bar_tween:
		bar_tween.kill()
	if chip_tween:
		chip_tween.kill()
	# No hit effect here. Both bars slide to the new value together.
	bar_tween = _ui_tween().set_parallel(true)
	bar_tween.tween_property(health_bar, "value", current, heal_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar_tween.tween_property(chip_bar, "value", current, heal_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Tints the bar and shakes it, then puts it back exactly where it was.
func _play_hit_effect() -> void:
	if hit_tween and hit_tween.is_running():
		hit_tween.kill()
	else:
		# Only remember the rest spot when not mid-shake, or we'd remember a shaken spot.
		_box_rest_position = health_box.position
	health_bar.self_modulate = hit_tint
	hit_tween = _ui_tween().set_parallel(true)
	hit_tween.tween_property(health_bar, "self_modulate", Color.WHITE, flash_time)
	hit_tween.tween_method(_shake, shake_strength, 0.0, shake_time)
	hit_tween.chain().tween_callback(func(): health_box.position = _box_rest_position)


func _shake(strength: float) -> void:
	health_box.position = _box_rest_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength


func _flash_damage() -> void:
	if flash_tween:
		flash_tween.kill()
	damage_flash.color.a = 0.35
	flash_tween = create_tween()
	flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.4)


## HUD tweens ignore Engine.time_scale, so the Tab menu's slow motion doesn't slow them down.
func _ui_tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


## The death screen: a short summary of the run, Restart and Quit.
## hud.gd fades the rest of the HUD out; the empty bars are hidden here.
func _on_player_died() -> void:
	health_box.hide()
	stamina_bar.hide()
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	var parts := PackedStringArray()
	if wave_manager:
		if wave_manager.current_wave > 0:
			parts.append("Reached wave %d" % wave_manager.current_wave)
		else:
			parts.append("Fell before the first wave")
	parts.append("Level %d" % _player.level)
	if wave_manager:
		var count : int = wave_manager.enemies_defeated
		parts.append("%d %s defeated" % [count, "enemy" if count == 1 else "enemies"])
	summary_label.text = "   ·   ".join(parts)
	game_over.show()
