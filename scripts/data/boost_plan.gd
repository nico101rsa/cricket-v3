class_name BoostPlan
extends RefCounted

# The Manager Boost (ADR 0005) as a harness input: the overs the Player presses
# the Boost, plus the base buff it fires. A press buffs the Player's current side
# (runs while batting / wicket while bowling) by base_mult for base_n balls — the
# Boost Stack jokers (#31–#37) modify it. base_mult/base_n are strawman, tunable.
# See spec 2026-06-08-jokers-in-sim-7cC2e-boost-design.md.

var press_overs: Array[int] = []
var base_mult: float = 1.15
var base_n: int = 6

# Does the Player press the Boost at the start of this 1-based over?
func presses_on(over: int) -> bool:
	return press_overs.has(over)

# Build a plan that presses at the given overs (base params default).
static func at(overs: Array[int]) -> BoostPlan:
	var p := BoostPlan.new()
	p.press_overs = overs.duplicate()
	return p
