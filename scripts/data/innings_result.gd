class_name InningsResult
extends RefCounted

# Aggregate outcome of one innings. No per-ball log (spec §6). batters and
# fall_of_wickets hold plain Dictionaries (see spec §6 for keys).
var total: int
var wickets: int
var balls: int
var fall_of_wickets: Array
var batters: Array

func _init(p_total: int = 0, p_wickets: int = 0, p_balls: int = 0, p_fall: Array = [], p_batters: Array = []) -> void:
	total = p_total
	wickets = p_wickets
	balls = p_balls
	fall_of_wickets = p_fall
	batters = p_batters

# The Player's batting row, or {} if the Player did not feature.
func player_line() -> Dictionary:
	for b in batters:
		if b["is_player"]:
			return b
	return {}
