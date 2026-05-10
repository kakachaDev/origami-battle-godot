@tool
extends Resource
class_name BotData

@export var bot_name: String = "Bot"
@export_range(0, 4) var passive_gem_type: int = 0
@export var active_skills: Array[SkillData] = []
@export var active_skill_ranks: Array = []   # int per skill, parallel to active_skills
@export var active_skill_counts: Array = []  # initial use count per skill
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.5
@export_range(0, 200) var skill_use_deficit_threshold: int = 50
@export_range(0.0, 1.0, 0.01) var skill_use_chance: float = 0.5
