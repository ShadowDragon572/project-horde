## The moment between waves:
## - a big "WAVE N COMPLETE" banner (with a sound and a soft flash) when a wave is cleared,
## - a smaller "WAVE N" banner when the next one starts,
## - the break prompt with the countdown and the loadout / ready keys.
## Finds the wave manager by its "wave_manager" group, like hud.gd finds the player.
extends Control

@export_group("Banner")
## Scale the text pops up from.
@export var start_scale : float = 0.3
## Final scale of the "WAVE N COMPLETE" text.
@export var complete_scale : float = 1.0
## Final scale of the smaller "WAVE N" text when a wave starts.
@export var wave_start_scale : float = 0.6
## Seconds for the pop-in (it overshoots a little, then settles).
@export var pop_time : float = 0.35
## Seconds the text stays up at full size.
@export var hold_time : float = 1.0
## Seconds for the fade out.
@export var fade_time : float = 0.5

@export_group("Wave Complete")
## Played when a wave is cleared. Leave empty for no sound.
@export var wave_complete_sound : AudioStream
## Peak alpha of the soft screen flash. 0 turns it off. Keep it low (0.1 to 0.15).
@export_range(0.0, 0.5) var flash_strength : float = 0.12
## Seconds for the flash to fade away.
@export var flash_time : float = 0.3

var _wave_manager
var _player
var _banner_tween : Tween
var _flash_tween : Tween
var _banner_busy : bool = false # True while "WAVE N COMPLETE" is up. The prompt waits for it.

@onready var banner : Label = %Banner
@onready var flash : ColorRect = %Flash
@onready var prompt : Control = %Prompt
@onready var prompt_label : Label = %PromptLabel
@onready var controls_card : Control = %ControlsCard
@onready var sound : AudioStreamPlayer = %Sound


func _ready() -> void:
	# Keep animating and reading keys while the tree is paused (stance editor, upgrade menu).
	# The scene also sets this, it's repeated here so it can't get lost.
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner.modulate.a = 0.0
	flash.color.a = 0.0
	prompt.hide()

	_player = get_tree().get_first_node_in_group("player")
	_wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if _wave_manager == null:
		push_error("WaveBanner: no node in group 'wave_manager'")
		return
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_cleared.connect(_on_wave_cleared)
	_wave_manager.countdown_changed.connect(_on_countdown_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_use_break_keys():
		return
	if event.is_action_pressed("open_loadout"):
		get_tree().call_group("stance_editor", "open")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ready_wave"):
		if _wave_manager.start_next_wave_now():
			get_viewport().set_input_as_handled()


## The break keys only work during a break, and not while something else has the screen:
## a paused tree (stance editor or upgrade menu), the Tab menu, or the death screen.
func _can_use_break_keys() -> bool:
	if _wave_manager == null or not _wave_manager.is_on_break():
		return false
	if get_tree().paused:
		return false
	if _player and (_player.is_dead or _player.stance_manager.ui_open):
		return false
	return true


# Wave events

func _on_wave_cleared(wave_number: int) -> void:
	_banner_busy = true
	prompt.hide()
	if wave_complete_sound:
		sound.stream = wave_complete_sound
		sound.play()
	_flash_screen()
	_show_banner("WAVE %d COMPLETE" % wave_number, complete_scale, _on_complete_banner_done)


func _on_complete_banner_done() -> void:
	_banner_busy = false
	prompt.visible = _wave_manager.is_on_break()


func _on_wave_started(wave_number: int) -> void:
	_banner_busy = false
	prompt.hide()
	controls_card.hide()
	_show_banner("WAVE %d" % wave_number, wave_start_scale)


func _on_countdown_changed(seconds_left: float) -> void:
	var loadout_key := UIKit.key_text("open_loadout")
	var ready_key := UIKit.key_text("ready_wave")
	if _wave_manager.waiting_for_ready:
		# Before wave 1 there's no clock: the run starts when the player is ready.
		prompt_label.text = "Press [%s] to start   ·   [%s] Change loadout" % [ready_key, loadout_key]
	else:
		prompt_label.text = "Next wave in %d   ·   [%s] Change loadout   ·   [%s] Ready" % [
			ceili(seconds_left), loadout_key, ready_key]
	prompt.visible = not _banner_busy and _wave_manager.is_on_break()
	# The controls card only shows during the first break, for new players.
	controls_card.visible = _wave_manager.waiting_for_ready


# Animation

## Pops the text in from small with a slight overshoot, holds it, then fades it out.
## Used for both banners; only the text and final size differ.
func _show_banner(text: String, target_scale: float, on_done: Callable = Callable()) -> void:
	if _banner_tween:
		_banner_tween.kill()
	banner.text = text
	banner.pivot_offset = banner.size / 2.0 # Grow from the middle, not the top-left corner.
	banner.scale = Vector2.ONE * start_scale
	banner.modulate.a = 0.0

	# ignore_time_scale: the Tab menu's slow motion must not stretch the banner.
	_banner_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE * target_scale, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, pop_time * 0.5)
	_banner_tween.chain().tween_interval(hold_time)
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, fade_time)
	if on_done.is_valid():
		_banner_tween.chain().tween_callback(on_done)


## A very soft full-screen flash that fades out quickly. flash_strength 0 turns it off.
func _flash_screen() -> void:
	if flash_strength <= 0.0:
		return
	if _flash_tween:
		_flash_tween.kill()
	flash.color.a = flash_strength
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(flash, "color:a", 0.0, flash_time)
