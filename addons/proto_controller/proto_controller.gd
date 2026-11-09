# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

# extended with shooting and reloading.
# extended with stances: two hands, two loadouts.
extends CharacterBody3D

signal health_changed(current: int, maximum: int)
## Sent when stamina goes up or down. Not sent on frames where it didn't change.
signal stamina_changed(current: float, maximum: float)
## Sent when you run out (true) and when you've recovered enough to sprint again (false).
signal exhausted_changed(is_exhausted: bool)
signal died
signal xp_changed(current: int, needed: int, level: int)
signal upgrade_offered(choices: Array)
signal enemy_hit

const TRACER = preload("res://scenes/tracer.tscn")
const IMPACT_SPARKS = preload("uid://cqo5evxl2clh0")
const WALL_SPARK_COLOR := Color(1.0, 0.8, 0.3)
const ENEMY_SPARK_COLOR := Color(1.0, 0.25, 0.2)

@export_group("Abilities")
## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = true
## Can we hold to crouch?
@export var can_crouch : bool = true
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 5.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we move while crouched?
@export var crouch_speed : float = 3.5
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Gravity")
## Multiplies the project's gravity. Higher feels heavier.
@export var gravity_scale : float = 1.5
## Extra gravity while falling, so you come down faster than you went up.
@export var fall_gravity_multiplier : float = 1.6
## How quickly gravity grows the longer you fall. 1.0 means no growth.
@export var gravity_growth : float = 2.5
## Cap on that growth so long falls don't get absurd.
@export var max_gravity_multiplier : float = 2.5
## Fastest we can fall, in m/s.
@export var terminal_velocity : float = 40.0

@export_group("Movement Feel")
## How quickly we reach full speed on the ground (m/s gained per second).
@export var ground_acceleration : float = 60.0
## How quickly we stop on the ground after letting go.
@export var ground_deceleration : float = 45.0
## Share of ground control we keep in the air. 0 is none, 1 is full.
@export_range(0.0, 1.0) var air_control : float = 0.3

@export_group("Crouch")
## Collider height while crouched, in meters. Must be at least twice the capsule radius.
@export var crouch_height : float = 1.2
## Seconds to go fully down or fully back up.
@export var crouch_transition_time : float = 0.12

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "input_left"
## Name of Input Action to move Right.
@export var input_right : String = "input_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "input_forward"
## Name of Input Action to move Backward.
@export var input_back : String = "input_back"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to Crouch.
@export var input_crouch : String = "crouch"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

@export_group("Player-wide Weapon Bonuses")
## Added to every weapon's damage. Upgrades raise this.
@export var damage : int = 0
## Added to every weapon's pierce. Upgrades raise this.
@export var pierce : int = 0
## Added to every gun's magazine size.
@export var magazine_bonus : int = 0
## Multiplies every reload time. 0.8 means reloads are 20% faster.
@export var reload_time_multiplier : float = 1.0

@export_group("Health")
@export var max_health : int = 100
## Seconds after a hit during which you can't be hit again.
@export var invulnerable_time : float = 0.3

@export_group("Stamina")
## Full stamina. Only sprinting uses it.
@export var max_stamina : float = 100.0
## Stamina used per second while sprinting.
@export var drain_per_second : float = 25.0
## Stamina regained per second once regen starts.
@export var regen_per_second : float = 20.0
## Seconds after you stop sprinting before stamina starts coming back.
@export var regen_delay : float = 0.8
## After running out, you can't sprint again until stamina is back above this.
@export var exhausted_threshold : float = 30.0

@export_group("Progression")
## XP needed for level 2. Every level after needs more.
@export var xp_base : int = 10
## Multiplier applied to the XP requirement each level.
@export var xp_growth : float = 1.25
## How many upgrades are offered per level.
@export var upgrade_choices : int = 3
## Played when an orb is collected (optional, any short blip).
@export var pickup_sound : AudioStream
## Pickups within this many seconds chain into a rising pitch.
@export var pickup_chain_window : float = 0.8

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

var fall_time : float = 0.0
var is_crouching : bool = false
var crouch_amount : float = 0.0
var capsule : CapsuleShape3D
var standing_height : float = 0.0
var standing_collider_y : float = 0.0
var standing_head_y : float = 0.0

var health : int = 0
var is_dead : bool = false
var last_hit_time : float = -100.0

var stamina : float = 0.0
var is_exhausted : bool = false
var _regen_wait : float = 0.0 # Counts down after sprinting stops. Regen starts at 0.

var level : int = 1
var xp : int = 0
var xp_needed : int = 0
var pending_upgrades : int = 0
var upgrade_stacks : Dictionary = {}
var current_choices : Array = []
var pickup_chain : int = 0
var last_pickup_time : float = -100.0

@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

@onready var ray_cast_3d: RayCast3D = %RayCast3D
@onready var ray_cast_end: Node3D = %RayCastEnd
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand_left: Hand = %HandLeft
@onready var hand_right: Hand = %HandRight
@onready var stance_manager: StanceManager = $StanceManager

@onready var hit_sound: AudioStreamPlayer = %HitSound


func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	ray_cast_3d.add_exception(self)
	hand_left.player = self
	hand_right.player = self
	stance_manager.setup(hand_left, hand_right)
	health = max_health
	health_changed.emit(health, max_health)
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)
	xp_needed = _xp_for_level(level)
	xp_changed.emit(xp, xp_needed, level)
	_setup_crouch()
	# Grab the mouse right away, so the first click fires instead of just capturing it.
	capture_mouse()

# Esc no longer quits here. The pause menu (pause_menu.gd) owns Esc and has a Quit button.
func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	# Fallback: clicking recaptures the mouse if it got freed (for example by alt-tabbing).
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()

	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if freeflying:
			disable_freefly()
		else:
			enable_freefly()


func _process(_delta: float) -> void:
	_handle_weapon_input()


func _physics_process(delta: float) -> void:
	if can_freefly and freeflying:
		_process_freefly(delta)
		return

	_update_crouch(delta)
	_apply_gravity(delta)
	_apply_jump()
	_apply_movement(delta)
	move_and_slide()


# Weapons

func _handle_weapon_input() -> void:
	if is_dead or stance_manager.ui_open or not mouse_captured:
		return

	if Input.is_action_just_pressed("stance_swap"):
		stance_manager.cycle()

	if stance_manager.active_stance().is_two_handed():
		# One weapon, both hands: either button fires it, either key reloads it.
		var held := Input.is_action_pressed("fire_left") or Input.is_action_pressed("fire_right")
		var just := Input.is_action_just_pressed("fire_left") or Input.is_action_just_pressed("fire_right")
		if held:
			hand_right.try_fire(just)
		if Input.is_action_just_pressed("reload_left") or Input.is_action_just_pressed("reload_right"):
			hand_right.reload()
		return

	if Input.is_action_pressed("fire_left"):
		hand_left.try_fire(Input.is_action_just_pressed("fire_left"))
	if Input.is_action_pressed("fire_right"):
		hand_right.try_fire(Input.is_action_just_pressed("fire_right"))
	if Input.is_action_just_pressed("reload_left"):
		hand_left.reload()
	if Input.is_action_just_pressed("reload_right"):
		hand_right.reload()


## A hand calls this when it fires a gun. The shot goes where the crosshair points,
## and the tracer starts at the gun's muzzle.
func fire_hitscan(weapon: WeaponData, muzzle_position: Vector3) -> void:
	var hit_point := _fire_hitscan(weapon.damage + damage, weapon.pierce + pierce)
	_spawn_tracer(muzzle_position, hit_point)


## A hand calls this partway through a melee swing.
## Hits everything that can take damage in a capsule that runs from the camera
## straight out to melee_range, melee_radius wide.
## (It used to be a single ball at the far end of the reach, which left a dead zone
## up close: with a 4 m axe, anything nearer than about 2.5 m couldn't be hit.)
func melee_hit(weapon: WeaponData) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = weapon.melee_radius
	# A capsule's height is end to end, round caps included, so this reaches exactly
	# melee_range. It can't be shorter than its own two caps.
	shape.height = maxf(weapon.melee_range, weapon.melee_radius * 2.0)

	var forward := -camera.global_basis.z
	var center := camera.global_position + forward * (shape.height / 2.0)
	# Capsules stand along their local Y axis. Tip the camera's basis forward 90 degrees
	# so the capsule's Y points where the camera looks.
	var basis := camera.global_basis.orthonormalized() * Basis(Vector3.RIGHT, -PI / 2.0)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(basis, center)
	query.collision_mask = ray_cast_3d.collision_mask
	query.exclude = [get_rid()]

	var already_hit : Array = []
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var target = result["collider"]
		if target in already_hit or not target.has_method("take_damage"):
			continue
		already_hit.append(target)
		target.take_damage(weapon.damage + damage)
		enemy_hit.emit()
		_spawn_impact(target.global_position + Vector3.UP, -forward, ENEMY_SPARK_COLOR)


func _fire_hitscan(shot_damage: int, shot_pierce: int) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin := ray_cast_3d.global_position
	var end := ray_cast_3d.to_global(ray_cast_3d.target_position)

	var excluded: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(origin, end, ray_cast_3d.collision_mask)
	query.collide_with_areas = ray_cast_3d.collide_with_areas
	query.collide_with_bodies = ray_cast_3d.collide_with_bodies

	var enemies_hit := 0

	for i in shot_pierce + 2:
		query.exclude = excluded
		var result := space.intersect_ray(query)
		if result.is_empty():
			return end

		var point: Vector3 = result["position"]
		var normal: Vector3 = result["normal"]
		var collider = result["collider"]

		if collider and collider.has_method("take_damage"):
			collider.take_damage(shot_damage)
			enemy_hit.emit()
			_spawn_impact(point, normal, ENEMY_SPARK_COLOR)
			enemies_hit += 1
			if enemies_hit > shot_pierce:
				return point
			excluded.append(result["rid"])
		else:
			_spawn_impact(point, normal, WALL_SPARK_COLOR)
			return point

	return end


func _spawn_impact(point: Vector3, normal: Vector3, tint: Color) -> void:
	var sparks = IMPACT_SPARKS.instantiate()
	get_tree().current_scene.add_child(sparks)
	sparks.burst(point, normal, tint)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var tracer = TRACER.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.fire(from, to)

# Health

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	
	hit_sound.play()
	
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_hit_time < invulnerable_time:
		return
	last_hit_time = now

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)

	if health == 0:
		_die()

func heal(amount: int) -> void:
	if is_dead:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	can_move = false
	can_jump = false
	release_mouse()
	died.emit()

# Progression

func collect_xp(amount: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_pickup_time > pickup_chain_window:
		pickup_chain = 0
	last_pickup_time = now

	_play_pickup_sound()
	pickup_chain += 1
	add_xp(amount)


func add_xp(amount: int) -> void:
	if is_dead:
		return

	xp += amount
	var leveled_up := false

	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = _xp_for_level(level)
		pending_upgrades += 1
		leveled_up = true

	xp_changed.emit(xp, xp_needed, level)

	if leveled_up and current_choices.is_empty():
		_offer_upgrades()


func choose_upgrade(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return

	var id: String = current_choices[index]["id"]
	Upgrades.apply(id, self)
	upgrade_stacks[id] = upgrade_stacks.get(id, 0) + 1

	current_choices = []
	pending_upgrades -= 1
	if pending_upgrades > 0:
		_offer_upgrades()


func _offer_upgrades() -> void:
	var available := Upgrades.POOL.filter(_is_available)
	available.shuffle()
	current_choices = available.slice(0, upgrade_choices)

	if current_choices.is_empty():
		pending_upgrades = 0
		return

	upgrade_offered.emit(current_choices)


func _is_available(upgrade: Dictionary) -> bool:
	var max_stacks: int = upgrade.get("max_stacks", 0)
	return max_stacks == 0 or upgrade_stacks.get(upgrade["id"], 0) < max_stacks


func _xp_for_level(for_level: int) -> int:
	return maxi(1, roundi(xp_base * pow(xp_growth, for_level - 1)))


func _play_pickup_sound() -> void:
	if pickup_sound == null:
		return

	var p := AudioStreamPlayer.new()
	p.stream = pickup_sound
	p.pitch_scale = 1.0 + minf(pickup_chain * 0.06, 0.6)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# Movement

func _apply_gravity(delta: float) -> void:
	if not has_gravity or is_on_floor():
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


func _apply_jump() -> void:
	if can_jump and Input.is_action_just_pressed(input_jump) and is_on_floor():
		velocity.y = jump_velocity


func _apply_movement(delta: float) -> void:
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	# Holding sprint while standing still or crouching isn't sprinting, so it costs nothing.
	var wants_sprint := can_sprint and can_move and not is_crouching \
		and input_dir != Vector2.ZERO and Input.is_action_pressed(input_sprint)
	var sprinting := wants_sprint and not is_exhausted and stamina > 0.0
	_update_stamina(delta, sprinting)

	if is_crouching:
		move_speed = crouch_speed
	elif sprinting:
		move_speed = sprint_speed
	else:
		move_speed = base_speed # Also what you get when out of stamina.

	if not can_move:
		velocity.x = 0
		velocity.z = 0
		return

	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_velocity := move_dir * move_speed

	# Speed up while there's input, slow down when there isn't.
	var rate := ground_acceleration if move_dir else ground_deceleration
	if not is_on_floor():
		rate *= air_control

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Drains stamina while sprinting, and refills it after a short pause once you stop.
func _update_stamina(delta: float, sprinting: bool) -> void:
	var before := stamina
	if sprinting:
		stamina = maxf(stamina - drain_per_second * delta, 0.0)
		_regen_wait = regen_delay
		if stamina == 0.0:
			_set_exhausted(true)
	elif _regen_wait > 0.0:
		_regen_wait -= delta
	else:
		stamina = minf(stamina + regen_per_second * delta, max_stamina)
		# minf() so a threshold set above max_stamina can't lock sprinting off forever.
		if is_exhausted and stamina >= minf(exhausted_threshold, max_stamina):
			_set_exhausted(false)

	if stamina != before:
		stamina_changed.emit(stamina, max_stamina)


func _set_exhausted(value: bool) -> void:
	if is_exhausted == value:
		return
	is_exhausted = value
	exhausted_changed.emit(is_exhausted)


func _setup_crouch() -> void:
	capsule = collider.shape as CapsuleShape3D
	if capsule == null:
		push_error("Crouch disabled. Collider shape must be a CapsuleShape3D.")
		can_crouch = false
		return

	# Give this player its own copy so resizing it can't affect anything else using the shape.
	capsule = capsule.duplicate()
	collider.shape = capsule

	standing_height = capsule.height
	standing_collider_y = collider.position.y
	standing_head_y = head.position.y


func _update_crouch(delta: float) -> void:
	if not can_crouch:
		return

	if Input.is_action_pressed(input_crouch):
		is_crouching = true
	elif is_crouching and _can_stand_up():
		is_crouching = false

	var target := 1.0 if is_crouching else 0.0
	crouch_amount = move_toward(crouch_amount, target, delta / maxf(crouch_transition_time, 0.001))
	_apply_crouch_pose()


func _can_stand_up() -> bool:
	# Pretend to move our current (crouched) capsule up by the missing height.
	# If that would hit something, there's a ceiling in the way.
	var missing_height := standing_height - capsule.height
	return not test_move(global_transform, Vector3.UP * missing_height)


func _apply_crouch_pose() -> void:
	var t := smoothstep(0.0, 1.0, crouch_amount)
	var height := lerpf(standing_height, crouch_height, t)
	var drop := standing_height - height

	capsule.height = height
	# Keep the bottom of the capsule on the floor by sliding its center down half the drop.
	collider.position.y = standing_collider_y - drop * 0.5
	# The eyes drop the full amount, so they stay the same distance below the top of the head.
	head.position.y = standing_head_y - drop


func _process_freefly(delta: float) -> void:
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	move_and_collide(motion * freefly_speed * delta)


func enable_freefly() -> void:
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO


func disable_freefly() -> void:
	collider.disabled = false
	freeflying = false


# Camera and mouse

## Base rotates around Y (left/right), head rotates around X (up/down).
func rotate_look(rot_input: Vector2) -> void:
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed

	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


# Setup validation

## Disables features whose Input Actions haven't been created.
func check_input_mappings() -> void:
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_crouch and not InputMap.has_action(input_crouch):
		push_error("Crouching disabled. No InputAction found for input_crouch: " + input_crouch)
		can_crouch = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
