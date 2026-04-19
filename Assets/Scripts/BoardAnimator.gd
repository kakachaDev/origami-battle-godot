extends Node
class_name BoardAnimator

const SWAP_TIME := 0.25
const DESTROY_TIME := 0.16
const FALL_SPEED := 900.0  # px/s

func animate_swap(cell_a: Control, cell_b: Control, pos_a: Vector2, pos_b: Vector2) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(cell_a, "position", pos_b, SWAP_TIME)
	tw.tween_property(cell_b, "position", pos_a, SWAP_TIME)
	await tw.finished

func animate_return(cell_a: Control, cell_b: Control, pos_a: Vector2, pos_b: Vector2) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(cell_a, "position", pos_a, SWAP_TIME)
	tw.tween_property(cell_b, "position", pos_b, SWAP_TIME)
	await tw.finished

func animate_destroy(cells: Array) -> void:
	if cells.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	for cell in cells:
		tw.tween_property(cell as Control, "scale", Vector2.ZERO, DESTROY_TIME)
	await tw.finished
	for cell in cells:
		(cell as Control).visible = false
		(cell as Control).scale = Vector2.ONE

func animate_fall(entries: Array) -> void:
	# entries: Array of {cell: Control, target: Vector2}
	# All gems fall simultaneously; duration is proportional to distance.
	if entries.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	for e in entries:
		var dist := absf((e.cell as Control).position.y - e.target.y)
		tw.tween_property(e.cell, "position", e.target, dist / FALL_SPEED)
	await tw.finished
