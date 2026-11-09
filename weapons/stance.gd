## One loadout: what's in the left hand and what's in the right hand.
## A two-handed weapon always lives in `right`, and `left` stays empty.
class_name Stance
extends Resource

@export var display_name : String = "Stance"
@export var left : WeaponData
@export var right : WeaponData


func is_two_handed() -> bool:
	return right != null and right.two_handed
