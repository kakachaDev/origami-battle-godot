extends Node
class_name BotPlayer

const BotDataRes = preload("res://Assets/Scripts/BotData.gd")

@export var bot_data: BotDataRes

@onready var _manager: GameManager = $"../GameManager"
@onready var _board: GameBoard = $"../Bottom/GameField/Gems"

var _skill_counts: Array = []

func _ready() -> void:
	if bot_data != null and bot_data.passive_gem_type >= 0:
		_manager.r_passive_gem_type = bot_data.passive_gem_type
	if bot_data != null:
		_skill_counts = bot_data.active_skill_counts.duplicate()
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

	await _try_use_skill()

	if _manager.current_player != GameManager.RIGHT or _board.is_busy:
		return

	var swap := _pick_swap()
	if swap.size() == 2:
		_board.execute_bot_swap(swap[0], swap[1])

# ── Skill logic ───────────────────────────────────────────────────────────────

func _try_use_skill() -> void:
	if bot_data == null:
		return
	var idx := _choose_skill_index()
	if idx < 0:
		return

	var skill_data: SkillData = bot_data.active_skills[idx]
	var effect := skill_data.skill_effect as SkillEffect
	if effect == null:
		return

	var rank: int = bot_data.active_skill_ranks[idx] if idx < bot_data.active_skill_ranks.size() else 1
	var target := Vector2i(-1, -1)

	if effect.activation_type == SkillEffect.ActivationType.PICK_GEM:
		target = _choose_pick_gem_target(effect)
		if target == Vector2i(-1, -1):
			return

	_skill_counts[idx] -= 1
	_board.bot_execute_skill(effect, rank, target)

	while _board.is_busy:
		await get_tree().process_frame

func _choose_skill_index() -> int:
	if bot_data == null or bot_data.active_skills.is_empty():
		return -1

	var deficit := _manager.l_score - _manager.r_score
	if deficit < bot_data.skill_use_deficit_threshold:
		return -1

	var state := _board.board_state
	for i in bot_data.active_skills.size():
		if i >= _skill_counts.size() or _skill_counts[i] <= 0:
			continue
		var skill_data: SkillData = bot_data.active_skills[i]
		if skill_data == null or skill_data.skill_effect == null:
			continue
		var effect := skill_data.skill_effect as SkillEffect
		if effect == null:
			continue
		# ActivateModifiers only useful when bombs are on the board
		if effect is SkillEffectActivateModifiers and not _has_modifiers(state):
			continue
		return i

	return -1

func _choose_pick_gem_target(effect: SkillEffect) -> Vector2i:
	var state := _board.board_state
	if effect is SkillEffectDestroyType:
		return _most_common_gem_pos(state)
	# Generic fallback: first non-empty cell
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			if state.grid[row][col] >= 0:
				return Vector2i(row, col)
	return Vector2i(-1, -1)

func _most_common_gem_pos(state: BoardState) -> Vector2i:
	var type_count: Array = [0, 0, 0, 0, 0]
	var type_pos: Array = [Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1)]
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			var gem: int = state.grid[row][col]
			if gem >= 0 and gem < 5:
				type_count[gem] += 1
				if type_pos[gem] == Vector2i(-1, -1):
					type_pos[gem] = Vector2i(row, col)
	var best := -1
	for i in 5:
		if best < 0 or type_count[i] > type_count[best]:
			best = i
	return type_pos[best] if best >= 0 else Vector2i(-1, -1)

func _has_modifiers(state: BoardState) -> bool:
	for row in BoardState.ROWS:
		for col in BoardState.COLS:
			if state.get_modifier(row, col) != BoardState.MOD_NONE:
				return true
	return false

# ── Swap selection ────────────────────────────────────────────────────────────

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
				var score := _evaluate_swap(state, a, b)
				if score > 0:
					swaps.append({"a": a, "b": b, "score": score})
			if row + 1 < BoardState.ROWS:
				var a := Vector2i(row, col)
				var b := Vector2i(row + 1, col)
				var score := _evaluate_swap(state, a, b)
				if score > 0:
					swaps.append({"a": a, "b": b, "score": score})

	if swaps.is_empty():
		return [Vector2i(0, 0), Vector2i(0, 1)]

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
	return _simulate_cascade(grid)

func _simulate_cascade(grid: Array) -> int:
	var total := 0
	var wave := 1
	while wave <= 20:
		var matches := _find_matches_sim(grid)
		if matches.is_empty():
			break
		total += matches.size() * wave
		for pos in matches:
			grid[pos.x][pos.y] = -1
		_apply_gravity_sim(grid)
		wave += 1
	return total

func _find_matches_sim(grid: Array) -> Array:
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
	return hits.keys()

func _apply_gravity_sim(grid: Array) -> void:
	for col in BoardState.COLS:
		var empty := BoardState.ROWS - 1
		for row in range(BoardState.ROWS - 1, -1, -1):
			if grid[row][col] != -1:
				if row != empty:
					grid[empty][col] = grid[row][col]
					grid[row][col] = -1
				empty -= 1
