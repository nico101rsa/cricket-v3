class_name BowlingAttack
extends RefCounted

# Derives the pace and spin (attack, control) profiles from a base bowling pair
# by tilting in opposite directions: pace trades control for attack (more
# wickets, more runs), spin trades attack for control (containment). Transient
# per-match derived data. See spec 2026-06-07-bowling-change-design.md.

const DEFAULT_TILT := 2  # strawman — the balance harness sweeps it later

var pace_attack: int
var pace_control: int
var spin_attack: int
var spin_control: int

func _init(base_attack: int, base_control: int, tilt: int = DEFAULT_TILT) -> void:
	pace_attack = maxi(1, base_attack + tilt)
	pace_control = maxi(1, base_control - tilt)
	spin_attack = maxi(1, base_attack - tilt)
	spin_control = maxi(1, base_control + tilt)

# kind is BowlingPlan.Kind. Returns Vector2i(attack, control).
func profile(kind: int) -> Vector2i:
	if kind == BowlingPlan.Kind.SPIN:
		return Vector2i(spin_attack, spin_control)
	return Vector2i(pace_attack, pace_control)
