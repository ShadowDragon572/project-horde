## Shakes its parent Camera3D. Put it on a plain Node under the player's camera.
## Anything can shake the screen with: get_tree().call_group("camera_shake", "add_trauma", 0.5)
extends Node
 
## How far the view can slide at full trauma, in meters.
@export var max_offset : float = 0.25
## Trauma lost per second. Higher stops the shake sooner.
@export var decay : float = 1.8
## How jittery the shake is. Higher is faster.
@export var frequency : float = 30.0
 
## 0 to 1. Explosions add to it, and it drains over time.
var trauma : float = 0.0
var time : float = 0.0
var noise := FastNoiseLite.new()
 
@onready var camera : Camera3D = get_parent()
 
 
func _ready() -> void:
	add_to_group("camera_shake")
	noise.frequency = 0.1
 
 
func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)
 
 
func _process(delta: float) -> void:
	if trauma <= 0.0:
		return
 
	trauma = maxf(trauma - decay * delta, 0.0)
	time += delta * frequency
	# Squaring makes small shakes subtle and big ones punchy.
	var strength := trauma * trauma * max_offset
	# Noise instead of randf(), so the camera wobbles smoothly instead of teleporting.
	camera.h_offset = noise.get_noise_2d(time, 0.0) * strength
	camera.v_offset = noise.get_noise_2d(0.0, time) * strength
 
