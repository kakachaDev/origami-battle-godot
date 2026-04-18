@tool
extends Resource
class_name SkillData

enum SkillType {
	CUBE,
	LUBE,
	HAND,
	BALOON,
	BOTLE,
	FLOWER,
	HAMMER40K,
	SPHERE,
}

const _ICON_PATHS: Dictionary = {
	SkillType.CUBE: "res://Assets/Sprites/Skills/SkillIcons/Cube.png",
	SkillType.LUBE: "res://Assets/Sprites/Skills/SkillIcons/Lube.png",
	SkillType.HAND: "res://Assets/Sprites/Skills/SkillIcons/Hand.png",
	SkillType.BALOON: "res://Assets/Sprites/Skills/SkillIcons/Baloon.png",
	SkillType.BOTLE: "res://Assets/Sprites/Skills/SkillIcons/Botle.png",
	SkillType.FLOWER: "res://Assets/Sprites/Skills/SkillIcons/Flower.png",
	SkillType.HAMMER40K: "res://Assets/Sprites/Skills/SkillIcons/Hammer40k.png",
	SkillType.SPHERE: "res://Assets/Sprites/Skills/SkillIcons/Sphere.png",
}

@export var skill_type: SkillType = SkillType.CUBE:
	set(value):
		skill_type = value
		icon = load(_ICON_PATHS[value])

@export var skill_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
