extends Control
class_name GameBoard

const ROWS := 7
const COLS := 7
const CELL_SIZE := 110.0
const CELL_STEP := 146.0
const START_X := 29.0
const START_Y := 29.0

const CELL_SCENE: PackedScene = preload("res://Assets/Prefabs/GemCell.tscn")
const FALL_STAGGER := 0.06

const APPLEBOMB_RES: GemData = preload("res://Assets/Resources/Gems/Applebomb.tres")
const MOD_BOMB_LR_RES: ModifierData = preload("res://Assets/Resources/Modifiers/BombLeftRight.tres")
const MOD_BOMB_UD_RES: ModifierData = preload("res://Assets/Resources/Modifiers/BombUpDown.tres")
const PASSIVE_CHARGE_MAX := 5

@export var gem_resources: Array[GemData] = []
@export var l_passive_effect: Resource  # GemEffect
@export var r_passive_effect: Resource  # GemEffect

var _board: BoardState
var _animator: BoardAnimator
var _cells: Array  # Array[Array[GemCell]]

var _drag_from: Vector2i = Vector2i(-1, -1)
var _busy := false

var _current_player: int = 0
var _l_passive_gem_type: int = -1
var _r_passive_gem_type: int = -1
var _l_passive_charge: int = 0
var _r_passive_charge: int = 0

var _event_queue: Array = []

signal move_completed(gems_by_type: Dictionary)
signal passive_charged(player: int, charge: int, source_world_pos: Vector2)
signal passive_fire_requested(player: int, icon_targets: Array)
signal passive_fire_completed

# ── Public API ────────────────────────────────────────────────────────────────

var board_state: BoardState:
	get:
		return _board

func configure_passive(l_type: int, r_type: int) -> void:
	_l_passive_gem_type = l_type
	_r_passive_gem_type = r_type

func set_current_player(player: int) -> void:
	_current_player = player

func get_cell_world_center(row: int, col: int) -> Vector2:
	return global_position + Vector2(START_X + col * CELL_STEP + CELL_SIZE * 0.5, START_Y + row * CELL_STEP + CELL_SIZE * 0.5)

# ── Init ──────────────────────────────────────────────────────────────────────

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

# ── Input ─────────────────────────────────────────────────────────────────────

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

	_event_queue.clear()
	_simulate_swap(pos_a, pos_b)

	if _event_queue.is_empty():
		_board.swap(pos_a, pos_b)
		await _animator.animate_return(cell_a, cell_b, vis_a, vis_b)
		_busy = false
		return

	_cells[pos_a.x][pos_a.y] = cell_b
	_cells[pos_b.x][pos_b.y] = cell_a

	var gems_by_type := await _play_event_queue()
	move_completed.emit(gems_by_type)
	_busy = false

# ── Simulation (synchronous) ──────────────────────────────────────────────────

func _simulate_swap(pos_a: Vector2i, pos_b: Vector2i) -> void:
	var gem_a := _board.get_gem(pos_a.x, pos_a.y)
	var mod_a := _board.get_modifier(pos_a.x, pos_a.y)
	var gem_b := _board.get_gem(pos_b.x, pos_b.y)
	var mod_b := _board.get_modifier(pos_b.x, pos_b.y)
	var is_apple_a := gem_a == BoardState.APPLEBOMB_TYPE
	var is_apple_b := gem_b == BoardState.APPLEBOMB_TYPE
	var has_mod_a := mod_a != BoardState.MOD_NONE
	var has_mod_b := mod_b != BoardState.MOD_NONE

	if is_apple_a or is_apple_b or (has_mod_a and has_mod_b):
		var to_destroy: Array[Vector2i] = []
		if is_apple_a and is_apple_b:
			to_destroy = _board.get_all_positions()
		elif is_apple_a and has_mod_b:
			var type_pos := _board.get_all_positions_of_type(gem_b)
			for p in type_pos:
				_board.set_modifier(p.x, p.y, mod_b)
				_event_queue.append({"t": "modifier_set", "pos": p, "mod": mod_b})
			to_destroy.append_array(type_pos)
			to_destroy.append(pos_a)
		elif is_apple_b and has_mod_a:
			var type_pos := _board.get_all_positions_of_type(gem_a)
			for p in type_pos:
				_board.set_modifier(p.x, p.y, mod_a)
				_event_queue.append({"t": "modifier_set", "pos": p, "mod": mod_a})
			to_destroy.append_array(type_pos)
			to_destroy.append(pos_b)
		elif is_apple_a or is_apple_b:
			var apple_pos := pos_a if is_apple_a else pos_b
			var other_pos := pos_b if is_apple_a else pos_a
			var effect := APPLEBOMB_RES.activation_effect as GemEffect
			if effect:
				to_destroy = effect.get_targets(_board, apple_pos, other_pos)
		else:
			var combined: Dictionary = {}
			for p in _get_bomb_positions(pos_a, mod_a): combined[p] = true
			for p in _get_bomb_positions(pos_b, mod_b): combined[p] = true
			for p in combined: to_destroy.append(p)
		_simulate_wave(to_destroy, {}, false)
	else:
		var groups := _board.find_match_groups()
		if groups.is_empty():
			return
		var spawn_hosts: Dictionary = {}
		var all_matches: Array[Vector2i] = []
		for group in groups:
			all_matches.append_array(group.positions)
			if group.spawn_type != BoardState.SPAWN_NONE:
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
					_:
						gem_type = BoardState.APPLEBOMB_TYPE
						mod_int = BoardState.MOD_NONE
				spawn_hosts[group.spawn_pos] = {"gem_type": gem_type, "mod": mod_int}
		_simulate_wave(all_matches, spawn_hosts, false)

func _simulate_wave(initial: Array[Vector2i], spawn_hosts: Dictionary, from_passive: bool) -> void:
	# 1. Expand bomb chain BEFORE placing spawn gems (avoids chain-triggering new mods)
	var to_destroy := _expand_bomb_chain(initial)

	# 2. Compute passive charges
	var pending_charge_events: Array = []
	var fired_player := -1
	if not from_passive:
		for pos in to_destroy:
			var gem_type := _board.get_gem(pos.x, pos.y)
			if gem_type == -1:
				continue
			if _current_player == 0 and gem_type == _l_passive_gem_type:
				_l_passive_charge += 1
				if _l_passive_charge >= PASSIVE_CHARGE_MAX:
					_l_passive_charge -= PASSIVE_CHARGE_MAX
					if fired_player == -1:
						fired_player = 0
				pending_charge_events.append({"t": "passive_charge", "player": 0,
					"charge": _l_passive_charge, "source_world_pos": get_cell_world_center(pos.x, pos.y)})
			elif _current_player == 1 and gem_type == _r_passive_gem_type:
				_r_passive_charge += 1
				if _r_passive_charge >= PASSIVE_CHARGE_MAX:
					_r_passive_charge -= PASSIVE_CHARGE_MAX
					if fired_player == -1:
						fired_player = 1
				pending_charge_events.append({"t": "passive_charge", "player": 1,
					"charge": _r_passive_charge, "source_world_pos": get_cell_world_center(pos.x, pos.y)})

	# 3. Build gem_infos for the destroy event
	var gem_infos: Array = []
	for pos in to_destroy:
		var t := _board.get_gem(pos.x, pos.y)
		if t != -1:
			gem_infos.append({"gem_type": t, "pos": pos,
				"world_pos": get_cell_world_center(pos.x, pos.y)})

	# 4. Destroy event (spawn_hosts stored for playback animation handling)
	_event_queue.append({"t": "destroy", "positions": to_destroy.duplicate(),
		"gem_infos": gem_infos, "spawn_hosts": spawn_hosts.duplicate()})

	# 5. Clear board (all destroyed positions, including spawn host slots)
	_board.clear_matches(to_destroy)

	# 6. Place spawn gems after clearing so they fall with column
	for pos in spawn_hosts:
		var info = spawn_hosts[pos]
		_board.place_gem(pos.x, pos.y, info.gem_type, info.mod)

	# 7. Passive charge events (after destroy in queue)
	for ev in pending_charge_events:
		_event_queue.append(ev)

	# 8. Passive fire
	if fired_player != -1:
		var effect := (l_passive_effect if fired_player == 0 else r_passive_effect) as GemEffect
		if effect:
			var center := Vector2i(BoardState.ROWS / 2, BoardState.COLS / 2)
			var icon_targets := effect.get_icon_targets(_board, center)
			if not icon_targets.is_empty():
				_event_queue.append({"t": "passive_fire", "player": fired_player, "icon_targets": icon_targets})
				var raw_passive := effect.get_targets(_board, center, Vector2i(-1, -1))
				if not raw_passive.is_empty():
					# Destruction effect: separate wave after the icon lands
					var passive_destroy := _expand_bomb_chain(raw_passive)
					var passive_infos: Array = []
					for pos in passive_destroy:
						var t := _board.get_gem(pos.x, pos.y)
						if t != -1:
							passive_infos.append({"gem_type": t, "pos": pos,
								"world_pos": get_cell_world_center(pos.x, pos.y)})
					_event_queue.append({"t": "destroy", "positions": passive_destroy.duplicate(),
						"gem_infos": passive_infos, "spawn_hosts": {}})
					_board.clear_matches(passive_destroy)
				else:
					# Modifier effect: apply mods to board now, emit modifier_set on landing
					for icon_pos in icon_targets:
						if _board.get_gem(icon_pos.x, icon_pos.y) != -1:
							var mod := randi() % 2
							_board.set_modifier(icon_pos.x, icon_pos.y, mod)
							_event_queue.append({"t": "modifier_set", "pos": icon_pos, "mod": mod})

	# 9. Gravity
	var falls := _board.apply_gravity()

	# 10. Track where spawn hosts land after gravity
	var spawn_final: Dictionary = {}
	for pos in spawn_hosts:
		spawn_final[pos] = pos
	for fall in falls:
		var from: Vector2i = fall.from
		if spawn_final.has(from):
			spawn_final[from] = fall.to

	# 11. Fill empty
	var new_gems := _board.fill_empty()

	# 12. Fall event
	_event_queue.append({"t": "fall", "falls": falls, "new_gems": new_gems,
		"spawn_final": spawn_final, "spawn_hosts": spawn_hosts.duplicate()})

	# 13. Cascade
	var cascade := _board.find_matches()
	if cascade.is_empty():
		return
	var cascade_groups := _board.find_match_groups()
	var cascade_spawn: Dictionary = {}
	var cascade_all: Array[Vector2i] = []
	for group in cascade_groups:
		cascade_all.append_array(group.positions)
		if group.spawn_type != BoardState.SPAWN_NONE:
			var first: Vector2i = group.positions[0]
			var ggt := _board.get_gem(first.x, first.y)
			var gtype: int
			var gmod: int
			match group.spawn_type:
				BoardState.SPAWN_BOMB_LR:
					gtype = ggt
					gmod = BoardState.MOD_BOMB_LR
				BoardState.SPAWN_BOMB_UD:
					gtype = ggt
					gmod = BoardState.MOD_BOMB_UD
				_:
					gtype = BoardState.APPLEBOMB_TYPE
					gmod = BoardState.MOD_NONE
			cascade_spawn[group.spawn_pos] = {"gem_type": gtype, "mod": gmod}
	_simulate_wave(cascade_all, cascade_spawn, false)

# ── Playback (sequential animations) ─────────────────────────────────────────

func _play_event_queue() -> Dictionary:
	var gems_by_type: Dictionary = {}
	var pool: Array[GemCell] = []

	for event in _event_queue:
		match event.t:
			"destroy":
				for info in event.gem_infos:
					var gt: int = info.gem_type
					gems_by_type[gt] = gems_by_type.get(gt, 0) + 1

				var regular_cells: Array[GemCell] = []
				var spawn_host_cells: Array[GemCell] = []
				for pos in event.positions:
					var cell: GemCell = _cells[pos.x][pos.y]
					if cell == null:
						continue
					if event.spawn_hosts.has(pos):
						spawn_host_cells.append(cell)
					else:
						pool.append(cell)
						regular_cells.append(cell)

				if not regular_cells.is_empty():
					await _animator.animate_destroy(regular_cells)
				if not spawn_host_cells.is_empty():
					var tw := _animator.create_tween().set_parallel(true)
					tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
					for cell in spawn_host_cells:
						tw.tween_property(cell as Control, "scale", Vector2.ZERO, BoardAnimator.DESTROY_TIME)
					await tw.finished

			"passive_charge":
				passive_charged.emit(event.player, event.charge, event.source_world_pos)

			"passive_fire":
				passive_fire_requested.emit(event.player, event.icon_targets)
				await passive_fire_completed

			"modifier_set":
				var pos: Vector2i = event.pos
				if _cells[pos.x][pos.y] != null:
					_apply_cell_state(_cells[pos.x][pos.y], pos)

			"fall":
				# Update _cells pointers for falling gems
				for fall in event.falls:
					var from: Vector2i = fall.from
					var to: Vector2i = fall.to
					_cells[to.x][to.y] = _cells[from.x][from.y]
					_cells[from.x][from.y] = null

				# Update spawn host cells at their final board positions
				for orig_pos in event.spawn_final:
					var final_pos: Vector2i = event.spawn_final[orig_pos]
					var cell: GemCell = _cells[final_pos.x][final_pos.y]
					if cell != null:
						_apply_cell_state(cell, final_pos)
						cell.scale = Vector2.ONE
						cell.visible = true

				# Assign pool cells to new gem positions and place above grid
				var new_gems: Array = event.new_gems
				var col_counts: Dictionary = {}
				for s in new_gems:
					var c: int = (s.pos as Vector2i).y
					col_counts[c] = col_counts.get(c, 0) + 1
				var col_idx: Dictionary = {}
				var pool_used := 0
				for s in new_gems:
					var pos: Vector2i = s.pos
					var col: int = pos.y
					var total: int = col_counts[col]
					var idx: int = col_idx.get(col, 0)
					col_idx[col] = idx + 1
					if pool_used < pool.size():
						var cell: GemCell = pool[pool_used]
						pool_used += 1
						_cells[pos.x][pos.y] = cell
						_apply_cell_state(cell, pos)
						cell.scale = Vector2.ONE
						cell.visible = true
						cell.position = _cell_pos(-(total - idx), col)
				pool = pool.slice(pool_used)

				# Build fall animation entries (falling gems + new spawn gems)
				var by_col: Dictionary = {}
				for fall in event.falls:
					var tp: Vector2i = fall.to
					var col: int = tp.y
					if not by_col.has(col):
						by_col[col] = []
					var fall_cell: GemCell = _cells[tp.x][tp.y]
					if fall_cell != null:
						by_col[col].append({"cell": fall_cell, "target": _cell_pos(tp.x, tp.y), "target_row": tp.x})
				for s in new_gems:
					var pos: Vector2i = s.pos
					var col: int = pos.y
					if not by_col.has(col):
						by_col[col] = []
					var spawn_cell: GemCell = _cells[pos.x][pos.y]
					if spawn_cell != null:
						by_col[col].append({"cell": spawn_cell, "target": _cell_pos(pos.x, pos.y), "target_row": pos.x})

				var all_entries: Array = []
				for col in by_col:
					var gems: Array = by_col[col]
					gems.sort_custom(func(a, b): return a.target_row > b.target_row)
					for i in gems.size():
						all_entries.append({"cell": gems[i].cell, "target": gems[i].target,
							"delay": i * FALL_STAGGER})
				if not all_entries.is_empty():
					await _animator.animate_fall(all_entries)

	return gems_by_type

# ── Helpers ───────────────────────────────────────────────────────────────────

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

func _get_modifier_resource(mod: int) -> ModifierData:
	match mod:
		BoardState.MOD_BOMB_LR: return MOD_BOMB_LR_RES
		BoardState.MOD_BOMB_UD: return MOD_BOMB_UD_RES
	return null

func _get_bomb_positions(pos: Vector2i, mod: int) -> Array[Vector2i]:
	var mod_res := _get_modifier_resource(mod)
	if not mod_res:
		return []
	var effect := mod_res.effect as GemEffect
	if not effect:
		return []
	var result: Array[Vector2i] = []
	for p in effect.get_targets(_board, pos, Vector2i(-1, -1)):
		if _board.get_gem(p.x, p.y) != BoardState.APPLEBOMB_TYPE:
			result.append(p)
	return result

func _expand_bomb_chain(initial: Array[Vector2i]) -> Array[Vector2i]:
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
		var mod: int = _board.get_modifier(pos.x, pos.y)
		if mod == BoardState.MOD_NONE:
			continue
		var mod_res := _get_modifier_resource(mod)
		if not mod_res:
			continue
		var effect := mod_res.effect as GemEffect
		if not effect:
			continue
		var extras := effect.get_targets(_board, pos, Vector2i(-1, -1))
		for np in extras:
			if not to_destroy.has(np) and _board.get_gem(np.x, np.y) != BoardState.APPLEBOMB_TYPE:
				to_destroy[np] = true
				frontier.append(np)
	var result: Array[Vector2i] = []
	for pos in to_destroy:
		result.append(pos)
	return result
