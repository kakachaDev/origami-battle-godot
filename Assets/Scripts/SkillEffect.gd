@tool
class_name SkillEffect
extends Resource

enum ActivationType { INSTANT = 0, PICK_GEM = 1 }

@export var activation_type: ActivationType = ActivationType.INSTANT

# origin = clicked gem pos (Vector2i(-1,-1) for INSTANT skills), rank = 1..3
func get_targets(board: BoardState, origin: Vector2i, rank: int) -> Array[Vector2i]:
	return []

# Returns Array of {pos, mod, gem} to apply as modifier_set events before destruction.
func get_modifier_spreads(board: BoardState, origin: Vector2i, rank: int) -> Array:
	return []
