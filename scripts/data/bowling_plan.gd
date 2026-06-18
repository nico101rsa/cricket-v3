class_name BowlingPlan
extends RefCounted

# Caller-supplied bowler-type choice, one type per match phase — the bowling
# mirror of IntentPlan and the output of the Bowling Change Key Moment
# (setNextBowler, ADR 0006). See spec 2026-06-07-bowling-change-design.md.

enum Kind { PACE, SPIN }  # named Kind (not Type) to avoid built-in collisions

const POWERPLAY_OVERS := 6     # aligns with IntentPlan / T20 powerplay
const DEATH_START_OVER := 16   # aligns with IntentPlan death overs

var powerplay: int = Kind.PACE  # overs 1..6
var middle: int = Kind.SPIN     # overs 7..15
var death: int = Kind.PACE      # overs 16..20

# Bowling Key Moment overrides (spec 2026-06-18): per-over bowler-kind overrides from
# in-match captain decisions. null => plain phase rotation (byte-identical to every
# pre-Key-Moment caller). Mirror of IntentPlan.key_moments.
var key_moments: BowlingKeyMomentPlan = null

# 1-based over number -> bowler Kind for that over (Key Moment overrides win).
func for_over(over: int) -> int:
	var base := _phase_kind(over)
	if key_moments != null:
		return key_moments.effective_for_over(over, base)
	return base

# The plain phase kind (no Key Moment overrides applied).
func _phase_kind(over: int) -> int:
	if over <= POWERPLAY_OVERS:
		return powerplay
	if over < DEATH_START_OVER:
		return middle
	return death

# Textbook rotation: pace powerplay, spin middle, pace death (== the defaults).
static func textbook() -> BowlingPlan:
	return BowlingPlan.new()

# All-pace (attack everywhere) — for the directional test / all-out policy.
static func pace_only() -> BowlingPlan:
	var p := BowlingPlan.new()
	p.powerplay = Kind.PACE
	p.middle = Kind.PACE
	p.death = Kind.PACE
	return p

# All-spin (contain everywhere).
static func spin_only() -> BowlingPlan:
	var p := BowlingPlan.new()
	p.powerplay = Kind.SPIN
	p.middle = Kind.SPIN
	p.death = Kind.SPIN
	return p
