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

var _slots: Array[TextureRect] = []

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
		var slot := TextureRect.new()
		slot.name = "Slot%d" % (i + 1)
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(slot)
		_slots.append(slot)

	_update_layout()
	_update_states()

func _update_layout() -> void:
	if _slots.is_empty() or size.x == 0:
		return
	var n := _slots.size()
	var w := size.x
	var h := size.y

	var spacing: float
	if n <= 1:
		spacing = 0.0
	else:
		# Reduce spacing if total overflows parent; allow negative (overlap) if necessary
		spacing = minf((w - icon_size * n) / (n - 1), max_spacing)

	var total_w := icon_size * n + spacing * (n - 1)
	var start_x := (w - total_w) / 2.0
	var y := (h - icon_size) / 2.0

	for i in n:
		_slots[i].position = Vector2(start_x + i * (icon_size + spacing), y)
		_slots[i].size = Vector2(icon_size, icon_size)

func _update_states() -> void:
	if not is_node_ready() or stack_data == null:
		return
	var n := _slots.size()
	for i in n:
		var is_active: bool
		if reverse:
			is_active = i < current_count
		else:
			is_active = i >= n - current_count
		_slots[i].texture = stack_data.sprite_active if is_active else stack_data.sprite_disabled
