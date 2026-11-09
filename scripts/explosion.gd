## A low-poly explosion: flash, light, fireball, smoke, debris, camera shake and sound.
## Everything is built in code from the exports below, so the whole effect is tuned in one Inspector.
## Spawn it, set its position, and it plays once and frees itself.
extends Node3D
 
@export_group("Flash")
## A bright ball that pops out and fades in a blink. Hides the moment the drone disappears.
@export var flash_enabled : bool = true
@export var flash_color : Color = Color(1.0, 0.95, 0.75)
@export var flash_size : float = 2.2
@export var flash_duration : float = 0.12
 
@export_group("Light")
## A short burst of real light, so walls and the floor light up for a moment.
@export var light_enabled : bool = true
@export var light_color : Color = Color(1.0, 0.6, 0.25)
@export var light_energy : float = 6.0
@export var light_range : float = 8.0
@export var light_duration : float = 0.3
 
@export_group("Fireball")
@export var fireball_enabled : bool = true
@export var fireball_amount : int = 10
@export var fireball_lifetime : float = 0.45
## Size of each fire chunk at its biggest.
@export var fireball_size : float = 0.9
@export var fireball_speed : float = 3.0
## Hot to cold over each chunk's life. Leave empty for yellow > orange > dark red.
@export var fireball_colors : Gradient
 
@export_group("Smoke")
@export var smoke_enabled : bool = true
@export var smoke_amount : int = 6
@export var smoke_lifetime : float = 1.2
@export var smoke_size : float = 1.1
@export var smoke_speed : float = 1.2
## How fast the smoke drifts up, in m/s².
@export var smoke_rise : float = 1.5
@export var smoke_color : Color = Color(0.25, 0.25, 0.25, 0.8)
 
@export_group("Debris")
@export var debris_enabled : bool = true
@export var debris_amount : int = 8
@export var debris_lifetime : float = 1.0
@export var debris_size : float = 0.15
@export var debris_speed : float = 7.0
@export var debris_gravity : float = 20.0
@export var debris_color : Color = Color(0.2, 0.22, 0.2)
 
@export_group("Camera Shake")
@export var shake_enabled : bool = true
## How hard it shakes if the player is standing right on top of it. 0 to 1.
@export_range(0.0, 1.0) var shake_trauma : float = 0.6
## No shake past this distance. Fades out in between.
@export var shake_radius : float = 12.0
 
@export_group("Sound")
## Leave empty for no sound.
@export var sound : AudioStream
@export var sound_volume_db : float = 0.0
## Random pitch change, so repeated explosions don't sound identical.
@export_range(0.0, 0.5) var pitch_variation : float = 0.1
 
 
func _ready() -> void:
	# Whoever spawns us sets our position right after add_child(), which is after _ready().
	# Waiting until the end of the frame means everything starts in the right spot.
	_play.call_deferred()
 
 
func _play() -> void:
	var longest := 0.0
	if fireball_colors == null:
		fireball_colors = _default_fire_colors()
 
	if flash_enabled:
		_spawn_flash()
		longest = maxf(longest, flash_duration)
	if light_enabled:
		_spawn_light()
		longest = maxf(longest, light_duration)
	if fireball_enabled:
		_spawn_particles(fireball_amount, fireball_lifetime, fireball_size, fireball_speed,
				Vector3.ZERO, _sphere_mesh(), fireball_colors, false)
		longest = maxf(longest, fireball_lifetime)
	if smoke_enabled:
		var fade := Gradient.new()
		fade.set_color(0, smoke_color)
		fade.set_color(1, Color(smoke_color, 0.0))
		_spawn_particles(smoke_amount, smoke_lifetime, smoke_size, smoke_speed,
				Vector3.UP * smoke_rise, _sphere_mesh(), fade, true)
		longest = maxf(longest, smoke_lifetime)
	if debris_enabled:
		var solid := Gradient.new()
		solid.set_color(0, debris_color)
		solid.set_color(1, debris_color)
		var debris := _spawn_particles(debris_amount, debris_lifetime, debris_size, debris_speed,
				Vector3.DOWN * debris_gravity, BoxMesh.new(), solid, false)
		debris.scale_amount_curve = null  # Chunks keep their size instead of shrinking away.
		debris.angular_velocity_min = -720.0
		debris.angular_velocity_max = 720.0
		longest = maxf(longest, debris_lifetime)
	if shake_enabled:
		_shake_camera()
	if sound:
		_play_sound()
		longest = maxf(longest, sound.get_length())
 
	# Everything is one-shot, so clean up once the slowest part is done.
	get_tree().create_timer(longest + 0.2).timeout.connect(queue_free)
 
 
func _spawn_flash() -> void:
	var material := _unshaded_material(true)
	material.albedo_color = flash_color
	var mesh := _sphere_mesh()
	mesh.material = material
 
	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	ball.scale = Vector3.ONE * flash_size * 0.3 # start at 30% so effect is more noticable
	add_child(ball)
 
	var tween := create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * flash_size, flash_duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, flash_duration)
 
 
func _spawn_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = light_range
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, light_duration)
 
 
## One burst of low-poly chunks. `colors` runs from birth (left) to death (right).
func _spawn_particles(amount: int, lifetime: float, size: float, speed: float, gravity: Vector3,
		mesh: PrimitiveMesh, colors: Gradient, transparent: bool) -> CPUParticles3D:
	mesh.material = _unshaded_material(transparent)
	# Vertex color carries the gradient color into the material.
	(mesh.material as StandardMaterial3D).vertex_color_use_as_albedo = true
 
	var particles := CPUParticles3D.new()
	particles.mesh = mesh
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0  # All at once, not a stream.
	particles.direction = Vector3.UP
	particles.spread = 180.0  # Every direction.
	particles.gravity = gravity
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.damping_min = speed * 0.5  # Burst out fast, then slow down.
	particles.damping_max = speed
	particles.scale_amount_min = size * 0.6
	particles.scale_amount_max = size
	particles.scale_amount_curve = _grow_then_shrink()
	particles.color_ramp = colors
	add_child(particles)
	particles.emitting = true
	return particles
 
 
func _shake_camera() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var closeness := 1.0 - global_position.distance_to(player.global_position) / shake_radius
	if closeness > 0.0:
		get_tree().call_group("camera_shake", "add_trauma", shake_trauma * closeness)
 
 
func _play_sound() -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.bus = &"SFX"
	player.volume_db = sound_volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	add_child(player)
	player.play()
 
 
# Building blocks
 
## A chunky sphere: 6 sides and 3 rings, so it reads as low poly.
func _sphere_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.radius = 0.5
	mesh.height = 1.0
	return mesh
 
 
## Creates an unshaded material for flash and particle effects. 
## Flat color, no lighting. Fire and flashes give off light, they shouldn't be shaded by it.
func _unshaded_material(transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
 
 
## Particles pop up to full size fast, then shrink to nothing.
func _grow_then_shrink() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
 
 
func _default_fire_colors() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.6))    # White-hot yellow
	gradient.set_color(1, Color(0.35, 0.08, 0.02))  # Dark red, about to vanish
	gradient.add_point(0.3, Color(1.0, 0.55, 0.1))  # Orange
	return gradient
 
