## One corner of the HUD: shows what a hand is holding, its ammo, its reload,
## and which keys use it right now.
## Fonts, sizes and the panel style come from res://assets/theme/main_theme.tres.
extends PanelContainer

## Ammo text turns this color when the magazine is nearly empty.
const LOW_AMMO_COLOR := Color(1, 0.35, 0.3)
## The ammo line for melee weapons ("Melee") is drawn this faint.
const MELEE_TEXT_COLOR := Color(1, 1, 1, 0.55)

@export var side : Hand.Slot = Hand.Slot.RIGHT

var _reload_tween : Tween
var _weapon : WeaponData  # What this hand holds, so the key hint knows if it can reload.
var _two_handed : bool = false

@onready var icon : TextureRect = %Icon
@onready var name_label : Label = %NameLabel
@onready var ammo_label : Label = %AmmoLabel
@onready var reload_bar : ProgressBar = %ReloadBar
@onready var keys_label : Label = %KeysLabel


func _ready() -> void:
	# The right panel mirrors the left one: text hugs the right edge, icon on the outside.
	if side == Hand.Slot.RIGHT:
		for label in [name_label, ammo_label, keys_label]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		icon.get_parent().move_child(icon, -1)


func bind(hand: Hand, manager: StanceManager) -> void:
	hand.weapon_changed.connect(_on_weapon_changed)
	hand.ammo_changed.connect(_on_ammo_changed)
	hand.reload_started.connect(_on_reload_started)
	hand.reload_finished.connect(_on_reload_finished)
	manager.stance_changed.connect(_on_stance_changed)
	_show_reload_bar(false)
	# The hand may already be holding something by the time we connect.
	_on_weapon_changed(hand.weapon)
	if hand.weapon:
		_on_ammo_changed(hand.weapon.current_ammo, hand.magazine_size())
	_on_stance_changed(manager.active, manager.active_stance())


func _on_weapon_changed(weapon: WeaponData) -> void:
	_on_reload_finished()
	_weapon = weapon
	_update_keys()
	icon.texture = weapon.icon if weapon else null
	# No icon means no empty 64 px gap: the text moves over to the edge.
	icon.visible = icon.texture != null
	name_label.text = UIKit.weapon_name(weapon)
	# The ammo line always keeps its space, so both corner panels stay the same height.
	# Guns fill it in _on_ammo_changed(), which the hand sends right after this.
	if weapon and weapon.kind == WeaponData.Kind.MELEE:
		ammo_label.text = "Melee"
		ammo_label.modulate = MELEE_TEXT_COLOR
	elif weapon == null:
		ammo_label.text = " "


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	if max_ammo < 0:
		return
	ammo_label.text = "%d / %d" % [current, max_ammo]
	# Turn red when the magazine is nearly empty.
	ammo_label.modulate = LOW_AMMO_COLOR if current * 4 <= max_ammo else Color.WHITE


func _on_reload_started(duration: float) -> void:
	_show_reload_bar(true)
	reload_bar.value = 0.0
	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween()
	_reload_tween.tween_property(reload_bar, "value", reload_bar.max_value, duration)


func _on_reload_finished() -> void:
	if _reload_tween:
		_reload_tween.kill()
	_show_reload_bar(false)


## Fades the bar instead of hiding it, so it keeps its space
## and the panel doesn't change height every reload.
func _show_reload_bar(on: bool) -> void:
	reload_bar.modulate.a = 1.0 if on else 0.0


func _on_stance_changed(_index: int, stance: Stance) -> void:
	_two_handed = stance.is_two_handed()
	if side == Hand.Slot.LEFT:
		# The two-handed weapon is shown on the right panel only.
		visible = not _two_handed
	_update_keys()


## "LMB  ·  reload Q". Melee weapons (and empty hands) can't reload, so they only show the attack key.
func _update_keys() -> void:
	var fire : String
	var reload : String
	if side == Hand.Slot.LEFT:
		fire = UIKit.key_text("fire_left")
		reload = UIKit.key_text("reload_left")
	elif _two_handed:
		# A two-handed weapon answers to both buttons and both reload keys.
		fire = "%s / %s" % [UIKit.key_text("fire_left"), UIKit.key_text("fire_right")]
		reload = "%s / %s" % [UIKit.key_text("reload_left"), UIKit.key_text("reload_right")]
	else:
		fire = UIKit.key_text("fire_right")
		reload = UIKit.key_text("reload_right")

	if _weapon and _weapon.kind == WeaponData.Kind.GUN:
		keys_label.text = "%s  ·  reload %s" % [fire, reload]
	else:
		keys_label.text = fire
