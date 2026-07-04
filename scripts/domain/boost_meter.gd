class_name BoostMeter
extends RefCounted

# ADR 0005 water-meter (spec 2026-07-04-boost-water-meter-design.md DW1-DW6).
# Per-innings, ticked once per BALL (the deterministic re-sim has no wall clock —
# spec §2). Press locks magnitude+window from current fill (linear); the meter then
# drains to 0 over exactly that window, and recharges at 1/RECHARGE_BALLS after.
# Pure state machine: no RNG, shared by headless careers and the live match.

const RECHARGE_BALLS := 34     # empty -> full; 6 + 34 = 40-ball full cycle (DW4)
const MIN_PRESS_FILL := 0.25   # a near-empty press is a no-op (DW5)

var fill := 1.0                # starts full each innings (DW1)
var drain_left := 0            # balls of drain remaining (> 0 while boost active)
var _drain_per_ball := 0.0

func draining() -> bool:
	return drain_left > 0

# Attempt a press at a ball start. Returns {} when blocked (draining / under min),
# else the locked buff {"mult": float, "n": int} — DW2's linear lock.
func try_press(base_mult: float, base_n: int) -> Dictionary:
	if draining() or fill < MIN_PRESS_FILL:
		return {}
	var n := maxi(1, roundi(fill * base_n))
	var mult := 1.0 + fill * (base_mult - 1.0)
	drain_left = n
	_drain_per_ball = fill / n
	return {"mult": mult, "n": n}

# Advance one ball (call after each ball resolves).
func tick() -> void:
	if drain_left > 0:
		drain_left -= 1
		fill = 0.0 if drain_left == 0 else maxf(0.0, fill - _drain_per_ball)
	else:
		fill = minf(1.0, fill + 1.0 / RECHARGE_BALLS)
