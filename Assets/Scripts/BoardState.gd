extends RefCounted
class_name BoardState

const COLS := 7
const ROWS := 7
const GEM_COUNT := 5  # Red, Blue, Green, Pink, Banana
const APPLEBOMB_TYPE := 5

const MOD_NONE := -1
const MOD_BOMB_LR := 0
const MOD_BOMB_UD := 1

const SPAWN_NONE := 0
const SPAWN_BOMB_LR := 1
const SPAWN_BOMB_UD := 2
const SPAWN_APPLEBOMB := 3

var grid: Array          # grid[row][col]: int, -1 = empty
var modifier_grid: Array # modifier_grid[row][col]: int, MOD_NONE / MOD_BOMB_LR / MOD_BOMB_UD

func _init() -> void:
	grid = []
	modifier_grid = []
	for row in ROWS:
		var r: Array = []
		r.resize(COLS)
		r.fill(-1)
		grid.append(r)
		var m: Array = []
		m.resize(COLS)
		m.fill(MOD_NONE)
		modifier_grid.append(m)
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

func get_modifier(row: int, col: int) -> int:
	return modifier_grid[row][col]

func set_modifier(row: int, col: int, mod: int) -> void:
	modifier_grid[row][col] = mod

func place_gem(row: int, col: int, gem_type: int, mod: int = MOD_NONE) -> void:
	grid[row][col] = gem_type
	modifier_grid[row][col] = mod

func swap(a: Vector2i, b: Vector2i) -> void:
	var tmp_gem: int = grid[a.x][a.y]
	grid[a.x][a.y] = grid[b.x][b.y]
	grid[b.x][b.y] = tmp_gem
	var tmp_mod: int = modifier_grid[a.x][a.y]
	modifier_grid[a.x][a.y] = modifier_grid[b.x][b.y]
	modifier_grid[b.x][b.y] = tmp_mod

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

# Returns Array of {positions: Array[Vector2i], spawn_pos: Vector2i, spawn_type: int}
func find_match_groups() -> Array:
	# Phase 1: collect raw runs of length >= 3
	var raw_runs: Array = []

	for row in ROWS:
		var run_start := 0
		for col in range(1, COLS + 1):
			var end: bool = col == COLS or grid[row][col] != grid[row][run_start] or grid[row][col] == -1
			if end:
				if col - run_start >= 3:
					var pos_arr: Array[Vector2i] = []
					for c in range(run_start, col):
						pos_arr.append(Vector2i(row, c))
					raw_runs.append({"positions": pos_arr, "dir": "H"})
				run_start = col

	for col in COLS:
		var run_start := 0
		for row in range(1, ROWS + 1):
			var end: bool = row == ROWS or grid[row][col] != grid[run_start][col] or grid[row][col] == -1
			if end:
				if row - run_start >= 3:
					var pos_arr: Array[Vector2i] = []
					for r in range(run_start, row):
						pos_arr.append(Vector2i(r, col))
					raw_runs.append({"positions": pos_arr, "dir": "V"})
				run_start = row

	if raw_runs.is_empty():
		return []

	# Phase 2: union-find — merge runs sharing at least one cell
	var pos_to_runs: Dictionary = {}
	for i in raw_runs.size():
		for pos in raw_runs[i].positions:
			if not pos_to_runs.has(pos):
				pos_to_runs[pos] = []
			pos_to_runs[pos].append(i)

	var parent: Array = []
	parent.resize(raw_runs.size())
	for i in raw_runs.size():
		parent[i] = i

	for pos in pos_to_runs:
		var indices: Array = pos_to_runs[pos]
		if indices.size() > 1:
			var root_a: int = indices[0]
			while parent[root_a] != root_a:
				root_a = parent[root_a]
			for i in range(1, indices.size()):
				var root_b: int = indices[i]
				while parent[root_b] != root_b:
					root_b = parent[root_b]
				if root_a != root_b:
					parent[root_b] = root_a

	for i in raw_runs.size():
		var r := i
		while parent[r] != r:
			r = parent[r]
		parent[i] = r

	var root_to_runs: Dictionary = {}
	for i in raw_runs.size():
		var root: int = parent[i]
		if not root_to_runs.has(root):
			root_to_runs[root] = []
		root_to_runs[root].append(i)

	# Phase 3: classify each merged group
	var groups: Array = []
	for root in root_to_runs:
		var run_indices: Array = root_to_runs[root]

		var pos_set: Dictionary = {}
		for ri in run_indices:
			for pos in raw_runs[ri].positions:
				pos_set[pos] = true

		var all_positions: Array[Vector2i] = []
		for pos in pos_set:
			all_positions.append(pos)

		var h_run_indices: Array = []
		var v_run_indices: Array = []
		for ri in run_indices:
			if raw_runs[ri].dir == "H":
				h_run_indices.append(ri)
			else:
				v_run_indices.append(ri)

		var total := all_positions.size()
		var spawn_pos := Vector2i(-1, -1)
		var spawn_type := SPAWN_NONE

		if total >= 5 or (h_run_indices.size() > 0 and v_run_indices.size() > 0):
			spawn_type = SPAWN_APPLEBOMB
			if h_run_indices.size() > 0 and v_run_indices.size() > 0:
				var h_set: Dictionary = {}
				for ri in h_run_indices:
					for pos in raw_runs[ri].positions:
						h_set[pos] = true
				var found := false
				for ri in v_run_indices:
					for pos in raw_runs[ri].positions:
						if h_set.has(pos):
							spawn_pos = pos
							found = true
							break
					if found:
						break
			if spawn_pos == Vector2i(-1, -1):
				# Straight 5+ with no perpendicular run — center of longest run
				var longest_run: Array = raw_runs[run_indices[0]].positions
				for ri in run_indices:
					if raw_runs[ri].positions.size() > longest_run.size():
						longest_run = raw_runs[ri].positions
				spawn_pos = longest_run[longest_run.size() / 2]
		elif total == 4:
			var run: Dictionary = raw_runs[run_indices[0]]
			spawn_pos = run.positions[run.positions.size() / 2]
			spawn_type = SPAWN_BOMB_LR if run.dir == "H" else SPAWN_BOMB_UD

		groups.append({"positions": all_positions, "spawn_pos": spawn_pos, "spawn_type": spawn_type})

	return groups

func clear_matches(matches: Array[Vector2i]) -> void:
	for pos in matches:
		grid[pos.x][pos.y] = -1
		modifier_grid[pos.x][pos.y] = MOD_NONE

func apply_gravity() -> Array:
	var falls: Array = []
	for col in COLS:
		var empty := ROWS - 1
		for row in range(ROWS - 1, -1, -1):
			if grid[row][col] != -1:
				if row != empty:
					falls.append({"from": Vector2i(row, col), "to": Vector2i(empty, col)})
					grid[empty][col] = grid[row][col]
					modifier_grid[empty][col] = modifier_grid[row][col]
					grid[row][col] = -1
					modifier_grid[row][col] = MOD_NONE
				empty -= 1
	return falls

func fill_empty() -> Array:
	var spawns: Array = []
	for row in ROWS:
		for col in COLS:
			if grid[row][col] == -1:
				var gem := randi() % GEM_COUNT
				grid[row][col] = gem
				spawns.append({"pos": Vector2i(row, col), "gem": gem})
	return spawns

func get_bomb_lr_positions(row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for col in COLS:
		if grid[row][col] != -1:
			result.append(Vector2i(row, col))
	return result

func get_bomb_ud_positions(col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in ROWS:
		if grid[row][col] != -1:
			result.append(Vector2i(row, col))
	return result

func get_all_positions_of_type(gem_type: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in ROWS:
		for col in COLS:
			if grid[row][col] == gem_type:
				result.append(Vector2i(row, col))
	return result

func get_all_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in ROWS:
		for col in COLS:
			if grid[row][col] != -1:
				result.append(Vector2i(row, col))
	return result

# Expands destroy set by following bomb chains. Call BEFORE clear_matches.
func expand_bomb_chain(initial: Array[Vector2i]) -> Array[Vector2i]:
	var to_destroy: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for pos in initial:
		if not to_destroy.has(pos):
			to_destroy[pos] = true
			frontier.append(pos)
	var i := 0
	while i < frontier.size():
		var pos: Vector2i = frontier[i]
		i += 1
		var mod: int = modifier_grid[pos.x][pos.y]
		var new_positions: Array[Vector2i] = []
		if mod == MOD_BOMB_LR:
			new_positions = get_bomb_lr_positions(pos.x)
		elif mod == MOD_BOMB_UD:
			new_positions = get_bomb_ud_positions(pos.y)
		for np in new_positions:
			if not to_destroy.has(np):
				to_destroy[np] = true
				frontier.append(np)
	var result: Array[Vector2i] = []
	for pos in to_destroy:
		result.append(pos)
	return result
