@tool
class_name EffectDestroyAllField
extends GemEffect

func get_targets(board: BoardState, _origin: Vector2i, _other: Vector2i) -> Array[Vector2i]:
	return board.get_all_positions()
