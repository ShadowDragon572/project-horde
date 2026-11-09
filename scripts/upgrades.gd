class_name Upgrades
extends RefCounted

## To add an upgrade: 1) add an entry to POOL, 2) add a matching branch in apply().
## max_stacks of 0 means unlimited.
const POOL := [
	{
		"id": "pierce",
		"name": "Piercing Rounds",
		"description": "Shots pass through 1 more enemy.",
		"max_stacks": 0,
	},
	{
		"id": "damage",
		"name": "Heavy Rounds",
		"description": "+1 damage per shot.",
		"max_stacks": 0,
	},
	{
		"id": "reload",
		"name": "Quick Hands",
		"description": "Reload 15% faster.",
		"max_stacks": 5,
	},
	{
		"id": "magazine",
		"name": "Extended Mag",
		"description": "+4 magazine size.",
		"max_stacks": 0,
	},
	{
		"id": "health",
		"name": "Vitality",
		"description": "+20 max health and heal 20.",
		"max_stacks": 0,
	},
	{
		"id": "speed",
		"name": "Fleet Foot",
		"description": "+8% move speed.",
		"max_stacks": 5,
	},
]


static func apply(id: String, player) -> void:
	match id:
		"pierce":
			player.pierce += 1
		"damage":
			player.damage += 1
		"reload":
			player.reload_time_multiplier *= 0.85
		"magazine":
			player.magazine_bonus += 4
			# Top up every owned gun so the extra rounds are usable right away.
			for weapon in player.stance_manager.owned:
				if weapon.kind == WeaponData.Kind.GUN and weapon.current_ammo >= 0:
					weapon.current_ammo += 4
			# Refresh the HUD for whatever is in each hand right now.
			for hand in [player.hand_left, player.hand_right]:
				if hand.weapon and hand.weapon.kind == WeaponData.Kind.GUN:
					hand.ammo_changed.emit(hand.weapon.current_ammo, hand.magazine_size())
		"health":
			player.max_health += 20
			player.heal(20)
		"speed":
			player.base_speed *= 1.08
			player.sprint_speed *= 1.08
