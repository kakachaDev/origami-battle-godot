extends Node
class_name GameManager

const MOVES_PER_TURN := 2
const LEFT := 0
const RIGHT := 1
const PASSIVE_CHARGE_MAX := 5

@export var total_rounds: int = 0
@export var passive_stack_resources: Array[PassiveStackData] = []

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

@onready var _board: GameBoard = $"../GameField/Gems"
@onready var _l_turns: Label = $"../HotBar/L_Turns"
@onready var _r_turns: Label = $"../HotBar/R_Turns"
@onready var _l_score: Label = $"../HotBar/L_Score"
@onready var _r_score: Label = $"../HotBar/R_Score"
@onready var _turn_label: Label = $"../HotBar/Turn"
@onready var _score_line: ScoreLine = $"../HotBar/ScoreLine"
@onready var _l_add_score: TextureRect = $"../HotBar/L_AddScore"
@onready var _r_add_score: TextureRect = $"../HotBar/R_AddScore"
@onready var _l_passive: PassiveStack = $"../HotBar/L_PassiveStack"
@onready var _r_passive: PassiveStack = $"../HotBar/R_PassiveStack"

func _ready() -> void:
	_board.move_completed.connect(_on_move_completed)
	_l_add_score.visible = false
	_r_add_score.visible = false
	if passive_stack_resources.size() >= 5:
		l_passive_gem_type = randi() % 5
		r_passive_gem_type = randi() % 5
		_l_passive.stack_data = passive_stack_resources[l_passive_gem_type]
		_r_passive.stack_data = passive_stack_resources[r_passive_gem_type]
		_l_passive.max_count = PASSIVE_CHARGE_MAX
		_r_passive.max_count = PASSIVE_CHARGE_MAX
		_l_passive.current_count = 0
		_r_passive.current_count = 0
	_update_ui()

func _on_move_completed(gems_by_type: Dictionary) -> void:
	var total := 0
	for c in gems_by_type.values():
		total += c

	if current_player == LEFT:
		l_score += total
		_show_add_score(_l_add_score, total)
		_charge_passive(LEFT, gems_by_type.get(l_passive_gem_type, 0))
		l_moves_left -= 1
		if l_moves_left <= 0:
			current_player = RIGHT
	else:
		r_score += total
		_show_add_score(_r_add_score, total)
		_charge_passive(RIGHT, gems_by_type.get(r_passive_gem_type, 0))
		r_moves_left -= 1
		if r_moves_left <= 0:
			current_player = LEFT
			current_round += 1
			l_moves_left = MOVES_PER_TURN
			r_moves_left = MOVES_PER_TURN
	_update_ui()

func _charge_passive(player: int, gained: int) -> void:
	if gained == 0:
		return
	if player == LEFT:
		l_passive_charge += gained
		while l_passive_charge >= PASSIVE_CHARGE_MAX:
			l_passive_charge -= PASSIVE_CHARGE_MAX
		_l_passive.current_count = l_passive_charge
	else:
		r_passive_charge += gained
		while r_passive_charge >= PASSIVE_CHARGE_MAX:
			r_passive_charge -= PASSIVE_CHARGE_MAX
		_r_passive.current_count = r_passive_charge

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
