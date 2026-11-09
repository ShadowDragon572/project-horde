extends Area3D

signal hit_enemy

@export var direction: Vector3

var speed = 50

func _ready() -> void:
	_self_destruction()

func _self_destruction():
	get_tree().create_timer(2).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not direction: return
	global_position += direction * speed * delta

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(1)
		hit_enemy.emit()
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		hit_enemy.emit()
	queue_free()
	
	
