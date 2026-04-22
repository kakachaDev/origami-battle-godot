extends Node
class_name GameUI

@export var passive_stack_resources: Array[PassiveStackData] = []

@onready var _manager: GameManager = $"../GameManager"
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
	_manager.score_updated.connect(_on_score_updated)
	_manager.player_scored.connect(_on_player_scored)
	_manager.turns_updated.connect(_on_turns_updated)
	_manager.passive_types_assigned.connect(_on_passive_types_assigned)
	_manager.passive_charge_updated.connect(_on_passive_charge_updated)
	_board.gems_about_to_destroy.connect(_on_gems_about_to_destroy)
	_l_add_score.visible = false
	_r_add_score.visible = false

func _on_score_updated(l_score: int, r_score: int) -> void:
	_l_score.text = str(l_score)
	_r_score.text = str(r_score)
	_score_line.value = clampf(float(l_score - r_score), -100.0, 100.0)

func _on_player_scored(player: int, amount: int) -> void:
	if player == GameManager.LEFT:
		_show_add_score(_l_add_score, amount)
	else:
		_show_add_score(_r_add_score, amount)

func _on_turns_updated(l_moves: int, r_moves: int, player: int, round: int) -> void:
	_l_turns.text = str(l_moves)
	_r_turns.text = str(r_moves)
	if _manager.total_rounds > 0:
		_turn_label.text = "Round %d/%d" % [round, _manager.total_rounds]
	else:
		_turn_label.text = "Round %d" % round

func _on_passive_types_assigned(l_gem_type: int, r_gem_type: int) -> void:
	if passive_stack_resources.size() < 5:
		return
	_l_passive.stack_data = passive_stack_resources[l_gem_type]
	_r_passive.stack_data = passive_stack_resources[r_gem_type]
	_l_passive.max_count = GameManager.PASSIVE_CHARGE_MAX
	_r_passive.max_count = GameManager.PASSIVE_CHARGE_MAX
	_l_passive.current_count = 0
	_r_passive.current_count = 0

func _on_passive_charge_updated(player: int, charge: int) -> void:
	if player == GameManager.LEFT:
		_l_passive.current_count = charge
	else:
		_r_passive.current_count = charge

func _on_gems_about_to_destroy(gem_infos: Array) -> void:
	for info in gem_infos:
		var gem_type: int = info["gem_type"]
		var world_pos: Vector2 = info["world_pos"]
		if _manager.current_player == GameManager.LEFT and gem_type == _manager.l_passive_gem_type:
			_spawn_flying_gem(world_pos, _l_passive, passive_stack_resources[gem_type], GameManager.LEFT)
		elif _manager.current_player == GameManager.RIGHT and gem_type == _manager.r_passive_gem_type:
			_spawn_flying_gem(world_pos, _r_passive, passive_stack_resources[gem_type], GameManager.RIGHT)

func _spawn_flying_gem(from: Vector2, target: PassiveStack, data: PassiveStackData, player: int) -> void:
	var icon := TextureRect.new()
	icon.texture = data.sprite_active
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(48, 48)
	get_parent().add_child(icon)

	var p0 := from - icon.size * 0.5
	var p2 := target.global_position + target.size * 0.5 - icon.size * 0.5
	var arc := clampf(p0.distance_to(p2) * 0.35, 120.0, 300.0)
	var p1 := (p0 + p2) * 0.5 + Vector2(0.0, -arc)

	icon.global_position = p0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		icon.global_position = u * u * p0 + 2.0 * u * t * p1 + t * t * p2
	, 0.0, 1.0, 0.65)
	tween.tween_property(icon, "scale", Vector2(0.0, 0.0), 0.07)
	tween.tween_callback(func() -> void:
		icon.queue_free()
		_manager.charge_passive_one(player)
	)

func _show_add_score(node: TextureRect, amount: int) -> void:
	var label := node.get_node("Count") as Label
	label.text = "+%d" % amount
	node.modulate = Color.WHITE
	node.visible = true
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(node, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: node.visible = false)
