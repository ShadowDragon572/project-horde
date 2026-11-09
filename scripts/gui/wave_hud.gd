## The small wave panel at the top centre: "Wave 2  ·  4 enemies left".
## The countdown between waves lives in the break prompt (wave_banner.gd), not here.
extends Control

@onready var wave_label: Label = %WaveLabel
@onready var enemies_label: Label = %EnemiesLabel

func _ready() -> void:
	# Before wave 1 there's no wave yet, so say which one is coming.
	wave_label.text = "Wave 1 incoming"
	enemies_label.hide()

	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager == null:
		push_error("WaveHUD: no WaveManager found in group 'wave_manager'")
		return

	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	wave_manager.enemies_left_changed.connect(_on_enemies_left_changed)

func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave %d" % wave_number
	enemies_label.show()

func _on_wave_cleared(wave_number: int) -> void:
	wave_label.text = "Wave %d cleared" % wave_number
	enemies_label.hide()

func _on_enemies_left_changed(count: int) -> void:
	enemies_label.text = "·   %d %s left" % [count, "enemy" if count == 1 else "enemies"]
