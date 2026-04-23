@tool
class_name EffectApplyRandomModifiers
extends GemEffect

const APPLY_COUNT := 2

func apply_to_board(board: BoardState, _origin: Vector2i, _other: Vector2i) -> void:
	var candidates: Array[Vector2i] = []
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			var gem := board.get_gem(row, col)
			if gem != -1 and gem != BoardState.APPLEBOMB_TYPE and board.get_modifier(row, col) == BoardState.MOD_NONE:
				candidates.append(Vector2i(row, col))
	candidates.shuffle()
	for i in mini(APPLY_COUNT, candidates.size()):
		board.set_modifier(candidates[i].x, candidates[i].y, randi() % 2)

func get_targets(_board: BoardState, _origin: Vector2i, _other: Vector2i) -> Array[Vector2i]:
	return []
