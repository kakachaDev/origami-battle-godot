@tool
class_name EffectApplyRandomModifiers
extends GemEffect

func apply_to_board(board: BoardState, _origin: Vector2i, _other: Vector2i) -> void:
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			var gem := board.get_gem(row, col)
			if gem != -1 and gem != BoardState.APPLEBOMB_TYPE and board.get_modifier(row, col) == BoardState.MOD_NONE:
				board.set_modifier(row, col, randi() % 2)

func get_targets(_board: BoardState, _origin: Vector2i, _other: Vector2i) -> Array[Vector2i]:
	return []
