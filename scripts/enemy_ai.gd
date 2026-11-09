class_name Enemy
extends CharacterBody3D
 
signal died
 
const DAMAGE_NUMBER = preload("uid://dyfqlxl0uljbb")
const XP_ORB = preload("res://scenes/xp_orb.tscn")
 
## What the enemy is doing right now. Each state has its own rules for moving and attacking.
enum State { CHASE, WINDUP, LUNGE, RECOVER }
 
@export_group("Health")
@export var max_health : int = 3
 
@export_group("Rewards")
@export var xp_value : int = 2
 
@export_group("Attack")
## Start winding up once the player is this close (flat distance, ignoring height).
@export var lunge_range : float = 4.0
## During the lunge, the player gets hit if they're this close to the enemy's center.
@export var hit_range : float = 1.6
## Don't wind up if the player is this much higher or lower than us.
@export var max_height_difference : float = 1.5
## The enemy stops moving closer than this.
@export var stop_distance : float = 1.4
@export var attack_damage : int = 10
## How long the enemy stands still and telegraphs before lunging.
@export var windup_time : float = 0.45
## Speed of the lunge itself.
@export var lunge_speed : float = 14.0
## How long the lunge lasts. Distance covered is about lunge_speed * lunge_time.
@export var lunge_time : float = 0.25
## Pause after a lunge. This is the player's window to hit back.
@export var recover_time : float = 0.6
 
@export_group("Windup Tell")
## How far the body tilts back during the windup, in degrees.
@export var lean_angle : float = 25.0
## Color pulsed over the body while winding up.
@export var windup_color : Color = Color(1.0, 0.3, 0.1)
## How many times the color blinks during the windup. 1 is a single ramp up.
@export var windup_blinks : int = 1
 
@export_group("Sounds")
## Plays once when the windup starts (a growl or charge-up). Optional.
@export var windup_sound : AudioStream
## Plays on every blink of the windup (the drone's beeps). Optional.
@export var blink_sound : AudioStream
## Each blink plays this much higher than the last, so the beeping builds tension. 0 keeps it flat.
@export var blink_pitch_rise : float = 0.08
## Plays when the lunge starts (a whoosh). Optional.
@export var lunge_sound : AudioStream
@export var sound_volume_db : float = 0.0
## Base pitch for all of this enemy's sounds. Lower sounds bigger (tank), higher sounds smaller (fast).
@export var sound_pitch : float = 1.0
## Random pitch change, so a crowd of the same enemy doesn't sound robotic.
@export_range(0.0, 0.5) var pitch_variation : float = 0.08
 
@export_group("Movement")
@export var speed : float = 6.0
## How quickly we reach full speed on the ground (m/s gained per second).
@export var ground_acceleration : float = 40.0
## How quickly we stop on the ground.
@export var ground_deceleration : float = 40.0
## Share of ground control we keep in the air. 0 is none, 1 is full.
@export_range(0.0, 1.0) var air_control : float = 0.3
## Only re-path when the player's ground spot moved at least this far. Saves work with big hordes.
@export var repath_distance : float = 0.5
## How quickly the body turns to face where it's going. Higher is snappier.
@export var turn_speed : float = 10.0
 
@export_group("Gravity")
## Same values as the player so enemies fall and jump with the same feel.
@export var gravity_scale : float = 1.5
@export var fall_gravity_multiplier : float = 1.6
@export var gravity_growth : float = 2.5
@export var max_gravity_multiplier : float = 2.5
@export var terminal_velocity : float = 40.0
## Falling below this height counts as dying, so a lost enemy can't hold up the wave.
@export var kill_height : float = -50.0
 
@export_group("Jumping")
## Tallest ledge the enemy will try to jump onto, in meters.
@export var max_jump_height : float = 1.5
## Extra height above the ledge so the capsule clears the lip.
@export var jump_clearance : float = 0.3
## Seconds between jumps, so a blocked enemy doesn't bunny-hop forever.
@export var jump_cooldown : float = 0.6
## How far ahead to look for the top of a ledge.
@export var ledge_check_distance : float = 0.8
## Physics layers that count as level geometry (floors, walls, stairs).
@export_flags_3d_physics var ground_mask : int = 1
 
@export_group("Shortcuts")
## Take the direct route when the walking path is this many times longer than a straight line.
@export var shortcut_ratio : float = 1.5
## Only consider shortcuts to a player within this many meters (horizontally).
@export var shortcut_max_distance : float = 10.0
## Once a shortcut is chosen, stick with it this long so the enemy doesn't flip-flop.
@export var shortcut_commit_time : float = 0.4

@export_group("Getting Unstuck")
## Trying to move for this long without getting anywhere counts as stuck.
@export var stuck_time : float = 3.0
## Moving less than this many meters during stuck_time counts as "not getting anywhere".
@export var stuck_distance : float = 0.5
## Off the floor this long without actually falling means we're wedged on something
## round, like the gap between barrels. (We can only jump from the floor, so we'd never get out.)
@export var wedged_time : float = 1.5
## Farther than this from the navmesh counts as somewhere enemies shouldn't be
## (like on top of a barrel), so getting unstuck moves us back down instead of hopping.
@export var off_navmesh_distance : float = 1.5

var health : int = 3
var is_dead : bool = false
var fall_time : float = 0.0
var jump_timer : float = 0.0
var shortcut_timer : float = 0.0
var is_shortcutting : bool = false
var stuck_timer : float = 0.0
var wedged_timer : float = 0.0
## Where we were when stuck_timer last reset. Progress is measured from here.
var stuck_anchor : Vector3

var state : State = State.CHASE
## Counts down the time left in the current state (windup, lunge, recover).
var state_timer : float = 0.0
## Locked in when the lunge starts, so the player can sidestep it.
var lunge_dir : Vector3 = Vector3.ZERO
## Only one hit per lunge.
var has_hit : bool = false
## Scales `speed` while moving. Subclasses use it to sprint (the drone) without changing `speed` itself.
var speed_multiplier : float = 1.0
 
var target : Node3D
var flash_material : StandardMaterial3D
var flash_tween : Tween
var lean_tween : Tween
## Plays this enemy's sounds from its position. Made in code, so no scene changes are needed.
var sfx : AudioStreamPlayer3D
 
@onready var navigation_agent_3d: NavigationAgent3D = %NavigationAgent3D
## Everything you can see. We tilt this for the lean, so the collision shape stays upright.
@onready var visual: Node3D = %Visual
 
 
func _ready() -> void:
	health = max_health
	add_to_group("enemies")  # Lets explosions find every enemy.
	target = get_tree().get_first_node_in_group("player")
	navigation_agent_3d.link_reached.connect(_on_link_reached)
	_setup_hit_flash()
	sfx = AudioStreamPlayer3D.new()
	sfx.max_polyphony = 2  # A beep can start before the previous one ends.
	sfx.bus = &"SFX"  # Runs through the lo-fi filter. Falls back to Master if there's no SFX bus.
	add_child(sfx)
 
 
func _physics_process(delta: float) -> void:
	if global_position.y < kill_height and not is_dead:
		is_dead = true
		died.emit()
		queue_free()
		return
 
	if target.get("is_dead"):
		return
 
	jump_timer -= delta
	shortcut_timer -= delta
	state_timer -= delta
	_apply_gravity(delta)
 
	var move_dir := Vector3.ZERO
	match state:
		State.CHASE:
			move_dir = _update_chase(delta)
		State.WINDUP:
			move_dir = _update_windup(delta)
		State.LUNGE:
			_update_lunge()
		State.RECOVER:
			if state_timer <= 0.0:
				state = State.CHASE
 
	# The lunge sets its own velocity. Every other state steers with acceleration,
	# so WINDUP and RECOVER (move_dir is zero) slide to a stop instead of freezing.
	if state != State.LUNGE:
		_apply_movement(move_dir, delta)
		_try_ledge_jump(move_dir)
		_check_stuck(move_dir, delta)
	move_and_slide()
 
 
# States
 
func _update_chase(delta: float) -> Vector3:
	if _can_start_windup():
		_start_windup()
		return Vector3.ZERO
 
	if global_position.distance_to(target.global_position) <= stop_distance:
		_face(_flat_direction_to(target.global_position), delta)
		return Vector3.ZERO
 
	var dir := _get_chase_direction()
	_face(dir, delta)
	return dir
 
 
func _can_start_windup() -> bool:
	if not is_on_floor():
		return false
 
	var to_player := target.global_position - global_position
	if absf(to_player.y) > max_height_difference:
		return false
	to_player.y = 0.0
	if to_player.length() > lunge_range:
		return false
 
	# Don't lunge into a wall the player is standing behind.
	var query := PhysicsRayQueryParameters3D.create(global_position, target.global_position, ground_mask)
	query.exclude = [get_rid(), (target as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
 
 
func _start_windup() -> void:
	state = State.WINDUP
	state_timer = windup_time
	_play_windup_tell()
 
 
## Returns the direction to move in during the windup. Standing still here, but the drone overrides it.
func _update_windup(delta: float) -> Vector3:
	# Keep turning toward the player so the lunge looks aimed.
	_face(_flat_direction_to(target.global_position), delta)
	if state_timer <= 0.0:
		_release_attack()
	return Vector3.ZERO
 
 
## Called when the windup ends. Other enemy types (like the drone) override this.
func _release_attack() -> void:
	state = State.LUNGE
	state_timer = lunge_time
	has_hit = false
	# Lock the direction now. Once it's committed, the player can sidestep it.
	lunge_dir = _flat_direction_to(target.global_position)
	_tween_lean(-deg_to_rad(lean_angle) * 0.5, 0.08)  # Snap forward into the lunge.
	_play_sound(lunge_sound)
 
 
func _update_lunge() -> void:
	velocity.x = lunge_dir.x * lunge_speed
	velocity.z = lunge_dir.z * lunge_speed
 
	if not has_hit and global_position.distance_to(target.global_position) <= hit_range:
		has_hit = true
		target.call("take_damage", attack_damage)
		_start_recover()  # Stop on contact instead of shoving through the player.
	elif state_timer <= 0.0:
		_start_recover()
 
 
func _start_recover() -> void:
	state = State.RECOVER
	state_timer = recover_time
	_tween_lean(0.0, recover_time * 0.5)
 
 
# Windup tell (lean + color flash)
 
func _play_windup_tell() -> void:
	_tween_lean(deg_to_rad(lean_angle), windup_time)
	_play_sound(windup_sound)
 
	if flash_tween:
		flash_tween.kill()
	flash_material.albedo_color = Color(windup_color, 0.0)
	flash_tween = create_tween()
	var blink := windup_time / maxi(windup_blinks, 1)
	for i in maxi(windup_blinks, 1):
		# Beep as each blink starts. bind() fills in the arguments for when the tween calls it later.
		flash_tween.tween_callback(_play_sound.bind(blink_sound, 1.0 + i * blink_pitch_rise))
		flash_tween.tween_property(flash_material, "albedo_color:a", 0.6, blink * 0.7)
		flash_tween.tween_property(flash_material, "albedo_color:a", 0.0, blink * 0.3)
 
 
## Plays a sound from this enemy, with a little random pitch. Does nothing if `stream` is empty.
func _play_sound(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	if sfx.stream != stream:
		sfx.stream = stream  # Swapping streams cuts off whatever was playing, so only swap when needed.
	sfx.volume_db = sound_volume_db
	sfx.pitch_scale = sound_pitch * pitch * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	sfx.play()
 
 
## Tilts the visual around its X axis. Positive leans back, negative leans forward.
func _tween_lean(angle: float, duration: float) -> void:
	if lean_tween:
		lean_tween.kill()
	lean_tween = create_tween()
	lean_tween.tween_property(visual, "rotation:x", angle, duration)
 
 
## Turns the body toward a flat direction. Godot's "forward" is -Z.
func _face(dir: Vector3, delta: float) -> void:
	if dir == Vector3.ZERO:
		return
	var angle := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, angle, minf(turn_speed * delta, 1.0))
 
 
func _flat_direction_to(point: Vector3) -> Vector3:
	var dir := point - global_position
	dir.y = 0.0
	return dir.normalized()
 
 
# Chasing
 
func _get_chase_direction() -> Vector3:
	# Aim at the floor under the player, not the player. While they're in the air,
	# the nearest navmesh point to their body can be the stairs they just left.
	var goal := _ground_below(target.global_position)
	if goal.distance_to(navigation_agent_3d.target_position) > repath_distance:
		navigation_agent_3d.target_position = goal
 
	var next_point := navigation_agent_3d.get_next_path_position()
 
	# Go straight for the player when the path ran out (they're somewhere the
	# navmesh doesn't reach), or when dropping/jumping is much shorter than the
	# walking route. Gravity and ledge jumps handle the rest.
	if navigation_agent_3d.is_navigation_finished() or _should_take_shortcut(goal):
		next_point = goal
 
	var dir := next_point - global_position
	dir.y = 0.0
	return dir.normalized()
 
 
func _should_take_shortcut(goal: Vector3) -> bool:
	# Stay committed while in the air or for a moment after deciding.
	if shortcut_timer > 0.0 or (is_shortcutting and not is_on_floor()):
		return true
 
	is_shortcutting = _shortcut_is_worth_it(goal)
	if is_shortcutting:
		shortcut_timer = shortcut_commit_time
	return is_shortcutting
 
 
func _shortcut_is_worth_it(goal: Vector3) -> bool:
	var feet := _ground_below(global_position)
 
	# Too high to jump up to. (Any drop is fine.)
	if goal.y - feet.y > max_jump_height:
		return false
 
	var straight := Vector2(feet.x, feet.z).distance_to(Vector2(goal.x, goal.z))
	if straight > shortcut_max_distance:
		return false
 
	# The walking route is already close to a straight line, so just walk.
	if _remaining_path_length() < straight * shortcut_ratio:
		return false
 
	# Is anything in the way? Cast a ray a little above the higher of the two floors.
	# A ledge we can jump onto or a drop we can fall off won't block it, a real wall will.
	var y := maxf(feet.y, goal.y) + 0.5
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(feet.x, y, feet.z), Vector3(goal.x, y, goal.z), ground_mask)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
 
 
## How far we'd still have to walk along the navmesh path.
func _remaining_path_length() -> float:
	var path := navigation_agent_3d.get_current_navigation_path()
	var index := navigation_agent_3d.get_current_navigation_path_index()
	if index >= path.size():
		return 0.0
 
	var length := global_position.distance_to(path[index])
	for i in range(index, path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	return length
 
 
func _ground_below(from: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 50.0, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else from
 
 
# Movement (same math as the player)
 
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		fall_time = 0.0
		return
 
	var gravity := get_gravity() * gravity_scale
 
	# Falling: gravity gets stronger the longer we've been falling.
	if velocity.y < 0.0:
		fall_time += delta
		var growth := minf(pow(gravity_growth, fall_time), max_gravity_multiplier)
		gravity *= fall_gravity_multiplier * growth
 
	velocity += gravity * delta
	velocity.y = maxf(velocity.y, -terminal_velocity)
 
 
func _apply_movement(move_dir: Vector3, delta: float) -> void:
	var target_velocity := move_dir * speed * speed_multiplier
 
	var rate := ground_acceleration if move_dir else ground_deceleration
	if not is_on_floor():
		rate *= air_control
 
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
 
 
# Jumping
 
## Upward speed needed to rise `height` meters under our rising gravity.
## From v² = 2gh. Rising uses plain gravity_scale (the fall multiplier only kicks in on the way down).
func _jump_velocity_for(height: float) -> float:
	var g := get_gravity().length() * gravity_scale
	return sqrt(2.0 * g * (height + jump_clearance))
 
 
func _jump(height: float, move_dir: Vector3) -> void:
	velocity.y = _jump_velocity_for(height)
	# Keep pushing forward; hitting the wall zeroed our horizontal speed.
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	jump_timer = jump_cooldown
 
 
## Reactive jump: we're pressing into a wall that turns out to be a short ledge.
func _try_ledge_jump(move_dir: Vector3) -> void:
	if not is_on_floor() or jump_timer > 0.0 or move_dir == Vector3.ZERO:
		return
	if not is_on_wall() or get_wall_normal().dot(move_dir) > -0.5:
		return
 
	var height := _measure_ledge(move_dir)
	if height > 0.0:
		_jump(height, move_dir)
 
 
## How tall the ledge in front of us is, or -1 if there's nothing we can jump onto.
func _measure_ledge(move_dir: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var floor_y := _ground_below(global_position).y
 
	# Drop a ray from just above our max jump height, a little way in front of us.
	var ahead := global_position + move_dir * ledge_check_distance
	ahead.y = floor_y + max_jump_height + 0.1
	var query := PhysicsRayQueryParameters3D.create(ahead, Vector3(ahead.x, floor_y, ahead.z), ground_mask)
	var hit := space.intersect_ray(query)
 
	# Nothing found, the wall is taller than we can jump (the ray starts inside it),
	# or the top is too steep to stand on.
	if hit.is_empty() or hit.normal.y < 0.7:
		return -1.0
 
	var height: float = hit.position.y - floor_y
	return height if height > 0.05 else -1.0
 
 
# Getting unstuck

## A safety net so one lost enemy can't hold up the whole wave.
## Watches for two things: trying to walk but not getting anywhere, and being
## wedged off the floor without falling. Either one triggers _unstick().
func _check_stuck(move_dir: Vector3, delta: float) -> void:
	if is_on_floor() or absf(velocity.y) > 0.5:
		wedged_timer = 0.0
	else:
		wedged_timer += delta

	# Standing still on purpose (in range, winding up, recovering) isn't stuck.
	if move_dir == Vector3.ZERO or global_position.distance_to(stuck_anchor) > stuck_distance:
		stuck_timer = 0.0
		stuck_anchor = global_position
	else:
		stuck_timer += delta

	if stuck_timer >= stuck_time or wedged_timer >= wedged_time:
		_unstick()


## Off the navmesh (on a barrel, wedged on a prop): move to the nearest walkable floor.
## On the navmesh (blocked by a crowd or a small lip): just hop toward the player.
func _unstick() -> void:
	stuck_timer = 0.0
	wedged_timer = 0.0
	stuck_anchor = global_position

	var map := navigation_agent_3d.get_navigation_map()
	var floor_point := NavigationServer3D.map_get_closest_point(map, global_position)
	if global_position.distance_to(floor_point) > off_navmesh_distance:
		# The navmesh sits a little above the real floor. Start a bit higher still
		# and let gravity settle us, so we never spawn inside the ground.
		global_position = floor_point + Vector3.UP * 1.5
		velocity = Vector3.ZERO
	else:
		_jump(max_jump_height * 0.5, _flat_direction_to(target.global_position))


## NavigationLink3D: the path itself says "jump here".
func _on_link_reached(details: Dictionary) -> void:
	if not is_on_floor() or state != State.CHASE:
		return
	var entry: Vector3 = details.link_entry_position
	var exit: Vector3 = details.link_exit_position
	var height := exit.y - entry.y
	# Going down just walks off the edge and gravity does the rest.
	if height > 0.1:
		var dir := exit - entry
		dir.y = 0.0
		_jump(height, dir.normalized())
 
 
# Health
 
func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	_spawn_damage_number(amount)
	health -= amount
	if health <= 0:
		is_dead = true
		_drop_xp()
		died.emit()
		queue_free()
	else:
		_play_hit_flash()
 
 
func _spawn_damage_number(amount: int) -> void:
	var number = DAMAGE_NUMBER.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = global_position + Vector3(0, 2.0, 0)
	number.setup(amount)
 
 
func _setup_hit_flash() -> void:
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.albedo_color = Color(1, 1, 1, 0)
 
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = flash_material
 
 
func _play_hit_flash() -> void:
	if flash_tween:
		flash_tween.kill()
	flash_material.albedo_color = Color(1, 1, 1, 0.7)
	flash_tween = create_tween()
	flash_tween.tween_property(flash_material, "albedo_color:a", 0.0, 0.12)
 
func _drop_xp() -> void:
	var orb = XP_ORB.instantiate()
	orb.xp_value = xp_value
	get_tree().current_scene.add_child(orb)
	orb.drop_from(global_position)
 
