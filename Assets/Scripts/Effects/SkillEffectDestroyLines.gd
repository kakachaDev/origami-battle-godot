@tool
class_name SkillEffectDestroyLines
extends SkillEffect

func get_targets(board: BoardState, _origin: Vector2i, rank: int) -> Array[Vector2i]:
	var line_count := rank + 1  # rank1=2, rank2=3, rank3=4
	var hits: Dictionary = {}
	for i in line_count:
		if randi() % 2 == 0:
			var row := randi() % BoardState.ROWS
			for pos in board.get_bomb_lr_positions(row):
				hits[pos] = true
		else:
			var col := randi() % BoardState.COLS
			for pos in board.get_bomb_ud_positions(col):
				hits[pos] = true
	var result: Array[Vector2i] = []
	for pos in hits:
		result.append(pos)
	return result
