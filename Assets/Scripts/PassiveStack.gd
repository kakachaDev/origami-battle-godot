@tool
extends Control
class_name PassiveStack

@export var stack_data: PassiveStackData:
	set(v):
		stack_data = v
		_rebuild()

@export_range(1, 10) var max_count: int = 7:
	set(v):
		max_count = clampi(v, 1, 10)
		_rebuild()

@export_range(0, 10) var current_count: int = 0:
	set(v):
		current_count = clampi(v, 0, max_count)
		if not _skip_update:
			_update_states()

@export var icon_size: float = 48.0:
	set(v):
		icon_size = maxf(v, 1.0)
		_rebuild()

@export var max_spacing: float = 10.0:
	set(v):
		max_spacing = v
		_update_layout()

@export var reverse: bool = false:
	set(v):
		reverse = v
		_update_states()

var _slots: Array[Control] = []
var _skip_update := false

func _ready() -> void:
	_rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _rebuild() -> void:
	if not is_node_ready():
		return
	for child in get_children():
		child.free()
	_slots.clear()

	if stack_data == null:
		return

	for i in max_count:
		var container := Control.new()
		container.name = "Slot%d" % (i + 1)

		var bg := TextureRect.new()
		bg.name = "Bg"
		bg.texture = stack_data.sprite_disabled
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(bg)

		var fg := TextureRect.new()
		fg.name = "Fg"
		fg.texture = stack_data.sprite_active
		fg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fg.scale = Vector2.ZERO
		container.add_child(fg)

		add_child(container)
		_slots.append(container)

	_update_layout()
	_update_states()

func _update_layout() -> void:
	if _slots.is_empty() or size.x == 0:
		return
	var n := _slots.size()
	var spacing: float
	if n <= 1:
		spacing = 0.0
	else:
		spacing = minf((size.x - icon_size * n) / (n - 1), max_spacing)

	var total_w := icon_size * n + spacing * (n - 1)
	var start_x := (size.x - total_w) / 2.0
	var y := (size.y - icon_size) / 2.0

	for i in n:
		_slots[i].position = Vector2(start_x + i * (icon_size + spacing), y)
		_slots[i].size = Vector2(icon_size, icon_size)
		var bg := _slots[i].get_node("Bg") as TextureRect
		var fg := _slots[i].get_node("Fg") as TextureRect
		if bg:
			bg.position = Vector2.ZERO
			bg.size = Vector2(icon_size, icon_size)
		if fg:
			fg.position = Vector2.ZERO
			fg.size = Vector2(icon_size, icon_size)
			fg.pivot_offset = Vector2(icon_size * 0.5, icon_size * 0.5)

func _update_states() -> void:
	if not is_node_ready() or stack_data == null:
		return
	for i in _slots.size():
		var fg := _slots[i].get_node("Fg") as TextureRect
		if fg:
			fg.scale = Vector2.ONE if _slot_active(i, current_count) else Vector2.ZERO

func _slot_active(i: int, count: int) -> bool:
	var n := _slots.size()
	return i < count if reverse else i >= n - count

func set_count_animated(new_count: int) -> void:
	if Engine.is_editor_hint():
		current_count = new_count
		return
	_skip_update = true
	var old_count := current_count
	current_count = clampi(new_count, 0, max_count)
	_skip_update = false

	for i in _slots.size():
		var was := _slot_active(i, old_count)
		var now := _slot_active(i, current_count)
		if was == now:
			continue
		var fg := _slots[i].get_node("Fg") as TextureRect
		if fg == null:
			continue
		var tween := create_tween()
		if now:
			fg.scale = Vector2.ZERO
			tween.tween_property(fg, "scale", Vector2(1.2, 1.2), 0.12)
			tween.tween_property(fg, "scale", Vector2.ONE, 0.08)
		else:
			tween.tween_property(fg, "scale", Vector2.ZERO, 0.15)
