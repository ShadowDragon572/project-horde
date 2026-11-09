## Everything that describes one weapon: its stats, its model and how it feels.
## Make one .tres file per weapon type (Pistol, SMG, Axe...).
## The game gives the player a *copy* of these, so each owned weapon can later
## get its own upgrades and remembers its own ammo.
class_name WeaponData
extends Resource

enum Kind { GUN, MELEE }

@export var display_name : String = "Weapon"
@export var icon : Texture2D
## The scene with the weapon model in it. Needs a Marker3D named "Muzzle" for guns,
## and can have a Marker3D named "LeftGrip" where the left hand holds a two-handed weapon.
@export var viewmodel : PackedScene
@export var kind : Kind = Kind.GUN
## Takes up both hands. Always sits in the right hand, the left hand helps hold it.
@export var two_handed : bool = false

@export_group("Gun")
## Bullets per magazine.
@export var magazine_size : int = 12
## Seconds a reload takes.
@export var reload_time : float = 1.5
## Shots per second.
@export var fire_rate : float = 6.0
## Keep firing while the button is held.
@export var automatic : bool = false
@export var damage : int = 1
## Extra enemies a shot passes through.
@export var pierce : int = 0

@export_group("Melee")
## How far in front of the camera the hit reaches, in meters.
@export var melee_range : float = 2.0
## How wide the hit is, in meters.
@export var melee_radius : float = 0.7
## Seconds for one full swing.
@export var swing_time : float = 0.45

@export_group("Recoil")
## How far the hand is pushed back, in meters (local X, Y, Z).
@export var recoil_kick : Vector3 = Vector3(0.0, 0.01, 0.06)
## How far the muzzle climbs, in degrees (local X, Y, Z).
@export var recoil_climb : Vector3 = Vector3(6.0, 0.0, 0.0)
## Random sideways twist and roll per shot, in degrees.
@export var recoil_random : float = 1.5
## Seconds for the hand to return to rest.
@export var recoil_recover_time : float = 0.12

@export_group("Reload Animation")
## How far the hand drops, in meters.
@export var reload_dip : float = 0.3
## Hand tilt at the bottom of the dip, in degrees. Mirrored automatically for the left hand.
@export var reload_tilt : Vector3 = Vector3(-25.0, 0.0, 15.0)

@export_group("Audio")
@export var fire_sound : AudioStream
@export var reload_sound : AudioStream

# Not exported: this changes while you play. -1 means "full, fill me up on first equip".
var current_ammo : int = -1
