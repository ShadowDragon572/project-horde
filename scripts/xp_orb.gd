extends Node3D

enum State { DROPPING, IDLE, ATTRACTING, COLLECTED }

@export var xp_value : int = 2
@export var color : Color = Color(0.4, 0.9, 1.0)
@export var radius : float = 0.14

@export_group("Drop")
## Layers that count as floor when the orb lands (your level geometry).
@export_flags_3d_physics var floor_mask : int = 1
@export var hover_height : float = 0.6
@export var bob_height : float = 0.08

@export_group("Magnet")
@export var magnet_radius : float = 6.0
@export var collect_radius : float = 0.8
## Small backward recoil right before the orb launches at you.
@export var windup_speed : float = 5.0
@export var acceleration : float = 70.0
@export var max_speed : float = 32.0
## Aim point relative to the player's origin.
@export var target_offset : Vector3 = Vector3(0, 0.4, 0)

var state : State = State.DROPPING
var speed : float = 0.0
var rest_y : float = 0.0
var bob_time : float = 0.0

var player : Node3D
var orb_mesh : MeshInstance3D
var orb_material : StandardMaterial3D
var glow_light : OmniLight3D
var trail : CPUParticles3D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	bob_time = randf() * TAU
	_build_visuals()


func drop_from(origin: Vector3) -> void:
	var landing := origin + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
	var ray_start := landing + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(
		ray_start, ray_start + Vector3.DOWN * 30.0, floor_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		landing = hit["position"] + Vector3.UP * hover_height

	global_position = origin
	rest_y = landing.y

	scale = Vector3.ZERO
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tween := create_tween()
	tween.tween_method(_drop_step.bind(origin, landing), 0.0, 1.0, 0.5)
	tween.tween_callback(_on_landed)


func _drop_step(t: float, start: Vector3, rest: Vector3) -> void:
	var pos := start.lerp(rest, t)
	pos.y += sin(t * PI) * 0.6
	global_position = pos


func _on_landed() -> void:
	state = State.IDLE


func _physics_process(delta: float) -> void:
	if state == State.DROPPING or state == State.COLLECTED:
		return
	if not is_instance_valid(player):
		return

	var target := player.global_position + target_offset
	if state == State.IDLE:
		_idle(delta, target)
	else:
		_attract(delta, target)


func _idle(delta: float, target: Vector3) -> void:
	bob_time += delta * 3.0
	global_position.y = rest_y + sin(bob_time) * bob_height

	if player.get("is_dead"):
		return
	if global_position.distance_to(target) <= magnet_radius:
		_start_attract()


func _start_attract() -> void:
	state = State.ATTRACTING
	speed = -windup_speed
	trail.emitting = true

	var tween := create_tween()
	tween.tween_property(orb_mesh, "scale", Vector3.ONE * 1.5, 0.08)
	tween.tween_property(orb_mesh, "scale", Vector3.ONE, 0.1)


func _attract(delta: float, target: Vector3) -> void:
	speed = minf(speed + acceleration * delta, max_speed)

	var offset := target - global_position
	var distance := offset.length()
	if distance <= collect_radius:
		_collect()
		return

	global_position += offset / distance * minf(speed * delta, distance)
	scale = Vector3.ONE * clampf(distance / 3.0, 0.4, 1.0)


func _collect() -> void:
	state = State.COLLECTED
	trail.emitting = false
	player.collect_xp(xp_value)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(orb_mesh, "scale", Vector3.ONE * 2.5, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(orb_material, "albedo_color:a", 0.0, 0.15)
	tween.tween_property(glow_light, "light_energy", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


func _build_visuals() -> void:
	orb_material = StandardMaterial3D.new()
	orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_material.albedo_color = color
	orb_material.emission_enabled = true
	orb_material.emission = color
	orb_material.emission_energy_multiplier = 3.0

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = orb_material

	orb_mesh = MeshInstance3D.new()
	orb_mesh.mesh = sphere
	orb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb_mesh)

	glow_light = OmniLight3D.new()
	glow_light.light_color = color
	glow_light.light_energy = 1.5
	glow_light.omni_range = 3.0
	glow_light.shadow_enabled = false
	add_child(glow_light)

	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = radius * 0.4
	trail_mesh.height = radius * 0.8
	trail_mesh.radial_segments = 8
	trail_mesh.rings = 4
	trail_mesh.material = orb_material

	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))

	trail = CPUParticles3D.new()
	trail.mesh = trail_mesh
	trail.emitting = false
	trail.amount = 40
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.0
	trail.scale_amount_curve = shrink
	add_child(trail)
