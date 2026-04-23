extends Node
class_name GameManager

const MOVES_PER_TURN := 2
const LEFT := 0
const RIGHT := 1
const PASSIVE_CHARGE_MAX := 5

@export var total_rounds: int = 0

var current_round: int = 1
var current_player: int = LEFT
var l_moves_left: int = MOVES_PER_TURN
var r_moves_left: int = MOVES_PER_TURN
var l_score: int = 0
var r_score: int = 0
var l_passive_gem_type: int = -1
var r_passive_gem_type: int = -1
var l_passive_charge: int = 0
var r_passive_charge: int = 0

signal score_updated(l_score: int, r_score: int)
signal player_scored(player: int, amount: int)
signal turns_updated(l_moves: int, r_moves: int, player: int, round: int)
signal passive_types_assigned(l_gem_type: int, r_gem_type: int)
signal passive_charge_updated(player: int, charge: int)
signal passive_fired(player: int)

@onready var _board: GameBoard = $"../GameField/Gems"

func _ready() -> void:
	_board.move_completed.connect(_on_move_completed)
	l_passive_gem_type = randi() % 5
	r_passive_gem_type = randi() % 5
	call_deferred("_emit_initial_state")

func _emit_initial_state() -> void:
	passive_types_assigned.emit(l_passive_gem_type, r_passive_gem_type)
	score_updated.emit(l_score, r_score)
	turns_updated.emit(l_moves_left, r_moves_left, current_player, current_round)

func _on_move_completed(gems_by_type: Dictionary) -> void:
	var total := 0
	for c in gems_by_type.values():
		total += c
	var bonus_move := total > 3
	if current_player == LEFT:
		l_score += total
		player_scored.emit(LEFT, total)
		if not bonus_move:
			l_moves_left -= 1
		if l_moves_left <= 0:
			current_player = RIGHT
	else:
		r_score += total
		player_scored.emit(RIGHT, total)
		if not bonus_move:
			r_moves_left -= 1
		if r_moves_left <= 0:
			current_player = LEFT
			current_round += 1
			l_moves_left = MOVES_PER_TURN
			r_moves_left = MOVES_PER_TURN
	score_updated.emit(l_score, r_score)
	turns_updated.emit(l_moves_left, r_moves_left, current_player, current_round)

func charge_passive_one(player: int) -> void:
	if player == LEFT:
		l_passive_charge += 1
		if l_passive_charge >= PASSIVE_CHARGE_MAX:
			l_passive_charge -= PASSIVE_CHARGE_MAX
			passive_fired.emit(LEFT)
		passive_charge_updated.emit(LEFT, l_passive_charge)
	else:
		r_passive_charge += 1
		if r_passive_charge >= PASSIVE_CHARGE_MAX:
			r_passive_charge -= PASSIVE_CHARGE_MAX
			passive_fired.emit(RIGHT)
		passive_charge_updated.emit(RIGHT, r_passive_charge)
