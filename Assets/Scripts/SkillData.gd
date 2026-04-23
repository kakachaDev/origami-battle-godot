@tool
extends Resource
class_name SkillData

@export var skill_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var skill_effect: Resource  # GemEffect
