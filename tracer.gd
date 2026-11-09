extends Node3D

@export var speed := 300.0
@export var max_streak_length := 3.0

@onready var streak: MeshInstance3D = $Streak

func fire(from: Vector3, to: Vector3) -> void:
	var distance := from.distance_to(to)
	if distance < 0.1:
		queue_free()
		return

	var length := minf(max_streak_length, distance)
	# Avoids a look_at error when shooting straight up or down
	var up := Vector3.FORWARD if absf((to - from).normalized().y) > 0.99 else Vector3.UP

	global_position = from
	look_at(to, up)
	streak.scale.z = length
	streak.position.z = length * 0.5  # tail trails behind the front

	var tween := create_tween()
	tween.tween_property(self, "global_position", to, distance / speed)
	tween.tween_property(streak, "scale", Vector3(0.0, 0.0, length), 0.05)
	tween.tween_callback(queue_free)
