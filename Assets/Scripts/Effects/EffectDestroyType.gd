@tool
class_name EffectDestroyType
extends GemEffect

# Destroys all gems matching the type at `other`, plus `origin` itself.
func get_targets(board: BoardState, origin: Vector2i, other: Vector2i) -> Array[Vector2i]:
	if other == Vector2i(-1, -1):
		return []
	var gem_type := board.get_gem(other.x, other.y)
	if gem_type == -1:
		return []
	var result := board.get_all_positions_of_type(gem_type)
	if not result.has(origin):
		result.append(origin)
	return result
