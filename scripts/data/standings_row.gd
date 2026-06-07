class_name StandingsRow
extends RefCounted

# One team's league-phase record. NRR uses actual balls faced/bowled — a V1
# simplification of the all-out-quota rule. See spec
# 2026-06-07-season-league-7b2a-design.md §6.

var team_index: int = 0
var played: int = 0
var points: int = 0
var runs_for: int = 0
var balls_for: int = 0
var runs_against: int = 0
var balls_against: int = 0

# Net run rate: runs/over scored minus runs/over conceded. 0.0 if no balls.
func nrr() -> float:
	var rpo_for := (runs_for * 6.0) / balls_for if balls_for > 0 else 0.0
	var rpo_against := (runs_against * 6.0) / balls_against if balls_against > 0 else 0.0
	return rpo_for - rpo_against
