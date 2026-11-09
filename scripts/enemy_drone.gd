## Rolls at the player without stopping. Once close, it lights its fuse and sprints at them,
## exploding on contact or when the fuse runs out. It also explodes when shot.
## Everything else (chasing, jumping, health, the blink) comes from Enemy.
extends Enemy

@export_group("Sprint")
## Speed while the fuse is lit, as a multiple of `speed`. Sprinting starts at `lunge_range`.
@export var sprint_multiplier : float = 1.8
## How fast it can turn while sprinting, in degrees per second. Lower makes it easier to sidestep.
@export var sprint_turn_rate : float = 120.0
## Explodes as soon as the player is this close, even if the fuse hasn't run out.
@export var contact_range : float = 1.2

@export_group("Explosion")
## Anything within this distance takes damage.
@export var explosion_radius : float = 3.0
## Damage to the player.
@export var explosion_damage : int = 25
## Damage to other enemies caught in the blast.
@export var enemy_damage : int = 5
## Also explode when shot to death. The player gets the XP as usual.
@export var explode_when_shot : bool = true
## The effect spawned where it blew up.
@export var explosion_effect : PackedScene

@export_group("Wheels")
## How fast the wheel animation plays per m/s of rolling speed.
@export var wheel_spin : float = 3.0

var wheels : AnimationPlayer
## The way we're sprinting. Turns toward the player at most sprint_turn_rate per second.
var sprint_dir : Vector3 = Vector3.ZERO


func _ready() -> void:
	super()  # Run Enemy's _ready() first (health, target, hit flash...).
	# Smooth outline directions for the low-poly model, so the outline doesn't split.
	OutlineNormals.apply(visual)
	# The AnimationPlayer lives inside the instanced drone model, so a % unique name
	# from this scene can't reach it. Search for it instead.
	wheels = find_child("AnimationPlayer", true, false)
	if wheels:
		wheels.play("move")


func _physics_process(delta: float) -> void:
	super(delta)
	if is_dead or target.get("is_dead"):
		return

	if state == State.WINDUP and global_position.distance_to(target.global_position) <= contact_range:
		_explode()
		return

	if wheels:
		# Spin the wheels as fast as we're actually rolling, so they stop when we stop.
		var rolling_speed := Vector2(velocity.x, velocity.z).length()
		wheels.speed_scale = rolling_speed * wheel_spin


## Enemy calls this when the player gets within lunge_range. We light the fuse and start sprinting.
func _start_windup() -> void:
	super()
	sprint_dir = _flat_direction_to(target.global_position)
	speed_multiplier = sprint_multiplier


## Called every frame while the fuse burns. Instead of standing still, steer toward the player.
func _update_windup(delta: float) -> Vector3:
	if state_timer <= 0.0:
		_explode()
		return Vector3.ZERO

	# Turn toward the player, but only so fast. A sharp sidestep can still beat it.
	var wanted := _flat_direction_to(target.global_position)
	var angle := sprint_dir.signed_angle_to(wanted, Vector3.UP)
	var max_turn := deg_to_rad(sprint_turn_rate) * delta
	sprint_dir = sprint_dir.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn))
	_face(sprint_dir, delta)
	return sprint_dir


func take_damage(amount: int = 1) -> void:
	var was_dead := is_dead
	super(amount)  # Handles health, XP, `died` and queue_free().
	if is_dead and not was_dead and explode_when_shot:
		_blast()


## Fuse ran out or we touched the player: blow up.
## No XP: the player only gets rewarded for shooting it before it goes off.
func _explode() -> void:
	if is_dead:
		return
	is_dead = true
	_blast()
	died.emit()
	queue_free()


## Damage and effect only. Whoever calls this takes care of dying.
func _blast() -> void:
	if global_position.distance_to(target.global_position) <= explosion_radius:
		target.call("take_damage", explosion_damage)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.take_damage(enemy_damage)

	if explosion_effect:
		var effect = explosion_effect.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
