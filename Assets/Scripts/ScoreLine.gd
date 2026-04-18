@tool
extends Control
class_name ScoreLine

@export var min_value: float = -100.0
@export var max_value: float = 100.0

@export var value: float = 0.0:
	set(v):
		value = clampf(v, min_value, max_value)
		_update_point_sprite()

@export var point_sprite_positive: Texture2D:
	set(v):
		point_sprite_positive = v
		_update_point_sprite()

@export var point_sprite_negative: Texture2D:
	set(v):
		point_sprite_negative = v
		_update_point_sprite()

@export var smooth_speed: float = 5.0

var _display_ratio: float = 0.5

func _ready() -> void:
	_display_ratio = _value_to_ratio(value)
	_apply_ratio(_display_ratio)
	_update_point_sprite()

func _process(delta: float) -> void:
	var target_ratio := _value_to_ratio(value)
	if smooth_speed <= 0.0:
		if _display_ratio != target_ratio:
			_display_ratio = target_ratio
			_apply_ratio(_display_ratio)
		return
	if absf(_display_ratio - target_ratio) < 0.001:
		return
	_display_ratio = lerpf(_display_ratio, target_ratio, smooth_speed * delta)
	_apply_ratio(_display_ratio)

func _value_to_ratio(v: float) -> float:
	if is_equal_approx(max_value, min_value):
		return 0.5
	return (v - min_value) / (max_value - min_value)

func _apply_ratio(ratio: float) -> void:
	var fg := get_node_or_null("Foreground") as ColorRect
	if fg == null:
		return
	fg.anchor_right = ratio
	fg.offset_right = 0.0

func _update_point_sprite() -> void:
	if not is_node_ready():
		return
	var point := get_node_or_null("Foreground/Point") as TextureRect
	if point == null:
		return
	point.texture = point_sprite_negative if value < 0.0 else point_sprite_positive
