class_name BallOutcome
extends RefCounted

# Outcome of a single delivery. A wicket always scores 0 runs (V1).
var wicket: bool
var runs: int

func _init(p_wicket: bool = false, p_runs: int = 0) -> void:
	wicket = p_wicket
	runs = p_runs
