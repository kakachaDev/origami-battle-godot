@tool
extends TextureButton
class_name ActiveSkillBase

@export var skill_data: SkillData:
	set(value):
		skill_data = value
		_update_visuals()

@export_range(1, 3) var rank: int = 1:
	set(value):
		rank = clampi(value, 1, 3)
		_update_rank()

@export var count: int = 0:
	set(value):
		count = value
		_update_count()

func _ready() -> void:
	_update_visuals()

func _update_visuals() -> void:
	if not is_node_ready():
		return
	_update_icon()
	_update_rank()
	_update_count()

func _update_icon() -> void:
	var icon_node := get_node_or_null("Icon") as TextureRect
	if icon_node == null:
		return
	icon_node.texture = skill_data.icon if skill_data else null

func _update_rank() -> void:
	if not is_node_ready():
		return
	var rank_node := get_node_or_null("Rank") as HBoxContainer
	if rank_node == null:
		return
	var stars := rank_node.get_children()
	for i in stars.size():
		(stars[i] as TextureRect).visible = i < rank

func _update_count() -> void:
	if not is_node_ready():
		return
	var text_node := get_node_or_null("Count/Text") as Label
	if text_node == null:
		return
	text_node.text = str(count)
	var empty := count == 0
	disabled = empty
	modulate = Color("#7b7b7b") if empty else Color.WHITE
