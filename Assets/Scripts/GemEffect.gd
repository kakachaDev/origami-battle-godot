@tool
class_name GemEffect
extends Resource

# origin = position of the gem that owns this effect (row, col as Vector2i)
# other  = position of the second gem (swap target), or Vector2i(-1,-1) if not applicable
func get_targets(board: BoardState, origin: Vector2i, other: Vector2i) -> Array[Vector2i]:
	return []
