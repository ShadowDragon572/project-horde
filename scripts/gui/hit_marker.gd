extends Control

@export var color := Color.WHITE
@export var inner_gap := 6.0
@export var length := 14.0
@export var thickness := 2.0
@export var duration := 0.15

var tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate.a = 0.0

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.enemy_hit.connect(show_hit)
	else:
		push_warning("HitMarker: no node in group 'player' found.")

func _draw() -> void:
	for dir in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d: Vector2 = dir.normalized()
		draw_line(d * inner_gap, d * length, color, thickness)

func show_hit() -> void:
	if tween: tween.kill()
	self_modulate.a = 1.0
	scale = Vector2(1.4, 1.4)
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, duration)
	tween.tween_property(self, "self_modulate:a", 0.0, duration)
