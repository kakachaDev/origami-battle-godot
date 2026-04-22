extends Control
class_name GameBoard

const ROWS := 7
const COLS := 7
const CELL_SIZE := 110.0
const CELL_STEP := 146.0   # 110 cell + 36 gap
const START_X := 29.0
const START_Y := 29.0

const CELL_SCENE: PackedScene = preload("res://Assets/Prefabs/GemCell.tscn")
const FALL_STAGGER := 0.06  # seconds between each gem in a column, bottom to top

const APPLEBOMB_RES: GemData = preload("res://Assets/Resources/Gems/Applebomb.tres")
const MOD_BOMB_LR_RES: ModifierData = preload("res://Assets/Resources/Modifiers/BombLeftRight.tres")
const MOD_BOMB_UD_RES: ModifierData = preload("res://Assets/Resources/Modifiers/BombUpDown.tres")

@export var gem_resources: Array[GemData] = []
var _board: BoardState
var _animator: BoardAnimator
var _cells: Array  # Array[Array[GemCell]]

var _drag_from: Vector2i = Vector2i(-1, -1)
var _busy := false

signal move_completed(gems_by_type: Dictionary)
signal gems_about_to_destroy(gem_infos: Array)

func _ready() -> void:
	_board = BoardState.new()
	_animator = BoardAnimator.new()
	add_child(_animator)
	mouse_filter = MOUSE_FILTER_STOP
	_build_cells()

func _build_cells() -> void:
	_cells = []
	for row in ROWS:
		var row_arr: Array = []
		for col in COLS:
			var cell: GemCell = CELL_SCENE.instantiate()
			cell.position = _cell_pos(row, col)
			cell.pivot_offset = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
			cell.mouse_filter = MOUSE_FILTER_PASS
			_apply_cell_state(cell, Vector2i(row, col))
			add_child(cell)
			row_arr.append(cell)
		_cells.append(row_arr)

func _cell_pos(row: int, col: int) -> Vector2:
	return Vector2(START_X + col * CELL_STEP, START_Y + row * CELL_STEP)

func _cell_at(local_pos: Vector2) -> Vector2i:
	var col := int((local_pos.x - START_X) / CELL_STEP)
	var row := int((local_pos.y - START_Y) / CELL_STEP)
	if row < 0 or row >= ROWS or col < 0 or col >= COLS:
		return Vector2i(-1, -1)
	return Vector2i(row, col)

func _apply_cell_state(cell: GemCell, pos: Vector2i) -> void:
	var t := _board.get_gem(pos.x, pos.y)
	var m := _board.get_modifier(pos.x, pos.y)
	if t == BoardState.APPLEBOMB_TYPE:
		cell.gem_data = APPLEBOMB_RES
		cell.modifier_data = null
	elif t == -1:
		cell.gem_data = null
		cell.modifier_data = null
	else:
		cell.gem_data = gem_resources[t]
		match m:
			BoardState.MOD_BOMB_LR: cell.modifier_data = MOD_BOMB_LR_RES
			BoardState.MOD_BOMB_UD: cell.modifier_data = MOD_BOMB_UD_RES
			_: cell.modifier_data = null

func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = _cell_at(mb.position) if mb.pressed else Vector2i(-1, -1)
	elif event is InputEventMouseMotion:
		if _drag_from == Vector2i(-1, -1):
			return
		var target := _cell_at(event.position)
		if target == Vector2i(-1, -1) or target == _drag_from:
			return
		if not _board.is_adjacent(_drag_from, target):
			_drag_from = Vector2i(-1, -1)
			return
		var from := _drag_from
		_drag_from = Vector2i(-1, -1)
		_do_swap(from, target)

func _do_swap(pos_a: Vector2i, pos_b: Vector2i) -> void:
	_busy = true
	var cell_a: GemCell = _cells[pos_a.x][pos_a.y]
	var cell_b: GemCell = _cells[pos_b.x][pos_b.y]
	var vis_a := _cell_pos(pos_a.x, pos_a.y)
	var vis_b := _cell_pos(pos_b.x, pos_b.y)

	await _animator.animate_swap(cell_a, cell_b, vis_a, vis_b)
	_board.swap(pos_a, pos_b)

	var gem_a := _board.get_gem(pos_a.x, pos_a.y)
	var mod_a := _board.get_modifier(pos_a.x, pos_a.y)
	var gem_b := _board.get_gem(pos_b.x, pos_b.y)
	var mod_b := _board.get_modifier(pos_b.x, pos_b.y)

	var is_apple_a := gem_a == BoardState.APPLEBOMB_TYPE
	var is_apple_b := gem_b == BoardState.APPLEBOMB_TYPE
	var has_mod_a := mod_a != BoardState.MOD_NONE
	var has_mod_b := mod_b != BoardState.MOD_NONE

	if is_apple_a or is_apple_b or (has_mod_a and has_mod_b):
		_cells[pos_a.x][pos_a.y] = cell_b
		_cells[pos_b.x][pos_b.y] = cell_a

		var to_destroy: Array[Vector2i] = []
		if is_apple_a and is_apple_b:
			to_destroy = _board.get_all_positions()
		elif is_apple_a and has_mod_b:
			var mod_pos: Array[Vector2i] = _get_bomb_positions(pos_b, mod_b)
			var type_pos := _board.get_all_positions_of_type(gem_b)
			var combined: Dictionary = {}
			for p in mod_pos: combined[p] = true
			for p in type_pos: combined[p] = true
			for p in combined: to_destroy.append(p)
		elif is_apple_b and has_mod_a:
			var mod_pos: Array[Vector2i] = _get_bomb_positions(pos_a, mod_a)
			var type_pos := _board.get_all_positions_of_type(gem_a)
			var combined: Dictionary = {}
			for p in mod_pos: combined[p] = true
			for p in type_pos: combined[p] = true
			for p in combined: to_destroy.append(p)
		elif is_apple_a:
			to_destroy = _board.get_all_positions_of_type(gem_b)
		elif is_apple_b:
			to_destroy = _board.get_all_positions_of_type(gem_a)
		else:
			# has_mod_a and has_mod_b
			var combined: Dictionary = {}
			for p in _get_bomb_positions(pos_a, mod_a): combined[p] = true
			for p in _get_bomb_positions(pos_b, mod_b): combined[p] = true
			for p in combined: to_destroy.append(p)

		var final_destroy := _board.expand_bomb_chain(to_destroy)
		var type_counts := await _resolve_destruction(final_destroy)
		move_completed.emit(type_counts)
	else:
		var matches := _board.find_matches()
		if matches.is_empty():
			_board.swap(pos_a, pos_b)
			await _animator.animate_return(cell_a, cell_b, vis_a, vis_b)
		else:
			_cells[pos_a.x][pos_a.y] = cell_b
			_cells[pos_b.x][pos_b.y] = cell_a
			var type_counts := await _resolve_matches(matches)
			move_completed.emit(type_counts)

	_busy = false

func _get_bomb_positions(pos: Vector2i, mod: int) -> Array[Vector2i]:
	if mod == BoardState.MOD_BOMB_LR:
		return _board.get_bomb_lr_positions(pos.x)
	elif mod == BoardState.MOD_BOMB_UD:
		return _board.get_bomb_ud_positions(pos.y)
	return []

# Shared destroy pipeline used by special swaps (no spawn logic).
func _resolve_destruction(positions: Array[Vector2i]) -> Dictionary:
	var type_counts: Dictionary = {}
	var gem_infos: Array = []
	for pos in positions:
		var t := _board.get_gem(pos.x, pos.y)
		if t == -1:
			continue
		type_counts[t] = type_counts.get(t, 0) + 1
		gem_infos.append({
			"gem_type": t,
			"world_pos": global_position + _cell_pos(pos.x, pos.y) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
		})
	gems_about_to_destroy.emit(gem_infos)

	var pool: Array[GemCell] = []
	for pos in positions:
		pool.append(_cells[pos.x][pos.y])

	await _animator.animate_destroy(pool)
	_board.clear_matches(positions)

	var falls := _board.apply_gravity()
	for fall in falls:
		_cells[fall.to.x][fall.to.y] = _cells[fall.from.x][fall.from.y]
		_cells[fall.from.x][fall.from.y] = null

	var spawns := _board.fill_empty()
	type_counts = await _refill_and_fall(pool, falls, spawns, type_counts)
	return type_counts

func _resolve_matches(matches: Array[Vector2i]) -> Dictionary:
	var groups := _board.find_match_groups()

	# Build spawn instructions and spawn_pos_set
	var spawn_instructions: Array = []
	var spawn_pos_set: Dictionary = {}
	for group in groups:
		if group.spawn_type == BoardState.SPAWN_NONE:
			continue
		var first: Vector2i = group.positions[0]
		var group_gem_type := _board.get_gem(first.x, first.y)
		var gem_type: int
		var mod_int: int
		match group.spawn_type:
			BoardState.SPAWN_BOMB_LR:
				gem_type = group_gem_type
				mod_int = BoardState.MOD_BOMB_LR
			BoardState.SPAWN_BOMB_UD:
				gem_type = group_gem_type
				mod_int = BoardState.MOD_BOMB_UD
			_: # SPAWN_APPLEBOMB
				gem_type = BoardState.APPLEBOMB_TYPE
				mod_int = BoardState.MOD_NONE
		var sp: Vector2i = group.spawn_pos
		spawn_instructions.append({"pos": sp, "gem_type": gem_type, "mod_int": mod_int})
		spawn_pos_set[sp] = true

	# Expand bomb chains from matched positions
	var final_destroy := _board.expand_bomb_chain(matches)

	# Emit signal
	var type_counts: Dictionary = {}
	var gem_infos: Array = []
	for pos in final_destroy:
		var t := _board.get_gem(pos.x, pos.y)
		if t == -1:
			continue
		type_counts[t] = type_counts.get(t, 0) + 1
		gem_infos.append({
			"gem_type": t,
			"world_pos": global_position + _cell_pos(pos.x, pos.y) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
		})
	gems_about_to_destroy.emit(gem_infos)

	# Pool = destroyed cells excluding spawn hosts
	var pool: Array[GemCell] = []
	for pos in final_destroy:
		if not spawn_pos_set.has(pos):
			pool.append(_cells[pos.x][pos.y])

	await _animator.animate_destroy(pool)

	# Animate spawn host cells separately (they also disappear then reappear as special gems)
	var spawn_host_cells: Array[GemCell] = []
	for instr in spawn_instructions:
		var sp: Vector2i = instr.pos
		if _cells[sp.x][sp.y] != null:
			spawn_host_cells.append(_cells[sp.x][sp.y])
	if not spawn_host_cells.is_empty():
		var tw := _animator.create_tween().set_parallel(true)
		tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		for cell in spawn_host_cells:
			tw.tween_property(cell as Control, "scale", Vector2.ZERO, BoardAnimator.DESTROY_TIME)
		await tw.finished

	# Clear all destroyed positions
	_board.clear_matches(final_destroy)

	# Place spawn gems BEFORE gravity so they fall naturally with the column
	for instr in spawn_instructions:
		_board.place_gem(instr.pos.x, instr.pos.y, instr.gem_type, instr.mod_int)

	# Gravity
	var falls := _board.apply_gravity()

	# Track where each spawn gem landed after gravity
	var spawn_final: Dictionary = {}  # original_pos → final_pos
	for instr in spawn_instructions:
		spawn_final[instr.pos] = instr.pos
	for fall in falls:
		var from: Vector2i = fall.from
		if spawn_final.has(from):
			spawn_final[from] = fall.to

	# Update _cells pointers for falls
	for fall in falls:
		_cells[fall.to.x][fall.to.y] = _cells[fall.from.x][fall.from.y]
		_cells[fall.from.x][fall.from.y] = null

	# Update spawn cells at their final positions
	for orig_pos in spawn_final:
		var final_pos: Vector2i = spawn_final[orig_pos]
		var cell: GemCell = _cells[final_pos.x][final_pos.y]
		if cell != null:
			_apply_cell_state(cell, final_pos)
			cell.scale = Vector2.ONE
			cell.visible = true

	# Fill empty (spawn positions are non-empty, so they won't be overwritten)
	var spawns := _board.fill_empty()
	type_counts = await _refill_and_fall(pool, falls, spawns, type_counts)
	return type_counts

# Assigns refill cells from pool, positions them above grid, then animates the fall.
# Also checks for cascades and accumulates counts.
func _refill_and_fall(pool: Array[GemCell], falls: Array, spawns: Array, type_counts: Dictionary) -> Dictionary:
	var col_counts: Dictionary = {}
	for s in spawns:
		var c: int = (s.pos as Vector2i).y
		col_counts[c] = col_counts.get(c, 0) + 1
	var col_idx: Dictionary = {}

	var pool_idx := 0
	for s in spawns:
		var pos: Vector2i = s.pos
		var col: int = pos.y
		var total: int = col_counts[col]
		var idx: int = col_idx.get(col, 0)
		col_idx[col] = idx + 1
		var cell: GemCell = pool[pool_idx]
		pool_idx += 1
		_cells[pos.x][pos.y] = cell
		_apply_cell_state(cell, pos)
		cell.scale = Vector2.ONE
		cell.visible = true
		cell.position = _cell_pos(-(total - idx), col)

	var by_col: Dictionary = {}
	for fall in falls:
		var tp: Vector2i = fall.to
		var col: int = tp.y
		if not by_col.has(col):
			by_col[col] = []
		by_col[col].append({"cell": _cells[tp.x][tp.y], "target": _cell_pos(tp.x, tp.y), "target_row": tp.x})
	for s in spawns:
		var pos: Vector2i = s.pos
		var col: int = pos.y
		if not by_col.has(col):
			by_col[col] = []
		by_col[col].append({"cell": _cells[pos.x][pos.y], "target": _cell_pos(pos.x, pos.y), "target_row": pos.x})

	var all_entries: Array = []
	for col in by_col:
		var gems: Array = by_col[col]
		gems.sort_custom(func(a, b): return a.target_row > b.target_row)
		for i in gems.size():
			all_entries.append({"cell": gems[i].cell, "target": gems[i].target, "delay": i * FALL_STAGGER})

	await _animator.animate_fall(all_entries)

	var cascade := _board.find_matches()
	if not cascade.is_empty():
		var cascade_counts := await _resolve_matches(cascade)
		for k in cascade_counts:
			type_counts[k] = type_counts.get(k, 0) + cascade_counts[k]

	return type_counts
