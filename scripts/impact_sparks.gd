extends CPUParticles3D

@export var spark_size := Vector3(0.03, 0.2, 0.03)

var spark_material := StandardMaterial3D.new()


func _ready() -> void:
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.emission_enabled = true
	spark_material.emission_energy_multiplier = 4.0

	var spark_mesh := BoxMesh.new()
	spark_mesh.size = spark_size
	spark_mesh.material = spark_material

	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))

	mesh = spark_mesh
	scale_amount_curve = shrink
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	emitting = false
	one_shot = true
	explosiveness = 1.0
	amount = 20
	lifetime = 0.5
	lifetime_randomness = 0.3
	local_coords = false

	direction = Vector3(0, 0, -1)
	spread = 45.0
	initial_velocity_min = 4.0
	initial_velocity_max = 8.0
	damping_min = 2.0
	damping_max = 4.0
	gravity = Vector3(0, -12.0, 0)
	particle_flag_align_y = true

	finished.connect(queue_free)


func burst(point: Vector3, normal: Vector3, tint: Color) -> void:
	spark_material.albedo_color = tint
	spark_material.emission = tint

	global_position = point + normal * 0.02
	var up := Vector3.RIGHT if absf(normal.y) > 0.99 else Vector3.UP
	look_at(global_position + normal, up)

	restart()
