## Owns the player's weapons and stances, and tells the hands what to hold.
## Lives on the player as a plain Node called StanceManager.
class_name StanceManager
extends Node

## The active stance changed (switched in combat, or edited between waves).
signal stance_changed(index: int, stance: Stance)
## Something moved around in the stance editor.
signal stances_edited

## What the player starts a run with. Weapons in these get copied, so each
## stance slot gets its own weapon (two pistols = two separate pistols).
@export var starting_stances : Array[Stance] = []
## Extra weapons the player owns at the start but hasn't put in a stance.
@export var starting_spares : Array[WeaponData] = []

## Every weapon the player owns, in a stance or not.
var owned : Array[WeaponData] = []
var stances : Array[Stance] = []
var active : int = 0
## True while a stance menu is open. The player won't fire while this is set.
var ui_open : bool = false

var _left : Hand
var _right : Hand


## Called once by the player in _ready(), after the hands are set up.
func setup(left_hand: Hand, right_hand: Hand) -> void:
	_left = left_hand
	_right = right_hand

	for base in starting_stances:
		var s := Stance.new()
		s.display_name = base.display_name
		s.left = add_weapon(base.left)
		s.right = add_weapon(base.right)
		stances.append(s)
	for base in starting_spares:
		add_weapon(base)

	if stances.is_empty():
		push_error("StanceManager has no starting stances. Add some in the Inspector.")
		return
	apply_active()


## Give the player their own copy of a weapon. Use this for rewards and pickups too.
func add_weapon(base: WeaponData) -> WeaponData:
	if base == null:
		return null
	var copy := base.duplicate() as WeaponData
	owned.append(copy)
	stances_edited.emit()
	return copy


func active_stance() -> Stance:
	return stances[active]


# Switching (allowed any time)

func set_active(index: int) -> void:
	if index == active or index < 0 or index >= stances.size():
		return
	active = index
	apply_active()


func cycle() -> void:
	set_active((active + 1) % stances.size())


## Puts the active stance's weapons into the hands.
func apply_active() -> void:
	var s := active_stance()
	_right.equip(s.right)
	if s.is_two_handed():
		_left.equip(null)
		_left.support(_right)
	else:
		_left.support(null)
		_left.equip(s.left)
	stance_changed.emit(active, s)


# Editing (only between waves; the editor calls these)

## Put `weapon` in a slot. Pass null to empty the slot.
func assign(stance_index: int, side: Hand.Slot, weapon: WeaponData) -> void:
	var s := stances[stance_index]
	if weapon:
		_remove_everywhere(weapon) # One weapon can only be in one slot.

	if s.is_two_handed():
		# A two-handed weapon fills both slots, so touching either slot replaces it.
		s.right = null

	if weapon and weapon.two_handed:
		s.left = null
		s.right = weapon
	elif side == Hand.Slot.LEFT:
		s.left = weapon
	else:
		s.right = weapon
	stances_edited.emit()


func swap_hands(stance_index: int) -> void:
	var s := stances[stance_index]
	if s.is_two_handed():
		return
	var old_left := s.left
	s.left = s.right
	s.right = old_left
	stances_edited.emit()


## Where a weapon currently is, for the editor's labels. Empty string if it's spare.
func where_is(weapon: WeaponData) -> String:
	for i in stances.size():
		var s := stances[i]
		if s.right == weapon:
			return "%s, %s" % [s.display_name, "both hands" if weapon.two_handed else "right"]
		if s.left == weapon:
			return "%s, left" % s.display_name
	return ""


func _remove_everywhere(weapon: WeaponData) -> void:
	for s in stances:
		if s.left == weapon:
			s.left = null
		if s.right == weapon:
			s.right = null
