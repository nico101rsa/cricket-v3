class_name BoostPlan
extends RefCounted

# The Manager Boost (ADR 0005) as a harness input: the overs the Player presses
# the Boost, plus the base buff it fires. A press buffs the Player's current side
# (runs while batting / wicket while bowling) by base_mult for base_n balls — the
# Boost Stack jokers (#31–#37) modify it. base_mult/base_n are strawman, tunable.
# See spec 2026-06-08-jokers-in-sim-7cC2e-boost-design.md.

var press_overs: Array[int] = []
# 1.15 -> 1.22 (T9 gate, 2026-07-04): the DW13 double-fire fix removed the hidden
# bowling-innings half of every live press, which had been ~half the lever's value;
# 1.22 restores the Boost lever into the spec's +2..+8 win-pt band (spec §9).
var base_mult: float = 1.22
var base_n: int = 6

# DW13 (spec 2026-07-04): innings-aware presses for live sessions. When non-empty,
# MatchResolver passes for_innings(1|2) to each innings so a press fires ONLY in
# its own innings. Empty (all headless flat plans) -> for_innings returns self,
# byte-identical to the old behaviour.
var press_pairs: Array = []   # [[innings_no, over], ...]

func for_innings(n: int) -> BoostPlan:
	if press_pairs.is_empty():
		return self
	var p := BoostPlan.new()
	p.base_mult = base_mult
	p.base_n = base_n
	for pr in press_pairs:
		if pr[0] == n:
			p.press_overs.append(pr[1])
	return p

# Does the Player press the Boost at the start of this 1-based over?
func presses_on(over: int) -> bool:
	return press_overs.has(over)

# Build a plan that presses at the given overs (base params default).
static func at(overs: Array[int]) -> BoostPlan:
	var p := BoostPlan.new()
	p.press_overs = overs.duplicate()
	return p
