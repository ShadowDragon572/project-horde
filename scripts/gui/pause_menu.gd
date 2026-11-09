## Esc opens this instead of quitting: Resume, Controls, Quit.
## It pauses the tree, so the wave countdown and enemies stop too.
## Esc is ignored while another screen already owns the game (stance editor, upgrade
## menu, Tab menu, death screen); those handle Esc themselves or don't need it.
extends Control

## hud.gd listens to these to fade the rest of the HUD out behind the menu.
signal opened
signal closed

var _player

@onready var main_buttons : Control = %MainButtons
@onready var controls_box : Control = %ControlsBox
@onready var controls_list = %ControlsList
@onready var title : Label = %Title


func _ready() -> void:
	# Keep running while the tree is paused, or we couldn't unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	%ResumeButton.pressed.connect(resume)
	%ControlsButton.pressed.connect(_show_controls.bind(true))
	%BackButton.pressed.connect(_show_controls.bind(false))
	%QuitButton.pressed.connect(func(): get_tree().quit())
	_player = get_tree().get_first_node_in_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		# Esc backs out of the controls page first, then resumes.
		if controls_box.visible:
			_show_controls(false)
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif _can_pause():
		pause()
		get_viewport().set_input_as_handled()


## Something else already has the screen if the tree is paused (stance editor,
## upgrade menu), the Tab menu is open, or the player is dead.
func _can_pause() -> bool:
	if get_tree().paused:
		return false
	if _player and (_player.is_dead or _player.stance_manager.ui_open):
		return false
	return true


func pause() -> void:
	_show_controls(false)
	show()
	get_tree().paused = true
	if _player:
		_player.release_mouse()
	opened.emit()


func resume() -> void:
	hide()
	get_tree().paused = false
	if _player:
		_player.capture_mouse()
	closed.emit()


func _show_controls(on: bool) -> void:
	main_buttons.visible = not on
	controls_box.visible = on
	title.text = "Controls" if on else "Paused"
	if on:
		controls_list.refresh()
