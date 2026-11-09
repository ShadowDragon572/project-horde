## Runs the wave loop: break -> spawn enemies -> wait until all are dead -> repeat.
extends Node3D
 
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal enemies_left_changed(count: int)
signal countdown_changed(seconds_left: float)  # Sent every frame during the break.

@export_group("Fog")
@export var world_environment : WorldEnvironment
@export var target_fog_density := 0.02 
@export var target_fog_light_color := Color("ed3b5cff")
@export var fog_fade_duration := 3.0

@export_group("Spawn Area")
@export var min_spawn_distance := 20.0
## Layers that block the player's view (walls, terrain).
@export_flags_3d_physics var line_of_sight_mask := 1
## Keeps enemies from spawning inside the floor.
@export var spawn_height_offset := 1.0
 
@export_group("Waves")
## Hand-made waves, played in order. Every enemy scene in them must emit `died`, or the wave never ends.
@export var waves: Array[WaveData] = []
## Seconds of break after each cleared wave. The player can change loadout or skip it with "ready_wave".
@export var time_between_waves := 15.0
## Before wave 1, wait for the player to press "ready_wave" instead of counting down,
## so new players have time to read the controls. Turn off to use first_break_time.
@export var wait_for_ready_before_first_wave := true
## Seconds of break before wave 1 when not waiting for ready. Kept separate so the start of a run can stay short.
@export var first_break_time := 4.0
## Hard cap so endless mode can't spawn a crazy number in one wave.
@export var max_enemies_per_wave := 50
## Increases the health multiplier of enemies at set waves and keeps it until next entry.
@export var wave_health_scaling: Dictionary[int, float] = {}
 
@export_group("Endless")
## After the last hand-made wave, it repeats with this much more of each enemy per extra wave (0.25 = +25%).
@export var endless_count_growth := 0.25
## ...and this much more health per extra wave (0.15 = +15%).
@export var endless_health_growth := 0.15
 
var current_wave := 0
var enemies_left := 0
var enemies_defeated := 0  # Total for the whole run. Shown on the death screen.
var intermission_left := 0.0  # Above 0 = on a break.
var waiting_for_ready := false  # True before wave 1 while the countdown is held for the player.
var player: Node3D
var _recent_points: Array[Marker3D] = []  # Last few spawn points, to avoid repeats.
 
var default_fog_density : float
var default_fog_light_color : Color
var fog_tween : Tween 

# --- SETUP ---
 
func _enter_tree() -> void:
	add_to_group("wave_manager")
 
 
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	# Physics and navigation aren't ready on the first frame, so wait briefly.
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Break before wave 1. maxf() so a first_break_time of 0 still counts as a (very short) break.
	intermission_left = maxf(first_break_time, 0.001)
	waiting_for_ready = wait_for_ready_before_first_wave
	# Grab default values for WorldEnvironment fog settings
	default_fog_density = world_environment.environment.fog_density
	default_fog_light_color = world_environment.environment.fog_light_color
	
	

# --- BREAK TIMER ---

# This node pauses with the tree, so the countdown stops while the stance editor
# (or the upgrade menu) has the game paused, and carries on from the same number after.
func _process(delta: float) -> void:
	if intermission_left > 0.0:
		# While waiting for ready the clock doesn't run, but the UI still gets updates.
		if not waiting_for_ready:
			intermission_left -= delta
		countdown_changed.emit(maxf(intermission_left, 0.0))
		if intermission_left <= 0.0:
			_start_next_wave()


## True during the countdown between waves (and before wave 1).
func is_on_break() -> bool:
	return intermission_left > 0.0


## Skips the rest of the break and starts the next wave right away.
## Does nothing mid-wave or while the game is paused (stance editor or upgrade menu open).
## Returns true if a wave was started.
func start_next_wave_now() -> bool:
	if not is_on_break() or get_tree().paused:
		return false
	waiting_for_ready = false
	intermission_left = 0.0
	countdown_changed.emit(0.0)
	_start_next_wave()
	return true

 
# --- STARTING A WAVE ---
 
func _start_next_wave() -> void:
	if waves.is_empty():
		push_error("WaveManager: the Waves list is empty")
		return
 
	current_wave += 1
	if wave_health_scaling.has(current_wave):
		_tween_fog(target_fog_density, target_fog_light_color)
	
	# Hand-made waves in order, then keep repeating the last one.
	var wave: WaveData = waves[mini(current_wave, waves.size()) - 1]
	# How many waves past the hand-made ones we are. 0 until they run out.
	var extra := maxi(current_wave - waves.size(), 0)
	var count_multiplier := 1.0 + extra * endless_count_growth
	var health_multiplier := _find_wave_health_multiplier(current_wave) + (extra * endless_health_growth)
	var spawn_list := _build_spawn_list(wave, count_multiplier)
	# Count the whole wave now so early kills can't end it before all enemies spawn.
	enemies_left = spawn_list.size()
	wave_started.emit(current_wave)
	enemies_left_changed.emit(enemies_left)
 
	if spawn_list.is_empty():
		push_warning("WaveManager: wave %d has no enemies" % current_wave)
		_finish_wave()
		return
 
	# Spawn one at a time without freezing the game.
	var spawned := 0
	while spawned < spawn_list.size():
		var pos := _get_spawn_position()
		if pos == Vector3.INF:
			# No good spot yet; retry shortly.
			await get_tree().create_timer(0.2).timeout
			continue
		_spawn_enemy(spawn_list[spawned], pos, health_multiplier)
		spawned += 1
		# Enemies in the same burst come out together, so only wait between bursts.
		if spawned % wave.burst_size == 0:
			await get_tree().create_timer(wave.spawn_interval).timeout
 
func _tween_fog(density: float, color: Color):
	if fog_tween and fog_tween.is_running():
		fog_tween.kill()
	fog_tween = create_tween().set_parallel()
	fog_tween.tween_property(world_environment.environment, "fog_density", density, fog_fade_duration) \
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fog_tween.tween_property(world_environment.environment, "fog_light_color", color, fog_fade_duration) \
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 
func _find_wave_health_multiplier(wave_num: int) -> float:
	var best_wave: int = 0
	var multiplier: float = 1.0
	for wave_key in wave_health_scaling:
		var current_multiplier : float = wave_health_scaling[wave_key]
		# The wave we pass in has to be greater than or equal the current entry 
		# and current current entry > latest entry we've reached (keys can be in any order)
		if wave_num >= wave_key and wave_key > best_wave:
			best_wave = wave_key
			multiplier = current_multiplier
	
	return multiplier

## Turns a wave's groups into one flat list of scenes, e.g. [grunt, grunt, tank, grunt, drone].
func _build_spawn_list(wave: WaveData, count_multiplier: float) -> Array[PackedScene]:
	var list: Array[PackedScene] = []
	for group in wave.groups:
		if group == null or group.enemy_scene == null:
			continue
		for i in roundi(group.count * count_multiplier):
			list.append(group.enemy_scene)
 
	if wave.shuffle:
		list.shuffle()
	# Cap after shuffling, so every type still shows up.
	if list.size() > max_enemies_per_wave:
		list.resize(max_enemies_per_wave)
	return list
 
 
# --- CHOOSING A SPAWN POINT ---
 
## Picks a far-away spawn point, preferring ones the player can't see.
## Returns Vector3.INF if none are usable.
func _get_spawn_position() -> Vector3:
	var points := get_tree().get_nodes_in_group("enemy_spawn")
	if points.is_empty():
		push_error("WaveManager: no nodes in group 'enemy_spawn'")
		return Vector3.INF
 
	var eye := player.global_position + Vector3(0, 1.5, 0)  # Player's eye height.
	var hidden: Array[Marker3D] = []
	var visible_far: Array[Marker3D] = []
	var farthest: Marker3D = null  # Fallback when every point is too close.
 
	# Skip points that are recent or too close, then sort by visibility.
	for p in points:
		var marker := p as Marker3D
		if marker == null: continue
		if farthest == null or marker.global_position.distance_to(player.global_position) \
				> farthest.global_position.distance_to(player.global_position):
			farthest = marker
		if marker in _recent_points: continue
		if marker.global_position.distance_to(player.global_position) < min_spawn_distance:
			continue
 
		if _is_hidden_from_player(eye, marker.global_position + Vector3(0, 1.0, 0)):
			hidden.append(marker)
		else:
			visible_far.append(marker)
 
	# Use visible points only if no hidden ones exist.
	var pool := hidden if not hidden.is_empty() else visible_far
	if pool.is_empty():
		# Every point is recent or too close. Use the farthest one rather than
		# waiting, so the wave always finishes spawning.
		_recent_points.clear()
		pool = [farthest]
 
	var chosen: Marker3D = pool.pick_random()
 
	# Remember only the last 3 picks.
	_recent_points.append(chosen)
	if _recent_points.size() > 3:
		_recent_points.pop_front()
 
	# Snap to the navmesh so the enemy can always walk from where it spawns.
	var map := get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, chosen.global_position)
 
 
## Returns true if a wall blocks the view between the two points.
func _is_hidden_from_player(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, line_of_sight_mask)
	query.exclude = [player.get_rid()]  # Don't let the ray hit the player's own body.
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()
 
 
# --- SPAWNING AND DEATHS ---
 
func _spawn_enemy(scene: PackedScene, pos: Vector3, health_multiplier: float) -> void:
	var enemy = scene.instantiate()
	# Set before add_child(), because the enemy copies max_health into health in _ready().
	enemy.max_health = ceili(enemy.max_health * health_multiplier)
	add_child(enemy)  # Must be in the scene before setting its world position.
	enemy.global_position = pos + Vector3(0, spawn_height_offset, 0)
	enemy.died.connect(_on_enemy_died)
 
 
func _on_enemy_died() -> void:
	enemies_left -= 1
	enemies_defeated += 1
	enemies_left_changed.emit(enemies_left)
	if enemies_left <= 0:
		_finish_wave()
 
 
func _finish_wave() -> void:
	if wave_health_scaling.has(current_wave):
		_tween_fog(default_fog_density, default_fog_light_color)
		
	wave_cleared.emit(current_wave)
	intermission_left = time_between_waves  # Starts the break, which leads to the next wave.
	# The stance editor no longer opens here. The break prompt (wave_banner.gd) lets the
	# player open it with "open_loadout" instead.
 
