@tool
class_name EffectDestroy3x3Center
extends GemEffect

func get_icon_targets(_board: BoardState, _origin: Vector2i) -> Array[Vector2i]:
	return [Vector2i(BoardState.ROWS / 2, BoardState.COLS / 2)]

func get_targets(board: BoardState, _origin: Vector2i, _other: Vector2i) -> Array[Vector2i]:
	var center := Vector2i(BoardState.ROWS / 2, BoardState.COLS / 2)
	var result: Array[Vector2i] = []
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var pos := center + Vector2i(dr, dc)
			if board.get_gem(pos.x, pos.y) != -1:
				result.append(pos)
	return result
