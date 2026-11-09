## The thin stamina bar under the health bar.
## Hidden while stamina is full, fades in as soon as you sprint,
## and changes color while you're exhausted.
extends ProgressBar

## Fill color normally.
@export var normal_color : Color = Color(0.98, 0.85, 0.35)
## Fill color while exhausted (ran out, waiting to recover).
@export var exhausted_color : Color = Color(0.6, 0.6, 0.68)
## Seconds stamina must stay full before the bar fades out.
@export var hide_delay : float = 0.8
## Seconds for the fade in or out.
@export var fade_time : float = 0.25

var _fill_style : StyleBoxFlat
var _full_time : float = 0.0 # How long stamina has been full.
var _fade_tween : Tween
var _shown : bool = false


func _ready() -> void:
	# Our own copy of the fill, so recoloring it doesn't affect other bars.
	_fill_style = get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("fill", _fill_style)
	_fill_style.bg_color = normal_color
	modulate.a = 0.0

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("StaminaBar: no node in group 'player'")
		return
	player.stamina_changed.connect(_on_stamina_changed)
	player.exhausted_changed.connect(_on_exhausted_changed)
	_on_stamina_changed(player.stamina, player.max_stamina)


func _process(delta: float) -> void:
	# Count how long the bar has been full, then fade it out.
	if value >= max_value:
		_full_time += delta
		if _shown and _full_time >= hide_delay:
			_fade(false)
	else:
		_full_time = 0.0


func _on_stamina_changed(current: float, maximum: float) -> void:
	max_value = maximum
	value = current
	if current < maximum and not _shown:
		_fade(true)


func _on_exhausted_changed(is_exhausted: bool) -> void:
	_fill_style.bg_color = exhausted_color if is_exhausted else normal_color


func _fade(show_bar: bool) -> void:
	_shown = show_bar
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_ignore_time_scale(true)
	_fade_tween.tween_property(self, "modulate:a", 1.0 if show_bar else 0.0, fade_time)
