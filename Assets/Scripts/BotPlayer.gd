extends Node
class_name BotPlayer

const BotDataRes = preload("res://Assets/Scripts/BotData.gd")

@export var bot_data: BotDataRes

@onready var _manager: GameManager = $"../GameManager"
@onready var _board: GameBoard = $"../Bottom/GameField/Gems"

func _ready() -> void:
	if bot_data != null and bot_data.passive_gem_type >= 0:
		_manager.r_passive_gem_type = bot_data.passive_gem_type
	_manager.turns_updated.connect(_on_turns_updated)

func _on_turns_updated(_l: int, _r: int, player: int, _round: int) -> void:
	if player == GameManager.RIGHT:
		_play_bot_turn()

func _play_bot_turn() -> void:
	while _board.is_busy:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	if _manager.current_player != GameManager.RIGHT or _board.is_busy:
		return
	var swap := _pick_swap()
	if swap.size() == 2:
		_board.execute_bot_swap(swap[0], swap[1])

func _pick_swap() -> Array:
	var state := _board.board_state
	if state == null:
		return []

	var swaps: Array = []
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			if col + 1 < BoardState.COLS:
				var a := Vector2i(row, col)
				var b := Vector2i(row, col + 1)
				swaps.append({"a": a, "b": b, "score": _evaluate_swap(state, a, b)})
			if row + 1 < BoardState.ROWS:
				var a := Vector2i(row, col)
				var b := Vector2i(row + 1, col)
				swaps.append({"a": a, "b": b, "score": _evaluate_swap(state, a, b)})

	if swaps.is_empty():
		return []

	swaps.sort_custom(func(x, y): return x.score > y.score)

	var d := clampf(bot_data.difficulty if bot_data != null else 0.5, 0.0, 1.0)
	var idx := roundi((1.0 - d) * (swaps.size() - 1))
	var chosen: Dictionary = swaps[idx]
	return [chosen.a, chosen.b]

func _evaluate_swap(state: BoardState, pos_a: Vector2i, pos_b: Vector2i) -> int:
	var grid: Array = []
	for row in BoardState.ROWS:
		grid.append(state.grid[row].duplicate())
	var tmp: int = grid[pos_a.x][pos_a.y]
	grid[pos_a.x][pos_a.y] = grid[pos_b.x][pos_b.y]
	grid[pos_b.x][pos_b.y] = tmp
	return _count_matches(grid)

func _count_matches(grid: Array) -> int:
	var hits: Dictionary = {}
	for row in BoardState.ROWS:
		var run := 0
		for col in range(1, BoardState.COLS + 1):
			var end: bool = col == BoardState.COLS or grid[row][col] != grid[row][run] or grid[row][col] == -1
			if end:
				if col - run >= 3:
					for c in range(run, col):
						hits[Vector2i(row, c)] = true
				run = col
	for col in BoardState.COLS:
		var run := 0
		for row in range(1, BoardState.ROWS + 1):
			var end: bool = row == BoardState.ROWS or grid[row][col] != grid[run][col] or grid[row][col] == -1
			if end:
				if row - run >= 3:
					for r in range(run, row):
						hits[Vector2i(r, col)] = true
				run = row
	return hits.size()
