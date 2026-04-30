@tool
class_name SkillEffectActivateModifiers
extends SkillEffect

func get_targets(board: BoardState, _origin: Vector2i, _rank: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			if board.get_modifier(row, col) != BoardState.MOD_NONE:
				result.append(Vector2i(row, col))
	return result
