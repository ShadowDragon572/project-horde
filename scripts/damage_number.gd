extends Label3D

@export var rise_height := 1.2
@export var duration := 0.7

func setup(amount: int, color: Color = Color.WHITE) -> void:
	text = str(amount)
	modulate = color
	scale = Vector3.ONE * 0.5
	
	# Random horizontal offset so rapid hits don't stack perfectly
	global_position += Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	
	var tween := create_tween().set_parallel(true)
	# Pop in, then settle
	tween.tween_property(self, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Float upward
	tween.tween_property(self, "global_position:y", global_position.y + rise_height, duration).set_ease(Tween.EASE_OUT)
	# Fade out over the second half
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(queue_free)
