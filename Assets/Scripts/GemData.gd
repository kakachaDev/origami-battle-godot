@tool
extends Resource
class_name GemData

@export var gem_name: String = ""
@export var sprite_base: Texture2D
@export var sprite_modified: Texture2D
## True for Applebomb (wildcard gem): has no _modified state, cannot have a modifier applied
@export var is_multicolor: bool = false
