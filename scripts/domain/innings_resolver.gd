class_name InningsResolver
extends RefCounted

# Pure resolution of one T20 innings by looping BallResolver.resolve_ball().
# See spec 2026-06-07-innings-sim-design.md and ADR 0004. No member state.

# Build -> batting position (1..9). Higher batting share bats higher up.
static func player_position(attrs: Attributes, itun: InningsTuning) -> int:
	var batting := attrs.power + attrs.composure
	var bowling := attrs.attack + attrs.control
	var share := float(batting) / float(batting + bowling)
	var pos := roundi(itun.pos_base - itun.pos_span * share)
	return clampi(pos, 1, 9)

# Weakening-tail scale for a partner at 1-based order position `pos`.
static func partner_factor(pos: int, itun: InningsTuning) -> float:
	return maxf(itun.tail_floor, 1.0 - (pos - 1) * itun.tail_slope)
