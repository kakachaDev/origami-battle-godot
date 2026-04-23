@tool
class_name EffectApplyRandomModifiers
extends GemEffect

const APPLY_COUNT := 2

# Pre-select target positions so icons know where to fly before landing.
func get_icon_targets(board: BoardState, _origin: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			var gem := board.get_gem(row, col)
			if gem != -1 and gem != BoardState.APPLEBOMB_TYPE and board.get_modifier(row, col) == BoardState.MOD_NONE:
				candidates.append(Vector2i(row, col))
	candidates.shuffle()
	var result: Array[Vector2i] = []
	for i in mini(APPLY_COUNT, candidates.size()):
		result.append(candidates[i])
	return result

func apply_to_board(_board: BoardState, _origin: Vector2i, _other: Vector2i) -> void:
	pass  # Applied per-icon via GameBoard.apply_modifier_to_cell on landing

func get_targets(_board: BoardState, _origin: Vector2i, _other: Vector2i) -> Array[Vector2i]:
	return []
