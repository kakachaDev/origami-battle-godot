extends Node
class_name GameManager

const MOVES_PER_TURN := 2
const LEFT := 0
const RIGHT := 1

@export var total_rounds: int = 0

var current_round: int = 1
var current_player: int = LEFT
var l_moves_left: int = MOVES_PER_TURN
var r_moves_left: int = MOVES_PER_TURN
var l_score: int = 0
var r_score: int = 0

@onready var _board: GameBoard = $"../GameField/Gems"
@onready var _l_turns: Label = $"../HotBar/L_Turns"
@onready var _r_turns: Label = $"../HotBar/R_Turns"
@onready var _l_score: Label = $"../HotBar/L_Score"
@onready var _r_score: Label = $"../HotBar/R_Score"
@onready var _turn_label: Label = $"../HotBar/Turn"
@onready var _score_line: ScoreLine = $"../HotBar/ScoreLine"
@onready var _l_add_score: TextureRect = $"../HotBar/L_AddScore"
@onready var _r_add_score: TextureRect = $"../HotBar/R_AddScore"

func _ready() -> void:
	_board.move_completed.connect(_on_move_completed)
	_l_add_score.visible = false
	_r_add_score.visible = false
	_update_ui()

func _on_move_completed(gems_destroyed: int) -> void:
	if current_player == LEFT:
		l_score += gems_destroyed
		_show_add_score(_l_add_score, gems_destroyed)
		l_moves_left -= 1
		if l_moves_left <= 0:
			current_player = RIGHT
	else:
		r_score += gems_destroyed
		_show_add_score(_r_add_score, gems_destroyed)
		r_moves_left -= 1
		if r_moves_left <= 0:
			current_player = LEFT
			current_round += 1
			l_moves_left = MOVES_PER_TURN
			r_moves_left = MOVES_PER_TURN
	_update_ui()

func _update_ui() -> void:
	_l_score.text = str(l_score)
	_r_score.text = str(r_score)
	_l_turns.text = str(l_moves_left)
	_r_turns.text = str(r_moves_left)
	if total_rounds > 0:
		_turn_label.text = "Round %d/%d" % [current_round, total_rounds]
	else:
		_turn_label.text = "Round %d" % current_round
	_score_line.value = clampf(float(l_score - r_score), -100.0, 100.0)

func _show_add_score(node: TextureRect, amount: int) -> void:
	var label := node.get_node("Count") as Label
	label.text = "+%d" % amount
	node.modulate = Color.WHITE
	node.visible = true
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(node, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: node.visible = false)
