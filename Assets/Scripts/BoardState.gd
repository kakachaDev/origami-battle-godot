extends RefCounted
class_name BoardState

const COLS := 7
const ROWS := 7
const GEM_COUNT := 5  # Red, Blue, Green, Pink, Banana

var grid: Array  # grid[row][col]: int, -1 = empty

func _init() -> void:
	grid = []
	for row in ROWS:
		var r: Array = []
		r.resize(COLS)
		r.fill(-1)
		grid.append(r)
	for row in ROWS:
		for col in COLS:
			grid[row][col] = _pick_gem(row, col)

func _pick_gem(row: int, col: int) -> int:
	for _attempt in 50:
		var gem := randi() % GEM_COUNT
		if not _would_match(row, col, gem):
			return gem
	return randi() % GEM_COUNT

func _would_match(row: int, col: int, gem: int) -> bool:
	if col >= 2 and grid[row][col - 1] == gem and grid[row][col - 2] == gem:
		return true
	if row >= 2 and grid[row - 1][col] == gem and grid[row - 2][col] == gem:
		return true
	return false

func get_gem(row: int, col: int) -> int:
	return grid[row][col]

func swap(a: Vector2i, b: Vector2i) -> void:
	var tmp: int = grid[a.x][a.y]
	grid[a.x][a.y] = grid[b.x][b.y]
	grid[b.x][b.y] = tmp

func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := (b - a).abs()
	return (d.x == 1 and d.y == 0) or (d.x == 0 and d.y == 1)

func find_matches() -> Array[Vector2i]:
	var hits: Dictionary = {}
	for row in ROWS:
		var run := 0
		for col in range(1, COLS + 1):
			var end: bool = col == COLS or grid[row][col] != grid[row][run] or grid[row][col] == -1
			if end:
				if col - run >= 3:
					for c in range(run, col):
						hits[Vector2i(row, c)] = true
				run = col
	for col in COLS:
		var run := 0
		for row in range(1, ROWS + 1):
			var end: bool = row == ROWS or grid[row][col] != grid[run][col] or grid[row][col] == -1
			if end:
				if row - run >= 3:
					for r in range(run, row):
						hits[Vector2i(r, col)] = true
				run = row
	var result: Array[Vector2i] = []
	for key in hits:
		result.append(key)
	return result

func clear_matches(matches: Array[Vector2i]) -> void:
	for pos in matches:
		grid[pos.x][pos.y] = -1

func apply_gravity() -> Array:
	# Returns Array of {from: Vector2i, to: Vector2i}, bottom-up order
	var falls: Array = []
	for col in COLS:
		var empty := ROWS - 1
		for row in range(ROWS - 1, -1, -1):
			if grid[row][col] != -1:
				if row != empty:
					falls.append({"from": Vector2i(row, col), "to": Vector2i(empty, col)})
					grid[empty][col] = grid[row][col]
					grid[row][col] = -1
				empty -= 1
	return falls

func fill_empty() -> Array:
	# Returns Array of {pos: Vector2i, gem: int}, top-to-bottom order
	var spawns: Array = []
	for row in ROWS:
		for col in COLS:
			if grid[row][col] == -1:
				var gem := randi() % GEM_COUNT
				grid[row][col] = gem
				spawns.append({"pos": Vector2i(row, col), "gem": gem})
	return spawns
