@tool
class_name EffectDestroyRow
extends GemEffect

func get_targets(board: BoardState, origin: Vector2i, _other: Vector2i) -> Array[Vector2i]:
	return board.get_bomb_lr_positions(origin.x)
