@tool
class_name SkillEffectDestroyType
extends SkillEffect

func get_targets(board: BoardState, origin: Vector2i, rank: int) -> Array[Vector2i]:
	if origin == Vector2i(-1, -1):
		return []
	var gem := board.get_gem(origin.x, origin.y)
	if rank >= 3 and gem == BoardState.APPLEBOMB_TYPE:
		return board.get_all_positions()
	if gem < 0 or gem == BoardState.APPLEBOMB_TYPE:
		return []
	return board.get_all_positions_of_type(gem)

func get_modifier_spreads(board: BoardState, origin: Vector2i, rank: int) -> Array:
	if rank < 2 or origin == Vector2i(-1, -1):
		return []
	var gem := board.get_gem(origin.x, origin.y)
	var mod := board.get_modifier(origin.x, origin.y)
	if gem < 0 or gem == BoardState.APPLEBOMB_TYPE or mod == BoardState.MOD_NONE:
		return []
	var result: Array = []
	for pos in board.get_all_positions_of_type(gem):
		if pos != origin:
			result.append({"pos": pos, "mod": mod, "gem": gem})
	return result
