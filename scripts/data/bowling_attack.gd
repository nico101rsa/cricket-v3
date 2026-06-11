class_name BowlingAttack
extends RefCounted

# Derives the pace and spin (attack, control) profiles from a base bowling pair
# by tilting in opposite directions: pace trades control for attack (more
# wickets, more runs), spin trades attack for control (containment). Transient
# per-match derived data. See spec 2026-06-07-bowling-change-design.md.
# Card-rescale 2026-06-11: floats on the /100 scale; tilt = 2 legacy points.

const DEFAULT_TILT := 12.5  # 2 legacy points × Attributes.SCALE (card-rescale DR3)

var pace_attack: float
var pace_control: float
var spin_attack: float
var spin_control: float

func _init(base_attack: float, base_control: float, tilt: float = DEFAULT_TILT) -> void:
	pace_attack = maxf(Attributes.SCALE, base_attack + tilt)
	pace_control = maxf(Attributes.SCALE, base_control - tilt)
	spin_attack = maxf(Attributes.SCALE, base_attack - tilt)
	spin_control = maxf(Attributes.SCALE, base_control + tilt)

# kind is BowlingPlan.Kind. Returns Vector2(attack, control).
func profile(kind: int) -> Vector2:
	if kind == BowlingPlan.Kind.SPIN:
		return Vector2(spin_attack, spin_control)
	return Vector2(pace_attack, pace_control)
