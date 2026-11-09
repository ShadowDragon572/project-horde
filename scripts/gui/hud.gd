## Wires the HUD pieces that need the player's hands and stances.
## Attach to the CanvasLayer in main.tscn.
extends CanvasLayer

# % unique names keep working even if these nodes get moved into a container later.
@onready var left_panel = %HandPanel
@onready var right_panel = %HandPanel2
@onready var quick_swap = %StanceQuickSwap
@onready var stance_editor = %StanceEditor
@onready var pause_menu = %PauseMenu
@onready var health_hud = $HealthHUD
@onready var upgrade_menu = $UpgradeMenu

func _ready() -> void:
	# The player lives in main_level.tscn, so find it by group instead of an export.
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("HUD: no node in group 'player'")
		return
	# Wait for the player if it isn't ready yet, so its stances exist.
	if not player.is_node_ready():
		await player.ready

	left_panel.bind(player.hand_left, player.stance_manager)
	right_panel.bind(player.hand_right, player.stance_manager)
	quick_swap.bind(player.stance_manager)
	stance_editor.bind(player.stance_manager)
	stance_editor.closed.connect(player.capture_mouse)
	stance_editor.opened.connect(_set_hud_hidden.bind(true, stance_editor))
	stance_editor.closed.connect(_set_hud_hidden.bind(false, stance_editor))
	pause_menu.opened.connect(_set_hud_hidden.bind(true, pause_menu))
	pause_menu.closed.connect(_set_hud_hidden.bind(false, pause_menu))
	upgrade_menu.opened.connect(_set_hud_hidden.bind(true, upgrade_menu))
	upgrade_menu.closed.connect(_set_hud_hidden.bind(false, upgrade_menu))
	# On death only the death screen stays (it lives in HealthHUD): no crosshair or ammo behind it.
	player.died.connect(_set_hud_hidden.bind(true, health_hud))


## Fades every other HUD piece out while a full-screen menu (`keep`) is open,
## so nothing shows through it.
## This uses modulate instead of visible on purpose: pieces like the left hand panel
## change their own visibility (two-handed stances), and closing the editor can do that
## right before we'd restore it. Turning modulate back to white can't undo their choice.
func _set_hud_hidden(hidden: bool, keep: CanvasItem) -> void:
	for child in get_children():
		if child != keep and child is CanvasItem:
			child.modulate.a = 0.0 if hidden else 1.0
