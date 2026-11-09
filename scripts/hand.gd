## One hand on screen. Holds a weapon, fires it, reloads it and animates it.
## You'll have two of these under the camera: HandLeft and HandRight.
## The whole hand (arm + weapon) moves together, so recoil and reload
## tweens move this node itself.
class_name Hand
extends Node3D

signal weapon_changed(weapon: WeaponData)
signal ammo_changed(current: int, max_ammo: int)
signal reload_started(duration: float)
signal reload_finished

enum Slot { LEFT, RIGHT }

@export var side : Slot = Slot.RIGHT
## Seconds to raise a weapon after equipping it. You can't fire during this.
@export var draw_time : float = 0.2

@export_group("Arm Animations (optional)")
## The AnimationPlayer that came with your arms model. Leave empty to use tweens only.
@export var arm_animations : AnimationPlayer
@export var anim_idle : StringName = &"idle"
@export var anim_fire : StringName = &"fire"
@export var anim_reload : StringName = &"reload"
@export var anim_swing : StringName = &"swing"

var player # The player script. Set by the player in _ready().
var weapon : WeaponData
var is_reloading : bool = false

var _view : Node3D        # The weapon model we spawned.
var _muzzle : Node3D
var _muzzle_flash : OmniLight3D
var _cooldown : float = 0.0
var _reload_token : int = 0 # Bumps on every equip, so an old reload can tell it was cancelled.
var _tween : Tween
var _rest_position : Vector3
var _rest_rotation : Vector3
var _rest_scale : Vector3   # Holding a scaled weapon's LeftGrip copies its scale, so we reset this too.
var _supporting : Hand      # The hand whose two-handed weapon we're helping hold.

@onready var weapon_socket : Node3D = $WeaponSocket
@onready var fire_sound : AudioStreamPlayer = $FireSound
@onready var reload_sound : AudioStreamPlayer = $ReloadSound


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation
	_rest_scale = scale
	visible = false


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

	# Helping hold a two-handed weapon: stick to its LeftGrip marker.
	if _supporting:
		var grip := _supporting.get_grip()
		if grip:
			global_transform = grip.global_transform


# Equipping

func equip(new_weapon: WeaponData) -> void:
	_reload_token += 1
	is_reloading = false
	if _tween:
		_tween.kill()

	if _view:
		_view.queue_free()
	_view = null
	_muzzle = null
	_muzzle_flash = null

	weapon = new_weapon
	visible = weapon != null
	position = _rest_position
	rotation = _rest_rotation

	if weapon:
		if weapon.viewmodel:
			_view = weapon.viewmodel.instantiate()
			weapon_socket.add_child(_view)
			_muzzle = _view.get_node_or_null("Muzzle")
			_muzzle_flash = _view.get_node_or_null("Muzzle/MuzzleFlash")
		# Always overwrite, so a weapon with no sound doesn't keep the last weapon's.
		fire_sound.stream = weapon.fire_sound
		reload_sound.stream = weapon.reload_sound
		if weapon.current_ammo < 0:
			weapon.current_ammo = magazine_size()
		_play_draw()

	weapon_changed.emit(weapon)
	_emit_ammo()


## Call with the right hand to make this (left) hand help hold its two-handed weapon.
## Call with null to go back to normal.
func support(other: Hand) -> void:
	_supporting = other
	if other:
		visible = other.get_grip() != null
	else:
		position = _rest_position
		rotation = _rest_rotation
		scale = _rest_scale
		visible = weapon != null


## The spot where the other hand should grab this hand's weapon, if it has one.
func get_grip() -> Node3D:
	if _view == null:
		return null
	return _view.get_node_or_null("LeftGrip")


func magazine_size() -> int:
	if weapon == null:
		return 0
	return weapon.magazine_size + player.magazine_bonus


# Firing

## Called every frame the fire button is held. `just_pressed` is true on the first frame.
func try_fire(just_pressed: bool) -> void:
	if weapon == null or is_reloading or _cooldown > 0.0:
		return
	if not weapon.automatic and not just_pressed:
		return

	if weapon.kind == WeaponData.Kind.MELEE:
		_swing()
		return

	if weapon.current_ammo <= 0:
		reload()
		return

	_cooldown = 1.0 / maxf(weapon.fire_rate, 0.01)
	weapon.current_ammo -= 1
	_emit_ammo()

	var from := _muzzle.global_position if _muzzle else global_position
	player.fire_hitscan(weapon, from)
	fire_sound.play()
	_flash_muzzle()
	_play_recoil()

	if weapon.current_ammo <= 0:
		reload()


func _swing() -> void:
	_cooldown = weapon.swing_time
	_play_swing()
	fire_sound.play() # A melee weapon's fire_sound is its swing sound.
	var token := _reload_token
	# The hit lands partway through the swing, not the moment you click.
	await get_tree().create_timer(weapon.swing_time * 0.4, false).timeout
	if token == _reload_token: # Still holding the same weapon?
		player.melee_hit(weapon)


func _flash_muzzle() -> void:
	if _muzzle_flash == null:
		return
	_muzzle_flash.light_energy = 3.0
	create_tween().tween_property(_muzzle_flash, "light_energy", 0.0, 0.06)


# Reloading

func reload() -> void:
	if weapon == null or weapon.kind != WeaponData.Kind.GUN:
		return
	if is_reloading or weapon.current_ammo >= magazine_size():
		return

	is_reloading = true
	var token := _reload_token
	var time : float = weapon.reload_time * player.reload_time_multiplier
	reload_started.emit(time)
	reload_sound.play()
	_play_reload(time)

	await get_tree().create_timer(time, false).timeout
	if token != _reload_token:
		return # Weapon was swapped out mid-reload. The old one keeps its old ammo.

	weapon.current_ammo = magazine_size()
	is_reloading = false
	_emit_ammo()
	reload_finished.emit()


func _emit_ammo() -> void:
	if weapon and weapon.kind == WeaponData.Kind.GUN:
		ammo_changed.emit(weapon.current_ammo, magazine_size())
	else:
		ammo_changed.emit(-1, -1)


# Animation (tweens move the whole hand; arm clips play on top if you have them)

func _play_draw() -> void:
	_cooldown = draw_time
	position = _rest_position + Vector3(0.0, -0.35, 0.0)
	_tween = create_tween()
	_step(_rest_position, _rest_rotation, draw_time, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_play_clip(anim_idle)


func _play_recoil() -> void:
	if _tween:
		_tween.kill()

	var kick_rotation := _rest_rotation + weapon.recoil_climb * PI / 180.0
	kick_rotation.y += deg_to_rad(randf_range(-weapon.recoil_random, weapon.recoil_random))
	kick_rotation.z += deg_to_rad(randf_range(-weapon.recoil_random, weapon.recoil_random))

	_tween = create_tween()
	_step(_rest_position + weapon.recoil_kick, kick_rotation,
		0.03, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_step(_rest_position, _rest_rotation,
		weapon.recoil_recover_time, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_play_clip(anim_fire)


func _play_reload(time: float) -> void:
	if _tween:
		_tween.kill()

	var tilt := weapon.reload_tilt * PI / 180.0
	if side == Slot.LEFT:
		# Mirror the twist and roll so the left hand tilts outward too.
		tilt.y = -tilt.y
		tilt.z = -tilt.z
	var dip := Vector3(0.0, -weapon.reload_dip, 0.0)

	_tween = create_tween()
	# Drop quickly, then settle into the pose
	_step(_rest_position + dip, _rest_rotation + tilt,
		time * 0.25, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	# Slow sway while the magazine is swapped
	_step(_rest_position + dip * 0.9, _rest_rotation + tilt * 1.25,
		time * 0.45, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	# Snap back with a small overshoot
	_step(_rest_position, _rest_rotation,
		time * 0.30, Tween.TRANS_BACK, Tween.EASE_OUT)
	_play_clip(anim_reload)


func _play_swing() -> void:
	if _tween:
		_tween.kill()

	# Swing across the body: the right hand swings to the left, the left hand to the right.
	var across := 1.0 if side == Slot.RIGHT else -1.0
	var wind_up_rot := _rest_rotation + Vector3(deg_to_rad(35.0), deg_to_rad(-30.0 * across), 0.0)
	var slash_rot := _rest_rotation + Vector3(deg_to_rad(-40.0), deg_to_rad(50.0 * across), 0.0)
	var slash_pos := _rest_position + Vector3(-0.25 * across, -0.1, -0.15)
	var t := weapon.swing_time

	_tween = create_tween()
	_step(_rest_position + Vector3(0.05 * across, 0.08, 0.05), wind_up_rot,
		t * 0.3, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_step(slash_pos, slash_rot, t * 0.2, Tween.TRANS_EXPO, Tween.EASE_IN)
	_step(_rest_position, _rest_rotation, t * 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_play_clip(anim_swing)


func _step(pos: Vector3, rot: Vector3, time: float,
		trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	_tween.tween_property(self, "position", pos, time).set_trans(trans).set_ease(ease_type)
	_tween.parallel().tween_property(self, "rotation", rot, time).set_trans(trans).set_ease(ease_type)


func _play_clip(clip: StringName) -> void:
	if arm_animations and arm_animations.has_animation(clip):
		arm_animations.stop()
		arm_animations.play(clip)
