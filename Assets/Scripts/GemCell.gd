@tool
extends Control
class_name GemCell

@export var gem_data: GemData:
	set(v):
		gem_data = v
		_update_visuals()

@export var modifier_data: ModifierData:
	set(v):
		modifier_data = v
		_update_visuals()

func _ready() -> void:
	_update_visuals()

func _update_visuals() -> void:
	if not is_node_ready():
		return
	_update_gem()
	_update_modifier()

func _update_gem() -> void:
	var gem := get_node_or_null("Gem") as TextureRect
	if gem == null:
		return
	if gem_data == null:
		gem.texture = null
		return
	var has_modifier := modifier_data != null and not gem_data.is_multicolor
	gem.texture = gem_data.sprite_modified if has_modifier else gem_data.sprite_base

func _update_modifier() -> void:
	var mod_node := get_node_or_null("GemModificator") as TextureRect
	if mod_node == null:
		return
	if modifier_data == null or (gem_data != null and gem_data.is_multicolor):
		mod_node.visible = false
		mod_node.texture = null
	else:
		mod_node.visible = true
		mod_node.texture = modifier_data.sprite
