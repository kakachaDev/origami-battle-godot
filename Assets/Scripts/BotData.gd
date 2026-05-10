@tool
extends Resource
class_name BotData

@export var bot_name: String = "Bot"
@export_range(0, 4) var passive_gem_type: int = 0
@export var active_skills: Array[SkillData] = []
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.5
