extends Control
class_name GameBoard

const ROWS := 7
const COLS := 7
const CELL_SIZE := 110.0
const CELL_STEP := 146.0   # 110 cell + 36 gap
const START_X := 29.0
const START_Y := 29.0

const CELL_SCENE: PackedScene = preload("res://Assets/Prefabs/GemCell.tscn")

@export var gem_resources: Array[GemData] = []
var _board: BoardState
var _animator: BoardAnimator
var _cells: Array  # Array[Array[GemCell]]

var _drag_from: Vector2i = Vector2i(-1, -1)
var _busy := false

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
			cell.gem_data = gem_resources[_board.get_gem(row, col)]
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
	var matches := _board.find_matches()

	if matches.is_empty():
		_board.swap(pos_a, pos_b)
		await _animator.animate_return(cell_a, cell_b, vis_a, vis_b)
	else:
		_cells[pos_a.x][pos_a.y] = cell_b
		_cells[pos_b.x][pos_b.y] = cell_a
		await _resolve_matches(matches)

	_busy = false

func _resolve_matches(matches: Array[Vector2i]) -> void:
	var pool: Array[GemCell] = []
	for pos in matches:
		pool.append(_cells[pos.x][pos.y])

	await _animator.animate_destroy(pool)
	_board.clear_matches(matches)

	var falls := _board.apply_gravity()

	# Update cell references (falls are bottom-up, safe to apply in order)
	for fall in falls:
		var fp: Vector2i = fall.from
		var tp: Vector2i = fall.to
		_cells[tp.x][tp.y] = _cells[fp.x][fp.y]
		_cells[fp.x][fp.y] = null

	var fall_entries: Array = []
	for fall in falls:
		var tp: Vector2i = fall.to
		fall_entries.append({"cell": _cells[tp.x][tp.y], "target": _cell_pos(tp.x, tp.y)})
	await _animator.animate_fall(fall_entries)

	var spawns := _board.fill_empty()

	# Count empties per column to stagger spawn start positions
	var col_totals: Dictionary = {}
	for s in spawns:
		var c: int = (s.pos as Vector2i).y
		col_totals[c] = col_totals.get(c, 0) + 1
	var col_idx: Dictionary = {}

	var spawn_entries: Array = []
	for i in spawns.size():
		var s = spawns[i]
		var pos: Vector2i = s.pos
		var col: int = pos.y
		var total: int = col_totals[col]
		var idx: int = col_idx.get(col, 0)
		col_idx[col] = idx + 1
		var start_row := -(total - idx)  # stagger: row -total … -1
		var cell: GemCell = pool[i]
		_cells[pos.x][pos.y] = cell
		cell.gem_data = gem_resources[s.gem]
		cell.scale = Vector2.ONE
		cell.position = _cell_pos(start_row, col)
		spawn_entries.append({"cell": cell, "target": _cell_pos(pos.x, pos.y)})
	await _animator.animate_spawn(spawn_entries)

	var cascade := _board.find_matches()
	if not cascade.is_empty():
		await _resolve_matches(cascade)
