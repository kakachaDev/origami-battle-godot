extends Node
class_name GameUI

@export var passive_stack_resources: Array[PassiveStackData] = []
@export var l_passive_effect: Resource  # GemEffect
@export var r_passive_effect: Resource  # GemEffect

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

# True while a passive effect is animating or executing — prevents double-fire
# and suppresses passive charging from gems destroyed by the effect itself.
var _passive_effect_active := false

func _ready() -> void:
	_manager.score_updated.connect(_on_score_updated)
	_manager.player_scored.connect(_on_player_scored)
	_manager.turns_updated.connect(_on_turns_updated)
	_manager.passive_types_assigned.connect(_on_passive_types_assigned)
	_manager.passive_charge_updated.connect(_on_passive_charge_updated)
	_manager.passive_fired.connect(_on_passive_fired)
	_board.gems_about_to_destroy.connect(_on_gems_about_to_destroy)
	_board.effect_completed.connect(_on_effect_completed)
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
		_l_passive.set_count_animated(charge)
	else:
		_r_passive.set_count_animated(charge)

func _on_gems_about_to_destroy(gem_infos: Array) -> void:
	# Suppress passive charging while a passive effect is executing (avoid wrong-player charge).
	if _passive_effect_active:
		return
	var player := _manager.current_player
	for info in gem_infos:
		var gem_type: int = info["gem_type"]
		var world_pos: Vector2 = info["world_pos"]
		if player == GameManager.LEFT and gem_type == _manager.l_passive_gem_type:
			_manager.charge_passive_one(GameManager.LEFT)
			_spawn_flying_gem(world_pos, _l_passive, passive_stack_resources[gem_type])
		elif player == GameManager.RIGHT and gem_type == _manager.r_passive_gem_type:
			_manager.charge_passive_one(GameManager.RIGHT)
			_spawn_flying_gem(world_pos, _r_passive, passive_stack_resources[gem_type])

func _spawn_flying_gem(from: Vector2, target: PassiveStack, data: PassiveStackData) -> void:
	var icon := TextureRect.new()
	icon.texture = data.sprite_active
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(48, 48)
	get_parent().add_child(icon)

	var p0 := from - icon.size * 0.5
	var p3 := target.global_position + target.size * 0.5 - icon.size * 0.5
	var dist := p0.distance_to(p3)
	var away := -signf((p3 - p0).x)
	if is_zero_approx(away): away = 1.0
	var p1 := p0 + Vector2(away * clampf(dist * 0.35, 80.0, 220.0), clampf(dist * 0.3, 100.0, 260.0))
	var p2 := p3 + Vector2(away * 50.0, -80.0)

	icon.global_position = p0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		icon.global_position = u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3
	, 0.0, 1.0, 0.7)
	tween.tween_property(icon, "scale", Vector2(0.0, 0.0), 0.07)
	tween.tween_callback(func() -> void: icon.queue_free())

func _on_passive_fired(player: int) -> void:
	# Prevent double-fire: if an effect is already in flight, ignore this signal.
	if _passive_effect_active:
		return
	_passive_effect_active = true

	var effect := (l_passive_effect if player == GameManager.LEFT else r_passive_effect) as GemEffect
	if not effect:
		_passive_effect_active = false
		return
	var passive_node := _l_passive if player == GameManager.LEFT else _r_passive
	var data: PassiveStackData = passive_node.stack_data
	if not data:
		_passive_effect_active = false
		return

	var center := Vector2i(BoardState.ROWS / 2, BoardState.COLS / 2)
	var icon_targets := effect.get_icon_targets(_board.board_state, center)

	if icon_targets.is_empty():
		_passive_effect_active = false
		return

	# pending[0] counts icons still in flight; resets flag when all land (for modifier effects).
	var pending := [icon_targets.size()]
	var is_modifier_effect := effect is EffectApplyRandomModifiers

	for target_pos in icon_targets:
		var target_world := _board.get_cell_world_center(target_pos.x, target_pos.y)
		var pos_copy := target_pos
		_spawn_passive_icon(passive_node, data, target_world, func():
			_on_passive_icon_landed(effect, pos_copy, pending, is_modifier_effect)
		)

func _on_passive_icon_landed(effect: GemEffect, target_pos: Vector2i, pending: Array, is_modifier: bool) -> void:
	pending[0] -= 1
	if is_modifier:
		_board.apply_modifier_to_cell(target_pos, randi() % 2)
		if pending[0] == 0:
			_passive_effect_active = false
	else:
		# Single-icon destruction effect — execute_effect resets flag via effect_completed.
		_board.execute_effect(effect, target_pos, Vector2i(-1, -1))

func _spawn_passive_icon(source: PassiveStack, data: PassiveStackData, target: Vector2, on_land: Callable) -> void:
	var icon := TextureRect.new()
	icon.texture = data.sprite_active
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(48, 48)
	get_parent().add_child(icon)

	var p0 := source.global_position + source.size * 0.5 - icon.size * 0.5
	var p3 := target - icon.size * 0.5
	var dist := p0.distance_to(p3)
	var away := signf((p3 - p0).x)
	if is_zero_approx(away): away = 1.0
	var p1 := p0 + Vector2(away * clampf(dist * 0.35, 80.0, 220.0), -clampf(dist * 0.3, 100.0, 260.0))
	var p2 := p3 + Vector2(-away * 50.0, -80.0)

	icon.global_position = p0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		icon.global_position = u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3
	, 0.0, 1.0, 0.7)
	tween.tween_property(icon, "scale", Vector2(0.0, 0.0), 0.07)
	tween.tween_callback(func() -> void:
		icon.queue_free()
		on_land.call()
	)

func _on_effect_completed() -> void:
	_passive_effect_active = false

func _show_add_score(node: TextureRect, amount: int) -> void:
	var label := node.get_node("Count") as Label
	label.text = "+%d" % amount
	node.modulate = Color.WHITE
	node.visible = true
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(node, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: node.visible = false)
