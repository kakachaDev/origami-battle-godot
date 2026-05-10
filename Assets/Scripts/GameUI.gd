extends Node
class_name GameUI

const _SKILL_DESTROY_TYPE: SkillData = preload("res://Assets/Resources/Skills/DestroyType.tres")
const _SKILL_DESTROY_LINES: SkillData = preload("res://Assets/Resources/Skills/DestroyLines.tres")
const _SKILL_ACTIVATE_MODS: SkillData = preload("res://Assets/Resources/Skills/ActivateModifiers.tres")

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
@onready var _l_skill1: ActiveSkillBase = $"../HotBar/L_ActiveSkillSlots/Slot1/ActiveSkillBase"
@onready var _l_skill2: ActiveSkillBase = $"../HotBar/L_ActiveSkillSlots/Slot2/ActiveSkillBase"
@onready var _r_skill1: ActiveSkillBase = $"../HotBar/R_ActiveSkillSlots/Slot1/ActiveSkillBase"
@onready var _r_slot2: Control = $"../HotBar/R_ActiveSkillSlots/Slot2"

var _current_player: int = GameManager.LEFT
var _selected_skill: ActiveSkillBase = null

var _l_score_val: int = 0
var _r_score_val: int = 0
var _l_add_score_tween_h: Array = [null]
var _r_add_score_tween_h: Array = [null]

func _ready() -> void:
	_manager.score_updated.connect(_on_score_updated)
	_manager.turns_updated.connect(_on_turns_updated)
	_manager.passive_types_assigned.connect(_on_passive_types_assigned)
	_manager.passive_charge_updated.connect(_on_passive_charge_updated)
	_board.passive_charged.connect(_on_passive_charged)
	_board.passive_fire_requested.connect(_on_passive_fire_requested)
	_board.skill_targeting_changed.connect(_on_skill_targeting_changed)
	_l_add_score.visible = false
	_r_add_score.visible = false

	_r_slot2.visible = false

	_l_skill1.skill_data = _SKILL_DESTROY_TYPE
	_l_skill1.rank = 2
	_l_skill1.count = 1
	_l_skill2.skill_data = _SKILL_DESTROY_LINES
	_l_skill2.rank = 1
	_l_skill2.count = 1
	_r_skill1.skill_data = _SKILL_ACTIVATE_MODS
	_r_skill1.rank = 1
	_r_skill1.count = 1

	_update_skill_button_interaction()

	_l_skill1.pressed.connect(func(): _on_skill_pressed(_l_skill1, GameManager.LEFT))
	_l_skill2.pressed.connect(func(): _on_skill_pressed(_l_skill2, GameManager.LEFT))
	_r_skill1.pressed.connect(func(): _on_skill_pressed(_r_skill1, GameManager.RIGHT))

func _on_score_updated(l_score: int, r_score: int) -> void:
	var l_delta := l_score - _l_score_val
	var r_delta := r_score - _r_score_val
	_l_score_val = l_score
	_r_score_val = r_score

	_l_score.text = str(l_score)
	_r_score.text = str(r_score)
	if l_delta != 0:
		_punch_scale(_l_score)
	if r_delta != 0:
		_punch_scale(_r_score)
	_score_line.value = clampf(float(l_score - r_score), -100.0, 100.0)

	if l_delta > 0:
		_show_add_score(_l_add_score, l_delta, -25.0)
	if r_delta > 0:
		_show_add_score(_r_add_score, r_delta, 25.0)

func _punch_scale(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	var punch := create_tween()
	punch.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	punch.tween_property(label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_turns_updated(l_moves: int, r_moves: int, player: int, round: int) -> void:
	_l_turns.text = str(l_moves)
	_r_turns.text = str(r_moves)
	_current_player = player
	_update_skill_button_interaction()
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

func _on_passive_charged(player: int, _charge: int, source_world_pos: Vector2) -> void:
	var passive_node := _l_passive if player == GameManager.LEFT else _r_passive
	var gem_type := _manager.l_passive_gem_type if player == GameManager.LEFT else _manager.r_passive_gem_type
	if gem_type >= 0 and gem_type < passive_stack_resources.size():
		_spawn_flying_gem(source_world_pos, passive_node, passive_stack_resources[gem_type])

func _on_passive_fire_requested(player: int, icon_targets: Array) -> void:
	var passive_node := _l_passive if player == GameManager.LEFT else _r_passive
	var data: PassiveStackData = passive_node.stack_data
	if not data or icon_targets.is_empty():
		(func(): _board.passive_fire_completed.emit()).call_deferred()
		return
	var pending := [icon_targets.size()]
	for target_pos in icon_targets:
		var world := _board.get_cell_world_center(target_pos.x, target_pos.y)
		_spawn_passive_icon(passive_node, data, world, func():
			pending[0] -= 1
			if pending[0] == 0:
				_board.passive_fire_completed.emit()
		)

func _update_skill_button_interaction() -> void:
	var l_active := _current_player == GameManager.LEFT
	_l_skill1.mouse_filter = Control.MOUSE_FILTER_STOP if l_active else Control.MOUSE_FILTER_IGNORE
	_l_skill2.mouse_filter = Control.MOUSE_FILTER_STOP if l_active else Control.MOUSE_FILTER_IGNORE
	_r_skill1.mouse_filter = Control.MOUSE_FILTER_STOP if not l_active else Control.MOUSE_FILTER_IGNORE

func _on_skill_pressed(button: ActiveSkillBase, player: int) -> void:
	if _board.is_busy or player != _current_player:
		return
	var effect := button.skill_data.skill_effect as SkillEffect if button.skill_data else null
	if effect == null:
		return
	if _selected_skill == button:
		_selected_skill = null
		button.button_pressed = false
		_board.cancel_skill_targeting()
		return
	if _selected_skill != null:
		_selected_skill.button_pressed = false
		_board.cancel_skill_targeting()
	_selected_skill = button
	button.button_pressed = true
	_board.activate_skill(effect, button.rank)

func _on_skill_targeting_changed(is_targeting: bool) -> void:
	if not is_targeting and _selected_skill != null:
		_selected_skill.button_pressed = false
		_selected_skill = null

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

func _show_add_score(node: TextureRect, amount: int, start_angle_deg: float) -> void:
	var tween_holder := _l_add_score_tween_h if node == _l_add_score else _r_add_score_tween_h
	if tween_holder[0]:
		tween_holder[0].kill()

	var label := node.get_node("Count") as Label
	label.text = "+0"

	node.pivot_offset = node.size * 0.5
	node.rotation_degrees = start_angle_deg
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.scale = Vector2.ONE
	node.visible = true

	var tw := create_tween()
	tween_holder[0] = tw

	tw.tween_property(node, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "rotation_degrees", 0.0, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(
		func(v: float) -> void: label.text = "+%d" % roundi(v),
		0.0, float(amount), 0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.tween_interval(0.35)

	tw.tween_property(node, "modulate:a", 0.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "rotation_degrees", start_angle_deg, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.tween_callback(func() -> void: node.visible = false)
