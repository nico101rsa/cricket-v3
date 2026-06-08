class_name InningsResult
extends RefCounted

# Aggregate outcome of one innings. No per-ball log (spec §6). batters and
# fall_of_wickets hold plain Dictionaries (see spec §6 for keys).
var total: int
var wickets: int
var balls: int
var fall_of_wickets: Array
var batters: Array

# Player-as-bowler figures for THIS innings (0 if the Player did not bowl here).
# wickets taken / runs conceded / balls bowled during the Player's overs. See
# spec 2026-06-08-player-as-bowler-design.md (the D5 bowling stat line).
var player_bowl_wickets: int
var player_bowl_runs: int
var player_bowl_balls: int

func _init(p_total: int = 0, p_wickets: int = 0, p_balls: int = 0, p_fall: Array = [], p_batters: Array = [],
		p_bowl_wickets: int = 0, p_bowl_runs: int = 0, p_bowl_balls: int = 0) -> void:
	total = p_total
	wickets = p_wickets
	balls = p_balls
	fall_of_wickets = p_fall
	batters = p_batters
	player_bowl_wickets = p_bowl_wickets
	player_bowl_runs = p_bowl_runs
	player_bowl_balls = p_bowl_balls

# The Player's batting row, or {} if the Player did not feature.
func player_line() -> Dictionary:
	for b in batters:
		if b["is_player"]:
			return b
	return {}
