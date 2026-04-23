@tool
class_name EffectDestroyColumn
extends GemEffect

func get_targets(board: BoardState, origin: Vector2i, _other: Vector2i) -> Array[Vector2i]:
	return board.get_bomb_ud_positions(origin.y)
